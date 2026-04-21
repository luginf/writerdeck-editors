
# WRITHDECK

Some simple editors for a writerdeck:

- writhdeck.lua : Lua TUI (lcurses)
- writhdeck.py  : Python TUI (curses, stdlib)
- writhdeck.fs  : Forth TUI (gforth + ncurses FFI)
- writhdeck-ansi.fs : Forth TUI (gforth, pure ANSI, no FFI)
- writhdeck.tcl : Tcl/Tk — the most advanced version; GUI and TUI dual mode, fully configurable via `~/Documents/writhdeck/writhdeck.ini`

Converted to Lua and others with the help of LLM (Claude Code).

Nano, micro or scite are also great tools for a simple writerdeck.


## Usage

```
wish writhdeck.tcl            # GUI, file browser
wish writhdeck.tcl file.txt   # GUI, open file directly
tclsh writhdeck.tcl --no-gui  # TUI, file browser
tclsh writhdeck.tcl --no-gui file.txt  # TUI, open file directly

lua writhdeck.lua             # TUI, file browser
lua writhdeck.lua file.txt    # TUI, open file directly
```

Similar usage for the other versions.


## Summary

### Common features (all versions)

- Plain `.txt` file editor focused on distraction-free writing
- Documents stored in `~/Documents/writhdeck/` (auto-created)
- File browser: files sorted by modification date, open / create / rename / delete
- Word-wrapped display with configurable margins
- Heading detection: configurable marker (`= title =`) and Markdown (`# title`)
- Table of contents overlay: jump to any heading
- Status bar: filename, modified flag, line/col, word count, clock
- Go to line
- UTF-8 input support
- Cursor position restored across sessions (`.cursors.json`)


---

### writhdeck.tcl — Tcl/Tk (GUI + TUI)

Configuration: `~/Documents/writhdeck/writhdeck.ini`
Sections: `[editor]`, `[behaviour]`, `[keys]`, `[colors]`

#### GUI mode (default, requires Tk)

**Display**
- Graphical window with scrollable editor and file browser
- Configurable pixel margins, font size, colors (via INI)
- Heading lines highlighted in a configurable color
- Line numbers: synchronized with scroll (`line_numbers = 1` in INI)
- Dynamic font resize: Ctrl++ / Ctrl+-  (keyboard and numpad)
- Fullscreen toggle (default: Alt+Enter, configurable)
- Built-in Solarized Light theme (commented out in INI, ready to enable)
- Optional second docs folder (`docs_dir` INI key), shown as two labeled sections in the browser
- Clock (HH:MM) in status bar (`show_clock = 1` in INI)

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
| F11 | Table of contents (configurable) |
| Alt+Enter | Fullscreen toggle (configurable) |
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

All shortcuts are configurable via the `[keys]` section of the INI.
The help bar text is configurable (`help_bar` in INI); set empty to hide it.


---

#### TUI mode (`--no-gui` flag, pure terminal via ANSI escapes)

**Display**
- Identical feature set to the GUI editor, rendered in the terminal
- Browser with `»` selection marker; section headers for dual-folder mode
- Vim-style navigation (j/k) + arrow keys, Home/End, PgUp/PgDn
- Bold rendering for heading lines
- Scroll indicator: `▐/│` bar in the rightmost column when content overflows
- Line numbers: left column (`line_numbers = 1`), shown on first visual row of each paragraph
- Clock (HH:MM) on the right of the status bar (`show_clock = 1`)

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
| Ctrl+H | Help |
| Ctrl+L | Toggle line numbers |
| F11 | Table of contents (configurable) |
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

All shortcuts are configurable via the `[keys]` section of the INI.
The help bar text is configurable (`help_bar` in INI); set empty to hide it.


---

### writhdeck.lua — Lua TUI (lcurses)

**Dependencies:** lcurses, luafilesystem

- UTF-8 aware editing (multi-byte character movement)
- Word count + character count in status bar
- Configurable margins in columns/rows (separate INI keys from Tk pixel values)
- TOC as fullscreen overlay with scrolling
- Heading lines rendered in bold
- Save confirmation dialog before closing (no silent auto-save)


---

### writhdeck.py — Python TUI (curses, stdlib)

**Dependencies:** Python 3.7+ (no external libraries; optional `windows-curses` on Windows)

- Basic editor with file browser, word-wrapped display, status bar
- Cursor position persisted in `.cursors.json`


---

### writhdeck.fs — Forth TUI (gforth + ncurses FFI)

**Dependencies:** gforth 0.7+, libncurses

- Uses C FFI to call ncurses directly
- Full-screen terminal editor with file browser


---

### writhdeck-ansi.fs — Forth TUI (gforth, pure ANSI, no FFI)

**Dependencies:** gforth only

- Pure ANSI escape sequences for terminal control
- Can open a file passed as a command-line argument directly


---

## Credits

Based on <https://github.com/lallero7/writhdeckForCMD>, 
itself based on <https://github.com/shmimel/bee-write-back/>


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
