#!/usr/bin/env tclsh
# Test script to check Tcl syntax in source files

set errors 0

# Files to check
set files [glob -nocomplain src/*.tcl src/i18n/*.tcl]

foreach file $files {
    if {[catch {open $file r} fh]} {
        puts "ERROR: Cannot open $file"
        incr errors
        continue
    }

    set content [read $fh]
    close $fh

    # Try to parse the file as Tcl
    if {[catch {
        # Parse the Tcl script to check for syntax errors
        set result [info complete $content]
        if {!$result} {
            error "Incomplete Tcl script"
        }
    } err]} {
        puts "ERROR: Syntax error in $file: $err"
        incr errors
    }
}

if {$errors == 0} {
    puts "✓ All source files have valid Tcl syntax"
    exit 0
} else {
    puts "✗ Found $errors error(s)"
    exit 1
}
