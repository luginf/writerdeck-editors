#!/usr/bin/env tclsh
# Align markdown table pipes for better readability

proc align-markdown-tables {file} {
    set lines [split [chan read [open $file r]] "\n"]
    set result {}
    set table_lines {}

    foreach line $lines {
        # Detect table line (contains | with content)
        if {[string match "*|*" $line] && [string length $line] > 2} {
            lappend table_lines $line
        } else {
            # End of table - process and output
            if {[llength $table_lines] > 0} {
                foreach aligned [align-table-block $table_lines] {
                    lappend result $aligned
                }
                set table_lines {}
            }
            lappend result $line
        }
    }

    # Process final table if exists
    if {[llength $table_lines] > 0} {
        foreach aligned [align-table-block $table_lines] {
            lappend result $aligned
        }
    }

    return [join $result "\n"]
}

proc align-table-block {table_lines} {
    # Parse all rows into cells
    set rows {}
    set col_widths {}
    set is_separator [list]

    foreach line $table_lines {
        # Remove leading/trailing spaces and pipes
        set line [string trim $line " |"]
        set cells [split $line "|"]

        set row {}
        set col 0
        set line_is_sep 1

        foreach cell $cells {
            set cell [string trim $cell]
            lappend row $cell

            # Track if this cell is part of separator row (all dashes/spaces)
            if {![string match {[-\s]*} $cell] || $cell eq ""} {
                set line_is_sep 0
            }

            # Track max width for each column
            set width [string length $cell]
            if {$col >= [llength $col_widths]} {
                lappend col_widths $width
            } else {
                set current [lindex $col_widths $col]
                if {$width > $current} {
                    lset col_widths $col $width
                }
            }
            incr col
        }

        lappend rows $row
        lappend is_separator $line_is_sep
    }

    # Rebuild table with aligned pipes
    set result {}
    for {set row_idx 0} {$row_idx < [llength $rows]} {incr row_idx} {
        set row [lindex $rows $row_idx]
        set sep [lindex $is_separator $row_idx]

        set line "|"
        for {set col 0} {$col < [llength $row]} {incr col} {
            set cell [lindex $row $col]
            set width [lindex $col_widths $col]

            if {$sep} {
                # Separator row - use dashes
                append line " [string repeat - $width] |"
            } else {
                # Regular row - pad with spaces
                set padding [expr {$width - [string length $cell]}]
                append line " $cell[string repeat " " $padding] |"
            }
        }
        lappend result $line
    }

    return $result
}

# Main
if {[llength $argv] == 0} {
    puts "Usage: align-tables.tcl <file>"
    puts "Aligns markdown table pipes for better readability"
    puts ""
    puts "Examples:"
    puts "  align-tables.tcl README.md              # Show preview"
    puts "  align-tables.tcl README.md --inplace    # Modify file"
    exit 1
}

set file [lindex $argv 0]

if {![file exists $file]} {
    puts "Error: File '$file' not found"
    exit 1
}

set content [align-markdown-tables $file]

if {[llength $argv] > 1 && [lindex $argv 1] eq "--inplace"} {
    set out [open $file w]
    puts -nonewline $out $content
    close $out
    puts "✓ Aligned tables in $file"
} else {
    puts $content
    puts ""
    puts "Use: align-tables.tcl $file --inplace  (to write back to file)"
}
