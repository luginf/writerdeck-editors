#!/bin/sh
# sh/Tcl polyglot - backslash continues Tcl comment to next line, hiding shell bootstrap \
_w=$(stty -g 2>/dev/null); trap '[ -n "$_w" ] && stty "$_w" 2>/dev/null' EXIT INT TERM; tclsh "$0" "$@"; exit $?

# # # # # # # # # # # #
#
#     writhdeck.tcl (CLI-only build)
#
#  ~  Tcl/Tk 8.6 (console/TUI) text editor for writerdecks ~
#
#     Usage: tclsh writhdeck-cli.tcl [filename]
#
#    https://github.com/luginf/writhdeck
#    -----------------------------
#    Copyright (C) 2026 by Luginfo
#
#    BSD Zero Clause License
#
#    Permission to use, copy, modify, and/or distribute this software
#    for any purpose with or without fee is hereby granted.
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

set ::version          "v20260518"

# bail out immediately when invoked by bash tab-completion
if {[info exists ::env(COMP_LINE)] || [info exists ::env(COMP_POINT)]} { exit 0 }

if {[lsearch $::argv "--help"] >= 0 || [lsearch $::argv "-h"] >= 0} {
    puts "Usage: writhdeck-cli.tcl \[FILE\]

writhdeck CLI-only (TUI) mode. No GUI/Tk support.

Keyboard shortcuts (defaults - configurable in writhdeck.ini):
  ^S  Save              ^Z  Undo           ^Y  Redo
  ^Q  Close / Esc       ^F  Find           ^R  Find & Replace
  ^H  Help              ^G  Go to line     ^O  Open file
  ^A  Select all        ^K  Toggle sticky selection
  ^C  Copy              ^X  Cut            ^V  Paste
  ^L  Line numbers      ^D  Dark/light toggle
  ^Space  Next space    ^Shift+Space  Prev space"
    exit 0
}

set ::no_gui    1
set ::force_gui 0
foreach _f {--no-gui --tui --ng --cli --gui} { set ::argv [lsearch -all -inline -not $::argv $_f] }
unset _f
set ::argc [llength $::argv]

set ::HOME_DIR [expr {[info exists ::env(HOME)] ? $::env(HOME) : \
    ([info exists ::env(USERPROFILE)] ? $::env(USERPROFILE) : [file normalize ~])}]

# Tcl 9 no longer expands ~ in file normalize; this proc handles it explicitly.
proc tilde-expand {path} {
    if {[string index $path 0] ne "~"} { return $path }
    if {$path eq "~" || [string index $path 1] eq "/"} {
        return $::HOME_DIR[string range $path 1 end]
    }
    return $path
}

set ::DOCS_DIR_DEFAULT [file join $::HOME_DIR Documents writhdeck]
  # set ::DOCS_DIR_DEFAULT "C:/Temp/writhdeck"       ;# Windows custom
  # set ::DOCS_DIR_DEFAULT "/tmp/writhdeck"         ;# Linux custom
set ::DOCS_DIR         $::DOCS_DIR_DEFAULT
set ::INI_FILE         [file join $::DOCS_DIR_DEFAULT "writhdeck.ini"]
set ::FILE_EXT ".txt"
set ::filename        ""
set ::dirty           0

# ===========================================================================
# state.tcl
# ===========================================================================
set ::msg             ""
set ::ed_msg          ""
set ::msg_after_id    ""
set ::scratchpad      0
set ::file_mtime_known 0
set ::watch_after_id  ""
set ::session_headings {}
set ::gui_cmd_mode    0
set ::tui_cmd_mode    0

file mkdir $::DOCS_DIR_DEFAULT
set ::STATE_FILE        [file join $::DOCS_DIR_DEFAULT ".writhdeck.json"]
set ::cursor_cache      {}
set ::favorites_list    {}
set ::recent_list       {}
set ::daily_data        {}
set ::session_file        ""
set ::session_baseline    -1
set ::session_max_today   0
set ::state_cache_valid   0

# --- state persistence (.writhdeck.json) --------------------------------------
# Format: {"cursors":{"path":[cy,cx],...},"favorites":[...],"recent":[...],"daily":["path\tdate\tN",...]}
proc state-parse-array {raw key} {
    set ri [string first "\"$key\"" $raw]
    if {$ri < 0} { return {} }
    set ai [string first "\[" $raw $ri]
    set ae [string first "\]" $raw [expr {$ai + 1}]]
    if {$ai < 0 || $ae < 0} { return {} }
    set sub [string range $raw [expr {$ai + 1}] [expr {$ae - 1}]]
    set result {}
    set re {"((?:[^"\\]|\\.)*)"}
    set start 0
    while {[regexp -start $start -indices $re $sub match item]} {
        set item_text [string range $sub {*}$item]
        lappend result $item_text
        set end [lindex $match 1]
        set start [expr {$end + 1}]
    }
    return $result
}

proc state-load {} {
    set ::cursor_cache   {}
    set ::favorites_list {}
    set ::recent_list    {}
    set ::daily_data     {}
    if {![file exists $::STATE_FILE]} { set ::state_cache_valid 1; return }
    set fh [open $::STATE_FILE r]; chan configure $fh -encoding utf-8
    set raw [read $fh]; close $fh
    set ci [string first "\"cursors\"" $raw]
    if {$ci >= 0} {
        set ob [string first "\{" $raw $ci]
        set cb [string first "\}" $raw [expr {$ob + 1}]]
        if {$ob >= 0 && $cb >= 0} {
            set sub [string range $raw [expr {$ob + 1}] [expr {$cb - 1}]]
            set re {"([^"\\]*)"\s*:\s*\[(\d+)\s*,\s*(\d+)\]}
            set start 0
            while {[regexp -start $start $re $sub -> key cy cx]} {
                dict set ::cursor_cache $key [list [expr {int($cy)}] [expr {int($cx)}]]
                set idx [string first "\"$key\"" $sub $start]
                set start [expr {$idx + [string length $key] + 2}]
            }
        }
    }
    foreach p [state-parse-array $raw "favorites"] { lappend ::favorites_list [file normalize $p] }
    foreach p [state-parse-array $raw "recent"]    { lappend ::recent_list    [file normalize $p] }
    set new_cache {}
    dict for {k v} $::cursor_cache { dict set new_cache [file normalize $k] $v }
    set ::cursor_cache $new_cache
    foreach item [state-parse-array $raw "daily"] {
        set item [string map [list {\t} "\t"] $item]
        set parts [split $item "\t"]
        if {[llength $parts] >= 3} {
            set fp [file normalize [lindex $parts 0]]
            if {![dict exists $::daily_data $fp]} { dict set ::daily_data $fp {} }
            for {set i 1} {$i + 1 < [llength $parts]} {incr i 2} {
                set date [lindex $parts $i]
                set cnt  [lindex $parts [expr {$i + 1}]]
                dict set ::daily_data $fp $date [expr {int($cnt)}]
            }
        }
    }
    set ::state_cache_valid 1
    daily-cleanup
}

