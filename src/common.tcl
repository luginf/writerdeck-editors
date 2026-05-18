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

