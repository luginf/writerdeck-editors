#!/usr/bin/env wish
# writerdeck-tk.tcl — Tk text editor port of writerdeck
# Usage: wish writerdeck-tk.tcl [filename]

set ::filename ""
set ::dirty    0
set ::msg      ""

# ─── window ───────────────────────────────────────────────────────────────────
wm title . "WriterDeck"
wm minsize . 500 400

set font {Mono 13}

text .t \
    -wrap word \
    -font $font \
    -bg "#1a1a1a" -fg "#e8e8e8" \
    -insertbackground "#e8e8e8" \
    -selectbackground "#3a5a8a" \
    -borderwidth 0 -padx 12 -pady 8 \
    -undo 1

scrollbar .sb -orient vertical -command {.t yview}
.t configure -yscrollcommand {.sb set}

frame .bar -bg "#2a2a2a"
label .bar.lbl \
    -textvariable ::status \
    -bg "#2a2a2a" -fg "#aaaaaa" \
    -font [list [lindex $font 0] 10] \
    -anchor w -padx 8
pack .bar.lbl -fill x

pack .bar -side bottom -fill x
pack .sb  -side right  -fill y
pack .t   -fill both   -expand 1

focus .t

# ─── status bar ───────────────────────────────────────────────────────────────
proc refresh-status {} {
    set d  [expr {$::dirty ? "* " : "  "}]
    set fn [expr {$::filename eq "" ? "\[new\]" : [file tail $::filename]}]
    lassign [split [.t index insert] .] ln col
    set m  [expr {$::msg ne "" ? "   | $::msg" : ""}]
    set ::status "${d}${fn}   Ln ${ln}  Col [expr {$col + 1}]${m}"
}

proc set-msg {text} {
    set ::msg $text
    refresh-status
    after 2000 { set ::msg ""; refresh-status }
}

bind .t <KeyRelease>    { refresh-status }
bind .t <ButtonRelease> { refresh-status }

# ─── dirty tracking ───────────────────────────────────────────────────────────
bind .t <<Modified>> {
    if {[.t edit modified]} { set ::dirty 1; .t edit modified false }
    refresh-status
}

# ─── file I/O ─────────────────────────────────────────────────────────────────
proc load-file {path} {
    set ::filename $path
    wm title . "WriterDeck — [file tail $path]"
    if {[file exists $path]} {
        set fh [open $path r]
        fconfigure $fh -encoding utf-8
        .t delete 1.0 end
        .t insert 1.0 [read $fh]
        close $fh
        .t edit modified false
    }
    set ::dirty 0
    .t mark set insert 1.0
    .t see insert
    refresh-status
}

proc save-file {} {
    if {$::filename eq ""} return
    set fh [open $::filename w]
    fconfigure $fh -encoding utf-8
    puts -nonewline $fh [.t get 1.0 {end - 1 chars}]
    close $fh
    set ::dirty 0
    .t edit modified false
    set-msg "saved"
}

proc quit-editor {} {
    if {$::dirty} save-file
    exit
}

# ─── key bindings ─────────────────────────────────────────────────────────────
bind .t <Control-s> { save-file;   break }
bind .t <Control-q> { quit-editor; break }
bind .t <Control-w> { quit-editor; break }
bind .t <Escape>    { quit-editor; break }

bind .t <Control-k> {
    if {[.t index insert] eq [.t index {insert lineend}]} {
        .t delete insert
    } else {
        .t delete insert {insert lineend}
    }
    break
}

bind .t <Tab>       { .t insert insert "    "; break }
bind .t <Control-g> { goto-dialog; break }

# ─── goto line dialog ─────────────────────────────────────────────────────────
proc goto-dialog {} {
    set w .goto
    catch {destroy $w}
    toplevel $w
    wm title $w "Go to line"
    wm resizable $w 0 0
    wm transient $w .

    label  $w.l  -text "Go to line:"
    entry  $w.e  -width 8
    button $w.ok -text "OK"     -command [list goto-apply $w]
    button $w.cn -text "Cancel" -command [list destroy $w]
    grid $w.l $w.e $w.ok $w.cn -padx 4 -pady 8

    bind $w.e  <Return> [list goto-apply $w]
    bind $w    <Escape> [list destroy $w]
    focus $w.e
}

proc goto-apply {w} {
    set n [$w.e get]
    if {[string is integer -strict $n] && $n >= 1} {
        set last [lindex [split [.t index end] .] 0]
        .t mark set insert [expr {min($n, $last - 1)}].0
        .t see insert
        focus .t
    }
    destroy $w
}

# ─── start ────────────────────────────────────────────────────────────────────
if {$::argc > 0} {
    load-file [lindex $::argv 0]
} else {
    refresh-status
}
