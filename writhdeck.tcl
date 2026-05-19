#!/bin/sh
# sh/Tcl polyglot - backslash continues Tcl comment to next line, hiding shell bootstrap \
_w=$(stty -g 2>/dev/null); trap '[ -n "$_w" ] && stty "$_w" 2>/dev/null' EXIT INT TERM; tclsh "$0" "$@"; exit $?

# # # # # # # # # # # #
#
#     writhdeck.tcl 
#     
#  ~  Tcl/Tk 8.5+ (console/GUI) text editor for writerdecks ~
#
#     Usage: tclsh writhdeck.tcl [--no-gui] [filename]
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
    puts "Usage: writhdeck.tcl \[OPTIONS\] \[FILE\]

Options:
  --help, -h      Show this help and exit
  --gui           Force GUI (Tk) mode - skip display detection
  --no-gui        Force TUI (terminal) mode
  --tui, --ng     Aliases for --no-gui

Keyboard shortcuts (defaults - configurable in writhdeck.ini):
  ^S  Save              ^Z  Undo           ^Y  Redo
  ^Q  Close / Esc       ^F  Find           ^R  Find & Replace
  ^H  Help              ^G  Go to line     ^O  Open file
  ^A  Select all        ^K  Toggle sticky selection
  ^C  Copy              ^X  Cut            ^V  Paste
  ^L  Line numbers      ^D  Dark/light toggle
  ^Space  Next space    ^Shift+Space  Prev space
  F11  Table of contents
  Ctrl+= / Ctrl+-  Font size
  Alt+Enter  Fullscreen
  Shift+Arrows  Extend selection"
    exit 0
}

set ::no_gui    [expr {[lsearch -regexp $::argv {^(--no-gui|--tui|--ng|--cli)$}] >= 0}]
set ::force_gui [expr {!$::no_gui && [lsearch $::argv "--gui"] >= 0}]
foreach _f {--no-gui --tui --ng --cli --gui} { set ::argv [lsearch -all -inline -not $::argv $_f] }
unset _f
set ::argc [llength $::argv]
if {!$::no_gui} {
    if {$::tcl_platform(platform) eq "windows"} {
        if {[catch {package require Tk}]} { set ::no_gui 1 }
    } else {
        if {$::force_gui} {
            # --gui: skip display-socket heuristic, attempt Tk directly.
            # Tk itself will error if the display is truly unavailable.
            if {[catch {package require Tk} err]} {
                puts stderr "writhdeck: --gui: cannot load Tk: $err"; exit 1
            }
        } else {
            # On Unix/POSIX, guard against hanging on a stale DISPLAY/WAYLAND_DISPLAY.
            # Returns:  1 = socket confirmed (try Tk)
            #           0 = no display env var (native display like Haiku - try Tk, won't hang)
            #          -1 = env var(s) set but no socket found (stale, skip Tk to avoid hang)
            proc _display-socket-check {} {
                set has_var 0
                if {[info exists ::env(WAYLAND_DISPLAY)] && $::env(WAYLAND_DISPLAY) ne ""} {
                    set has_var 1
                    set dir [expr {[info exists ::env(XDG_RUNTIME_DIR)] ? $::env(XDG_RUNTIME_DIR) : ""}]
                    if {$dir ne "" && [file exists [file join $dir $::env(WAYLAND_DISPLAY)]]} { return 1 }
                }
                if {[info exists ::env(DISPLAY)] && $::env(DISPLAY) ne ""} {
                    set has_var 1
                    if {[regexp {^:(\d+)} $::env(DISPLAY) -> num]} {
                        if {[file exists "/tmp/.X11-unix/X$num"]} { return 1 }
                    }
                }
                return [expr {$has_var ? -1 : 0}]
            }
            set _dsc [_display-socket-check]
            if {$_dsc < 0 || [catch {package require Tk}]} {
                set ::no_gui 1
            }
            unset _dsc
            rename _display-socket-check {}
        }
    }
}

set ::HOME_DIR [expr {[info exists ::env(HOME)] ? $::env(HOME) : \
    ([info exists ::env(USERPROFILE)] ? $::env(USERPROFILE) : \
    [expr {![catch {file home} _h] ? $_h : [file normalize ~]}])}]

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
set ::cfg_bg2                "#1a1a1a"
set ::cfg_bg2_alt            "#fdf6e3"
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
set ::cfg_help_bar       "^S save   ^Q close   F10 workspace   ^H help"
set ::cfg_word_goal      500
# status bar zones - tokens: filename dirty sel ln col words chars goal clock help_bar space
set ::cfg_status_left   "workspace filename dirty sel ln col words chars"
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
set ::cfg_key_workspace    "F10"
set ::cfg_key_timer        "Alt-t"
set ::cfg_key_cmd_mode     "Escape"
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
# workspace state (WS1 = primary, WS2 = secondary toggled via cfg_key_workspace)
set ::ws_n           1
set ::ws_dual_mode   0
set ::ws1_filename   ""
set ::ws1_scratchpad 0
set ::ws1_dirty      0
set ::ws1_content    ""
set ::ws1_cursor     "1.0"
set ::ws1_file_mtime 0
set ::ws2_filename   ""
set ::ws2_scratchpad 1
set ::ws2_dirty      0
set ::ws2_content    ""
set ::ws2_cursor     "1.0"
set ::ws2_file_mtime 0
set ::split_ws2_mode 0

proc marker-val {v} { expr {$v eq "0" ? "" : $v} }

