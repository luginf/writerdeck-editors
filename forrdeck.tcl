#!/usr/bin/env tclsh
# forrdeck-tk.tcl — Tk/TUI text editor with file browser
# Usage: tclsh forrdeck-tk.tcl [--no-gui] [filename]

set ::no_gui [expr {[lsearch $::argv "--no-gui"] >= 0}]
if {$::no_gui} {
    set ::argv [lsearch -all -inline -not $::argv "--no-gui"]
    set ::argc [llength $::argv]
}
if {!$::no_gui} {
    # auto-detect: no graphical display available
    set _has_display [expr {
        ([info exists ::env(DISPLAY)]          && $::env(DISPLAY)          ne "") ||
        ([info exists ::env(WAYLAND_DISPLAY)]  && $::env(WAYLAND_DISPLAY)  ne "")
    }]
    if {!$_has_display || [catch {package require Tk}]} {
        set ::no_gui 1
    }
    unset _has_display
}

set ::DOCS_DIR_DEFAULT [file join $::env(HOME) Documents forrdeck]
set ::DOCS_DIR         $::DOCS_DIR_DEFAULT
set ::INI_FILE         [file join $::DOCS_DIR_DEFAULT "forrdeck.ini"]
set ::FILE_EXT ".txt"
set ::filename ""
set ::dirty    0
set ::msg      ""

file mkdir $::DOCS_DIR_DEFAULT
set ::CURSOR_FILE [file join $::DOCS_DIR_DEFAULT ".cursors.json"]

# ─── cursor persistence (JSON, compatible with forrdeck.lua) ──────────────────
proc cursors-load {} {
    if {![file exists $::CURSOR_FILE]} { return {} }
    set fh [open $::CURSOR_FILE r]; fconfigure $fh -encoding utf-8
    set raw [read $fh]; close $fh
    set d {}
    set re {"([^"\\]*)"\s*:\s*\[(\d+)\s*,\s*(\d+)\]"}
    set start 0
    while {[regexp -start $start $re $raw -> key cy cx]} {
        dict set d $key [list [expr {int($cy)}] [expr {int($cx)}]]
        set idx [string first "\"$key\"" $raw $start]
        set start [expr {$idx + [string length $key] + 2}]
    }
    return $d
}

