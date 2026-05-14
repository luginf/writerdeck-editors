
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

