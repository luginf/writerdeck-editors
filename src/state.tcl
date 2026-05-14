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
