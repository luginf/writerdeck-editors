if {!$::no_gui} {
wm title . "Writhdeck Browser"

# wm iconphoto . -default [image create photo -file [file join [file dirname [info script]] writhdeck.png]]
set ::_icon_b64 {iVBORw0KGgoAAAANSUhEUgAAAGAAAABgAQMAAADYVuV7AAAAwXpUWHRSYXcgcHJvZmlsZSB0eXBlIGV4aWYAAHjabVBbDsMgDPvnFDsCJDyS49C1k3aDHX+mSauyzhKOgyUTErbP+xUeA5RyyKVJ1VojkDUrdQiJhr5zinnnHdUt9NN9OA3CFaOyteJGOu7TGWClQ5VLkDzdWGZDs+fLTxBZ4THR0KsHqQcxmZE8oHf/ikq7fmHZ4gyxEwZlmce+9Q3bWwveYaKNE0cwc7UBeJwauEMUcGKsA1qhybl5GBbyb08Hwhfm3FkghSRy6AAAAYVpQ0NQSUNDIHByb2ZpbGUAAHicfZG/S8NAHMVfU2tFKw52EHHIUJ3solIcaxWKUKHUCq06mFz6C5o0JCkujoJrwcEfi1UHF2ddHVwFQfAHiH+AOCm6SInfSwotYjw47sO7e4+7d4DQrDLV7IkDqmYZmWRCzOVXxeArAhhAEL2ISczU59LpFDzH1z18fL2L8izvc3+OQaVgMsAnEseZbljEG8SxTUvnvE8cZmVJIT4nnjTogsSPXJddfuNccljgmWEjm5knDhOLpS6Wu5iVDZV4hjiiqBrlCzmXFc5bnNVqnbXvyV8YKmgry1ynOYYkFrGENETIqKOCKixEadVIMZGh/YSHf9Txp8klk6sCRo4F1KBCcvzgf/C7W7M4PeUmhRJA4MW2P8aB4C7Qatj297Ftt04A/zNwpXX8tSYw+0l6o6NFjoChbeDiuqPJe8DlDjDypEuG5Eh+mkKxCLyf0TflgeFboH/N7a29j9MHIEtdpW6Ag0NgokTZ6x7v7uvu7d8z7f5+AHHScqZUIDF8AAANeGlUWHRYTUw6Y29tLmFkb2JlLnhtcAAAAAAAPD94cGFja2V0IGJlZ2luPSLvu78iIGlkPSJXNU0wTXBDZWhpSHpyZVN6TlRjemtjOWQiPz4KPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iWE1QIENvcmUgNC40LjAtRXhpdjIiPgogPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4KICA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIgogICAgeG1sbnM6eG1wTU09Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9tbS8iCiAgICB4bWxuczpzdEV2dD0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUeXBlL1Jlc291cmNlRXZlbnQjIgogICAgeG1sbnM6ZGM9Imh0dHA6Ly9wdXJsLm9yZy9kYy9lbGVtZW50cy8xLjEvIgogICAgeG1sbnM6R0lNUD0iaHR0cDovL3d3dy5naW1wLm9yZy94bXAvIgogICAgeG1sbnM6dGlmZj0iaHR0cDovL25zLmFkb2JlLmNvbS90aWZmLzEuMC8iCiAgICB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iCiAgIHhtcE1NOkRvY3VtZW50SUQ9ImdpbXA6ZG9jaWQ6Z2ltcDplZjBhMzc3Yi0wZDI4LTQwZWEtOTBkMi1kZmZhNDQ2NzdjYmUiCiAgIHhtcE1NOkluc3RhbmNlSUQ9InhtcC5paWQ6YThmNzI2MjItMDY1Yy00NTM2LTlkMTctOTU3ZDZmMWJiODE1IgogICB4bXBNTTpPcmlnaW5hbERvY3VtZW50SUQ9InhtcC5kaWQ6NDY4NjQzNWItMWY0MS00MmQ4LWI2ZDgtZjYyZTEwODhiZDcwIgogICBkYzpGb3JtYXQ9ImltYWdlL3BuZyIKICAgR0lNUDpBUEk9IjIuMCIKICAgR0lNUDpQbGF0Zm9ybT0iTGludXgiCiAgIEdJTVA6VGltZVN0YW1wPSIxNzc4NDg0NTY3NTM1MjEwIgogICBHSU1QOlZlcnNpb249IjIuMTAuMzYiCiAgIHRpZmY6T3JpZW50YXRpb249IjEiCiAgIHhtcDpDcmVhdG9yVG9vbD0iR0lNUCAyLjEwIgogICB4bXA6TWV0YWRhdGFEYXRlPSIyMDI2OjA1OjExVDA5OjI5OjI3KzAyOjAwIgogICB4bXA6TW9kaWZ5RGF0ZT0iMjAyNjowNToxMVQwOToyOToyNyswMjowMCI+CiAgIDx4bXBNTTpIaXN0b3J5PgogICAgPHJkZjpTZXE+CiAgICAgPHJkZjpsaQogICAgICBzdEV2dDphY3Rpb249InNhdmVkIgogICAgICBzdEV2dDpjaGFuZ2VkPSIvIgogICAgICBzdEV2dDppbnN0YW5jZUlEPSJ4bXAuaWlkOjE0Yjc3ZjU1LTBhOTQtNDY1OC1iZDZjLWY0ODVkZjNhOGY0ZSIKICAgICAgc3RFdnQ6c29mdHdhcmVBZ2VudD0iR2ltcCAyLjEwIChMaW51eCkiCiAgICAgIHN0RXZ0OndoZW49IjIwMjYtMDUtMTFUMDk6Mjk6MjcrMDI6MDAiLz4KICAgIDwvcmRmOlNlcT4KICAgPC94bXBNTTpIaXN0b3J5PgogIDwvcmRmOkRlc2NyaXB0aW9uPgogPC9yZGY6UkRGPgo8L3g6eG1wbWV0YT4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgIAo8P3hwYWNrZXQgZW5kPSJ3Ij8+jCyuRQAAAAZQTFRFAAAA////pdmf3QAAAAlwSFlzAAALEwAACxMBAJqcGAAAAAd0SU1FB+oFCwcdGxSsKUAAAAJDSURBVDjLrdSxjtNAEADQ8eXEXRGRSCAhROEUSJTUCMHmToDo+Ag6PoAO1jkKBMWZks7iDyipcOAQKZ0/cCIXoYsDInHO6x1mZmNua0QKy0/ZnZ3dnTGg94P/AwguMFMY/8UB4raFUfTQO8z9AK99hB5kSovKX3TuY+LepiFDFkcLPYYLZkARrAv2AzTBaME44AAusn034GErQdWPeNgvwWpP5iwc9mWOW3PWV4w40ukIR4MOI5ljusDhUBCuUC1xGB0wVInh0hzDpkGwqrJhZh5QngRd2V5eHUJoEYw2L+O86nPuYNC8iJPZgNbUgkk6HdJ2NGzR3tshZdydqHFEeQpuFPoI+DSBdnCl0HtwGTFnXJvZfejscFCaLmXmEJeUgKAgbKs+p7YE2nW2LQe0jEPOwBZYDlW6Ax0nJ+CBnguHN1IiO5zwcbSQ9xZB4OErhN4wTqDFNxnm1rE3fTyOHTZ87ady/RlvDpsMPTzBqOP9U5S87ZpQJ1hQbSR0iGg6GguqGsFinWNB9ZRAg/j+eSZQdCX4sXub0CNYxE+HS0JsBdlZItBAdT+l3RCMQJ3eElBRpCbvXWdUjOZ+eJVDbwl5/Vm9ZawIy7qERwRVMM4Rv2vKbUHYEB7qwlBJAtZrtB/0LKA2AGzWiEeadiqN8RNxRLdjuciR5jwlGC1Iz0+0NBhD/z7mMhfU6tklwpmgiaDrupVbs4Q7FCxsm3bhupXxxVDhlLt2tnw7r7zPhu21oBYqVYtKmeDigzKW2/6nL9IfSdCzoS69vcYAAAAASUVORK5CYII=}
catch {
    wm iconphoto . -default [image create photo -data $::_icon_b64]
}

wm minsize . 500 400

bind Button <FocusIn>  { %W configure -state active }
bind Button <FocusOut> { %W configure -state normal }
bind Button <Return>   { %W invoke }

# --- browser frame ------------------------------------------------------------
frame .br -bg $bg

label .br.title \
    -text " Writhdeck" \
    -bg $bg -fg $fg \
    -font [list [lindex $font 0] 15 bold] \
    -anchor w -pady 10 -padx 4
pack .br.title -fill x

frame .br.mid -bg $bg
text .br.mid.lst \
    -bg $bg -fg $fg -font $font \
    -borderwidth 0 -highlightthickness 0 \
    -yscrollcommand {.br.mid.sb set} -wrap none -state disabled
lassign [theme-colors] _ _ _ _ _ _ c_comment _
set header_font [list [lindex $::font 0] [lindex $::font 1] bold]
.br.mid.lst tag configure header -foreground $c_comment -font $header_font
.br.mid.lst tag configure file -foreground $fg
.br.mid.lst tag configure selected -background $bg_sel -foreground $fg

# Tabstops will be configured dynamically in br-refresh based on actual file names

scrollbar .br.mid.sb -orient vertical -command {.br.mid.lst yview} \
    -bg $bg_bar -troughcolor $bg
pack .br.mid.sb  -side right -fill y
pack .br.mid.lst -fill both  -expand 1
pack .br.mid     -fill both  -expand 1

frame .br.bar -bg $bg_bar
frame .br.bar.left -bg $bg_bar

text .br.bar.help -height 2 -width 90 -bg $bg_bar -fg $fg_bar -font $font_sm \
    -borderwidth 0 -highlightthickness 0 -padx 2 -pady 1 -wrap none -state disabled -cursor arrow
pack .br.bar.help -in .br.bar.left -side top -fill both -expand 0

.br.bar.help tag configure link -foreground $fg_bar
set _hover_bg [lindex [theme-colors] 6]
.br.bar.help tag configure link_hover -background $_hover_bg

# Build help bar with clickable shortcuts
set _shortcuts {}
foreach {char cmd key} {
    h help-dialog br_key_help
    n br-new br_key_new
    t open-scratchpad br_key_scratchpad
    f br-toggle-favorite br_key_fav
    s br-stats br_key_stats
    b br-backup br_key_backup
    d br-delete br_key_delete
    r br-rename br_key_rename
    i br-info-shortcut br_key_info
    w word-occurrences-dialog br_key_words
    c profile-config-dialog br_key_config
    z br-reload br_key_reload
    q quit-app br_key_quit
} {
    set label "$char:[t $key]"
    lappend _shortcuts [list $label $cmd]
}
lappend _shortcuts [list "$::cfg_lbl_toc:[t br_key_sections]" "toc-dialog"]

# Populate the help bar with clickable links
.br.bar.help configure -state normal
.br.bar.help delete 1.0 end
set _idx 0
foreach item $_shortcuts {
    lassign $item label cmd
    if {$_idx == 7} {
        .br.bar.help insert end "\n"
    }
    set start [.br.bar.help index end-1c]
    .br.bar.help insert end "$label  "
    set end [.br.bar.help index end-3c]
    set tag_name "link_$_idx"
    .br.bar.help tag add $tag_name $start $end
    .br.bar.help tag bind $tag_name <Enter> [list .br.bar.help tag add link_hover $start $end]
    .br.bar.help tag bind $tag_name <Leave> [list .br.bar.help tag remove link_hover $start $end]
    .br.bar.help tag bind $tag_name <Button-1> [list $cmd]
    .br.bar.help tag bind $tag_name <Motion> [list .br.bar.help configure -cursor hand2]
    incr _idx
}
.br.bar.help configure -state disabled

label .br.bar.cnt -textvariable ::br_status \
    -bg $bg_bar -fg $fg_bar -font $font_sm -anchor e -padx 8 -pady $bar_pady
pack .br.bar.left -side left
pack .br.bar.cnt  -side right
pack .br.bar -side bottom -fill x
if {$::cfg_bar_height > 0} {
    .br.bar configure -height [expr {$::cfg_bar_height * 2}]
    pack propagate .br.bar 0
} else {
    pack propagate .br.bar 1
}

# browser state - each entry: {type dir name}  (type = header | file | favorite | recent)
set ::br_entries {}

proc br-refresh {} {
    set prev ""
    # Get current selection from text widget
    set tags [.br.mid.lst tag ranges selected]
    if {[llength $tags]} {
        set idx [lindex $tags 0]
        set line [expr {int($idx)}]
        if {$line > 0 && $line <= [llength $::br_entries]} {
            lassign [lindex $::br_entries [expr {$line - 1}]] type dir name
            if {$type in {file recent favorite}} { set prev "$dir|$name" }
        }
    }

    set ::state_cache_valid 0
    set ::br_entries {}
    set total 0
    set shown {}
    foreach dir [br-dirs] {
        foreach f [list-docs $dir] { lappend shown [file join $dir $f] }
    }
    foreach e [build-extra-entries $shown] { lappend ::br_entries $e }
    foreach dir [br-dirs] {
        lappend ::br_entries [list header $dir ""]
        foreach f [list-docs $dir] {
            lappend ::br_entries [list file $dir $f]
            incr total
        }
    }

    # Calculate tab positions based on longest filename
    set max_name_len 0
    foreach e $::br_entries {
        lassign $e type dir name
        if {$type ni {file recent favorite}} continue
        set name_len [string length $name]
        if {$name_len > $max_name_len} { set max_name_len $name_len }
    }

    # Calculate tabstops: 2 spaces indent + max filename length + 2 spaces gap
    set char_width [font measure $::font "W"]
    set tab1 [expr {int((2 + $max_name_len + 2) * $char_width)}]
    set tab2 [expr {int($tab1 + 10 * $char_width)}]
    .br.mid.lst configure -tabs [list $tab1 $tab2] -tabstyle wordprocessor

    .br.mid.lst configure -state normal
    .br.mid.lst delete 1.0 end
    set new_sel -1
    set first_file -1
    set prev_type ""
    array unset ::br_line_to_entry
    set current_line 1
    for {set i 0} {$i < [llength $::br_entries]} {incr i} {
        lassign [lindex $::br_entries $i] type dir name
        if {$type eq "header"} {
            # Add blank line before header (except first)
            if {$prev_type ne ""} {
                .br.mid.lst insert end "\n"
                incr current_line
            }
            set label [expr {$name ne "" ? $name : [string map [list $::HOME_DIR ~] $dir]}]
            .br.mid.lst insert end " $label\n" header
            set ::br_line_to_entry($current_line) $i
            incr current_line
            set prev_type "header"
        } else {
            set meta [fmt-meta [file join $dir $name]]
            .br.mid.lst insert end "  $name\t$meta\n" file
            set ::br_line_to_entry($current_line) $i
            incr current_line
            set prev_type "file"
            if {$first_file < 0} { set first_file $i }
            if {"$dir|$name" eq $prev} { set new_sel $i }
        }
    }
    .br.mid.lst configure -state disabled

    set s [expr {$total != 1 ? "s" : ""}]
    set ::br_status " [t br_files $total $s] "

    if {$new_sel < 0} { set new_sel $first_file }
    if {$new_sel >= 0} {
        # Find the text line corresponding to this br_entries index
        set text_line ""
        foreach line [array names ::br_line_to_entry] {
            if {$::br_line_to_entry($line) == $new_sel} {
                set text_line $line
                break
            }
        }
        if {$text_line ne ""} {
            .br.mid.lst tag remove selected 1.0 end
            .br.mid.lst tag add selected ${text_line}.0 ${text_line}.end
            .br.mid.lst see ${text_line}.0
        }
    }
}

# returns {type dir name} of selected entry, or {} if none/header
proc br-selected {} {
    set tags [.br.mid.lst tag ranges selected]
    if {![llength $tags]} { return {} }
    set idx [lindex $tags 0]
    set line [expr {int($idx)}]
    # Use the mapping from text line to br_entries index
    if {![info exists ::br_line_to_entry($line)]} { return {} }
    set entry_idx $::br_line_to_entry($line)
    if {$entry_idx < 0 || $entry_idx >= [llength $::br_entries]} { return {} }
    set e [lindex $::br_entries $entry_idx]
    if {[lindex $e 0] ni {file recent favorite}} { return {} }
    return $e
}

# returns the dir of the section containing the current selection
proc br-active-dir {} {
    set tags [.br.mid.lst tag ranges selected]
    set line [expr {[llength $tags] ? int([lindex $tags 0]) : 1}]
    # Use the mapping to get the correct entry index
    if {![info exists ::br_line_to_entry($line)]} {
        set i 0
    } else {
        set i $::br_line_to_entry($line)
    }
    while {$i >= 0} {
        lassign [lindex $::br_entries $i] type dir
        if {$type eq "header"} { return [expr {$dir ne "" ? $dir : $::DOCS_DIR_DEFAULT}] }
        incr i -1
    }
    return $::DOCS_DIR_DEFAULT
}

proc br-open {} {
    set e [br-selected]
    if {![llength $e]} return
    show-editor [file join [lindex $e 1] [lindex $e 2]]
}

proc br-info-shortcut {} {
    set e [br-selected]
    if {[llength $e]} {
        set fpath [file join [lindex $e 1] [lindex $e 2]]
        file-info-dialog $fpath
    }
}

# --- browser dialogs ----------------------------------------------------------
proc input-dialog {title prompt} {
    set w .dlg
    catch {destroy $w}
    toplevel $w
    wm title $w $title
    wm resizable $w 0 0
    wm transient $w .

    label  $w.l   -text $prompt -font $::font_sm -padx 12 -pady 8 -anchor w
    entry  $w.e   -width 28    -font $::font_sm
    frame  $w.f
    button $w.f.ok -text "OK"           -font $::font_sm -command {set ::dlg_val [.dlg.e get]; destroy .dlg}
    button $w.f.cn -text [t dlg_cancel] -font $::font_sm -command {set ::dlg_val ""; destroy .dlg}
    pack $w.f.ok $w.f.cn -side left -padx 4 -pady 6

    pack $w.l -fill x
    pack $w.e -fill x -padx 12
    pack $w.f
    update
    grab $w

    bind $w.e <Return> {set ::dlg_val [.dlg.e get]; destroy .dlg}
    bind $w    <Escape> {set ::dlg_val ""; destroy .dlg}
    focus $w.e

    set ::dlg_val ""
    tkwait window $w
    return $::dlg_val
}

proc info-dialog {msg} {
    set w .idlg
    catch {destroy $w}
    toplevel $w
    wm title $w "Writhdeck"
    wm resizable $w 0 0
    wm transient $w .
    text $w.t -font $::font_sm -padx 16 -pady 12 -wrap word -width 50 -height 3 \
        -relief flat -bg [$w cget -bg] -fg $::fg -bd 0 -highlightthickness 0 -cursor arrow
    $w.t insert end $msg
    $w.t configure -state disabled
    button $w.b -text "OK" -font $::font_sm -command [list destroy $w]
    pack $w.t -fill x
    pack $w.b -anchor e -padx 8 -pady 6
    bind $w <Return> [list destroy $w]
    bind $w <Escape> [list destroy $w]
    update
    grab $w
    focus $w.b
    tkwait window $w
}

proc file-info-dialog {fpath} {
    if {![file exists $fpath]} {
        info-dialog "File not found: $fpath"
        return
    }

    set w .fidlg
    catch {destroy $w}
    toplevel $w
    wm title $w "File Info"
    wm transient $w .
    wm minsize $w 450 180

    set size [file size $fpath]
    set mtime [file mtime $fpath]
    set atime [file atime $fpath]
    set mdate [clock format $mtime -format "%Y-%m-%d %H:%M:%S"]
    set adate [clock format $atime -format "%Y-%m-%d %H:%M:%S"]

    set size_str [expr {$size > 1024*1024 ? [format "%.1f MB" [expr {$size / (1024.0*1024)}]] : ($size > 1024 ? [format "%.1f KB" [expr {$size / 1024.0}]] : "$size bytes")}]

    frame $w.info -bg $::bg
    label $w.info.l1 -text "Path:" -font $::font_sm -bg $::bg -fg $::fg -anchor w
    label $w.info.v1 -text "[string map [list $::HOME_DIR ~] $fpath]" -font $::font_sm -bg $::bg -fg $::fg -anchor w -wraplength 350

    label $w.info.l2 -text "Size:" -font $::font_sm -bg $::bg -fg $::fg -anchor w
    label $w.info.v2 -text "$size_str" -font $::font_sm -bg $::bg -fg $::fg -anchor w

    label $w.info.l3 -text "Modified:" -font $::font_sm -bg $::bg -fg $::fg -anchor w
    label $w.info.v3 -text "$mdate" -font $::font_sm -bg $::bg -fg $::fg -anchor w

    label $w.info.l4 -text "Accessed:" -font $::font_sm -bg $::bg -fg $::fg -anchor w
    label $w.info.v4 -text "$adate" -font $::font_sm -bg $::bg -fg $::fg -anchor w

    grid $w.info.l1 -row 0 -column 0 -sticky nw -padx 8 -pady 4
    grid $w.info.v1 -row 0 -column 1 -sticky nw -padx 8 -pady 4
    grid $w.info.l2 -row 1 -column 0 -sticky nw -padx 8 -pady 4
    grid $w.info.v2 -row 1 -column 1 -sticky nw -padx 8 -pady 4
    grid $w.info.l3 -row 2 -column 0 -sticky nw -padx 8 -pady 4
    grid $w.info.v3 -row 2 -column 1 -sticky nw -padx 8 -pady 4
    grid $w.info.l4 -row 3 -column 0 -sticky nw -padx 8 -pady 4
    grid $w.info.v4 -row 3 -column 1 -sticky nw -padx 8 -pady 4

    frame $w.f -bg $::bg
    button $w.f.ok -text "OK" -font $::font_sm -command [list destroy $w]
    button $w.f.stats -text "Stats" -font $::font_sm -command [list file-stats-dialog $fpath]
    button $w.f.words -text "Word Occurrences" -font $::font_sm -command [list word-occurrences-dialog $fpath]

    pack $w.info -fill both -expand 1 -padx 8 -pady 8
    pack $w.f -fill x -padx 8 -pady 6
    pack $w.f.ok $w.f.stats $w.f.words -side left -padx 4

    bind $w <Return> [list destroy $w]
    bind $w <Escape> [list destroy $w]
    update
    grab $w
    focus $w.f.ok
    tkwait window $w
}

proc word-occurrences-dialog {fpath} {
    if {![file exists $fpath]} return

    set w .wodlg
    catch {destroy $w}
    toplevel $w
    wm title $w "Word Occurrences"
    wm geometry $w 400x500
    wm transient $w .

    set word_data [get-word-occurrences $fpath]
    if {[llength $word_data] == 0} {
        info-dialog "No words to display"
        return
    }

    catch {
        frame $w.f
        listbox $w.f.lb -font [list [lindex $::font 0] 9] -yscrollcommand [list $w.f.sb set] -width 50 -height 20
        scrollbar $w.f.sb -orient vertical -command [list $w.f.lb yview]

        foreach pair $word_data {
            lassign $pair word count
            $w.f.lb insert end [format "%-30s %6d" $word $count]
        }

        pack $w.f.sb -side right -fill y
        pack $w.f.lb -side left -fill both -expand 1
        pack $w.f -fill both -expand 1 -padx 8 -pady 8

        frame $w.btns
        button $w.btns.ok -text "Close" -font $::font_sm -command [list destroy $w]
        pack $w.btns.ok -padx 8 -pady 6
        pack $w.btns -fill x
    }

    update
    grab $w
    focus $w.f.lb
}

proc file-stats-dialog {fpath} {
    if {![file exists $fpath]} return

    set e [list file [file dirname $fpath] [file tail $fpath]]
    if {[llength $e]} {
        lassign $e _ dir name
        set path [file join $dir $name]
        if {!$::state_cache_valid} { state-load }
        if {![dict exists $::daily_data $path] || [dict size [dict get $::daily_data $path]] == 0} {
            info-dialog "No statistics available for this file"
            return
        }
        set fdata [dict get $::daily_data $path]
        set msg "Daily writing stats for: [string map [list $::HOME_DIR ~] $path]\n\n"
        append msg "Date          Words\n"
        append msg "----          -----\n"
        foreach date [lsort -decreasing [dict keys $fdata]] {
            append msg [format "%-14s %5d\n" $date [dict get $fdata $date]]
        }
        info-dialog $msg
    }
}


proc confirm-dialog {msg {default yes}} {
    set w .cdlg
    catch {destroy $w}
    toplevel $w
    wm title $w "Writhdeck"
    wm resizable $w 0 0
    wm transient $w .
    label  $w.l   -text $msg -font $::font_sm -padx 16 -pady 12 -anchor w -wraplength 340
    frame  $w.f
    button $w.f.y -text [t dlg_yes] -font $::font_sm \
        -command {set ::dlg_val yes; destroy .cdlg}
    button $w.f.n -text [t dlg_no]  -font $::font_sm \
        -command {set ::dlg_val no;  destroy .cdlg}
    pack $w.f.y $w.f.n -side left -padx 4 -pady 6
    pack $w.l -fill x
    pack $w.f -anchor e -padx 8
    bind $w <Return> { catch { [focus] invoke } }
    bind $w <Escape> { set ::dlg_val no; destroy .cdlg }
    bind $w y        { set ::dlg_val yes; destroy .cdlg }
    bind $w n        { set ::dlg_val no;  destroy .cdlg }
    update
    grab $w
    if {$default eq "yes"} { focus $w.f.y } else { focus $w.f.n }
    set ::dlg_val no
    tkwait window $w
    return $::dlg_val
}

proc yesnocancel-dialog {msg} {
    set w .yncdlg
    catch {destroy $w}
    toplevel $w
    wm title $w "Writhdeck"
    wm resizable $w 0 0
    wm transient $w .
    label  $w.l   -text $msg -font $::font_sm -padx 16 -pady 12 -anchor w -wraplength 340
    frame  $w.f
    button $w.f.y -text [t dlg_yes]    -font $::font_sm \
        -command {set ::dlg_val yes;    destroy .yncdlg}
    button $w.f.n -text [t dlg_no]     -font $::font_sm \
        -command {set ::dlg_val no;     destroy .yncdlg}
    button $w.f.c -text [t dlg_cancel] -font $::font_sm \
        -command {set ::dlg_val cancel; destroy .yncdlg}
    pack $w.f.y $w.f.n $w.f.c -side left -padx 4 -pady 6
    pack $w.l -fill x
    pack $w.f -anchor e -padx 8
    bind $w <Return> { catch { [focus] invoke } }
    bind $w <Escape> { set ::dlg_val cancel; destroy .yncdlg }
    update
    grab $w
    bind $w y        { set ::dlg_val yes;    destroy .yncdlg }
    bind $w n        { set ::dlg_val no;     destroy .yncdlg }
    after idle [list focus $w.f.y]
    set ::dlg_val cancel
    tkwait window $w
    return $::dlg_val
}

proc br-new {} {
    set dir  [br-active-dir]
    set name [input-dialog "New file" "File name:"]
    set name [string trim $name]
    if {$name eq ""} return
    if {[file extension $name] eq ""} { append name $::FILE_EXT }
    set full [file join $dir $name]
    if {[file exists $full]} {
        info-dialog [t br_exists $name]
        return
    }
    close [open $full w]
    show-editor $full
}

proc br-delete {} {
    set e [br-selected]
    if {![llength $e]} return
    lassign $e _ dir name
    if {[confirm-dialog [t br_delete $name]] eq "yes"} {
        set full [file join $dir $name]
        file delete $full
        recent-remove $full
        br-refresh
    }
}

proc br-rename {} {
    set e [br-selected]
    if {![llength $e]} return
    lassign $e _ dir name
    set new [input-dialog "Rename" "Rename \"$name\" to:"]
    set new [string trim $new]
    if {$new eq ""} return
    if {[file extension $new] eq ""} { append new $::FILE_EXT }
    set new_path [file join $dir $new]
    if {[file exists $new_path]} {
        info-dialog [t br_exists $new]
        return
    }
    set old_path [file join $dir $name]
    file rename $old_path $new_path
    recent-rename $old_path $new_path
    br-refresh
}

proc br-reload {} {
    set exe      [info nameofexecutable]
    set script   $::argv0
    # when compiled (tclexecomp etc.), argv0 IS the binary — don't pass it as a script arg
    set compiled [expr {[file normalize $script] eq [file normalize $exe]}]

    if {$::tcl_platform(platform) eq "windows"} {
        if {$compiled} {
            catch {exec cmd /c "start \"\" \"$exe\"" >@1 2>@1}
        } else {
            catch {exec cmd /c "start \"\" \"$exe\" \"$script\"" >@1 2>@1}
        }
    } else {
        if {$compiled} {
            catch {exec sh -c "exec \"$exe\" >/dev/null 2>&1 &"}
        } else {
            catch {exec sh -c "exec \"$exe\" \"$script\" >/dev/null 2>&1 &"}
        }
    }

    after 200 exit
}

proc br-backup {} {
    set e [br-selected]
    if {![llength $e]} return
    lassign $e _ dir name
    set dst [do-backup $dir $name]
    info-dialog [t br_backed_up $name [string map [list $::HOME_DIR ~] [file dirname $dst]] [file tail $dst]]
}

proc br-toggle-favorite {} {
    set e [br-selected]
    if {![llength $e]} return
    toggle-favorite [file join [lindex $e 1] [lindex $e 2]]
    br-refresh
}

proc br-stats {{path ""}} {
    if {$path eq ""} {
        set e [br-selected]
        if {![llength $e]} return
        set path [file join [lindex $e 1] [lindex $e 2]]
    }
    if {!$::state_cache_valid} { state-load }
    if {![dict exists $::daily_data $path] || [dict size [dict get $::daily_data $path]] == 0} {
        info-dialog [t br_stats_no_data]
        return
    }
    set fdata [dict get $::daily_data $path]
    set nrows [dict size $fdata]
    set w .stats
    catch {destroy $w}
    toplevel $w
    wm title $w "[t br_stats_title] - [file tail $path]"
    wm resizable $w 0 0
    wm transient $w .
    text $w.t -font $::font_sm -state normal -bg $::bg -fg $::fg \
        -borderwidth 0 -padx 16 -pady 12 -width 36 \
        -height [expr {$nrows + 7}] -cursor arrow
    $w.t tag configure heading -foreground $::fg_bar -font [concat $::font_sm bold]
    $w.t insert end "\n  [file tail $path]\n" heading
    $w.t insert end [format "\n  %-14s %s\n" "Date" "Words"] heading
    set today [clock format [clock seconds] -format "%Y-%m-%d"]
    set grand_total 0
    foreach date [lsort -decreasing [dict keys $fdata]] {
        set n [dict get $fdata $date]
        incr grand_total $n
        set lbl [expr {$date eq $today ? "$date  <- [t br_stats_today]" : $date}]
        $w.t insert end [format "  %-26s %d\n" $lbl $n]
    }
    $w.t insert end "\n"
    $w.t insert end [format "  %-26s %d\n" [t br_stats_total] $grand_total] heading
    $w.t configure -state disabled
    frame $w.btns
    button $w.btns.ok    -text "Close"           -font $::font_sm \
        -command [list after idle [list destroy $w]]
    button $w.btns.clear -text [t br_stats_clear] -font $::font_sm \
        -command [list apply {{w path} {
            if {[confirm-dialog [t br_stats_clear_confirm [file tail $path]]] eq "yes"} {
                daily-clear $path
                after idle [list destroy $w]
            }
        }} $w $path]
    pack $w.btns.clear -side left  -padx 8 -pady 8
    pack $w.btns.ok    -side right -padx 8 -pady 8
    pack $w.t    -fill both -expand 1
    pack $w.btns -fill x
    update
    grab $w
    bind $w.t <KeyPress-q> "[list after idle [list destroy $w]]; break"
    bind $w.t <Control-h>  "[list after idle [list destroy $w]]; break"
    bind $w   <Control-h>  [list after idle [list destroy $w]]
    focus $w.t
}

bind .br.mid.lst <Return>      { br-open }
bind .br.mid.lst <Double-1>    { br-open }
bind .br.mid.lst <n>           { br-new }
bind .br.mid.lst <t>           { open-scratchpad }
bind .br.mid.lst <f>           { br-toggle-favorite }
bind .br.mid.lst <s>           { br-stats }
bind .br.mid.lst <b>           { br-backup }
bind .br.mid.lst <d>           { br-delete }
bind .br.mid.lst <r>           { br-rename }
bind .br.mid.lst <i>           { set e [br-selected]; if {[llength $e]} { file-info-dialog [file join [lindex $e 1] [lindex $e 2]] } }
bind .br.mid.lst <w>           { set e [br-selected]; if {[llength $e]} { word-occurrences-dialog [file join [lindex $e 1] [lindex $e 2]] } }
bind .br.mid.lst <c>           { profile-config-dialog }
bind .br.mid.lst <q>           { quit-app }
bind .br.mid.lst <z>           { br-reload }

proc br-select-line {line_offset} {
    set tags [.br.mid.lst tag ranges selected]
    set current_line [expr {[llength $tags] ? int([lindex $tags 0]) : 1}]
    set new_line [expr {$current_line + $line_offset}]
    set text_lines [expr {int([.br.mid.lst index end])}]

    # Skip headers and empty lines
    while {$new_line > 0 && $new_line < $text_lines} {
        set line_content [string trim [.br.mid.lst get ${new_line}.0 ${new_line}.end]]
        set line_tags [.br.mid.lst tag names ${new_line}.0]
        # Check if line is empty or is a header
        if {$line_content eq "" || "header" in $line_tags} {
            incr new_line $line_offset
        } else {
            break
        }
    }

    if {$new_line > 0 && $new_line < $text_lines} {
        .br.mid.lst tag remove selected 1.0 end
        .br.mid.lst tag add selected ${new_line}.0 ${new_line}.end
        .br.mid.lst see ${new_line}.0
    }
}

bind .br.mid.lst <Up> {
    br-select-line -1
    break
}
bind .br.mid.lst <Down> {
    br-select-line 1
    break
}

bind .br.mid.lst <Motion> {
    set line [expr {int([.br.mid.lst index @%x,%y])}]
    set line_content [string trim [.br.mid.lst get ${line}.0 ${line}.end]]
    set line_tags [.br.mid.lst tag names ${line}.0]
    # Show hand cursor for files, normal arrow for headers/empty
    if {$line_content ne "" && "header" ni $line_tags} {
        .br.mid.lst configure -cursor hand2
    } else {
        .br.mid.lst configure -cursor arrow
    }
}

bind .br.mid.lst <Button-1> {
    set line [expr {int([.br.mid.lst index @%x,%y])}]
    if {[info exists ::br_line_to_entry($line)]} {
        set entry_idx $::br_line_to_entry($line)
        set e [lindex $::br_entries $entry_idx]
        if {[lindex $e 0] ni {file recent favorite}} {
            break
        }
        .br.mid.lst tag remove selected 1.0 end
        .br.mid.lst tag add selected ${line}.0 ${line}.end
        focus .br.mid.lst
    }
    break
}

# --- editor frame -------------------------------------------------------------
frame .ed -bg $bg2

text .ed.t \
    -wrap word -font $font \
    -bg $bg -fg $fg \
    -insertbackground $fg \
    -selectbackground $bg_sel -selectforeground $fg \
    -blockcursor 0 \
    -insertwidth [expr {$::cfg_block_cursor_gui ? 0 : 2}] \
    -insertofftime [expr {$::cfg_block_cursor_gui ? 0 : ($::cfg_blink_cursor ? 300 : 0)}] \
    -borderwidth 0 -highlightthickness 0 \
    -padx [expr {$::cfg_margin_width/3}] \
    -pady [expr {$::cfg_margin_height/3}] \
    -undo 1

scrollbar .ed.sb -orient vertical -command {.ed.t yview} \
    -bg $bg_bar -troughcolor $bg

proc ed-yscroll {first last} {
    .ed.sb set $first $last
    catch { .ed.ln yview moveto $first }
}
.ed.t configure -yscrollcommand ed-yscroll
after idle apply-line-spacing
.ed.t tag configure heading \
    -foreground $::cfg_color_heading \
    -font [list $::cfg_font_family $::cfg_font_size bold]
.ed.t tag configure comment \
    -foreground $::cfg_color_comment
.ed.t tag configure bold \
    -foreground $::cfg_color_markup \
    -font [list $::cfg_font_family $::cfg_font_size bold]
.ed.t tag configure italic \
    -foreground $::cfg_color_markup \
    -font [list $::cfg_font_family $::cfg_font_size italic]
.ed.t tag configure underline \
    -foreground $::cfg_color_markup \
    -underline 1
.ed.t tag configure strikethrough \
    -foreground $::cfg_color_comment \
    -overstrike 0
.ed.t tag configure marker \
    -foreground $::cfg_color_comment
.ed.t tag raise marker

frame .ed.bar -bg $bg_bar
label .ed.bar.left   -textvariable ::ed_bar_left \
    -bg $bg_bar -fg $fg_bar -font $font_sm -anchor w -padx 8 -pady $bar_pady
label .ed.bar.msg    -textvariable ::ed_msg \
    -bg $bg_bar -fg $fg_bar -font $font_sm -anchor center -width 10 -pady $bar_pady
label .ed.bar.center -textvariable ::ed_bar_center \
    -bg $bg_bar -fg $fg_bar -font $font_sm -anchor center -pady $bar_pady
label .ed.bar.right  -textvariable ::ed_bar_right \
    -bg $bg_bar -fg $fg_bar -font $font_sm -anchor e -padx 8 -pady $bar_pady
set _helpzone [status-zone-of help_bar]
if {$::cfg_help_bar ne "" && $_helpzone ne ""} {
    set _ha [expr {$_helpzone eq "right" ? "e" : ($_helpzone eq "center" ? "center" : "w")}]
    label .ed.bar.help -text $::cfg_help_bar \
        -bg $bg_bar -fg $fg_bar -font $font_sm -anchor $_ha -padx 8 -pady $bar_pady
    unset _ha
}
pack .ed.bar.left  -side left
if {[winfo exists .ed.bar.help] && [status-zone-of help_bar] eq "left"} {
    pack .ed.bar.help -side left
}
pack .ed.bar.right -side right
if {[winfo exists .ed.bar.help] && [status-zone-of help_bar] eq "right"} {
    pack .ed.bar.help -side right
}
pack .ed.bar.msg   -side right
if {[winfo exists .ed.bar.help] && [status-zone-of help_bar] eq "center"} {
    pack .ed.bar.help -fill x -expand 1
}
pack .ed.bar.center -fill x -expand 1
pack .ed.bar -side bottom -fill x
if {$::cfg_bar_height > 0} {
    .ed.bar configure -height $::cfg_bar_height
    pack propagate .ed.bar 0
}
unset _helpzone
pack .ed.sb  -side right  -fill y
if {$::cfg_line_numbers} {
    text .ed.ln \
        -width 4 -font $font \
        -bg $bg_bar -fg $fg_dim \
        -state disabled -borderwidth 0 \
        -padx 4 -pady $::cfg_margin_height \
        -highlightthickness 0 -wrap none \
        -cursor arrow
    pack .ed.ln -side left -fill y
}
pack .ed.t -fill both -expand 1 \
    -padx [expr {$::cfg_margin_width - $::cfg_margin_width/3}] \
    -pady [expr {$::cfg_margin_height - $::cfg_margin_height/3}]
after idle cursor-setup

# --- search bar (hidden until Ctrl+F) ----------------------------------------
set ::search_term  ""
set ::search_count ""
set ::search_ed    ".ed.t"
set ::toc_ed       ".ed.t"

frame .ed.sf -bg $bg_bar
label .ed.sf.lbl -text " Find: " -bg $bg_bar -fg $fg_bar -font $font_sm
entry .ed.sf.e   -bg $bg -fg $fg -font $font_sm -insertbackground $fg \
    -relief flat -bd 1 -width 32 -highlightthickness 0
label .ed.sf.cnt -textvariable ::search_count \
    -bg $bg_bar -fg $fg_bar -font $font_sm -width 14 -anchor w
pack .ed.sf.lbl -side left
pack .ed.sf.e   -side left -padx 4
pack .ed.sf.cnt -side left

frame .ed.sf.r -bg $bg_bar
label  .ed.sf.r.lbl -text " Replace: " -bg $bg_bar -fg $fg_bar -font $font_sm
entry  .ed.sf.r.e   -bg $bg -fg $fg -font $font_sm -insertbackground $fg \
    -relief flat -bd 1 -width 32 -highlightthickness 0
button .ed.sf.r.one -text " Replace " -bg $bg_bar -fg $fg_bar -font $font_sm \
    -relief flat -command replace-one -padx 2
button .ed.sf.r.all -text " All " -bg $bg_bar -fg $fg_bar -font $font_sm \
    -relief flat -command replace-all -padx 2
pack .ed.sf.r.lbl -side left
pack .ed.sf.r.e   -side left -padx 4
pack .ed.sf.r.one -side left
pack .ed.sf.r.all -side left

# --- editor status ------------------------------------------------------------
set ::wc_after_id ""
set ::gui_wc 0
set ::gui_cc 0
set ::gui_wc_line_cache  {}
set ::gui_wc_last_nlines 0
set ::ed_bar_left   ""
set ::ed_bar_center ""
set ::ed_bar_right  ""
set ::status_update_pending 0
set ::hl_after_id ""
set ::ln_last_count 0

proc gui-status-state {} {
    set t [active-ed]
    set clk [clock format [clock seconds] -format "%H:%M"]
    set timer_display [expr {$::cfg_timer_duration * 60}]
    if {$::timer_active} { set timer_display $::timer_remaining; timer-tick }
    if {$::split_ws2_mode && $t eq ".ed.pw.r.t"} {
        set fn [expr {$::ws2_scratchpad ? "** scratchpad **" : \
                     ($::ws2_filename eq "" ? "\[new\]" : [file tail $::ws2_filename])}]
        lassign [split [$t index insert] .] ln col
        set total [expr {[lindex [split [$t index end] .] 0] - 1}]
        return [dict create fn $fn dirty $::ws2_dirty sel 0 ln $ln total $total \
                    col [expr {$col+1}] words $::gui_wc chars $::gui_cc \
                    clock $clk timer $timer_display]
    }
    set fn [expr {$::scratchpad ? "** scratchpad **" : \
                 ($::filename eq "" ? "\[new\]" : [file tail $::filename])}]
    lassign [split [$t index insert] .] ln col
    set total [expr {[lindex [split [$t index end] .] 0] - 1}]
    return [dict create fn $fn dirty $::dirty sel 0 ln $ln total $total \
                col [expr {$col+1}] words $::gui_wc chars $::gui_cc \
                clock $clk timer $timer_display]
}

proc gui-status-update {} {
    if {$::gui_cmd_mode} {
        set ::ed_bar_left ""
        set ::ed_bar_center "$::cfg_lbl_cmd_mode: exit mode  t: timer  q: quit  s: stats  w: words"
        set ::ed_bar_right ""
        return
    }
    set state [gui-status-state]
    set ::ed_bar_left   " [status-build $::cfg_status_left   $state]"
    set ::ed_bar_center [status-build $::cfg_status_center $state]
    set ::ed_bar_right  "[status-build $::cfg_status_right  $state] "
}

proc wc-flush {} {
    if {$::wc_after_id ne ""} { after cancel $::wc_after_id }
    set ::wc_after_id ""
    set t [active-ed]
    set nlines [expr {[lindex [split [$t index end] .] 0] - 1}]
    set ::gui_cc [expr {[$t count -chars 1.0 end] - 1}]
    if {$nlines != $::gui_wc_last_nlines || $::gui_wc_line_cache eq {}} {
        set text [$t get 1.0 end-1c]
        set ::gui_wc 0
        set ::gui_wc_line_cache {}
        set lnum 1
        foreach ln_text [split $text \n] {
            set wc [llength [regexp -all -inline {\S+} $ln_text]]
            dict set ::gui_wc_line_cache $lnum $wc
            incr ::gui_wc $wc
            incr lnum
        }
        set ::gui_wc_last_nlines $nlines
    } else {
        lassign [split [$t index insert] .] cy _
        set ln_text [$t get $cy.0 "$cy.0 lineend"]
        set new_wc [llength [regexp -all -inline {\S+} $ln_text]]
        set old_wc [expr {[dict exists $::gui_wc_line_cache $cy] \
                          ? [dict get $::gui_wc_line_cache $cy] : 0}]
        incr ::gui_wc [expr {$new_wc - $old_wc}]
        dict set ::gui_wc_line_cache $cy $new_wc
    }
    gui-status-update
}

proc ed-status {} {
    if {[status-zone-of words] ne "" || [status-zone-of chars] ne "" || [status-zone-of goal] ne ""} {
        if {$::wc_after_id ne ""} { after cancel $::wc_after_id }
        set ::wc_after_id [after 400 wc-flush]
    }
    cursor-update
    if {!$::status_update_pending} {
        set ::status_update_pending 1
        after idle {
            set ::status_update_pending 0
            gui-status-update
        }
    }
}

proc set-msg {text} {
    if {$::msg_after_id ne ""} { after cancel $::msg_after_id }
    set ::msg $text
    set ::ed_msg $text
    set ::msg_after_id [after 2000 {
        set ::msg_after_id ""
        set ::msg ""
        set ::ed_msg ""
        ed-status
    }]
}

proc clock-tick {} {
    catch { gui-status-update }
    after 30000 clock-tick
}
if {[status-zone-of clock] ne ""} { clock-tick }

# --- block cursor (inverted, terminal-style) ----------------------------------
set ::cursor_blink_id      ""
set ::cursor_blink_visible 1
set ::cursor_prev_pos      ""
set ::cursor_mode          ""   ;# "tag" | "block" | ""

proc cursor-update {} {
    if {!$::cfg_block_cursor_gui} return
    if {$::cursor_blink_id ne ""} { after cancel $::cursor_blink_id; set ::cursor_blink_id "" }
    set ::cursor_blink_visible 1
    catch {
        set pos [.ed.t index insert]
        set ch  [.ed.t get $pos "$pos +1c"]
        if {$ch ne "\n" && $ch ne ""} {
            if {$::cursor_mode ne "tag"} {
                .ed.t configure -blockcursor 0 -insertwidth 0 -insertofftime 0
                set ::cursor_mode "tag"
            }
            if {$::cursor_prev_pos ne ""} {
                .ed.t tag remove cur $::cursor_prev_pos "$::cursor_prev_pos +1c"
            }
            .ed.t tag add cur $pos "$pos +1c"
            set ::cursor_prev_pos $pos
        } else {
            if {$::cursor_prev_pos ne ""} {
                .ed.t tag remove cur $::cursor_prev_pos "$::cursor_prev_pos +1c"
                set ::cursor_prev_pos ""
            }
            if {$::cursor_mode ne "block"} {
                .ed.t configure -blockcursor 1 -insertwidth 0 \
                    -insertofftime 0 -insertbackground $::fg
                set ::cursor_mode "block"
            }
        }
    }
    if {$::cfg_blink_cursor} { set ::cursor_blink_id [after 600 cursor-blink-tick] }
}

proc cursor-blink-tick {} {
    set ::cursor_blink_id ""
    if {!$::cfg_block_cursor_gui || !$::cfg_blink_cursor} return
    set ::cursor_blink_visible [expr {!$::cursor_blink_visible}]
    catch {
        set ch [.ed.t get insert "insert +1c"]
        if {$ch ne "\n" && $ch ne ""} {
            if {$::cursor_blink_visible} {
                .ed.t tag configure cur -background $::fg -foreground $::bg
            } else {
                .ed.t tag configure cur -background {} -foreground {}
            }
        }
    }
    set ::cursor_blink_id [after 500 cursor-blink-tick]
}

proc cursor-setup {} {
    if {$::cursor_blink_id ne ""} { after cancel $::cursor_blink_id; set ::cursor_blink_id "" }
    set ::cursor_mode ""; set ::cursor_prev_pos ""
    catch {
        if {$::cfg_block_cursor_gui} {
            .ed.t configure -blockcursor 0 -insertwidth 0 -insertofftime 0 \
                -insertbackground $::fg
            .ed.t tag configure cur -background $::fg -foreground $::bg
            .ed.t tag raise cur
            cursor-update
        } else {
            .ed.t tag remove cur 1.0 end
            .ed.t configure -blockcursor 0 -insertwidth 2 \
                -insertofftime [expr {$::cfg_blink_cursor ? 300 : 0}]
        }
    }
}

bind .ed.t <KeyRelease>    { ed-status }
bind .ed.t <ButtonRelease> { ed-status }
bind .ed.t <<Modified>> {
    if {[.ed.t edit modified]} { set ::dirty 1; .ed.t edit modified false }
    ed-status
    if {$::hl_after_id ne ""} { after cancel $::hl_after_id }
    set ::hl_after_id [after 300 {
        set ::hl_after_id ""
        highlight-headings
        ln-update
    }]
}

proc ln-update {} {
    if {![winfo exists .ed.ln]} return
    set last [lindex [split [.ed.t index end] .] 0]
    if {$last != $::ln_last_count} {
        set ::ln_last_count $last
        set digits [string length [expr {$last - 1}]]
        .ed.ln configure -state normal -width [expr {$digits + 1}]
        .ed.ln delete 1.0 end
        set fmt "%${digits}d\n"
        for {set i 1} {$i < $last} {incr i} {
            .ed.ln insert end [format $fmt $i]
        }
        .ed.ln configure -state disabled
    }
    catch { .ed.ln yview moveto [lindex [.ed.t yview] 0] }
}

proc ln-toggle {} {
    if {[winfo exists .ed.ln]} {
        destroy .ed.ln
        set ::cfg_line_numbers 0
        set ::ln_last_count 0
    set ::gui_wc_line_cache {}
    set ::gui_wc_last_nlines 0
    } else {
        set bg_bar [.ed.bar cget -bg]
        set fg_dim [lindex [.ed.bar.left cget -fg] 0]
        text .ed.ln \
            -width 4 -font [.ed.t cget -font] \
            -bg $bg_bar -fg $fg_dim \
            -state disabled -borderwidth 0 \
            -padx 4 -pady [.ed.t cget -pady] \
            -highlightthickness 0 -wrap none \
            -cursor arrow
        if {$::split_mode} {
            # in split mode, defer line numbers until split is closed
        } else {
            pack .ed.ln -side left -fill y -before .ed.t
        }
        set ::cfg_line_numbers 1
        ln-update
    }
}

# --- file I/O -----------------------------------------------------------------
proc ed-update-title {} {
    set ws [expr {$::ws_dual_mode ? " \[$::ws_n\]" : ""}]
    if {$::scratchpad} {
        wm title . "Writhdeck - ** scratchpad **$ws"
    } elseif {$::filename ne ""} {
        wm title . "Writhdeck - [file tail $::filename]$ws"
    } else {
        wm title . "Writhdeck$ws"
    }
}

proc load-file {path} {
    set ::filename $path
    ed-update-title
    .ed.t configure -undo 0

    .ed.t delete 1.0 end
    if {[file exists $path] && [file size $path] > 0} {
        set fh [open $path r]
        chan configure $fh -encoding utf-8
        .ed.t insert 1.0 [read $fh]
        close $fh
}

    .ed.t edit reset
    .ed.t edit modified false
    catch { .ed.pw.r.t edit reset; .ed.pw.r.t edit modified false }

    .ed.t configure -undo 1
    .ed.t edit separator

    set ::dirty 0
    set ::ln_last_count 0
    set ::gui_wc_line_cache {}
    set ::gui_wc_last_nlines 0
    set ::file_mtime_known [expr {[file exists $path] ? [file mtime $path] : 0}]
    if {$::watch_after_id ne ""} { after cancel $::watch_after_id }
    set ::watch_after_id [after 2000 watch-file]
    highlight-headings
    lassign [cursor-get $path] cy cx
    if {[dict exists $::session_headings $path]} {
        set hs [toc-collect]
        set hidx [dict get $::session_headings $path]
        if {$hidx < [llength $hs]} {
            set cy [lindex [lindex $hs $hidx] 0]; set cx 0
        }
    }
    .ed.t mark set insert ${cy}.${cx}
    .ed.t see insert
    catch { .ed.pw.l.t mark set insert ${cy}.${cx}; .ed.pw.l.t see insert }
    ed-status
    if {[status-zone-of words] ne "" || [status-zone-of chars] ne "" || [status-zone-of goal] ne ""} { wc-flush }
    ln-update
}

proc save-file {} {
    if {$::filename eq ""} { if {$::scratchpad} { save-as }; return }
    set fh [open $::filename w]
    chan configure $fh -encoding utf-8
    puts -nonewline $fh [.ed.t get 1.0 {end - 1 chars}]
    close $fh
    set ::dirty 0
    .ed.t edit modified false
    set ::file_mtime_known [file mtime $::filename]
    lassign [split [[primary-ed] index insert] .] cy cx
    cursor-put $::filename $cy $cx
    daily-update [llength [regexp -all -inline {\S+} [[primary-ed] get 1.0 end-1c]]]
    set-msg [t ed_saved]
}

proc save-as {} {
    set dir [expr {$::filename ne "" ? [file dirname $::filename] : $::DOCS_DIR_DEFAULT}]
    set name [input-dialog "Save as" "Save as:"]
    set name [string trim $name]
    if {$name eq ""} return
    if {[file extension $name] eq ""} { append name $::FILE_EXT }
    set new_path [file join $dir $name]
    if {[file exists $new_path] && $new_path ne $::filename} {
        if {[confirm-dialog "\"$name\" already exists. Overwrite?"] ne "yes"} return
    }
    set ::filename $new_path
    set ::scratchpad 0
    ed-update-title
    save-file
}

proc search-open {} {
    set ::search_ed [active-ed]
    if {![winfo ismapped .ed.sf]} {
        pack .ed.sf -before .ed.bar -side bottom -fill x
    }
    catch { pack forget .ed.sf.r }
    .ed.sf.e delete 0 end
    if {$::search_term ne ""} { .ed.sf.e insert 0 $::search_term }
    .ed.sf.e selection range 0 end
    focus .ed.sf.e
}

proc replace-open {} {
    set ::search_ed [active-ed]
    if {![winfo ismapped .ed.sf]} {
        pack .ed.sf -before .ed.bar -side bottom -fill x
    }
    pack .ed.sf.r -fill x
    .ed.sf.e delete 0 end
    if {$::search_term ne ""} { .ed.sf.e insert 0 $::search_term }
    .ed.sf.e selection range 0 end
    focus .ed.sf.e
}

proc replace-one {} {
    if {$::search_term eq ""} return
    set t $::search_ed
    set repl [.ed.sf.r.e get]
    set slen [string length $::search_term]
    set pos [.ed.t search -nocase -exact -- $::search_term [$t index insert] end]
    if {$pos eq ""} { set pos [.ed.t search -nocase -exact -- $::search_term 1.0 end] }
    if {$pos ne ""} {
        .ed.t delete $pos "$pos + ${slen} chars"
        .ed.t insert $pos $repl
        $t mark set insert "$pos + [string length $repl] chars"
        $t see insert
        search-update
    }
}

proc replace-all {} {
    if {$::search_term eq ""} return
    set repl [.ed.sf.r.e get]
    set count 0; set pos 1.0
    while 1 {
        set pos [.ed.t search -nocase -exact -count len -- $::search_term $pos end]
        if {$pos eq ""} break
        .ed.t delete $pos "$pos + $len chars"
        .ed.t insert $pos $repl
        set pos "$pos + [string length $repl] chars"
        incr count
    }
    set-msg "replaced $count occurrence[expr {$count!=1?{s}:{}}]"
    search-update
}

proc search-close {} {
    .ed.t tag remove found 1.0 end
    catch { pack forget .ed.sf }
    catch { focus $::search_ed }
    set ::search_count ""
}

proc search-update {} {
    set t $::search_ed
    set term [.ed.sf.e get]
    .ed.t tag remove found 1.0 end
    set ::search_count ""
    if {$term eq ""} return
    set ::search_term $term
    set count 0; set pos 1.0; set len 1
    set cap 500
    while {$count < $cap} {
        set pos [.ed.t search -nocase -forwards -count len -- $term $pos end]
        if {$pos eq ""} break
        .ed.t tag add found $pos "$pos + $len chars"
        incr count; set pos "$pos + $len chars"
    }
    .ed.t tag configure found -background "#5a3a00" -foreground "#ffdd88"
    set capped [expr {$count >= $cap}]
    set plural [expr {$count != 1 ? "s" : ""}]
    set ::search_count " $count match${plural}[expr {$capped ? {+} : {}}]"
    set pos [.ed.t search -nocase -forwards -- $term [$t index insert] end]
    if {$pos eq ""} { set pos [.ed.t search -nocase -forwards -- $term 1.0 end] }
    if {$pos ne ""} { $t mark set insert $pos; $t see insert }
}

proc search-next {} {
    if {$::search_term eq ""} return
    set t $::search_ed
    set pos [.ed.t search -nocase -forwards -- $::search_term "[$t index insert] + 1 chars" end]
    if {$pos eq ""} { set pos [.ed.t search -nocase -forwards -- $::search_term 1.0 end] }
    if {$pos ne ""} { $t mark set insert $pos; $t see insert }
}

proc search-prev {} {
    if {$::search_term eq ""} return
    set t $::search_ed
    set pos [.ed.t search -nocase -backwards -- $::search_term [$t index insert] 1.0]
    if {$pos eq ""} { set pos [.ed.t search -nocase -backwards -- $::search_term end 1.0] }
    if {$pos ne ""} { $t mark set insert $pos; $t see insert }
}

proc close-editor {} {
    if {$::dirty} {
        set _label [expr {$::scratchpad ? "scratchpad" : [file tail $::filename]}]
        set r [yesnocancel-dialog [t ed_save_before $_label]]
        if {$r eq "cancel"} return
        if {$r eq "yes"}    save-file
    }
    if {$::filename ne ""} {
        daily-update [llength [regexp -all -inline {\S+} [[primary-ed] get 1.0 end-1c]]]
        lassign [split [[primary-ed] index insert] .] cy cx
        cursor-put $::filename $cy $cx
    }
    set ::session_file ""
    if {$::watch_after_id ne ""} { after cancel $::watch_after_id; set ::watch_after_id "" }
    split-close
    if {$::ws_n == 2} {
        set ::ws2_filename   $::filename
        set ::ws2_scratchpad $::scratchpad
        set ::ws2_dirty      $::dirty
        set ::ws2_content    [.ed.t get 1.0 end-1c]
        set ::ws2_cursor     [.ed.t index insert]
    }
    set ::filename   ""
    set ::scratchpad 0
    set ::file_mtime_known 0
    set ::dirty     0
    set ::msg       ""
    set ::ed_msg    ""
    wm title . "Writhdeck"
    .ed.t delete 1.0 end
    search-close
    if {$::cfg_browser} { show-browser } else { exit }
}

proc apply-theme {} {
    lassign [theme-colors] bg fg bg_bar fg_bar bg_sel c_heading c_comment c_markup bg2
    set ::bg $bg; set ::fg $fg; set ::bg_bar $bg_bar
    set ::fg_bar $fg_bar; set ::bg_sel $bg_sel; set ::bg2 $bg2
    # browser
    foreach w {.br .br.mid} { catch { $w configure -bg $bg } }
    foreach w {.br.title .br.bar.help .br.bar.cnt} {
        catch { $w configure -bg $bg_bar -fg $fg_bar }
    }
    catch { .br.title configure -bg $bg -fg $fg }
    catch { .br.bar configure -bg $bg_bar }
    catch { .br.bar.help tag configure link_hover -background $c_comment }
    catch { .br.mid.lst configure -bg $bg -fg $fg }
    set header_font [list [lindex $::font 0] [lindex $::font 1] bold]
    catch { .br.mid.lst tag configure header -foreground $c_comment -font $header_font }
    catch { .br.mid.lst tag configure file -foreground $fg }
    catch { .br.mid.lst tag configure selected -background $bg_sel -foreground $fg }
    catch { .br.mid.sb configure -bg $bg_bar -troughcolor $bg }
    # editor
    catch { .ed configure -bg $bg2 }
    catch { .ed.t configure -bg $bg -fg $fg \
                -insertbackground $fg -selectbackground $bg_sel -selectforeground $fg \
                -blockcursor 0 \
                -insertwidth [expr {$::cfg_block_cursor_gui ? 0 : 2}] \
                -insertofftime [expr {$::cfg_block_cursor_gui ? 0 : ($::cfg_blink_cursor ? 300 : 0)}] }
    catch { cursor-setup }
    catch { .ed.t tag configure heading       -foreground $c_heading }
    catch { .ed.t tag configure comment       -foreground $c_comment }
    catch { .ed.t tag configure bold          -foreground $c_markup }
    catch { .ed.t tag configure italic        -foreground $c_markup }
    catch { .ed.t tag configure underline     -foreground $c_markup }
    catch { .ed.t tag configure strikethrough -foreground $c_comment }
    catch { .ed.t tag configure marker        -foreground $c_comment }
    catch { .ed.sb configure -bg $bg_bar -troughcolor $bg }
    catch { .ed.bar configure -bg $bg_bar }
    foreach w {.ed.bar.left .ed.bar.center .ed.bar.right .ed.bar.msg .ed.bar.help} {
        catch { $w configure -bg $bg_bar -fg $fg_bar }
    }
    catch { .ed.ln configure -bg $bg_bar -fg $fg_bar }
    # search bar
    catch { .ed.sf configure -bg $bg_bar }
    catch { .ed.sf.lbl configure -bg $bg_bar -fg $fg_bar }
    catch { .ed.sf.e configure -bg $bg -fg $fg -insertbackground $fg }
    catch { .ed.sf.cnt configure -bg $bg_bar -fg $fg_bar }
    catch { .ed.sf.r configure -bg $bg_bar }
    catch { .ed.sf.r.lbl configure -bg $bg_bar -fg $fg_bar }
    catch { .ed.sf.r.e configure -bg $bg -fg $fg -insertbackground $fg }
    catch { .ed.sf.r.one configure -bg $bg_bar -fg $fg_bar }
    catch { .ed.sf.r.all configure -bg $bg_bar -fg $fg_bar }
    # split-view peers
    catch { .ed.pw configure -bg $bg_bar }
    foreach side {l r} {
        catch { .ed.pw.$side configure -bg $bg2 }
        catch { .ed.pw.${side}.t configure -bg $bg -fg $fg \
                    -insertbackground $fg -selectbackground $bg_sel -selectforeground $fg \
                    -highlightbackground $bg -highlightcolor $fg }
        catch { .ed.pw.${side}.sb configure -bg $bg_bar -troughcolor $bg }
        catch { .ed.pw.${side}.t tag configure focus_dim -foreground $c_comment }
    }
    catch { .ed.t tag configure focus_dim -foreground $c_comment }
}

proc ws-check-inactive-dirty {} {
    if {!$::ws_dual_mode} { return 1 }
    if {$::ws_n == 1} {
        set iws 2;  set ifn $::ws2_filename;  set isp $::ws2_scratchpad
        set idirty $::ws2_dirty;  set icontent $::ws2_content
    } else {
        set iws 1;  set ifn $::ws1_filename;  set isp $::ws1_scratchpad
        set idirty $::ws1_dirty;  set icontent $::ws1_content
    }
    if {!$idirty || ($ifn eq "" && !$isp)} { return 1 }
    set _lbl [expr {$isp ? "scratchpad \[$iws\]" : "[file tail $ifn] \[$iws\]"}]
    set r [yesnocancel-dialog [t ed_save_before $_lbl]]
    if {$r eq "cancel"} { return 0 }
    if {$r eq "yes" && $ifn ne ""} {
        set fh [open $ifn w];  chan configure $fh -encoding utf-8
        puts -nonewline $fh $icontent;  close $fh
        if {$iws == 1} { set ::ws1_dirty 0 } else { set ::ws2_dirty 0 }
    }
    return 1
}

proc quit-app {} {
    if {$::dirty && ($::filename ne "" || $::scratchpad)} {
        set _label [expr {$::scratchpad ? "scratchpad" : [file tail $::filename]}]
        set r [yesnocancel-dialog [t ed_save_before $_label]]
        if {$r eq "cancel"} return
        if {$r eq "yes"} save-file
    }
    if {![ws-check-inactive-dirty]} return
    if {$::filename ne ""} {
        daily-update [llength [regexp -all -inline {\S+} [[primary-ed] get 1.0 end-1c]]]
        lassign [split [[primary-ed] index insert] .] cy cx
        cursor-put $::filename $cy $cx
    }
    exit
}

wm protocol . WM_DELETE_WINDOW quit-app

# --- editor bindings ----------------------------------------------------------

proc ed-paste {} {
    # On X11, Tk's default <<Paste>> does not replace the selection.
    # We delete it manually so paste behaves consistently across platforms.
    set t [active-ed]
    if {![catch {::tk::GetSelection $t CLIPBOARD} clip]} {
        $t configure -autoseparators 0
        $t edit separator
        catch { $t delete sel.first sel.last }
        $t insert insert $clip
        $t edit separator
        $t configure -autoseparators 1
    }
}

bind .ed.t <$::cfg_key_save>    { save-file;         break }
bind .ed.t <$::cfg_key_save_as> { save-as;           break }
bind .ed.t <$::cfg_key_close>   { close-editor;      break }
bind .ed.t <$::cfg_key_paste>        { ed-paste;          break }
bind .ed.t <$::cfg_key_select_all>  { .ed.t tag add sel 1.0 end; break }
bind .ed.t <$::cfg_key_dark_toggle> { toggle-dark-mode;  break }
bind .br.mid.lst <$::cfg_key_dark_toggle> { toggle-dark-mode }

bind .ed.t <$::cfg_key_sticky_sel> { break }
bind .ed.t <Tab>                { .ed.t insert insert "\t"; break }
bind .ed.t <$::cfg_key_goto>       { goto-dialog;    break }
bind .ed.t <$::cfg_key_help>       { help-dialog;    break }
bind .ed.t <$::cfg_key_redo>        { catch {.ed.t edit redo}; ed-status; break }
bind .ed.t <$::cfg_key_typewriter>  { typewriter-toggle; break }
bind .ed.t <KeyRelease>            {+ if {$::typewriter_mode} { typewriter-tick .ed.t } }
bind .ed.t <ButtonRelease>         {+ if {$::typewriter_mode} { typewriter-tick .ed.t } }
foreach _k {Left Right Up Down BackSpace Delete} {
    bind .ed.t <$_k> "if {\$::typewriter_mode && \$::cfg_hemingway_mode} break"
}
bind .ed.t <$::cfg_key_undo> "if {\$::typewriter_mode && \$::cfg_hemingway_mode} break"
bind .ed.t <$::cfg_key_replace> { replace-open;      break }
bind .ed.t <$::cfg_key_find>    { search-open;       break }
bind .ed.t <$::cfg_key_open>    { open-file-dialog;  break }

bind .ed.sf.e <KeyRelease>   { search-update }
bind .ed.sf.e <Return>       { search-next }
bind .ed.sf.e <Shift-Return> { search-prev }
bind .ed.sf.e <Escape>       { search-close }
bind .ed.sf.e <Control-f>    { search-next; break }
bind .ed.sf.e <Tab>          { focus .ed.sf.r.e; break }

bind .ed.sf.r.e <Return>        { replace-one }
bind .ed.sf.r.e <Control-Return> { replace-all }
bind .ed.sf.r.e <Escape>        { search-close }
bind .ed.sf.r.e <Tab>           { focus .ed.sf.e; break }
bind .br.mid.lst <h>                  { help-dialog }
bind .br.mid.lst <$::cfg_key_help>   { help-dialog }

proc open-file-dialog {{initialdir ""}} {
    if {$::split_ws2_mode && [focus] eq ".ed.pw.r.t"} {
        set dir [expr {$::ws2_filename ne "" ? [file dirname $::ws2_filename] : $::DOCS_DIR_DEFAULT}]
        set path [tk_getOpenFile -initialdir $dir \
            -filetypes {{"Text files" {.txt}} {"All files" *}}]
        if {$path ne ""} { split-ws2-load-file $path }
        return
    }
    if {$initialdir eq ""} {
        set initialdir [expr {$::filename ne "" ? [file dirname $::filename] : $::DOCS_DIR_DEFAULT}]
    }
    set path [tk_getOpenFile \
        -initialdir $initialdir \
        -filetypes {{"Text files" {.txt}} {"All files" *}}]
    if {$path ne ""} { show-editor $path }
}

bind .br.mid.lst <Control-o> {
    set _e [br-selected]
    open-file-dialog [expr {[llength $_e] ? [lindex $_e 1] : $::DOCS_DIR_DEFAULT}]
}

proc toggle-fullscreen {} {
    set ::fullscreen [expr {!$::fullscreen}]
    wm attributes . -fullscreen $::fullscreen
}

bind .ed.t          <$::cfg_key_fullscreen> { toggle-fullscreen; break }
bind .br.mid.lst    <$::cfg_key_fullscreen> { toggle-fullscreen }
bind .ed.t          <$::cfg_key_split>       { split-toggle; break }
bind .ed.t          <$::cfg_key_split_focus> { split-cycle-focus; break }
bind .ed.t          <$::cfg_key_workspace>   { workspace-toggle; break }

# --- headings & TOC -----------------------------------------------------------
proc highlight-headings {} {
    set last [lindex [split [.ed.t index end] .] 0]
    set full [expr {$last != $::hl_last_count}]
    if {$full} {
        set ::hl_last_count $last
        set ::hl_line_cache {}
        foreach t {heading comment bold italic underline strikethrough marker} {
            .ed.t tag remove $t 1.0 end
        }
    }
    for {set ln 1} {$ln < $last} {incr ln} {
        set line [.ed.t get $ln.0 "$ln.0 lineend"]
        if {!$full} {
            if {[dict exists $::hl_line_cache $ln] && [dict get $::hl_line_cache $ln] eq $line} continue
            foreach t {heading comment bold italic underline strikethrough marker} {
                .ed.t tag remove $t $ln.0 "$ln.0 lineend"
            }
        }
        dict set ::hl_line_cache $ln $line
        if {[parse-heading $line] ne ""} {
            .ed.t tag add heading $ln.0 "$ln.0 lineend"
        } elseif {[parse-comment $line]} {
            .ed.t tag add comment $ln.0 "$ln.0 lineend"
        } else {
            if {$::cached_bold_re ne "" && [string first $::cfg_bold_marker $line] >= 0} {
                apply-inline $ln $line bold $::cached_bold_re $::cached_bold_mlen }
            if {$::cached_italic_re ne "" && [string first $::cfg_italic_marker $line] >= 0} {
                apply-inline $ln $line italic $::cached_italic_re $::cached_italic_mlen }
            if {$::cached_underline_re ne "" && [string first $::cfg_underline_marker $line] >= 0} {
                apply-inline $ln $line underline $::cached_underline_re $::cached_underline_mlen 1 }
            if {$::cached_strikethrough_re ne "" && [string first $::cfg_strikethrough_marker $line] >= 0} {
                apply-inline $ln $line strikethrough $::cached_strikethrough_re $::cached_strikethrough_mlen 1 }
        }
    }
}

proc toc-collect {} {
    set result {}
    if {$::hl_line_cache ne {}} {
        dict for {ln line} $::hl_line_cache {
            set hl [heading-level $line]
            if {$hl ne ""} { lassign $hl title level; lappend result [list $ln $title $level] }
        }
    } else {
        set last [lindex [split [.ed.t index end] .] 0]
        for {set ln 1} {$ln < $last} {incr ln} {
            set line [.ed.t get $ln.0 "$ln.0 lineend"]
            set hl [heading-level $line]
            if {$hl ne ""} { lassign $hl title level; lappend result [list $ln $title $level] }
        }
    }
    return $result
}

proc toc-show {} {
    set ::toc_ed [active-ed]
    set headings [toc-collect]
    if {![llength $headings]} { set-msg [t toc_no_headings]; return }

    set w .toc
    catch {destroy $w}
    toplevel $w
    wm title $w [t toc_title]
    wm resizable $w 1 0
    wm transient $w .

    set h [expr {min([llength $headings], 24)}]
    listbox $w.lst \
        -font $::font -bg $::bg -fg $::cfg_color_heading \
        -selectbackground $::bg_sel -selectforeground $::fg \
        -activestyle none -borderwidth 0 -highlightthickness 0 \
        -width 48 -height $h
    pack $w.lst -fill both -expand 1 -padx 2 -pady 2

    set presel 0
    if {[dict exists $::session_headings $::filename]} {
        set presel [dict get $::session_headings $::filename]
        if {$presel >= [llength $headings]} { set presel 0 }
    } else {
        set curline [lindex [split [.ed.t index insert] .] 0]
        set idx 0
        foreach item $headings {
            if {[lindex $item 0] <= $curline} { set presel $idx }
            incr idx
        }
    }
    set lnw [string length [expr {[lindex [split [.ed.t index end] .] 0] - 1}]]
    foreach item $headings {
        lassign $item ln title level
        set indent [string repeat "- " [expr {$level - 1}]]
        $w.lst insert end [format "  %${lnw}d   %s%s" $ln $indent $title]
    }
    $w.lst selection set $presel
    $w.lst activate $presel
    $w.lst see $presel

    bind $w.lst <Return>          [list toc-jump $w $headings]
    bind $w.lst <Double-1>        [list toc-jump $w $headings]
    bind $w.lst <ButtonRelease-1> "[list toc-jump $w $headings]; break"
    bind $w     <Escape>          [list destroy $w]
    bind $w     <Control-q>       [list destroy $w]
    bind $w.lst <Control-q>       [list destroy $w]
    bind $w     <$::cfg_key_toc>  [list destroy $w]
    bind $w     <Destroy>  { after idle { catch { focus $::toc_ed } } }
    focus $w.lst
}

proc toc-jump {w headings} {
    set sel [$w.lst curselection]
    if {![llength $sel]} return
    set selIdx [lindex $sel 0]
    lassign [lindex $headings $selIdx] ln title
    dict set ::session_headings $::filename $selIdx
    destroy $w
    set t $::toc_ed
    $t mark set insert $ln.0
    $t see insert
    focus $t
}

bind .ed.t <$::cfg_key_toc>          { toc-show;   break }
bind .br.mid.lst <$::cfg_key_toc>   { br-toc-show; break }
bind .ed.t <$::cfg_key_line_numbers> { ln-toggle;  break }

proc br-toc-show {} {
    set sections {}
    for {set i 0} {$i < [llength $::br_entries]} {incr i} {
        lassign [lindex $::br_entries $i] type dir name
        if {$type eq "header"} {
            set lbl [expr {$name ne "" ? $name : [string map [list $::HOME_DIR ~] $dir]}]
            lappend sections [list $i $lbl]
        }
    }
    if {![llength $sections]} { set-msg [t br_toc_empty]; return }

    set w .brtoc
    catch {destroy $w}
    toplevel $w
    wm title $w [t br_toc_title]
    wm resizable $w 1 0
    wm transient $w .

    set h [expr {min([llength $sections], 12)}]
    listbox $w.lst \
        -font $::font -bg $::bg -fg $::fg_bar \
        -selectbackground $::bg_sel -selectforeground $::fg \
        -activestyle none -borderwidth 0 -highlightthickness 0 \
        -width 40 -height $h
    pack $w.lst -fill both -expand 1 -padx 2 -pady 2

    foreach sec $sections {
        lassign $sec idx lbl
        $w.lst insert end "  $lbl"
    }
    $w.lst selection set 0
    $w.lst activate 0
    $w.lst see 0

    bind $w.lst <Return>          [list br-toc-jump $w $sections]
    bind $w.lst <Double-1>        [list br-toc-jump $w $sections]
    bind $w.lst <ButtonRelease-1> "[list br-toc-jump $w $sections]; break"
    bind $w     <Escape>          [list destroy $w]
    bind $w     <Control-q>       [list destroy $w]
    bind $w.lst <Control-q>       [list destroy $w]
    bind $w     <$::cfg_key_toc>  [list destroy $w]
    bind $w     <Destroy>  { after idle { catch { focus .br.mid.lst } } }
    focus $w.lst
}

proc br-toc-jump {w sections} {
    set sel [$w.lst curselection]
    if {![llength $sel]} return
    lassign [lindex $sections [lindex $sel 0]] idx lbl
    destroy $w
    set line_num [expr {$idx + 1}]
    .br.mid.lst tag remove selected 1.0 end
    .br.mid.lst tag add selected ${line_num}.0 ${line_num}.end
    .br.mid.lst see ${line_num}.0
    focus .br.mid.lst
}

# --- taille de police dynamique -----------------------------------------------
proc apply-line-spacing {} {
    set lh [font metrics [.ed.t cget -font] -linespace]
    set extra [expr {int($lh * ($::cfg_line_spacing - 100) / 100.0)}]
    set sp [expr {max(0, $extra)}]
    .ed.t configure -spacing1 $sp -spacing2 $sp -spacing3 0
    foreach side {l r} {
        catch { .ed.pw.${side}.t configure -spacing1 $sp -spacing2 $sp -spacing3 0 }
    }
}

proc font-resize {delta} {
    set ::cfg_font_size [expr {max(6, min(72, $::cfg_font_size + $delta))}]
    set f [list $::cfg_font_family $::cfg_font_size]
    set ::font $f
    .ed.t configure -font $f
    foreach side {l r} { catch { .ed.pw.${side}.t configure -font $f } }
    .ed.t tag configure heading -font [list $::cfg_font_family $::cfg_font_size bold]
    apply-line-spacing
}

bind .ed.t <Control-equal>    { font-resize  1; break }
bind .ed.t <Control-plus>    { font-resize  1; break }
bind .ed.t <Control-KP_Add>  { font-resize  1; break }
bind .ed.t <Control-minus>   { font-resize -1; break }
bind .ed.t <Control-KP_Subtract> { font-resize -1; break }
proc gui-handle-esc {} {
    if {!$::gui_cmd_mode} {
        set ::gui_cmd_mode 1
        gui-status-update
    } else {
        # Just exit command mode
        set ::gui_cmd_mode 0
        ed-status
    }
}

proc gui-handle-keypress {key} {
    if {$::gui_cmd_mode} {
        if {$key eq "t" || $key eq "T"} {
            if {$::timer_active} { timer-pause } else { timer-start }
            set ::gui_cmd_mode 0
            ed-status
            return 1
        } elseif {$key eq "s" || $key eq "S"} {
            if {$::filename ne ""} {
                daily-update [llength [regexp -all -inline {\S+} [[primary-ed] get 1.0 end-1c]]]
                br-stats $::filename
            }
            set ::gui_cmd_mode 0
            ed-status
            return 1
        } elseif {$key eq "w" || $key eq "W"} {
            if {$::filename ne ""} {
                word-occurrences-dialog $::filename
            }
            set ::gui_cmd_mode 0
            ed-status
            return 1
        } elseif {$key eq "q" || $key eq "Q"} {
            set ::gui_cmd_mode 0
            ed-status
            close-editor
            return 1
        }
        # Pour les autres touches non reconnues, reste en mode modal
        return 1
    }
    return 0
}

bind .ed.t <$::cfg_key_cmd_mode> {
    gui-handle-esc
    break
}
bind .ed.t <t> {
    if {![gui-handle-keypress t]} {
        # Normal 't' input
        %W insert insert t
        ed-status
    }
    break
}
bind .ed.t <T> {
    if {![gui-handle-keypress T]} {
        # Normal 'T' input
        %W insert insert T
        ed-status
    }
    break
}
bind .ed.t <c> {
    if {![gui-handle-keypress c]} {
        # Normal 'c' input
        %W insert insert c
        ed-status
    }
    break
}
bind .ed.t <C> {
    if {![gui-handle-keypress C]} {
        # Normal 'C' input
        %W insert insert C
        ed-status
    }
    break
}
bind .ed.t <Alt-t> {
    if {!$::gui_cmd_mode} {
        if {$::timer_active} { timer-pause } else { timer-start }
        ed-status
    }
    break
}
bind .ed.t <q> {
    if {![gui-handle-keypress q]} {
        # Normal 'q' input
        %W insert insert q
        ed-status
    }
    break
}
bind .ed.t <Q> {
    if {![gui-handle-keypress Q]} {
        # Normal 'Q' input
        %W insert insert Q
        ed-status
    }
    break
}
bind .ed.t <s> {
    if {![gui-handle-keypress s]} {
        # Normal 's' input
        %W insert insert s
        ed-status
    }
    break
}
bind .ed.t <S> {
    if {![gui-handle-keypress S]} {
        # Normal 'S' input
        %W insert insert S
        ed-status
    }
    break
}
bind .ed.t <w> {
    if {![gui-handle-keypress w]} {
        # Normal 'w' input
        %W insert insert w
        ed-status
    }
    break
}
bind .ed.t <W> {
    if {![gui-handle-keypress W]} {
        # Normal 'W' input
        %W insert insert W
        ed-status
    }
    break
}

bind .ed.t <Any-KeyPress> {
    if {$::gui_cmd_mode} {
        set k %K
        if {$k ne "Escape"} {
            break
        }
    }
}

proc profile-config-update-profile {w} {
    set profile $::profile_config_profile
    if {$profile eq ""} return

    set cur_font $::cfg_font_family
    if {[dict exists $::cfg_profiles $profile font_family]} {
        set cur_font [dict get $::cfg_profiles $profile font_family]
    }
    $w.tab_profile.profile.ffont.entry delete 0 end
    $w.tab_profile.profile.ffont.entry insert 0 $cur_font

    set cur_size $::cfg_font_size
    if {[dict exists $::cfg_profiles $profile font_size]} {
        set cur_size [dict get $::cfg_profiles $profile font_size]
    }
    $w.tab_profile.fsize.spin set $cur_size

    set cur_mw $::cfg_margin_width
    if {[dict exists $::cfg_profiles $profile margin_width]} {
        set cur_mw [dict get $::cfg_profiles $profile margin_width]
    }
    $w.tab_profile.fmarginw.spin set $cur_mw

    set cur_mh $::cfg_margin_height
    if {[dict exists $::cfg_profiles $profile margin_height]} {
        set cur_mh [dict get $::cfg_profiles $profile margin_height]
    }
    $w.tab_profile.fmarginh.spin set $cur_mh

    set cur_goal $::cfg_word_goal
    if {[dict exists $::cfg_profiles $profile word_goal]} {
        set cur_goal [dict get $::cfg_profiles $profile word_goal]
    }
    $w.tab_profile.fwordgoal.spin set $cur_goal

    set cur_dark $::cfg_dark_mode
    if {[dict exists $::cfg_profiles $profile dark_mode]} {
        set cur_dark [dict get $::cfg_profiles $profile dark_mode]
    }
    set ::profile_config_dark_mode $cur_dark

    set idx [lsearch -exact [lsort [font families]] $cur_font]
    $w.tab_profile.profile.fonts selection clear 0 end
    if {$idx >= 0} { $w.tab_profile.profile.fonts selection set $idx; $w.tab_profile.profile.fonts see $idx }
}

proc config-tab-switch {w tab} {
    pack forget $w.tab_profile $w.tab_timer
    if {$tab eq "profile"} {
        pack $w.tab_profile -fill both -expand 1 -padx 8 -pady 8
        $w.tabs.profile configure -fg $::fg -bg $::bg_sel
        $w.tabs.timer configure -fg $::fg_bar -bg $::bg
    } else {
        pack $w.tab_timer -fill both -expand 1 -padx 8 -pady 8
        $w.tabs.profile configure -fg $::fg_bar -bg $::bg
        $w.tabs.timer configure -fg $::fg -bg $::bg_sel
    }
}

proc profile-config-dialog {} {
    set w .profile_config
    catch {destroy $w}
    catch {unset ::profile_config_profile}
    toplevel $w
    wm title $w [t profile_config_title]
    wm transient $w .
    $w configure -bg $::bg

    set profiles [lsort [dict keys $::cfg_profiles]]
    set schemes [lsort [dict keys $::cfg_schemes]]

    if {[llength $profiles] == 0} {
        label $w.msg -text "No profiles defined" -font $::font_sm -fg $::fg_bar -bg $::bg -padx 16 -pady 12
        button $w.close -text [t profile_config_cancel] -font $::font_sm \
            -command "destroy $w" -bg $::bg_bar -fg $::fg_bar
        pack $w.msg -fill x
        pack $w.close -pady 8
        update
        grab $w
        focus $w.close
        return
    }

    # --- Tab bar ---
    frame $w.tabs -bg $::bg
    pack $w.tabs -fill x -padx 8 -pady {8 0}
    button $w.tabs.profile -text [t config_tab_profile] -font $::font_sm -fg $::fg -bg $::bg_sel \
        -command "config-tab-switch $w profile" -borderwidth 1 -relief raised -padx 12 -pady 4
    button $w.tabs.timer -text [t config_tab_timer] -font $::font_sm -fg $::fg_bar -bg $::bg \
        -command "config-tab-switch $w timer" -borderwidth 1 -relief raised -padx 12 -pady 4
    pack $w.tabs.profile -side left -padx 2
    pack $w.tabs.timer -side left -padx 2

    # --- Tab content frames ---
    frame $w.tab_profile -bg $::bg
    frame $w.tab_timer -bg $::bg
    pack $w.tab_profile -fill both -expand 1 -padx 8 -pady 8

    # --- Profile tab content ---
    # --- Global settings frame ---
    frame $w.tab_profile.global -relief ridge -borderwidth 2 -bg $::bg
    pack $w.tab_profile.global -fill x -padx 0 -pady 8

    label $w.tab_profile.global.title -text "Global Settings" -font $::font_sm -fg $::fg_bar -bg $::bg
    pack $w.tab_profile.global.title -anchor w -padx 8 -pady {4 2}

    label $w.tab_profile.global.lbl_defprof -text [t profile_config_default_profile] -font $::font_sm -bg $::bg -fg $::fg
    pack $w.tab_profile.global.lbl_defprof -anchor w -padx 12 -pady {4 2}
    frame $w.tab_profile.global.fprof -bg $::bg
    pack $w.tab_profile.global.fprof -fill x -padx 12 -pady {0 6}
    tk_optionMenu $w.tab_profile.global.fprof.om ::profile_config_default_prof {*}$profiles
    $w.tab_profile.global.fprof.om configure -bg $::bg_bar -fg $::fg_bar -activebackground $::bg_sel -activeforeground $::fg -borderwidth 1 -highlightthickness 0
    set ::profile_config_default_prof $::cfg_profile
    pack $w.tab_profile.global.fprof.om -anchor w

    label $w.tab_profile.global.lbl_scheme -text [t profile_config_default_scheme] -font $::font_sm -bg $::bg -fg $::fg
    pack $w.tab_profile.global.lbl_scheme -anchor w -padx 12 -pady {4 2}
    frame $w.tab_profile.global.fscheme -bg $::bg
    pack $w.tab_profile.global.fscheme -fill x -padx 12 -pady {0 6}
    tk_optionMenu $w.tab_profile.global.fscheme.om ::profile_config_default_scheme {*}$schemes
    $w.tab_profile.global.fscheme.om configure -bg $::bg_bar -fg $::fg_bar -activebackground $::bg_sel -activeforeground $::fg -borderwidth 1 -highlightthickness 0
    set ::profile_config_default_scheme $::cfg_scheme
    pack $w.tab_profile.global.fscheme.om -anchor w

    label $w.tab_profile.global.lbl_lang -text [t profile_config_language] -font $::font_sm -bg $::bg -fg $::fg
    pack $w.tab_profile.global.lbl_lang -anchor w -padx 12 -pady {4 2}
    frame $w.tab_profile.global.flang -bg $::bg
    pack $w.tab_profile.global.flang -fill x -padx 12 -pady {0 6}
    set langs [lsort [dict keys $::i18n]]
    tk_optionMenu $w.tab_profile.global.flang.om ::profile_config_language {*}$langs
    $w.tab_profile.global.flang.om configure -bg $::bg_bar -fg $::fg_bar -activebackground $::bg_sel -activeforeground $::fg -borderwidth 1 -highlightthickness 0
    set ::profile_config_language $::cfg_lang
    pack $w.tab_profile.global.flang.om -anchor w

    # --- Profile-specific settings frame ---
    frame $w.tab_profile.profile -relief ridge -borderwidth 2 -bg $::bg
    pack $w.tab_profile.profile -fill x -padx 0 -pady 8

    label $w.tab_profile.profile.title -text "Profile Settings" -font $::font_sm -fg $::fg_bar -bg $::bg
    pack $w.tab_profile.profile.title -anchor w -padx 8 -pady {4 2}

    # Profile selector row
    frame $w.tab_profile.profile.fprof -bg $::bg
    pack $w.tab_profile.profile.fprof -fill x -padx 12 -pady {0 6}
    label $w.tab_profile.profile.fprof.lbl -text [t profile_config_edit_profile] -font $::font_sm -width 20 -anchor w -bg $::bg -fg $::fg
    tk_optionMenu $w.tab_profile.profile.fprof.om ::profile_config_profile {*}$profiles
    $w.tab_profile.profile.fprof.om configure -bg $::bg_bar -fg $::fg_bar -activebackground $::bg_sel -activeforeground $::fg -borderwidth 1 -highlightthickness 0
    if {[lsearch -exact $profiles $::cfg_profile] >= 0} {
        set ::profile_config_profile $::cfg_profile
    } else {
        set ::profile_config_profile [lindex $profiles 0]
    }
    pack $w.tab_profile.profile.fprof.lbl -side left -padx {0 8}
    pack $w.tab_profile.profile.fprof.om -side left -fill x -expand 1 -padx {8 0}

    # Font family row
    frame $w.tab_profile.profile.ffont -bg $::bg
    pack $w.tab_profile.profile.ffont -fill x -padx 12 -pady 4
    label $w.tab_profile.profile.ffont.lbl -text [t profile_config_font] -font $::font_sm -width 20 -anchor w -bg $::bg -fg $::fg
    entry $w.tab_profile.profile.ffont.entry -width 30 -font $::font_sm -bg $::bg_bar -fg $::fg
    pack $w.tab_profile.profile.ffont.lbl -side left
    pack $w.tab_profile.profile.ffont.entry -side left -fill x -expand 1 -padx {8 0}

    # Available fonts listbox with scrollbar
    label $w.tab_profile.profile.lbl_fonts -text "Available fonts:" -font $::font_sm -bg $::bg -fg $::fg
    pack $w.tab_profile.profile.lbl_fonts -anchor w -padx 12 -pady {4 2}
    frame $w.tab_profile.profile.fonts_frame -bg $::bg
    pack $w.tab_profile.profile.fonts_frame -fill both -expand 1 -padx 12 -pady 2
    listbox $w.tab_profile.profile.fonts -height 5 -width 40 -font $::font_sm -selectmode single \
        -yscrollcommand [list $w.tab_profile.profile.fonts_scroll set] -bg $::bg_bar -fg $::fg
    scrollbar $w.tab_profile.profile.fonts_scroll -command [list $w.tab_profile.profile.fonts yview] -bg $::bg_bar
    foreach f [lsort [font families]] {
        $w.tab_profile.profile.fonts insert end $f
    }
    pack $w.tab_profile.profile.fonts -side left -fill both -expand 1 -in $w.tab_profile.profile.fonts_frame
    pack $w.tab_profile.profile.fonts_scroll -side left -fill y -in $w.tab_profile.profile.fonts_frame

    # Font preview (below listbox)
    label $w.tab_profile.profile.preview -text "Preview" -font $::font_sm -bg $::bg -fg $::fg
    pack $w.tab_profile.profile.preview -fill x -padx 12 -pady {8 2}

    # Font size row (create BEFORE bindings)
    frame $w.tab_profile.fsize -bg $::bg
    pack $w.tab_profile.fsize -fill x -padx 12 -pady 4
    label $w.tab_profile.fsize.lbl -text [t profile_config_size] -font $::font_sm -width 20 -anchor w -bg $::bg -fg $::fg
    spinbox $w.tab_profile.fsize.spin -from 6 -to 72 -width 5 -font $::font_sm -bg $::bg_bar -fg $::fg -command {
        set font [.profile_config.tab_profile.profile.ffont.entry get]
        set size [.profile_config.tab_profile.fsize.spin get]
        if {$font ne "" && $size ne ""} {
            catch {.profile_config.tab_profile.profile.preview configure -font [list $font $size] -text "Sample Text - $font"}
        }
    }
    pack $w.tab_profile.fsize.lbl -side left
    pack $w.tab_profile.fsize.spin -side left -padx {8 0}

    # Bind to update preview on font/size change (AFTER all widgets created)
    bind $w.tab_profile.profile.fonts <<ListboxSelect>> {
        set sel [%W curselection]
        if {[llength $sel] > 0} {
            set font_var [%W get [lindex $sel 0]]
            .profile_config.tab_profile.profile.ffont.entry delete 0 end
            .profile_config.tab_profile.profile.ffont.entry insert 0 $font_var
            set size [.profile_config.tab_profile.fsize.spin get]
            if {$size ne ""} {
                .profile_config.tab_profile.profile.preview configure -font [list $font_var $size] -text "Sample Text - $font_var"
            }
        }
    }

    bind $w.tab_profile.profile.ffont.entry <KeyRelease> {
        set font [.profile_config.tab_profile.profile.ffont.entry get]
        set size [.profile_config.tab_profile.fsize.spin get]
        if {$font ne "" && $size ne ""} {
            catch {.profile_config.tab_profile.profile.preview configure -font [list $font $size] -text "Sample Text - $font"}
        }
    }

    bind $w.tab_profile.fsize.spin <KeyRelease> {
        set font [.profile_config.tab_profile.profile.ffont.entry get]
        set size [.profile_config.tab_profile.fsize.spin get]
        if {$font ne "" && $size ne ""} {
            catch {.profile_config.tab_profile.profile.preview configure -font [list $font $size] -text "Sample Text - $font"}
        }
    }

    # Margin width row
    frame $w.tab_profile.fmarginw -bg $::bg
    pack $w.tab_profile.fmarginw -fill x -padx 12 -pady 4
    label $w.tab_profile.fmarginw.lbl -text [t profile_config_margin_w] -font $::font_sm -width 20 -anchor w -bg $::bg -fg $::fg
    spinbox $w.tab_profile.fmarginw.spin -from 0 -to 200 -width 5 -font $::font_sm -bg $::bg_bar -fg $::fg
    pack $w.tab_profile.fmarginw.lbl -side left
    pack $w.tab_profile.fmarginw.spin -side left -padx {8 0}

    # Margin height row
    frame $w.tab_profile.fmarginh -bg $::bg
    pack $w.tab_profile.fmarginh -fill x -padx 12 -pady 4
    label $w.tab_profile.fmarginh.lbl -text [t profile_config_margin_h] -font $::font_sm -width 20 -anchor w -bg $::bg -fg $::fg
    spinbox $w.tab_profile.fmarginh.spin -from 0 -to 200 -width 5 -font $::font_sm -bg $::bg_bar -fg $::fg
    pack $w.tab_profile.fmarginh.lbl -side left
    pack $w.tab_profile.fmarginh.spin -side left -padx {8 0}

    # Word goal row
    frame $w.tab_profile.fwordgoal -bg $::bg
    pack $w.tab_profile.fwordgoal -fill x -padx 12 -pady 4
    label $w.tab_profile.fwordgoal.lbl -text [t profile_config_word_goal] -font $::font_sm -width 20 -anchor w -bg $::bg -fg $::fg
    spinbox $w.tab_profile.fwordgoal.spin -from 0 -to 10000 -width 8 -font $::font_sm -bg $::bg_bar -fg $::fg
    label $w.tab_profile.fwordgoal.hint -text "(words/day, 0=disabled)" -font $::font_sm -fg $::fg_bar -bg $::bg
    pack $w.tab_profile.fwordgoal.lbl -side left
    pack $w.tab_profile.fwordgoal.spin -side left -padx {8 4}
    pack $w.tab_profile.fwordgoal.hint -side left

    # Dark mode row
    frame $w.tab_profile.fdarkmode -bg $::bg
    pack $w.tab_profile.fdarkmode -fill x -padx 12 -pady 4
    label $w.tab_profile.fdarkmode.lbl -text [t profile_config_dark_mode] -font $::font_sm -width 20 -anchor w -bg $::bg -fg $::fg
    checkbutton $w.tab_profile.fdarkmode.check -variable profile_config_dark_mode -font $::font_sm -bg $::bg -fg $::fg \
        -selectcolor $::bg_sel -activebackground $::bg -activeforeground $::fg \
        -borderwidth 1 -relief raised -highlightthickness 1 -highlightbackground $::fg_bar
    pack $w.tab_profile.fdarkmode.lbl -side left
    pack $w.tab_profile.fdarkmode.check -side left -padx {8 2}

    # --- Timer tab content ---
    frame $w.tab_timer.timer_sec -relief ridge -borderwidth 2 -bg $::bg
    pack $w.tab_timer.timer_sec -fill x -padx 0 -pady 8
    label $w.tab_timer.timer_sec.title -text [t timer_section] -font $::font_sm -fg $::fg_bar -bg $::bg
    pack $w.tab_timer.timer_sec.title -anchor w -padx 8 -pady {4 2}

    frame $w.tab_timer.timer_sec.type -bg $::bg
    pack $w.tab_timer.timer_sec.type -fill x -padx 12 -pady 4
    label $w.tab_timer.timer_sec.type.lbl -text [t timer_type] -font $::font_sm -width 20 -anchor w -bg $::bg -fg $::fg
    set timer_types [list [t timer_type_countdown] [t timer_type_stopwatch]]
    tk_optionMenu $w.tab_timer.timer_sec.type.om ::profile_config_timer_type {*}$timer_types
    $w.tab_timer.timer_sec.type.om configure -bg $::bg_bar -fg $::fg_bar -activebackground $::bg_sel -activeforeground $::fg -borderwidth 1 -highlightthickness 0
    pack $w.tab_timer.timer_sec.type.lbl -side left
    pack $w.tab_timer.timer_sec.type.om -side left -fill x -expand 1 -padx {8 0}

    frame $w.tab_timer.timer_sec.duration -bg $::bg
    pack $w.tab_timer.timer_sec.duration -fill x -padx 12 -pady 4
    label $w.tab_timer.timer_sec.duration.lbl -text [t timer_duration] -font $::font_sm -width 20 -anchor w -bg $::bg -fg $::fg
    spinbox $w.tab_timer.timer_sec.duration.spin -from 1 -to 120 -width 5 -font $::font_sm -bg $::bg_bar -fg $::fg
    label $w.tab_timer.timer_sec.duration.display -text "0'00\"" -font $::font_sm -bg $::bg_bar -fg $::fg -width 5 -anchor e
    pack $w.tab_timer.timer_sec.duration.lbl -side left
    pack $w.tab_timer.timer_sec.duration.spin -side left -padx {8 0}
    pack $w.tab_timer.timer_sec.duration.display -side left -padx {8 0}

    trace add variable ::profile_config_timer_type write [list apply {{name1 name2 op} {
        if {$::profile_config_timer_type eq "stopwatch"} {
            pack forget .profile_config.tab_timer.timer_sec.duration.spin
            pack .profile_config.tab_timer.timer_sec.duration.display -side left -padx {8 0}
        } else {
            pack forget .profile_config.tab_timer.timer_sec.duration.display
            pack .profile_config.tab_timer.timer_sec.duration.spin -side left -padx {8 0}
        }
    }}]

    frame $w.tab_timer.timer_sec.sound -bg $::bg
    pack $w.tab_timer.timer_sec.sound -fill x -padx 12 -pady 4
    label $w.tab_timer.timer_sec.sound.lbl -text [t timer_sound] -font $::font_sm -width 20 -anchor w -bg $::bg -fg $::fg
    checkbutton $w.tab_timer.timer_sec.sound.check -variable profile_config_timer_sound -font $::font_sm -bg $::bg -fg $::fg \
        -selectcolor $::bg_sel -activebackground $::bg -activeforeground $::fg \
        -borderwidth 1 -relief raised -highlightthickness 1 -highlightbackground $::fg_bar
    pack $w.tab_timer.timer_sec.sound.lbl -side left
    pack $w.tab_timer.timer_sec.sound.check -side left -padx {8 2}

    frame $w.tab_timer.timer_sec.alert -bg $::bg
    pack $w.tab_timer.timer_sec.alert -fill x -padx 12 -pady 4
    label $w.tab_timer.timer_sec.alert.lbl -text [t timer_alert] -font $::font_sm -width 20 -anchor w -bg $::bg -fg $::fg
    checkbutton $w.tab_timer.timer_sec.alert.check -variable profile_config_timer_alert -font $::font_sm -bg $::bg -fg $::fg \
        -selectcolor $::bg_sel -activebackground $::bg -activeforeground $::fg \
        -borderwidth 1 -relief raised -highlightthickness 1 -highlightbackground $::fg_bar
    pack $w.tab_timer.timer_sec.alert.lbl -side left
    pack $w.tab_timer.timer_sec.alert.check -side left -padx {8 2}

    frame $w.tab_timer.timer_sec.show -bg $::bg
    pack $w.tab_timer.timer_sec.show -fill x -padx 12 -pady 4
    label $w.tab_timer.timer_sec.show.lbl -text [t chrono_show] -font $::font_sm -width 20 -anchor w -bg $::bg -fg $::fg
    checkbutton $w.tab_timer.timer_sec.show.check -variable profile_config_chrono_show -font $::font_sm -bg $::bg -fg $::fg \
        -selectcolor $::bg_sel -activebackground $::bg -activeforeground $::fg \
        -borderwidth 1 -relief raised -highlightthickness 1 -highlightbackground $::fg_bar
    pack $w.tab_timer.timer_sec.show.lbl -side left
    pack $w.tab_timer.timer_sec.show.check -side left -padx {8 2}

    # Load timer values from config
    set ::profile_config_timer_sound $::cfg_timer_sound
    set ::profile_config_timer_alert $::cfg_timer_alert
    set ::profile_config_chrono_show $::cfg_chrono_show
    set ::profile_config_timer_type $::cfg_timer_type
    $w.tab_timer.timer_sec.duration.spin set $::cfg_timer_duration

    # Update profile display when changed via trace
    trace add variable ::profile_config_profile write [list apply {{name1 name2 op} {
        profile-config-update-profile .profile_config
    }}]

    # Load initial values
    profile-config-update-profile $w

    # Button frame
    frame $w.btns -bg $::bg
    pack $w.btns -fill x -padx 8 -pady 8

    button $w.btns.apply -text [t profile_config_apply] -font $::font_sm \
        -bg $::bg_bar -fg $::fg_bar -width 12 \
        -command {
            set profile $::profile_config_profile
            set font [.profile_config.tab_profile.profile.ffont.entry get]
            set size [.profile_config.tab_profile.fsize.spin get]
            set mw [.profile_config.tab_profile.fmarginw.spin get]
            set mh [.profile_config.tab_profile.fmarginh.spin get]
            set goal [.profile_config.tab_profile.fwordgoal.spin get]
            set dark $::profile_config_dark_mode
            set def_prof $::profile_config_default_prof
            set def_scheme $::profile_config_default_scheme
            set def_lang $::profile_config_language
            set timer_dur [.profile_config.tab_timer.timer_sec.duration.spin get]
            set timer_snd $::profile_config_timer_sound
            set timer_alrt $::profile_config_timer_alert
            set timer_typ $::profile_config_timer_type
            set chrono_shw $::profile_config_chrono_show

            if {$font eq "" || $size eq "" || $mw eq "" || $mh eq ""} return

            dict set ::cfg_profiles $profile font_family $font
            dict set ::cfg_profiles $profile font_size $size
            dict set ::cfg_profiles $profile margin_width $mw
            dict set ::cfg_profiles $profile margin_height $mh
            dict set ::cfg_profiles $profile word_goal $goal
            dict set ::cfg_profiles $profile dark_mode $dark

            # Check if the profile being edited is currently active BEFORE changing ::cfg_profile
            set is_current_profile [expr {$profile eq $::cfg_profile}]

            set ::cfg_profile $def_prof
            set ::cfg_scheme $def_scheme
            set ::cfg_lang $def_lang
            set ::cfg_timer_duration $timer_dur
            set ::cfg_timer_sound $timer_snd
            set ::cfg_timer_alert $timer_alrt
            set ::cfg_timer_type $timer_typ
            set ::cfg_chrono_show $chrono_shw

            ini-save

            # Apply the selected scheme to update color variables
            scheme-apply $def_scheme
            lassign [theme-colors] bg fg bg_bar fg_bar bg_sel _ _ _ bg2
            set ::bg $bg
            set ::fg $fg
            set ::bg_bar $bg_bar
            set ::fg_bar $fg_bar
            set ::bg2 $bg2
            set ::bg_sel $bg_sel

            # Apply profile if it was the currently active one
            if {$is_current_profile} {
                profile-apply $profile
                if {[info exists ::editor_open]} {
                    set f [list $::cfg_font_family $::cfg_font_size]
                    set ::font $f
                    catch {.ed.t configure -font $f}
                    foreach side {l r} {
                        catch {.ed.pw.${side}.t configure -font $f}
                    }
                    .ed.t tag configure heading -font [list $::cfg_font_family $::cfg_font_size bold]
                    apply-line-spacing
                }
            }

            # Apply theme to update all GUI colors
            apply-theme

            catch {trace remove variable ::profile_config_profile write}
            destroy .profile_config
            br-reload
        }
    pack $w.btns.apply -side left -padx 4

    button $w.btns.cancel -text [t profile_config_cancel] -font $::font_sm \
        -bg $::bg_bar -fg $::fg_bar -width 12 -command {
            catch {trace remove variable ::profile_config_profile write}
            destroy .profile_config
        }
    pack $w.btns.cancel -side left -padx 4

    update
    set geom [wm geometry $w]
    set width [string range $geom 0 [string first x $geom]-1]
    if {$width < 550} {set width 550}
    wm geometry $w ${width}x[expr {[winfo height $w] + 20}]
    grab $w
    bind $w <Escape> {
        catch {trace remove variable ::profile_config_profile write}
        destroy .profile_config
    }
    focus $w.tab_profile.profile.ffont.entry
}

proc timer-alert-gui {} {
    do-beep
    set w .timer_alert
    catch {destroy $w}
    toplevel $w
    wm title $w "Timer Alert"
    wm transient $w .
    wm resizable $w 0 0
    label  $w.l -text "Timer finished!" -font [list [lindex $::font 0] 16 bold] -padx 20 -pady 20 -anchor c -bg $::bg -fg $::fg
    button $w.b -text "OK" -font $::font_sm -command [list destroy $w] -bg $::bg_bar -fg $::fg_bar
    pack $w.l -fill both -expand 1
    pack $w.b -pady 8
    update
    grab $w
    focus $w.b
}

proc help-dialog {} {
    set w .help
    catch {destroy $w}
    toplevel $w
    wm title $w "[t help_k_help] - Writhdeck"
    wm resizable $w 0 0
    wm transient $w .

    set hm $::cfg_heading_marker
    set sections {}
    set height 23
    set _ts [clock seconds]
    lappend sections [t help_writhdeck] [list \
        [t help_version]       $::version \
    ]
    lappend sections [t help_date_time_sect] [list \
        [t help_current_time]  [clock format $_ts -format "%H:%M:%S"] \
        [t help_date]          [clock format $_ts -format "%Y-%m-%d"] \
    ]
    incr height 5
    set _sel_txt ""
    catch { set _sel_txt [[active-ed] get sel.first sel.last] }
    if {$_sel_txt ne ""} {
        set _sel_wc [llength [regexp -all -inline {\S+} $_sel_txt]]
        set _sel_cc [string length $_sel_txt]
        lappend sections [t help_sel_info] [list \
            "Words"  $_sel_wc \
            "Chars"  $_sel_cc \
        ]
        incr height 4
    }
    if {$::filename ne ""} {
        set txt [.ed.t get 1.0 end-1c]
        set wc    [llength [regexp -all -inline {\S+} $txt]]
        set chars [string length $txt]
        set today_wc [daily-today $wc]
        set file_entries [list "Words" $wc "Chars" $chars]
        if {$::cfg_word_goal > 0} {
            lappend file_entries "Today" "+$today_wc / $::cfg_word_goal"
        } else {
            lappend file_entries "Today" "+$today_wc"
        }
        lappend sections [t help_file_info] $file_entries
        incr height 5
    }
    lappend sections \
        [t help_editor_sect] [list \
            [key-label $::cfg_key_save]         [t help_k_save] \
            [key-label $::cfg_key_save_as]      [t help_save_as] \
            [key-label $::cfg_key_close]        [t help_return_browser] \
            [key-label $::cfg_key_find]         [t help_find_next] \
            [key-label $::cfg_key_replace]      [t help_find_replace] \
            [key-label $::cfg_key_open]         [t help_k_open] \
            [key-label $::cfg_key_goto]         [t help_k_goto] \
            [key-label $::cfg_key_undo]         [t help_k_undo] \
            [key-label $::cfg_key_redo]         [t help_k_redo] \
            [key-label $::cfg_key_typewriter]   [t help_k_typewriter] \
            "Ctrl+Up/Dn / Ctrl+Lt/Rt"           [t help_para_word] \
            [key-label $::cfg_key_toc]          [format [t help_toc_marker] "${hm}title${hm}"] \
            [key-label $::cfg_key_fullscreen]   [t help_k_fullscreen] \
            [key-label $::cfg_key_split]        [t help_k_split] \
            [key-label $::cfg_key_split_focus]  [t help_k_split_focus] \
            [key-label $::cfg_key_workspace]    [t help_k_workspace] \
            [key-label $::cfg_key_help]         [t help_k_help] \
        ] \
        [t help_browser_sect] [list \
            [t help_double_click]               [t help_open] \
            "n"                                 [t br_help_new_file] \
            "t"                                 [t br_help_scratchpad] \
            "f"                                 [t br_help_toggle_fav] \
            "s"                                 [t br_help_writing_stats] \
            "b"                                 [t br_help_backup] \
            "i"                                 [t br_help_show_path] \
            "w"                                 [t br_help_word_occ] \
            "d"                                 [t br_help_delete_file] \
            "r"                                 [t br_help_rename_file] \
            "c"                                 [t br_help_font_settings] \
            "z"                                 [t br_help_reload] \
            [key-label $::cfg_key_toc]          [t br_help_browser_sections] \
            [key-label $::cfg_key_fullscreen]   [t br_help_fullscreen_br] \
            [key-label $::cfg_key_open]         [t br_help_open_file_br] \
            "h / [key-label $::cfg_key_help]"   [t br_help_help] \
            "q"                                 [t br_help_quit_app] \
        ]

    text $w.t \
        -font $::font_sm -state normal \
        -bg $::bg -fg $::fg \
        -borderwidth 0 -padx 16 -pady 12 \
        -width 60 -height $height \
        -cursor arrow
    $w.t tag configure heading -foreground $::fg_bar -font [concat $::font_sm bold]
    $w.t tag configure key     -foreground $::fg -font [concat $::font_sm bold]
    $w.t tag configure desc    -foreground $::fg

    foreach {section entries} $sections {
        $w.t insert end "\n $section\n" heading
        foreach {key desc} $entries {
            $w.t insert end [format "  %-20s" $key] key
            $w.t insert end "  $desc\n"             desc
        }
    }
    $w.t configure -state disabled

    button $w.ok -text [t dlg_cancel] -command [list destroy $w]
    pack $w.t  -fill both -expand 1
    catch {
        label $w.logo -image [image create photo -data $::_icon_b64] \
            -bg $::bg -pady 6
        pack $w.logo
    }
    pack $w.ok -pady 8

    update
    grab $w
    bind $w.t <Up>         {%W yview scroll -1 units; break}
    bind $w.t <Down>       {%W yview scroll  1 units; break}
    bind $w.t <Prior>      {%W yview scroll -5 units; break}
    bind $w.t <Next>       {%W yview scroll  5 units; break}
    bind $w.t <KeyPress-q> "[list after idle [list destroy $w]]; break"
    bind $w.t <Control-h>  "[list after idle [list destroy $w]]; break"
    bind $w   <Control-h>  [list after idle [list destroy $w]]
    focus $w.t
}

proc active-ed {} {
    if {$::split_mode} {
        set f [focus]
        if {$f eq ".ed.pw.r.t"} { return ".ed.pw.r.t" }
        return ".ed.pw.l.t"
    }
    return ".ed.t"
}

proc typewriter-center {t} {
    set bbox [$t dlineinfo insert]
    if {$bbox eq ""} return
    set ly    [lindex $bbox 1]
    set lh    [lindex $bbox 3]
    set wh    [winfo height $t]
    set delta [expr {int($ly + $lh/2 - $wh/2)}]
    if {abs($delta) < 2} return
    $t yview scroll $delta pixels
}

proc focus-para-update {t} {
    $t tag remove focus_dim 1.0 end
    set blank_before [$t search -backwards -regexp {^\s*$} "insert linestart - 1 char" 1.0]
    set para_start [expr {$blank_before eq "" ? "1.0" : [$t index "$blank_before + 1 line"]}]
    set blank_after [$t search -regexp {^\s*$} "insert lineend + 1 char" end]
    set para_end [expr {$blank_after eq "" ? "end" : [$t index "$blank_after lineend + 1 char"]}]
    if {[$t compare 1.0 < $para_start]} { $t tag add focus_dim 1.0 $para_start }
    if {[$t compare $para_end < end]}   { $t tag add focus_dim $para_end end }
}

proc typewriter-tick {t} {
    if {!$::typewriter_mode} return
    typewriter-center $t
    focus-para-update $t
}

proc typewriter-toggle {} {
    set ::typewriter_mode [expr {!$::typewriter_mode}]
    set c_comment [lindex [theme-colors] 6]
    foreach w [list .ed.t .ed.pw.l.t .ed.pw.r.t] {
        catch { $w tag configure focus_dim -foreground $c_comment }
        if {!$::typewriter_mode} { catch { $w tag remove focus_dim 1.0 end } }
    }
    if {$::cfg_hemingway_mode} {
        set _mw [expr {$::cfg_margin_width  * ($::typewriter_mode ? 2 : 1)}]
        set _mh [expr {$::cfg_margin_height * ($::typewriter_mode ? 2 : 1)}]
        set _sp [expr {$::cfg_split_shrink_margin ? max(1,$::cfg_margin_width/2) : $::cfg_margin_width}]
        set _sp [expr {$_sp * ($::typewriter_mode ? 2 : 1)}]
        catch { .ed.t configure -padx [expr {$_mw/3}] -pady [expr {$_mh/3}] }
        catch { pack configure .ed.t -padx [expr {$_mw - $_mw/3}] -pady [expr {$_mh - $_mh/3}] }
        foreach side {l r} {
            set _sp_in [expr {$_sp/3}]; set _sp_out [expr {$_sp - $_sp/3}]
            catch { .ed.pw.${side}.t configure -padx $_sp_in -pady [expr {$_mh/3}] }
            catch { pack configure .ed.pw.${side}.t -padx $_sp_out -pady [expr {$_mh - $_mh/3}] }
        }
        if {$::typewriter_mode} {
            catch { pack forget .ed.bar }
        } else {
            catch { pack .ed.bar -side bottom -fill x -before .ed.sb }
        }
    }
    if {$::typewriter_mode} { typewriter-tick [active-ed] }
}

proc goto-dialog {} {
    set t [active-ed]
    set n [input-dialog [t goto_title] [t goto_prompt]]
    if {[string is integer -strict $n] && $n >= 1} {
        set last [lindex [split [$t index end] .] 0]
        $t mark set insert [expr {min($n, $last - 1)}].0
        $t see insert
        focus $t
    }
}

# --- split view ---------------------------------------------------------------
set ::split_ln_was_on 0

proc primary-ed {} {
    if {$::split_mode} { return ".ed.pw.l.t" }
    return ".ed.t"
}

proc split-peer-modified {t} {
    if {[$t edit modified]} { set ::dirty 1; $t edit modified false }
    ed-status
    if {$::hl_after_id ne ""} { after cancel $::hl_after_id }
    set ::hl_after_id [after 300 { set ::hl_after_id ""; highlight-headings; ln-update }]
}

proc split-make-pane {side bg fg bg_bar bg_sel sp1 sp2 bg2} {
    set frame ".ed.pw.$side"
    frame $frame -bg $bg2
    scrollbar ${frame}.sb -orient vertical -bg $bg_bar -troughcolor $bg
    set _padx [expr {$::cfg_split_shrink_margin \
        ? max(1, $::cfg_margin_width / 2) : $::cfg_margin_width}]
    set _padx_in  [expr {$_padx/3}]
    set _padx_out [expr {$_padx - $_padx_in}]
    set _pady_in  [expr {$::cfg_margin_height/3}]
    set _pady_out [expr {$::cfg_margin_height - $_pady_in}]
    .ed.t peer create ${frame}.t \
        -wrap word -font [.ed.t cget -font] \
        -width 1 \
        -bg $bg -fg $fg \
        -insertbackground $fg -selectbackground $bg_sel -selectforeground $fg \
        -blockcursor 0 -insertwidth 2 -insertofftime 0 \
        -borderwidth 0 -padx $_padx_in -pady $_pady_in \
        -highlightthickness 2 -highlightbackground $bg -highlightcolor $fg \
        -yscrollcommand "${frame}.sb set" \
        -spacing1 $sp1 -spacing2 $sp2 -spacing3 0
    ${frame}.sb configure -command "${frame}.t yview"
    pack ${frame}.sb -side right -fill y
    pack ${frame}.t  -fill both  -expand 1 -padx $_padx_out -pady $_pady_out
    set t ${frame}.t
    bind $t <KeyRelease>                { ed-status }
    bind $t <ButtonRelease>             { ed-status }
    bind $t <<Modified>>                [list split-peer-modified $t]
    bind $t <$::cfg_key_save>           { save-file; break }
    bind $t <$::cfg_key_save_as>        { save-as; break }
    bind $t <$::cfg_key_close>          { close-editor; break }
    bind $t <$::cfg_key_paste>          { ed-paste; break }
    bind $t <$::cfg_key_select_all>     "[list $t tag add sel 1.0 end]; break"
    bind $t <$::cfg_key_dark_toggle>    { toggle-dark-mode; break }
    bind $t <Tab>                       "[list $t insert insert {\t}]; break"
    bind $t <$::cfg_key_goto>           { goto-dialog; break }
    bind $t <$::cfg_key_help>           { help-dialog; break }
    bind $t <$::cfg_key_undo>           "if {\$::typewriter_mode && \$::cfg_hemingway_mode} break; [list catch [list $t edit undo]]; ed-status; break"
    bind $t <$::cfg_key_redo>           "[list catch [list $t edit redo]]; ed-status; break"
    bind $t <$::cfg_key_find>           { search-open; break }
    bind $t <$::cfg_key_replace>        { replace-open; break }
    bind $t <$::cfg_key_open>           { open-file-dialog; break }
    bind $t <$::cfg_key_typewriter>     { typewriter-toggle; break }
    bind $t <KeyRelease>               +[list typewriter-tick $t]
    bind $t <ButtonRelease>            +[list typewriter-tick $t]
    foreach _k {Left Right Up Down BackSpace Delete} {
        bind $t <$_k> "if {\$::typewriter_mode && \$::cfg_hemingway_mode} break"
    }
    bind $t <$::cfg_key_toc>            { toc-show; break }
    bind $t <$::cfg_key_line_numbers>   { ln-toggle; break }
    bind $t <$::cfg_key_fullscreen>     { toggle-fullscreen; break }
    bind $t <$::cfg_key_split>          { split-toggle; break }
    bind $t <$::cfg_key_split_focus>    { split-cycle-focus; break }
    bind $t <$::cfg_key_workspace>      { workspace-toggle; break }
    bind $t <Control-equal>             { font-resize  1; break }
    bind $t <Control-plus>              { font-resize  1; break }
    bind $t <Control-KP_Add>            { font-resize  1; break }
    bind $t <Control-minus>             { font-resize -1; break }
    bind $t <Control-KP_Subtract>       { font-resize -1; break }
}

proc split-open {} {
    wm geometry . [winfo width .]x[winfo height .]
    lassign [theme-colors] bg fg bg_bar fg_bar bg_sel _ _ _ bg2
    set sp1 [.ed.t cget -spacing1]
    set sp2 [.ed.t cget -spacing2]
    set cur [.ed.t index insert]

    pack forget .ed.t .ed.sb
    if {[winfo exists .ed.ln]} {
        set ::split_ln_was_on 1
        pack forget .ed.ln
    } else {
        set ::split_ln_was_on 0
    }

    panedwindow .ed.pw -orient horizontal -bg $bg_bar -sashwidth 4 -sashpad 0 -sashrelief flat
    split-make-pane l $bg $fg $bg_bar $bg_sel $sp1 $sp2 $bg2
    split-make-pane r $bg $fg $bg_bar $bg_sel $sp1 $sp2 $bg2
    .ed.pw add .ed.pw.l -stretch always
    .ed.pw add .ed.pw.r -stretch always
    pack .ed.pw -fill both -expand 1 -before .ed.bar

    .ed.pw.l.t mark set insert $cur
    .ed.pw.l.t see insert

    set ::split_mode 1
    focus .ed.pw.l.t
}

proc split-close {} {
    if {!$::split_mode} return
    if {$::split_ws2_mode} {
        split-ws2-save-state
        set ::split_ws2_mode 0
    }
    catch { .ed.t mark set insert [.ed.pw.l.t index insert] }
    pack forget .ed.pw
    destroy .ed.pw
    pack .ed.sb  -side right -fill y
    if {$::split_ln_was_on && [winfo exists .ed.ln]} {
        pack .ed.ln -side left  -fill y
    }
    pack .ed.t -fill both -expand 1 \
        -padx [expr {$::cfg_margin_width - $::cfg_margin_width/3}] \
        -pady [expr {$::cfg_margin_height - $::cfg_margin_height/3}]
    .ed.t see insert
    set ::split_mode 0
    focus .ed.t
}

proc split-toggle {} {
    if {$::split_mode} { split-close } else { split-open }
}

proc split-cycle-focus {} {
    if {!$::split_mode} return
    if {[focus] eq ".ed.pw.r.t"} {
        focus .ed.pw.l.t
    } else {
        focus .ed.pw.r.t
    }
}

proc split-ws2-open {} {
    lassign [theme-colors] bg fg bg_bar fg_bar bg_sel _ _ _ bg2
    set sp1 [.ed.t cget -spacing1]
    set sp2 [.ed.t cget -spacing2]
    set _padx [expr {$::cfg_split_shrink_margin ? max(1,$::cfg_margin_width/2) : $::cfg_margin_width}]
    set _padx_in  [expr {$_padx/3}]
    set _padx_out [expr {$_padx - $_padx_in}]
    set _pady_in  [expr {$::cfg_margin_height/3}]
    set _pady_out [expr {$::cfg_margin_height - $_pady_in}]
    catch { pack forget .ed.pw.r.sb .ed.pw.r.t }
    catch { destroy .ed.pw.r.t }
    text .ed.pw.r.t \
        -wrap word -font [.ed.t cget -font] -width 1 \
        -bg $bg -fg $fg -insertbackground $fg \
        -selectbackground $bg_sel -selectforeground $fg \
        -blockcursor 0 -insertwidth 2 -insertofftime 0 \
        -borderwidth 0 -padx $_padx_in -pady $_pady_in \
        -highlightthickness 2 -highlightbackground $bg -highlightcolor $fg \
        -yscrollcommand ".ed.pw.r.sb set" -spacing1 $sp1 -spacing2 $sp2 -spacing3 0
    .ed.pw.r.sb configure -command ".ed.pw.r.t yview"
    pack .ed.pw.r.sb -side right -fill y
    pack .ed.pw.r.t  -fill both  -expand 1 -padx $_padx_out -pady $_pady_out
    .ed.pw.r.t configure -undo 0
    .ed.pw.r.t delete 1.0 end
    if {$::ws2_content ne ""} { .ed.pw.r.t insert 1.0 $::ws2_content }
    .ed.pw.r.t edit reset
    .ed.pw.r.t edit modified false
    .ed.pw.r.t configure -undo 1
    if {$::ws2_dirty} { .ed.pw.r.t edit modified true }
    catch { .ed.pw.r.t mark set insert $::ws2_cursor }
    .ed.pw.r.t see insert
    bind .ed.pw.r.t <<Modified>>             { split-ws2-track-dirty }
    bind .ed.pw.r.t <KeyRelease>             { ed-status }
    bind .ed.pw.r.t <ButtonRelease>          { ed-status }
    bind .ed.pw.r.t <$::cfg_key_save>        { split-ws2-save; break }
    bind .ed.pw.r.t <$::cfg_key_save_as>     { split-ws2-save-as; break }
    bind .ed.pw.r.t <$::cfg_key_close>       { split-toggle; break }
    bind .ed.pw.r.t <$::cfg_key_paste>       { ed-paste; break }
    bind .ed.pw.r.t <$::cfg_key_select_all>  { .ed.pw.r.t tag add sel 1.0 end; break }
    bind .ed.pw.r.t <$::cfg_key_dark_toggle> { toggle-dark-mode; break }
    bind .ed.pw.r.t <Tab>                    { .ed.pw.r.t insert insert "\t"; break }
    bind .ed.pw.r.t <$::cfg_key_goto>        { goto-dialog; break }
    bind .ed.pw.r.t <$::cfg_key_help>        { help-dialog; break }
    bind .ed.pw.r.t <$::cfg_key_undo>        { catch {.ed.pw.r.t edit undo}; ed-status; break }
    bind .ed.pw.r.t <$::cfg_key_redo>        { catch {.ed.pw.r.t edit redo}; ed-status; break }
    bind .ed.pw.r.t <$::cfg_key_find>        { search-open; break }
    bind .ed.pw.r.t <$::cfg_key_open>        { open-file-dialog; break }
    bind .ed.pw.r.t <$::cfg_key_split>       { split-toggle; break }
    bind .ed.pw.r.t <$::cfg_key_split_focus> { split-cycle-focus; break }
    bind .ed.pw.r.t <$::cfg_key_workspace>   { workspace-toggle; break }
    bind .ed.pw.r.t <Control-equal>          { font-resize  1; break }
    bind .ed.pw.r.t <Control-plus>           { font-resize  1; break }
    bind .ed.pw.r.t <Control-KP_Add>         { font-resize  1; break }
    bind .ed.pw.r.t <Control-minus>          { font-resize -1; break }
    bind .ed.pw.r.t <Control-KP_Subtract>    { font-resize -1; break }
    set ::ws_dual_mode 1
    set ::split_ws2_mode 1
    focus .ed.pw.r.t
}

proc split-ws2-track-dirty {} {
    if {[.ed.pw.r.t edit modified]} { set ::ws2_dirty 1; .ed.pw.r.t edit modified false }
    ed-status
}

proc split-ws2-save {} {
    if {$::ws2_filename eq ""} { split-ws2-save-as; return }
    set fh [open $::ws2_filename w]; chan configure $fh -encoding utf-8
    puts -nonewline $fh [.ed.pw.r.t get 1.0 {end - 1 chars}]; close $fh
    set ::ws2_dirty 0
    .ed.pw.r.t edit modified false
    set ::ws2_file_mtime [file mtime $::ws2_filename]
    ed-status
}

proc split-ws2-save-as {} {
    set dir [expr {$::ws2_filename ne "" ? [file dirname $::ws2_filename] : $::DOCS_DIR_DEFAULT}]
    set name [string trim [input-dialog "Save as" "Save as:"]]
    if {$name eq ""} return
    if {[file extension $name] eq ""} { append name $::FILE_EXT }
    set new_path [file join $dir $name]
    if {[file exists $new_path] && $new_path ne $::ws2_filename} {
        if {[confirm-dialog "\"$name\" already exists. Overwrite?"] ne "yes"} return
    }
    set ::ws2_filename $new_path
    set ::ws2_scratchpad 0
    split-ws2-save
}

proc split-ws2-load-file {path} {
    .ed.pw.r.t configure -undo 0
    .ed.pw.r.t delete 1.0 end
    if {[file exists $path] && [file size $path] > 0} {
        set fh [open $path r]; chan configure $fh -encoding utf-8
        .ed.pw.r.t insert 1.0 [read $fh]; close $fh
    }
    .ed.pw.r.t edit reset; .ed.pw.r.t edit modified false
    .ed.pw.r.t configure -undo 1
    set ::ws2_filename $path; set ::ws2_scratchpad 0; set ::ws2_dirty 0
    set ::ws2_file_mtime [expr {[file exists $path] ? [file mtime $path] : 0}]
    recent-push $path
    .ed.pw.r.t mark set insert 1.0; .ed.pw.r.t see insert
    ed-status
}

proc split-ws2-save-state {} {
    if {![winfo exists .ed.pw.r.t]} return
    set ::ws2_content [.ed.pw.r.t get 1.0 end-1c]
    set ::ws2_cursor  [.ed.pw.r.t index insert]
}

proc workspace-toggle {} {
    if {$::split_mode} {
        if {$::split_ws2_mode} { split-cycle-focus } else { split-ws2-open }
        return
    }
    set ::ws_dual_mode 1
    set cur_content [.ed.t get 1.0 end-1c]
    set cur_cursor  [.ed.t index insert]
    if {$::ws_n == 1} {
        set ::ws1_filename   $::filename
        set ::ws1_scratchpad $::scratchpad
        set ::ws1_dirty      $::dirty
        set ::ws1_content    $cur_content
        set ::ws1_cursor     $cur_cursor
        set ::ws1_file_mtime $::file_mtime_known
        set new_fn    $::ws2_filename
        set new_sp    $::ws2_scratchpad
        set new_d     $::ws2_dirty
        set new_c     $::ws2_content
        set new_pos   $::ws2_cursor
        set new_mtime $::ws2_file_mtime
        set ::ws_n 2
    } else {
        set ::ws2_filename   $::filename
        set ::ws2_scratchpad $::scratchpad
        set ::ws2_dirty      $::dirty
        set ::ws2_content    $cur_content
        set ::ws2_cursor     $cur_cursor
        set ::ws2_file_mtime $::file_mtime_known
        set new_fn    $::ws1_filename
        set new_sp    $::ws1_scratchpad
        set new_d     $::ws1_dirty
        set new_c     $::ws1_content
        set new_pos   $::ws1_cursor
        set new_mtime $::ws1_file_mtime
        set ::ws_n 1
    }
    .ed.t configure -undo 0
    .ed.t delete 1.0 end
    if {$new_c ne ""} { .ed.t insert 1.0 $new_c }
    .ed.t edit reset
    .ed.t edit modified false
    .ed.t configure -undo 1
    set ::filename   $new_fn
    set ::scratchpad $new_sp
    set ::dirty      $new_d
    if {$new_d} { .ed.t edit modified true }
    set ::file_mtime_known $new_mtime
    if {$::watch_after_id ne ""} { after cancel $::watch_after_id; set ::watch_after_id "" }
    if {$::filename ne "" && !$::scratchpad} {
        set ::watch_after_id [after 2000 watch-file]
    }
    set ::ln_last_count 0
    set ::gui_wc_line_cache {}
    set ::gui_wc_last_nlines 0
    catch { .ed.t mark set insert $new_pos }
    .ed.t see insert
    ed-update-title
    highlight-headings
    ed-status
    focus .ed.t
}

# --- frame switching ----------------------------------------------------------
proc watch-file {} {
    set ::watch_after_id ""
    if {$::cfg_watch_file && $::filename ne "" && !$::scratchpad \
            && [file exists $::filename]} {
        set mtime [file mtime $::filename]
        if {$mtime != $::file_mtime_known} {
            set ::file_mtime_known $mtime
            set _key [expr {$::dirty ? "ed_watch_reload_dirty" : "ed_watch_reload"}]
            if {[confirm-dialog [t $_key [file tail $::filename]]] eq "yes"} {
                load-file $::filename
            }
        }
    }
    set ::watch_after_id [after 2000 watch-file]
}

proc show-browser {} {
    pack forget .ed
    pack .br -fill both -expand 1
    br-refresh
    focus .br.mid.lst
}

proc ini-reload {} {
    ini-load
    markers-update
    if {$::cfg_font_family ne "Mono" && \
            [lsearch -exact [font families] $::cfg_font_family] < 0} {
        set ::cfg_font_family "Mono"
    }
    if {$::cfg_bar_font_family ne "Mono" && \
            [lsearch -exact [font families] $::cfg_bar_font_family] < 0} {
        set ::cfg_bar_font_family "Mono"
    }
    set f [list $::cfg_font_family $::cfg_font_size]
    set ::font $f
    set _bpad [expr {$::cfg_bar_height > 0 \
        ? min(2, max(0, ($::cfg_bar_height - 6) / 2)) : 0}]
    set ::font_sm [expr {$::cfg_bar_height > 0 \
        ? [list $::cfg_bar_font_family [expr {-max(6, $::cfg_bar_height - 2*$_bpad)}]] \
        : [list $::cfg_bar_font_family 10]}]
    catch { .ed.t configure -font $f \
        -padx [expr {$::cfg_margin_width/3}] -pady [expr {$::cfg_margin_height/3}] \
        -blockcursor 0 \
        -insertwidth [expr {$::cfg_block_cursor_gui ? 0 : 2}] \
        -insertofftime [expr {$::cfg_block_cursor_gui ? 0 : ($::cfg_blink_cursor ? 300 : 0)}] }
    catch { pack configure .ed.t \
        -padx [expr {$::cfg_margin_width - $::cfg_margin_width/3}] \
        -pady [expr {$::cfg_margin_height - $::cfg_margin_height/3}] }
    catch { .ed.t tag configure heading -font [list $::cfg_font_family $::cfg_font_size bold] }
    foreach side {l r} {
        catch { .ed.pw.${side}.t configure -font $f }
    }
    foreach _w {.ed.bar.left .ed.bar.right .ed.bar.msg .ed.bar.center .ed.bar.help
                .ed.sf.lbl .ed.sf.cnt .ed.sf.r.lbl .ed.sf.r.one .ed.sf.r.all
                .br.bar.left .br.bar.right} {
        catch { $_w configure -font $::font_sm }
    }
    catch { apply-theme }
    catch { apply-line-spacing }
}

proc open-scratchpad {} {
    set ::ws_n 1
    pack forget .br
    pack .ed -fill both -expand 1
    ini-reload
    .ed.t configure -undo 0
    .ed.t delete 1.0 end
    .ed.t edit reset
    .ed.t edit modified false
    .ed.t configure -undo 1
    set ::filename  ""
    set ::scratchpad 1
    set ::dirty     0
    set ::ln_last_count 0
    set ::gui_wc_line_cache {}
    set ::gui_wc_last_nlines 0
    ed-update-title
    highlight-headings
    ed-status
    focus .ed.t
}

proc show-editor {path} {
    if {[winfo ismapped .br]} { set ::ws_n 1 }
    set ::scratchpad 0
    pack forget .br
    pack .ed -fill both -expand 1
    ini-reload
    load-file $path
    recent-push $path
    set _wc [llength [regexp -all -inline {\S+} [[primary-ed] get 1.0 end-1c]]]
    daily-open $path $_wc
    focus .ed.t
}

} ;# end if {!$::no_gui}
