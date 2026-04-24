
# WRITHDECK 

A distraction-free text editor for writerdecks — GUI and TUI dual mode, fully configurable.

```
wish writhdeck.tcl                     # GUI, file browser
wish writhdeck.tcl file.txt            # GUI, open file directly
tclsh writhdeck.tcl --no-gui           # TUI, file browser
tclsh writhdeck.tcl --no-gui file.txt  # TUI, open file directly
```

Nano, micro or scite are also great tools for a simple writerdeck.


## Features

- Plain `.txt` file editor focused on distraction-free writing
- Documents stored in `~/Documents/writhdeck/` (auto-created)
- File browser: files sorted by modification date, open / create / rename / delete
- Word-wrapped display with configurable margins
- Heading detection: configurable marker (`= title =`) and Markdown (`# title`)
- Table of contents overlay: jump to any heading (last selection remembered per session)
- Status bar: fully configurable zones (left / center / right) with tokens: `filename dirty sel ln col words chars clock help_bar space`
- Go to line
- UTF-8 input support
- Cursor position restored across sessions (`.cursors.json`)
- Configuration reloaded on each new document open (no restart needed)


---

## Configuration

`~/Documents/writhdeck/writhdeck.ini` — sections: `[editor]`, `[behaviour]`, `[keys]`, `[colors]`

All keyboard shortcuts are configurable via the `[keys]` section.


---

## GUI mode (default, requires Tk)

**Display**
- Graphical window with scrollable editor and file browser
- Configurable pixel margins, font size, line spacing, colors (via INI)
- Heading lines highlighted in a configurable color
- Line numbers: synchronized with scroll (`line_numbers = 1`)
- Dynamic font resize: Ctrl++ / Ctrl+-  (keyboard and numpad)
- Fullscreen toggle (default: Alt+Enter, configurable)
- Built-in Solarized Light theme (commented out in INI, ready to enable)
- Optional second docs folder (`docs_dir`), shown as two labeled sections in the browser
- Clock (HH:MM) in status bar (`show_clock = 1`)
- Block cursor: rectangle with inverted colors, like a classic terminal (`block_cursor = 1`)
- Non-blinking cursor option (`blink_cursor = 0`)

**Shortcuts — Editor**

| Key | Action |
|---|---|
| Ctrl+S | Save |
| Ctrl+Shift+S | Save as… (with overwrite confirmation) |
| Ctrl+Q / Esc | Close file, return to browser |
| Ctrl+F | Find (inline bar, live highlight, match counter) |
| Ctrl+R | Find & Replace (inline bar; Enter: replace one, Ctrl+Enter: all) |
| Ctrl+Z | Undo |
| Ctrl+O | Open any file (system dialog) |
| Ctrl+G | Go to line |
| Ctrl+H | Help dialog |
| Ctrl+L | Toggle line numbers |
| F11 | Table of contents |
| Alt+Enter | Fullscreen toggle |
| Tab | Insert 4 spaces |

**Shortcuts — Browser**

| Key | Action |
|---|---|
| Enter / double-click | Open file |
| n | New file |
| d | Delete file |
| r | Rename file |
| h / Ctrl+H | Help |
| Ctrl+O | Open any file (system dialog) |
| Alt+Enter | Fullscreen toggle |
| q | Quit |


---

## TUI mode (`--no-gui` flag, pure terminal via ANSI escapes)

**Display**
- Identical feature set to the GUI editor, rendered in the terminal
- Browser with `»` selection marker; section headers for dual-folder mode
- Vim-style navigation (j/k) + arrow keys, Home/End, PgUp/PgDn
- Bold rendering for heading lines
- Scroll indicator: `▐/│` bar in the rightmost column when content overflows
- Line numbers: left column (`line_numbers = 1`), shown on first visual row of each paragraph
- Status bar: filename, position, word/char count, clock
- Word and char count also available in help dialog (Ctrl+H)
- Cursor blink controlled via `blink_cursor` INI option

**Shortcuts — Editor**

| Key | Action |
|---|---|
| Ctrl+S | Save |
| Ctrl+Q / Esc | Close file, return to browser |
| Ctrl+F | Find (prompt at bottom; repeat to find next) |
| Ctrl+R | Find & Replace (global, with replacement counter) |
| Ctrl+Z | Undo (100-state stack) |
| Ctrl+O | Save and return to browser |
| Ctrl+G | Go to line |
| Ctrl+H | Help (includes word and char count) |
| Ctrl+L | Toggle line numbers |
| F11 | Table of contents |
| Ctrl+A | Select all |
| Ctrl+K | Toggle sticky selection (first press: set anchor; second press: cancel) |
| Shift+↑↓←→ | Extend selection |
| Ctrl+C | Copy (via xclip / xsel / wl-copy) |
| Ctrl+X | Cut |
| Ctrl+V | Paste (multi-line supported) |

**Shortcuts — Browser**

| Key | Action |
|---|---|
| Enter | Open file |
| n | New file |
| d | Delete file |
| r | Rename file |
| Ctrl+H | Help |
| q / Ctrl+Q | Quit |


---

## Credits

Based on <https://github.com/lallero7/writhdeckForCMD>,
itself based on <https://github.com/shmimel/bee-write-back/>

Designed to tcl with the help of LLM (Claude Code).


## Licence

Copyright (C) 2026 by Luginfo

    BSD Zero Clause License

    Permission to use, copy, modify, and/or distribute this software for any purpose
    with or without fee is hereby granted.

    THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
    WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES
    OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE
    FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
    WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION
    OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
    OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
