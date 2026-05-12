
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

proc tui-getch {} {
    set raw [read stdin 1]
    if {$raw eq ""} { return "" }
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
            set tui_state [dict create \
                fn    [expr {$filepath eq "" ? "** scratchpad **" : [file tail $filepath]}] \
                dirty $dirty \
                sel   [expr {$sel_anchor ne ""}] \
                ln    $cy  total [llength $lines] \
                col   [expr {$cx+1}] \
                words $wc_cached \
                chars $cc_cached \
                clock [clock format [clock seconds] -format "%H:%M"]]
            set bar_left   " [status-build $::cfg_status_left   $tui_state]"
            set bar_center [status-build $::cfg_status_center $tui_state]
            set bar_right  "[status-build $::cfg_status_right  $tui_state] "
            if {$::cfg_key_error ne "" && $message eq ""} { set message "key conflict: $::cfg_key_error"; set msg_time [clock seconds] }
            if {$message ne "" && [clock seconds] - $msg_time < 4} { set bar_left " $message" }
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
                } elseif {$key eq $::cfg_tui_close || $key eq "ESC"} {
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

    set sorted [get-word-occurrences $fpath]
    if {[llength $sorted] == 0} return

    catch {
        set content [chan read [open $fpath r]]
        set counts [dict create]
        foreach word [regexp -all -inline {\w+} [string tolower $content]] {
            if {[string length $word] > 2} {
                dict incr counts $word
            }
        }

        set all_lines [list [list "  Word Occurrences" 1] [list "" 0] \
            [list [format "  %-30s %s" "Word" "Count"] 1]]
        foreach word $sorted {
            set count [dict get $counts $word]
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