proc state-save {} {
    set cp {}
    dict for {k v} $::cursor_cache {
        set ke [string map {\\ \\\\ \" \\\"} $k]
        lappend cp "\"$ke\":\[[lindex $v 0],[lindex $v 1]\]"
    }
    set fp {}
    foreach p $::favorites_list { lappend fp "\"[string map {\\ \\\\ \" \\\"} $p]\"" }
    set rp {}
    foreach p $::recent_list    { lappend rp "\"[string map {\\ \\\\ \" \\\"} $p]\"" }
    set dp {}
    dict for {fpath fdata} $::daily_data {
        set entry [string map {\\ \\\\ \" \\\"} $fpath]
        dict for {date cnt} $fdata {
            append entry "\\t${date}\\t${cnt}"
        }
        lappend dp "\"${entry}\""
    }
    set fh [open $::STATE_FILE w]; chan configure $fh -encoding utf-8
    puts $fh "\{"
    if {[llength $cp]} {
        puts $fh "\"cursors\":\{\n[join $cp ",\n"]\n\},"
    } else {
        puts $fh "\"cursors\":\{\},"
    }
    if {[llength $fp]} {
        puts $fh "\"favorites\":\[\n[join $fp ",\n"]\n\],"
    } else {
        puts $fh "\"favorites\":\[\],"
    }
    if {[llength $rp]} {
        puts $fh "\"recent\":\[\n[join $rp ",\n"]\n\],"
    } else {
        puts $fh "\"recent\":\[\],"
    }
    if {[llength $dp]} {
        puts $fh "\"daily\":\[\n[join $dp ",\n"]\n\]"
    } else {
        puts $fh "\"daily\":\[\]"
    }
    puts $fh "\}"
    close $fh
}

proc cursor-get {filepath} {
    if {!$::cfg_cursor_restore} { return {1 0} }
    set filepath [file normalize $filepath]
    if {!$::state_cache_valid} { state-load }
    if {[dict exists $::cursor_cache $filepath]} {
        lassign [dict get $::cursor_cache $filepath] cy cx
        return [list [expr {$cy + 1}] $cx]
    }
    return {1 0}
}

proc cursor-put {filepath cy cx} {
    if {!$::cfg_cursor_restore} return
    set filepath [file normalize $filepath]
    if {!$::state_cache_valid} { state-load }
    dict set ::cursor_cache $filepath [list [expr {$cy - 1}] $cx]
    state-save
}

# ===========================================================================
# config.tcl
# ===========================================================================

proc recent-push {path} {
    set path [file normalize $path]
    if {!$::state_cache_valid} { state-load }
    set ::recent_list [lsearch -all -inline -not -exact $::recent_list $path]
    set ::recent_list [linsert $::recent_list 0 $path]
    if {[llength $::recent_list] > 5} { set ::recent_list [lrange $::recent_list 0 4] }
    state-save
}

proc recent-remove {path} {
    set path [file normalize $path]
    if {!$::state_cache_valid} { state-load }
    set ::recent_list [lsearch -all -inline -not -exact $::recent_list $path]
    state-save
}

proc recent-rename {old new} {
    set old [file normalize $old]
    set new [file normalize $new]
    if {!$::state_cache_valid} { state-load }
    set changed 0
    set idx [lsearch -exact $::recent_list $old]
    if {$idx >= 0} { set ::recent_list [lreplace $::recent_list $idx $idx $new]; set changed 1 }
    set idx [lsearch -exact $::favorites_list $old]
    if {$idx >= 0} { set ::favorites_list [lreplace $::favorites_list $idx $idx $new]; set changed 1 }
    if {$changed} { state-save }
}

# --- daily writing stats ------------------------------------------------------
proc daily-open {filepath wc} {
    set filepath [file normalize $filepath]
    set ::session_file $filepath
    set today [clock format [clock seconds] -format "%Y-%m-%d"]
    if {!$::state_cache_valid} { state-load }
    set prior 0
    if {[dict exists $::daily_data $filepath] &&
        [dict exists [dict get $::daily_data $filepath] $today]} {
        set prior [dict get [dict get $::daily_data $filepath] $today]
    }
    set ::session_baseline  [expr {$wc - $prior}]
    set ::session_max_today $prior
}

proc daily-today {wc} {
    if {$::session_baseline < 0} { return 0 }
    set current [expr {max(0, $wc - $::session_baseline)}]
    if {$current > $::session_max_today} { set ::session_max_today $current }
    return $::session_max_today
}

proc daily-update {wc} {
    if {$::session_file eq "" || $::session_baseline < 0} return
    set today [clock format [clock seconds] -format "%Y-%m-%d"]
    set added [daily-today $wc]
    if {![dict exists $::daily_data $::session_file]} { dict set ::daily_data $::session_file {} }
    dict set ::daily_data $::session_file $today $added
    state-save
}

proc daily-cleanup {} {
    set today [clock format [clock seconds] -format "%Y-%m-%d"]
    set new_data {}
    dict for {fp fdata} $::daily_data {
        if {$fp in $::favorites_list} {
            dict set new_data $fp $fdata
        } else {
            if {[dict exists $fdata $today]} {
                dict set new_data $fp [dict create $today [dict get $fdata $today]]
            }
        }
    }
    set ::daily_data $new_data
}

proc daily-clear {filepath} {
    set filepath [file normalize $filepath]
    if {[dict exists $::daily_data $filepath]} {
        dict unset ::daily_data $filepath
    }
    state-save
}

# --- schemes (loaded from src/schemes/*.tcl) --------------------------------
set ::scheme_defs  {}

# --- ini ----------------------------------------------------------------------
set ::cfg_scheme   "default"
set ::cfg_schemes  {}
set ::cfg_profile  "default"
set ::cfg_profiles {}
set ::cfg_margin_width        60
set ::cfg_margin_height       40
set ::cfg_split_shrink_margin 1
set ::cfg_watch_file          1
set ::cfg_hemingway_mode      0
set ::cfg_font_size      13
set ::cfg_font_family    "Mono"
set ::cfg_bar_font_family "Mono"
set ::cfg_bg             "#1a1a1a"
set ::cfg_fg             "#e8e8e8"
set ::cfg_bg_bar         "#2a2a2a"
set ::cfg_fg_bar         "#aaaaaa"
set ::cfg_bg_sel         "#3a5a8a"
set ::cfg_docs_dir       ""
set ::cfg_console_margin_cols    6
set ::cfg_console_margin_rows    4
set ::cfg_heading_marker    "="
set ::cfg_markdown_headings 1
set ::cfg_color_heading  "#c8a060"
set ::cfg_comment_marker "%"
set ::cfg_color_comment  "#606060"
set ::cfg_bold_marker          "**"
set ::cfg_italic_marker        "//"
set ::cfg_underline_marker     "__"
set ::cfg_strikethrough_marker "--"
set ::cfg_color_markup         "#6aa9d4"
# alternate (light) theme - used when dark_mode = 0
set ::cfg_bg_alt             "#fdf6e3"
set ::cfg_fg_alt             "#657b83"
set ::cfg_bg_bar_alt         "#eee8d5"
set ::cfg_fg_bar_alt         "#93a1a1"
set ::cfg_bg_sel_alt         "#e6ddb9"
set ::cfg_color_heading_alt  "#b58900"
set ::cfg_color_comment_alt  "#aaaaaa"
set ::cfg_color_markup_alt   "#2a7090"
# dark_mode: 0 = light (alt colors), 1 = dark (primary colors)
set ::cfg_dark_mode          1
set ::cfg_key_dark_toggle    "Control-d"
set ::cfg_browser              1
set ::cfg_console_center_alert 1
set ::cfg_line_numbers   0
set ::cfg_cursor_restore 1
set ::cfg_block_cursor_gui     1
set ::cfg_block_cursor_console 1
set ::cfg_blink_cursor         0
set ::cfg_line_spacing   100
set ::cfg_bar_height     18
set ::cfg_lang           "en"
set ::cfg_help_bar       "^S save   ^Q close   ^H help"
set ::cfg_word_goal      500
# status bar zones - tokens: filename dirty sel ln col words chars goal clock help_bar space
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
set ::cfg_key_redo         "Control-y"
set ::cfg_key_typewriter   "Control-t"
set ::cfg_key_fullscreen   "Alt-Return"
set ::cfg_key_split        "F3"
set ::cfg_key_split_focus  "F4"
set ::cfg_key_timer        "Alt-t"
set ::cfg_key_error        ""
set ::cfg_timer_duration   25
set ::cfg_timer_sound      1
set ::cfg_timer_alert      1
set ::cfg_chrono_show      1
set ::cfg_timer_type       "countdown"
set ::timer_active         0
set ::timer_remaining      0
set ::timer_last_tick      0
set ::timer_schedule_id    ""
set ::timer_alert_shown    0
set ::fullscreen 0
set ::split_mode 0

proc marker-val {v} { expr {$v eq "0" ? "" : $v} }

proc timer-alert {} {
    if {$::timer_alert_shown} return
    set ::timer_alert_shown 1
    if {$::cfg_timer_sound} { puts -nonewline "\a"; flush stdout }
    if {!$::no_gui} {
        catch { timer-alert-gui }
    } else {
        catch { tui-timer-alert }
    }
}

proc timer-tick {} {
    if {!$::timer_active} return
    if {$::cfg_timer_type eq "countdown" && $::timer_remaining <= 0} return
    set now [clock seconds]
    if {$::timer_last_tick == 0} {
        set ::timer_last_tick $now
        return
    }
    if {$now > $::timer_last_tick} {
        if {$::cfg_timer_type eq "countdown"} {
            incr ::timer_remaining -[expr {$now - $::timer_last_tick}]
            if {$::timer_remaining < 0} { set ::timer_remaining 0 }
            if {$::timer_remaining == 0 && $::cfg_timer_alert} {
                timer-alert
            }
        } else {
            incr ::timer_remaining [expr {$now - $::timer_last_tick}]
        }
        set ::timer_last_tick $now
        if {!$::no_gui} { catch {ed-status} }
    }
}

proc timer-schedule {} {
    if {$::timer_active && $::cfg_chrono_show} {
        set ::timer_schedule_id [after 1000 timer-schedule-tick]
    } else {
        if {$::timer_schedule_id ne ""} {
            catch {after cancel $::timer_schedule_id}
            set ::timer_schedule_id ""
        }
    }
}

proc timer-schedule-tick {} {
    timer-tick
    timer-schedule
}

proc timer-start {} {
    if {$::cfg_timer_type eq "countdown"} {
        set ::timer_remaining [expr {$::cfg_timer_duration * 60}]
    } else {
        set ::timer_remaining 0
    }
    set ::timer_active 1
    set ::timer_alert_shown 0
    set ::timer_last_tick [clock seconds]
    timer-schedule
}

proc timer-pause {} {
    set ::timer_active 0
    if {$::timer_schedule_id ne ""} {
        catch {after cancel $::timer_schedule_id}
        set ::timer_schedule_id ""
    }
}

proc timer-reset {} {
    set ::timer_active 0
    if {$::cfg_timer_type eq "countdown"} {
        set ::timer_remaining [expr {$::cfg_timer_duration * 60}]
    } else {
        set ::timer_remaining 0
    }
    set ::timer_last_tick 0
    if {$::timer_schedule_id ne ""} {
        catch {after cancel $::timer_schedule_id}
        set ::timer_schedule_id ""
    }
    if {!$::no_gui} { catch {ed-status} }
}

proc profile-apply {name} {
    if {![dict exists $::cfg_profiles $name]} return
    set d [dict get $::cfg_profiles $name]
    foreach {key var} {
        margin_width     ::cfg_margin_width
        margin_height    ::cfg_margin_height
        font_size        ::cfg_font_size
        font_family      ::cfg_font_family
        bar_font_family  ::cfg_bar_font_family
        line_spacing     ::cfg_line_spacing
        bar_height       ::cfg_bar_height
        word_goal        ::cfg_word_goal
        lang             ::cfg_lang
        line_numbers     ::cfg_line_numbers
        status_left      ::cfg_status_left
        status_center    ::cfg_status_center
        status_right     ::cfg_status_right
        help_bar         ::cfg_help_bar
    } {
        if {[dict exists $d $key]} { set $var [dict get $d $key] }
    }
    foreach {key var} {
        dark_mode        ::cfg_dark_mode
        block_cursor_gui ::cfg_block_cursor_gui
        blink_cursor     ::cfg_blink_cursor
    } {
        if {[dict exists $d $key]} { set $var [string is true [dict get $d $key]] }
    }
    set ::cfg_profile $name
}

proc scheme-apply {name} {
    if {![dict exists $::cfg_schemes $name]} return
    set d [dict get $::cfg_schemes $name]
    foreach {key var} {
        color_bg          ::cfg_bg
        color_fg          ::cfg_fg
        color_bg_bar      ::cfg_bg_bar
        color_fg_bar      ::cfg_fg_bar
        color_bg_sel      ::cfg_bg_sel
        color_heading     ::cfg_color_heading
        color_comment     ::cfg_color_comment
        color_markup      ::cfg_color_markup
        color_bg_alt      ::cfg_bg_alt
        color_fg_alt      ::cfg_fg_alt
        color_bg_bar_alt  ::cfg_bg_bar_alt
        color_fg_bar_alt  ::cfg_fg_bar_alt
        color_bg_sel_alt  ::cfg_bg_sel_alt
        color_heading_alt ::cfg_color_heading_alt
        color_comment_alt ::cfg_color_comment_alt
        color_markup_alt  ::cfg_color_markup_alt
    } {
        if {[dict exists $d $key]} { set $var [dict get $d $key] }
    }
}

proc ini-load {} {
    if {![file exists $::INI_FILE]} { ini-save; return }
    set fh [open $::INI_FILE r]
    chan configure $fh -encoding utf-8
    set section     ""
    set cur_scheme  ""
    set cur_profile ""
    set toplevel    {editor behaviour keys}
    while {[gets $fh line] >= 0} {
        set line [string trim $line]
        if {$line eq "" || [string match "#*" $line]} continue
        # section header
        if {[regexp {^\[(\w+)\]$} $line -> hdr]} {
            if {$hdr eq "schemes"} {
                set section "schemes"
                set cur_scheme ""
                set cur_profile ""
            } elseif {$hdr eq "profiles"} {
                set section "profiles"
                set cur_profile ""
                set cur_scheme ""
            } elseif {$section eq "schemes" && $hdr ni $toplevel} {
                set cur_scheme $hdr
            } elseif {$section eq "profiles" && $hdr ni $toplevel} {
                set cur_profile $hdr
            } else {
                set section $hdr
                set cur_scheme ""
                set cur_profile ""
            }
            continue
        }
        if {[regexp {^(\w+)\s*=(.*)$} $line -> key val]} {
            set v [string trim $val]
            # inside a named scheme block - store in dict
            if {$cur_scheme ne ""} {
                dict set ::cfg_schemes $cur_scheme $key $v
                continue
            }
            # inside a named profile block - store in dict
            if {$cur_profile ne ""} {
                dict set ::cfg_profiles $cur_profile $key $v
                continue
            }
            switch [string trim $key] {
                scheme           { set ::cfg_scheme          $v }
                profile          { set ::cfg_profile         $v }
                margin_width          { set ::cfg_margin_width        $v }
                margin_height         { set ::cfg_margin_height       $v }
                split_shrink_margin   { set ::cfg_split_shrink_margin [string is true $v] }
                watch_file            { set ::cfg_watch_file          [string is true $v] }
                hemingway_mode        { set ::cfg_hemingway_mode      [string is true $v] }
                font_size        { set ::cfg_font_size      $v }
                font_family      { set ::cfg_font_family    $v }
                bar_font_family  { set ::cfg_bar_font_family $v }
                color_bg         { set ::cfg_bg             $v }
                color_fg         { set ::cfg_fg             $v }
                color_bg_bar     { set ::cfg_bg_bar         $v }
                color_fg_bar     { set ::cfg_fg_bar         $v }
                docs_dir         { set ::cfg_docs_dir       $v }
                console_margin_cols  { set ::cfg_console_margin_cols $v }
                console_margin_rows  { set ::cfg_console_margin_rows $v }
                margin_cols          { set ::cfg_console_margin_cols $v }
                margin_rows          { set ::cfg_console_margin_rows $v }
                color_bg_sel     { set ::cfg_bg_sel         $v }
                heading_marker      { set ::cfg_heading_marker    $v }
                markdown_headings  { set ::cfg_markdown_headings [string is true $v] }
                color_heading    { set ::cfg_color_heading   $v }
                dim_marker       { set ::cfg_comment_marker  [marker-val $v] }
                comment_marker   { set ::cfg_comment_marker  [marker-val $v] }
                bold_marker          { set ::cfg_bold_marker          [marker-val $v] }
                italic_marker        { set ::cfg_italic_marker        [marker-val $v] }
                underline_marker     { set ::cfg_underline_marker     [marker-val $v] }
                strikethrough_marker { set ::cfg_strikethrough_marker [marker-val $v] }
                color_dim            { set ::cfg_color_comment        $v }
                color_comment        { set ::cfg_color_comment        $v }
                color_markup         { set ::cfg_color_markup         $v }
                color_bg_alt         { set ::cfg_bg_alt            $v }
                color_fg_alt         { set ::cfg_fg_alt            $v }
                color_bg_bar_alt     { set ::cfg_bg_bar_alt        $v }
                color_fg_bar_alt     { set ::cfg_fg_bar_alt        $v }
                color_bg_sel_alt     { set ::cfg_bg_sel_alt        $v }
                color_heading_alt    { set ::cfg_color_heading_alt  $v }
                color_dim_alt        { set ::cfg_color_comment_alt  $v }
                color_comment_alt    { set ::cfg_color_comment_alt  $v }
                color_markup_alt     { set ::cfg_color_markup_alt   $v }
                word_goal            { set ::cfg_word_goal            $v }
                dark_mode            { set ::cfg_dark_mode [string is true $v] }
                key_dark_toggle      { set ::cfg_key_dark_toggle   $v }
                browser              { set ::cfg_browser              [string is true $v] }
                console_center_alert { set ::cfg_console_center_alert [string is true $v] }
                line_numbers     { set ::cfg_line_numbers   $v }
                cursor_restore   { set ::cfg_cursor_restore $v }
                block_cursor         { set ::cfg_block_cursor_gui     [string is true $v]
                                       set ::cfg_block_cursor_console [string is true $v] }
                block_cursor_gui     { set ::cfg_block_cursor_gui     [string is true $v] }
                block_cursor_console { set ::cfg_block_cursor_console [string is true $v] }
                blink_cursor         { set ::cfg_blink_cursor         [string is true $v] }
                line_spacing     { set ::cfg_line_spacing   $v }
                bar_height       { set ::cfg_bar_height     $v }
                lang             { set ::cfg_lang           $v }
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
                key_redo         { set ::cfg_key_redo         $v }
                key_typewriter   { set ::cfg_key_typewriter   $v }
                key_fullscreen   { set ::cfg_key_fullscreen   $v }
                key_split        { set ::cfg_key_split        $v }
                key_split_focus  { set ::cfg_key_split_focus  $v }
                key_timer        { set ::cfg_key_timer        $v }
                toc_key          { set ::cfg_key_toc          $v }
                ln_key           { set ::cfg_key_line_numbers $v }
                fullscreen_key   { set ::cfg_key_fullscreen   $v }
                timer_duration   { set ::cfg_timer_duration   $v }
                timer_sound      { set ::cfg_timer_sound      [string is true $v] }
                timer_alert      { set ::cfg_timer_alert      [string is true $v] }
                timer_type       { set ::cfg_timer_type       $v }
                chrono_show      { set ::cfg_chrono_show      [string is true $v] }
            }
        }
    }
    close $fh
    profile-apply $::cfg_profile
    scheme-apply $::cfg_scheme
}

proc ini-save {} {
    set fh [open $::INI_FILE w]
    chan configure $fh -encoding utf-8
    puts $fh "# WrithDeck - configuration"
    puts $fh "# https://github.com/luginf/writhdeck"
    puts $fh ""
    puts $fh "\[editor\]"
    puts $fh "profile        = $::cfg_profile"
    puts $fh "scheme         = $::cfg_scheme"
    puts $fh "# docs_dir = ~/Documents/writerdeck"
    puts $fh "# (main default document and conf folder: ~/Documents/writhdeck)"
    puts $fh "console_margin_cols = $::cfg_console_margin_cols"
    puts $fh "console_margin_rows = $::cfg_console_margin_rows"
    puts $fh ""
    puts $fh "heading_marker       = $::cfg_heading_marker"
    puts $fh "comment_marker       = $::cfg_comment_marker"
    puts $fh "bold_marker          = $::cfg_bold_marker"
    puts $fh "italic_marker        = $::cfg_italic_marker"
    puts $fh "underline_marker     = $::cfg_underline_marker"
    puts $fh "strikethrough_marker = $::cfg_strikethrough_marker"
    puts $fh ""
    puts $fh "\[behaviour\]"
    puts $fh "browser              = $::cfg_browser"
    puts $fh "watch_file           = $::cfg_watch_file"
    puts $fh "hemingway_mode       = $::cfg_hemingway_mode"
    puts $fh "markdown_headings    = $::cfg_markdown_headings"
    puts $fh "split_shrink_margin  = $::cfg_split_shrink_margin"
    puts $fh "console_center_alert = $::cfg_console_center_alert"
    puts $fh "line_numbers         = $::cfg_line_numbers"
    puts $fh "cursor_restore = $::cfg_cursor_restore"
    puts $fh "block_cursor_gui     = $::cfg_block_cursor_gui"
    puts $fh "block_cursor_console = $::cfg_block_cursor_console"
    puts $fh "blink_cursor         = $::cfg_blink_cursor"
    puts $fh "# lang: interface language - en or fr"
    puts $fh "lang           = $::cfg_lang"
    puts $fh "# help_bar: text shown in the shortcuts bar, empty to hide"
    puts $fh "help_bar       = $::cfg_help_bar"
    puts $fh "# word_goal: target word count shown in status bar with 'goal' token (0 = disabled)"
    puts $fh "word_goal      = $::cfg_word_goal"
    puts $fh "# status bar zones - tokens: filename dirty sel ln col words chars goal clock timer help_bar space"
    puts $fh "status_left    = $::cfg_status_left"
    puts $fh "status_center  = $::cfg_status_center"
    puts $fh "status_right   = $::cfg_status_right"
    puts $fh "dark_mode      = $::cfg_dark_mode"
    puts $fh "# timer and stopwatch"
    puts $fh "timer_duration = $::cfg_timer_duration"
    puts $fh "timer_sound    = $::cfg_timer_sound"
    puts $fh "timer_alert    = $::cfg_timer_alert"
    puts $fh "timer_type     = $::cfg_timer_type"
    puts $fh "chrono_show    = $::cfg_chrono_show"
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
    puts $fh "key_redo         = $::cfg_key_redo"
    puts $fh "key_typewriter   = $::cfg_key_typewriter"
    puts $fh "key_fullscreen   = $::cfg_key_fullscreen"
    puts $fh "key_split        = $::cfg_key_split"
    puts $fh "key_split_focus  = $::cfg_key_split_focus"
    puts $fh "key_timer        = $::cfg_key_timer"
    puts $fh "key_dark_toggle  = $::cfg_key_dark_toggle"
    puts $fh ""
    puts $fh "\[profiles\]"
    puts $fh {# Each [name] block defines a profile (display, behaviour and status bar settings).}
    puts $fh {# Select the active profile with:  profile = <name>  in [editor]}
    puts $fh ""

    # Add "roman" example profile if not already defined
    if {![dict exists $::cfg_profiles roman]} {
        puts $fh "\[roman\]"
        puts $fh "margin_width    = 180"
        puts $fh "margin_height   = 80"
        puts $fh "font_size       = 18"
        puts $fh "font_family     = Noto Serif"
        puts $fh "line_spacing    = 110"
        puts $fh "bar_height      = 20"
        puts $fh "word_goal       = 1000"
        puts $fh ""
    }

    # Write all profiles including "default" from the dictionary
    foreach pname [dict keys $::cfg_profiles] {
        puts $fh "\[$pname\]"
        set d [dict get $::cfg_profiles $pname]
        foreach key {margin_width margin_height
                     font_size font_family bar_font_family line_spacing bar_height
                     word_goal dark_mode lang block_cursor_gui blink_cursor line_numbers
                     status_left status_center status_right help_bar} {
            if {[dict exists $d $key]} {
                puts $fh "$key = [dict get $d $key]"
            }
        }
        puts $fh ""
    }

    # Also write defaults from global variables for backwards compatibility
    if {![dict exists $::cfg_profiles default]} {
        puts $fh "\[default\]"
        puts $fh "margin_width    = $::cfg_margin_width"
        puts $fh "margin_height   = $::cfg_margin_height"
        puts $fh "font_size       = $::cfg_font_size"
        puts $fh "font_family     = $::cfg_font_family"
        puts $fh "bar_font_family = $::cfg_bar_font_family"
        puts $fh "line_spacing    = $::cfg_line_spacing"
        puts $fh "bar_height      = $::cfg_bar_height"
        puts $fh "word_goal       = $::cfg_word_goal"
        puts $fh ""
    }
    puts $fh ""
    puts $fh "\[schemes\]"
    puts $fh {# Each [name] block defines a color scheme.}
    puts $fh {# Select the active scheme with:  scheme = <name>  in [editor]}
    puts $fh "# colors in #rrggbb format"
    puts $fh ""
    puts $fh "\[default\]"
    puts $fh "# dark mode"
    puts $fh "color_bg       = $::cfg_bg"
    puts $fh "color_fg       = $::cfg_fg"
    puts $fh "color_bg_bar   = $::cfg_bg_bar"
    puts $fh "color_fg_bar   = $::cfg_fg_bar"
    puts $fh "color_bg_sel   = $::cfg_bg_sel"
    puts $fh "color_heading  = $::cfg_color_heading"
    puts $fh "color_comment  = $::cfg_color_comment"
    puts $fh "color_markup   = $::cfg_color_markup"
    puts $fh "# light mode"
    puts $fh "color_bg_alt      = $::cfg_bg_alt"
    puts $fh "color_fg_alt      = $::cfg_fg_alt"
    puts $fh "color_bg_bar_alt  = $::cfg_bg_bar_alt"
    puts $fh "color_fg_bar_alt  = $::cfg_fg_bar_alt"
    puts $fh "color_bg_sel_alt  = $::cfg_bg_sel_alt"
    puts $fh "color_heading_alt = $::cfg_color_heading_alt"
    puts $fh "color_comment_alt = $::cfg_color_comment_alt"
    puts $fh "color_markup_alt  = $::cfg_color_markup_alt"
    # write any extra schemes stored in memory (user-defined)
    foreach sname [dict keys $::cfg_schemes] {
        if {$sname eq "default"} continue
        puts $fh ""
        puts $fh "\[$sname\]"
        set d [dict get $::cfg_schemes $sname]
        foreach key {color_bg color_fg color_bg_bar color_fg_bar color_bg_sel
                     color_heading color_comment color_markup
                     color_bg_alt color_fg_alt color_bg_bar_alt color_fg_bar_alt
                     color_bg_sel_alt color_heading_alt color_comment_alt color_markup_alt} {
            if {[dict exists $d $key]} {
                puts $fh "$key = [dict get $d $key]"
            }
        }
    }
    close $fh
}

proc schemes-init {} {
    foreach scheme_name [dict keys $::scheme_defs] {
        set scheme_data [dict get $::scheme_defs $scheme_name]
        dict set ::cfg_schemes $scheme_name $scheme_data
    }
}

# Map Tk key name -> string returned by tui-getch
proc tk-key-to-tui {key} {
    set k [string tolower $key]
    if {[regexp {^control-([a-z])$} $k -> letter]} {
        scan $letter %c code
        return [format %c [expr {$code - 96}]]
    }
    if {$k eq "control-space"} { return "\x00" }
    if {[regexp {^f(\d+)$} $k -> n]} { return "F$n" }
    return $key
}

# Return a short human-readable label for a Tk key name
proc key-label {key} {
    if {[regexp -nocase {^control-([a-z])$} $key -> l]} { return "^[string toupper $l]" }
    if {[string tolower $key] eq "control-space"}        { return "^SPC" }
    if {[string tolower $key] eq "control-shift-space"}  { return "^+SPC" }
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
    set ::cfg_tui_redo         [tk-key-to-tui $::cfg_key_redo]
    set ::cfg_tui_typewriter   [tk-key-to-tui $::cfg_key_typewriter]
    set ::cfg_tui_dark_toggle  [tk-key-to-tui $::cfg_key_dark_toggle]
    set ::cfg_tui_split        [tk-key-to-tui $::cfg_key_split]
    set ::cfg_tui_timer        [tk-key-to-tui $::cfg_key_timer]
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
    set ::cfg_lbl_redo       [key-label $::cfg_key_redo]
    set ::cfg_lbl_typewriter [key-label $::cfg_key_typewriter]
    set ::cfg_lbl_split      [key-label $::cfg_key_split]
    set ::cfg_lbl_split_focus [key-label $::cfg_key_split_focus]
    # conflict detection
    set pairs [list \
        key_save $::cfg_tui_save \
        key_close $::cfg_tui_close  key_find $::cfg_tui_find \
        key_replace $::cfg_tui_replace  key_help $::cfg_tui_help \
        key_goto $::cfg_tui_goto  key_open $::cfg_tui_open \
        key_undo $::cfg_tui_undo  key_copy $::cfg_tui_copy \
        key_cut $::cfg_tui_cut  key_paste $::cfg_tui_paste \
        key_select_all $::cfg_tui_select_all  key_sticky_sel $::cfg_tui_sticky_sel \
        key_toc $::cfg_tui_toc  key_line_numbers $::cfg_tui_line_nums \
        key_redo $::cfg_tui_redo  key_typewriter $::cfg_tui_typewriter]
    set seen [dict create]; set conflicts {}
    foreach {name val} $pairs {
        if {[dict exists $seen $val]} {
            lappend conflicts "$name=[dict get $seen $val]"
        } else { dict set seen $val $name }
    }
    set ::cfg_key_error [join $conflicts "  "]
}
keys-init

# --- i18n --------------------------------------------------------------------
set ::i18n [dict create]
proc t {key args} {
    set lang [expr {[dict exists $::i18n $::cfg_lang] ? $::cfg_lang : "en"}]
    set s [dict get $::i18n $lang $key]
    if {[llength $args]} { return [format $s {*}$args] }
    return $s
}

# --- theme helpers ------------------------------------------------------------
proc theme-colors {} {
    if {$::cfg_dark_mode} {
        return [list $::cfg_bg $::cfg_fg $::cfg_bg_bar $::cfg_fg_bar \
                     $::cfg_bg_sel $::cfg_color_heading $::cfg_color_comment $::cfg_color_markup]
    } else {
        return [list $::cfg_bg_alt $::cfg_fg_alt $::cfg_bg_bar_alt $::cfg_fg_bar_alt \
                     $::cfg_bg_sel_alt $::cfg_color_heading_alt $::cfg_color_comment_alt $::cfg_color_markup_alt]
    }
}

proc toggle-dark-mode {} {
    set ::cfg_dark_mode [expr {!$::cfg_dark_mode}]
    if {!$::no_gui} { apply-theme }
}

# --- config -------------------------------------------------------------------
# validate font family (font families is a Tk command - skip in TUI)
if {!$::no_gui && $::cfg_font_family ne "Mono"} {
    if {[lsearch -exact [font families] $::cfg_font_family] < 0} {
        puts stderr "writhdeck: font family '$::cfg_font_family' not found, using Mono"
        set ::cfg_font_family "Mono"
    }
}
if {!$::no_gui && $::cfg_bar_font_family ne "Mono"} {
    if {[lsearch -exact [font families] $::cfg_bar_font_family] < 0} {
        puts stderr "writhdeck: bar font family '$::cfg_bar_font_family' not found, using Mono"
        set ::cfg_bar_font_family "Mono"
    }
}
set ::typewriter_mode 0


# ===========================================================================
# schemes (default alt01)
# ===========================================================================
# Default color scheme - dark and light variants

dict set ::scheme_defs default {
    color_bg       "#1a1a1a"
    color_fg       "#e8e8e8"
    color_bg_bar   "#2a2a2a"
    color_fg_bar   "#aaaaaa"
    color_bg_sel   "#3a5a8a"
    color_heading  "#c8a060"
    color_comment  "#606060"
    color_markup   "#6aa9d4"
    color_bg_alt   "#fdf6e3"
    color_fg_alt   "#657b83"
    color_bg_bar_alt "#eee8d5"
    color_fg_bar_alt "#93a1a1"
    color_bg_sel_alt "#e6ddb9"
    color_heading_alt "#b58900"
    color_comment_alt "#aaaaaa"
    color_markup_alt "#2a7090"
}
# Alt01 - Warm, muted color scheme

dict set ::scheme_defs alt01 {
    color_bg       "#2a2520"
    color_fg       "#d4c4b0"
    color_bg_bar   "#3d3531"
    color_fg_bar   "#c4b4a0"
    color_bg_sel   "#4a4035"
    color_heading  "#e8a87c"
    color_comment  "#6a5a50"
    color_markup   "#c49070"
    color_bg_alt   "#f5f0eb"
    color_fg_alt   "#3a2a20"
    color_bg_bar_alt "#e8e0d8"
    color_fg_bar_alt "#3a2a20"
    color_bg_sel_alt "#e0d4c8"
    color_heading_alt "#a65d2b"
    color_comment_alt "#a89080"
    color_markup_alt "#8b5a3c"
}

# ===========================================================================
# i18n (en fr)
# ===========================================================================
dict set ::i18n en {
    toc_title          "Table of contents"
    toc_no_headings    "no headings found"
    toc_jump_bar       "Enter jump  esc/ctrl+q cancel"
    toc_headings       "%d heading%s"
    br_no_docs         "No documents yet. Press n to create one."
    br_help_gui        "h:help  n:new  t:scratchpad  f:fav  s:stats  b:backup  d:delete  r:rename  i:info  c:config  z:reload  %s:sections  q:quit"
    br_help_tui        "h:%s  n:new  t:scratchpad  f:fav  s:stats  b:backup  d:delete  r:rename  i:info  c:config  w:words  %s:sections  q:quit"
    br_backed_up       "backup %s -> %s"
    br_favorites       "Favorites"
    br_stats_title     "Writing stats"
    br_stats_no_data   "No writing stats yet for this file."
    br_stats_today     "Today"
    br_stats_total     "Total"
    br_stats_clear     "Clear stats"
    br_stats_clear_confirm "Clear all writing stats for \"%s\"?"
    br_fav_added       "[+] added to favorites: %s"
    br_fav_removed     "[-] removed from favorites: %s"
    br_exists          "'%s' already exists"
    br_deleted         "deleted '%s'"
    br_renamed         "renamed -> '%s'"
    br_delete          "Delete \"%s\"?"
    br_files           "%d file%s"
    br_recent          "Recents"
    ed_saved           "saved"
    ed_watch_reload       "\"%s\" was modified externally. Reload?"
    ed_watch_reload_dirty "\"%s\" was modified externally and you have unsaved changes. Reload?"
    ed_save_before     "Save \"%s\" before closing?"
    ed_save_before_tui "save before closing? (y/n/c=cancel)"
    help_date_time     "Date & Time"
    help_cur_time      "Current time:  %-12s  Date: %s"
    help_file_info     "File info"
    help_sel_info      "Selection info"
    help_words_chars   "Words: %-8d  Chars: %d"
    help_shortcuts     "Writhdeck - keyboard shortcuts"
    help_close         "Press any key to close"
    help_k_save        "Save"
    help_k_undo        "Undo"
    help_k_redo        "Redo"
    help_k_close       "Close / Esc"
    help_k_sel_all     "Select all"
    help_k_sticky      "Toggle selection"
    help_k_copy        "Copy"
    help_k_find        "Find"
    help_k_cut         "Cut"
    help_k_replace     "Replace"
    help_k_paste       "Paste"
    help_k_goto        "Go to line"
    help_k_lnum        "Line numbers"
    help_k_open        "Open (browser)"
    help_k_typewriter  "Typewriter / focus mode (toggle)"
    help_k_ctrl_arrows "Ctrl+Up/Dn  Paragraph  |  Ctrl+Lt/Rt / Alt+BF  Word"
    help_k_toc         "Table of contents"
    help_k_help        "This help"
    help_shift_arrows  "Shift+Arrows  Extend selection"
    help_k_split       "Split view (toggle)"
    help_k_split_focus "Split view - cycle focus"
    br_toc_title       "Browser sections"
    br_toc_empty       "no sections"
    br_toc_bar         "Up/Dn nav  Enter jump  esc cancel"
    dlg_yes            "Yes"
    dlg_no             "No"
    dlg_cancel         "Cancel"
    goto_title         "Go to line"
    goto_prompt        "Line:"
    profile_config_title   "Configuration"
    profile_config_default_profile "Default profile:"
    profile_config_default_scheme  "Default color scheme:"
    profile_config_language        "Language:"
    profile_config_edit_profile "Edit profile:"
    profile_config_font    "Font family:"
    profile_config_size    "Font size:"
    profile_config_margin_w "Margin width:"
    profile_config_margin_h "Margin height:"
    profile_config_word_goal "Daily word goal:"
    profile_config_dark_mode "Dark mode:"
    profile_config_apply   "Apply"
    profile_config_cancel  "Cancel"
    br_key_help            "help"
    br_key_new             "new"
    br_key_scratchpad      "scratchpad"
    br_key_fav             "fav"
    br_key_stats           "stats"
    br_key_backup          "backup"
    br_key_delete          "delete"
    br_key_rename          "rename"
    br_key_info            "info"
    br_key_words           "words"
    br_key_config          "config"
    br_key_reload          "reload"
    br_key_quit            "quit"
    br_help_new_file       "New file"
    br_help_scratchpad     "Scratchpad (temp, no disk file)"
    br_help_toggle_fav     "Toggle favorite"
    br_help_writing_stats  "Writing stats"
    br_help_backup         "Backup (copies to backups/ with timestamp)"
    br_help_show_path      "Show full path"
    br_help_word_occ       "Word occurrences"
    br_help_delete_file    "Delete"
    br_help_rename_file    "Rename"
    br_help_font_settings  "Font settings by profile"
    br_help_reload         "Reload"
    br_help_browser_sections "Browser sections"
    br_help_fullscreen_br  "Fullscreen"
    br_help_open_file_br   "Open file"
    br_help_help           "Help"
    br_help_quit_app       "Quit"
    br_key_sections        "sections"
    help_writhdeck         "WRITHDECK"
    help_version           "Version"
    help_date_time_sect    "DATE & TIME"
    help_current_time      "Current time"
    help_date              "Date"
    help_editor_sect       "EDITOR"
    help_save_as           "Save as"
    help_return_browser    "Return to browser"
    help_find_next         "Find (Enter: next  Shift+Enter: prev)"
    help_find_replace      "Find & Replace (Enter: replace one  Ctrl+Enter: all)"
    help_para_word         "Paragraph / word navigation"
    help_toc_marker        "Table of contents  (%s)"
    help_browser_sect      "BROWSER"
    help_open              "Open"
    help_double_click      "Enter / double-click"
    help_key_open_text     "Open"
    help_k_fullscreen      "Fullscreen"
    config_tab_profile     "Profile"
    config_tab_timer       "Timer"
    timer_section          "Settings"
    timer_duration         "Duration (min):"
    timer_sound            "Sound at end:"
    timer_alert            "Alert message:"
    timer_type             "Type:"
    timer_type_countdown   "countdown"
    timer_type_stopwatch   "stopwatch"
    chrono_show            "Show in status bar:"
}

dict set ::i18n fr {
    toc_title          "Table des matières"
    toc_no_headings    "aucun titre trouvé"
    toc_jump_bar       "Enter aller  esc/ctrl+q annuler"
    toc_headings       "%d titre%s"
    br_no_docs         "Aucun document. Appuyez sur n pour en créer un."
    br_help_gui        "h:aide  n:nouveau  t:bloc-notes  f:fav  s:stats  b:backup  d:supprimer  r:renommer  i:infos  c:config  z:recharger  %s:sections  q:quitter"
    br_help_tui        "h:%s  n:nouveau  t:bloc-notes  f:fav  s:stats  b:backup  d:supprimer  r:renommer  i:infos  c:config  w:mots  %s:sections  q:quitter"
    br_backed_up       "sauvegarde %s -> %s"
    br_favorites       "Favoris"
    br_stats_title     "Statistiques d'écriture"
    br_stats_no_data   "Aucune statistique d'écriture pour ce fichier."
    br_stats_today     "Aujourd'hui"
    br_stats_total     "Total"
    br_stats_clear     "Effacer les stats"
    br_stats_clear_confirm "Effacer toutes les statistiques de \"%s\" ?"
    br_fav_added       "[+] ajouté aux favoris : %s"
    br_fav_removed     "[-] retiré des favoris : %s"
    br_exists          "'%s' existe déjà"
    br_deleted         "'%s' supprimé"
    br_renamed         "renommé -> '%s'"
    br_delete          "Supprimer \"%s\" ?"
    br_files           "%d fichier%s"
    br_recent          "Récents"
    ed_saved           "enregistré"
    ed_watch_reload       "\"%s\" a été modifié externement. Recharger ?"
    ed_watch_reload_dirty "\"%s\" a été modifié externement et vous avez des modifications non sauvegardées. Recharger ?"
    ed_save_before     "Enregistrer \"%s\" avant de fermer ?"
    ed_save_before_tui "enregistrer avant de fermer ? (o/n/c=annuler)"
    help_date_time     "Date & Heure"
    help_cur_time      "Heure actuelle: %-12s  Date : %s"
    help_file_info     "Infos fichier"
    help_sel_info      "Infos sélection"
    help_words_chars   "Mots : %-8d  Caract. : %d"
    help_shortcuts     "Writhdeck - raccourcis clavier"
    help_close         "Appuyer sur une touche pour fermer"
    help_k_save        "Enregistrer"
    help_k_undo        "Annuler"
    help_k_redo        "Rétablir"
    help_k_close       "Fermer / Esc"
    help_k_sel_all     "Tout sélectionner"
    help_k_sticky      "Activer sélection"
    help_k_copy        "Copier"
    help_k_find        "Chercher"
    help_k_cut         "Couper"
    help_k_replace     "Remplacer"
    help_k_paste       "Coller"
    help_k_goto        "Aller à la ligne"
    help_k_lnum        "Numéros de lignes"
    help_k_open        "Ouvrir (explorateur)"
    help_k_typewriter  "Mode machine à écrire / focus (bascule)"
    help_k_ctrl_arrows "Ctrl+Up/Dn  Paragraphe  |  Ctrl+Lt/Rt / Alt+BF  Mot"
    help_k_toc         "Table des matières"
    help_k_help        "Cette aide"
    help_shift_arrows  "Maj+Flèches   Étendre la sélection"
    help_k_split       "Vue partagée (bascule)"
    help_k_split_focus "Vue partagée - changer de fenêtre"
    br_toc_title       "Sections du navigateur"
    br_toc_empty       "aucune section"
    br_toc_bar         "Up/Dn nav  Enter aller  esc annuler"
    dlg_yes            "Oui"
    dlg_no             "Non"
    dlg_cancel         "Annuler"
    goto_title         "Aller à la ligne"
    goto_prompt        "Ligne :"
    profile_config_title   "Configuration"
    profile_config_default_profile "Profil par défaut :"
    profile_config_default_scheme  "Schéma de couleurs par défaut :"
    profile_config_language        "Langue :"
    profile_config_edit_profile "Éditer le profil :"
    profile_config_font    "Police :"
    profile_config_size    "Taille :"
    profile_config_margin_w "Largeur marge :"
    profile_config_margin_h "Hauteur marge :"
    profile_config_word_goal "Objectif quotidien :"
    profile_config_dark_mode "Mode sombre :"
    profile_config_apply   "Appliquer"
    profile_config_cancel  "Annuler"
    br_key_help            "aide"
    br_key_new             "nouveau"
    br_key_scratchpad      "bloc-notes"
    br_key_fav             "fav"
    br_key_stats           "stats"
    br_key_backup          "backup"
    br_key_delete          "supprimer"
    br_key_rename          "renommer"
    br_key_info            "infos"
    br_key_words           "mots"
    br_key_config          "config"
    br_key_reload          "recharger"
    br_key_quit            "quitter"
    br_help_new_file       "Nouveau fichier"
    br_help_scratchpad     "Bloc-notes (temp, pas de fichier)"
    br_help_toggle_fav     "Basculer en favoris"
    br_help_writing_stats  "Statistiques d'écriture"
    br_help_backup         "Sauvegarde (copie dans backups/ avec timestamp)"
    br_help_show_path      "Afficher le chemin complet"
    br_help_word_occ       "Occurrences de mots"
    br_help_delete_file    "Supprimer"
    br_help_rename_file    "Renommer"
    br_help_font_settings  "Paramètres de police par profil"
    br_help_reload         "Recharger"
    br_help_browser_sections "Sections du navigateur"
    br_help_fullscreen_br  "Plein écran"
    br_help_open_file_br   "Ouvrir un fichier"
    br_help_help           "Aide"
    br_help_quit_app       "Quitter"
    br_key_sections        "sections"
    help_writhdeck         "WRITHDECK"
    help_version           "Version"
    help_date_time_sect    "DATE & HEURE"
    help_current_time      "Heure actuelle"
    help_date              "Date"
    help_editor_sect       "ÉDITEUR"
    help_save_as           "Enregistrer sous"
    help_return_browser    "Retour au navigateur"
    help_find_next         "Chercher (Entrée : suivant  Maj+Entrée : précédent)"
    help_find_replace      "Chercher et remplacer (Entrée : remplacer un  Ctrl+Entrée : tout)"
    help_para_word         "Navigation par paragraphe / mot"
    help_toc_marker        "Table des matières  (%s)"
    help_browser_sect      "NAVIGATEUR"
    help_open              "Ouvrir"
    help_double_click      "Entrée / double-clic"
    help_key_open_text     "Ouvrir"
    help_k_fullscreen      "Plein écran"
    config_tab_profile     "Profil"
    config_tab_timer       "Minuterie"
    timer_section          "Parametres"
    timer_duration         "Duree (min) :"
    timer_sound            "Son a la fin :"
    timer_alert            "Message d'alerte :"
    timer_type             "Type :"
    timer_type_countdown   "compte a rebours"
    timer_type_stopwatch   "chronometre"
    chrono_show            "Afficher dans la barre :"
}


# ===========================================================================
# common.tcl
# ===========================================================================
# --- initialization (run after schemes and i18n are loaded) -----------
schemes-init
ini-load

# Apply docs_dir from config (must be after ini-load)
if {$::cfg_docs_dir ne ""} {
    set ::DOCS_DIR [file normalize [tilde-expand $::cfg_docs_dir]]
    if {$::DOCS_DIR eq $::DOCS_DIR_DEFAULT} { set ::DOCS_DIR $::DOCS_DIR_DEFAULT }
    file mkdir $::DOCS_DIR
}

# Initialize fonts and theme colors (must be after ini-load to use selected scheme/profile)
set font    [list $::cfg_font_family $::cfg_font_size]
set bar_pady [expr {$::cfg_bar_height > 0 \
    ? min(2, max(0, ($::cfg_bar_height - 6) / 2)) : 0}]
set font_sm  [expr {$::cfg_bar_height > 0 \
    ? [list $::cfg_bar_font_family [expr {-max(6, $::cfg_bar_height - 2*$bar_pady)}]] \
    : [list $::cfg_bar_font_family 10]}]
set ::font_sm $font_sm
lassign [theme-colors] bg fg bg_bar fg_bar bg_sel
set fg_dim  "#676767"
# expose as globals for use in procs
set ::bg     $bg
set ::fg     $fg
set ::bg_bar $bg_bar
set ::fg_bar $fg_bar
set ::bg_sel $bg_sel

# --- utils --------------------------------------------------------------------
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
        return [list $::DOCS_DIR $::DOCS_DIR_DEFAULT]
    }
    return [list $::DOCS_DIR_DEFAULT]
}

set ::cached_heading_re       ""
set ::cached_comment_re       ""
set ::cached_bold_re          ""
set ::cached_italic_re        ""
set ::cached_underline_re     ""
set ::cached_strikethrough_re ""
set ::cached_bold_mlen          0
set ::cached_italic_mlen        0
set ::cached_underline_mlen     0
set ::cached_strikethrough_mlen 0
set ::hl_line_cache {}
set ::hl_last_count 0

proc heading-re {} {
    set m [regsub -all {[\\^$.|?*+()\[\]{}]} $::cfg_heading_marker {\\&}]
    return "^\\s*${m}\\s*(.+?)\\s*${m}\\s*$"
}

proc parse-comment {line} {
    if {$::cached_comment_re eq ""} { return 0 }
    return [regexp -- $::cached_comment_re $line]
}

proc inline-re {marker} {
    if {$marker eq ""} { return "" }
    set m [regsub -all {[\\^$.|?*+()\[\]{}]} $marker {\\&}]
    return "${m}.+?${m}"
}

proc apply-inline {ln line tag re mlen {content_only 0}} {
    set s 0
    set llen [string length $line]
    while {[regexp -start $s -indices -- $re $line m]} {
        lassign $m a b
        set pre  [expr {$a > 0       ? [string index $line [expr {$a-1}]] : ""}]
        set post [expr {$b+1 < $llen ? [string index $line [expr {$b+1}]] : ""}]
        if {($pre  eq "" || ![string is alnum $pre]) &&
            ($post eq "" || ![string is alnum $post]) &&
            ![string is space [string index $line [expr {$a + $mlen}]]] &&
            ![string is space [string index $line [expr {$b - $mlen}]]]} {
            if {$content_only} {
                .ed.t tag add $tag "$ln.[expr {$a+$mlen}]" "$ln.[expr {$b-$mlen+1}]"
            } else {
                .ed.t tag add $tag $ln.$a "$ln.[expr {$b+1}]"
            }
            .ed.t tag add marker $ln.$a "$ln.[expr {$a+$mlen}]"
            .ed.t tag add marker "$ln.[expr {$b-$mlen+1}]" "$ln.[expr {$b+1}]"
        }
        set s [expr {$b+1}]
    }
}

proc parse-heading {line} {
    if {[regexp $::cached_heading_re $line -> title]} { return [string trim $title] }
    if {$::cfg_markdown_headings && \
            [regexp {^\s*(#{1,6})\s+(.+)$} $line -> _ title]} { return [string trim $title] }
    return ""
}

proc heading-level {line} {
    set m    [regsub -all {[\\^$.|?*+()\[\]{}]} $::cfg_heading_marker {\\&}]
    set mlen [string length $::cfg_heading_marker]
    if {$mlen > 0} {
        set re "^\\s*((?:${m})+)\\s*(.+?)\\s*(?:${m})+\\s*\$"
        if {[regexp $re $line -> markers title]} {
            return [list [string trim $title] [expr {[string length $markers] / $mlen}]]
        }
    }
    if {$::cfg_markdown_headings && \
            [regexp {^\s*(#{1,6})\s+(.+)$} $line -> hashes title]} {
        return [list [string trim $title] [string length $hashes]]
    }
    return ""
}

proc markers-update {} {
    set ::cached_heading_re [heading-re]
    if {$::cfg_comment_marker ne ""} {
        set m [regsub -all {[\\^$.|?*+()\[\]{}]} $::cfg_comment_marker {\\&}]
        set ::cached_comment_re "^${m}"
    } else {
        set ::cached_comment_re ""
    }
    set ::cached_bold_re          [inline-re $::cfg_bold_marker]
    set ::cached_italic_re        [inline-re $::cfg_italic_marker]
    set ::cached_underline_re     [inline-re $::cfg_underline_marker]
    set ::cached_strikethrough_re [inline-re $::cfg_strikethrough_marker]
    set ::cached_bold_mlen          [string length $::cfg_bold_marker]
    set ::cached_italic_mlen        [string length $::cfg_italic_marker]
    set ::cached_underline_mlen     [string length $::cfg_underline_marker]
    set ::cached_strikethrough_mlen [string length $::cfg_strikethrough_marker]
    set ::hl_line_cache {}
    set ::hl_last_count 0
}

proc fmt-meta {path} {
    set sz [file size $path]
    set sz_str [expr {$sz < 1024 ? "${sz}B" : "[expr {$sz/1024}]K"}]
    set mt [clock format [file mtime $path] -format "%d %b %H:%M"]
    return "$sz_str\t$mt"
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
    set timer [dict get $state timer]
    set result ""
    foreach tok $tokens {
        switch -- $tok {
            filename { append result $fn }
            dirty    { if {$dirty}      { append result " \[+\]" } }
            sel      { if {$sel}        { append result " \[sel\]" } }
            ln       { append result [format "  Ln %d/%d" $ln $total] }
            col      { append result [format "  Col %-3d" $col] }
            words    { append result "  ${words}w" }
            chars    { append result "  ${chars}c" }
            goal     { if {$::cfg_word_goal > 0} { append result [format "  %d/%d" [daily-today $words] $::cfg_word_goal] } }
            clock    { append result "  $clk" }
            timer    { if {$::cfg_chrono_show} {
                set _m [expr {$timer / 60}]
                set _s [expr {$timer % 60}]
                if {$::timer_active} {
                    append result [format " \[%d'%02d\"]" $_m $_s]
                } else {
                    append result [format "  %d'%02d\"" $_m $_s]
                }
            } }
            space    { append result " " }
            help_bar {}
        }
    }
    return $result
}

markers-update

proc build-extra-entries {shown} {
    if {!$::state_cache_valid} { state-load }
    set result {}
    set vfav {}
    foreach p $::favorites_list { if {[file isfile $p]} { lappend vfav $p } }
    if {[llength $vfav]} {
        lappend result [list header "" [t br_favorites]]
        foreach p $vfav { lappend result [list favorite [file dirname $p] [file tail $p]] }
    }
    set vrec {}
    foreach p $::recent_list { if {[file isfile $p]} { lappend vrec $p } }
    if {[llength $vrec]} {
        lappend result [list header "" [t br_recent]]
        foreach p $vrec { lappend result [list recent [file dirname $p] [file tail $p]] }
    }
    return $result
}

proc do-backup {dir name} {
    set bdir [file join $::DOCS_DIR backups]
    file mkdir $bdir
    set ts  [clock format [clock seconds] -format "%Y-%m-%dT%Hh%M"]
    set dst [file join $bdir "[file rootname $name]_${ts}[file extension $name]"]
    set src [file join $dir $name]
    if {[file type $src] eq "link"} { set src [file normalize $src] }
    file copy -force $src $dst
    return $dst
}

proc toggle-favorite {path} {
    set path [file normalize $path]
    if {!$::state_cache_valid} { state-load }
    set idx [lsearch -exact $::favorites_list $path]
    if {$idx >= 0} {
        set ::favorites_list [lreplace $::favorites_list $idx $idx]
    } else {
        lappend ::favorites_list $path
    }
    state-save
}

proc _cmp_word_count {counts a b} {
    set cmp [expr {[dict get $counts $b] - [dict get $counts $a]}]
    if {$cmp != 0} {return $cmp}
    return [string compare $a $b]
}

proc get-word-occurrences {fpath} {
    set counts [dict create]
    if {[catch {
        set fh [open $fpath r]
        set content [read $fh]
        close $fh
        foreach word [regexp -all -inline {\w+} [string tolower $content]] {
            if {[string length $word] > 2} {
                dict incr counts $word
            }
        }
    }]} {
        return [list]
    }
    set result {}
    foreach word [lsort -command [list _cmp_word_count $counts] [dict keys $counts]] {
        lappend result [list $word [dict get $counts $word]]
    }
    return $result
}


# ===========================================================================
# tui.tcl
# ===========================================================================

# --- TUI mode -----------------------------------------------------------------

set ::tui_stty ""

proc tui-reverse-video {on} {
    puts -nonewline [expr {$on ? "\033\[?5h" : "\033\[?5l"}]
    flush stdout
}

proc tui-init {} {
    catch { set ::tui_stty [exec stty -g <@stdin] }
    catch { exec stty raw -echo <@stdin }
    chan configure stdin  -blocking 1 -translation binary -buffering none
    chan configure stdout -encoding utf-8 -buffering full
    puts -nonewline "\033\[?25l\033\[2J\033\[?2004h"
    set _cq [expr {$::cfg_block_cursor_console \
        ? ($::cfg_blink_cursor ? 1 : 2) \
        : ($::cfg_blink_cursor ? 5 : 6)}]
    puts -nonewline "\033\[${_cq} q"
    unset _cq
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
        bold     { puts -nonewline "\033\[1m" }
        heading  { puts -nonewline "\033\[1m" }
        dim-text { puts -nonewline "\033\[2m" }
        dim      { puts -nonewline "\033\[2m" }
        underline { puts -nonewline "\033\[4m" }
        reverse  { puts -nonewline "\033\[7m" }
        off      { puts -nonewline "\033\[0m" }
    }
}

proc tui-parse-inline-spans {line} {
    set spans {}
    set llen [string length $line]
    foreach {tag re mlen marker} [list \
            bold          $::cached_bold_re          $::cached_bold_mlen          $::cfg_bold_marker \
            italic        $::cached_italic_re        $::cached_italic_mlen        $::cfg_italic_marker \
            underline     $::cached_underline_re     $::cached_underline_mlen     $::cfg_underline_marker \
            strikethrough $::cached_strikethrough_re $::cached_strikethrough_mlen $::cfg_strikethrough_marker] {
        if {$re eq "" || [string first $marker $line] < 0} continue
        set s 0
        while {[regexp -start $s -indices -- $re $line m]} {
            lassign $m a b
            set pre  [expr {$a > 0       ? [string index $line [expr {$a-1}]] : ""}]
            set post [expr {$b+1 < $llen ? [string index $line [expr {$b+1}]] : ""}]
            if {($pre eq "" || ![string is alnum $pre]) &&
                ($post eq "" || ![string is alnum $post]) &&
                ![string is space [string index $line [expr {$a+$mlen}]]] &&
                ![string is space [string index $line [expr {$b-$mlen}]]]} {
                lappend spans [list $a          [expr {$a+$mlen-1}]  marker]
                lappend spans [list [expr {$a+$mlen}] [expr {$b-$mlen}] $tag]
                lappend spans [list [expr {$b-$mlen+1}] $b            marker]
            }
            set s [expr {$b+1}]
        }
    }
    return $spans
}

proc tui-inline-esc {style in_sel} {
    set codes {}
    switch $style {
        bold          { lappend codes 1 }
        italic        { lappend codes 3 }
        underline     { lappend codes 4 }
        strikethrough -
        marker        { lappend codes 2 }
    }
    if {$in_sel} { lappend codes 7 }
    if {$codes eq {}} { return [expr {$in_sel ? "\033\[7m" : ""}] }
    return "\033\[[join $codes {;}]m"
}

proc tui-render-inline-seg {seg scol spans sf st} {
    set slen [string length $seg]
    set char_style [lrepeat $slen ""]
    foreach sp $spans {
        lassign $sp sa sb stype
        for {set k [expr {max(0, $sa-$scol)}]} {$k <= [expr {min($slen-1, $sb-$scol)}]} {incr k} {
            if {[lindex $char_style $k] eq ""} { lset char_style $k $stype }
        }
    }
    set result ""
    set prev_esc ""
    for {set k 0} {$k < $slen} {incr k} {
        set in_sel [expr {$sf >= 0 && $k >= $sf && $k < $st}]
        set esc [tui-inline-esc [lindex $char_style $k] $in_sel]
        if {$esc ne $prev_esc} {
            if {$prev_esc ne ""} { append result "\033\[0m" }
            if {$esc ne ""} { append result $esc }
            set prev_esc $esc
        }
        append result [string index $seg $k]
    }
    if {$prev_esc ne ""} { append result "\033\[0m" }
    puts -nonewline $result
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

proc tui-help-dialog {rows cols wc cc {sel_wc -1} {sel_cc -1}} {
    set lbl_save   $::cfg_lbl_save;   set lbl_close  $::cfg_lbl_close
    set lbl_undo   $::cfg_lbl_undo;   set lbl_selall $::cfg_lbl_sel_all
    set lbl_sticky $::cfg_lbl_sticky; set lbl_copy   $::cfg_lbl_copy
    set lbl_find   $::cfg_lbl_find;   set lbl_cut    [key-label $::cfg_key_cut]
    set lbl_repl   $::cfg_lbl_replace; set lbl_paste $::cfg_lbl_paste
    set lbl_goto   $::cfg_lbl_goto;   set lbl_lnum   $::cfg_lbl_line_nums
    set lbl_open   $::cfg_lbl_open;   set lbl_toc    $::cfg_lbl_toc
    set lbl_help   $::cfg_lbl_help
    set lbl_redo   $::cfg_lbl_redo;   set lbl_tw     $::cfg_lbl_typewriter
    set _ts [clock seconds]
    set _e ""
    # two-column line: key(10) + action(19) | key(10) + action
    set f2 "  %-10s %-19s%-10s %s"
    # Each entry: {text inv} - inv=1 renders in reverse video
    set lines [list \
        [list "  WrithDeck" 1] \
        [list "  $::version" 0] \
        [list "" 0] \
        [list "  [t help_date_time]" 1] \
        [list [format "  [t help_cur_time]" \
            [clock format $_ts -format "%H:%M:%S"] \
            [clock format $_ts -format "%Y-%m-%d"]] 0] \
        [list "" 0] \
    ]
    if {$sel_wc >= 0} {
        lappend lines [list "  [t help_sel_info]" 1]
        lappend lines [list [format "  [t help_words_chars]" $sel_wc $sel_cc] 0]
        lappend lines [list "" 0]
    }
    set hm $::cfg_heading_marker
    set fb "  %-14s %s"
    if {$wc > 0} {
        set _today_wc [daily-today $wc]
        set _goal_str [expr {$::cfg_word_goal > 0 ? " / $::cfg_word_goal" : ""}]
        lappend lines \
            [list "  [t help_file_info]" 1] \
            [list [format "  [t help_words_chars]" $wc $cc] 0] \
            [list "  [t br_stats_today]: +${_today_wc}${_goal_str}" 0] \
            [list "" 0]
    }
    lappend lines \
        [list "  EDITOR" 1] \
        [list "" 0] \
        [list [format $f2 $lbl_save   [t help_k_save]    $lbl_undo   [t help_k_undo]]    0] \
        [list [format $f2 $_e         $_e                $lbl_redo   [t help_k_redo]]    0] \
        [list [format $f2 $lbl_close  [t help_k_close]   $lbl_selall [t help_k_sel_all]] 0] \
        [list [format $f2 $lbl_sticky [t help_k_sticky]  $lbl_copy   [t help_k_copy]]   0] \
        [list [format $f2 $lbl_find   [t help_k_find]    $lbl_cut    [t help_k_cut]]    0] \
        [list [format $f2 $lbl_repl   [t help_k_replace] $lbl_paste  [t help_k_paste]]  0] \
        [list [format $f2 $lbl_goto   [t help_k_goto]    $lbl_lnum   [t help_k_lnum]]   0] \
        [list [format $f2 $lbl_open   [t help_k_open]    $lbl_tw     [t help_k_typewriter]] 0] \
        [list "" 0] \
        [list [format "  %-16s %s" [t help_k_ctrl_arrows] ""] 0] \
        [list [format "  %-16s %s" $lbl_toc  [t help_k_toc]]  0] \
        [list [format "  %-16s %s" $lbl_help [t help_k_help]] 0] \
        [list "" 0] \
        [list "  BROWSER" 1] \
        [list "" 0] \
        [list [format $fb "Enter"          "Open file"]                0] \
        [list [format $fb "n"              "New file"]                 0] \
        [list [format $fb "t"              "Scratchpad"]               0] \
        [list [format $fb "f"              "Toggle favorite"]          0] \
        [list [format $fb "b"              "Backup (backups/ folder)"] 0] \
        [list [format $fb "i"              "Show full path"]           0] \
        [list [format $fb "d"              "Delete"]                   0] \
        [list [format $fb "r"              "Rename"]                   0] \
        [list [format $fb $lbl_toc         "Browser sections"]         0] \
        [list [format $fb $lbl_open        "Open any file"]            0] \
        [list [format $fb "h / $lbl_help"  "Help"]                     0] \
        [list [format $fb "q / Ctrl+Q"     "Quit"]                     0] \
        [list "" 0]
    set h [llength $lines]
    set w 60
    set left   [expr {max(0, ($cols - $w) / 2)}]
    set usable [expr {$rows - 2}]
    set scroll 0

    while 1 {
        set max_scroll [expr {max(0, $h - $usable)}]
        puts -nonewline "\033\[2J"
        for {set i 0} {$i < $usable} {incr i} {
            set li [expr {$scroll + $i}]
            set row_y [expr {$i + 1}]
            if {$li < $h} {
                tui-move $row_y $left
                lassign [lindex $lines $li] txt inv
                if {$inv} { tui-attr reverse }
                puts -nonewline "[string range $txt 0 [expr {$w-1}]]\033\[K"
                if {$inv} { tui-attr off }
            } else {
                tui-move $row_y 0; puts -nonewline "\033\[K"
            }
        }
        set hint [expr {$max_scroll > 0 ? "  Up/Dn scroll   q / Ctrl+H  close" : "  q / Ctrl+H  close"}]
        tui-bar [expr {$rows-1}] $hint "" $cols
        flush stdout
        set key [tui-getch]
        if {$key eq "q" || $key eq $::cfg_tui_help} break
        if {$key eq "UP"   && $scroll > 0}            { incr scroll -1 }
        if {$key eq "DOWN" && $scroll < $max_scroll}  { incr scroll  1 }
    }
    puts -nonewline "\033\[2J"
}

proc tui-getch {{timeout -1}} {
    if {$timeout < 0} {
        set timeout 0
        if {$::timer_active && $::cfg_chrono_show} { set timeout 50 }
    }
    chan configure stdin -blocking 0
    set raw [read stdin 1]
    chan configure stdin -blocking 1
    if {$raw eq ""} {
        # No immediate input, wait for timeout
        if {$timeout > 0} {
            after $timeout
            chan configure stdin -blocking 0
            set raw [read stdin 1]
            chan configure stdin -blocking 1
        }
        if {$raw eq ""} { return "" }
    }
    scan $raw %c b
    if {$b == 27} {
        # Read escape sequence byte by byte
        set seq ""
        chan configure stdin -blocking 0; set ch [read stdin 1]; chan configure stdin -blocking 1
        if {$ch eq ""} { return ESC }
        append seq $ch
        switch -- $ch {
            O {
                # SS3 sequence (xterm F1-F4): read one more byte
                chan configure stdin -blocking 0; set ch2 [read stdin 1]; chan configure stdin -blocking 1
                if {$ch2 ne ""} { append seq $ch2 }
            }
            {[} {
                # CSI sequence: read until letter or ~
                while {[string length $seq] < 20} {
                    chan configure stdin -blocking 0; set ch [read stdin 1]; chan configure stdin -blocking 1
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
            "\x1bOA"      { return UP    }  "\x1bOB"      { return DOWN  }
            "\x1bOC"      { return RIGHT }  "\x1bOD"      { return LEFT  }
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
            "\x1b\[1;5A"  { return CTRL-UP    }
            "\x1b\[1;5B"  { return CTRL-DOWN  }
            "\x1b\[1;5C"  { return CTRL-RIGHT }
            "\x1b\[1;5D"  { return CTRL-LEFT  }
            "\x1b\[5A"    { return CTRL-UP    }
            "\x1b\[5B"    { return CTRL-DOWN  }
            "\x1b\[5C"    { return CTRL-RIGHT }
            "\x1b\[5D"    { return CTRL-LEFT  }
            "\x1b\[1;3A"  { return CTRL-UP    }
            "\x1b\[1;3B"  { return CTRL-DOWN  }
            "\x1b\[1;3C"  { return CTRL-RIGHT }
            "\x1b\[1;3D"  { return CTRL-LEFT  }
            "\x1bb"       { return CTRL-LEFT  }
            "\x1bf"       { return CTRL-RIGHT }
            "\x1bt"       { return ALT-t }
            "\x1bT"       { return ALT-T }
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

# -- Word wrap -----------------------------------------------------------------

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

proc tui-build-layout {lines width cacheVar} {
    upvar 1 $cacheVar cache
    set vrows {}; set ish {}; set isd {}
    set new_cache [lrepeat [llength $lines] ""]
    set li 0
    foreach line $lines {
        set entry [lindex $cache $li]
        if {$entry ne "" && [lindex $entry 4] == $width && [lindex $entry 0] eq $line} {
            set segs  [lindex $entry 1]
            set is_h  [lindex $entry 2]
            set is_d  [lindex $entry 3]
            set spans [lindex $entry 5]          ;# may be empty on first pass
            lset new_cache $li [list $line $segs $is_h $is_d $width $spans]
        } else {
            set segs [tui-wrap-line $line $width]
            set is_h [expr {[parse-heading $line] ne ""}]
            set is_d [parse-comment $line]
            lset new_cache $li [list $line $segs $is_h $is_d $width {}]  ;# spans lazy
        }
        set lnum [expr {$li + 1}]
        foreach seg $segs {
            lappend vrows [list $lnum [lindex $seg 0] [lindex $seg 1]]
        }
        lappend ish $is_h
        lappend isd $is_d
        incr li
    }
    set cache $new_cache
    return [list $vrows $ish $isd]
}

proc tui-patch-vrows {dl} {
    upvar 1 lines lines vrows vrows ish_cache ish_cache isd_cache isd_cache \
            layout_cache layout_cache tw tw dirty_line dirty_line
    set idx [expr {$dl - 1}]
    set line [lindex $lines $idx]
    set old_entry [lindex $layout_cache $idx]
    if {$old_entry eq "" || [lindex $old_entry 4] != $tw} { return 0 }
    if {[lindex $old_entry 0] eq $line} { set dirty_line -1; return 1 }
    set old_nrows [llength [lindex $old_entry 1]]
    set new_segs  [tui-wrap-line $line $tw]
    set is_h      [expr {[parse-heading $line] ne ""}]
    set is_d      [parse-comment $line]
    set spans     [tui-parse-inline-spans $line]
    # binary search for first vrow belonging to line dl
    set n [llength $vrows]; set lo 0; set hi [expr {$n-1}]; set vs -1
    while {$lo <= $hi} {
        set mid [expr {($lo+$hi)/2}]
        if {[lindex [lindex $vrows $mid] 0] < $dl} { set lo [expr {$mid+1}] } \
        else { set vs $mid; set hi [expr {$mid-1}] }
    }
    if {$vs < 0} { return 0 }
    set new_entries {}
    foreach seg $new_segs { lappend new_entries [list $dl [lindex $seg 0] [lindex $seg 1]] }
    set vrows [lreplace $vrows $vs [expr {$vs+$old_nrows-1}] {*}$new_entries]
    lset layout_cache $idx [list $line $new_segs $is_h $is_d $tw $spans]
    lset ish_cache $idx $is_h
    lset isd_cache $idx $is_d
    set dirty_line -1
    return 1
}

proc tui-l2v {vrows cy cx} {
    set n [llength $vrows]
    if {$n == 0} { return {0 0} }
    # binary search: find first vrow with li >= cy
    set lo 0; set hi [expr {$n - 1}]
    while {$lo < $hi} {
        set mid [expr {($lo + $hi) / 2}]
        if {[lindex [lindex $vrows $mid] 0] < $cy} { set lo [expr {$mid + 1}] } \
        else { set hi $mid }
    }
    for {set vi $lo} {$vi < $n} {incr vi} {
        lassign [lindex $vrows $vi] li scol ecol
        if {$li > $cy} break
        if {$li == $cy && $scol <= $cx && $cx <= $ecol} {
            set nx [expr {$vi+1}]
            if {$cx == $ecol && $ecol > $scol && $nx < $n \
                    && [lindex [lindex $vrows $nx] 0] == $li \
                    && [lindex [lindex $vrows $nx] 1] <= $cx} continue
            return [list $vi [expr {$cx - $scol}]]
        }
    }
    lassign [lindex $vrows [expr {$n-1}]] li scol ecol
    return [list [expr {$n-1}] [expr {max(0, min($cx-$scol, $ecol-$scol))}]]
}

proc tui-v2l {vrows vi scx} {
    set n [llength $vrows]
    if {$n == 0} { return {1 0} }
    set vi [expr {max(0, min($vi, $n-1))}]
    lassign [lindex $vrows $vi] li scol ecol
    return [list $li [expr {$scol + max(0, min($scx, $ecol-$scol))}]]
}

# -- TUI helpers ---------------------------------------------------------------

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
    if {$::cfg_console_center_alert} {
        set line "  $msg (y/n)  "
        set w [string length $line]
        set row [expr {$rows / 2}]
        set lcol [expr {max(0, ($cols - $w) / 2)}]
        foreach r [list [expr {$row-1}] $row [expr {$row+1}]] {
            tui-move $r 0; puts -nonewline "\033\[2K"
        }
        tui-move $row $lcol
        tui-attr reverse; puts -nonewline $line; tui-attr off
    } else {
        tui-bar [expr {$rows-1}] " $msg (y/n)" "" $cols
    }
    flush stdout
    while 1 {
        set k [tui-getch]
        if {$k in {y Y}} { return 1 }
        if {$k in {n N ESC}} { return 0 }
    }
}

proc tui-yesnocancel {msg rows cols} {
    if {$::cfg_console_center_alert} {
        set line "  $msg  "
        set w [string length $line]
        set row [expr {$rows / 2}]
        set lcol [expr {max(0, ($cols - $w) / 2)}]
        foreach r [list [expr {$row-1}] $row [expr {$row+1}]] {
            tui-move $r 0; puts -nonewline "\033\[2K"
        }
        tui-move $row $lcol
        tui-attr reverse; puts -nonewline $line; tui-attr off
    } else {
        tui-bar [expr {$rows-1}] " $msg" "" $cols
    }
    flush stdout
    while 1 {
        set k [tui-getch]
        if {$k in {y Y o O}} { return yes }
        if {$k in {n N}}     { return no }
        if {$k in {c C ESC}} { return cancel }
    }
}

proc tui-active-dir {entries cfi} {
    set i [expr {$cfi >= 0 ? $cfi : 0}]
    while {$i >= 0} {
        lassign [lindex $entries $i] type dir
        if {$type eq "header"} { return [expr {$dir ne "" ? $dir : $::DOCS_DIR_DEFAULT}] }
        incr i -1
    }
    return $::DOCS_DIR_DEFAULT
}

# -- Clipboard ----------------------------------------------------------------

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

# -- Selection helpers ---------------------------------------------------------

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

# -- TUI Browser ---------------------------------------------------------------

proc tui-push-undo {} {
    upvar 1 undo_stack undo_stack redo_stack redo_stack lines lines cy cy cx cx
    lappend undo_stack [list $lines $cy $cx]
    if {[llength $undo_stack] > 100} { set undo_stack [lrange $undo_stack end-99 end] }
    set redo_stack {}
}

proc tui-mark-dirty {} {
    upvar 1 dirty dirty wc_dirty wc_dirty wrap_dirty wrap_dirty dirty_line dirty_line
    set dirty 1; set wc_dirty 1; set wrap_dirty 1; set dirty_line -1
}

proc tui-mark-line-dirty {} {
    upvar 1 dirty dirty wc_dirty wc_dirty wrap_dirty wrap_dirty dirty_line dirty_line \
            cy cy wc_cached wc_cached cc_cached cc_cached layout_cache layout_cache lines lines
    set dirty 1
    if {!$wrap_dirty} { set dirty_line $cy }
    if {!$wc_dirty} {
        set idx [expr {$cy - 1}]
        set old_entry [lindex $layout_cache $idx]
        if {$old_entry ne ""} {
            set old_line [lindex $old_entry 0]
            set new_line [lindex $lines $idx]
            incr wc_cached [expr {[llength [regexp -all -inline {\S+} $new_line]] \
                                 - [llength [regexp -all -inline {\S+} $old_line]]}]
            incr cc_cached [expr {[string length $new_line] - [string length $old_line]}]
        } else { set wc_dirty 1 }
    }
}

proc tui-compute-wc {} {
    upvar 1 lines lines wc_cached wc_cached cc_cached cc_cached wc_dirty wc_dirty
    set wc_cached 0; set cc_cached 0
    foreach l $lines {
        incr wc_cached [llength [regexp -all -inline {\S+} $l]]
        incr cc_cached [string length $l]
    }
    set wc_dirty 0
}

proc tui-browser {} {
    set sel 0; set scroll 0; set msg ""
    set prev_rows -1; set prev_cols -1
    while 1 {
        set ::tui_size_n 14
        lassign [tui-size] rows cols
        if {$rows != $prev_rows || $cols != $prev_cols} {
            set prev_rows $rows; set prev_cols $cols
        }
        # build entries
        set entries {}; set fcount 0
        set shown {}
        foreach dir [br-dirs] {
            foreach f [list-docs $dir] { lappend shown [file join $dir $f] }
        }
        foreach e [build-extra-entries $shown] { lappend entries $e }
        foreach dir [br-dirs] {
            lappend entries [list header $dir ""]
            foreach f [list-docs $dir] {
                lappend entries [list file $dir $f]
                incr fcount
            }
        }
        set fidx {}
        for {set i 0} {$i < [llength $entries]} {incr i} {
            if {[lindex [lindex $entries $i] 0] in {file recent favorite}} { lappend fidx $i }
        }
        set nf [llength $fidx]
        if {$nf > 0} { set sel [expr {max(0, min($sel, $nf-1))}] }

        tui-attr bold; tui-fill 0 " Writhdeck" $cols; tui-attr off
        set usable [expr {$rows - 3}]

        if {$nf == 0} {
            set m [t br_no_docs]
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
                    set lbl [expr {$name ne "" ? $name : [string map [list $::HOME_DIR ~] $dir]}]
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
        if {$::cfg_help_bar ne ""} { tui-help [expr {$rows-2}] [format [t br_help_tui] [t br_key_help] $::cfg_lbl_toc] $cols }
        set clk [expr {[status-zone-of clock] ne "" ? "  [clock format [clock seconds] -format {%H:%M}]" : ""}]
        if {$msg ne ""} { tui-bar [expr {$rows-1}] " $msg" "${clk} " $cols; set msg ""
        } else { tui-bar [expr {$rows-1}] " [string map [list $::HOME_DIR ~] $::DOCS_DIR_DEFAULT]" \
                         " [t br_files $fcount $plu]${clk} " $cols }
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
                    if {[file exists $fp]} { set msg [t br_exists $name]
                    } else { close [open $fp w]; return $fp }
                }
            }
            t { return "__scratchpad__" }
            h {
                tui-help-dialog $rows $cols 0 0
            }
            i {
                if {$cfi >= 0} {
                    lassign [lindex $entries $cfi] _ dir name
                    set msg [file join $dir $name]
                }
            }
            f {
                if {$cfi >= 0} {
                    lassign [lindex $entries $cfi] _ dir name
                    set _path [file join $dir $name]
                    set _was_fav [expr {$_path in $::favorites_list}]
                    toggle-favorite $_path
                    set msg [t [expr {$_was_fav ? "br_fav_removed" : "br_fav_added"}] $name]
                }
            }
            s {
                if {$cfi >= 0} {
                    lassign [lindex $entries $cfi] _ dir name
                    set _path [file join $dir $name]
                    if {!$::state_cache_valid} { state-load }
                    if {![dict exists $::daily_data $_path] || [dict size [dict get $::daily_data $_path]] == 0} {
                        set msg [t br_stats_no_data]
                    } else {
                        set _fdata [dict get $::daily_data $_path]
                        set _today [clock format [clock seconds] -format "%Y-%m-%d"]
                        set _lines [list [list "  [t br_stats_title] - $name" 1] [list "" 0] \
                            [list [format "  %-14s %s" "Date" "Words"] 1]]
                        set _grand_total 0
                        foreach _date [lsort -decreasing [dict keys $_fdata]] {
                            set _n [dict get $_fdata $_date]
                            incr _grand_total $_n
                            set _lbl [expr {$_date eq $_today ? "$_date  <- [t br_stats_today]" : $_date}]
                            lappend _lines [list [format "  %-28s %d" $_lbl $_n] 0]
                        }
                        lappend _lines [list "" 0]
                        lappend _lines [list [format "  %-28s %d" [t br_stats_total] $_grand_total] 1]
                        lappend _lines [list "" 0]
                        set _h [llength $_lines]; set _w 46
                        set _left [expr {max(0,($cols-$_w)/2)}]
                        set _top  [expr {max(0,($rows-$_h)/2)}]
                        puts -nonewline "\033\[2J"
                        for {set _i 0} {$_i < $_h} {incr _i} {
                            tui-move [expr {$_top+$_i}] $_left
                            lassign [lindex $_lines $_i] _txt _inv
                            if {$_inv} { tui-attr reverse }
                            puts -nonewline "[string range $_txt 0 [expr {$_w-1}]]\033\[K"
                            if {$_inv} { tui-attr off }
                        }
                        tui-bar [expr {$rows-1}] "  c [t br_stats_clear]   q / Ctrl+H  close" "" $cols
                        flush stdout
                        while 1 {
                            set _k [tui-getch]
                            if {$_k eq "q" || $_k eq $::cfg_tui_help} break
                            if {$_k eq "c"} {
                                if {[tui-confirm [t br_stats_clear_confirm $name] $rows $cols]} {
                                    daily-clear $_path
                                }
                                break
                            }
                        }
                        puts -nonewline "\033\[2J"
                    }
                }
            }
            b {
                if {$cfi >= 0} {
                    lassign [lindex $entries $cfi] _ dir name
                    set dst [do-backup $dir $name]
                    set msg [t br_backed_up $name [string map [list $::HOME_DIR ~] [file dirname $dst]]]
                }
            }
            d {
                if {$cfi >= 0} {
                    lassign [lindex $entries $cfi] _ dir name
                    if {[tui-confirm [t br_delete $name] $rows $cols]} {
                        set full [file join $dir $name]
                        file delete $full
                        recent-remove $full
                        set msg [t br_deleted $name]; if {$sel > 0} { incr sel -1 }
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
                        if {[file exists $np]} { set msg [t br_exists $new]
                        } else {
                            set old_path [file join $dir $name]
                            file rename $old_path $np
                            recent-rename $old_path $np
                            set msg [t br_renamed $new]
                        }
                    }
                }
            }
            w {
                if {$cfi >= 0} {
                    lassign [lindex $entries $cfi] _ dir name
                    set _path [file join $dir $name]
                    if {[file isfile $_path]} {
                        tui-word-occurrences $_path $rows $cols
                    }
                }
            }
            c {
                tui-config-dialog $rows $cols
            }
        }
        if {$key eq $::cfg_tui_help && $key ne "h"} {
            tui-help-dialog $rows $cols 0 0
        }
        if {$key eq $::cfg_tui_toc} {
            set _secs {}
            for {set _i 0} {$_i < [llength $entries]} {incr _i} {
                lassign [lindex $entries $_i] _t _d _n
                if {$_t eq "header"} {
                    set _lbl [expr {$_n ne "" ? $_n : [string map [list $::HOME_DIR ~] $_d]}]
                    lappend _secs [list $_i $_lbl]
                }
            }
            if {[llength $_secs] > 0} {
                set _ns [llength $_secs]; set _sel 0; set _scroll 0
                set _usable [expr {$rows-3}]
                while 1 {
                    if {$_sel < $_scroll}             { set _scroll $_sel }
                    if {$_sel >= $_scroll + $_usable} { set _scroll [expr {$_sel - $_usable + 1}] }
                    tui-attr bold; tui-fill 0 " [t br_toc_title]" $cols; tui-attr off
                    for {set _i 0} {$_i < $_usable} {incr _i} {
                        set _idx [expr {$_scroll+$_i}]
                        if {$_idx >= $_ns} {
                            tui-move [expr {$_i+1}] 0; puts -nonewline "\033\[K"
                            continue
                        }
                        set _line [format "  %s" [lindex [lindex $_secs $_idx] 1]]
                        if {$_idx == $_sel} { tui-attr reverse }
                        tui-fill [expr {$_i+1}] [string range $_line 0 [expr {$cols-1}]] $cols
                        if {$_idx == $_sel} { tui-attr off }
                    }
                    tui-help [expr {$rows-2}] [t br_toc_bar] $cols
                    tui-bar  [expr {$rows-1}] "" "" $cols
                    flush stdout
                    set _key [tui-getch]
                    switch -- $_key {
                        ESC - "\x11" - q { break }
                        UP - k   { if {$_sel > 0}      { incr _sel -1 } }
                        DOWN - j { if {$_sel < $_ns-1} { incr _sel  1 } }
                        HOME     { set _sel 0 }
                        END      { set _sel [expr {$_ns-1}] }
                        ENTER {
                            set _hi [lindex [lindex $_secs $_sel] 0]
                            for {set _j 0} {$_j < [llength $fidx]} {incr _j} {
                                if {[lindex $fidx $_j] > $_hi} { set sel $_j; break }
                            }
                            break
                        }
                    }
                }
                puts -nonewline "\033\[2J"
            }
        }
        if {$key eq $::cfg_tui_open} {
            set _dir [expr {$cfi >= 0 ? [lindex [lindex $entries $cfi] 1] : $::DOCS_DIR_DEFAULT}]
            set _lbl [string map [list $::HOME_DIR ~] $_dir]
            set _in  [string trim [tui-prompt "open \[${_lbl}/\]: " $rows $cols]]
            if {$_in ne "" && !$::tui_escaped} {
                set _fp [expr {[file pathtype $_in] eq "absolute" ? $_in : [file join $_dir $_in]}]
                if {[file isfile $_fp]} { return $_fp } else { set msg "not found: $_in" }
            }
        }
    }
}

# -- TUI TOC -------------------------------------------------------------------

proc tui-toc {lines rows cols {cy 1} {filepath ""}} {
    set headings {}; set ln 1
    foreach line $lines {
        set hl [heading-level $line]
        if {$hl ne ""} {
            lassign $hl t level
            lappend headings [list $ln $t $level]
        }
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
        set usable [expr {$rows-3}]
        if {$sel < $scroll}            { set scroll $sel }
        if {$sel >= $scroll + $usable} { set scroll [expr {$sel - $usable + 1}] }
        tui-attr bold; tui-fill 0 " [t toc_title]" $cols; tui-attr off
        for {set i 0} {$i < $usable} {incr i} {
            set idx [expr {$scroll+$i}]
            if {$idx >= [llength $headings]} {
                tui-move [expr {$i+1}] 0; puts -nonewline "\033\[K"
                continue
            }
            lassign [lindex $headings $idx] ln title level
            set indent [string repeat "- " [expr {$level - 1}]]
            set line [format "  %4d   %s%s" $ln $indent $title]
            if {$idx == $sel} { tui-attr reverse }
            tui-fill [expr {$i+1}] [string range $line 0 [expr {$cols-1}]] $cols
            if {$idx == $sel} { tui-attr off }
        }
        set nh [llength $headings]; set plu [expr {$nh != 1 ? "s" : ""}]
        tui-help [expr {$rows-2}] [t toc_jump_bar] $cols
        tui-bar  [expr {$rows-1}] " [t toc_headings $nh $plu]" "" $cols
        flush stdout
        switch -- [tui-getch] {
            ESC - "\x11" { return {} }
            UP - k   { if {$sel > 0} { incr sel -1 } }
            DOWN - j { if {$sel < $nh-1} { incr sel 1 } }
            HOME     { set sel 0 }
            END      { set sel [expr {$nh-1}] }
            ENTER    { if {$filepath ne ""} { dict set ::session_headings $filepath $sel }
                       return [lindex $headings $sel] }
        }
    }
}

proc tui-save-file {filepath lines} {
    set fh [open $filepath w]; chan configure $fh -encoding utf-8
    puts -nonewline $fh "[join $lines \n]\n"; close $fh
}

# -- TUI Editor ----------------------------------------------------------------

proc tui-scratchpad-save {rows cols linesVar filepathVar dirtyVar} {
    upvar 1 $linesVar lines $filepathVar filepath $dirtyVar dirty
    lassign [tui-size] rows cols
    set name [string trim [tui-prompt "save as: " $rows $cols]]
    if {$name eq ""} return
    if {[file extension $name] eq ""} { append name $::FILE_EXT }
    set fp [file join $::DOCS_DIR_DEFAULT $name]
    if {[file exists $fp]} {
        if {![tui-confirm "\"$name\" exists. Overwrite?" $rows $cols]} return
    }
    set filepath $fp
    tui-save-file $filepath $lines
    set dirty 0
}

proc tui-editor {filepath} {
    # -- load ------------------------------------------------------------------
    set lines {}
    if {$filepath ne "" && [file exists $filepath] && [file size $filepath] > 0} {
        set fh [open $filepath r]; chan configure $fh -encoding utf-8
        set content [read $fh]; close $fh
        foreach line [split $content "\n"] { lappend lines $line }
        if {[llength $lines] > 1 && [lindex $lines end] eq ""} {
            set lines [lrange $lines 0 end-1]
        }
    }
    if {[llength $lines] == 0} { set lines [list ""] }
    if {$filepath ne ""} {
        recent-push $filepath
        set _wc [llength [regexp -all -inline {\S+} [join $lines "\n"]]]
        daily-open $filepath $_wc
    }

    # -- cursor restore --------------------------------------------------------
    if {$filepath eq ""} { set cy 1; set cx 0 } else { lassign [cursor-get $filepath] cy cx }
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
    set redo_stack {}
    set file_mtime_known [expr {$filepath ne "" && [file exists $filepath] \
        ? [file mtime $filepath] : 0}]
    set sel_anchor ""
    set sel_sticky  0
    if {![info exists ::tui_search]}  { set ::tui_search  "" }
    if {![info exists ::tui_replace]} { set ::tui_replace "" }

    # push-undo: call before any destructive edit
    set wc_dirty 1; set wrap_dirty 1; set wc_cached 0; set cc_cached 0
    set vrows {}; set prev_tw -1
    set ish_cache {}; set isd_cache {}
    set layout_cache {}
    set prev_rows -1; set prev_cols -1
    set dirty_line -1

    while 1 {
        set ::tui_size_n 14
        lassign [tui-size] rows cols
        if {$rows != $prev_rows || $cols != $prev_cols} {
            set prev_rows $rows; set prev_cols $cols
            set wrap_dirty 1
        }

        # -- layout ------------------------------------------------------------
        set _hm   [expr {$::typewriter_mode && $::cfg_hemingway_mode ? 2 : 1}]
        set roff  [expr {$::cfg_console_margin_rows * $_hm}]
        set marg  [expr {$::cfg_console_margin_cols * $_hm}]
        set ln_w  [expr {$::cfg_line_numbers ? [string length [llength $lines]] + 2 : 0}]
        set coff  [expr {$marg + $ln_w}]
        set tw    [expr {max(1, $cols - $coff - $marg - 1)}]   ;# -1 for scroll indicator
        set _hm_bar [expr {$::typewriter_mode && $::cfg_hemingway_mode}]
        set th    [expr {max(1, $rows - ($::typewriter_mode && $::cfg_hemingway_mode ? 0 : 2) - 2*$roff)}]

        set cy [expr {max(1, min($cy, [llength $lines]))}]
        set cx [expr {max(0, min($cx, [string length [lindex $lines [expr {$cy-1}]]]))}]

        if {$wrap_dirty || $tw != $prev_tw} {
            lassign [tui-build-layout $lines $tw layout_cache] vrows ish_cache isd_cache
            set prev_tw $tw; set wrap_dirty 0; set dirty_line -1
        } elseif {$dirty_line > 0} {
            if {![tui-patch-vrows $dirty_line]} {
                lassign [tui-build-layout $lines $tw layout_cache] vrows ish_cache isd_cache
                set dirty_line -1
            }
        }
        lassign [tui-l2v $vrows $cy $cx] vi scx

        if {$toc_jumped} { set scroll_y $vi; set toc_jumped 0 } elseif {$::typewriter_mode} {
            set scroll_y [expr {$vi - $th/2}]
        } else {
            if {$vi < $scroll_y}        { set scroll_y $vi }
            if {$vi >= $scroll_y + $th} { set scroll_y [expr {$vi - $th + 1}] }
        }
        set scroll_y [expr {max(0, min($scroll_y, max(0, [llength $vrows] - $th)))}]

        # -- draw --------------------------------------------------------------
        set sel_r [tui-sel-range $sel_anchor $cy $cx]
        if {$sel_r ne {}} { lassign $sel_r _sly _scx_s _ely _ecx_s }

        # typewriter focus: paragraph boundaries (source line numbers)
        if {$::typewriter_mode} {
            set _para_s $cy; set _para_e $cy
            set _nl [llength $lines]
            while {$_para_s > 1 && [string trim [lindex $lines [expr {$_para_s-2}]]] ne ""} { incr _para_s -1 }
            while {$_para_e < $_nl && [string trim [lindex $lines $_para_e]] ne ""} { incr _para_e }
        }

        for {set i 0} {$i < $th} {incr i} {
            set vi2 [expr {$scroll_y + $i}]
            set srow [expr {$i + $roff}]
            tui-move $srow 0
            if {$vi2 >= [llength $vrows]} {
                puts -nonewline [string repeat { } $cols]
                continue
            }
            lassign [lindex $vrows $vi2] li scol ecol
            set seg [string range [lindex $lines [expr {$li-1}]] $scol [expr {$ecol-1}]]
            set ish [lindex $ish_cache [expr {$li-1}]]
            set isd [lindex $isd_cache [expr {$li-1}]]
            set seg_len [string length $seg]

            # left margin + line number - written inline from col 0 (no tui-move within line)
            if {$ln_w > 0 && $scol == 0} {
                tui-attr dim
                puts -nonewline "[string repeat { } $marg][format "%[expr {$ln_w-1}]d " $li]"
                tui-attr off
            } else {
                puts -nonewline [string repeat { } $coff]
            }

            # text (with selection highlight) - cursor now at col $coff
            set sf -1; set st -1
            if {$sel_r ne {}} {
                if      {$li > $_sly && $li < $_ely}         { set sf 0;                              set st $seg_len } \
                elseif  {$li == $_sly && $li == $_ely}        { set sf [expr {max(0,$_scx_s-$scol)}]; set st [expr {min($seg_len,$_ecx_s-$scol)}] } \
                elseif  {$li == $_sly}                        { set sf [expr {max(0,$_scx_s-$scol)}]; set st $seg_len } \
                elseif  {$li == $_ely}                        { set sf 0;                              set st [expr {min($seg_len,$_ecx_s-$scol)}] }
                if {$sf >= 0 && $sf >= $st} { set sf -1 }
            }
            set _tw_dim [expr {$::typewriter_mode && ($li < $_para_s || $li > $_para_e)}]
            if {$_tw_dim} {
                tui-attr dim
                if {$sf >= 0} {
                    puts -nonewline [string range $seg 0 [expr {$sf-1}]]
                    tui-attr reverse; puts -nonewline [string range $seg $sf [expr {$st-1}]]; tui-attr off
                    tui-attr dim; puts -nonewline [string range $seg $st end]
                } else {
                    puts -nonewline $seg
                }
                tui-attr off
            } elseif {$ish || $isd} {
                set _a [expr {$ish ? "heading" : "dim-text"}]
                if {$sf >= 0} {
                    if {$sf > 0} { tui-attr $_a; puts -nonewline [string range $seg 0 [expr {$sf-1}]]; tui-attr off }
                    tui-attr reverse; puts -nonewline [string range $seg $sf [expr {$st-1}]]; tui-attr off
                    if {$st < $seg_len} { tui-attr $_a; puts -nonewline [string range $seg $st end]; tui-attr off }
                } else {
                    tui-attr $_a; puts -nonewline $seg; tui-attr off
                }
            } else {
                set _lc_entry [lindex $layout_cache [expr {$li-1}]]
                set _spans [lindex $_lc_entry 5]
                if {$_spans eq {}} {
                    set _spans [tui-parse-inline-spans [lindex $lines [expr {$li-1}]]]
                    lset layout_cache [expr {$li-1}] [lreplace $_lc_entry 5 5 $_spans]
                }
                tui-render-inline-seg $seg $scol $_spans $sf $st
            }
            # right padding - fill to end of line with spaces (no \033[K)
            tui-attr off
            puts -nonewline [string repeat { } [expr {$tw - $seg_len + $marg + 1}]]
        }

        # -- scroll indicator --------------------------------------------------
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

        # -- bars --------------------------------------------------------------
        if {$_hm_bar} {
            tui-move [expr {$rows-2}] 0; puts -nonewline "\033\[K"
            tui-move [expr {$rows-1}] 0; puts -nonewline "\033\[K"
        } else {
            set sel_info [expr {$sel_r ne {} ? " \[sel\]" : ""}]
            set sel_hint [expr {$sel_anchor ne "" ? "$::cfg_lbl_sticky cancel-sel" : "$::cfg_lbl_sticky sel"}]
            set _hzone [status-zone-of help_bar]
            if {$::cfg_help_bar ne "" && $_hzone ne ""} { tui-help [expr {$rows-2}] $::cfg_help_bar $cols $_hzone }
            if {$wc_dirty && ([status-zone-of words] ne "" || [status-zone-of chars] ne "" || [status-zone-of goal] ne "")} {
                tui-compute-wc
            }
            timer-tick
            set timer_display [expr {$::cfg_timer_duration * 60}]
            if {$::timer_active} {
                set timer_display $::timer_remaining
            }
            set tui_state [dict create \
                fn    [expr {$filepath eq "" ? "** scratchpad **" : [file tail $filepath]}] \
                dirty $dirty \
                sel   [expr {$sel_anchor ne ""}] \
                ln    $cy  total [llength $lines] \
                col   [expr {$cx+1}] \
                words $wc_cached \
                chars $cc_cached \
                clock [clock format [clock seconds] -format "%H:%M"] \
                timer $timer_display]
            if {$::tui_cmd_mode} {
                set bar_left " $message"
                set bar_center ""
                set bar_right ""
            } else {
                set bar_left   " [status-build $::cfg_status_left   $tui_state]"
                set bar_center [status-build $::cfg_status_center $tui_state]
                set bar_right  "[status-build $::cfg_status_right  $tui_state] "
                if {$::cfg_key_error ne "" && $message eq ""} { set message "key conflict: $::cfg_key_error"; set msg_time [clock seconds] }
                if {$message ne "" && [clock seconds] - $msg_time < 4} { set bar_left " $message" }
            }
            tui-bar [expr {$rows-1}] $bar_left $bar_right $cols $bar_center
        }

        tui-move [expr {$vi - $scroll_y + $roff}] [expr {$scx + $coff}]
        puts -nonewline "\033\[?25h"; flush stdout

        set key [tui-getch]; puts -nonewline "\033\[?25l"
        set rst       1
        set clear_sel 1

        # -- external modification check ---------------------------------------
        if {$::cfg_watch_file && $filepath ne "" && [file exists $filepath]} {
            set _mtime [file mtime $filepath]
            if {$_mtime != $file_mtime_known} {
                set file_mtime_known $_mtime
                set _wkey [expr {$dirty ? "ed_watch_reload_dirty" : "ed_watch_reload"}]
                if {[tui-confirm [t $_wkey [file tail $filepath]] $rows $cols]} {
                    set lines {}
                    if {[file size $filepath] > 0} {
                        set fh [open $filepath r]; chan configure $fh -encoding utf-8
                        foreach line [split [read $fh] "\n"] { lappend lines $line }
                        close $fh
                        if {[llength $lines] > 1 && [lindex $lines end] eq ""} {
                            set lines [lrange $lines 0 end-1]
                        }
                    }
                    if {[llength $lines] == 0} { set lines [list ""] }
                    set cy 1; set cx 0; set scroll_y 0
                    set undo_stack {}; set redo_stack {}
                    set dirty 0; set wrap_dirty 1
                }
            }
        }

        switch -- $key {
            UP {
                if {$::typewriter_mode && $::cfg_hemingway_mode} {}  \
                elseif {$vi > 0} { if {$sticky<0} {set sticky $scx}; lassign [tui-v2l $vrows [expr {$vi-1}] $sticky] cy cx }
                set rst 0
                if {$sel_sticky} { if {$sel_anchor eq ""} { set sel_anchor [list $cy $cx] }; set clear_sel 0 }
            }
            DOWN {
                if {$::typewriter_mode && $::cfg_hemingway_mode} {}  \
                elseif {$vi < [llength $vrows]-1} { if {$sticky<0} {set sticky $scx}; lassign [tui-v2l $vrows [expr {$vi+1}] $sticky] cy cx }
                set rst 0
                if {$sel_sticky} { if {$sel_anchor eq ""} { set sel_anchor [list $cy $cx] }; set clear_sel 0 }
            }
            SHIFT-UP {
                if {!($::typewriter_mode && $::cfg_hemingway_mode)} {
                    set sel_sticky 0
                    if {$sel_anchor eq ""} { set sel_anchor [list $cy $cx] }
                    if {$vi > 0} { if {$sticky<0} {set sticky $scx}; lassign [tui-v2l $vrows [expr {$vi-1}] $sticky] cy cx }
                    set rst 0; set clear_sel 0
                }
            }
            SHIFT-DOWN {
                if {!($::typewriter_mode && $::cfg_hemingway_mode)} {
                    set sel_sticky 0
                    if {$sel_anchor eq ""} { set sel_anchor [list $cy $cx] }
                    if {$vi < [llength $vrows]-1} { if {$sticky<0} {set sticky $scx}; lassign [tui-v2l $vrows [expr {$vi+1}] $sticky] cy cx }
                    set rst 0; set clear_sel 0
                }
            }
            SHIFT-LEFT {
                if {!($::typewriter_mode && $::cfg_hemingway_mode)} {
                    set sel_sticky 0
                    if {$sel_anchor eq ""} { set sel_anchor [list $cy $cx] }
                    if {$cx > 0} { incr cx -1 } elseif {$cy > 1} { incr cy -1; set cx [string length [lindex $lines [expr {$cy-1}]]] }
                    set clear_sel 0
                }
            }
            SHIFT-RIGHT {
                if {!($::typewriter_mode && $::cfg_hemingway_mode)} {
                    set sel_sticky 0
                    if {$sel_anchor eq ""} { set sel_anchor [list $cy $cx] }
                    if {$cx < [string length [lindex $lines [expr {$cy-1}]]]} { incr cx
                    } elseif {$cy < [llength $lines]} { incr cy; set cx 0 }
                    set clear_sel 0
                }
            }
            LEFT {
                if {$::typewriter_mode && $::cfg_hemingway_mode} {} elseif {$sel_sticky} {
                    if {$cx > 0} { incr cx -1 } elseif {$cy > 1} { incr cy -1; set cx [string length [lindex $lines [expr {$cy-1}]]] }
                    set clear_sel 0
                } elseif {$sel_anchor ne ""} {
                    lassign [tui-sel-range $sel_anchor $cy $cx] cy cx
                } elseif {$cx > 0} { incr cx -1
                } elseif {$cy > 1} { incr cy -1; set cx [string length [lindex $lines [expr {$cy-1}]]] }
            }
            RIGHT {
                if {$::typewriter_mode && $::cfg_hemingway_mode} {} elseif {$sel_sticky} {
                    if {$cx < [string length [lindex $lines [expr {$cy-1}]]]} { incr cx
                    } elseif {$cy < [llength $lines]} { incr cy; set cx 0 }
                    set clear_sel 0
                } elseif {$sel_anchor ne ""} {
                    lassign [tui-sel-range $sel_anchor $cy $cx] sly scx_ ely ecx_
                    set cy $ely; set cx $ecx_
                } elseif {$cx < [string length [lindex $lines [expr {$cy-1}]]]} { incr cx
                } elseif {$cy < [llength $lines]} { incr cy; set cx 0 }
            }
            CTRL-UP {
                set r [expr {$cy - 1}]
                while {$r > 1 && [string trim [lindex $lines [expr {$r-1}]]] eq ""} { incr r -1 }
                while {$r > 1 && [string trim [lindex $lines [expr {$r-2}]]] ne ""} { incr r -1 }
                set cy [expr {max(1,$r)}]; set cx 0; set rst 0
            }
            CTRL-DOWN {
                set r $cy; set _nl [llength $lines]
                while {$r <= $_nl && [string trim [lindex $lines [expr {$r-1}]]] ne ""} { incr r }
                while {$r <= $_nl && [string trim [lindex $lines [expr {$r-1}]]] eq ""} { incr r }
                set cy [expr {min($_nl,$r)}]; set cx 0; set rst 0
            }
            CTRL-LEFT {
                if {$cx == 0 && $cy > 1} {
                    incr cy -1; set cx [string length [lindex $lines [expr {$cy-1}]]]
                }
                set l [lindex $lines [expr {$cy-1}]]
                while {$cx > 0 && [string index $l [expr {$cx-1}]] eq " "} { incr cx -1 }
                while {$cx > 0 && [string index $l [expr {$cx-1}]] ne " "} { incr cx -1 }
                set rst 0
            }
            CTRL-RIGHT {
                set l [lindex $lines [expr {$cy-1}]]; set _nl [llength $lines]
                set len [string length $l]
                while {$cx < $len && [string index $l $cx] ne " "} { incr cx }
                while {$cx < $len && [string index $l $cx] eq " "}  { incr cx }
                if {$cx >= $len && $cy < $_nl} { incr cy; set cx 0 }
                set rst 0
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
                if {!($::typewriter_mode && $::cfg_hemingway_mode)} {
                    tui-push-undo
                    if {$sel_anchor ne ""} {
                        lassign [tui-sel-delete $lines $sel_anchor $cy $cx] lines cy cx; tui-mark-dirty
                    } elseif {$cx > 0} {
                        set l [lindex $lines [expr {$cy-1}]]
                        lset lines [expr {$cy-1}] "[string range $l 0 [expr {$cx-2}]][string range $l $cx end]"
                        incr cx -1; tui-mark-line-dirty
                    } elseif {$cy > 1} {
                        set cx [string length [lindex $lines [expr {$cy-2}]]]
                        lset lines [expr {$cy-2}] "[lindex $lines [expr {$cy-2}]][lindex $lines [expr {$cy-1}]]"
                        set lines [lreplace $lines [expr {$cy-1}] [expr {$cy-1}]]
                        incr cy -1; tui-mark-dirty
                    }
                }
            }
            DC {
                if {!($::typewriter_mode && $::cfg_hemingway_mode)} {
                    tui-push-undo
                    if {$sel_anchor ne ""} {
                        lassign [tui-sel-delete $lines $sel_anchor $cy $cx] lines cy cx; tui-mark-dirty
                    } else {
                        set l [lindex $lines [expr {$cy-1}]]
                        if {$cx < [string length $l]} {
                            lset lines [expr {$cy-1}] "[string range $l 0 [expr {$cx-1}]][string range $l [expr {$cx+1}] end]"
                            tui-mark-line-dirty
                        } elseif {$cy < [llength $lines]} {
                            lset lines [expr {$cy-1}] "${l}[lindex $lines $cy]"
                            set lines [lreplace $lines $cy $cy]; tui-mark-dirty
                        }
                    }
                }
            }
            ENTER {
                tui-push-undo
                if {$sel_anchor ne ""} { lassign [tui-sel-delete $lines $sel_anchor $cy $cx] lines cy cx; tui-mark-dirty }
                set l [lindex $lines [expr {$cy-1}]]
                set lines [linsert [lreplace $lines [expr {$cy-1}] [expr {$cy-1}] \
                    [string range $l 0 [expr {$cx-1}]]] $cy [string range $l $cx end]]
                incr cy; set cx 0; tui-mark-dirty
            }
            TAB {
                tui-push-undo
                if {$sel_anchor ne ""} { lassign [tui-sel-delete $lines $sel_anchor $cy $cx] lines cy cx; tui-mark-dirty }
                set l [lindex $lines [expr {$cy-1}]]
                lset lines [expr {$cy-1}] "[string range $l 0 [expr {$cx-1}]]\t[string range $l $cx end]"
                incr cx 1; tui-mark-line-dirty
            }
            default {
                set c [scan $key %c]
                if {$key eq $::cfg_tui_save} {
                    if {$filepath eq ""} {
                        tui-scratchpad-save $rows $cols lines filepath dirty
                        if {$filepath ne ""} {
                            set file_mtime_known [file mtime $filepath]
                            set message [t ed_saved]; set msg_time [clock seconds]
                        }
                    } else {
                        tui-save-file $filepath $lines
                        set file_mtime_known [file mtime $filepath]
                        cursor-put $filepath $cy $cx
                        set dirty 0; set message [t ed_saved]; set msg_time [clock seconds]
                    }
                    set clear_sel 0
                } elseif {$key eq "ESC"} {
                    # Enter command mode with ESC
                    set ::tui_cmd_mode 1
                    set message "ESC: exit mode  t: timer  q: quit  s: stats  (other: back)"
                    set msg_time [clock seconds]
                    set clear_sel 0
                } elseif {$::tui_cmd_mode} {
                    # In command mode
                    if {$key eq "ESC"} {
                        # Double ESC exits command mode only
                        set ::tui_cmd_mode 0
                        set message ""
                        set msg_time [clock seconds]
                        set clear_sel 0
                    } elseif {$key eq "t"} {
                        # Toggle timer, exit command mode
                        if {$::timer_active} { timer-pause } else { timer-start }
                        set ::tui_cmd_mode 0
                        set message ""
                        set msg_time [clock seconds]
                        set clear_sel 0
                    } elseif {$key eq "q"} {
                        # Quit/close file, exit command mode first
                        set ::tui_cmd_mode 0
                        if {$dirty} {
                            lassign [tui-size] rows cols
                            set r [tui-yesnocancel [t ed_save_before_tui] $rows $cols]
                            if {$r eq "cancel"} {
                                set clear_sel 0
                            } else {
                                if {$r eq "yes"} {
                                    if {$filepath eq ""} {
                                        tui-scratchpad-save $rows $cols lines filepath dirty
                                    } else {
                                        tui-save-file $filepath $lines
                                    }
                                }
                                if {$filepath ne ""} { daily-update $wc_cached; cursor-put $filepath $cy $cx }
                                set ::session_file ""; return
                            }
                        } else {
                            if {$filepath ne ""} { daily-update $wc_cached; cursor-put $filepath $cy $cx }
                            set ::session_file ""; return
                        }
                    } elseif {$key eq "s"} {
                        # Show statistics, exit command mode
                        set ::tui_cmd_mode 0
                        lassign [tui-size] rows cols
                        if {$filepath ne ""} {
                            if {![dict exists $::daily_data $filepath] || [dict size [dict get $::daily_data $filepath]] == 0} {
                                puts -nonewline "\033\[2J"
                                tui-move 1 2
                                puts -nonewline [t br_stats_no_data]
                                puts -nonewline "\033\[K"
                                tui-bar [expr {$rows-1}] "Press any key to continue" "" $cols
                                flush stdout
                                set key [tui-getch]
                            } else {
                                set fdata [dict get $::daily_data $filepath]
                                set stat_lines [list]
                                lappend stat_lines "[t br_stats_title] - [file tail $filepath]"
                                lappend stat_lines ""
                                lappend stat_lines "Date          Words"
                                lappend stat_lines "----          -----"
                                dict for {date count} $fdata {
                                    lappend stat_lines [format "%-14s %5d" $date $count]
                                }
                                puts -nonewline "\033\[2J"
                                set display_lines [expr {min([llength $stat_lines], $rows - 2)}]
                                for {set _i 0} {$_i < $display_lines} {incr _i} {
                                    tui-move $_i 2
                                    set line [lindex $stat_lines $_i]
                                    puts -nonewline [string range $line 0 [expr {$cols-5}]]
                                    puts -nonewline "\033\[K"
                                }
                                tui-bar [expr {$rows-1}] "Press any key to continue" "" $cols
                                flush stdout
                                set key [tui-getch]
                            }
                        }
                        set message ""
                        set msg_time [clock seconds]
                        set clear_sel 0
                    } else {
                        # Any other key does nothing, stay in command mode
                        set key ""
                        set clear_sel 0
                    }
                } elseif {$key eq $::cfg_tui_close} {
                    if {$dirty} {
                        lassign [tui-size] rows cols
                        set r [tui-yesnocancel [t ed_save_before_tui] $rows $cols]
                        if {$r eq "cancel"} {
                            set clear_sel 0
                        } else {
                            if {$r eq "yes"} {
                                if {$filepath eq ""} {
                                    tui-scratchpad-save $rows $cols lines filepath dirty
                                } else {
                                    tui-save-file $filepath $lines
                                }
                            }
                            if {$filepath ne ""} { daily-update $wc_cached; cursor-put $filepath $cy $cx }
                            set ::session_file ""; return
                        }
                    } else {
                        if {$filepath ne ""} { daily-update $wc_cached; cursor-put $filepath $cy $cx }
                        set ::session_file ""; return
                    }
                } elseif {$key eq $::cfg_tui_open} {
                    if {$filepath ne ""} { tui-save-file $filepath $lines; daily-update $wc_cached; cursor-put $filepath $cy $cx }
                    set ::session_file ""; set dirty 0; return
                } elseif {$key eq $::cfg_tui_undo} {
                    if {!($::typewriter_mode && $::cfg_hemingway_mode) && [llength $undo_stack] > 0} {
                        lappend redo_stack [list $lines $cy $cx]
                        lassign [lindex $undo_stack end] lines cy cx
                        set undo_stack [lrange $undo_stack 0 end-1]; tui-mark-dirty
                    }
                    set clear_sel 0
                } elseif {$key eq $::cfg_tui_redo} {
                    if {[llength $redo_stack] > 0} {
                        lappend undo_stack [list $lines $cy $cx]
                        lassign [lindex $redo_stack end] lines cy cx
                        set redo_stack [lrange $redo_stack 0 end-1]; tui-mark-dirty
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
                        tui-push-undo; tui-copy $txt
                        lassign [tui-sel-delete $lines $sel_anchor $cy $cx] lines cy cx
                        tui-mark-dirty; set message "cut"; set msg_time [clock seconds]
                    }
                } elseif {$key eq $::cfg_tui_paste || [string match "PASTE:*" $key]} {
                    if {[string match "PASTE:*" $key]} {
                        set txt [string range $key 6 end]
                    } else {
                        set txt [tui-paste]
                    }
                    if {$txt ne ""} {
                        tui-push-undo
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
                        tui-mark-dirty
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
                                tui-push-undo; set lines $new_lines; tui-mark-dirty
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
                    if {[llength $target] >= 2} {
                        set cy [lindex $target 0]; set cx 0
                        set toc_jumped 1
                    }
                } elseif {$key eq $::cfg_tui_dark_toggle} {
                    set ::cfg_dark_mode [expr {!$::cfg_dark_mode}]
                    tui-reverse-video [expr {!$::cfg_dark_mode}]
                    set clear_sel 0
                } elseif {$key eq $::cfg_tui_typewriter} {
                    set ::typewriter_mode [expr {!$::typewriter_mode}]
                    set wrap_dirty 1; puts -nonewline "\033\[2J"
                    set clear_sel 0
                } elseif {$key eq $::cfg_tui_line_nums} {
                    set ::cfg_line_numbers [expr {$::cfg_line_numbers ? 0 : 1}]
                    set clear_sel 0
                } elseif {$key eq $::cfg_tui_help} {
                    lassign [tui-size] rows cols
                    if {$wc_dirty} { tui-compute-wc }
                    set _sel_wc -1; set _sel_cc -1
                    if {$sel_anchor ne ""} {
                        set _stxt [tui-sel-text $lines $sel_anchor $cy $cx]
                        set _sel_wc [llength [regexp -all -inline {\S+} $_stxt]]
                        set _sel_cc [string length $_stxt]
                    }
                    tui-help-dialog $rows $cols $wc_cached $cc_cached $_sel_wc $_sel_cc
                    set clear_sel 0
                } elseif {$key eq "ALT-t"} {
                    if {$::timer_active} { timer-pause } else { timer-start }
                    set clear_sel 0
                } elseif {$key eq "ALT-T"} {
                    timer-reset
                    set clear_sel 0
                } elseif {[string match "F*" $key]} {                          ;# ignore unknown F-keys
                    set clear_sel 0
                } elseif {[string length $key] >= 1 && ($c eq "" || $c >= 32)} {
                    tui-push-undo
                    if {$sel_anchor ne ""} { lassign [tui-sel-delete $lines $sel_anchor $cy $cx] lines cy cx; tui-mark-dirty }
                    set l [lindex $lines [expr {$cy-1}]]
                    lset lines [expr {$cy-1}] "[string range $l 0 [expr {$cx-1}]]${key}[string range $l $cx end]"
                    incr cx [string length $key]; tui-mark-line-dirty
                }
            }
        }
        if {$rst}       { set sticky -1 }
        if {$clear_sel} { set sel_anchor ""; set sel_sticky 0 }
    }
}

proc tui-word-occurrences {fpath rows cols} {
    if {![file exists $fpath]} return

    set word_data [get-word-occurrences $fpath]
    if {[llength $word_data] == 0} return

    catch {
        set all_lines [list [list "  Word Occurrences" 1] [list "" 0] \
            [list [format "  %-30s %s" "Word" "Count"] 1]]
        foreach pair $word_data {
            lassign $pair word count
            lappend all_lines [list [format "  %-30s %6d" $word $count] 0]
        }

        set _usable [expr {$rows-4}]
        set _total [llength $all_lines]
        set _scroll 0
        set _w [expr {min(50, $cols-4)}]
        set _left [expr {max(0,($cols-$_w)/2)}]
        set _top  [expr {max(0,($rows-$_usable)/2)}]

        while 1 {
            if {$_scroll < 0} { set _scroll 0 }
            if {$_scroll >= $_total - $_usable} { set _scroll [expr {$_total - $_usable}] }

            puts -nonewline "\033\[2J"
            for {set _i 0} {$_i < $_usable} {incr _i} {
                set _idx [expr {$_scroll + $_i}]
                if {$_idx < $_total} {
                    tui-move [expr {$_top+$_i}] $_left
                    lassign [lindex $all_lines $_idx] _txt _inv
                    if {$_inv} { tui-attr reverse }
                    puts -nonewline "[string range $_txt 0 [expr {$_w-1}]]\033\[K"
                    if {$_inv} { tui-attr off }
                } else {
                    tui-move [expr {$_top+$_i}] $_left
                    puts -nonewline "\033\[K"
                }
            }
            tui-bar [expr {$rows-1}] "  UP/DOWN scroll  q close" "" $cols
            flush stdout

            set _k [tui-getch]
            switch -- $_k {
                q { break }
                UP - k { incr _scroll -1 }
                DOWN - j { incr _scroll 1 }
                HOME { set _scroll 0 }
                END { set _scroll [expr {$_total - $_usable}] }
                default {
                    if {$_k eq $::cfg_tui_help} { break }
                }
            }
        }
        puts -nonewline "\033\[2J"
    }
}

proc tui-timer-alert {} {
    lassign [tui-size] rows cols
    while 1 {
        puts -nonewline "\033\[2J"
        set lines {}
        set empty_lines [expr {($rows - 3) / 2}]
        for {set i 0} {$i < $empty_lines} {incr i} { lappend lines "" }
        lappend lines ""
        lappend lines [string repeat " " [expr {($cols - 16) / 2}]] "TIMER FINISHED!"
        lappend lines ""
        for {set i 0} {$i < $empty_lines} {incr i} { lappend lines "" }

        for {set _i 0} {$_i < [llength $lines]} {incr _i} {
            tui-move $_i 0
            puts -nonewline [string range [lindex $lines $_i] 0 [expr {$cols-1}]]
            puts -nonewline "\033\[K"
        }
        tui-bar [expr {$rows-1}] "Press any key to continue" "" $cols
        flush stdout

        set key [tui-getch]
        if {$key ne ""} break
    }
    puts -nonewline "\033\[2J"
}

proc tui-config-dialog {rows cols} {
    catch {
        set timer_dur $::cfg_timer_duration
        set timer_snd $::cfg_timer_sound
        set timer_alrt $::cfg_timer_alert
        set timer_typ $::cfg_timer_type
        set chrono_shw $::cfg_chrono_show
        set sel 0
        set max_fields 5

        while 1 {
            puts -nonewline "\033\[2J"

            set _lines {}
            lappend _lines "  Config - Timer / Stopwatch"
            lappend _lines ""
            lappend _lines "  Timer"
            set _dur_mark [expr {$sel == 0 ? ">" : " "}]
            lappend _lines "  $_dur_mark Duration: ${timer_dur}'00\""
            set _type_mark [expr {$sel == 1 ? ">" : " "}]
            lappend _lines "  $_type_mark Type: $timer_typ"
            set _snd_mark [expr {$sel == 2 ? ">" : " "}]
            set _snd_txt [expr {$timer_snd ? "on" : "off"}]
            lappend _lines "  $_snd_mark Sound at end: \[$_snd_txt\]"
            set _alrt_mark [expr {$sel == 3 ? ">" : " "}]
            set _alrt_txt [expr {$timer_alrt ? "on" : "off"}]
            lappend _lines "  $_alrt_mark Alert message: \[$_alrt_txt\]"
            lappend _lines ""
            lappend _lines "  Stopwatch"
            set _shw_mark [expr {$sel == 4 ? ">" : " "}]
            set _shw_txt [expr {$chrono_shw ? "yes" : "no"}]
            lappend _lines "  $_shw_mark Show in status bar: \[$_shw_txt\]"
            lappend _lines ""

            for {set _i 0} {$_i < [llength $_lines]} {incr _i} {
                tui-move $_i 0
                puts -nonewline [string range [lindex $_lines $_i] 0 [expr {$cols-1}]]
                puts -nonewline "\033\[K"
            }

            set hint "UP/DOWN nav  LEFT/RIGHT adjust/toggle  s:save  q:cancel"
            tui-bar [expr {$rows-1}] $hint "" $cols
            flush stdout

            set key [tui-getch]
            switch -- $key {
                UP - k { if {$sel > 0} { incr sel -1 } }
                DOWN - j { if {$sel < [expr {$max_fields-1}]} { incr sel 1 } }
                LEFT {
                    if {$sel == 0 && $timer_dur > 1} { incr timer_dur -1 }
                    if {$sel == 1} { set timer_typ [expr {$timer_typ eq "countdown" ? "stopwatch" : "countdown"}] }
                    if {$sel == 2} { set timer_snd [expr {!$timer_snd}] }
                    if {$sel == 3} { set timer_alrt [expr {!$timer_alrt}] }
                    if {$sel == 4} { set chrono_shw [expr {!$chrono_shw}] }
                }
                RIGHT {
                    if {$sel == 0 && $timer_dur < 120} { incr timer_dur }
                    if {$sel == 1} { set timer_typ [expr {$timer_typ eq "countdown" ? "stopwatch" : "countdown"}] }
                    if {$sel == 2} { set timer_snd [expr {!$timer_snd}] }
                    if {$sel == 3} { set timer_alrt [expr {!$timer_alrt}] }
                    if {$sel == 4} { set chrono_shw [expr {!$chrono_shw}] }
                }
                " " {
                    if {$sel == 1} { set timer_typ [expr {$timer_typ eq "countdown" ? "stopwatch" : "countdown"}] }
                    if {$sel == 2} { set timer_snd [expr {!$timer_snd}] }
                    if {$sel == 3} { set timer_alrt [expr {!$timer_alrt}] }
                    if {$sel == 4} { set chrono_shw [expr {!$chrono_shw}] }
                }
                s {
                    set ::cfg_timer_duration $timer_dur
                    set ::cfg_timer_type $timer_typ
                    set ::cfg_timer_sound $timer_snd
                    set ::cfg_timer_alert $timer_alrt
                    set ::cfg_chrono_show $chrono_shw
                    ini-save
                    break
                }
                q - "\x1B" { break }
            }
        }
        puts -nonewline "\033\[2J"
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
        }
        if {$::cfg_browser || $::argc == 0} {
            while 1 {
                set fp [tui-browser]
                if {$fp eq ""} break
                puts -nonewline "\033\[2J"; flush stdout
                if {$fp eq "__scratchpad__"} { tui-editor "" } else { tui-editor $fp }
            }
        }
    } err info]
    tui-cleanup
    if {$ok} { puts stderr $err }
}


# ===========================================================================
# main-cli.tcl
# ===========================================================================
# --- Development mode: auto-load modules if run directly from src/ ---
if {![info exists ::version]} {
    set srcdir [file dirname [info script]]
    foreach m {boot-cli state config common tui} {
        source [file join $srcdir $m.tcl]
    }
}

# --- CLI-only entry point (always TUI, never GUI) ---
tui-main
