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

proc write_build_info {output_dir mode inputs} {
    global tp3_dir basys3_part
    set revision [exec git -C $tp3_dir rev-parse HEAD]
    set changes [exec git -C $tp3_dir status --short]
    set manifest [open [file join $output_dir build-info.txt] w]
    puts $manifest [version]
    puts $manifest "Part $basys3_part"
    puts $manifest "Profile REFERENCE"
    puts $manifest "Mode $mode"
    puts $manifest "Commit $revision"
    puts $manifest "Git status:"
    puts $manifest $changes
    puts $manifest "SHA-256 de fuentes:"
    puts $manifest [exec sha256sum -- {*}$inputs]
    close $manifest
}

proc rtl_files {} {
    global tp3_dir
    set package [file join $tp3_dir rtl system_pkg.sv]
    set modules [lsort [glob -directory [file join $tp3_dir rtl] *.sv]]
    return [linsert [lsearch -all -inline -not -exact $modules $package] 0 $package]
}
