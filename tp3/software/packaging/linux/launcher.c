/* Linux entry point: keep a kernel-owned lease while the native payload runs.
 * Parent supervision avoids relying on Electron/Python retaining an inherited fd.
 * Only the maintenance entry requests an exclusive lease. No PID file is a lock.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <pwd.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

static volatile sig_atomic_t child_handle = -1;
static const char *failure_reason = "NATIVE_LAUNCH_FAILED";

static void relay(int number) {
    int saved = errno;
    if (child_handle >= 0)
        (void)syscall(SYS_pidfd_send_signal, child_handle, number, NULL, 0);
    errno = saved;
}

static bool structured(int argc, char **argv) {
    for (int i = 1; i < argc; ++i) {
        if (!strcmp(argv[i], "--output=json")) return true;
        if (!strcmp(argv[i], "--output") && i + 1 < argc && !strcmp(argv[i + 1], "json"))
            return true;
    }
    return false;
}

static int fail(bool json, const char *message) {
    if (json) {
        /* All messages are fixed strings, without user input or credentials. */
        printf("{\"result\":null,\"error\":{\"code\":\"CORE_START_FAILED\","
               "\"message\":\"%s\",\"details\":{\"reason\":\"%s\"}}}\n",
               message, failure_reason);
        fflush(stdout);
    } else {
        fprintf(stderr, "viewrv: %s\n", message);
    }
    return 1;
}

static int make_parents(char *path) {
    for (char *p = path + 1; ; ++p) {
        if (*p != '/' && *p != '\0') continue;
        char end = *p;
        *p = '\0';
        if (mkdir(path, 0700) && errno != EEXIST) { *p = end; return -1; }
        struct stat info;
        if (stat(path, &info) || !S_ISDIR(info.st_mode)) { *p = end; return -1; }
        *p = end;
        if (!end) return 0;
    }
}

