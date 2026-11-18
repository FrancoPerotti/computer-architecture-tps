set tp3_dir [file normalize [file join [file dirname [info script]] ..]]
set basys3_part xc7a35tcpg236-1

proc create_output_dir {path} {
    set directory [file normalize $path]
    if {[file exists $directory]} {
        error "Usar un directorio nuevo para conservar los resultados anteriores: $directory"
    }
    file mkdir $directory
    return $directory
}

proc file_sha256 {path} {
    set path [file normalize $path]
    if {[auto_execok sha256sum] ne ""} {
        return [exec sha256sum -- $path]
    }
    if {$::tcl_platform(platform) eq "windows" && [auto_execok powershell.exe] ne ""} {
        # El path se pasa por una variable de entorno, sin interpolarlo como c?digo.
        set ::env(TP3_HASH_FILE) $path
        set result [exec powershell.exe -NoProfile -NonInteractive -Command {
            (Get-FileHash -LiteralPath $env:TP3_HASH_FILE -Algorithm SHA256).Hash
        }]
        unset ::env(TP3_HASH_FILE)
        return "$result  $path"
    }
    error "Se requiere sha256sum o PowerShell con Get-FileHash para registrar SHA-256"
}

proc write_build_info {output_dir mode inputs} {
    global tp3_dir basys3_part
    if {[auto_execok git] eq ""} { error "Git debe estar disponible en el PATH de Vivado" }
    set repo [file normalize [file join $tp3_dir ..]]
    set revision [exec git -c safe.directory=$repo -C $repo rev-parse HEAD]
    set changes [exec git -c safe.directory=$repo -C $repo status --short]
    set manifest [open [file join $output_dir build-info.txt] w]
    puts $manifest [version]
    puts $manifest "Part $basys3_part"
    puts $manifest "Profile REFERENCE"
    puts $manifest "Mode $mode"
    puts $manifest "Commit $revision"
    puts $manifest "Git status:"
    puts $manifest $changes
    puts $manifest "SHA-256 de fuentes:"
    foreach input $inputs { puts $manifest [file_sha256 $input] }
    close $manifest
}

proc rtl_files {} {
    global tp3_dir
    set package [file join $tp3_dir rtl system_pkg.sv]
    set modules [lsort [glob -directory [file join $tp3_dir rtl] *.sv]]
    return [linsert [lsearch -all -inline -not -exact $modules $package] 0 $package]
}
