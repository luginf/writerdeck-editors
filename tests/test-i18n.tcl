#!/usr/bin/env tclsh
# Test script for i18n translations
# Validates that all language files have complete translations

set errors 0
set warnings 0

# Load all language files
set langs {}
foreach f [glob src/i18n/*.tcl] {
    lappend langs [file rootname [file tail $f]]
}
set langs [lsort $langs]

if {[llength $langs] == 0} {
    puts "ERROR: No language files found in src/i18n/"
    exit 1
}

puts "Testing i18n translations..."
puts "Languages found: $langs\n"

# Initialize i18n dictionary
set ::i18n {}

# Load all translations
foreach lang $langs {
    source src/i18n/${lang}.tcl
}

# Get keys from English
if {![dict exists $::i18n en]} {
    puts "ERROR: English translation file (en.tcl) not found"
    exit 1
}

set en_keys [dict keys [dict get $::i18n en]]
set en_count [llength $en_keys]
puts "English has $en_count translation keys\n"

# Check each language
foreach lang $langs {
    if {![dict exists $::i18n $lang]} {
        puts "ERROR: Language '$lang' not found in i18n dictionary"
        incr errors
        continue
    }

    set lang_dict [dict get $::i18n $lang]
    set lang_keys [dict keys $lang_dict]
    set lang_count [llength $lang_keys]

    # Check for missing keys
    set missing {}
    foreach key $en_keys {
        if {![dict exists $lang_dict $key]} {
            lappend missing $key
        }
    }

    # Check for extra keys
    set extra {}
    foreach key $lang_keys {
        if {[lsearch -exact $en_keys $key] < 0} {
            lappend extra $key
        }
    }

    # Report results
    if {[llength $missing] == 0 && [llength $extra] == 0} {
        puts "✓ $lang: $lang_count keys (complete)"
    } else {
        puts "✗ $lang: $lang_count keys"
        if {[llength $missing] > 0} {
            puts "  Missing keys: $missing"
            incr errors
        }
        if {[llength $extra] > 0} {
            puts "  Extra keys: $extra"
            incr warnings
        }
    }
}

puts ""

# Check for format string consistency (%s count)
puts "Checking format string consistency..."
set format_errors 0
foreach key $en_keys {
    set en_val [dict get $::i18n en $key]
    set en_count [regexp -all {%s} $en_val]

    foreach lang [lrange $langs 1 end] {
        if {[dict exists $::i18n $lang $key]} {
            set lang_val [dict get $::i18n $lang $key]
            set lang_count [regexp -all {%s} $lang_val]

            if {$en_count != $lang_count} {
                puts "✗ Key '$key': format mismatch"
                puts "  English has $en_count %s, $lang has $lang_count %s"
                incr format_errors
            }
        }
    }
}

if {$format_errors == 0} {
    puts "✓ All format strings are consistent"
} else {
    incr errors $format_errors
}

puts ""

# Summary
if {$errors == 0} {
    puts "✓ All i18n tests passed"
    exit 0
} else {
    puts "✗ Found $errors error(s), $warnings warning(s)"
    exit 1
}
