"""Build the pinned Linux programmer in the read-only Ubuntu container."""

import hashlib
import json
import os
import re
import shutil
import subprocess
import tarfile
import urllib.request
from pathlib import Path

SOFTWARE = Path(__file__).resolve().parents[1]
BUILD = SOFTWARE / "build/programmer"
LOCK = SOFTWARE / "packaging/programmer-linux.lock.json"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(arguments, **kwargs):
    subprocess.run([str(value) for value in arguments], check=True, **kwargs)


def copyright_file(root, name):
    path = root / f"usr/share/doc/{name}/copyright"
    for _ in range(10):
        if not path.is_symlink():
            return path
        target = Path(os.readlink(path))
        path = root / str(target).lstrip("/") if target.is_absolute() else path.parent / target
    raise ValueError("Copyright symlink loop")


def main():
    lock = json.loads(LOCK.read_text())
    BUILD.mkdir(parents=True, exist_ok=True)
    debs = BUILD / "debs"
    debs.mkdir(exist_ok=True)
    missing = [item for item in lock["packages"] if not (debs / item["file"]).exists()]
    if missing:
        Path("/tmp/viewrv-apt/partial").mkdir(parents=True, exist_ok=True)
        options = ["-o", "Dir::State::lists=/tmp/viewrv-apt", "-o", "Dir::Cache=/tmp/viewrv-cache"]
        run(["apt-get", *options, "update"])
        run(
            [
                "apt-get",
                *options,
                "download",
                *[f"{item['name']}={item['version']}" for item in missing],
            ],
            cwd=debs,
        )
    tools = BUILD / "toolchain"
    tools.mkdir(exist_ok=True)
    for item in lock["packages"]:
        file = debs / item["file"]
        if digest(file) != item["sha256"]:
            raise ValueError("Package hash mismatch: " + item["file"])
        run(["dpkg-deb", "-x", file, tools])
    # Linker scripts in libc6-dev refer to base runtime libraries. The image
    # digest pins these files; no system directory is changed.
    target = tools / "lib/x86_64-linux-gnu"
    target.mkdir(parents=True, exist_ok=True)
    for name in (
        "libc.so.6",
        "libm.so.6",
        "libmvec.so.1",
        "libpthread.so.0",
        "libdl.so.2",
        "librt.so.1",
    ):
        shutil.copyfile(Path("/lib/x86_64-linux-gnu") / name, target / name)
    (tools / "lib64").mkdir(exist_ok=True)
    shutil.copyfile("/lib64/ld-linux-x86-64.so.2", tools / "lib64/ld-linux-x86-64.so.2")
    archive = BUILD / "openFPGALoader-v1.2.0.tar.gz"
    if not archive.exists():
        urllib.request.urlretrieve(lock["source_url"], archive)
    if digest(archive) != lock["source_sha256"]:
        raise ValueError("openFPGALoader source hash mismatch")
    source = BUILD / "openFPGALoader-1.2.0"
    # Reconstruct from the verified archive, never from an edited cached checkout.
    shutil.rmtree(source, ignore_errors=True)
    with tarfile.open(archive) as stream:
        stream.extractall(BUILD, filter="data")
    environment = {
        **os.environ,
        "PATH": str(tools / "usr/bin") + os.pathsep + os.environ["PATH"],
        "LD_LIBRARY_PATH": str(tools / "usr/lib/x86_64-linux-gnu"),
        "PKG_CONFIG_SYSROOT_DIR": str(tools),
        "PKG_CONFIG_LIBDIR": str(tools / "usr/lib/x86_64-linux-gnu/pkgconfig")
        + ":"
        + str(tools / "usr/share/pkgconfig"),
    }
    flags = [
        "-DCMAKE_BUILD_TYPE=Release",
        "-DENABLE_CABLE_ALL=OFF",
        "-DENABLE_FTDI_BASED_CABLE=ON",
        "-DENABLE_VENDORS_ALL=OFF",
        "-DENABLE_XILINX_SUPPORT=ON",
        "-DENABLE_USB_SCAN=ON",
        "-DENABLE_UDEV=OFF",
        "-DENABLE_LIBGPIOD=OFF",
        f"-DCMAKE_CXX_FLAGS=--sysroot={tools}",
        "-DCMAKE_EXE_LINKER_FLAGS=-static-libstdc++ -static-libgcc",
        f"-DCMAKE_FIND_ROOT_PATH={tools}",
        "-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY",
        "-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY",
        "-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER",
        "-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON",
        "-DCMAKE_INSTALL_RPATH=$ORIGIN/lib",
    ]
    run([tools / "usr/bin/cmake", "-S", source, "-B", BUILD / "compile", *flags], env=environment)
    run(
        [tools / "usr/bin/cmake", "--build", BUILD / "compile", "--clean-first", "-j", "4"],
        env=environment,
    )
    destination = SOFTWARE / "resources/programmer"
    destination.mkdir(parents=True, exist_ok=True)
    for name in ("lib", "licenses", "sources"):
        shutil.rmtree(destination / name, ignore_errors=True)
        (destination / name).mkdir()
    executable = destination / "openFPGALoader"
    shutil.copy2(BUILD / "compile/openFPGALoader", executable)
    output = subprocess.check_output(["ldd", str(executable)], text=True, env=environment)
    if "not found" in output:
        raise ValueError(output)
    names = {
        "libusb-1.0.so.0": "libusb-1.0-0",
        "libftdi1.so.2": "libftdi1-2",
        "libudev.so.1": "libudev1",
        "libcap.so.2": "libcap2",
        "libz.so.1": "zlib1g",
        "libgcc_s.so.1": "libgcc-s1",
        "libstdc++.so.6": "libstdc++6",
    }
    dependencies = []
    for name, file in re.findall(r"^\s*(\S+) => (/\S+)", output, re.M):
        if name in {"libc.so.6", "libm.so.6", "libdl.so.2", "librt.so.1", "libpthread.so.0"}:
            continue
        package = names[name]
        shutil.copyfile(file, destination / "lib" / name)
        copyright = copyright_file(tools, package)
        if not copyright.is_file():
            copyright = copyright_file(Path("/"), package)
        shutil.copyfile(copyright, destination / "licenses" / (package + ".txt"))
        version = next(
            (item["version"] for item in lock["packages"] if item["name"] == package), None
        )
        if version is None:
            version = subprocess.check_output(
                ["dpkg-query", "-W", "-f=${Version}", package], text=True
            )
        dependencies.append({"file": name, "package": package, "version": version})
    shutil.copyfile(source / "LICENSE", destination / "licenses/openFPGALoader.txt")
    gcc_license = copyright_file(tools, "gcc-13-base")
    if not gcc_license.is_file():
        gcc_license = copyright_file(Path("/"), "gcc-13-base")
    shutil.copyfile(gcc_license, destination / "licenses/gcc-runtime.txt")
    shutil.copyfile(archive, destination / "sources/openFPGALoader-v1.2.0.tar.gz")
    shutil.copyfile(LOCK, destination / "sources/build-lock.json")
    files = [
        {"path": str(file.relative_to(destination)), "sha256": digest(file)}
        for file in sorted(destination.rglob("*"))
        if file.is_file() and file.name != "manifest.json"
    ]
    manifest = {
        "schema_version": 1,
        "version": "1.2.0",
        "platform": "linux",
        "architecture": "x86_64",
        "source_url": lock["source_url"],
        "source_sha256": lock["source_sha256"],
        "source_revision": lock["source_revision"],
        "build_flags": flags,
        "dependencies": dependencies,
        "files": files,
    }
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    run([executable, "--version"], env={**environment, "LD_LIBRARY_PATH": str(destination / "lib")})


if __name__ == "__main__":
    main()
