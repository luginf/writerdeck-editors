#!/bin/sh
# sh/Tcl polyglot — backslash continues Tcl comment to next line, hiding shell bootstrap \
_w=$(stty -g 2>/dev/null); trap '[ -n "$_w" ] && stty "$_w" 2>/dev/null' EXIT INT TERM; tclsh "$0" "$@"; exit $?

# # # # # # # # # # # #
#
#     writhdeck.tcl 
#     
#  ~  Tk/TUI text editor for writerdecks ~
#
# Usage: tclsh writhdeck.tcl [--no-gui] [filename]
# 
# 
#    Copyright (C) 2026 by Luginfo
#    
#    BSD Zero Clause License
#
#    Permission to use, copy, modify, and/or distribute this software for any purpose 
#    with or without fee is hereby granted.
#
#    THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES 
#    WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES 
#    OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE 
#    FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES 
#    WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION 
#    OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF 
#    OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
# # # # # # # # # # # #

# bail out immediately when invoked by bash tab-completion
if {[info exists ::env(COMP_LINE)] || [info exists ::env(COMP_POINT)]} { exit 0 }

set ::no_gui [expr {[lsearch $::argv "--no-gui"] >= 0}]
if {$::no_gui} {
    set ::argv [lsearch -all -inline -not $::argv "--no-gui"]
    set ::argc [llength $::argv]
}
if {!$::no_gui} {
    if {$::tcl_platform(platform) eq "windows"} {
        if {[catch {package require Tk}]} { set ::no_gui 1 }
    } else {
        # On Unix, check that the display socket actually exists before trying Tk —
        # package require Tk can hang indefinitely if DISPLAY is stale/unreachable.
        proc _display-socket-exists {} {
            if {[info exists ::env(WAYLAND_DISPLAY)] && $::env(WAYLAND_DISPLAY) ne ""} {
                set dir [expr {[info exists ::env(XDG_RUNTIME_DIR)] ? $::env(XDG_RUNTIME_DIR) : ""}]
                if {$dir ne "" && [file exists [file join $dir $::env(WAYLAND_DISPLAY)]]} { return 1 }
            }
            if {[info exists ::env(DISPLAY)] && $::env(DISPLAY) ne ""} {
                if {[regexp {^:(\d+)} $::env(DISPLAY) -> num]} {
                    return [file exists "/tmp/.X11-unix/X$num"]
                }
            }
            return 0
        }
        if {![_display-socket-exists] || [catch {package require Tk}]} {
            set ::no_gui 1
        }
        rename _display-socket-exists {}
    }
}

set ::HOME_DIR [expr {[info exists ::env(HOME)] ? $::env(HOME) : \
    ([info exists ::env(USERPROFILE)] ? $::env(USERPROFILE) : [file normalize ~])}]
set ::DOCS_DIR_DEFAULT [file join $::HOME_DIR Documents writhdeck]
set ::DOCS_DIR         $::DOCS_DIR_DEFAULT
set ::INI_FILE         [file join $::DOCS_DIR_DEFAULT "writhdeck.ini"]
set ::FILE_EXT ".txt"
set ::filename     ""
set ::dirty        0
set ::msg          ""
set ::ed_msg       ""
set ::session_headings {}

file mkdir $::DOCS_DIR_DEFAULT
set ::CURSOR_FILE [file join $::DOCS_DIR_DEFAULT ".cursors.json"]

# ─── cursor persistence (JSON, compatible with writhdeck.lua) ──────────────────
proc cursors-load {} {
    if {![file exists $::CURSOR_FILE]} { return {} }
    set fh [open $::CURSOR_FILE r]; fconfigure $fh -encoding utf-8
    set raw [read $fh]; close $fh
    set d {}
    set re {"([^"\\]*)"\s*:\s*\[(\d+)\s*,\s*(\d+)\]}
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
set ::cfg_bg             "#1a1a1a"
set ::cfg_fg             "#e8e8e8"
set ::cfg_bg_bar         "#2a2a2a"
set ::cfg_fg_bar         "#aaaaaa"
set ::cfg_bg_sel         "#3a5a8a"
set ::cfg_docs_dir       ""
set ::cfg_margin_cols    6
set ::cfg_margin_rows    4
set ::cfg_heading_marker "="
set ::cfg_color_heading  "#c8a060"
set ::cfg_dim_marker     "%"
set ::cfg_color_dim      "#606060"
# alternate (light) theme — used when dark_mode = 0
set ::cfg_bg_alt             "#fdf6e3"
set ::cfg_fg_alt             "#657b83"
set ::cfg_bg_bar_alt         "#eee8d5"
set ::cfg_fg_bar_alt         "#93a1a1"
set ::cfg_bg_sel_alt         "#268bd2"
set ::cfg_color_heading_alt  "#b58900"
set ::cfg_color_dim_alt      "#aaaaaa"
# dark_mode: 0 = light (alt colors), 1 = dark (primary colors)
set ::cfg_dark_mode          1
set ::cfg_key_dark_toggle    "Control-d"
set ::cfg_line_numbers   0
set ::cfg_cursor_restore 1
set ::cfg_block_cursor   1
set ::cfg_blink_cursor   0
set ::cfg_line_spacing   100
set ::cfg_word_count     1
set ::cfg_show_clock     1
set ::cfg_help_bar       "^S save   ^Q close   ^H help"
# status bar zones — tokens: filename dirty sel ln col words chars clock space
set ::cfg_status_left   "filename dirty sel ln col words chars"
set ::cfg_status_center ""
set ::cfg_status_right  "help_bar clock"
# shortcuts (Tk key names)
set ::cfg_key_save         "Control-s"
set ::cfg_key_save_as      "Control-S"
set ::cfg_key_close        "Control-q"
set ::cfg_key_find         "Control-f"
set ::cfg_key_replace      "Control-r"
set ::cfg_key_help         "Control-h"
set ::cfg_key_goto         "Control-g"
set ::cfg_key_open         "Control-o"
set ::cfg_key_undo         "Control-z"
set ::cfg_key_copy         "Control-c"
set ::cfg_key_cut          "Control-x"
set ::cfg_key_paste        "Control-v"
set ::cfg_key_select_all   "Control-a"
set ::cfg_key_sticky_sel   "Control-k"
set ::cfg_key_toc          "F11"
set ::cfg_key_line_numbers "Control-l"
set ::cfg_key_fullscreen   "Alt-Return"
set ::cfg_key_error        ""
set ::fullscreen 0

