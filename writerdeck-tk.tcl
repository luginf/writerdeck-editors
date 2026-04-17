#!/usr/bin/env wish
# writerdeck-tk.tcl — Tk text editor with file browser
# Usage: wish writerdeck-tk.tcl [filename]

set ::DOCS_DIR [file join $::env(HOME) Documents writerdeck]
set ::FILE_EXT ".txt"
set ::filename ""
set ::dirty    0
set ::msg      ""

file mkdir $::DOCS_DIR

# ─── config ───────────────────────────────────────────────────────────────────
set font    {Mono 13}
set font_sm {Mono 10}
set bg      "#1a1a1a"
set fg      "#e8e8e8"
set bg_bar  "#2a2a2a"
set fg_bar  "#aaaaaa"
set bg_sel  "#3a5a8a"
set fg_dim  "#666666"

wm title . "WriterDeck"
wm minsize . 500 400

# ─── utils ────────────────────────────────────────────────────────────────────
proc list-docs {} {
    set pairs {}
    foreach f [glob -nocomplain -directory $::DOCS_DIR -tails *] {
        set full [file join $::DOCS_DIR $f]
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

proc fmt-meta {path} {
    set sz [file size $path]
    set sz_str [expr {$sz < 1024 ? "${sz}B" : "[expr {$sz/1024}]K"}]
    set mt [clock format [file mtime $path] -format "%d %b %H:%M"]
    return [format "%6s  %s" $sz_str $mt]
}

# ─── browser frame ────────────────────────────────────────────────────────────
frame .br -bg $bg

label .br.title \
    -text " WriterDeck" \
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
    -text " ↵ ouvrir  n nouveau  d supprimer  r renommer  q quitter" \
    -bg $bg_bar -fg $fg_bar -font $font_sm -anchor w -padx 4
label .br.bar.cnt -textvariable ::br_status \
    -bg $bg_bar -fg $fg_bar -font $font_sm -anchor e -padx 8
pack .br.bar.help -side left
pack .br.bar.cnt  -side right
pack .br.bar -side bottom -fill x

# browser state
set ::br_files {}

proc br-refresh {} {
    set ::br_files [list-docs]
    set sel [.br.mid.lst curselection]
    set sel [expr {[llength $sel] ? [lindex $sel 0] : 0}]

    .br.mid.lst delete 0 end
    foreach f $::br_files {
        set full [file join $::DOCS_DIR $f]
        set meta [fmt-meta $full]
        .br.mid.lst insert end [format "  %-36s %s" $f $meta]
    }

    set n [llength $::br_files]
    set s [expr {$n != 1 ? "s" : ""}]
    set ::br_status " $n fichier${s} "

    if {$n > 0} {
        set sel [expr {min($sel, $n - 1)}]
        .br.mid.lst selection set $sel
        .br.mid.lst see $sel
    }
}

proc br-open {} {
    set sel [.br.mid.lst curselection]
    if {![llength $sel]} return
    set f [lindex $::br_files [lindex $sel 0]]
    show-editor [file join $::DOCS_DIR $f]
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
    set name [input-dialog "Nouveau fichier" "Nom du fichier :"]
    set name [string trim $name]
    if {$name eq ""} return
    if {[file extension $name] eq ""} { append name $::FILE_EXT }
    set full [file join $::DOCS_DIR $name]
    if {[file exists $full]} {
        tk_messageBox -message "« $name » existe déjà." -icon warning -parent .
        return
    }
    close [open $full w]
    show-editor $full
}

proc br-delete {} {
    set sel [.br.mid.lst curselection]
    if {![llength $sel]} return
    set f [lindex $::br_files [lindex $sel 0]]
    set r [tk_messageBox -message "Supprimer « $f » ?" \
           -type yesno -icon question -parent .]
    if {$r eq "yes"} {
        file delete [file join $::DOCS_DIR $f]
        br-refresh
    }
}

proc br-rename {} {
    set sel [.br.mid.lst curselection]
    if {![llength $sel]} return
    set f [lindex $::br_files [lindex $sel 0]]
    set new [input-dialog "Renommer" "Renommer « $f » en :"]
    set new [string trim $new]
    if {$new eq ""} return
    if {[file extension $new] eq ""} { append new $::FILE_EXT }
    set new_path [file join $::DOCS_DIR $new]
    if {[file exists $new_path]} {
        tk_messageBox -message "« $new » existe déjà." -icon warning -parent .
        return
    }
    file rename [file join $::DOCS_DIR $f] $new_path
    br-refresh
}

bind .br.mid.lst <Return>      { br-open }
bind .br.mid.lst <Double-1>    { br-open }
bind .br.mid.lst <n>           { br-new }
bind .br.mid.lst <d>           { br-delete }
bind .br.mid.lst <r>           { br-rename }
bind .br.mid.lst <q>           { exit }

# ─── editor frame ─────────────────────────────────────────────────────────────
frame .ed -bg $bg

text .ed.t \
    -wrap word -font $font \
    -bg $bg -fg $fg \
    -insertbackground $fg \
    -selectbackground $bg_sel \
    -borderwidth 0 -padx 12 -pady 8 \
    -undo 1

scrollbar .ed.sb -orient vertical -command {.ed.t yview} \
    -bg $bg_bar -troughcolor $bg
.ed.t configure -yscrollcommand {.ed.sb set}

frame .ed.bar -bg $bg_bar
label .ed.bar.lbl -textvariable ::ed_status \
    -bg $bg_bar -fg $fg_bar -font $font_sm -anchor w -padx 8
pack .ed.bar.lbl -fill x
pack .ed.bar -side bottom -fill x
pack .ed.sb  -side right  -fill y
pack .ed.t   -fill both   -expand 1

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
}

# ─── file I/O ─────────────────────────────────────────────────────────────────
proc load-file {path} {
    set ::filename $path
    wm title . "WriterDeck — [file tail $path]"
    .ed.t delete 1.0 end
    if {[file exists $path] && [file size $path] > 0} {
        set fh [open $path r]
        fconfigure $fh -encoding utf-8
        .ed.t insert 1.0 [read $fh]
        close $fh
    }
    .ed.t edit modified false
    set ::dirty 0
    .ed.t mark set insert 1.0
    .ed.t see insert
    ed-status
}

proc save-file {} {
    if {$::filename eq ""} return
    set fh [open $::filename w]
    fconfigure $fh -encoding utf-8
    puts -nonewline $fh [.ed.t get 1.0 {end - 1 chars}]
    close $fh
    set ::dirty 0
    .ed.t edit modified false
    set-msg "saved"
}

proc close-editor {} {
    if {$::dirty} save-file
    set ::filename ""
    set ::dirty    0
    set ::msg      ""
    wm title . "WriterDeck"
    .ed.t delete 1.0 end
    show-browser
}

# ─── editor bindings ──────────────────────────────────────────────────────────
bind .ed.t <Control-s> { save-file;    break }
bind .ed.t <Control-q> { close-editor; break }
bind .ed.t <Control-w> { close-editor; break }
bind .ed.t <Escape>    { close-editor; break }

bind .ed.t <Control-k> {
    if {[.ed.t index insert] eq [.ed.t index {insert lineend}]} {
        .ed.t delete insert
    } else {
        .ed.t delete insert {insert lineend}
    }
    break
}

bind .ed.t <Tab>       { .ed.t insert insert "    "; break }
bind .ed.t <Control-g> { goto-dialog; break }
bind .ed.t <Control-h> { help-dialog; break }
bind .br.mid.lst <h>   { help-dialog }

proc help-dialog {} {
    set w .help
    catch {destroy $w}
    toplevel $w
    wm title $w "Help — WriterDeck"
    wm resizable $w 0 0
    wm transient $w .
    grab $w

    set sections {
        "EDITOR" {
            "Ctrl+S"       "Save"
            "Ctrl+Q / ESC" "Save and return to browser"
            "Ctrl+K"       "Delete to end of line"
            "Ctrl+G"       "Go to line"
            "Ctrl+Z"       "Undo"
            "Tab"          "Insert 4 spaces"
            "Ctrl+H"       "This help"
        }
        "BROWSER" {
            "↵ / double-click"  "Open selected file"
            "n"                 "New file"
            "d"                 "Delete file"
            "r"                 "Rename file"
            "h"                 "This help"
            "q"                 "Quit"
        }
    }

    text $w.t \
        -font {Mono 11} -state normal \
        -bg "#1a1a1a" -fg "#e8e8e8" \
        -borderwidth 0 -padx 16 -pady 12 \
        -width 46 -height 18 \
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

# ─── start ────────────────────────────────────────────────────────────────────
if {$::argc > 0} {
    show-editor [lindex $::argv 0]
} else {
    show-browser
}