proc timer-alert {} {
    if {$::timer_alert_shown} return
    set ::timer_alert_shown 1
    if {!$::no_gui} {
        if {$::cfg_timer_sound} { catch { timer-alert-gui } }
    } else {
        if {$::cfg_timer_sound} { do-beep }
        if {$::cfg_timer_alert} { catch { tui-timer-alert } }
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
        color_bg2         ::cfg_bg2
        color_bg2_alt     ::cfg_bg2_alt
    } {
        if {[dict exists $d $key]} { set $var [dict get $d $key] }
    }
    if {![dict exists $d color_bg2]}     { set ::cfg_bg2     $::cfg_bg }
    if {![dict exists $d color_bg2_alt]} { set ::cfg_bg2_alt $::cfg_bg_alt }
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
                color_bg2            { set ::cfg_bg2               $v }
                color_bg2_alt        { set ::cfg_bg2_alt           $v }
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
                key_workspace    { set ::cfg_key_workspace    $v }
                key_timer        { set ::cfg_key_timer        $v }
                key_cmd_mode     { set ::cfg_key_cmd_mode     $v }
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
    puts $fh "key_workspace    = $::cfg_key_workspace"
    puts $fh "key_timer        = $::cfg_key_timer"
    puts $fh "key_dark_toggle  = $::cfg_key_dark_toggle"
    puts $fh "key_cmd_mode     = $::cfg_key_cmd_mode"
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
    puts $fh "# outer margin background (same as color_bg/color_bg_alt by default)"
    puts $fh "# color_bg2       = $::cfg_bg2"
    puts $fh "# color_bg2_alt   = $::cfg_bg2_alt"
    # write any extra schemes stored in memory (user-defined)
    foreach sname [dict keys $::cfg_schemes] {
        if {$sname eq "default"} continue
        puts $fh ""
        puts $fh "\[$sname\]"
        set d [dict get $::cfg_schemes $sname]
        foreach key {color_bg color_fg color_bg_bar color_fg_bar color_bg_sel
                     color_heading color_comment color_markup
                     color_bg_alt color_fg_alt color_bg_bar_alt color_fg_bar_alt
                     color_bg_sel_alt color_heading_alt color_comment_alt color_markup_alt
                     color_bg2 color_bg2_alt} {
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
    if {$k eq "escape"}        { return "ESC" }
    if {[regexp {^f(\d+)$} $k -> n]} { return "F$n" }
    return $key
}

# Return a short human-readable label for a Tk key name
proc key-label {key} {
    if {[regexp -nocase {^control-([a-z])$} $key -> l]} { return "^[string toupper $l]" }
    if {[string tolower $key] eq "control-space"}        { return "^SPC" }
    if {[string tolower $key] eq "control-shift-space"}  { return "^+SPC" }
    if {[string tolower $key] eq "escape"}               { return "ESC" }
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
    set ::cfg_tui_split_focus  [tk-key-to-tui $::cfg_key_split_focus]
    set ::cfg_tui_workspace    [tk-key-to-tui $::cfg_key_workspace]
    set ::cfg_tui_timer        [tk-key-to-tui $::cfg_key_timer]
    set ::cfg_tui_cmd_mode     [tk-key-to-tui $::cfg_key_cmd_mode]
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
    set ::cfg_lbl_workspace  [key-label $::cfg_key_workspace]
    set ::cfg_lbl_cmd_mode    [key-label $::cfg_key_cmd_mode]
    # migrate old help_bar default to include workspace shortcut
    if {$::cfg_help_bar eq "^S save   ^Q close   ^H help"} {
        set ::cfg_help_bar "^S save   ^Q close   $::cfg_lbl_workspace workspace   ^H help"
    }
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
                     $::cfg_bg_sel $::cfg_color_heading $::cfg_color_comment $::cfg_color_markup \
                     $::cfg_bg2]
    } else {
        return [list $::cfg_bg_alt $::cfg_fg_alt $::cfg_bg_bar_alt $::cfg_fg_bar_alt \
                     $::cfg_bg_sel_alt $::cfg_color_heading_alt $::cfg_color_comment_alt $::cfg_color_markup_alt \
                     $::cfg_bg2_alt]
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
# schemes (alt01 default everforest gruvbox nord retro solarized)
# ===========================================================================
# Alt01 - Dark red/bordeaux color scheme

dict set ::scheme_defs alt01 {
    color_bg       "#1a1214"
    color_fg       "#e8dcc8"
    color_bg_bar   "#241820"
    color_fg_bar   "#9e8878"
    color_bg_sel   "#521828"
    color_heading  "#e63060"
    color_comment  "#6e5858"
    color_markup   "#c24868"
    color_bg_alt   "#fffde9"
    color_fg_alt   "#363c42"
    color_bg_bar_alt "#eee8d5"
    color_fg_bar_alt "#93a1a1"
    color_bg_sel_alt "#f0e7c1"
    color_heading_alt "#c8064a"
    color_comment_alt "#aaaaaa"
    color_markup_alt "#7e1c3e"
    color_bg2         "#150f10"
    color_bg2_alt     "#fffde9"
}
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
    color_bg2         "#1a1a1a"
    color_bg2_alt     "#fdf6e3"
}
# Everforest color scheme - Sainnhepark
# https://github.com/sainnhepark/everforest

dict set ::scheme_defs everforest {
    color_bg       "#2b3339"
    color_fg       "#d3c6aa"
    color_bg_bar   "#1e2326"
    color_fg_bar   "#a7c080"
    color_bg_sel   "#3a464c"
    color_heading  "#a7c080"
    color_comment  "#7a8478"
    color_markup   "#7fbbb3"
    color_bg_alt   "#fdf6e3"
    color_fg_alt   "#5c6a72"
    color_bg_bar_alt "#efead4"
    color_fg_bar_alt "#8da101"
    color_bg_sel_alt "#e6e2cc"
    color_heading_alt "#8da101"
    color_comment_alt "#a6b0a0"
    color_markup_alt "#3a94c5"
    color_bg2         "#2b3339"
    color_bg2_alt     "#fdf6e3"
}
# Gruvbox color scheme - Morhetz
# https://github.com/morhetz/gruvbox

dict set ::scheme_defs gruvbox {
    color_bg       "#282828"
    color_fg       "#ebdbb2"
    color_bg_bar   "#1d2021"
    color_fg_bar   "#a89984"
    color_bg_sel   "#504945"
    color_heading  "#fabd2f"
    color_comment  "#928374"
    color_markup   "#83a598"
    color_bg_alt   "#fbf1c7"
    color_fg_alt   "#3c3836"
    color_bg_bar_alt "#ebdbb2"
    color_fg_bar_alt "#7c6f64"
    color_bg_sel_alt "#d5c4a1"
    color_heading_alt "#b57614"
    color_comment_alt "#a89984"
    color_markup_alt "#076678"
    color_bg2         "#282828"
    color_bg2_alt     "#fbf1c7"
}
# Nord color scheme - Arctic, north-bluish color palette
# https://www.nordtheme.com/

dict set ::scheme_defs nord {
    color_bg       "#2e3440"
    color_fg       "#d8dee9"
    color_bg_bar   "#3b4252"
    color_fg_bar   "#81a1c1"
    color_bg_sel   "#434c5e"
    color_heading  "#88c0d0"
    color_comment  "#4c566a"
    color_markup   "#8fbec0"
    color_bg_alt   "#eceff4"
    color_fg_alt   "#2e3440"
    color_bg_bar_alt "#e5e9f0"
    color_fg_bar_alt "#5e81ac"
    color_bg_sel_alt "#d8dee9"
    color_heading_alt "#5e81ac"
    color_comment_alt "#4c566a"
    color_markup_alt "#5e81ac"
    color_bg2         "#2e3440"
    color_bg2_alt     "#eceff4"
}
# Retro color scheme - phosphor green terminal (dark) / monochrome (light)
# Dark: classic green-on-black CRT terminal aesthetic
# Light: clean black on white

dict set ::scheme_defs retro {
    color_bg       "#0a0a0a"
    color_fg       "#33ff33"
    color_bg_bar   "#111111"
    color_fg_bar   "#22bb22"
    color_bg_sel   "#004400"
    color_heading  "#aaffaa"
    color_comment  "#1a661a"
    color_markup   "#00ffcc"
    color_bg_alt   "#ffffff"
    color_fg_alt   "#000000"
    color_bg_bar_alt "#e0e0e0"
    color_fg_bar_alt "#333333"
    color_bg_sel_alt "#d0d0d0"
    color_heading_alt "#000000"
    color_comment_alt "#999999"
    color_markup_alt  "#333333"
    color_bg2         "#0a0a0a"
    color_bg2_alt     "#ffffff"
}
# Solarized color scheme - Ethan Schoonover
# https://ethanschoonover.com/solarized/

dict set ::scheme_defs solarized {
    color_bg       "#002b36"
    color_fg       "#839496"
    color_bg_bar   "#073642"
    color_fg_bar   "#586e75"
    color_bg_sel   "#004555"
    color_heading  "#b58900"
    color_comment  "#586e75"
    color_markup   "#268bd2"
    color_bg_alt   "#fdf6e3"
    color_fg_alt   "#657b83"
    color_bg_bar_alt "#eee8d5"
    color_fg_bar_alt "#93a1a1"
    color_bg_sel_alt "#e6ddb9"
    color_heading_alt "#b58900"
    color_comment_alt "#93a1a1"
    color_markup_alt "#268bd2"
    color_bg2         "#002b36"
    color_bg2_alt     "#fdf6e3"
}

# ===========================================================================
# i18n (de en es fr ko no)
# ===========================================================================
dict set ::i18n en {
    toc_title          "Table of contents"
    toc_no_headings    "no headings found"
    toc_jump_bar       "Enter jump  esc/ctrl+q cancel"
    toc_headings       "%d heading%s"
    br_no_docs         "No documents yet. Press n to create one."
    br_help_gui        "h:help  n:new  t:scratchpad  f:fav  s:stats  b:backup  d:delete  r:rename  i:info  c:config  z:reload  %s:sections  q:quit"
    br_help_tui        "h:%s  n:new  t:scratchpad  f:fav  s:stats  b:backup  d:delete  r:rename  i:info  c:config  w:words  %s:sections  q:quit"
    br_backed_up       "backup %s -> %s  (%s)"
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
    help_k_workspace   "Second workspace (toggle WS1/WS2)"
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

dict set ::i18n de {
    toc_title          "Inhaltsverzeichnis"
    toc_no_headings    "keine Ueberschriften gefunden"
    toc_jump_bar       "Enter springen  esc/ctrl+q abbrechen"
    toc_headings       "%d Ueberschrift%s"
    br_no_docs         "Keine Dokumente. Druecke n, um ein Dokument zu erstellen."
    br_help_gui        "h:hilfe  n:neu  t:notizen  f:fav  s:statistiken  b:sicherung  d:loeschen  r:umbenennen  i:info  c:konfiguration  z:neuladen  %s:abschnitte  q:beenden"
    br_help_tui        "h:%s  n:neu  t:notizen  f:fav  s:statistiken  b:sicherung  d:loeschen  r:umbenennen  i:info  c:konfiguration  w:woerter  %s:abschnitte  q:beenden"
    br_backed_up       "sicherung %s -> %s  (%s)"
    br_favorites       "Favoriten"
    br_stats_title     "Schreibstatistiken"
    br_stats_no_data   "Noch keine Schreibstatistiken fuer diese Datei."
    br_stats_today     "Heute"
    br_stats_total     "Insgesamt"
    br_stats_clear     "Statistiken loeschen"
    br_stats_clear_confirm "Alle Schreibstatistiken fuer \"%s\" loeschen?"
    br_fav_added       "[+] zu Favoriten hinzugefuegt: %s"
    br_fav_removed     "[-] aus Favoriten entfernt: %s"
    br_exists          "'%s' existiert bereits"
    br_deleted         "'%s' geloescht"
    br_renamed         "umbenannt -> '%s'"
    br_delete          "\"%s\" loeschen?"
    br_files           "%d Datei%s"
    br_recent          "Zuletzt verwendet"
    ed_saved           "gespeichert"
    ed_watch_reload       "\"%s\" wurde extern geaendert. Neuladen?"
    ed_watch_reload_dirty "\"%s\" wurde extern geaendert und Sie haben nicht gespeicherte Aenderungen. Neuladen?"
    ed_save_before     "\"%s\" vor dem Schliessen speichern?"
    ed_save_before_tui "vor dem Schliessen speichern? (j/n/a=abbrechen)"
    help_date_time     "Datum & Zeit"
    help_cur_time      "Aktuelle Zeit: %-12s  Datum: %s"
    help_file_info     "Dateiinfo"
    help_sel_info      "Auswahlinfo"
    help_words_chars   "Woerter: %-8d  Zeichen: %d"
    help_shortcuts     "Writhdeck - Tastenkuerzel"
    help_close         "Beliebige Taste druecken zum Schliessen"
    help_k_save        "Speichern"
    help_k_undo        "Rueckgaengig"
    help_k_redo        "Wiederherstellen"
    help_k_close       "Schliessen / Esc"
    help_k_sel_all     "Alles auswaehlen"
    help_k_sticky      "Auswahl umschalten"
    help_k_copy        "Kopieren"
    help_k_find        "Suchen"
    help_k_cut         "Ausschneiden"
    help_k_replace     "Ersetzen"
    help_k_paste       "Einfuegen"
    help_k_goto        "Gehe zu Zeile"
    help_k_lnum        "Zeilennummern"
    help_k_open        "Oeffnen (Browser)"
    help_k_typewriter  "Schreibmaschinen-/Fokusmodus (umschalten)"
    help_k_ctrl_arrows "Strg+Auf/Ab  Absatz  |  Strg+Links/Rechts / Alt+BF  Wort"
    help_k_toc         "Inhaltsverzeichnis"
    help_k_help        "Diese Hilfe"
    help_shift_arrows  "Umschalt+Pfeile  Auswahl erweitern"
    help_k_split       "Geteilte Ansicht (umschalten)"
    help_k_split_focus "Geteilte Ansicht - Fokus wechseln"
    help_k_workspace   "Zweiter Arbeitsbereich (WS1/WS2 umschalten)"
    br_toc_title       "Browser-Abschnitte"
    br_toc_empty       "keine Abschnitte"
    br_toc_bar         "Auf/Ab nav  Enter springen  esc abbrechen"
    dlg_yes            "Ja"
    dlg_no             "Nein"
    dlg_cancel         "Abbrechen"
    goto_title         "Gehe zu Zeile"
    goto_prompt        "Zeile:"
    profile_config_title   "Konfiguration"
    profile_config_default_profile "Standardprofil:"
    profile_config_default_scheme  "Standardfarbschema:"
    profile_config_language        "Sprache:"
    profile_config_edit_profile "Profil bearbeiten:"
    profile_config_font    "Schriftart:"
    profile_config_size    "Schriftgroesse:"
    profile_config_margin_w "Randbreite:"
    profile_config_margin_h "Randhoehe:"
    profile_config_word_goal "Tägliches Ziel:"
    profile_config_dark_mode "Dunkler Modus:"
    profile_config_apply   "Anwenden"
    profile_config_cancel  "Abbrechen"
    br_key_help            "hilfe"
    br_key_new             "neu"
    br_key_scratchpad      "notizen"
    br_key_fav             "fav"
    br_key_stats           "statistiken"
    br_key_backup          "sicherung"
    br_key_delete          "loeschen"
    br_key_rename          "umbenennen"
    br_key_info            "info"
    br_key_words           "woerter"
    br_key_config          "konfiguration"
    br_key_reload          "neuladen"
    br_key_quit            "beenden"
    br_help_new_file       "Neue Datei"
    br_help_scratchpad     "Notizen (temporaer, keine Datei)"
    br_help_toggle_fav     "Favorit umschalten"
    br_help_writing_stats  "Schreibstatistiken"
    br_help_backup         "Sicherung (kopiert in backups/ mit Zeitstempel)"
    br_help_show_path      "Vollstaendigen Pfad anzeigen"
    br_help_word_occ       "Wortvorkommnisse"
    br_help_delete_file    "Loeschen"
    br_help_rename_file    "Umbenennen"
    br_help_font_settings  "Schrifteinstellungen nach Profil"
    br_help_reload         "Neuladen"
    br_help_browser_sections "Browser-Abschnitte"
    br_help_fullscreen_br  "Vollbild"
    br_help_open_file_br   "Datei oeffnen"
    br_help_help           "Hilfe"
    br_help_quit_app       "Beenden"
    br_key_sections        "abschnitte"
    help_writhdeck         "WRITHDECK"
    help_version           "Version"
    help_date_time_sect    "DATUM & UHRZEIT"
    help_current_time      "Aktuelle Uhrzeit"
    help_date              "Datum"
    help_editor_sect       "EDITOR"
    help_save_as           "Speichern unter"
    help_return_browser    "Zurück zum Browser"
    help_find_next         "Suchen (Eingabe: naechstes  Umschalt+Eingabe: vorheriges)"
    help_find_replace      "Suchen und ersetzen (Eingabe: eines ersetzen  Strg+Eingabe: alles)"
    help_para_word         "Absatz- / Wort-Navigation"
    help_toc_marker        "Inhaltsverzeichnis  (%s)"
    help_browser_sect      "BROWSER"
    help_open              "Oeffnen"
    help_double_click      "Eingabe / Doppelklick"
    help_key_open_text     "Oeffnen"
    help_k_fullscreen      "Vollbild"
    config_tab_profile     "Profil"
    config_tab_timer       "Timer"
    timer_section          "Einstellungen"
    timer_duration         "Dauer (min):"
    timer_sound            "Ton am Ende:"
    timer_alert            "Warnmeldung:"
    timer_type             "Typ:"
    timer_type_countdown   "Countdown"
    timer_type_stopwatch   "Stoppuhr"
    chrono_show            "In der Statusleiste anzeigen:"
}

dict set ::i18n es {
    toc_title          "Tabla de contenidos"
    toc_no_headings    "no se encontraron encabezados"
    toc_jump_bar       "Enter saltar  esc/ctrl+q cancelar"
    toc_headings       "%d encabezado%s"
    br_no_docs         "Sin documentos. Presiona n para crear uno."
    br_help_gui        "h:ayuda  n:nuevo  t:notas  f:fav  s:estadisticas  b:copia  d:eliminar  r:renombrar  i:info  c:configuracion  z:recargar  %s:secciones  q:salir"
    br_help_tui        "h:%s  n:nuevo  t:notas  f:fav  s:estadisticas  b:copia  d:eliminar  r:renombrar  i:info  c:configuracion  w:palabras  %s:secciones  q:salir"
    br_backed_up       "copia %s -> %s  (%s)"
    br_favorites       "Favoritos"
    br_stats_title     "Estadisticas de escritura"
    br_stats_no_data   "Sin estadisticas de escritura para este archivo."
    br_stats_today     "Hoy"
    br_stats_total     "Total"
    br_stats_clear     "Borrar estadisticas"
    br_stats_clear_confirm "Borrar todas las estadisticas de escritura para \"%s\"?"
    br_fav_added       "[+] anadido a favoritos: %s"
    br_fav_removed     "[-] eliminado de favoritos: %s"
    br_exists          "'%s' ya existe"
    br_deleted         "'%s' eliminado"
    br_renamed         "renombrado -> '%s'"
    br_delete          "Eliminar \"%s\"?"
    br_files           "%d archivo%s"
    br_recent          "Recientes"
    ed_saved           "guardado"
    ed_watch_reload       "\"%s\" fue modificado externamente. Recargar?"
    ed_watch_reload_dirty "\"%s\" fue modificado externamente y tiene cambios sin guardar. Recargar?"
    ed_save_before     "Guardar \"%s\" antes de cerrar?"
    ed_save_before_tui "guardar antes de cerrar? (s/n/c=cancelar)"
    help_date_time     "Fecha y hora"
    help_cur_time      "Hora actual: %-12s  Fecha: %s"
    help_file_info     "Info del archivo"
    help_sel_info      "Info de seleccion"
    help_words_chars   "Palabras: %-8d  Caracteres: %d"
    help_shortcuts     "Writhdeck - atajos de teclado"
    help_close         "Presiona cualquier tecla para cerrar"
    help_k_save        "Guardar"
    help_k_undo        "Deshacer"
    help_k_redo        "Rehacer"
    help_k_close       "Cerrar / Esc"
    help_k_sel_all     "Seleccionar todo"
    help_k_sticky      "Activar seleccion"
    help_k_copy        "Copiar"
    help_k_find        "Buscar"
    help_k_cut         "Cortar"
    help_k_replace     "Reemplazar"
    help_k_paste       "Pegar"
    help_k_goto        "Ir a linea"
    help_k_lnum        "Numeros de linea"
    help_k_open        "Abrir (navegador)"
    help_k_typewriter  "Modo maquina de escribir / enfoque (activar)"
    help_k_ctrl_arrows "Ctrl+Arriba/Abajo  Parrafo  |  Ctrl+Izq/Der / Alt+BF  Palabra"
    help_k_toc         "Tabla de contenidos"
    help_k_help        "Esta ayuda"
    help_shift_arrows  "Mayus+Flechas  Extender seleccion"
    help_k_split       "Vista dividida (activar)"
    help_k_split_focus "Vista dividida - cambiar enfoque"
    help_k_workspace   "Segundo espacio de trabajo (alternar ET1/ET2)"
    br_toc_title       "Secciones del navegador"
    br_toc_empty       "sin secciones"
    br_toc_bar         "Arriba/Abajo nav  Enter saltar  esc cancelar"
    dlg_yes            "Si"
    dlg_no             "No"
    dlg_cancel         "Cancelar"
    goto_title         "Ir a linea"
    goto_prompt        "Linea:"
    profile_config_title   "Configuracion"
    profile_config_default_profile "Perfil predeterminado:"
    profile_config_default_scheme  "Esquema de color predeterminado:"
    profile_config_language        "Idioma:"
    profile_config_edit_profile "Editar perfil:"
    profile_config_font    "Fuente:"
    profile_config_size    "Tamano de fuente:"
    profile_config_margin_w "Ancho de margen:"
    profile_config_margin_h "Alto de margen:"
    profile_config_word_goal "Objetivo diario:"
    profile_config_dark_mode "Modo oscuro:"
    profile_config_apply   "Aplicar"
    profile_config_cancel  "Cancelar"
    br_key_help            "ayuda"
    br_key_new             "nuevo"
    br_key_scratchpad      "notas"
    br_key_fav             "fav"
    br_key_stats           "estadisticas"
    br_key_backup          "copia"
    br_key_delete          "eliminar"
    br_key_rename          "renombrar"
    br_key_info            "info"
    br_key_words           "palabras"
    br_key_config          "configuracion"
    br_key_reload          "recargar"
    br_key_quit            "salir"
    br_help_new_file       "Nuevo archivo"
    br_help_scratchpad     "Notas (temporal, sin archivo)"
    br_help_toggle_fav     "Activar favorito"
    br_help_writing_stats  "Estadisticas de escritura"
    br_help_backup         "Copia (copia en backups/ con marca de tiempo)"
    br_help_show_path      "Mostrar ruta completa"
    br_help_word_occ       "Ocurrencias de palabras"
    br_help_delete_file    "Eliminar"
    br_help_rename_file    "Renombrar"
    br_help_font_settings  "Configuracion de fuente por perfil"
    br_help_reload         "Recargar"
    br_help_browser_sections "Secciones del navegador"
    br_help_fullscreen_br  "Pantalla completa"
    br_help_open_file_br   "Abrir archivo"
    br_help_help           "Ayuda"
    br_help_quit_app       "Salir"
    br_key_sections        "secciones"
    help_writhdeck         "WRITHDECK"
    help_version           "Version"
    help_date_time_sect    "FECHA Y HORA"
    help_current_time      "Hora actual"
    help_date              "Fecha"
    help_editor_sect       "EDITOR"
    help_save_as           "Guardar como"
    help_return_browser    "Volver al navegador"
    help_find_next         "Buscar (Intro: siguiente  Mayus+Intro: anterior)"
    help_find_replace      "Buscar y reemplazar (Intro: reemplazar uno  Ctrl+Intro: todo)"
    help_para_word         "Navegacion por parrafo / palabra"
    help_toc_marker        "Tabla de contenidos  (%s)"
    help_browser_sect      "NAVEGADOR"
    help_open              "Abrir"
    help_double_click      "Intro / Doble clic"
    help_key_open_text     "Abrir"
    help_k_fullscreen      "Pantalla completa"
    config_tab_profile     "Perfil"
    config_tab_timer       "Temporizador"
    timer_section          "Configuracion"
    timer_duration         "Duracion (min):"
    timer_sound            "Sonido al final:"
    timer_alert            "Mensaje de alerta:"
    timer_type             "Tipo:"
    timer_type_countdown   "cuenta atras"
    timer_type_stopwatch   "cronometro"
    chrono_show            "Mostrar en la barra de estado:"
}

dict set ::i18n fr {
    toc_title          "Table des matières"
    toc_no_headings    "aucun titre trouvé"
    toc_jump_bar       "Enter aller  esc/ctrl+q annuler"
    toc_headings       "%d titre%s"
    br_no_docs         "Aucun document. Appuyez sur n pour en créer un."
    br_help_gui        "h:aide  n:nouveau  t:bloc-notes  f:fav  s:stats  b:backup  d:supprimer  r:renommer  i:infos  c:config  z:recharger  %s:sections  q:quitter"
    br_help_tui        "h:%s  n:nouveau  t:bloc-notes  f:fav  s:stats  b:backup  d:supprimer  r:renommer  i:infos  c:config  w:mots  %s:sections  q:quitter"
    br_backed_up       "sauvegarde %s -> %s  (%s)"
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
    help_k_workspace   "Second espace de travail (bascule ES1/ES2)"
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

dict set ::i18n ko {
    toc_title          "목차"
    toc_no_headings    "제목을 찾을 수 없음"
    toc_jump_bar       "이동 입력  esc/ctrl+q 취소"
    toc_headings       "%d개의 제목%s"
    br_no_docs         "문서가 없습니다. n을 눌러서 새 문서를 만드세요."
    br_help_gui        "h:도움말  n:새로운  t:메모장  f:즐겨찾기  s:통계  b:백업  d:삭제  r:이름변경  i:정보  c:설정  z:다시로드  %s:섹션  q:종료"
    br_help_tui        "h:%s  n:새로운  t:메모장  f:즐겨찾기  s:통계  b:백업  d:삭제  r:이름변경  i:정보  c:설정  w:단어  %s:섹션  q:종료"
    br_backed_up       "백업 %s -> %s  (%s)"
    br_favorites       "즐겨찾기"
    br_stats_title     "작문 통계"
    br_stats_no_data   "이 파일에 대한 작문 통계가 없습니다."
    br_stats_today     "오늘"
    br_stats_total     "합계"
    br_stats_clear     "통계 지우기"
    br_stats_clear_confirm "\"%s\"의 모든 작문 통계를 지우시겠습니까?"
    br_fav_added       "[+] 즐겨찾기에 추가됨: %s"
    br_fav_removed     "[-] 즐겨찾기에서 제거됨: %s"
    br_exists          "'%s'는 이미 존재합니다"
    br_deleted         "삭제됨 '%s'"
    br_renamed         "이름 변경 -> '%s'"
    br_delete          "\"%s\"를 삭제하시겠습니까?"
    br_files           "%d개 파일%s"
    br_recent          "최근"
    ed_saved           "저장됨"
    ed_watch_reload       "\"%s\"가 외부에서 수정되었습니다. 다시 로드하시겠습니까?"
    ed_watch_reload_dirty "\"%s\"가 외부에서 수정되었으며 저장하지 않은 변경 사항이 있습니다. 다시 로드하시겠습니까?"
    ed_save_before     "종료하기 전에 \"%s\"를 저장하시겠습니까?"
    ed_save_before_tui "종료하기 전에 저장하시겠습니까? (y/n/c=취소)"
    help_date_time     "날짜 및 시간"
    help_cur_time      "현재 시간:  %-12s  날짜: %s"
    help_file_info     "파일 정보"
    help_sel_info      "선택 정보"
    help_words_chars   "단어: %-8d  문자: %d"
    help_shortcuts     "Writhdeck - 키보드 바로가기"
    help_close         "아무 키나 눌러서 닫기"
    help_k_save        "저장"
    help_k_undo        "실행 취소"
    help_k_redo        "다시 실행"
    help_k_close       "닫기 / Esc"
    help_k_sel_all     "모두 선택"
    help_k_sticky      "선택 토글"
    help_k_copy        "복사"
    help_k_find        "찾기"
    help_k_cut         "잘라내기"
    help_k_replace     "바꾸기"
    help_k_paste       "붙여넣기"
    help_k_goto        "줄로 이동"
    help_k_lnum        "줄 번호"
    help_k_open        "열기 (브라우저)"
    help_k_typewriter  "타이프라이터 / 포커스 모드 (토글)"
    help_k_ctrl_arrows "Ctrl+위/아래  단락  |  Ctrl+좌/우 / Alt+좌/우  단어"
    help_k_toc         "목차"
    help_k_help        "이 도움말"
    help_shift_arrows  "Shift+화살표  선택 확장"
    help_k_split       "분할 보기 (토글)"
    help_k_split_focus "분할 보기 - 포커스 순환"
    help_k_workspace   "두 번째 작업공간 (WS1/WS2 전환)"
    br_toc_title       "브라우저 섹션"
    br_toc_empty       "섹션 없음"
    br_toc_bar         "위/아래 이동  Enter 이동  esc 취소"
    dlg_yes            "예"
    dlg_no             "아니오"
    dlg_cancel         "취소"
    goto_title         "줄로 이동"
    goto_prompt        "줄:"
    profile_config_title   "설정"
    profile_config_default_profile "기본 프로필:"
    profile_config_default_scheme  "기본 색상 체계:"
    profile_config_language        "언어:"
    profile_config_edit_profile "프로필 편집:"
    profile_config_font    "글꼴 가족:"
    profile_config_size    "글꼴 크기:"
    profile_config_margin_w "여백 너비:"
    profile_config_margin_h "여백 높이:"
    profile_config_word_goal "일일 목표:"
    profile_config_dark_mode "어두운 모드:"
    profile_config_apply   "적용"
    profile_config_cancel  "취소"
    br_key_help            "도움말"
    br_key_new             "새로운"
    br_key_scratchpad      "메모장"
    br_key_fav             "즐겨찾기"
    br_key_stats           "통계"
    br_key_backup          "백업"
    br_key_delete          "삭제"
    br_key_rename          "이름변경"
    br_key_info            "정보"
    br_key_words           "단어"
    br_key_config          "설정"
    br_key_reload          "다시로드"
    br_key_quit            "종료"
    br_help_new_file       "새 파일"
    br_help_scratchpad     "메모장 (임시, 디스크 파일 없음)"
    br_help_toggle_fav     "즐겨찾기 토글"
    br_help_writing_stats  "작문 통계"
    br_help_backup         "백업 (타임스탬프가 있는 backups/에 복사)"
    br_help_show_path      "전체 경로 표시"
    br_help_word_occ       "단어 발생"
    br_help_delete_file    "삭제"
    br_help_rename_file    "이름 변경"
    br_help_font_settings  "프로필별 글꼴 설정"
    br_help_reload         "다시 로드"
    br_help_browser_sections "브라우저 섹션"
    br_help_fullscreen_br  "전체 화면"
    br_help_open_file_br   "파일 열기"
    br_help_help           "도움말"
    br_help_quit_app       "종료"
    br_key_sections        "섹션"
    help_writhdeck         "WRITHDECK"
    help_version           "버전"
    help_date_time_sect    "날짜 및 시간"
    help_current_time      "현재 시간"
    help_date              "날짜"
    help_editor_sect       "편집기"
    help_save_as           "다른 이름으로 저장"
    help_return_browser    "브라우저로 돌아가기"
    help_find_next         "찾기 (Enter: 다음  Shift+Enter: 이전)"
    help_find_replace      "찾기 및 바꾸기 (Enter: 하나 바꾸기  Ctrl+Enter: 모두)"
    help_para_word         "단락 / 단어 탐색"
    help_toc_marker        "목차  (%s)"
    help_browser_sect      "브라우저"
    help_open              "열기"
    help_double_click      "Enter / 더블 클릭"
    help_key_open_text     "열기"
    help_k_fullscreen      "전체 화면"
    config_tab_profile     "프로필"
    config_tab_timer       "타이머"
    timer_section          "설정"
    timer_duration         "기간 (분):"
    timer_sound            "종료 시 소리:"
    timer_alert            "경고 메시지:"
    timer_type             "유형:"
    timer_type_countdown   "카운트다운"
    timer_type_stopwatch   "스톱워치"
    chrono_show            "상태 표시줄에 표시:"
}

dict set ::i18n no {
    toc_title          "Innholdsfortegnelse"
    toc_no_headings    "ingen overskrifter funnet"
    toc_jump_bar       "Skriv inn hopp  esc/ctrl+q avbryt"
    toc_headings       "%d overskrift%s"
    br_no_docs         "Ingen dokumenter ennå. Trykk n for å lage en ny."
    br_help_gui        "h:hjelp  n:ny  t:notisbok  f:favoritt  s:statistikk  b:sikkerhetskopi  d:slett  r:gi nytt navn  i:info  c:innstillinger  z:last på nytt  %s:avsnitt  q:avslutt"
    br_help_tui        "h:%s  n:ny  t:notisbok  f:favoritt  s:statistikk  b:sikkerhetskopi  d:slett  r:gi nytt navn  i:info  c:innstillinger  w:ord  %s:avsnitt  q:avslutt"
    br_backed_up       "sikkerhetskopi %s -> %s  (%s)"
    br_favorites       "Favoritter"
    br_stats_title     "Skrivstatistikk"
    br_stats_no_data   "Ingen skrivstatistikk ennå for denne filen."
    br_stats_today     "I dag"
    br_stats_total     "Totalt"
    br_stats_clear     "Slett statistikk"
    br_stats_clear_confirm "Slette all skrivstatistikk for \"%s\"?"
    br_fav_added       "[+] lagt til favoritter: %s"
    br_fav_removed     "[-] fjernet fra favoritter: %s"
    br_exists          "'%s' eksisterer allerede"
    br_deleted         "slettet '%s'"
    br_renamed         "gitt nytt navn -> '%s'"
    br_delete          "Slette \"%s\"?"
    br_files           "%d fil%s"
    br_recent          "Nylige"
    ed_saved           "lagret"
    ed_watch_reload       "\"%s\" ble endret eksternt. Last på nytt?"
    ed_watch_reload_dirty "\"%s\" ble endret eksternt og du har ulagrede endringer. Last på nytt?"
    ed_save_before     "Lagre \"%s\" før lukking?"
    ed_save_before_tui "lagre før lukking? (y/n/c=avbryt)"
    help_date_time     "Dato og tid"
    help_cur_time      "Gjeldende tid:  %-12s  Dato: %s"
    help_file_info     "Filinfo"
    help_sel_info      "Valginformasjon"
    help_words_chars   "Ord: %-8d  Tegn: %d"
    help_shortcuts     "Writhdeck - tastatursnarveier"
    help_close         "Trykk en tast for å lukke"
    help_k_save        "Lagre"
    help_k_undo        "Angre"
    help_k_redo        "Gjør igjen"
    help_k_close       "Lukk / Esc"
    help_k_sel_all     "Velg alt"
    help_k_sticky      "Veksle valg"
    help_k_copy        "Kopier"
    help_k_find        "Finn"
    help_k_cut         "Klipp ut"
    help_k_replace     "Erstatt"
    help_k_paste       "Lim inn"
    help_k_goto        "Gå til linje"
    help_k_lnum        "Linjenumre"
    help_k_open        "Åpne (nettleser)"
    help_k_typewriter  "Skrivemaskintilstand / fokusmodus (veksle)"
    help_k_ctrl_arrows "Ctrl+Opp/Ned  Avsnitt  |  Ctrl+Venstre/Høyre / Alt+Bak/Frem  Ord"
    help_k_toc         "Innholdsfortegnelse"
    help_k_help        "Denne hjelpen"
    help_shift_arrows  "Shift+Piler  Utvid valg"
    help_k_split       "Delvis visning (veksle)"
    help_k_split_focus "Delvis visning - syklus fokus"
    help_k_workspace   "Andre arbeidsomrade (veksle ES1/ES2)"
    br_toc_title       "Nettleseravsnitt"
    br_toc_empty       "ingen avsnitt"
    br_toc_bar         "Opp/Ned navigering  Enter hopp  esc avbryt"
    dlg_yes            "Ja"
    dlg_no             "Nei"
    dlg_cancel         "Avbryt"
    goto_title         "Gå til linje"
    goto_prompt        "Linje:"
    profile_config_title   "Innstillinger"
    profile_config_default_profile "Standardprofil:"
    profile_config_default_scheme  "Standardfargeplan:"
    profile_config_language        "Språk:"
    profile_config_edit_profile "Rediger profil:"
    profile_config_font    "Skrifttype:"
    profile_config_size    "Skriftstørrelse:"
    profile_config_margin_w "Marginebredde:"
    profile_config_margin_h "Marginehøyde:"
    profile_config_word_goal "Daglig mål:"
    profile_config_dark_mode "Mørk modus:"
    profile_config_apply   "Bruk"
    profile_config_cancel  "Avbryt"
    br_key_help            "hjelp"
    br_key_new             "ny"
    br_key_scratchpad      "notisbok"
    br_key_fav             "favoritt"
    br_key_stats           "statistikk"
    br_key_backup          "sikkerhetskopi"
    br_key_delete          "slett"
    br_key_rename          "gi nytt navn"
    br_key_info            "info"
    br_key_words           "ord"
    br_key_config          "innstillinger"
    br_key_reload          "last på nytt"
    br_key_quit            "avslutt"
    br_help_new_file       "Ny fil"
    br_help_scratchpad     "Notisbok (midlertidig, ingen diskfil)"
    br_help_toggle_fav     "Veksle favoritt"
    br_help_writing_stats  "Skrivstatistikk"
    br_help_backup         "Sikkerhetskopi (kopier til sikkerhetskopi/ med tidsstempel)"
    br_help_show_path      "Vis fullstendig sti"
    br_help_word_occ       "Ordforkomster"
    br_help_delete_file    "Slett"
    br_help_rename_file    "Gi nytt navn"
    br_help_font_settings  "Skriftinnstillinger etter profil"
    br_help_reload         "Last på nytt"
    br_help_browser_sections "Nettleseravsnitt"
    br_help_fullscreen_br  "Fullskjerm"
    br_help_open_file_br   "Åpne fil"
    br_help_help           "Hjelp"
    br_help_quit_app       "Avslutt"
    br_key_sections        "avsnitt"
    help_writhdeck         "WRITHDECK"
    help_version           "Versjon"
    help_date_time_sect    "DATO OG TID"
    help_current_time      "Gjeldende tid"
    help_date              "Dato"
    help_editor_sect       "EDITOR"
    help_save_as           "Lagre som"
    help_return_browser    "Tilbake til nettleser"
    help_find_next         "Finn (Enter: neste  Shift+Enter: forrige)"
    help_find_replace      "Finn og erstatt (Enter: erstatt en  Ctrl+Enter: alt)"
    help_para_word         "Avsnitt- / ordnavigering"
    help_toc_marker        "Innholdsfortegnelse  (%s)"
    help_browser_sect      "NETTLESER"
    help_open              "Apne"
    help_double_click      "Enter / Dobbeltklipp"
    help_key_open_text     "Apne"
    help_k_fullscreen      "Fullskjerm"
    config_tab_profile     "Profil"
    config_tab_timer       "Timer"
    timer_section          "Innstillinger"
    timer_duration         "Varighet (min):"
    timer_sound            "Lyd ved slutt:"
    timer_alert            "Advarselmelding:"
    timer_type             "Type:"
    timer_type_countdown   "nedtelling"
    timer_type_stopwatch   "stoppeklokke"
    chrono_show            "Vis i statuslinje:"
}


# ===========================================================================
# common.tcl
# ===========================================================================
# --- initialization (run after schemes and i18n are loaded) -----------
schemes-init
ini-load
keys-init

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
lassign [theme-colors] bg fg bg_bar fg_bar bg_sel _ _ _ bg2
set fg_dim  "#676767"
# expose as globals for use in procs
set ::bg     $bg
set ::fg     $fg
set ::bg_bar $bg_bar
set ::fg_bar $fg_bar
set ::bg_sel $bg_sel
set ::bg2    $bg2

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
            workspace { if {$::ws_dual_mode} {
                set _wsn [expr {[dict exists $state ws] ? [dict get $state ws] : $::ws_n}]
                append result "\[$_wsn\] "
            } }
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

proc do-beep {} {
    catch {
        exec sh -c {ffplay -f lavfi -i "sine=frequency=440:duration=0.3" -nodisp -autoexit -loglevel quiet 2>/dev/null; sleep 0.4; ffplay -f lavfi -i "sine=frequency=440:duration=0.3" -nodisp -autoexit -loglevel quiet 2>/dev/null} &
    }
}

proc do-backup {dir name} {
    set bdir [file join $::DOCS_DIR backups]
    file mkdir $bdir
    set ts  [clock format [clock seconds] -format "%Y-%m-%dT%Hh%Mm%S"]
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
        set fh [open $fpath r]; chan configure $fh -encoding utf-8
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
# gui.tcl
# ===========================================================================
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
        if {$::ws_n == 1} {
            set fn [expr {$::ws2_scratchpad ? "** scratchpad **" : \
                         ($::ws2_filename eq "" ? "\[new\]" : [file tail $::ws2_filename])}]
            set _r_dirty $::ws2_dirty
        } else {
            set fn [expr {$::ws1_scratchpad ? "** scratchpad **" : \
                         ($::ws1_filename eq "" ? "\[new\]" : [file tail $::ws1_filename])}]
            set _r_dirty $::ws1_dirty
        }
        lassign [split [$t index insert] .] ln col
        set total [expr {[lindex [split [$t index end] .] 0] - 1}]
        set _r_ws [expr {$::ws_n == 1 ? 2 : 1}]
        return [dict create fn $fn dirty $_r_dirty sel 0 ln $ln total $total \
                    col [expr {$col+1}] words $::gui_wc chars $::gui_cc \
                    clock $clk timer $timer_display ws $_r_ws]
    }
    set fn [expr {$::scratchpad ? "** scratchpad **" : \
                 ($::filename eq "" ? "\[new\]" : [file tail $::filename])}]
    lassign [split [$t index insert] .] ln col
    set total [expr {[lindex [split [$t index end] .] 0] - 1}]
    return [dict create fn $fn dirty $::dirty sel 0 ln $ln total $total \
                col [expr {$col+1}] words $::gui_wc chars $::gui_cc \
                clock $clk timer $timer_display ws $::ws_n]
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
    if {$::split_ws2_mode && [focus] eq ".ed.pw.r.t"} {
        set eff_ws [expr {$::ws_n == 1 ? 2 : 1}]
        if {$::ws_n == 1} { set eff_sp $::ws2_scratchpad; set eff_fn $::ws2_filename
        } else             { set eff_sp $::ws1_scratchpad; set eff_fn $::ws1_filename }
        set ws " \[$eff_ws\]"
        if {$eff_sp} {
            wm title . "Writhdeck - ** scratchpad **$ws"
        } elseif {$eff_fn ne ""} {
            wm title . "Writhdeck - [file tail $eff_fn]$ws"
        } else {
            wm title . "Writhdeck$ws"
        }
        return
    }
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
    set t [active-ed]
    set result {}
    if {$t eq ".ed.pw.r.t"} {
        # WS2 right pane — independent widget, no cache, scan directly
        set last [lindex [split [$t index end] .] 0]
        for {set ln 1} {$ln < $last} {incr ln} {
            set line [$t get $ln.0 "$ln.0 lineend"]
            set hl [heading-level $line]
            if {$hl ne ""} { lassign $hl title level; lappend result [list $ln $title $level] }
        }
    } elseif {$::hl_line_cache ne {}} {
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
    if {$::split_ws2_mode && $::toc_ed eq ".ed.pw.r.t"} {
        set ::toc_fn [expr {$::ws_n == 1 ? $::ws2_filename : $::ws1_filename}]
    } else {
        set ::toc_fn $::filename
    }
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
    if {[dict exists $::session_headings $::toc_fn]} {
        set presel [dict get $::session_headings $::toc_fn]
        if {$presel >= [llength $headings]} { set presel 0 }
    } else {
        set curline [lindex [split [$::toc_ed index insert] .] 0]
        set idx 0
        foreach item $headings {
            if {[lindex $item 0] <= $curline} { set presel $idx }
            incr idx
        }
    }
    set lnw [string length [expr {[lindex [split [$::toc_ed index end] .] 0] - 1}]]
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
    dict set ::session_headings $::toc_fn $selIdx
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
    if {$::ws_dual_mode} { split-ws2-open; focus .ed.pw.l.t }
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
    if {$::split_ws2_mode} { ed-update-title }
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
    if {$::ws_n == 1} {
        set _r_content $::ws2_content;  set _r_dirty $::ws2_dirty;  set _r_cursor $::ws2_cursor
    } else {
        set _r_content $::ws1_content;  set _r_dirty $::ws1_dirty;  set _r_cursor $::ws1_cursor
    }
    .ed.pw.r.t configure -undo 0
    .ed.pw.r.t delete 1.0 end
    if {$_r_content ne ""} { .ed.pw.r.t insert 1.0 $_r_content }
    .ed.pw.r.t edit reset
    .ed.pw.r.t edit modified false
    .ed.pw.r.t configure -undo 1
    if {$_r_dirty} { .ed.pw.r.t edit modified true }
    catch { .ed.pw.r.t mark set insert $_r_cursor }
    .ed.pw.r.t see insert
    bind .ed.pw.l.t <FocusIn>               { if {$::split_ws2_mode} { ed-update-title } }
    bind .ed.pw.r.t <<Modified>>             { split-ws2-track-dirty }
    bind .ed.pw.r.t <FocusIn>               { ed-update-title }
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
    bind .ed.pw.r.t <$::cfg_key_replace>     { replace-open; break }
    bind .ed.pw.r.t <$::cfg_key_open>        { open-file-dialog; break }
    bind .ed.pw.r.t <$::cfg_key_toc>         { toc-show; break }
    bind .ed.pw.r.t <$::cfg_key_line_numbers> { ln-toggle; break }
    bind .ed.pw.r.t <$::cfg_key_fullscreen>  { toggle-fullscreen; break }
    bind .ed.pw.r.t <$::cfg_key_typewriter>  { typewriter-toggle; break }
    bind .ed.pw.r.t <KeyRelease>            +[list typewriter-tick .ed.pw.r.t]
    bind .ed.pw.r.t <ButtonRelease>         +[list typewriter-tick .ed.pw.r.t]
    foreach _k {Left Right Up Down BackSpace Delete} {
        bind .ed.pw.r.t <$_k> "if {\$::typewriter_mode && \$::cfg_hemingway_mode} break"
    }
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
    if {[.ed.pw.r.t edit modified]} {
        if {$::ws_n == 1} { set ::ws2_dirty 1 } else { set ::ws1_dirty 1 }
        .ed.pw.r.t edit modified false
    }
    ed-status
}

proc split-ws2-save {} {
    set fn [expr {$::ws_n == 1 ? $::ws2_filename : $::ws1_filename}]
    if {$fn eq ""} { split-ws2-save-as; return }
    set fh [open $fn w]; chan configure $fh -encoding utf-8
    puts -nonewline $fh [.ed.pw.r.t get 1.0 {end - 1 chars}]; close $fh
    if {$::ws_n == 1} {
        set ::ws2_dirty 0; set ::ws2_file_mtime [file mtime $fn]
    } else {
        set ::ws1_dirty 0; set ::ws1_file_mtime [file mtime $fn]
    }
    .ed.pw.r.t edit modified false
    ed-status
}

proc split-ws2-save-as {} {
    set cur_fn [expr {$::ws_n == 1 ? $::ws2_filename : $::ws1_filename}]
    set dir [expr {$cur_fn ne "" ? [file dirname $cur_fn] : $::DOCS_DIR_DEFAULT}]
    set name [string trim [input-dialog "Save as" "Save as:"]]
    if {$name eq ""} return
    if {[file extension $name] eq ""} { append name $::FILE_EXT }
    set new_path [file join $dir $name]
    if {[file exists $new_path] && $new_path ne $cur_fn} {
        if {[confirm-dialog "\"$name\" already exists. Overwrite?"] ne "yes"} return
    }
    if {$::ws_n == 1} { set ::ws2_filename $new_path; set ::ws2_scratchpad 0
    } else              { set ::ws1_filename $new_path; set ::ws1_scratchpad 0 }
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
    if {$::ws_n == 1} {
        set ::ws2_filename $path; set ::ws2_scratchpad 0; set ::ws2_dirty 0
        set ::ws2_file_mtime [expr {[file exists $path] ? [file mtime $path] : 0}]
    } else {
        set ::ws1_filename $path; set ::ws1_scratchpad 0; set ::ws1_dirty 0
        set ::ws1_file_mtime [expr {[file exists $path] ? [file mtime $path] : 0}]
    }
    recent-push $path
    .ed.pw.r.t mark set insert 1.0; .ed.pw.r.t see insert
    ed-status
}

proc split-ws2-save-state {} {
    if {![winfo exists .ed.pw.r.t]} return
    if {$::ws_n == 1} {
        set ::ws2_content [.ed.pw.r.t get 1.0 end-1c]
        set ::ws2_cursor  [.ed.pw.r.t index insert]
    } else {
        set ::ws1_content [.ed.pw.r.t get 1.0 end-1c]
        set ::ws1_cursor  [.ed.pw.r.t index insert]
    }
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
        [list [format "  %-16s %s" $::cfg_lbl_workspace [t help_k_workspace]] 0] \
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

    puts -nonewline "\033\[2J\033\[H"; flush stdout

    while 1 {
        set max_scroll [expr {max(0, $h - $usable)}]
        puts -nonewline "\033\[H"
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
}

proc tui-getch {{timeout -1}} {
    set _block 0
    if {$timeout < 0} {
        if {$::timer_active && $::cfg_chrono_show} {
            set timeout 50
        } else {
            set _block 1
            set timeout 0
        }
    }
    chan configure stdin -blocking 0
    set raw [read stdin 1]
    chan configure stdin -blocking 1
    if {$raw eq ""} {
        if {$timeout > 0} {
            after $timeout
            chan configure stdin -blocking 0
            set raw [read stdin 1]
            chan configure stdin -blocking 1
        } elseif {$_block} {
            set raw [read stdin 1]
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
            q - "\x11" {
                lassign [tui-size] rows cols
                if {[tui-ws-check-inactive-dirty $rows $cols]} { return "" }
            }
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
                    tui-info-dialog [file join $dir $name] $rows $cols
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
                    set _r [tui-stats-dialog $_path $rows $cols]
                    if {$_r ne ""} { set msg $_r }
                }
            }
            b {
                if {$cfi >= 0} {
                    lassign [lindex $entries $cfi] _ dir name
                    set dst [do-backup $dir $name]
                    set msg [t br_backed_up $name [string map [list $::HOME_DIR ~] [file dirname $dst]] [file tail $dst]]
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

proc tui-editor {filepath {init_state {}}} {
    # -- load ------------------------------------------------------------------
    set lines {}
    if {[dict size $init_state] > 0} {
        set lines [dict get $init_state lines]
        set cy    [dict get $init_state cy]
        set cx    [dict get $init_state cx]
        set dirty [dict get $init_state dirty]
    } else {
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
        set dirty 0
    }

    # -- cursor restore --------------------------------------------------------
    if {[dict size $init_state] == 0} {
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
    }
    set cy [expr {max(1, min($cy, [llength $lines]))}]
    set cx [expr {max(0, min($cx, [string length [lindex $lines [expr {$cy-1}]]]))}]

    set scroll_y 0
    set toc_jumped 0
    if {[dict size $init_state] == 0} { set dirty 0 }
    set message ""; set msg_time 0; set sticky -1
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
    set split 0; set split_ws2_mode 0; set split_focus 1
    set split_r_lines [list ""]; set split_r_cy 1; set split_r_cx 0
    set split_r_scroll 0; set split_r_dirty 0; set split_r_fp ""
    set split_r_vrows {}; set split_r_ish {}; set split_r_isd {}
    set split_r_layout {}; set split_r_prev_tw -1; set split_r_wrap_dirty 1

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
        if {$split} {
            set half  [expr {($cols - 1) / 2}]
            set tw    [expr {max(1, $half - $coff - $marg)}]
            set rcoff [expr {$half + 1 + $marg}]
            set tw_r  [expr {max(1, $cols - $rcoff - $marg)}]
        }

        set cy [expr {max(1, min($cy, [llength $lines]))}]
        set cx [expr {max(0, min($cx, [string length [lindex $lines [expr {$cy-1}]]]))}]

        if {$wrap_dirty || $tw != $prev_tw} {
            lassign [tui-build-layout $lines $tw layout_cache] vrows ish_cache isd_cache
            set prev_tw $tw; set wrap_dirty 0; set dirty_line -1
            if {$split && !$split_ws2_mode} { set split_r_wrap_dirty 1 }
        } elseif {$dirty_line > 0} {
            if {![tui-patch-vrows $dirty_line]} {
                lassign [tui-build-layout $lines $tw layout_cache] vrows ish_cache isd_cache
                set dirty_line -1
                if {$split && !$split_ws2_mode} { set split_r_wrap_dirty 1 }
            }
        }
        if {$split && ($split_r_wrap_dirty || $tw_r != $split_r_prev_tw)} {
            set _rsrc [expr {$split_ws2_mode ? $split_r_lines : $lines}]
            lassign [tui-build-layout $_rsrc $tw_r split_r_layout] \
                split_r_vrows split_r_ish split_r_isd
            set split_r_prev_tw $tw_r; set split_r_wrap_dirty 0
        }
        lassign [tui-l2v $vrows $cy $cx] vi scx
        set split_r_vi 0; set split_r_scx 0
        if {$split} { lassign [tui-l2v $split_r_vrows $split_r_cy $split_r_cx] split_r_vi split_r_scx }

        set _cth [expr {$split ? $th - 1 : $th}]
        if {$toc_jumped} { set scroll_y $vi; set toc_jumped 0 } elseif {$::typewriter_mode} {
            set scroll_y [expr {$vi - $_cth/2}]
        } else {
            if {$vi < $scroll_y}          { set scroll_y $vi }
            if {$vi >= $scroll_y + $_cth} { set scroll_y [expr {$vi - $_cth + 1}] }
        }
        set scroll_y [expr {max(0, min($scroll_y, max(0, [llength $vrows] - $_cth)))}]
        if {$split} {
            set _rv [lindex [tui-l2v $split_r_vrows $split_r_cy $split_r_cx] 0]
            if {$_rv < $split_r_scroll}              { set split_r_scroll $_rv }
            if {$_rv >= $split_r_scroll + $_cth}     { set split_r_scroll [expr {$_rv - $_cth + 1}] }
            set split_r_scroll [expr {max(0, min($split_r_scroll, max(0, [llength $split_r_vrows] - $_cth)))}]
        }

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

        if {$split} {
            set _l_fn [expr {$filepath eq "" ? "scratchpad" : [file tail $filepath]}]
            tui-move $roff 0
            tui-attr reverse
            puts -nonewline [format "%-*s" $half " \[$::ws_n\] $_l_fn"]
            tui-attr off
        }
        for {set i [expr {$split ? 1 : 0}]} {$i < $th} {incr i} {
            set vi2 [expr {$scroll_y + $i - ($split ? 1 : 0)}]
            set srow [expr {$i + $roff}]
            tui-move $srow 0
            if {$vi2 >= [llength $vrows]} {
                puts -nonewline [string repeat { } [expr {$split ? $half : $cols}]]
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
            puts -nonewline [string repeat { } [expr {$tw - $seg_len + $marg + ($split ? 0 : 1)}]]
        }

        # -- scroll indicator --------------------------------------------------
        set nvrows [llength $vrows]
        if {!$split && $nvrows > $th} {
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
        if {$split} {
            # divider
            for {set i 0} {$i < $th} {incr i} {
                tui-move [expr {$i + $roff}] $half
                tui-attr dim; puts -nonewline "|"; tui-attr off
            }
            # right pane
            set _r_fn [expr {$split_r_fp eq "" ? "scratchpad" : [file tail $split_r_fp]}]
            set _r_ws [expr {$::ws_n == 1 ? 2 : 1}]
            tui-move $roff $rcoff
            tui-attr reverse
            puts -nonewline [string range " \[$_r_ws\] $_r_fn" 0 [expr {$tw_r - 1}]]
            tui-attr off; puts -nonewline "\033\[K"
            set _rsrc_lines [expr {$split_ws2_mode ? $split_r_lines : $lines}]
            for {set i 1} {$i < $th} {incr i} {
                set row_y [expr {$i + $roff}]
                set vr [expr {$split_r_scroll + $i - 1}]
                tui-move $row_y $rcoff
                if {$vr < [llength $split_r_vrows]} {
                    lassign [lindex $split_r_vrows $vr] li scol ecol
                    set rseg [string range [lindex $_rsrc_lines [expr {$li-1}]] $scol [expr {$ecol-1}]]
                    set rish [lindex $split_r_ish [expr {$li-1}]]
                    set risd [lindex $split_r_isd [expr {$li-1}]]
                    if {$rish} { tui-attr heading } elseif {$risd} { tui-attr dim }
                    puts -nonewline "[string range $rseg 0 [expr {$tw_r-1}]]\033\[K"
                    if {$rish || $risd} { tui-attr off }
                } else {
                    puts -nonewline "\033\[K"
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
                timer $timer_display \
                ws    $::ws_n]
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

        if {$split && $split_focus == 2 && [llength $split_r_vrows] > 0} {
            tui-move [expr {$split_r_vi - $split_r_scroll + $roff + 1}] [expr {$split_r_scx + $rcoff}]
        } else {
            tui-move [expr {$vi - $scroll_y + $roff + ($split ? 1 : 0)}] [expr {$scx + $coff}]
        }
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

        # split focus==2: swap navigation context (and content for ws2 mode) so key handling targets right pane
        set _fswap 0
        if {$split && $split_focus == 2} {
            if {$split_ws2_mode} {
                foreach {_v _r} {lines split_r_lines  dirty split_r_dirty  filepath split_r_fp} {
                    set _tmp [set $_v]; set $_v [set $_r]; set $_r $_tmp
                }
            }
            foreach {_v _r} {cy split_r_cy  cx split_r_cx  vrows split_r_vrows  ish_cache split_r_ish  isd_cache split_r_isd  scroll_y split_r_scroll  layout_cache split_r_layout  tw tw_r} {
                set _tmp [set $_v]; set $_v [set $_r]; set $_r $_tmp
            }
            set vi $split_r_vi; set scx $split_r_scx
            set _fswap [expr {$split_ws2_mode ? 2 : 1}]
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
                        if {$wc_dirty} { tui-compute-wc }
                        daily-update $wc_cached
                        set file_mtime_known [file mtime $filepath]
                        cursor-put $filepath $cy $cx
                        set dirty 0; set message [t ed_saved]; set msg_time [clock seconds]
                    }
                    set clear_sel 0
                } elseif {$::tui_cmd_mode} {
                    # In command mode
                    if {$key eq $::cfg_tui_cmd_mode} {
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
                        set _rsl [expr {$_fswap==2 ? $lines : $split_r_lines}]
                        set _rsd [expr {$_fswap==2 ? $dirty : $split_r_dirty}]
                        set _rsf [expr {$_fswap==2 ? $filepath : $split_r_fp}]
                        tui-split-save-right $split $::ws_n $_rsl $_rsd $_rsf
                        lassign [tui-size] rows cols
                        if {$dirty} {
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
                                if {![tui-ws-check-inactive-dirty $rows $cols]} { set clear_sel 0 } else {
                                    set ::session_file ""; return
                                }
                            }
                        } else {
                            if {$filepath ne ""} { daily-update $wc_cached; cursor-put $filepath $cy $cx }
                            if {![tui-ws-check-inactive-dirty $rows $cols]} { set clear_sel 0 } else {
                                set ::session_file ""; return
                            }
                        }
                    } elseif {$key eq "s"} {
                        lassign [tui-size] rows cols
                        if {$filepath ne ""} {
                            if {$wc_dirty} { tui-compute-wc }
                            daily-update $wc_cached
                            set _r [tui-stats-dialog $filepath $rows $cols]
                            if {$_r ne ""} { set message $_r; set msg_time [clock seconds] }
                        }
                        set ::tui_cmd_mode 0
                        puts -nonewline "\033\[2J\033\[H"; flush stdout
                        set wrap_dirty 1
                        set clear_sel 0
                    } elseif {$key eq "w"} {
                        lassign [tui-size] rows cols
                        if {$filepath ne ""} {
                            tui-word-occurrences $filepath $rows $cols
                        }
                        set ::tui_cmd_mode 0
                        puts -nonewline "\033\[2J\033\[H"; flush stdout
                        set wrap_dirty 1
                        set clear_sel 0
                    } elseif {$key ne ""} {
                        # Any non-empty key exits command mode
                        set ::tui_cmd_mode 0
                        set message ""
                        set msg_time [clock seconds]
                        set clear_sel 0
                    }
                } elseif {$key eq $::cfg_tui_cmd_mode} {
                    set ::tui_cmd_mode 1
                    set message "$::cfg_lbl_cmd_mode: exit mode  t: timer  q: quit  s: stats  w: words"
                    set msg_time [clock seconds]
                    set clear_sel 0
                } elseif {$key eq $::cfg_tui_close} {
                    set _rsl [expr {$_fswap==2 ? $lines : $split_r_lines}]
                    set _rsd [expr {$_fswap==2 ? $dirty : $split_r_dirty}]
                    set _rsf [expr {$_fswap==2 ? $filepath : $split_r_fp}]
                    tui-split-save-right $split $::ws_n $_rsl $_rsd $_rsf
                    lassign [tui-size] rows cols
                    if {$dirty} {
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
                            if {![tui-ws-check-inactive-dirty $rows $cols]} { set clear_sel 0 } else {
                                set ::session_file ""; return
                            }
                        }
                    } else {
                        if {$filepath ne ""} { daily-update $wc_cached; cursor-put $filepath $cy $cx }
                        if {![tui-ws-check-inactive-dirty $rows $cols]} { set clear_sel 0 } else {
                            set ::session_file ""; return
                        }
                    }
                } elseif {$key eq $::cfg_tui_open} {
                    set _rsl [expr {$_fswap==2 ? $lines : $split_r_lines}]
                    set _rsd [expr {$_fswap==2 ? $dirty : $split_r_dirty}]
                    set _rsf [expr {$_fswap==2 ? $filepath : $split_r_fp}]
                    tui-split-save-right $split $::ws_n $_rsl $_rsd $_rsf
                    if {$filepath ne ""} { tui-save-file $filepath $lines; daily-update $wc_cached; cursor-put $filepath $cy $cx }
                    set ::session_file ""; set dirty 0
                    if {$::ws_n == 2} { return "__ws2_open__" }
                    return
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
                    puts -nonewline "\033\[2J\033\[H"; flush stdout
                    set wrap_dirty 1
                    set clear_sel 0
                } elseif {$key eq "ALT-t"} {
                    if {$::timer_active} { timer-pause } else { timer-start }
                    set clear_sel 0
                } elseif {$key eq "ALT-T"} {
                    timer-reset
                    set clear_sel 0
                } elseif {$key eq $::cfg_tui_workspace} {
                    if {$split && $split_ws2_mode == 0} {
                        # F10 in same-file split: load WS2 into right pane
                        set ::ws_dual_mode 1
                        if {$::ws_n == 1} {
                            set split_r_fp $::ws2_filename; set split_r_dirty $::ws2_dirty; set _c $::ws2_content
                        } else {
                            set split_r_fp $::ws1_filename; set split_r_dirty $::ws1_dirty; set _c $::ws1_content
                        }
                        set split_r_lines [expr {$_c ne "" ? [split $_c "\n"] : [list ""]}]
                        if {$_fswap} {
                            set cy 1; set cx 0; set scroll_y 0
                        } else {
                            set split_r_cy 1; set split_r_cx 0; set split_r_scroll 0
                        }
                        set split_r_wrap_dirty 1; set split_r_layout {}
                        set split_ws2_mode 1; set split_focus 1
                        set wrap_dirty 1; set prev_tw -1
                        puts -nonewline "\033\[2J"; flush stdout
                        set clear_sel 0
                    } elseif {$split && $split_ws2_mode == 1} {
                        # F10 in WS2 split: cycle focus (like F4)
                        set split_focus [expr {$split_focus == 1 ? 2 : 1}]
                        set clear_sel 0
                    } else {
                        # No split: normal workspace toggle
                        tui-split-save-right $split $::ws_n $split_r_lines $split_r_dirty $split_r_fp
                        if {$filepath ne ""} { cursor-put $filepath $cy $cx }
                        set ::tui_ws_save [dict create \
                            filepath $filepath lines $lines cy $cy cx $cx dirty $dirty]
                        set ::session_file ""; return "__ws_toggle__"
                    }
                } elseif {$key eq $::cfg_tui_split} {
                    if {$split} {
                        # Close split
                        if {$split_ws2_mode} {
                            set _rsl [expr {$_fswap==2 ? $lines : $split_r_lines}]
                            set _rsd [expr {$_fswap==2 ? $dirty : $split_r_dirty}]
                            set _rsf [expr {$_fswap==2 ? $filepath : $split_r_fp}]
                            tui-split-save-right 1 $::ws_n $_rsl $_rsd $_rsf
                        }
                        set split 0; set split_ws2_mode 0; set split_focus 1
                        set wrap_dirty 1; set prev_tw -1
                    } else {
                        # Open split: same-file by default
                        set split_r_cy $cy; set split_r_cx $cx; set split_r_scroll $scroll_y
                        set split_r_dirty 0; set split_r_fp $filepath
                        set split_r_lines $lines
                        set split_r_wrap_dirty 1; set split_r_layout {}
                        set split_ws2_mode 0; set split_focus 1
                        set split 1; set wrap_dirty 1; set prev_tw -1
                        # Like GUI: if WS2 was activated, load it into right pane immediately
                        if {$::ws_dual_mode} {
                            if {$::ws_n == 1} {
                                set split_r_fp $::ws2_filename
                                set split_r_dirty $::ws2_dirty
                                set _c $::ws2_content
                            } else {
                                set split_r_fp $::ws1_filename
                                set split_r_dirty $::ws1_dirty
                                set _c $::ws1_content
                            }
                            set split_r_lines [expr {$_c ne "" ? [split $_c "\n"] : [list ""]}]
                            set split_r_cy 1; set split_r_cx 0; set split_r_scroll 0
                            set split_r_wrap_dirty 1; set split_r_layout {}
                            set split_ws2_mode 1
                        }
                    }
                    puts -nonewline "\033\[2J"; flush stdout
                    set clear_sel 0
                } elseif {$split && $key eq $::cfg_tui_split_focus} {
                    # F4: toggle focus between left and right pane
                    set split_focus [expr {$split_focus == 1 ? 2 : 1}]
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
        if {$_fswap} {
            if {$_fswap == 2} {
                foreach {_v _r} {lines split_r_lines  dirty split_r_dirty  filepath split_r_fp} {
                    set _tmp [set $_v]; set $_v [set $_r]; set $_r $_tmp
                }
            }
            foreach {_v _r} {cy split_r_cy  cx split_r_cx  vrows split_r_vrows  ish_cache split_r_ish  isd_cache split_r_isd  scroll_y split_r_scroll  layout_cache split_r_layout  tw tw_r} {
                set _tmp [set $_v]; set $_v [set $_r]; set $_r $_tmp
            }
            if {$_fswap == 2 && $wrap_dirty} { set split_r_wrap_dirty 1; set wrap_dirty 0 }
            if {$_fswap == 1 && $wrap_dirty} { set split_r_wrap_dirty 1 }
        }
        if {$rst}       { set sticky -1 }
        if {$clear_sel} { set sel_anchor ""; set sel_sticky 0 }
    }
}

proc tui-info-dialog {text rows cols} {
    set _disp [string map [list $::HOME_DIR ~] $text]
    set _w [expr {min([string length $_disp] + 4, $cols)}]
    set _row [expr {$rows / 2}]
    set _lcol [expr {max(0, ($cols - $_w) / 2)}]
    puts -nonewline "\033\[2J\033\[H"
    foreach _r [list [expr {$_row-1}] [expr {$_row+1}]] {
        tui-move $_r 0; puts -nonewline "\033\[K"
    }
    tui-move $_row $_lcol
    tui-attr reverse
    puts -nonewline [string range "  $_disp  " 0 [expr {$_w-1}]]
    tui-attr off
    tui-bar [expr {$rows-1}] "  q / any key  close" "" $cols
    flush stdout
    set _k ""; while {$_k eq ""} { set _k [tui-getch] }
}

proc tui-stats-dialog {filepath rows cols} {
    if {!$::state_cache_valid} { state-load }
    set name [file tail $filepath]
    if {![dict exists $::daily_data $filepath] || [dict size [dict get $::daily_data $filepath]] == 0} {
        return [t br_stats_no_data]
    }
    set _fdata [dict get $::daily_data $filepath]
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
    puts -nonewline "\033\[2J\033\[H"
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
        set _k ""; while {$_k eq ""} { set _k [tui-getch] }
        if {$_k eq "q" || $_k eq $::cfg_tui_help} break
        if {$_k eq "c"} {
            if {[tui-confirm [t br_stats_clear_confirm $name] $rows $cols]} {
                daily-clear $filepath
            }
            break
        }
    }
    return ""
}

proc tui-word-occurrences {fpath rows cols} {
    if {![file exists $fpath]} return

    set word_data [get-word-occurrences $fpath]
    if {[llength $word_data] == 0} {
        tui-info-dialog [t br_stats_no_data] $rows $cols
        return
    }

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

        puts -nonewline "\033\[2J\033\[H"; flush stdout

        while 1 {
            set _max_scroll [expr {max(0, $_total - $_usable)}]
            if {$_scroll > $_max_scroll} { set _scroll $_max_scroll }
            if {$_scroll < 0} { set _scroll 0 }

            puts -nonewline "\033\[H"
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

            set _k ""; while {$_k eq ""} { set _k [tui-getch] }
            switch -- $_k {
                q { break }
                UP - k { incr _scroll -1 }
                DOWN - j { incr _scroll 1 }
                HOME { set _scroll 0 }
                END { set _scroll [expr {max(0, $_total - $_usable)}] }
                default {
                    if {$_k eq $::cfg_tui_help} { break }
                }
            }
        }
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
        set sel 0
        set max_fields 4

        puts -nonewline "\033\[2J\033\[H"; flush stdout

        while 1 {
            puts -nonewline "\033\[H"

            set _lines {}
            lappend _lines "  Config - Timer"
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
                }
                RIGHT {
                    if {$sel == 0 && $timer_dur < 120} { incr timer_dur }
                    if {$sel == 1} { set timer_typ [expr {$timer_typ eq "countdown" ? "stopwatch" : "countdown"}] }
                    if {$sel == 2} { set timer_snd [expr {!$timer_snd}] }
                    if {$sel == 3} { set timer_alrt [expr {!$timer_alrt}] }
                }
                " " {
                    if {$sel == 1} { set timer_typ [expr {$timer_typ eq "countdown" ? "stopwatch" : "countdown"}] }
                    if {$sel == 2} { set timer_snd [expr {!$timer_snd}] }
                    if {$sel == 3} { set timer_alrt [expr {!$timer_alrt}] }
                }
                s {
                    set ::cfg_timer_duration $timer_dur
                    set ::cfg_timer_type $timer_typ
                    set ::cfg_timer_sound $timer_snd
                    set ::cfg_timer_alert $timer_alrt
                    ini-save
                    break
                }
                q - "\x1B" { break }
            }
        }
    }
}

proc tui-split-save-right {split ws_n r_lines r_dirty r_fp} {
    if {!$split} return
    if {$ws_n == 1} {
        set ::ws2_content [join $r_lines "\n"]; set ::ws2_dirty $r_dirty; set ::ws2_filename $r_fp
    } else {
        set ::ws1_content [join $r_lines "\n"]; set ::ws1_dirty $r_dirty; set ::ws1_filename $r_fp
    }
}

proc tui-ws-check-inactive-dirty {rows cols} {
    if {!$::ws_dual_mode} { return 1 }
    if {$::ws_n == 1} {
        set iws 2;  set ifn $::ws2_filename;  set isp $::ws2_scratchpad
        set idirty $::ws2_dirty;  set icontent $::ws2_content
    } else {
        set iws 1;  set ifn $::ws1_filename;  set isp $::ws1_scratchpad
        set idirty $::ws1_dirty;  set icontent $::ws1_content
    }
    if {!$idirty || ($ifn eq "" && !$isp)} { return 1 }
    set _name [expr {$isp ? "scratchpad \[$iws\]" : "[file tail $ifn] \[$iws\]"}]
    set r [tui-yesnocancel "$_name: [t ed_save_before_tui]" $rows $cols]
    if {$r eq "cancel"} { return 0 }
    if {$r eq "yes" && $ifn ne ""} {
        set fh [open $ifn w];  chan configure $fh -encoding utf-8
        puts -nonewline $fh $icontent;  close $fh
        if {$iws == 1} { set ::ws1_dirty 0 } else { set ::ws2_dirty 0 }
    }
    return 1
}

proc tui-ws-run {fp} {
    set ::tui_ws_bg [dict create filepath "" lines [list ""] cy 1 cx 0 dirty 0]
    set ::ws_n 1
    set ret [tui-editor $fp]
    while {$ret eq "__ws_toggle__" || $ret eq "__ws2_open__"} {
        if {$ret eq "__ws_toggle__"} {
            set ::ws_dual_mode 1
            set saved $::tui_ws_save
            set next  $::tui_ws_bg
            set ::tui_ws_bg $saved
            set ::ws_n [expr {$::ws_n == 1 ? 2 : 1}]
            # Sync ws1/ws2 globals so split view can read correct inactive-workspace state
            if {$::ws_n == 2} {
                set ::ws1_filename   [dict get $saved filepath]
                set ::ws1_content    [join [dict get $saved lines] "\n"]
                set ::ws1_dirty      [dict get $saved dirty]
                set ::ws1_scratchpad [expr {[dict get $saved filepath] eq ""}]
            } else {
                set ::ws2_filename   [dict get $saved filepath]
                set ::ws2_content    [join [dict get $saved lines] "\n"]
                set ::ws2_dirty      [dict get $saved dirty]
                set ::ws2_scratchpad [expr {[dict get $saved filepath] eq ""}]
            }
            puts -nonewline "\033\[2J"; flush stdout
            set next_fp [dict get $next filepath]
            set ret [tui-editor $next_fp $next]
        } else {
            puts -nonewline "\033\[2J"; flush stdout
            set new_fp [tui-browser]
            if {$new_fp eq ""} { set ::ws_n 1; break }
            puts -nonewline "\033\[2J"; flush stdout
            if {$new_fp eq "__scratchpad__"} { set new_fp "" }
            set ret [tui-editor $new_fp]
        }
    }
    set ::ws_n 1
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
            tui-ws-run $fp
        }
        if {$::cfg_browser || $::argc == 0} {
            while 1 {
                set fp [tui-browser]
                if {$fp eq ""} break
                puts -nonewline "\033\[2J"; flush stdout
                if {$fp eq "__scratchpad__"} { tui-ws-run "" } else { tui-ws-run $fp }
            }
        }
    } err info]
    tui-cleanup
    if {$ok} { puts stderr $err }
}


# ===========================================================================
# main.tcl
# ===========================================================================
# --- Development mode: auto-load modules if run directly from src/ --- 
if {![info exists ::version]} {
    set srcdir [file dirname [info script]]
    foreach m {boot state config common tui} {
        source [file join $srcdir $m.tcl]
    }
    # Load GUI module only if not in TUI mode
    if {!$::no_gui} {
        source [file join $srcdir gui.tcl]
    }
}

# --- start --------------------------------------------------------------------
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
    # if {[file exists "writhdeck.png"]} {
    #     catch { wm iconphoto . [image create photo -file "writhdeck.png"] }
    # }
    if {$::argc > 0} { show-editor [lindex $::argv 0] } else { show-browser }
    if {$::cfg_key_error ne ""} {
        after 100 [list set-msg "key conflict: $::cfg_key_error"]
    }
}