static int lease_file(void) {
    const char *xdg = getenv("XDG_STATE_HOME");
    const char *home = getenv("HOME");
    if (!home || home[0] != '/') {
        struct passwd *account = getpwuid(getuid());
        if (!account || !account->pw_dir || account->pw_dir[0] != '/') return -1;
        home = account->pw_dir;
    }
    char directory[PATH_MAX];
    int length = (xdg && xdg[0] == '/')
        ? snprintf(directory, sizeof directory, "%s/viewrv", xdg)
        : snprintf(directory, sizeof directory, "%s/.local/state/viewrv", home);
    if (length < 0 || (size_t)length >= sizeof directory) return -1;
    mode_t previous = umask(0077);
    int result = -1;
    struct stat info;
    if (make_parents(directory) || lstat(directory, &info) || !S_ISDIR(info.st_mode) ||
        info.st_uid != getuid() || chmod(directory, 0700)) goto finished;
    char path[PATH_MAX];
    length = snprintf(path, sizeof path, "%s/maintenance.lock", directory);
    if (length < 0 || (size_t)length >= sizeof path) goto finished;
    result = open(path, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (result >= 0 && (fstat(result, &info) || !S_ISREG(info.st_mode) ||
                        info.st_uid != getuid() || info.st_nlink != 1 || fchmod(result, 0600))) {
        close(result);
        result = -1;
    }
finished:
    umask(previous);
    return result;
}

int main(int argc, char **argv) {
    char executable[PATH_MAX];
    ssize_t length = readlink("/proc/self/exe", executable, sizeof executable - 1);
    if (length <= 0 || (size_t)length >= sizeof executable - 1)
        return fail(false, "No se pudo identificar el ejecutable instalado.");
    executable[length] = '\0';
    char *separator = strrchr(executable, '/');
    if (!separator) return fail(false, "Ruta de producto inválida.");
    const char *name = separator + 1;
    bool maintenance = !strcmp(name, "viewrv-maintenance");
    bool json = !strcmp(name, "viewrv") && structured(argc, argv);
    if (strcmp(name, "viewrv") && strcmp(name, "viewrv-gui") &&
        strcmp(name, "viewrv-core") && !maintenance)
        return fail(json, "Entrada de producto no reconocida.");
    char payload[PATH_MAX];
    int count = snprintf(payload, sizeof payload, "%.*s/.%s-native",
                         (int)(separator - executable), executable, name);
    if (count < 0 || (size_t)count >= sizeof payload)
        return fail(json, "Ruta de producto demasiado larga.");
    int lease = lease_file();
    if (lease < 0)
        return fail(json, "No se pudo abrir la coordinación privada del producto.");
    if (flock(lease, (maintenance ? LOCK_EX : LOCK_SH) | LOCK_NB)) {
        close(lease);
        failure_reason = "PRODUCT_MAINTENANCE";
        return fail(json, maintenance
            ? "Cerrá la GUI y finalizá explícitamente los trabajos CLI antes del mantenimiento."
            : "El producto está en mantenimiento; volvé a abrirlo cuando termine.");
    }
    sigset_t blocked, previous;
    sigemptyset(&blocked);
    const int signals[] = {SIGINT, SIGTERM, SIGHUP, SIGQUIT};
    for (size_t i = 0; i < sizeof signals / sizeof signals[0]; ++i)
        sigaddset(&blocked, signals[i]);
    if (sigprocmask(SIG_BLOCK, &blocked, &previous)) {
        close(lease);
        return fail(json, "No se pudo preparar el arranque nativo.");
    }
    pid_t child = fork();
    if (child == 0) {
        /* A private session prevents one terminal signal from being delivered
         * both directly and through the supervising parent. */
        if (setsid() < 0) _exit(1);
        if (maintenance) {
            char descriptor[32];
            snprintf(descriptor, sizeof descriptor, "%d", lease);
            if (fcntl(lease, F_SETFD, 0) || setenv("VIEWRV_MAINTENANCE_FD", descriptor, 1))
                _exit(1);
        } else {
            close(lease);
            unsetenv("VIEWRV_MAINTENANCE_FD");
        }
        if (sigprocmask(SIG_SETMASK, &previous, NULL)) _exit(1);
        argv[0] = payload;
        execv(payload, argv);
        (void)fail(json, "No se pudo iniciar el componente nativo del producto.");
        _exit(1);
    }
    if (child < 0) {
        close(lease);
        return fail(json, "No se pudo crear el proceso nativo.");
    }
    int handle = (int)syscall(SYS_pidfd_open, child, 0);
    if (handle < 0) {
        /* The child is still ours and has not been reaped, so this PID cannot
         * have been recycled. Never fall back to signalling a later PID. */
        (void)kill(child, SIGKILL);
        (void)waitpid(child, NULL, 0);
        close(lease);
        return fail(json, "El sistema no permite supervisar el proceso nativo.");
    }
    child_handle = handle;
    struct sigaction action;
    memset(&action, 0, sizeof action);
    action.sa_handler = relay;
    sigemptyset(&action.sa_mask);
    for (size_t i = 0; i < sizeof signals / sizeof signals[0]; ++i)
        if (sigaction(signals[i], &action, NULL)) {
            (void)syscall(SYS_pidfd_send_signal, handle, SIGKILL, NULL, 0);
            (void)waitpid(child, NULL, 0);
            close(handle);
            close(lease);
            return fail(json, "No se pudo supervisar el proceso nativo.");
        }
    (void)sigprocmask(SIG_SETMASK, &previous, NULL);
    int status;
    pid_t ended;
    do { ended = waitpid(child, &status, 0); } while (ended < 0 && errno == EINTR);
    (void)sigprocmask(SIG_BLOCK, &blocked, NULL);
    child_handle = -1;
    close(handle);
    close(lease);
    if (ended < 0) return fail(json, "No se pudo esperar el cierre nativo.");
    if (WIFEXITED(status)) return WEXITSTATUS(status);
    return WIFSIGNALED(status) ? 128 + WTERMSIG(status) : 1;
}