proc ini-load {} {
    if {![file exists $::INI_FILE]} { ini-save; return }
    set fh [open $::INI_FILE r]
    fconfigure $fh -encoding utf-8
    while {[gets $fh line] >= 0} {
        set line [string trim $line]
        if {$line eq "" || [string match "#*" $line] || [string match {\[*} $line]} continue
        if {[regexp {^(\w+)\s*=\s*(.+)$} $line -> key val]} {
            set v [string trim $val]
            switch [string trim $key] {
                margin_width     { set ::cfg_margin_width   $v }
                margin_height    { set ::cfg_margin_height  $v }
                font_size        { set ::cfg_font_size      $v }
                color_bg         { set ::cfg_bg             $v }
                color_fg         { set ::cfg_fg             $v }
                color_bg_bar     { set ::cfg_bg_bar         $v }
                color_fg_bar     { set ::cfg_fg_bar         $v }
                docs_dir         { set ::cfg_docs_dir       $v }
                margin_cols      { set ::cfg_margin_cols    $v }
                margin_rows      { set ::cfg_margin_rows    $v }
                color_bg_sel     { set ::cfg_bg_sel         $v }
                heading_marker   { set ::cfg_heading_marker $v }
                color_heading    { set ::cfg_color_heading  $v }
                dim_marker       { set ::cfg_dim_marker     $v }
                color_dim        { set ::cfg_color_dim      $v }
                color_bg_alt         { set ::cfg_bg_alt            $v }
                color_fg_alt         { set ::cfg_fg_alt            $v }
                color_bg_bar_alt     { set ::cfg_bg_bar_alt        $v }
                color_fg_bar_alt     { set ::cfg_fg_bar_alt        $v }
                color_bg_sel_alt     { set ::cfg_bg_sel_alt        $v }
                color_heading_alt    { set ::cfg_color_heading_alt $v }
                color_dim_alt        { set ::cfg_color_dim_alt     $v }
                dark_mode            { set ::cfg_dark_mode [string is true $v] }
                key_dark_toggle      { set ::cfg_key_dark_toggle   $v }
                line_numbers     { set ::cfg_line_numbers   $v }
                cursor_restore   { set ::cfg_cursor_restore $v }
                block_cursor     { set ::cfg_block_cursor   [string is true $v] }
                blink_cursor     { set ::cfg_blink_cursor   [string is true $v] }
                line_spacing     { set ::cfg_line_spacing   $v }
                word_count       { set ::cfg_word_count     $v }
                show_clock       { set ::cfg_show_clock     $v }
                help_bar         { set ::cfg_help_bar       $v }
                status_left      { set ::cfg_status_left    $v }
                status_center    { set ::cfg_status_center  $v }
                status_right     { set ::cfg_status_right   $v }
                key_save         { set ::cfg_key_save         $v }
                key_save_as      { set ::cfg_key_save_as      $v }
                key_close        { set ::cfg_key_close        $v }
                key_find         { set ::cfg_key_find         $v }
                key_replace      { set ::cfg_key_replace      $v }
                key_help         { set ::cfg_key_help         $v }
                key_goto         { set ::cfg_key_goto         $v }
                key_open         { set ::cfg_key_open         $v }
                key_undo         { set ::cfg_key_undo         $v }
                key_copy         { set ::cfg_key_copy         $v }
                key_cut          { set ::cfg_key_cut          $v }
                key_paste        { set ::cfg_key_paste        $v }
                key_select_all   { set ::cfg_key_select_all   $v }
                key_sticky_sel   { set ::cfg_key_sticky_sel   $v }
                key_toc          { set ::cfg_key_toc          $v }
                key_line_numbers { set ::cfg_key_line_numbers $v }
                key_fullscreen   { set ::cfg_key_fullscreen   $v }
                toc_key          { set ::cfg_key_toc          $v }
                ln_key           { set ::cfg_key_line_numbers $v }
                fullscreen_key   { set ::cfg_key_fullscreen   $v }
            }
        }
    }
    close $fh
}

proc ini-save {} {
    set fh [open $::INI_FILE w]
    fconfigure $fh -encoding utf-8
    puts $fh "# Writhdeck — configuration"
    puts $fh ""
    puts $fh "\[editor\]"
    puts $fh "# docs_dir = ~/Documents/writerdeck"
    puts $fh "# (default: ~/Documents/writhdeck)"
    puts $fh "margin_width   = $::cfg_margin_width"
    puts $fh "margin_height  = $::cfg_margin_height"
    puts $fh "# ── terminal version — values in columns/lines"
    puts $fh "margin_cols    = $::cfg_margin_cols"
    puts $fh "margin_rows    = $::cfg_margin_rows"
    puts $fh "font_size      = $::cfg_font_size"
    puts $fh "line_spacing   = $::cfg_line_spacing"
    puts $fh "heading_marker = $::cfg_heading_marker"
    puts $fh "dim_marker     = $::cfg_dim_marker"
    puts $fh ""
    puts $fh "\[behaviour\]"
    puts $fh "line_numbers   = $::cfg_line_numbers"
    puts $fh "cursor_restore = $::cfg_cursor_restore"
    puts $fh "block_cursor   = $::cfg_block_cursor"
    puts $fh "blink_cursor   = $::cfg_blink_cursor"
    puts $fh "word_count     = $::cfg_word_count"
    puts $fh "show_clock     = $::cfg_show_clock"
    puts $fh "# help_bar: text shown in the shortcuts bar, empty to hide"
    puts $fh "help_bar       = $::cfg_help_bar"
    puts $fh "# status bar zones — tokens: filename dirty sel ln col words chars clock space"
    puts $fh "status_left    = $::cfg_status_left"
    puts $fh "status_center  = $::cfg_status_center"
    puts $fh "status_right   = $::cfg_status_right"
    puts $fh "dark_mode      = $::cfg_dark_mode"
    puts $fh ""
    puts $fh "\[keys\]"
    puts $fh "# Use Tk key names: Control-s, Alt-Return, F11, etc."
    puts $fh "key_save         = $::cfg_key_save"
    puts $fh "key_save_as      = $::cfg_key_save_as"
    puts $fh "key_close        = $::cfg_key_close"
    puts $fh "key_find         = $::cfg_key_find"
    puts $fh "key_replace      = $::cfg_key_replace"
    puts $fh "key_help         = $::cfg_key_help"
    puts $fh "key_goto         = $::cfg_key_goto"
    puts $fh "key_open         = $::cfg_key_open"
    puts $fh "key_undo         = $::cfg_key_undo"
    puts $fh "key_copy         = $::cfg_key_copy"
    puts $fh "key_cut          = $::cfg_key_cut"
    puts $fh "key_paste        = $::cfg_key_paste"
    puts $fh "key_select_all   = $::cfg_key_select_all"
    puts $fh "key_sticky_sel   = $::cfg_key_sticky_sel"
    puts $fh "key_toc          = $::cfg_key_toc"
    puts $fh "key_line_numbers = $::cfg_key_line_numbers"
    puts $fh "key_fullscreen   = $::cfg_key_fullscreen"
    puts $fh "key_dark_toggle  = $::cfg_key_dark_toggle"
    puts $fh ""
    puts $fh "\[colors\]"
    puts $fh "# colors in #rrggbb format"
    puts $fh "color_bg       = $::cfg_bg"
    puts $fh "color_fg       = $::cfg_fg"
    puts $fh "color_bg_bar   = $::cfg_bg_bar"
    puts $fh "color_fg_bar   = $::cfg_fg_bar"
    puts $fh "color_bg_sel   = $::cfg_bg_sel"
    puts $fh "color_heading  = $::cfg_color_heading"
    puts $fh "color_dim      = $::cfg_color_dim"
    puts $fh ""
    puts $fh "# ── alternate (light) theme ───────────────────────────────────"
    puts $fh "# Used when dark_mode = 0  (active by default)"
    puts $fh "color_bg_alt       = $::cfg_bg_alt"
    puts $fh "color_fg_alt       = $::cfg_fg_alt"
    puts $fh "color_bg_bar_alt   = $::cfg_bg_bar_alt"
    puts $fh "color_fg_bar_alt   = $::cfg_fg_bar_alt"
    puts $fh "color_bg_sel_alt   = $::cfg_bg_sel_alt"
    puts $fh "color_heading_alt  = $::cfg_color_heading_alt"
    puts $fh "color_dim_alt      = $::cfg_color_dim_alt"
    close $fh
}

ini-load

# Map Tk key name → string returned by tui-getch
proc tk-key-to-tui {key} {
    set k [string tolower $key]
    if {[regexp {^control-([a-z])$} $k -> letter]} {
        scan $letter %c code
        return [format %c [expr {$code - 96}]]
    }
    if {[regexp {^f(\d+)$} $k -> n]} { return "F$n" }
    return $key
}

# Return a short human-readable label for a Tk key name
proc key-label {key} {
    if {[regexp -nocase {^control-([a-z])$} $key -> l]} { return "^[string toupper $l]" }
    if {[regexp -nocase {^f(\d+)$} $key -> n]}          { return "F$n" }
    return $key
}

# Compute TUI equivalents and detect key conflicts
proc keys-init {} {
    set ::cfg_tui_save       [tk-key-to-tui $::cfg_key_save]
    set ::cfg_tui_save_as    [tk-key-to-tui $::cfg_key_save_as]
    set ::cfg_tui_close      [tk-key-to-tui $::cfg_key_close]
    set ::cfg_tui_find       [tk-key-to-tui $::cfg_key_find]
    set ::cfg_tui_replace    [tk-key-to-tui $::cfg_key_replace]
    set ::cfg_tui_help       [tk-key-to-tui $::cfg_key_help]
    set ::cfg_tui_goto       [tk-key-to-tui $::cfg_key_goto]
    set ::cfg_tui_open       [tk-key-to-tui $::cfg_key_open]
    set ::cfg_tui_undo       [tk-key-to-tui $::cfg_key_undo]
    set ::cfg_tui_copy       [tk-key-to-tui $::cfg_key_copy]
    set ::cfg_tui_cut        [tk-key-to-tui $::cfg_key_cut]
    set ::cfg_tui_paste      [tk-key-to-tui $::cfg_key_paste]
    set ::cfg_tui_select_all [tk-key-to-tui $::cfg_key_select_all]
    set ::cfg_tui_sticky_sel [tk-key-to-tui $::cfg_key_sticky_sel]
    set ::cfg_tui_toc          [tk-key-to-tui $::cfg_key_toc]
    set ::cfg_tui_line_nums    [tk-key-to-tui $::cfg_key_line_numbers]
    set ::cfg_tui_dark_toggle  [tk-key-to-tui $::cfg_key_dark_toggle]
    # labels for UI display
    set ::cfg_lbl_save       [key-label $::cfg_key_save]
    set ::cfg_lbl_close      [key-label $::cfg_key_close]
    set ::cfg_lbl_find       [key-label $::cfg_key_find]
    set ::cfg_lbl_replace    [key-label $::cfg_key_replace]
    set ::cfg_lbl_help       [key-label $::cfg_key_help]
    set ::cfg_lbl_goto       [key-label $::cfg_key_goto]
    set ::cfg_lbl_open       [key-label $::cfg_key_open]
    set ::cfg_lbl_undo       [key-label $::cfg_key_undo]
    set ::cfg_lbl_copy       [key-label $::cfg_key_copy]
    set ::cfg_lbl_paste      [key-label $::cfg_key_paste]
    set ::cfg_lbl_sel_all    [key-label $::cfg_key_select_all]
    set ::cfg_lbl_sticky     [key-label $::cfg_key_sticky_sel]
    set ::cfg_lbl_toc        [key-label $::cfg_key_toc]
    set ::cfg_lbl_line_nums  [key-label $::cfg_key_line_numbers]
    # conflict detection
    set pairs [list \
        key_save $::cfg_tui_save \
        key_close $::cfg_tui_close  key_find $::cfg_tui_find \
        key_replace $::cfg_tui_replace  key_help $::cfg_tui_help \
        key_goto $::cfg_tui_goto  key_open $::cfg_tui_open \
        key_undo $::cfg_tui_undo  key_copy $::cfg_tui_copy \
        key_cut $::cfg_tui_cut  key_paste $::cfg_tui_paste \
        key_select_all $::cfg_tui_select_all  key_sticky_sel $::cfg_tui_sticky_sel \
        key_toc $::cfg_tui_toc  key_line_numbers $::cfg_tui_line_nums]
    set seen [dict create]; set conflicts {}
    foreach {name val} $pairs {
        if {[dict exists $seen $val]} {
            lappend conflicts "$name=[dict get $seen $val]"
        } else { dict set seen $val $name }
    }
    set ::cfg_key_error [join $conflicts "  "]
}
keys-init

if {$::cfg_docs_dir ne ""} {
    set ::DOCS_DIR [file normalize $::cfg_docs_dir]
    if {$::DOCS_DIR eq $::DOCS_DIR_DEFAULT} { set ::DOCS_DIR $::DOCS_DIR_DEFAULT }
    file mkdir $::DOCS_DIR
}

# ─── theme helpers ────────────────────────────────────────────────────────────
proc theme-colors {} {
    if {$::cfg_dark_mode} {
        return [list $::cfg_bg $::cfg_fg $::cfg_bg_bar $::cfg_fg_bar \
                     $::cfg_bg_sel $::cfg_color_heading $::cfg_color_dim]
    } else {
        return [list $::cfg_bg_alt $::cfg_fg_alt $::cfg_bg_bar_alt $::cfg_fg_bar_alt \
                     $::cfg_bg_sel_alt $::cfg_color_heading_alt $::cfg_color_dim_alt]
    }
}

proc toggle-dark-mode {} {
    set ::cfg_dark_mode [expr {!$::cfg_dark_mode}]
    if {!$::no_gui} { apply-theme }
}

# ─── config ───────────────────────────────────────────────────────────────────
set font    [list Mono $::cfg_font_size]
set font_sm {Mono 10}
lassign [theme-colors] bg fg bg_bar fg_bar bg_sel
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

proc parse-dim {line} {
    if {$::cfg_dim_marker eq ""} { return 0 }
    set m [regsub -all {[\\^$.|?*+()\[\]{}]} $::cfg_dim_marker {\\&}]
    return [regexp "^${m} " $line]
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

proc status-zone-of {tok} {
    if {[lsearch -exact $::cfg_status_left   $tok] >= 0} { return left }
    if {[lsearch -exact $::cfg_status_center $tok] >= 0} { return center }
    if {[lsearch -exact $::cfg_status_right  $tok] >= 0} { return right }
    return ""
}

proc status-build {tokens state} {
    set fn    [dict get $state fn]
    set dirty [dict get $state dirty]
    set sel   [dict get $state sel]
    set ln    [dict get $state ln]
    set total [dict get $state total]
    set col   [dict get $state col]
    set words [dict get $state words]
    set chars [dict get $state chars]
    set clk   [dict get $state clock]
    set result ""
    foreach tok $tokens {
        switch -- $tok {
            filename { append result $fn }
            dirty    { if {$dirty}      { append result " \[+\]" } }
            sel      { if {$sel}        { append result " \[sel\]" } }
            ln       { append result [format "  Ln %d/%d" $ln $total] }
            col      { append result [format "  Col %-3d" $col] }
            words    { if {$words >= 0} { append result "  ${words}w" } }
            chars    { if {$chars >= 0} { append result "  ${chars}c" } }
            clock    { if {$clk ne ""}  { append result "  $clk" } }
            space    { append result " " }
            help_bar {}
        }
    }
    return $result
}

if {!$::no_gui} {
wm title . "Writhdeck"
wm minsize . 500 400

# ─── browser frame ────────────────────────────────────────────────────────────
frame .br -bg $bg

label .br.title \
    -text " Writhdeck" \
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
            set label [string map [list $::HOME_DIR ~] $dir]
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
    -blockcursor 0 \
    -insertwidth [expr {$::cfg_block_cursor ? 0 : 2}] \
    -insertofftime [expr {$::cfg_block_cursor ? 0 : ($::cfg_blink_cursor ? 300 : 0)}] \
    -borderwidth 0 -padx $::cfg_margin_width -pady $::cfg_margin_height \
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
    -font [list Mono $::cfg_font_size bold]
.ed.t tag configure dim \
    -foreground $::cfg_color_dim

frame .ed.bar -bg $bg_bar
label .ed.bar.left   -textvariable ::ed_bar_left \
    -bg $bg_bar -fg $fg_bar -font $font_sm -anchor w -padx 8
label .ed.bar.msg    -textvariable ::ed_msg \
    -bg $bg_bar -fg $fg_bar -font $font_sm -anchor center -width 10
label .ed.bar.center -textvariable ::ed_bar_center \
    -bg $bg_bar -fg $fg_bar -font $font_sm -anchor center
label .ed.bar.right  -textvariable ::ed_bar_right \
    -bg $bg_bar -fg $fg_bar -font $font_sm -anchor e -padx 8
set _helpzone [status-zone-of help_bar]
if {$::cfg_help_bar ne "" && $_helpzone ne ""} {
    set _ha [expr {$_helpzone eq "right" ? "e" : ($_helpzone eq "center" ? "center" : "w")}]
    label .ed.bar.help -text $::cfg_help_bar \
        -bg $bg_bar -fg $fg_bar -font $font_sm -anchor $_ha -padx 8
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
pack .ed.t   -fill both   -expand 1
after idle cursor-setup

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
set ::wc_after_id ""
set ::gui_wc 0
set ::gui_cc 0
set ::ed_bar_left   ""
set ::ed_bar_center ""
set ::ed_bar_right  ""

proc gui-status-state {} {
    set fn    [expr {$::filename eq "" ? "\[new\]" : [file tail $::filename]}]
    lassign [split [.ed.t index insert] .] ln col
    set total [expr {[lindex [split [.ed.t index end] .] 0] - 1}]
    set words [expr {$::cfg_word_count ? $::gui_wc : -1}]
    set chars [expr {$::cfg_word_count ? $::gui_cc : -1}]
    set clk   [expr {$::cfg_show_clock ? [clock format [clock seconds] -format "%H:%M"] : ""}]
    return [dict create fn $fn dirty $::dirty sel 0 ln $ln total $total \
                col [expr {$col+1}] words $words chars $chars clock $clk]
}

proc gui-status-update {} {
    set state [gui-status-state]
    set ::ed_bar_left   " [status-build $::cfg_status_left   $state]"
    set ::ed_bar_center [status-build $::cfg_status_center $state]
    set ::ed_bar_right  "[status-build $::cfg_status_right  $state] "
}

proc wc-flush {} {
    if {$::wc_after_id ne ""} { after cancel $::wc_after_id }
    set ::wc_after_id ""
    set text [.ed.t get 1.0 end-1c]
    set ::gui_wc [llength [regexp -all -inline {\S+} $text]]
    set ::gui_cc [string length $text]
    gui-status-update
}

proc ed-status {} {
    if {$::cfg_word_count} {
        if {$::wc_after_id ne ""} { after cancel $::wc_after_id }
        set ::wc_after_id [after 400 wc-flush]
    }
    gui-status-update
    cursor-update
}

proc set-msg {text} {
    set ::msg $text
    set ::ed_msg $text
    after 2000 { set ::msg ""; set ::ed_msg ""; ed-status }
}

proc clock-tick {} {
    catch { gui-status-update }
    after 30000 clock-tick
}
if {$::cfg_show_clock && [status-zone-of clock] ne ""} { clock-tick }

# ─── block cursor (inverted, terminal-style) ──────────────────────────────────
set ::cursor_blink_id      ""
set ::cursor_blink_visible 1
set ::cursor_prev_pos      ""
set ::cursor_mode          ""   ;# "tag" | "block" | ""

proc cursor-update {} {
    if {!$::cfg_block_cursor} return
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
            .ed.t tag configure cur -background $::fg -foreground $::bg
            set ::cursor_prev_pos $pos
        } else {
            if {$::cursor_prev_pos ne ""} {
                .ed.t tag remove cur $::cursor_prev_pos "$::cursor_prev_pos +1c"
                set ::cursor_prev_pos ""
            }
            if {$::cursor_mode ne "block"} {
                .ed.t configure -blockcursor 1 -insertwidth 2 \
                    -insertofftime [expr {$::cfg_blink_cursor ? 300 : 0}] \
                    -insertbackground $::fg
                set ::cursor_mode "block"
            }
        }
    }
    if {$::cfg_blink_cursor} { set ::cursor_blink_id [after 600 cursor-blink-tick] }
}

proc cursor-blink-tick {} {
    set ::cursor_blink_id ""
    if {!$::cfg_block_cursor || !$::cfg_blink_cursor} return
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
        if {$::cfg_block_cursor} {
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

proc ln-toggle {} {
    if {[winfo exists .ed.ln]} {
        destroy .ed.ln
        set ::cfg_line_numbers 0
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
        pack .ed.ln -in .ed -side left -fill y -before .ed.t
        set ::cfg_line_numbers 1
        ln-update
    }
}

# ─── file I/O ─────────────────────────────────────────────────────────────────
proc load-file {path} {
    set ::filename $path
    wm title . "Writhdeck — [file tail $path]"
    .ed.t configure -undo 0

    .ed.t delete 1.0 end
    if {[file exists $path] && [file size $path] > 0} {
        set fh [open $path r]
        fconfigure $fh -encoding utf-8
        .ed.t insert 1.0 [read $fh]
        close $fh
}

    .ed.t edit reset
    .ed.t edit modified false

    .ed.t configure -undo 1
    .ed.t edit separator

    set ::dirty 0
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
    ed-status
    if {$::cfg_word_count} { wc-flush }
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
    wm title . "Writhdeck — [file tail $new_path]"
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
    set ::ed_msg   ""
    wm title . "Writhdeck"
    .ed.t delete 1.0 end
    search-close
    show-browser
}

proc apply-theme {} {
    lassign [theme-colors] bg fg bg_bar fg_bar bg_sel c_heading c_dim
    set ::bg $bg; set ::fg $fg; set ::bg_bar $bg_bar
    set ::fg_bar $fg_bar; set ::bg_sel $bg_sel
    # browser
    foreach w {.br .br.mid} { catch { $w configure -bg $bg } }
    foreach w {.br.title .br.bar.help .br.bar.cnt} {
        catch { $w configure -bg $bg_bar -fg $fg_bar }
    }
    catch { .br.title configure -bg $bg -fg $fg }
    catch { .br.bar configure -bg $bg_bar }
    catch { .br.mid.lst configure -bg $bg -fg $fg \
                -selectbackground $bg_sel -selectforeground $fg }
    catch { .br.mid.sb configure -bg $bg_bar -troughcolor $bg }
    # editor
    catch { .ed configure -bg $bg }
    catch { .ed.t configure -bg $bg -fg $fg \
                -insertbackground $fg -selectbackground $bg_sel \
                -blockcursor 0 \
                -insertwidth [expr {$::cfg_block_cursor ? 0 : 2}] \
                -insertofftime [expr {$::cfg_block_cursor ? 0 : ($::cfg_blink_cursor ? 300 : 0)}] }
    catch { cursor-setup }
    catch { .ed.t tag configure heading -foreground $c_heading }
    catch { .ed.t tag configure dim     -foreground $c_dim }
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
}

proc quit-app {} {
    if {$::dirty && $::filename ne ""} {
        set r [tk_messageBox \
            -message "Save \"[file tail $::filename]\" before closing?" \
            -type yesnocancel -icon question -default yes -parent .]
        if {$r eq "cancel"} return
        if {$r eq "yes"} save-file
    }
    if {$::filename ne ""} {
        lassign [split [.ed.t index insert] .] cy cx
        cursor-put $::filename $cy $cx
    }
    exit
}

wm protocol . WM_DELETE_WINDOW quit-app

# ─── editor bindings ──────────────────────────────────────────────────────────

proc ed-paste {} {
    # On X11, Tk's default <<Paste>> does not replace the selection.
    # We delete it manually so paste behaves consistently across platforms.
    if {![catch {::tk::GetSelection .ed.t CLIPBOARD} clip]} {
        .ed.t configure -autoseparators 0
        .ed.t edit separator
        catch { .ed.t delete sel.first sel.last }
        .ed.t insert insert $clip
        .ed.t edit separator
        .ed.t configure -autoseparators 1
    }
}

bind .ed.t <$::cfg_key_save>    { save-file;         break }
bind .ed.t <$::cfg_key_save_as> { save-as;           break }
bind .ed.t <$::cfg_key_close>   { close-editor;      break }
bind .ed.t <Escape>             { close-editor;      break }
bind .ed.t <$::cfg_key_paste>        { ed-paste;          break }
bind .ed.t <$::cfg_key_select_all>  { .ed.t tag add sel 1.0 end; break }
bind .ed.t <$::cfg_key_dark_toggle> { toggle-dark-mode;  break }
bind .br.mid.lst <$::cfg_key_dark_toggle> { toggle-dark-mode }

bind .ed.t <$::cfg_key_sticky_sel> { break }
bind .ed.t <Tab>                { .ed.t insert insert "    "; break }
bind .ed.t <$::cfg_key_goto>    { goto-dialog;       break }
bind .ed.t <$::cfg_key_help>    { help-dialog;       break }
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

bind .ed.t          <$::cfg_key_fullscreen> { toggle-fullscreen; break }
bind .br.mid.lst    <$::cfg_key_fullscreen> { toggle-fullscreen }

# ─── headings & TOC ───────────────────────────────────────────────────────────
proc highlight-headings {} {
    .ed.t tag remove heading 1.0 end
    .ed.t tag remove dim     1.0 end
    set last [lindex [split [.ed.t index end] .] 0]
    for {set ln 1} {$ln < $last} {incr ln} {
        set line [.ed.t get $ln.0 "$ln.0 lineend"]
        if {[parse-heading $line] ne ""} {
            .ed.t tag add heading $ln.0 "$ln.0 lineend"
        } elseif {[parse-dim $line]} {
            .ed.t tag add dim $ln.0 "$ln.0 lineend"
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
    foreach item $headings {
        lassign $item ln title
        $w.lst insert end [format "  %4d   %s" $ln $title]
    }
    $w.lst selection set $presel
    $w.lst activate $presel
    $w.lst see $presel

    bind $w.lst <Return>          [list toc-jump $w $headings]
    bind $w.lst <Double-1>        [list toc-jump $w $headings]
    bind $w.lst <ButtonRelease-1> "[list toc-jump $w $headings]; break"
    bind $w     <Escape>   [list destroy $w]
    bind $w     <$::cfg_key_toc> [list destroy $w]
    bind $w     <Destroy>  { after idle { catch { focus .ed.t } } }
    focus $w.lst
}

proc toc-jump {w headings} {
    set sel [$w.lst curselection]
    if {![llength $sel]} return
    set selIdx [lindex $sel 0]
    lassign [lindex $headings $selIdx] ln title
    dict set ::session_headings $::filename $selIdx
    destroy $w
    .ed.t mark set insert $ln.0
    .ed.t see insert
    focus .ed.t
}

bind .ed.t <$::cfg_key_toc>          { toc-show;   break }
bind .ed.t <$::cfg_key_line_numbers> { ln-toggle;  break }

# ─── taille de police dynamique ───────────────────────────────────────────────
proc apply-line-spacing {} {
    set lh [font metrics [.ed.t cget -font] -linespace]
    set extra [expr {int($lh * ($::cfg_line_spacing - 100) / 100.0)}]
    set sp [expr {max(0, $extra)}]
    .ed.t configure -spacing1 $sp -spacing2 $sp -spacing3 0
}

proc font-resize {delta} {
    set ::cfg_font_size [expr {max(6, min(72, $::cfg_font_size + $delta))}]
    set f [list Mono $::cfg_font_size]
    .ed.t configure -font $f
    .ed.t tag configure heading -font [list Mono $::cfg_font_size bold]
    apply-line-spacing
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
    wm title $w "Help — Writhdeck"
    wm resizable $w 0 0
    wm transient $w .
    grab $w

    set hm $::cfg_heading_marker
    set sections {}
    set height 22
    if {$::filename ne ""} {
        set txt [.ed.t get 1.0 end-1c]
        set wc    [llength [regexp -all -inline {\S+} $txt]]
        set chars [string length $txt]
        lappend sections "FILE INFO" [list \
            "Word count"    $wc \
            "Char count"  $chars \
        ]
        set height 25
    }
    lappend sections \
        "EDITOR" [list \
            [key-label $::cfg_key_save]         "Save" \
            [key-label $::cfg_key_save_as]      "Save as" \
            "[key-label $::cfg_key_close] / ESC" "Return to browser" \
            [key-label $::cfg_key_find]         "Find (Enter: next  Shift+Enter: prev)" \
            [key-label $::cfg_key_replace]      "Find & Replace (Enter: replace one  Ctrl+Enter: all)" \
            [key-label $::cfg_key_open]         "Open file" \
            [key-label $::cfg_key_goto]         "Go to line" \
            [key-label $::cfg_key_undo]         "Undo" \
            "Tab"                               "Insert 4 spaces" \
            [key-label $::cfg_key_toc]          "Table of contents  (${hm}title${hm})" \
            [key-label $::cfg_key_fullscreen]   "Fullscreen" \
            [key-label $::cfg_key_help]         "Help" \
        ] \
        "BROWSER" [list \
            "↵ / double-click"                  "Open" \
            "n"                                 "New file" \
            "d"                                 "Delete" \
            "r"                                 "Rename" \
            [key-label $::cfg_key_fullscreen]   "Fullscreen" \
            [key-label $::cfg_key_open]         "Open file" \
            "h / [key-label $::cfg_key_help]"   "Help" \
            "q"                                 "Quit" \
        ]

    text $w.t \
        -font {Mono 11} -state normal \
        -bg "#1a1a1a" -fg "#e8e8e8" \
        -borderwidth 0 -padx 16 -pady 12 \
        -width 52 -height $height \
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

proc ini-reload {} {
    ini-load
    set f [list Mono $::cfg_font_size]
    catch { .ed.t configure -font $f \
        -padx $::cfg_margin_width -pady $::cfg_margin_height \
        -blockcursor 0 \
        -insertwidth [expr {$::cfg_block_cursor ? 0 : 2}] \
        -insertofftime [expr {$::cfg_block_cursor ? 0 : ($::cfg_blink_cursor ? 300 : 0)}] }
    catch { .ed.t tag configure heading -font [list Mono $::cfg_font_size bold] }
    catch { apply-theme }
    catch { apply-line-spacing }
}

proc show-editor {path} {
    pack forget .br
    pack .ed -fill both -expand 1
    ini-reload
    load-file $path
    focus .ed.t
}

} ;# end if {!$::no_gui}

# ─── TUI mode ─────────────────────────────────────────────────────────────────

set ::tui_stty ""

proc tui-reverse-video {on} {
    puts -nonewline [expr {$on ? "\033\[?5h" : "\033\[?5l"}]
    flush stdout
}

proc tui-init {} {
    catch { set ::tui_stty [exec stty -g <@stdin] }
    catch { exec stty raw -echo <@stdin }
    fconfigure stdin  -blocking 1 -translation binary -buffering none
    fconfigure stdout -encoding utf-8 -buffering none
    puts -nonewline "\033\[?25l\033\[2J\033\[?2004h"
    puts -nonewline [expr {$::cfg_blink_cursor ? "\033\[1 q" : "\033\[2 q"}]
    tui-reverse-video [expr {!$::cfg_dark_mode}]
}

proc tui-cleanup {} {
    puts -nonewline "\033\[0 q\033\[?5l\033\[?2004l\033\[?25h\033\[2J\033\[H"
    flush stdout
    if {$::tui_stty ne ""} { catch {exec stty $::tui_stty <@stdin}
    } else                 { catch {exec stty sane <@stdin} }
}

set ::tui_size_cache {24 80}
set ::tui_size_n     14

proc tui-size {} {
    if {[incr ::tui_size_n] >= 15} {
        set ::tui_size_n 0
        if {![catch {scan [exec stty size <@stdin] "%d %d" r c}]} {
            set ::tui_size_cache [list $r $c]
        }
    }
    return $::tui_size_cache
}

proc tui-move {row col} { puts -nonewline "\033\[[expr {$row+1}];[expr {$col+1}]H" }

proc tui-attr {a} {
    switch $a {
        bold     -
        heading  { puts -nonewline "\033\[1m" }
        dim-text { puts -nonewline "\033\[2m" }
        dim      { puts -nonewline "\033\[2m" }
        reverse  { puts -nonewline "\033\[7m" }
        off      { puts -nonewline "\033\[0m" }
    }
}

proc tui-fill {row text cols} {
    tui-move $row 0
    set text [string range $text 0 [expr {$cols-1}]]
    puts -nonewline "${text}[string repeat { } [expr {$cols - [string length $text]}]]"
}

proc tui-bar {row left right cols {center ""}} {
    tui-attr reverse
    set llen [string length $left]
    set rlen [string length $right]
    set clen [string length $center]
    if {$clen > 0} {
        set cstart [expr {($cols - $clen) / 2}]
        set gap1   [expr {max(0, $cstart - $llen)}]
        set gap2   [expr {max(0, $cols - $llen - $gap1 - $clen - $rlen)}]
        set txt "${left}[string repeat { } $gap1]${center}[string repeat { } $gap2]${right}"
    } else {
        set gap [expr {max(0, $cols - $llen - $rlen)}]
        set txt "${left}[string repeat { } $gap]${right}"
    }
    tui-fill $row $txt $cols
    tui-attr off
}

proc tui-help {row text cols {zone left}} {
    tui-attr dim
    switch $zone {
        right  {
            set pad [expr {max(0, $cols - [string length $text] - 1)}]
            tui-fill $row "[string repeat { } $pad]$text " $cols
        }
        center {
            set pad [expr {max(0, ($cols - [string length $text]) / 2)}]
            tui-fill $row "[string repeat { } $pad]$text" $cols
        }
        default { tui-fill $row " $text" $cols }
    }
    tui-attr off
}

proc tui-help-dialog {rows cols wc cc} {
    set lbl_save   $::cfg_lbl_save;   set lbl_close  $::cfg_lbl_close
    set lbl_undo   $::cfg_lbl_undo;   set lbl_selall $::cfg_lbl_sel_all
    set lbl_sticky $::cfg_lbl_sticky; set lbl_copy   $::cfg_lbl_copy
    set lbl_find   $::cfg_lbl_find;   set lbl_cut    [key-label $::cfg_key_cut]
    set lbl_repl   $::cfg_lbl_replace; set lbl_paste $::cfg_lbl_paste
    set lbl_goto   $::cfg_lbl_goto;   set lbl_lnum   $::cfg_lbl_line_nums
    set lbl_open   $::cfg_lbl_open;   set lbl_toc    $::cfg_lbl_toc
    set lbl_help   $::cfg_lbl_help
    set lines [list \
        "  File info" \
        [format "  Words: %-8d  Chars: %d" $wc $cc] \
        "" \
        "  Writhdeck — keyboard shortcuts" \
        "" \
        [format "  %-10s Save              %-10s Undo" $lbl_save $lbl_undo] \
        [format "  %-10s Close / Esc       %-10s Select all" $lbl_close $lbl_selall] \
        [format "  %-10s Toggle selection  %-10s Copy" $lbl_sticky $lbl_copy] \
        [format "  %-10s Find              %-10s Cut" $lbl_find $lbl_cut] \
        [format "  %-10s Replace           %-10s Paste" $lbl_repl $lbl_paste] \
        [format "  %-10s Go to line        %-10s Line numbers" $lbl_goto $lbl_lnum] \
        [format "  %-10s Open (browser)" $lbl_open] \
        "" \
        "  Shift+Arrows  Extend selection" \
        "" \
        [format "  %-16s Table of contents" $lbl_toc] \
        [format "  %-16s This help" $lbl_help] \
        "" \
        "  Press any key to close" \
    ]
    set h [llength $lines]
    set w 52
    set top  [expr {max(0, ($rows - $h) / 2)}]
    set left [expr {max(0, ($cols - $w) / 2)}]
    puts -nonewline "\033\[2J"
    for {set i 0} {$i < $h} {incr i} {
        tui-move [expr {$top + $i}] $left
        set txt [lindex $lines $i]
        puts -nonewline "[string range $txt 0 [expr {$w-1}]]\033\[K"
    }
    flush stdout
    tui-getch
    puts -nonewline "\033\[2J"
}

proc tui-getch {} {
    set raw [read stdin 1]
    if {$raw eq ""} { return "" }
    scan $raw %c b
    if {$b == 27} {
        # Read escape sequence byte by byte
        set seq ""
        fconfigure stdin -blocking 0; set ch [read stdin 1]; fconfigure stdin -blocking 1
        if {$ch eq ""} { return ESC }
        append seq $ch
        switch -- $ch {
            O {
                # SS3 sequence (xterm F1-F4): read one more byte
                fconfigure stdin -blocking 0; set ch2 [read stdin 1]; fconfigure stdin -blocking 1
                if {$ch2 ne ""} { append seq $ch2 }
            }
            {[} {
                # CSI sequence: read until letter or ~
                while {[string length $seq] < 20} {
                    fconfigure stdin -blocking 0; set ch [read stdin 1]; fconfigure stdin -blocking 1
                    if {$ch eq ""} break
                    append seq $ch
                    if {[regexp {[A-Za-z~]} $ch]} break
                }
            }
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
            "\x1b\[6~"    { return NPAGE }
            "\x1b\[11~"   { return F1    }  "\x1b\[12~"   { return F2    }
            "\x1b\[13~"   { return F3    }  "\x1b\[14~"   { return F4    }
            "\x1b\[15~"   { return F5    }  "\x1b\[17~"   { return F6    }
            "\x1b\[18~"   { return F7    }  "\x1b\[19~"   { return F8    }
            "\x1b\[20~"   { return F9    }  "\x1b\[21~"   { return F10   }
            "\x1b\[23~"   { return F11   }  "\x1b\[24~"   { return F12   }
            "\x1bOP"      { return F1    }  "\x1bOQ"      { return F2    }
            "\x1bOR"      { return F3    }  "\x1bOS"      { return F4    }
            "\x1b\[\[A"   { return F1    }  "\x1b\[\[B"   { return F2    }
            "\x1b\[\[C"   { return F3    }  "\x1b\[\[D"   { return F4    }
            "\x1b\[\[E"   { return F5    }
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
    if {$b == 127} { return BACKSPACE }
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
            if {$cx == $ecol && $ecol > $scol && $nx < $n && [lindex [lindex $vrows $nx] 0] == $li \
                    && [lindex [lindex $vrows $nx] 1] <= $cx} continue
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
    set ::tui_escaped 0
    while 1 {
        set d " $label$buf"
        tui-bar [expr {$rows-1}] $d "" $cols
        puts -nonewline "\033\[?25h"; tui-move [expr {$rows-1}] [string length $d]; flush stdout
        set k [tui-getch]; puts -nonewline "\033\[?25l"
        switch -- $k {
            ESC       { set ::tui_escaped 1; return "" }
            ENTER     { return $buf }
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

        tui-attr bold; tui-fill 0 " Writhdeck" $cols; tui-attr off
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
                    set lbl [string map [list $::HOME_DIR ~] $dir]
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
            while {$row < $rows-2} { tui-move $row 0; puts -nonewline "\033\[K"; incr row }
        }
        set plu [expr {$fcount != 1 ? "s" : ""}]
        if {$::cfg_help_bar ne ""} { tui-help [expr {$rows-2}] "\u21b5 open  n new  d delete  r rename  q quit   $::cfg_lbl_help help" $cols }
        set clk [expr {$::cfg_show_clock ? "  [clock format [clock seconds] -format {%H:%M}]" : ""}]
        if {$msg ne ""} { tui-bar [expr {$rows-1}] " $msg" "${clk} " $cols; set msg ""
        } else { tui-bar [expr {$rows-1}] " [string map [list $::HOME_DIR ~] $::DOCS_DIR_DEFAULT]" \
                         " $fcount file${plu}${clk} " $cols }
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

proc tui-toc {lines rows cols {cy 1} {filepath ""}} {
    set headings {}; set ln 1
    foreach line $lines {
        set t [parse-heading $line]
        if {$t ne ""} { lappend headings [list $ln $t] }
        incr ln
    }
    if {![llength $headings]} { return {} }
    set sel 0
    if {$filepath ne "" && [dict exists $::session_headings $filepath]} {
        set sel [dict get $::session_headings $filepath]
        if {$sel >= [llength $headings]} { set sel 0 }
    } else {
        set idx 0
        foreach h $headings {
            if {[lindex $h 0] <= $cy} { set sel $idx }
            incr idx
        }
    }
    set scroll 0
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
            ESC      { return {} }
            UP - k   { if {$sel > 0} { incr sel -1 } }
            DOWN - j { if {$sel < $nh-1} { incr sel 1 } }
            HOME     { set sel 0 }
            END      { set sel [expr {$nh-1}] }
            ENTER    { if {$filepath ne ""} { dict set ::session_headings $filepath $sel }
                       return [lindex $headings $sel] }
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
    if {[dict exists $::session_headings $filepath]} {
        set hidx [dict get $::session_headings $filepath]
        set hi 0; set ln 1
        foreach tline $lines {
            if {[parse-heading $tline] ne ""} {
                if {$hi == $hidx} { set cy $ln; set cx 0; break }
                incr hi
            }
            incr ln
        }
    }
    set cy [expr {max(1, min($cy, [llength $lines]))}]
    set cx [expr {max(0, min($cx, [string length [lindex $lines [expr {$cy-1}]]]))}]

    set scroll_y 0
    set toc_jumped 0
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
    set wc_dirty 1; set wrap_dirty 1; set wc_cached 0; set cc_cached 0
    set wrap_dirty 1; set vrows {}; set prev_tw -1
    set ish_cache {}; set isd_cache {}

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

        if {$wrap_dirty || $tw != $prev_tw} {
            set vrows [tui-wrap-map $lines $tw]
            set prev_tw $tw; set wrap_dirty 0
            set ish_cache {}; set isd_cache {}
            foreach _l $lines {
                lappend ish_cache [expr {[parse-heading $_l] ne ""}]
                lappend isd_cache [parse-dim $_l]
            }
            unset _l
        }
        lassign [tui-l2v $vrows $cy $cx] vi scx

        if {$toc_jumped} { set scroll_y $vi; set toc_jumped 0 } else {
            if {$vi < $scroll_y}        { set scroll_y $vi }
            if {$vi >= $scroll_y + $th} { set scroll_y [expr {$vi - $th + 1}] }
        }
        set scroll_y [expr {max(0, min($scroll_y, max(0, [llength $vrows] - $th)))}]

        # ── draw ──────────────────────────────────────────────────────────────
        set sel_r [tui-sel-range $sel_anchor $cy $cx]
        if {$sel_r ne {}} { lassign $sel_r _sly _scx_s _ely _ecx_s }

        for {set i 0} {$i < $th} {incr i} {
            set vi2 [expr {$scroll_y + $i}]
            set srow [expr {$i + $roff}]
            if {$vi2 >= [llength $vrows]} {
                tui-move $srow 0; puts -nonewline "\033\[K"
                continue
            }
            lassign [lindex $vrows $vi2] li scol ecol
            set seg [string range [lindex $lines [expr {$li-1}]] $scol [expr {$ecol-1}]]
            set ish [lindex $ish_cache [expr {$li-1}]]
            set isd [lindex $isd_cache [expr {$li-1}]]

            # left margin + line number
            tui-move $srow 0; puts -nonewline "\033\[K"
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
            set seg_len [string length $seg]
            set sf -1
            if {$sel_r ne {}} {
                if      {$li > $_sly && $li < $_ely}         { set sf 0;                              set st $seg_len } \
                elseif  {$li == $_sly && $li == $_ely}        { set sf [expr {max(0,$_scx_s-$scol)}]; set st [expr {min($seg_len,$_ecx_s-$scol)}] } \
                elseif  {$li == $_sly}                        { set sf [expr {max(0,$_scx_s-$scol)}]; set st $seg_len } \
                elseif  {$li == $_ely}                        { set sf 0;                              set st [expr {min($seg_len,$_ecx_s-$scol)}] }
                if {$sf >= 0 && $sf >= $st} { set sf -1 }
            }
            if {$sf >= 0} {
                if {$sf > 0} {
                    if {$ish} { tui-attr heading } elseif {$isd} { tui-attr dim-text }
                    puts -nonewline [string range $seg 0 [expr {$sf-1}]]
                    if {$ish || $isd} { tui-attr off }
                }
                tui-attr reverse
                puts -nonewline [string range $seg $sf [expr {$st-1}]]
                tui-attr off
                if {$st < $seg_len} {
                    if {$ish} { tui-attr heading } elseif {$isd} { tui-attr dim-text }
                    puts -nonewline [string range $seg $st end]
                    if {$ish || $isd} { tui-attr off }
                }
            } else {
                if {$ish} { tui-attr heading } elseif {$isd} { tui-attr dim-text }
                puts -nonewline $seg
                if {$ish || $isd} { tui-attr off }
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
        set sel_info [expr {$sel_r ne {} ? " \[sel\]" : ""}]
        set sel_hint [expr {$sel_anchor ne "" ? "$::cfg_lbl_sticky cancel-sel" : "$::cfg_lbl_sticky sel"}]
        set _hzone [status-zone-of help_bar]
        if {$::cfg_help_bar ne "" && $_hzone ne ""} { tui-help [expr {$rows-2}] $::cfg_help_bar $cols $_hzone }
        if {$::cfg_word_count && $wc_dirty} {
            set wc_cached 0; set cc_cached 0
            foreach l $lines {
                incr wc_cached [llength [regexp -all -inline {\S+} $l]]
                incr cc_cached [string length $l]
            }
            set wc_dirty 0
        }
        set clk [expr {$::cfg_show_clock ? [clock format [clock seconds] -format "%H:%M"] : ""}]
        set tui_state [dict create \
            fn    [file tail $filepath] \
            dirty $dirty \
            sel   [expr {$sel_anchor ne ""}] \
            ln    $cy  total [llength $lines] \
            col   [expr {$cx+1}] \
            words [expr {$::cfg_word_count ? $wc_cached : -1}] \
            chars [expr {$::cfg_word_count ? $cc_cached : -1}] \
            clock $clk]
        set bar_left   " [status-build $::cfg_status_left   $tui_state]"
        set bar_center [status-build $::cfg_status_center $tui_state]
        set bar_right  "[status-build $::cfg_status_right  $tui_state] "
        if {$::cfg_key_error ne "" && $message eq ""} { set message "key conflict: $::cfg_key_error"; set msg_time [clock seconds] }
        if {$message ne "" && [clock seconds] - $msg_time < 4} { set bar_left " $message" }
        tui-bar [expr {$rows-1}] $bar_left $bar_right $cols $bar_center

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
                    lassign [tui-sel-delete $lines $sel_anchor $cy $cx] lines cy cx; set dirty 1; set wc_dirty 1; set wrap_dirty 1
                } elseif {$cx > 0} {
                    set l [lindex $lines [expr {$cy-1}]]
                    lset lines [expr {$cy-1}] "[string range $l 0 [expr {$cx-2}]][string range $l $cx end]"
                    incr cx -1; set dirty 1; set wc_dirty 1; set wrap_dirty 1
                } elseif {$cy > 1} {
                    set cx [string length [lindex $lines [expr {$cy-2}]]]
                    lset lines [expr {$cy-2}] "[lindex $lines [expr {$cy-2}]][lindex $lines [expr {$cy-1}]]"
                    set lines [lreplace $lines [expr {$cy-1}] [expr {$cy-1}]]
                    incr cy -1; set dirty 1; set wc_dirty 1; set wrap_dirty 1
                }
            }
            DC {
                eval $push_undo
                if {$sel_anchor ne ""} {
                    lassign [tui-sel-delete $lines $sel_anchor $cy $cx] lines cy cx; set dirty 1; set wc_dirty 1; set wrap_dirty 1
                } else {
                    set l [lindex $lines [expr {$cy-1}]]
                    if {$cx < [string length $l]} {
                        lset lines [expr {$cy-1}] "[string range $l 0 [expr {$cx-1}]][string range $l [expr {$cx+1}] end]"
                        set dirty 1; set wc_dirty 1; set wrap_dirty 1
                    } elseif {$cy < [llength $lines]} {
                        lset lines [expr {$cy-1}] "${l}[lindex $lines $cy]"
                        set lines [lreplace $lines $cy $cy]; set dirty 1; set wc_dirty 1; set wrap_dirty 1
                    }
                }
            }
            ENTER {
                eval $push_undo
                if {$sel_anchor ne ""} { lassign [tui-sel-delete $lines $sel_anchor $cy $cx] lines cy cx; set dirty 1; set wc_dirty 1; set wrap_dirty 1 }
                set l [lindex $lines [expr {$cy-1}]]
                set lines [linsert [lreplace $lines [expr {$cy-1}] [expr {$cy-1}] \
                    [string range $l 0 [expr {$cx-1}]]] $cy [string range $l $cx end]]
                incr cy; set cx 0; set dirty 1; set wc_dirty 1; set wrap_dirty 1
            }
            TAB {
                eval $push_undo
                if {$sel_anchor ne ""} { lassign [tui-sel-delete $lines $sel_anchor $cy $cx] lines cy cx; set dirty 1; set wc_dirty 1; set wrap_dirty 1 }
                set l [lindex $lines [expr {$cy-1}]]
                lset lines [expr {$cy-1}] "[string range $l 0 [expr {$cx-1}]]    [string range $l $cx end]"
                incr cx 4; set dirty 1; set wc_dirty 1; set wrap_dirty 1
            }
            default {
                set c [scan $key %c]
                if {$key eq $::cfg_tui_save} {
                    set fh [open $filepath w]; fconfigure $fh -encoding utf-8
                    puts -nonewline $fh "[join $lines \n]\n"; close $fh
                    cursor-put $filepath $cy $cx
                    set dirty 0; set message "saved"; set msg_time [clock seconds]
                    set clear_sel 0
                } elseif {$key eq $::cfg_tui_close || $key eq "ESC"} {
                    if {$dirty} {
                        lassign [tui-size] rows cols
                        if {[tui-confirm "save before closing?" $rows $cols]} {
                            set fh [open $filepath w]; fconfigure $fh -encoding utf-8
                            puts -nonewline $fh "[join $lines \n]\n"; close $fh
                        }
                    }
                    cursor-put $filepath $cy $cx; return
                } elseif {$key eq $::cfg_tui_open} {
                    set fh [open $filepath w]; fconfigure $fh -encoding utf-8
                    puts -nonewline $fh "[join $lines \n]\n"; close $fh
                    cursor-put $filepath $cy $cx; set dirty 0; return
                } elseif {$key eq $::cfg_tui_undo} {
                    if {[llength $undo_stack] > 0} {
                        lassign [lindex $undo_stack end] lines cy cx
                        set undo_stack [lrange $undo_stack 0 end-1]; set dirty 1; set wc_dirty 1; set wrap_dirty 1
                    }
                    set clear_sel 0
                } elseif {$key eq $::cfg_tui_sticky_sel} {
                    if {$sel_sticky} {
                        set sel_sticky 0; set sel_anchor ""
                    } else {
                        set sel_sticky 1; set sel_anchor [list $cy $cx]
                    }
                    set clear_sel 0
                } elseif {$key eq $::cfg_tui_select_all} {
                    set sel_anchor [list 1 0]
                    set cy [llength $lines]; set cx [string length [lindex $lines end]]
                    set clear_sel 0
                } elseif {$key eq $::cfg_tui_copy} {
                    set txt [tui-sel-text $lines $sel_anchor $cy $cx]
                    if {$txt ne ""} { tui-copy $txt; set message "copied"; set msg_time [clock seconds] }
                    set clear_sel 0
                } elseif {$key eq $::cfg_tui_cut} {
                    set txt [tui-sel-text $lines $sel_anchor $cy $cx]
                    if {$txt ne ""} {
                        eval $push_undo; tui-copy $txt
                        lassign [tui-sel-delete $lines $sel_anchor $cy $cx] lines cy cx
                        set dirty 1; set wc_dirty 1; set wrap_dirty 1; set message "cut"; set msg_time [clock seconds]
                    }
                } elseif {$key eq $::cfg_tui_paste || [string match "PASTE:*" $key]} {
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
                        set dirty 1; set wc_dirty 1; set wrap_dirty 1
                    }
                } elseif {$key eq $::cfg_tui_find} {
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
                } elseif {$key eq $::cfg_tui_replace} {
                    lassign [tui-size] rows cols
                    set term [string trim [tui-prompt "find: " $rows $cols]]
                    if {$term ne ""} { set ::tui_search $term }
                    if {$::tui_search ne ""} {
                        set repl [tui-prompt "replace with (ESC=cancel): " $rows $cols]
                        if {!$::tui_escaped} {
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
                                eval $push_undo; set lines $new_lines; set dirty 1; set wc_dirty 1; set wrap_dirty 1
                                set message "replaced $count occurrence[expr {$count!=1?{s}:{}}]"
                                set msg_time [clock seconds]
                                set cy [expr {max(1, min($cy, [llength $lines]))}]
                                set cx [expr {max(0, min($cx, [string length [lindex $lines [expr {$cy-1}]]]))}]
                            } else { set message "not found: $::tui_search"; set msg_time [clock seconds] }
                        }
                    }
                    set clear_sel 0
                } elseif {$key eq $::cfg_tui_goto} {
                    lassign [tui-size] rows cols
                    set num [tui-prompt "go to line: " $rows $cols]
                    if {[string is integer -strict $num] && $num >= 1} {
                        set cy [expr {min($num, [llength $lines])}]; set cx 0
                    }
                } elseif {$key eq $::cfg_tui_toc} {
                    lassign [tui-size] rows cols
                    set target [tui-toc $lines $rows $cols $cy $filepath]
                    puts -nonewline "\033\[2J"
                    if {[llength $target] == 2} {
                        set cy [lindex $target 0]; set cx 0
                        set toc_jumped 1
                    }
                } elseif {$key eq $::cfg_tui_dark_toggle} {
                    set ::cfg_dark_mode [expr {!$::cfg_dark_mode}]
                    tui-reverse-video [expr {!$::cfg_dark_mode}]
                    set clear_sel 0
                } elseif {$key eq $::cfg_tui_line_nums} {
                    set ::cfg_line_numbers [expr {$::cfg_line_numbers ? 0 : 1}]
                    set clear_sel 0
                } elseif {$key eq $::cfg_tui_help} {
                    lassign [tui-size] rows cols
                    if {$wc_dirty} {
                        set wc_cached 0; set cc_cached 0
                        foreach l $lines {
                            incr wc_cached [llength [regexp -all -inline {\S+} $l]]
                            incr cc_cached [string length $l]
                        }
                        set wc_dirty 0
                    }
                    tui-help-dialog $rows $cols $wc_cached $cc_cached
                    set clear_sel 0
                } elseif {[string match "F*" $key]} {                          ;# ignore unknown F-keys
                    set clear_sel 0
                } elseif {[string length $key] >= 1 && ($c eq "" || $c >= 32)} {
                    eval $push_undo
                    if {$sel_anchor ne ""} { lassign [tui-sel-delete $lines $sel_anchor $cy $cx] lines cy cx; set dirty 1; set wc_dirty 1; set wrap_dirty 1 }
                    set l [lindex $lines [expr {$cy-1}]]
                    lset lines [expr {$cy-1}] "[string range $l 0 [expr {$cx-1}]]${key}[string range $l $cx end]"
                    incr cx [string length $key]; set dirty 1; set wc_dirty 1; set wrap_dirty 1
                }
            }
        }
        if {$rst}       { set sticky -1 }
        if {$clear_sel} { set sel_anchor ""; set sel_sticky 0 }
    }
}

proc tui-main {} {
    if {$::tcl_platform(platform) eq "windows"} {
        puts stderr "writhdeck: TUI mode is not supported on Windows"
        exit 1
    }
    if {[catch {exec stty -g <@stdin}]} {
        puts stderr "writhdeck: not a terminal"
        exit 1
    }
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
                puts -nonewline "\033\[2J"; flush stdout
                tui-editor $fp
            }
        }
    } err info]
    tui-cleanup
    if {$ok} { puts stderr $err }
}

# ─── start ────────────────────────────────────────────────────────────────────
if {$::no_gui && $::tcl_platform(platform) eq "windows"} {
    # On Windows without Tk, show a helpful message in a console or dialog
    catch {
        package require Tk
        tk_messageBox -title "Writhdeck" \
            -message "Please run writhdeck.tcl with wish.exe, not tclsh.exe.\n\nExample:\n  wish.exe writhdeck.tcl" \
            -icon info
    } err
    if {$err ne ""} {
        puts stderr "writhdeck: please run with wish.exe, not tclsh.exe"
    }
    exit 1
}
if {$::no_gui} {
    tui-main
} else {
    if {$::tcl_platform(platform) eq "windows"} {
        proc bgerror {msg} {
            tk_messageBox -title "Writhdeck Error" -message $msg -icon error -type ok
        }
    }
    if {[file exists "writhdeck.png"]} {
        catch { wm iconphoto . [image create photo -file "writhdeck.png"] }
    }
    if {$::argc > 0} { show-editor [lindex $::argv 0] } else { show-browser }
    if {$::cfg_key_error ne ""} {
        after 100 [list set-msg "key conflict: $::cfg_key_error"]
    }
}
