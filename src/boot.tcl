#!/bin/sh
# sh/Tcl polyglot - backslash continues Tcl comment to next line, hiding shell bootstrap \
_w=$(stty -g 2>/dev/null); trap '[ -n "$_w" ] && stty "$_w" 2>/dev/null' EXIT INT TERM; tclsh "$0" "$@"; exit $?

# # # # # # # # # # # #
#
#     writhdeck.tcl 
#     
#  ~  Tcl/Tk 8.6 (console/GUI) text editor for writerdecks ~
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

set ::version          "v20260515"

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