proc cursors-save {d} {
    set parts {}
    dict for {k v} $d {
        set ke [string map {\\ \\\\ \" \\\"} $k]
        lappend parts "\"$ke\":\[[lindex $v 0],[lindex $v 1]\]"
    }
    set fh [open $::CURSOR_FILE w]; fconfigure $fh -encoding utf-8
    puts $fh "\{[join $parts ,]\}"
    close $fh
}

proc cursor-get {filepath} {
    if {!$::cfg_cursor_restore} { return {1 0} }
    set d [cursors-load]
    if {[dict exists $d $filepath]} {
        lassign [dict get $d $filepath] cy cx
        return [list [expr {$cy + 1}] $cx]
    }
    return {1 0}
}

proc cursor-put {filepath cy cx} {
    if {!$::cfg_cursor_restore} return
    set d [cursors-load]
    dict set d $filepath [list [expr {$cy - 1}] $cx]
    cursors-save $d
}

# ─── ini ──────────────────────────────────────────────────────────────────────
set ::cfg_margin_width   60
set ::cfg_margin_height  40
set ::cfg_font_size      13
set ::cfg_fullscreen_key Alt-Return
set ::cfg_bg             "#1a1a1a"
set ::cfg_fg             "#e8e8e8"
set ::cfg_bg_bar         "#2a2a2a"
set ::cfg_fg_bar         "#aaaaaa"
set ::cfg_bg_sel         "#3a5a8a"
set ::cfg_docs_dir       ""
set ::cfg_margin_cols    0
set ::cfg_margin_rows    0
set ::cfg_heading_marker "="
set ::cfg_toc_key        "F11"
set ::cfg_color_heading  "#c8a060"
set ::cfg_line_numbers   0
set ::cfg_cursor_restore 1
set ::fullscreen 0

proc ini-load {} {
    if {![file exists $::INI_FILE]} { ini-save; return }
    set fh [open $::INI_FILE r]
    fconfigure $fh -encoding utf-8
    while {[gets $fh line] >= 0} {
        set line [string trim $line]
        if {$line eq "" || [string match "#*" $line] || [string match {\[*} $line]} continue
        if {[regexp {^(\w+)\s*=\s*(.+)$} $line -> key val]} {
            switch [string trim $key] {
                margin_width   { set ::cfg_margin_width   [string trim $val] }
                margin_height  { set ::cfg_margin_height  [string trim $val] }
                font_size      { set ::cfg_font_size      [string trim $val] }
                fullscreen_key { set ::cfg_fullscreen_key [string trim $val] }
                color_bg       { set ::cfg_bg             [string trim $val] }
                color_fg       { set ::cfg_fg             [string trim $val] }
                color_bg_bar   { set ::cfg_bg_bar         [string trim $val] }
                color_fg_bar   { set ::cfg_fg_bar         [string trim $val] }
                docs_dir         { set ::cfg_docs_dir       [string trim $val] }
                margin_cols      { set ::cfg_margin_cols    [string trim $val] }
                margin_rows      { set ::cfg_margin_rows    [string trim $val] }
                color_bg_sel     { set ::cfg_bg_sel         [string trim $val] }
                heading_marker   { set ::cfg_heading_marker [string trim $val] }
                toc_key          { set ::cfg_toc_key        [string trim $val] }
                color_heading    { set ::cfg_color_heading  [string trim $val] }
                line_numbers     { set ::cfg_line_numbers   [string trim $val] }
                cursor_restore   { set ::cfg_cursor_restore [string trim $val] }
            }
        }
    }
    close $fh
}

proc ini-save {} {
    set fh [open $::INI_FILE w]
    fconfigure $fh -encoding utf-8
    puts $fh "# Forrdeck — configuration"
    puts $fh "\[editor\]"
    puts $fh "# docs_dir = ~/Documents/writerdeck"
    puts $fh "# (default: ~/Documents/forrdeck)"
    puts $fh "margin_width   = $::cfg_margin_width"
    puts $fh "margin_height  = $::cfg_margin_height"
    puts $fh "font_size      = $::cfg_font_size"
    puts $fh "fullscreen_key = $::cfg_fullscreen_key"
    puts $fh ""
    puts $fh "# colors (#rrggbb format)"
    puts $fh "color_bg       = $::cfg_bg"
    puts $fh "color_fg       = $::cfg_fg"
    puts $fh "color_bg_bar   = $::cfg_bg_bar"
    puts $fh "color_fg_bar   = $::cfg_fg_bar"
    puts $fh "color_bg_sel   = $::cfg_bg_sel"
    puts $fh ""
    puts $fh "# ── terminal version (forrdeck.lua) — values in columns/lines"
    puts $fh "margin_cols = $::cfg_margin_cols"
    puts $fh "margin_rows = $::cfg_margin_rows"
    puts $fh ""
    puts $fh "# headings / table of contents"
    puts $fh "heading_marker = $::cfg_heading_marker"
    puts $fh "toc_key        = $::cfg_toc_key"
    puts $fh "color_heading  = $::cfg_color_heading"
    puts $fh ""
    puts $fh "# ── editor behaviour"
    puts $fh "# line_numbers   = 0  (1 = show line numbers in left margin)"
    puts $fh "# cursor_restore = 1  (0 = always open at line 1)"
    puts $fh ""
    puts $fh "# ── light theme (solarized light) ─────────────────────────────"
    puts $fh "# To enable: uncomment the lines below and comment out the"
    puts $fh "# color_* values defined above."
    puts $fh "#color_bg      = #fdf6e3"
    puts $fh "#color_fg      = #657b83"
    puts $fh "#color_bg_bar  = #eee8d5"
    puts $fh "#color_fg_bar  = #93a1a1"
    puts $fh "#color_bg_sel  = #268bd2"
    puts $fh "#color_heading = #b58900"
    close $fh
}

ini-load

if {$::cfg_docs_dir ne ""} {
    set ::DOCS_DIR [file normalize $::cfg_docs_dir]
    if {$::DOCS_DIR eq $::DOCS_DIR_DEFAULT} { set ::DOCS_DIR $::DOCS_DIR_DEFAULT }
    file mkdir $::DOCS_DIR
}

# ─── config ───────────────────────────────────────────────────────────────────
set font    [list Mono $::cfg_font_size]
set font_sm {Mono 10}
set bg      $::cfg_bg
set fg      $::cfg_fg
set bg_bar  $::cfg_bg_bar
set fg_bar  $::cfg_fg_bar
set bg_sel  $::cfg_bg_sel
set fg_dim  "#666666"
# expose as globals for use in procs
set ::bg     $bg
set ::fg     $fg
set ::bg_bar $bg_bar
set ::fg_bar $fg_bar
set ::bg_sel $bg_sel

# ─── utils ────────────────────────────────────────────────────────────────────
proc list-docs {dir} {
    set pairs {}
    foreach f [glob -nocomplain -directory $dir -tails *] {
        set full [file join $dir $f]
        if {[file isfile $full] && ![string match .* $f]} {
            lappend pairs [list [file mtime $full] $f]
        }
    }
    set result {}
    foreach item [lsort -integer -decreasing -index 0 $pairs] {
        lappend result [lindex $item 1]
    }
    return $result
}

proc br-dirs {} {
    if {$::DOCS_DIR ne $::DOCS_DIR_DEFAULT} {
        return [list $::DOCS_DIR_DEFAULT $::DOCS_DIR]
    }
    return [list $::DOCS_DIR_DEFAULT]
}

proc br-multi {} { return [expr {[llength [br-dirs]] > 1}] }

proc heading-re {} {
    set m [regsub -all {[\\^$.|?*+()\[\]{}]} $::cfg_heading_marker {\\&}]
    return "^\\s*${m}\\s*(.+?)\\s*${m}\\s*$"
}

proc parse-heading {line} {
    if {[regexp [heading-re] $line -> title]}              { return [string trim $title] }
    if {[regexp {^\s*(#{1,6})\s+(.+)$} $line -> _ title]} { return [string trim $title] }
    return ""
}

proc fmt-meta {path} {
    set sz [file size $path]
    set sz_str [expr {$sz < 1024 ? "${sz}B" : "[expr {$sz/1024}]K"}]
    set mt [clock format [file mtime $path] -format "%d %b %H:%M"]
    return [format "%6s  %s" $sz_str $mt]
}

if {!$::no_gui} {
wm title . "Forrdeck"
wm minsize . 500 400

# ─── browser frame ────────────────────────────────────────────────────────────
frame .br -bg $bg

label .br.title \
    -text " Forrdeck" \
    -bg $bg -fg $fg \
    -font [list [lindex $font 0] 15 bold] \
    -anchor w -pady 10 -padx 4
pack .br.title -fill x

frame .br.mid -bg $bg
listbox .br.mid.lst \
    -bg $bg -fg $fg -font $font \
    -selectbackground $bg_sel -selectforeground $fg \
    -activestyle none -borderwidth 0 -highlightthickness 0 \
    -yscrollcommand {.br.mid.sb set}
scrollbar .br.mid.sb -orient vertical -command {.br.mid.lst yview} \
    -bg $bg_bar -troughcolor $bg
pack .br.mid.sb  -side right -fill y
pack .br.mid.lst -fill both  -expand 1
pack .br.mid     -fill both  -expand 1

frame .br.bar -bg $bg_bar
label .br.bar.help \
    -text " ↵ open  n new  d delete  r rename  q quit  h help" \
    -bg $bg_bar -fg $fg_bar -font $font_sm -anchor w -padx 4
label .br.bar.cnt -textvariable ::br_status \
    -bg $bg_bar -fg $fg_bar -font $font_sm -anchor e -padx 8
pack .br.bar.help -side left
pack .br.bar.cnt  -side right
pack .br.bar -side bottom -fill x

# browser state — each entry: {type dir name}  (type = header | file)
set ::br_entries {}

proc br-refresh {} {
    # remember selection by identity
    set prev ""
    set sel [.br.mid.lst curselection]
    if {[llength $sel]} {
        lassign [lindex $::br_entries [lindex $sel 0]] type dir name
        if {$type eq "file"} { set prev "$dir|$name" }
    }

    set ::br_entries {}
    set total 0
    foreach dir [br-dirs] {
        if {[br-multi]} { lappend ::br_entries [list header $dir ""] }
        foreach f [list-docs $dir] {
            lappend ::br_entries [list file $dir $f]
            incr total
        }
    }

    .br.mid.lst delete 0 end
    set new_sel -1
    set first_file -1
    for {set i 0} {$i < [llength $::br_entries]} {incr i} {
        lassign [lindex $::br_entries $i] type dir name
        if {$type eq "header"} {
            set label [string map [list $::env(HOME) ~] $dir]
            .br.mid.lst insert end " $label"
            .br.mid.lst itemconfigure $i -foreground $::fg_bar \
                -selectforeground $::fg_bar -selectbackground $::bg_bar
        } else {
            set meta [fmt-meta [file join $dir $name]]
            .br.mid.lst insert end [format "  %-36s %s" $name $meta]
            if {$first_file < 0} { set first_file $i }
            if {"$dir|$name" eq $prev} { set new_sel $i }
        }
    }

    set s [expr {$total != 1 ? "s" : ""}]
    set ::br_status " $total file${s} "

    if {$total > 0} {
        if {$new_sel < 0} { set new_sel $first_file }
        .br.mid.lst selection set $new_sel
        .br.mid.lst see $new_sel
    }
}

# returns {type dir name} of selected entry, or {} if none/header
proc br-selected {} {
    set sel [.br.mid.lst curselection]
    if {![llength $sel]} { return {} }
    set e [lindex $::br_entries [lindex $sel 0]]
    if {[lindex $e 0] ne "file"} { return {} }
    return $e
}

# returns the dir of the section containing the current selection
proc br-active-dir {} {
    set sel [.br.mid.lst curselection]
    set i [expr {[llength $sel] ? [lindex $sel 0] : 0}]
    while {$i >= 0} {
        lassign [lindex $::br_entries $i] type dir
        if {$type eq "header"} { return $dir }
        incr i -1
    }
    return $::DOCS_DIR_DEFAULT
}

proc br-open {} {
    set e [br-selected]
    if {![llength $e]} return
    show-editor [file join [lindex $e 1] [lindex $e 2]]
}

# ─── browser dialogs ──────────────────────────────────────────────────────────
proc input-dialog {title prompt} {
    set w .dlg
    catch {destroy $w}
    toplevel $w
    wm title $w $title
    wm resizable $w 0 0
    wm transient $w .
    grab $w

    label $w.l -text $prompt -padx 12 -pady 8 -anchor w
    entry $w.e -width 28
    frame $w.f
    button $w.f.ok -text "OK"      -command {set ::dlg_val [.dlg.e get]; destroy .dlg}
    button $w.f.cn -text "Annuler" -command {set ::dlg_val ""; destroy .dlg}
    pack $w.f.ok $w.f.cn -side left -padx 4 -pady 6

    pack $w.l -fill x
    pack $w.e -fill x -padx 12
    pack $w.f

    bind $w.e <Return> {set ::dlg_val [.dlg.e get]; destroy .dlg}
    bind $w    <Escape> {set ::dlg_val ""; destroy .dlg}
    focus $w.e

    set ::dlg_val ""
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
        tk_messageBox -message "\"$name\" already exists." -icon warning -parent .
        return
    }
    close [open $full w]
    show-editor $full
}

proc br-delete {} {
    set e [br-selected]
    if {![llength $e]} return
    lassign $e _ dir name
    set r [tk_messageBox -message "Delete \"$name\"?" \
           -type yesno -icon question -parent .]
    if {$r eq "yes"} {
        file delete [file join $dir $name]
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
        tk_messageBox -message "\"$new\" already exists." -icon warning -parent .
        return
    }
    file rename [file join $dir $name] $new_path
    br-refresh
}

bind .br.mid.lst <Return>      { br-open }
bind .br.mid.lst <Double-1>    { br-open }
bind .br.mid.lst <n>           { br-new }
bind .br.mid.lst <d>           { br-delete }
bind .br.mid.lst <r>           { br-rename }
bind .br.mid.lst <q>           { exit }

bind .br.mid.lst <Up> {
    set i [lindex [concat [.br.mid.lst curselection] 1] 0]
    incr i -1
    while {$i >= 0 && [lindex [lindex $::br_entries $i] 0] eq "header"} { incr i -1 }
    if {$i >= 0} { .br.mid.lst selection clear 0 end; .br.mid.lst selection set $i; .br.mid.lst see $i }
    break
}
bind .br.mid.lst <Down> {
    set last [expr {[.br.mid.lst size] - 1}]
    set i [lindex [concat [.br.mid.lst curselection] -1] 0]
    incr i
    while {$i <= $last && [lindex [lindex $::br_entries $i] 0] eq "header"} { incr i }
    if {$i <= $last} { .br.mid.lst selection clear 0 end; .br.mid.lst selection set $i; .br.mid.lst see $i }
    break
}

# ─── editor frame ─────────────────────────────────────────────────────────────
frame .ed -bg $bg

text .ed.t \
    -wrap word -font $font \
    -bg $bg -fg $fg \
    -insertbackground $fg \
    -selectbackground $bg_sel \
    -borderwidth 0 -padx $::cfg_margin_width -pady $::cfg_margin_height \
    -undo 1

scrollbar .ed.sb -orient vertical -command {.ed.t yview} \
    -bg $bg_bar -troughcolor $bg

proc ed-yscroll {first last} {
    .ed.sb set $first $last
    catch { .ed.ln yview moveto $first }
}
.ed.t configure -yscrollcommand ed-yscroll
.ed.t tag configure heading \
    -foreground $::cfg_color_heading \
    -font [list Mono $::cfg_font_size bold]

frame .ed.bar -bg $bg_bar
label .ed.bar.lbl -textvariable ::ed_status \
    -bg $bg_bar -fg $fg_bar -font $font_sm -anchor w -padx 8
label .ed.bar.help \
    -text "^S save  ^Q close  ^F find  ^H replace  ^G goto  ^O open  F1 help" \
    -bg $bg_bar -fg $fg_bar -font $font_sm -anchor e -padx 8
pack .ed.bar.lbl  -side left
pack .ed.bar.help -side right
pack .ed.bar -side bottom -fill x
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
pack .ed.t   -fill both   -expand 1

# ─── search bar (hidden until Ctrl+F) ────────────────────────────────────────
set ::search_term  ""
set ::search_count ""

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

# ─── editor status ────────────────────────────────────────────────────────────
proc ed-status {} {
    set d  [expr {$::dirty ? "* " : "  "}]
    set fn [expr {$::filename eq "" ? "\[new\]" : [file tail $::filename]}]
    lassign [split [.ed.t index insert] .] ln col
    set m  [expr {$::msg ne "" ? "   | $::msg" : ""}]
    set ::ed_status "${d}${fn}   Ln ${ln}  Col [expr {$col + 1}]${m}"
}

proc set-msg {text} {
    set ::msg $text
    ed-status
    after 2000 { set ::msg ""; ed-status }
}

bind .ed.t <KeyRelease>    { ed-status }
bind .ed.t <ButtonRelease> { ed-status }
bind .ed.t <<Modified>> {
    if {[.ed.t edit modified]} { set ::dirty 1; .ed.t edit modified false }
    ed-status
    after idle { highlight-headings; ln-update }
}

proc ln-update {} {
    if {![winfo exists .ed.ln]} return
    set last [lindex [split [.ed.t index end] .] 0]
    .ed.ln configure -state normal
    .ed.ln delete 1.0 end
    for {set i 1} {$i < $last} {incr i} {
        .ed.ln insert end [format "%3d\n" $i]
    }
    .ed.ln configure -state disabled
    catch { .ed.ln yview moveto [lindex [.ed.t yview] 0] }
}

# ─── file I/O ─────────────────────────────────────────────────────────────────
proc load-file {path} {
    set ::filename $path
    wm title . "Forrdeck — [file tail $path]"
    .ed.t delete 1.0 end
    if {[file exists $path] && [file size $path] > 0} {
        set fh [open $path r]
        fconfigure $fh -encoding utf-8
        .ed.t insert 1.0 [read $fh]
        close $fh
    }
    .ed.t edit modified false
    set ::dirty 0
    lassign [cursor-get $path] cy cx
    .ed.t mark set insert ${cy}.${cx}
    .ed.t see insert
    ed-status
    highlight-headings
    ln-update
}

proc save-file {} {
    if {$::filename eq ""} return
    set fh [open $::filename w]
    fconfigure $fh -encoding utf-8
    puts -nonewline $fh [.ed.t get 1.0 {end - 1 chars}]
    close $fh
    set ::dirty 0
    .ed.t edit modified false
    lassign [split [.ed.t index insert] .] cy cx
    cursor-put $::filename $cy $cx
    set-msg "saved"
}

proc save-as {} {
    set dir [expr {$::filename ne "" ? [file dirname $::filename] : $::DOCS_DIR_DEFAULT}]
    set name [input-dialog "Save as" "Save as:"]
    set name [string trim $name]
    if {$name eq ""} return
    if {[file extension $name] eq ""} { append name $::FILE_EXT }
    set new_path [file join $dir $name]
    if {[file exists $new_path] && $new_path ne $::filename} {
        set r [tk_messageBox -message "\"$name\" already exists. Overwrite?" \
               -type yesno -icon question -parent .]
        if {$r ne "yes"} return
    }
    set ::filename $new_path
    wm title . "Forrdeck — [file tail $new_path]"
    save-file
}

proc search-open {} {
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
    set repl [.ed.sf.r.e get]
    set slen [string length $::search_term]
    set pos [.ed.t search -nocase -exact -- $::search_term insert end]
    if {$pos eq ""} { set pos [.ed.t search -nocase -exact -- $::search_term 1.0 end] }
    if {$pos ne ""} {
        .ed.t delete $pos "$pos + ${slen} chars"
        .ed.t insert $pos $repl
        .ed.t mark set insert "$pos + [string length $repl] chars"
        .ed.t see insert
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
    focus .ed.t
    set ::search_count ""
}

proc search-update {} {
    set term [.ed.sf.e get]
    .ed.t tag remove found 1.0 end
    set ::search_count ""
    if {$term eq ""} return
    set ::search_term $term
    set count 0; set pos 1.0
    while 1 {
        set pos [.ed.t search -nocase -forwards -count len -- $term $pos end]
        if {$pos eq ""} break
        .ed.t tag add found $pos "$pos + $len chars"
        incr count; set pos "$pos + $len chars"
    }
    .ed.t tag configure found -background "#5a3a00" -foreground "#ffdd88"
    set plural [expr {$count != 1 ? "s" : ""}]
    set ::search_count " $count match${plural}"
    set pos [.ed.t search -nocase -forwards -- $term insert end]
    if {$pos eq ""} { set pos [.ed.t search -nocase -forwards -- $term 1.0 end] }
    if {$pos ne ""} { .ed.t mark set insert $pos; .ed.t see insert }
}

proc search-next {} {
    if {$::search_term eq ""} return
    set pos [.ed.t search -nocase -forwards -- $::search_term "insert + 1 chars" end]
    if {$pos eq ""} { set pos [.ed.t search -nocase -forwards -- $::search_term 1.0 end] }
    if {$pos ne ""} { .ed.t mark set insert $pos; .ed.t see insert }
}

proc search-prev {} {
    if {$::search_term eq ""} return
    set pos [.ed.t search -nocase -backwards -- $::search_term insert 1.0]
    if {$pos eq ""} { set pos [.ed.t search -nocase -backwards -- $::search_term end 1.0] }
    if {$pos ne ""} { .ed.t mark set insert $pos; .ed.t see insert }
}

proc close-editor {} {
    if {$::dirty} {
        set r [tk_messageBox \
            -message "Save \"[file tail $::filename]\" before closing?" \
            -type yesnocancel -icon question -default yes -parent .]
        if {$r eq "cancel"} return
        if {$r eq "yes"}    save-file
    }
    if {$::filename ne ""} {
        lassign [split [.ed.t index insert] .] cy cx
        cursor-put $::filename $cy $cx
    }
    set ::filename ""
    set ::dirty    0
    set ::msg      ""
    wm title . "Forrdeck"
    .ed.t delete 1.0 end
    search-close
    show-browser
}

# ─── editor bindings ──────────────────────────────────────────────────────────
bind .ed.t <Control-s> { save-file;    break }
bind .ed.t <Control-S> { save-as;     break }
bind .ed.t <Control-q> { close-editor; break }
bind .ed.t <Control-w> { close-editor; break }
bind .ed.t <Escape>    { close-editor; break }

bind .ed.t <Control-k> { break }

bind .ed.t <Tab>          { .ed.t insert insert "    "; break }
bind .ed.t <Control-g>   { goto-dialog; break }
bind .ed.t <Control-h>   { replace-open; break }
bind .ed.t <Control-f>   { search-open; break }
bind .ed.t <Control-o>   { open-file-dialog; break }
bind .ed.t <F1>          { help-dialog; break }

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
bind .br.mid.lst <h>  { help-dialog }
bind .br.mid.lst <F1> { help-dialog }

proc open-file-dialog {} {
    set path [tk_getOpenFile \
        -initialdir $::DOCS_DIR_DEFAULT \
        -filetypes {{"Text files" {.txt}} {"All files" *}}]
    if {$path ne ""} { show-editor $path }
}

bind .br.mid.lst <Control-o> { open-file-dialog }

proc toggle-fullscreen {} {
    set ::fullscreen [expr {!$::fullscreen}]
    wm attributes . -fullscreen $::fullscreen
}

bind .ed.t          <$::cfg_fullscreen_key> { toggle-fullscreen; break }
bind .br.mid.lst    <$::cfg_fullscreen_key> { toggle-fullscreen }

# ─── headings & TOC ───────────────────────────────────────────────────────────
proc highlight-headings {} {
    .ed.t tag remove heading 1.0 end
    set last [lindex [split [.ed.t index end] .] 0]
    for {set ln 1} {$ln < $last} {incr ln} {
        set line [.ed.t get $ln.0 "$ln.0 lineend"]
        if {[parse-heading $line] ne ""} {
            .ed.t tag add heading $ln.0 "$ln.0 lineend"
        }
    }
}

proc toc-collect {} {
    set last [lindex [split [.ed.t index end] .] 0]
    set result {}
    for {set ln 1} {$ln < $last} {incr ln} {
        set line [.ed.t get $ln.0 "$ln.0 lineend"]
        set title [parse-heading $line]
        if {$title ne ""} { lappend result [list $ln $title] }
    }
    return $result
}

proc toc-show {} {
    set headings [toc-collect]
    if {![llength $headings]} { set-msg "aucun titre trouvé"; return }

    set w .toc
    catch {destroy $w}
    toplevel $w
    wm title $w "Table des matières"
    wm resizable $w 1 0
    wm transient $w .

    set h [expr {min([llength $headings], 24)}]
    listbox $w.lst \
        -font $::font -bg $::bg -fg $::cfg_color_heading \
        -selectbackground $::bg_sel -selectforeground $::fg \
        -activestyle none -borderwidth 0 -highlightthickness 0 \
        -width 48 -height $h
    pack $w.lst -fill both -expand 1 -padx 2 -pady 2

    foreach item $headings {
        lassign $item ln title
        $w.lst insert end [format "  %4d   %s" $ln $title]
    }
    $w.lst selection set 0

    bind $w.lst <Return>   [list toc-jump $w $headings]
    bind $w.lst <Double-1> [list toc-jump $w $headings]
    bind $w     <Escape>   [list destroy $w]
    bind $w     <$::cfg_toc_key> [list destroy $w]
    focus $w.lst
}

proc toc-jump {w headings} {
    set sel [$w.lst curselection]
    if {![llength $sel]} return
    set ln [lindex [lindex $headings [lindex $sel 0]] 0]
    destroy $w
    .ed.t mark set insert $ln.0
    .ed.t see insert
    focus .ed.t
}

bind .ed.t <$::cfg_toc_key> { toc-show; break }

# ─── taille de police dynamique ───────────────────────────────────────────────
proc font-resize {delta} {
    set ::cfg_font_size [expr {max(6, min(72, $::cfg_font_size + $delta))}]
    set f [list Mono $::cfg_font_size]
    .ed.t configure -font $f
    .ed.t tag configure heading -font [list Mono $::cfg_font_size bold]
}

bind .ed.t <Control-equal>    { font-resize  1; break }
bind .ed.t <Control-plus>    { font-resize  1; break }
bind .ed.t <Control-KP_Add>  { font-resize  1; break }
bind .ed.t <Control-minus>   { font-resize -1; break }
bind .ed.t <Control-KP_Subtract> { font-resize -1; break }

proc help-dialog {} {
    set w .help
    catch {destroy $w}
    toplevel $w
    wm title $w "Help — Forrdeck"
    wm resizable $w 0 0
    wm transient $w .
    grab $w

    set fs_key  $::cfg_fullscreen_key
    set toc_key $::cfg_toc_key
    set hm      $::cfg_heading_marker
    set sections [list \
        "EDITOR" [list \
            "Ctrl+S"       "Save" \
            "Ctrl+Shift+S" "Save as" \
            "Ctrl+Q / ESC" "Save and return to browser" \
            "Ctrl+K"       "Delete to end of line" \
            "Ctrl+F"       "Find (Enter: next  Shift+Enter: prev)" \
            "Ctrl+H"       "Find & Replace (Enter: replace one  Ctrl+Enter: all)" \
            "Ctrl+O"       "Open file" \
            "Ctrl+G"       "Go to line" \
            "Ctrl+Z"       "Undo" \
            "Tab"          "Insert 4 spaces" \
            $toc_key       "Table des matières  (${hm}titre${hm})" \
            $fs_key        "Plein écran" \
            "Ctrl+H"       "Cette aide" \
        ] \
        "BROWSER" [list \
            "↵ / double-click"  "Ouvrir" \
            "n"                 "Nouveau fichier" \
            "d"                 "Supprimer" \
            "r"                 "Renommer" \
            $fs_key             "Plein écran" \
            "Ctrl+O"            "Open file" \
            "h / F1"            "Help" \
            "q"                 "Quit" \
        ] \
    ]

    text $w.t \
        -font {Mono 11} -state normal \
        -bg "#1a1a1a" -fg "#e8e8e8" \
        -borderwidth 0 -padx 16 -pady 12 \
        -width 52 -height 22 \
        -cursor arrow
    $w.t tag configure heading -foreground "#aaaaaa" -font {Mono 11 bold}
    $w.t tag configure key     -foreground "#7ab0d4"
    $w.t tag configure desc    -foreground "#e8e8e8"

    foreach {section entries} $sections {
        $w.t insert end "\n $section\n" heading
        foreach {key desc} $entries {
            $w.t insert end [format "  %-20s" $key] key
            $w.t insert end "  $desc\n"             desc
        }
    }
    $w.t configure -state disabled

    button $w.ok -text "Close" -command [list destroy $w]
    pack $w.t  -fill both -expand 1
    pack $w.ok -pady 8

    bind $w <Escape>    [list destroy $w]
    bind $w <Return>    [list destroy $w]
    bind $w <Control-h> [list destroy $w]
    focus $w.ok
}

proc goto-dialog {} {
    set w .goto
    catch {destroy $w}
    toplevel $w
    wm title $w "Aller à la ligne"
    wm resizable $w 0 0
    wm transient $w .
    grab $w

    label $w.l -text "Aller à la ligne :" -padx 12 -pady 8 -anchor w
    entry $w.e -width 8
    frame $w.f
    button $w.f.ok -text "OK"      -command [list goto-apply $w]
    button $w.f.cn -text "Annuler" -command [list destroy $w]
    pack $w.f.ok $w.f.cn -side left -padx 4 -pady 6
    pack $w.l -fill x
    pack $w.e -fill x -padx 12
    pack $w.f

    bind $w.e <Return> [list goto-apply $w]
    bind $w    <Escape> [list destroy $w]
    focus $w.e
}

proc goto-apply {w} {
    set n [$w.e get]
    if {[string is integer -strict $n] && $n >= 1} {
        set last [lindex [split [.ed.t index end] .] 0]
        .ed.t mark set insert [expr {min($n, $last - 1)}].0
        .ed.t see insert
        focus .ed.t
    }
    destroy $w
}

# ─── frame switching ──────────────────────────────────────────────────────────
proc show-browser {} {
    pack forget .ed
    pack .br -fill both -expand 1
    br-refresh
    focus .br.mid.lst
}

proc show-editor {path} {
    pack forget .br
    pack .ed -fill both -expand 1
    load-file $path
    focus .ed.t
}

} ;# end if {!$::no_gui}

# ─── TUI mode ─────────────────────────────────────────────────────────────────

set ::tui_stty ""

proc tui-init {} {
    catch { set ::tui_stty [exec stty -g <@stdin] }
    catch { exec stty raw -echo <@stdin }
    fconfigure stdin  -blocking 1 -translation binary -buffering none
    fconfigure stdout -encoding utf-8 -buffering none
    puts -nonewline "\033\[?25l\033\[2J\033\[?2004h"
    flush stdout
}

proc tui-cleanup {} {
    puts -nonewline "\033\[?2004l\033\[?25h\033\[2J\033\[H"
    flush stdout
    if {$::tui_stty ne ""} { catch {exec stty $::tui_stty <@stdin}
    } else                 { catch {exec stty sane <@stdin} }
}

proc tui-size {} {
    if {[catch {scan [exec stty size <@stdin] "%d %d" r c} ]} { return {24 80} }
    return [list $r $c]
}

proc tui-move {row col} { puts -nonewline "\033\[[expr {$row+1}];[expr {$col+1}]H" }

proc tui-attr {a} {
    switch $a {
        bold    { puts -nonewline "\033\[1m" }
        reverse { puts -nonewline "\033\[7m" }
        dim     { puts -nonewline "\033\[2m" }
        off     { puts -nonewline "\033\[0m" }
    }
}

proc tui-fill {row text cols} {
    tui-move $row 0
    set text [string range $text 0 [expr {$cols-1}]]
    puts -nonewline "${text}[string repeat { } [expr {$cols - [string length $text]}]]"
}

proc tui-bar {row left right cols} {
    tui-attr reverse
    set gap [expr {max(0, $cols - [string length $left] - [string length $right])}]
    tui-fill $row "[string range $left 0 [expr {$cols-1}]][string repeat { } $gap]$right" $cols
    tui-attr off
}

proc tui-help {row text cols} {
    tui-attr dim; tui-fill $row " $text" $cols; tui-attr off
}

proc tui-getch {} {
    set raw [read stdin 1]
    if {$raw eq ""} { return "" }
    scan $raw %c b
    if {$b == 27} {
        # Read escape sequence byte by byte, stop at terminator
        set seq ""
        while {[string length $seq] < 20} {
            fconfigure stdin -blocking 0
            set ch [read stdin 1]
            fconfigure stdin -blocking 1
            if {$ch eq ""} break
            append seq $ch
            if {[regexp {[A-Za-z~]} $ch]} break
        }
        # bracketed paste: \x1b[200~ ... pasted text ... \x1b[201~
        if {[string range $seq 0 4] eq "\[200~"} {
            set pasted [string range $seq 5 end]
            while 1 {
                set ch [read stdin 1]
                if {$ch eq ""} break
                append pasted $ch
                if {[string match "*\x1b\[201~" $pasted]} {
                    set pasted [string range $pasted 0 end-6]
                    break
                }
            }
            return "PASTE:$pasted"
        }
        switch -exact -- "\x1b$seq" {
            "\x1b\[A"     { return UP    }  "\x1b\[B"     { return DOWN  }
            "\x1b\[C"     { return RIGHT }  "\x1b\[D"     { return LEFT  }
            "\x1b\[H"     { return HOME  }  "\x1b\[F"     { return END   }
            "\x1b\[1~"    { return HOME  }  "\x1b\[4~"    { return END   }
            "\x1b\[3~"    { return DC    }  "\x1b\[5~"    { return PPAGE }
            "\x1b\[6~"    { return NPAGE }  "\x1b\[23~"   { return F11   }
            "\x1b\[24~"   { return F12   }
            "\x1b\[1;2A"  { return SHIFT-UP    }
            "\x1b\[1;2B"  { return SHIFT-DOWN  }
            "\x1b\[1;2C"  { return SHIFT-RIGHT }
            "\x1b\[1;2D"  { return SHIFT-LEFT  }
            "\x1b\[a"     { return SHIFT-UP    }
            "\x1b\[b"     { return SHIFT-DOWN  }
            "\x1b\[c"     { return SHIFT-RIGHT }
            "\x1b\[d"     { return SHIFT-LEFT  }
        }
        return ESC
    }
    # UTF-8 multi-byte
    if {$b >= 0xC0 && $b < 0xE0} {
        return [encoding convertfrom utf-8 "${raw}[read stdin 1]"]
    } elseif {$b >= 0xE0 && $b < 0xF0} {
        return [encoding convertfrom utf-8 "${raw}[read stdin 2]"]
    } elseif {$b >= 0xF0} {
        return [encoding convertfrom utf-8 "${raw}[read stdin 3]"]
    }
    if {$b == 127 || $b == 8}  { return BACKSPACE }
    if {$b == 13  || $b == 10} { return ENTER }
    if {$b == 9}               { return TAB }
    return [format %c $b]
}

# ── Word wrap ─────────────────────────────────────────────────────────────────

proc tui-wrap-line {line width} {
    set len [string length $line]
    if {$width <= 0} { return [list [list 0 $len]] }
    if {$len == 0}   { return [list [list 0 0]] }
    set segs {}; set pos 0
    while {$pos < $len} {
        if {$len - $pos <= $width} { lappend segs [list $pos $len]; break }
        set ce [expr {$pos + $width}]
        set sub [string range $line $pos [expr {$ce-1}]]
        set lsp -1
        for {set i [expr {[string length $sub]-1}]} {$i >= 0} {incr i -1} {
            if {[string index $sub $i] eq " "} { set lsp $i; break }
        }
        if {$lsp > 0} {
            set ba [expr {$pos+$lsp}]; lappend segs [list $pos $ba]; set pos [expr {$ba+1}]
        } else { lappend segs [list $pos $ce]; set pos $ce }
    }
    return $segs
}

proc tui-wrap-map {lines width} {
    set vrows {}; set li 1
    foreach line $lines {
        foreach seg [tui-wrap-line $line $width] {
            lappend vrows [list $li [lindex $seg 0] [lindex $seg 1]]
        }
        incr li
    }
    return $vrows
}

proc tui-l2v {vrows cy cx} {
    set n [llength $vrows]
    for {set vi 0} {$vi < $n} {incr vi} {
        lassign [lindex $vrows $vi] li scol ecol
        if {$li == $cy && $scol <= $cx && $cx <= $ecol} {
            set nx [expr {$vi+1}]
            if {$cx == $ecol && $ecol > $scol && $nx < $n && [lindex [lindex $vrows $nx] 0] == $li} continue
            return [list $vi [expr {$cx - $scol}]]
        }
    }
    if {$n > 0} {
        lassign [lindex $vrows [expr {$n-1}]] li scol ecol
        return [list [expr {$n-1}] [expr {max(0, min($cx-$scol, $ecol-$scol))}]]
    }
    return {0 0}
}

proc tui-v2l {vrows vi scx} {
    set n [llength $vrows]
    if {$n == 0} { return {1 0} }
    set vi [expr {max(0, min($vi, $n-1))}]
    lassign [lindex $vrows $vi] li scol ecol
    return [list $li [expr {$scol + max(0, min($scx, $ecol-$scol))}]]
}

# ── TUI helpers ───────────────────────────────────────────────────────────────

proc tui-prompt {label rows cols} {
    set buf ""
    while 1 {
        set d " $label$buf"
        tui-bar [expr {$rows-1}] $d "" $cols
        puts -nonewline "\033\[?25h"; tui-move [expr {$rows-1}] [string length $d]; flush stdout
        set k [tui-getch]; puts -nonewline "\033\[?25l"
        switch -- $k {
            ESC       { return "" }   ENTER { return $buf }
            BACKSPACE { set buf [string range $buf 0 end-1] }
            default   { if {[string length $k] == 1 || [string length $k] > 1} { append buf $k } }
        }
    }
}

proc tui-confirm {msg rows cols} {
    tui-bar [expr {$rows-1}] " $msg (y/n)" "" $cols; flush stdout
    while 1 {
        set k [tui-getch]
        if {$k in {y Y}} { return 1 }
        if {$k in {n N ESC}} { return 0 }
    }
}

proc tui-active-dir {entries cfi} {
    set i [expr {$cfi >= 0 ? $cfi : 0}]
    while {$i >= 0} {
        lassign [lindex $entries $i] type dir
        if {$type eq "header"} { return $dir }
        incr i -1
    }
    return $::DOCS_DIR_DEFAULT
}

# ── Clipboard ────────────────────────────────────────────────────────────────

set ::tui_clipboard ""

proc tui-copy {text} {
    set ::tui_clipboard $text
    foreach cmd {
        {xclip -selection clipboard}
        {xsel --clipboard --input}
        {wl-copy}
    } {
        if {![catch { set fh [open "| $cmd" w]; puts -nonewline $fh $text; close $fh }]} return
    }
}

proc tui-paste {} {
    foreach cmd {
        {xclip -selection clipboard -o}
        {xsel --clipboard --output}
        {wl-paste --no-newline}
    } {
        if {![catch {set r [exec {*}$cmd]}]} { return $r }
    }
    return $::tui_clipboard
}

# ── Selection helpers ─────────────────────────────────────────────────────────

proc tui-sel-range {anchor cy cx} {
    if {$anchor eq ""} { return {} }
    lassign $anchor aly alx
    if {$aly < $cy || ($aly == $cy && $alx <= $cx)} {
        return [list $aly $alx $cy $cx]
    }
    return [list $cy $cx $aly $alx]
}

proc tui-sel-text {lines anchor cy cx} {
    set r [tui-sel-range $anchor $cy $cx]
    if {$r eq {}} { return "" }
    lassign $r sly scx ely ecx
    set out {}
    for {set li $sly} {$li <= $ely} {incr li} {
        set l [lindex $lines [expr {$li-1}]]
        if {$li == $sly && $li == $ely} {
            lappend out [string range $l $scx [expr {$ecx-1}]]
        } elseif {$li == $sly} {
            lappend out [string range $l $scx end]
        } elseif {$li == $ely} {
            lappend out [string range $l 0 [expr {$ecx-1}]]
        } else {
            lappend out $l
        }
    }
    return [join $out "\n"]
}

proc tui-sel-delete {lines anchor cy cx} {
    set r [tui-sel-range $anchor $cy $cx]
    if {$r eq {}} { return [list $lines $cy $cx] }
    lassign $r sly scx ely ecx
    set pre  [string range [lindex $lines [expr {$sly-1}]] 0 [expr {$scx-1}]]
    set post [string range [lindex $lines [expr {$ely-1}]] $ecx end]
    set new  [lreplace $lines [expr {$sly-1}] [expr {$ely-1}] "${pre}${post}"]
    return [list $new $sly $scx]
}

# ── TUI Browser ───────────────────────────────────────────────────────────────

proc tui-browser {} {
    set sel 0; set scroll 0; set msg ""
    while 1 {
        lassign [tui-size] rows cols
        puts -nonewline "\033\[2J"
        # build entries
        set entries {}; set fcount 0
        foreach dir [br-dirs] {
            if {[br-multi]} { lappend entries [list header $dir ""] }
            foreach f [list-docs $dir] { lappend entries [list file $dir $f]; incr fcount }
        }
        set fidx {}
        for {set i 0} {$i < [llength $entries]} {incr i} {
            if {[lindex [lindex $entries $i] 0] eq "file"} { lappend fidx $i }
        }
        set nf [llength $fidx]
        if {$nf > 0} { set sel [expr {max(0, min($sel, $nf-1))}] }

        tui-attr bold; tui-fill 0 " Forrdeck" $cols; tui-attr off
        set usable [expr {$rows - 3}]

        if {$nf == 0} {
            set m "No documents yet. Press n to create one."
            tui-move [expr {$rows/2}] [expr {max(0, ($cols-[string length $m])/2)}]
            puts -nonewline $m
        } else {
            set sel_ei [lindex $fidx $sel]
            if {$sel_ei < $scroll}             { set scroll $sel_ei }
            if {$sel_ei >= $scroll + $usable}  { set scroll [expr {$sel_ei - $usable + 1}] }
            if {$scroll < 0} { set scroll 0 }
            set row 1; set ei 0
            foreach entry $entries {
                if {$ei < $scroll} { incr ei; continue }
                if {$row >= $rows-2} break
                lassign $entry type dir name
                if {$type eq "header"} {
                    set lbl [string map [list $::env(HOME) ~] $dir]
                    tui-attr dim; tui-fill $row " $lbl" $cols; tui-attr off
                } else {
                    set fi [lsearch $fidx $ei]; set issel [expr {$fi == $sel}]
                    set fp [file join $dir $name]
                    set sz [file size $fp]
                    set ss [expr {$sz < 1024 ? "${sz}B" : "[expr {$sz/1024}]K"}]
                    set mt [clock format [file mtime $fp] -format "%b %d %H:%M"]
                    set meta [format "%6s  %s" $ss $mt]
                    set maxn [expr {$cols - 3 - [string length $meta] - 1}]
                    set dn   [string range $name 0 [expr {max(0,$maxn-1)}]]
                    set gap  [string repeat " " [expr {max(0,$cols-3-[string length $dn]-[string length $meta])}]]
                    set pfx  [expr {$issel ? " \u00bb " : "   "}]
                    if {$issel} { tui-attr reverse }
                    tui-fill $row [string range "${pfx}${dn}${gap}${meta}" 0 [expr {$cols-1}]] $cols
                    if {$issel} { tui-attr off }
                }
                incr row; incr ei
            }
        }
        set plu [expr {$fcount != 1 ? "s" : ""}]
        tui-help [expr {$rows-2}] "\u21b5 open  n new  d delete  r rename  q/^Q quit" $cols
        if {$msg ne ""} { tui-bar [expr {$rows-1}] " $msg" "" $cols; set msg ""
        } else { tui-bar [expr {$rows-1}] " [string map [list $::env(HOME) ~] $::DOCS_DIR_DEFAULT]" \
                         " $fcount file${plu} " $cols }
        flush stdout

        set key [tui-getch]
        set cfi [expr {$nf > 0 ? [lindex $fidx $sel] : -1}]
        switch -- $key {
            q - "\x11" { return "" }
            UP - k  { if {$sel > 0} { incr sel -1 } }
            DOWN - j { if {$sel < $nf-1} { incr sel 1 } }
            HOME    { set sel 0 }
            END     { set sel [expr {max(0,$nf-1)}] }
            ENTER {
                if {$cfi >= 0} { lassign [lindex $entries $cfi] _ dir name; return [file join $dir $name] }
            }
            n {
                set dir [tui-active-dir $entries $cfi]
                set name [string trim [tui-prompt "new file: " $rows $cols]]
                if {$name ne ""} {
                    if {[file extension $name] eq ""} { append name $::FILE_EXT }
                    set fp [file join $dir $name]
                    if {[file exists $fp]} { set msg "'$name' already exists"
                    } else { close [open $fp w]; return $fp }
                }
            }
            d {
                if {$cfi >= 0} {
                    lassign [lindex $entries $cfi] _ dir name
                    if {[tui-confirm "delete '$name'?" $rows $cols]} {
                        file delete [file join $dir $name]
                        set msg "deleted '$name'"; if {$sel > 0} { incr sel -1 }
                    }
                }
            }
            r {
                if {$cfi >= 0} {
                    lassign [lindex $entries $cfi] _ dir name
                    set new [string trim [tui-prompt "rename '$name' to: " $rows $cols]]
                    if {$new ne ""} {
                        if {[file extension $new] eq ""} { append new $::FILE_EXT }
                        set np [file join $dir $new]
                        if {[file exists $np]} { set msg "'$new' already exists"
                        } else { file rename [file join $dir $name] $np; set msg "renamed \u2192 '$new'" }
                    }
                }
            }
        }
    }
}

# ── TUI TOC ───────────────────────────────────────────────────────────────────

proc tui-toc {lines rows cols} {
    set headings {}; set ln 1
    foreach line $lines {
        set t [parse-heading $line]
        if {$t ne ""} { lappend headings [list $ln $t] }
        incr ln
    }
    if {![llength $headings]} { return -1 }
    set sel 0; set scroll 0
    while 1 {
        puts -nonewline "\033\[2J"
        set usable [expr {$rows-3}]
        if {$sel < $scroll}            { set scroll $sel }
        if {$sel >= $scroll + $usable} { set scroll [expr {$sel - $usable + 1}] }
        tui-attr bold; tui-fill 0 " Table of contents" $cols; tui-attr off
        for {set i 0} {$i < $usable} {incr i} {
            set idx [expr {$scroll+$i}]
            if {$idx >= [llength $headings]} break
            lassign [lindex $headings $idx] ln title
            set line [format "  %4d   %s" $ln $title]
            if {$idx == $sel} { tui-attr reverse }
            tui-fill [expr {$i+1}] [string range $line 0 [expr {$cols-1}]] $cols
            if {$idx == $sel} { tui-attr off }
        }
        set nh [llength $headings]; set plu [expr {$nh != 1 ? "s" : ""}]
        tui-help [expr {$rows-2}] "\u21b5 jump  esc cancel" $cols
        tui-bar  [expr {$rows-1}] " $nh heading${plu}" "" $cols
        flush stdout
        switch -- [tui-getch] {
            ESC      { return -1 }
            UP - k   { if {$sel > 0} { incr sel -1 } }
            DOWN - j { if {$sel < $nh-1} { incr sel 1 } }
            HOME     { set sel 0 }
            END      { set sel [expr {$nh-1}] }
            ENTER    { return [lindex [lindex $headings $sel] 0] }
        }
    }
}

# ── TUI Editor ────────────────────────────────────────────────────────────────

proc tui-editor {filepath} {
    # ── load ──────────────────────────────────────────────────────────────────
    set lines {}
    if {[file exists $filepath] && [file size $filepath] > 0} {
        set fh [open $filepath r]; fconfigure $fh -encoding utf-8
        set content [read $fh]; close $fh
        foreach line [split $content "\n"] { lappend lines $line }
        if {[llength $lines] > 1 && [lindex $lines end] eq ""} {
            set lines [lrange $lines 0 end-1]
        }
    }
    if {[llength $lines] == 0} { set lines [list ""] }

    # ── cursor restore ────────────────────────────────────────────────────────
    lassign [cursor-get $filepath] cy cx
    set cy [expr {max(1, min($cy, [llength $lines]))}]
    set cx [expr {max(0, min($cx, [string length [lindex $lines [expr {$cy-1}]]]))}]

    set scroll_y 0
    set dirty 0; set message ""; set msg_time 0; set sticky -1
    set undo_stack {}
    set sel_anchor ""
    set sel_sticky  0
    if {![info exists ::tui_search]}  { set ::tui_search  "" }
    if {![info exists ::tui_replace]} { set ::tui_replace "" }

    # push-undo: call before any destructive edit
    set push_undo {
        lappend undo_stack [list $lines $cy $cx]
        if {[llength $undo_stack] > 100} { set undo_stack [lrange $undo_stack end-99 end] }
    }

    while 1 {
        lassign [tui-size] rows cols

        # ── layout ────────────────────────────────────────────────────────────
        set roff  $::cfg_margin_rows
        set marg  $::cfg_margin_cols
        set ln_w  [expr {$::cfg_line_numbers ? [string length [llength $lines]] + 2 : 0}]
        set coff  [expr {$marg + $ln_w}]
        set tw    [expr {max(1, $cols - $coff - $marg - 1)}]   ;# -1 for scroll indicator
        set th    [expr {max(1, $rows - 2 - 2*$roff)}]

        set cy [expr {max(1, min($cy, [llength $lines]))}]
        set cx [expr {max(0, min($cx, [string length [lindex $lines [expr {$cy-1}]]]))}]

        set vrows [tui-wrap-map $lines $tw]
        lassign [tui-l2v $vrows $cy $cx] vi scx

        if {$vi < $scroll_y}        { set scroll_y $vi }
        if {$vi >= $scroll_y + $th} { set scroll_y [expr {$vi - $th + 1}] }
        set scroll_y [expr {max(0, min($scroll_y, max(0, [llength $vrows] - $th)))}]

        # ── draw ──────────────────────────────────────────────────────────────
        puts -nonewline "\033\[2J"
        set sel_r [tui-sel-range $sel_anchor $cy $cx]

        for {set i 0} {$i < $th} {incr i} {
            set vi2 [expr {$scroll_y + $i}]
            if {$vi2 >= [llength $vrows]} break
            lassign [lindex $vrows $vi2] li scol ecol
            set line_text [lindex $lines [expr {$li-1}]]
            set seg [string range $line_text $scol [expr {$ecol-1}]]
            set ish [expr {[parse-heading $line_text] ne ""}]
            set srow [expr {$i + $roff}]

            # line number
            if {$ln_w > 0 && $scol == 0} {
                tui-attr dim
                tui-move $srow $marg
                puts -nonewline [format "%[expr {$ln_w-1}]d " $li]
                tui-attr off
            } elseif {$ln_w > 0} {
                tui-move $srow $marg
                puts -nonewline [string repeat " " $ln_w]
            }

            # text (with selection highlight)
            tui-move $srow $coff
            if {$sel_r ne {}} {
                lassign $sel_r sly scx_s ely ecx_s
                set seg_len [string length $seg]
                for {set ci 0} {$ci < $seg_len} {incr ci} {
                    set abs [expr {$scol + $ci}]
                    set in_sel 0
                    if {$li > $sly && $li < $ely} {
                        set in_sel 1
                    } elseif {$li == $sly && $li == $ely} {
                        set in_sel [expr {$abs >= $scx_s && $abs < $ecx_s}]
                    } elseif {$li == $sly} {
                        set in_sel [expr {$abs >= $scx_s}]
                    } elseif {$li == $ely} {
                        set in_sel [expr {$abs < $ecx_s}]
                    }
                    if {$in_sel} { tui-attr reverse } elseif {$ish} { tui-attr bold }
                    puts -nonewline [string index $seg $ci]
                    if {$in_sel || $ish} { tui-attr off }
                }
            } else {
                if {$ish} { tui-attr bold }
                puts -nonewline $seg
                if {$ish} { tui-attr off }
            }
        }

        # ── scroll indicator ──────────────────────────────────────────────────
        set nvrows [llength $vrows]
        if {$nvrows > $th} {
            set bar_h [expr {max(1, int(double($th) * $th / $nvrows))}]
            set bar_p [expr {int(double($scroll_y) * ($th - $bar_h) / ($nvrows - $th))}]
            for {set i 0} {$i < $th} {incr i} {
                tui-move [expr {$i + $roff}] [expr {$cols - 1}]
                if {$i >= $bar_p && $i < $bar_p + $bar_h} {
                    puts -nonewline "\u2590"
                } else {
                    tui-attr dim; puts -nonewline "\u2502"; tui-attr off
                }
            }
        }

        # ── bars ──────────────────────────────────────────────────────────────
        set wc 0; foreach l $lines { incr wc [llength [split $l]] }
        set sel_info [expr {$sel_r ne {} ? " \[sel\]" : ""}]
        set sel_hint [expr {$sel_anchor ne "" ? "^K cancel-sel" : "^K sel"}]
        tui-help [expr {$rows-2}] "^S save  ^W close  ^F find  ^R replace  ^G goto  ^O open  ^Z undo  ^A selall  $sel_hint ^C copy  ^V paste  $::cfg_toc_key toc" $cols
        set left " [file tail $filepath][expr {$dirty ? { [+]} : {}}]${sel_info}"
        set right [format "ln %d/%d  col %d  %dw " $cy [llength $lines] [expr {$cx+1}] $wc]
        if {$message ne "" && [clock seconds] - $msg_time < 2} { set left " $message" }
        tui-bar [expr {$rows-1}] $left $right $cols

        tui-move [expr {$vi - $scroll_y + $roff}] [expr {$scx + $coff}]
        puts -nonewline "\033\[?25h"; flush stdout

        set key [tui-getch]; puts -nonewline "\033\[?25l"
        set rst       1
        set clear_sel 1

        switch -- $key {
            UP {
                if {$vi > 0} { if {$sticky<0} {set sticky $scx}; lassign [tui-v2l $vrows [expr {$vi-1}] $sticky] cy cx }
                set rst 0
                if {$sel_sticky} { if {$sel_anchor eq ""} { set sel_anchor [list $cy $cx] }; set clear_sel 0 }
            }
            DOWN {
                if {$vi < [llength $vrows]-1} { if {$sticky<0} {set sticky $scx}; lassign [tui-v2l $vrows [expr {$vi+1}] $sticky] cy cx }
                set rst 0
                if {$sel_sticky} { if {$sel_anchor eq ""} { set sel_anchor [list $cy $cx] }; set clear_sel 0 }
            }
            SHIFT-UP {
                set sel_sticky 0
                if {$sel_anchor eq ""} { set sel_anchor [list $cy $cx] }
                if {$vi > 0} { if {$sticky<0} {set sticky $scx}; lassign [tui-v2l $vrows [expr {$vi-1}] $sticky] cy cx }
                set rst 0; set clear_sel 0
            }
            SHIFT-DOWN {
                set sel_sticky 0
                if {$sel_anchor eq ""} { set sel_anchor [list $cy $cx] }
                if {$vi < [llength $vrows]-1} { if {$sticky<0} {set sticky $scx}; lassign [tui-v2l $vrows [expr {$vi+1}] $sticky] cy cx }
                set rst 0; set clear_sel 0
            }
            SHIFT-LEFT {
                set sel_sticky 0
                if {$sel_anchor eq ""} { set sel_anchor [list $cy $cx] }
                if {$cx > 0} { incr cx -1 } elseif {$cy > 1} { incr cy -1; set cx [string length [lindex $lines [expr {$cy-1}]]] }
                set clear_sel 0
            }
            SHIFT-RIGHT {
                set sel_sticky 0
                if {$sel_anchor eq ""} { set sel_anchor [list $cy $cx] }
                if {$cx < [string length [lindex $lines [expr {$cy-1}]]]} { incr cx
                } elseif {$cy < [llength $lines]} { incr cy; set cx 0 }
                set clear_sel 0
            }
            LEFT {
                if {$sel_sticky} {
                    if {$cx > 0} { incr cx -1 } elseif {$cy > 1} { incr cy -1; set cx [string length [lindex $lines [expr {$cy-1}]]] }
                    set clear_sel 0
                } elseif {$sel_anchor ne ""} {
                    lassign [tui-sel-range $sel_anchor $cy $cx] cy cx
                } elseif {$cx > 0} { incr cx -1
                } elseif {$cy > 1} { incr cy -1; set cx [string length [lindex $lines [expr {$cy-1}]]] }
            }
            RIGHT {
                if {$sel_sticky} {
                    if {$cx < [string length [lindex $lines [expr {$cy-1}]]]} { incr cx
                    } elseif {$cy < [llength $lines]} { incr cy; set cx 0 }
                    set clear_sel 0
                } elseif {$sel_anchor ne ""} {
                    lassign [tui-sel-range $sel_anchor $cy $cx] sly scx_ ely ecx_
                    set cy $ely; set cx $ecx_
                } elseif {$cx < [string length [lindex $lines [expr {$cy-1}]]]} { incr cx
                } elseif {$cy < [llength $lines]} { incr cy; set cx 0 }
            }
            HOME { set cx [lindex [lindex $vrows $vi] 1] }
            END  { set cx [lindex [lindex $vrows $vi] 2] }
            PPAGE {
                if {$sticky<0} {set sticky $scx}
                lassign [tui-v2l $vrows [expr {max(0,$vi-$th)}] $sticky] cy cx; set rst 0
            }
            NPAGE {
                if {$sticky<0} {set sticky $scx}
                lassign [tui-v2l $vrows [expr {min([llength $vrows]-1,$vi+$th)}] $sticky] cy cx; set rst 0
            }
            BACKSPACE {
                eval $push_undo
                if {$sel_anchor ne ""} {
                    lassign [tui-sel-delete $lines $sel_anchor $cy $cx] lines cy cx; set dirty 1
                } elseif {$cx > 0} {
                    set l [lindex $lines [expr {$cy-1}]]
                    lset lines [expr {$cy-1}] "[string range $l 0 [expr {$cx-2}]][string range $l $cx end]"
                    incr cx -1; set dirty 1
                } elseif {$cy > 1} {
                    set cx [string length [lindex $lines [expr {$cy-2}]]]
                    lset lines [expr {$cy-2}] "[lindex $lines [expr {$cy-2}]][lindex $lines [expr {$cy-1}]]"
                    set lines [lreplace $lines [expr {$cy-1}] [expr {$cy-1}]]
                    incr cy -1; set dirty 1
                }
            }
            DC {
                eval $push_undo
                if {$sel_anchor ne ""} {
                    lassign [tui-sel-delete $lines $sel_anchor $cy $cx] lines cy cx; set dirty 1
                } else {
                    set l [lindex $lines [expr {$cy-1}]]
                    if {$cx < [string length $l]} {
                        lset lines [expr {$cy-1}] "[string range $l 0 [expr {$cx-1}]][string range $l [expr {$cx+1}] end]"
                        set dirty 1
                    } elseif {$cy < [llength $lines]} {
                        lset lines [expr {$cy-1}] "${l}[lindex $lines $cy]"
                        set lines [lreplace $lines $cy $cy]; set dirty 1
                    }
                }
            }
            ENTER {
                eval $push_undo
                if {$sel_anchor ne ""} { lassign [tui-sel-delete $lines $sel_anchor $cy $cx] lines cy cx; set dirty 1 }
                set l [lindex $lines [expr {$cy-1}]]
                set lines [linsert [lreplace $lines [expr {$cy-1}] [expr {$cy-1}] \
                    [string range $l 0 [expr {$cx-1}]]] $cy [string range $l $cx end]]
                incr cy; set cx 0; set dirty 1
            }
            TAB {
                eval $push_undo
                if {$sel_anchor ne ""} { lassign [tui-sel-delete $lines $sel_anchor $cy $cx] lines cy cx; set dirty 1 }
                set l [lindex $lines [expr {$cy-1}]]
                lset lines [expr {$cy-1}] "[string range $l 0 [expr {$cx-1}]]    [string range $l $cx end]"
                incr cx 4; set dirty 1
            }
            default {
                set c [scan $key %c]
                if {$key eq "\x13"} {                                          ;# Ctrl+S save
                    set fh [open $filepath w]; fconfigure $fh -encoding utf-8
                    puts -nonewline $fh "[join $lines \n]\n"; close $fh
                    cursor-put $filepath $cy $cx
                    set dirty 0; set message "saved"; set msg_time [clock seconds]
                    set clear_sel 0
                } elseif {$key in {"\x17" "\x11" ESC}} {                       ;# Ctrl+W/Q/Esc close
                    if {$dirty} {
                        lassign [tui-size] rows cols
                        if {[tui-confirm "save before closing?" $rows $cols]} {
                            set fh [open $filepath w]; fconfigure $fh -encoding utf-8
                            puts -nonewline $fh "[join $lines \n]\n"; close $fh
                        }
                    }
                    cursor-put $filepath $cy $cx; return
                } elseif {$key eq "\x0f"} {                                    ;# Ctrl+O open (→ browser)
                    set fh [open $filepath w]; fconfigure $fh -encoding utf-8
                    puts -nonewline $fh "[join $lines \n]\n"; close $fh
                    cursor-put $filepath $cy $cx; set dirty 0; return
                } elseif {$key eq "\x1a"} {                                    ;# Ctrl+Z undo
                    if {[llength $undo_stack] > 0} {
                        lassign [lindex $undo_stack end] lines cy cx
                        set undo_stack [lrange $undo_stack 0 end-1]; set dirty 1
                    }
                    set clear_sel 0
                } elseif {$key eq "\x0b"} {                                    ;# Ctrl+K toggle sticky selection
                    if {$sel_sticky} {
                        set sel_sticky 0; set sel_anchor ""
                    } else {
                        set sel_sticky 1; set sel_anchor [list $cy $cx]
                    }
                    set clear_sel 0
                } elseif {$key eq "\x01"} {                                    ;# Ctrl+A select all
                    set sel_anchor [list 1 0]
                    set cy [llength $lines]; set cx [string length [lindex $lines end]]
                    set clear_sel 0
                } elseif {$key eq "\x03"} {                                    ;# Ctrl+C copy
                    set txt [tui-sel-text $lines $sel_anchor $cy $cx]
                    if {$txt ne ""} { tui-copy $txt; set message "copied"; set msg_time [clock seconds] }
                    set clear_sel 0
                } elseif {$key eq "\x18"} {                                    ;# Ctrl+X cut
                    set txt [tui-sel-text $lines $sel_anchor $cy $cx]
                    if {$txt ne ""} {
                        eval $push_undo; tui-copy $txt
                        lassign [tui-sel-delete $lines $sel_anchor $cy $cx] lines cy cx
                        set dirty 1; set message "cut"; set msg_time [clock seconds]
                    }
                } elseif {$key eq "\x16" || [string match "PASTE:*" $key]} {   ;# Ctrl+V / bracketed paste
                    if {[string match "PASTE:*" $key]} {
                        set txt [string range $key 6 end]
                    } else {
                        set txt [tui-paste]
                    }
                    if {$txt ne ""} {
                        eval $push_undo
                        if {$sel_anchor ne ""} { lassign [tui-sel-delete $lines $sel_anchor $cy $cx] lines cy cx }
                        set plines [split $txt "\n"]
                        set l [lindex $lines [expr {$cy-1}]]
                        set pre [string range $l 0 [expr {$cx-1}]]
                        set post [string range $l $cx end]
                        if {[llength $plines] == 1} {
                            lset lines [expr {$cy-1}] "${pre}${txt}${post}"
                            incr cx [string length $txt]
                        } else {
                            set nl [list "${pre}[lindex $plines 0]"]
                            foreach pl [lrange $plines 1 end-1] { lappend nl $pl }
                            lappend nl "[lindex $plines end]${post}"
                            set lines [lreplace $lines [expr {$cy-1}] [expr {$cy-1}] {*}$nl]
                            incr cy [expr {[llength $plines]-1}]
                            set cx [string length [lindex $plines end]]
                        }
                        set dirty 1
                    }
                } elseif {$key eq "\x06"} {                                    ;# Ctrl+F find
                    lassign [tui-size] rows cols
                    set term [string trim [tui-prompt "find: " $rows $cols]]
                    if {$term ne ""} { set ::tui_search $term }
                    if {$::tui_search ne ""} {
                        set found 0; set n [llength $lines]
                        for {set i 0} {$i < $n} {incr i} {
                            set li [expr {($cy - 1 + $i) % $n + 1}]
                            set l  [lindex $lines [expr {$li - 1}]]
                            set from [expr {$li == $cy && $i == 0 ? $cx + 1 : 0}]
                            set idx [string first [string tolower $::tui_search] [string tolower $l] $from]
                            if {$idx >= 0} { set cy $li; set cx $idx; set found 1; break }
                        }
                        if {!$found} { set message "not found: $::tui_search"; set msg_time [clock seconds] }
                    }
                    set clear_sel 0
                } elseif {$key eq "\x12"} {                                    ;# Ctrl+R replace
                    lassign [tui-size] rows cols
                    set term [string trim [tui-prompt "find: " $rows $cols]]
                    if {$term ne ""} { set ::tui_search $term }
                    if {$::tui_search ne ""} {
                        set repl [tui-prompt "replace with (ESC=cancel): " $rows $cols]
                        if {$repl ne "" || [string length $repl] == 0} {
                            set count 0; set new_lines {}
                            foreach l $lines {
                                set out ""; set pos 0
                                while 1 {
                                    set idx [string first [string tolower $::tui_search] [string tolower $l] $pos]
                                    if {$idx < 0} { append out [string range $l $pos end]; break }
                                    append out [string range $l $pos [expr {$idx-1}]]$repl
                                    set pos [expr {$idx + [string length $::tui_search]}]; incr count
                                }
                                lappend new_lines $out
                            }
                            if {$count > 0} {
                                eval $push_undo; set lines $new_lines; set dirty 1
                                set message "replaced $count occurrence[expr {$count!=1?{s}:{}}]"
                                set msg_time [clock seconds]
                                set cy [expr {max(1, min($cy, [llength $lines]))}]
                                set cx [expr {max(0, min($cx, [string length [lindex $lines [expr {$cy-1}]]]))}]
                            } else { set message "not found: $::tui_search"; set msg_time [clock seconds] }
                        }
                    }
                    set clear_sel 0
                } elseif {$key eq "\x07"} {                                    ;# Ctrl+G goto line
                    lassign [tui-size] rows cols
                    set num [tui-prompt "go to line: " $rows $cols]
                    if {[string is integer -strict $num] && $num >= 1} {
                        set cy [expr {min($num, [llength $lines])}]; set cx 0
                    }
                } elseif {$key eq $::cfg_toc_key} {
                    lassign [tui-size] rows cols
                    set target [tui-toc $lines $rows $cols]
                    if {$target > 0} { set cy $target; set cx 0 }
                } elseif {[string length $key] >= 1 && ($c eq "" || $c >= 32)} {
                    eval $push_undo
                    if {$sel_anchor ne ""} { lassign [tui-sel-delete $lines $sel_anchor $cy $cx] lines cy cx; set dirty 1 }
                    set l [lindex $lines [expr {$cy-1}]]
                    lset lines [expr {$cy-1}] "[string range $l 0 [expr {$cx-1}]]${key}[string range $l $cx end]"
                    incr cx [string length $key]; set dirty 1
                }
            }
        }
        if {$rst}       { set sticky -1 }
        if {$clear_sel} { set sel_anchor ""; set sel_sticky 0 }
    }
}

proc tui-main {} {
    tui-init
    set ok [catch {
        if {$::argc > 0} {
            set fp [lindex $::argv 0]
            if {![file exists $fp]} { close [open $fp w] }
            tui-editor $fp
        } else {
            while 1 {
                set fp [tui-browser]
                if {$fp eq ""} break
                tui-editor $fp
            }
        }
    } err info]
    tui-cleanup
    if {$ok} { puts stderr $err }
}

# ─── start ────────────────────────────────────────────────────────────────────
if {$::no_gui} {
    tui-main
} elseif {$::argc > 0} {
    show-editor [lindex $::argv 0]
} else {
    show-browser
}
