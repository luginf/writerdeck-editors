
# WRITHDECK 

A distraction-free text editor for writerdecks — GUI and TUI dual mode, fully configurable.

```
wish writhdeck.tcl                     # GUI, file browser
wish writhdeck.tcl file.txt            # GUI, open file directly
tclsh writhdeck.tcl --no-gui           # TUI, file browser
tclsh writhdeck.tcl --no-gui file.txt  # TUI, open file directly
```

Nano, micro or scite are also great tools for a simple writerdeck.


## Command-line options

| Option | Description |
|---|---|
| `--help`, `-h` | Show help and exit |
| `--gui` | Force GUI (Tk) mode — skip display socket detection |
| `--no-gui` | Force TUI (terminal) mode |
| `--tui`, `--ng` | Aliases for `--no-gui` |

When both `--gui` and `--no-gui` are given, `--no-gui` takes precedence.


## Features

- Plain `.txt` file editor focused on distraction-free writing
- Documents stored in `~/Documents/writhdeck/` (auto-created)
- File browser: files sorted by modification date, open / create / rename / delete
- Word-wrapped display with configurable margins
- **Inline syntax highlighting** (GUI and TUI):
  - Headings: configurable marker (`= title =`) and Markdown (`# title`)
  - Comments: lines starting with `%` (configurable `comment_marker`)
  - Bold `**text**`, italic `//text//`, underline `__text__`, strikethrough `--text--` — all markers configurable
  - Marker characters greyed out; styled text in a configurable `color_markup`
- Table of contents overlay: jump to any heading (last selection remembered per session)
- Status bar: fully configurable zones (left / center / right) with tokens: `filename dirty sel ln col words chars clock help_bar space`
- Go to line
- UTF-8 input support
- Cursor position restored across sessions (`.cursors.json`)
- Configuration reloaded on each new document open (no restart needed)
- Dark/light theme toggle (`Ctrl+D` by default, configurable)
- Interface language: `lang = en` or `fr`
- **Unified browser behavior**: after closing a file, both GUI and TUI return to the file browser (configurable via `browser`)


---

## Configuration

`~/Documents/writhdeck/writhdeck.ini` — sections: `[editor]`, `[behaviour]`, `[keys]`, `[colors]`

All keyboard shortcuts are configurable via the `[keys]` section.

### Key INI options

**`[editor]`**

| Key | Default | Description |
|---|---|---|
| `heading_marker` | `=` | Heading delimiter (`= title =`) |
| `comment_marker` | `%` | Line comment prefix; set to `0` or leave empty to disable |
| `bold_marker` | `**` | Bold inline marker; set to `0` or leave empty to disable |
| `italic_marker` | `//` | Italic inline marker; set to `0` or leave empty to disable |
| `underline_marker` | `__` | Underline inline marker; set to `0` or leave empty to disable |
| `strikethrough_marker` | `--` | Strikethrough inline marker; set to `0` or leave empty to disable |
| `margin_width` | `60` | Horizontal padding (px, GUI) |
| `margin_cols` | `6` | Horizontal margin (cols, TUI) |
| `font_size` | `13` | Font size (GUI) |
| `line_spacing` | `100` | Line spacing in % (GUI) |

**`[behaviour]`**

| Key | Default | Description |
|---|---|---|
| `browser` | `1` | Return to file browser after closing a file |
| `console_center_alert` | `1` | Center confirm dialogs (TUI); `0` = bottom bar |
| `block_cursor_gui` | `1` | Block cursor in GUI mode |
| `block_cursor_console` | `1` | Block cursor in TUI mode |
| `blink_cursor` | `0` | Blinking cursor |
| `line_numbers` | `0` | Show line numbers |
| `cursor_restore` | `1` | Restore cursor position on reopen |
| `lang` | `en` | Interface language (`en` or `fr`) |
| `dark_mode` | `1` | Dark theme; `0` = light (Solarized-style) |

**`[colors]`** — `color_heading`, `color_comment`, `color_markup`, `color_bg`, `color_fg`, `color_bg_bar`, `color_fg_bar`, `color_bg_sel` + `_alt` variants for light mode.


---

## GUI mode (default, requires Tk)

**Display**
- Graphical window with scrollable editor and file browser
- Configurable pixel margins, font size, line spacing, colors (via INI)
- Inline syntax highlighting: headings, comments, bold, italic, underline, strikethrough
- Line numbers: synchronized with scroll (`line_numbers = 1`)
- Dynamic font resize: Ctrl++ / Ctrl+-  (keyboard and numpad)
- Fullscreen toggle (default: Alt+Enter, configurable)
- Built-in Solarized Light theme (toggle with `dark_mode` or `Ctrl+D`)
- Optional second docs folder (`docs_dir`), shown as two labeled sections in the browser
- Clock (HH:MM) in status bar: add `clock` token to a status zone
- Block cursor: rectangle with inverted colors (`block_cursor_gui = 1`)
- Configurable status bar height (`bar_height`); font size adapts automatically

**Shortcuts — Editor**

| Key | Action |
|---|---|
| Ctrl+S | Save |
| Ctrl+Shift+S | Save as… (with overwrite confirmation) |
| Ctrl+Q / Esc | Close file, return to browser |
| Ctrl+F | Find (inline bar, live highlight, match counter) |
| Ctrl+R | Find & Replace (inline bar; Enter: replace one, Ctrl+Enter: all) |
| Ctrl+Z | Undo |
| Ctrl+Y | Redo |
| Ctrl+O | Open any file (system dialog) |
| Ctrl+G | Go to line |
| Ctrl+H | Help dialog (includes date/time and file word/char count) |
| Ctrl+L | Toggle line numbers |
| Ctrl+D | Toggle dark/light theme |
| Ctrl+Space | Jump to next space |
| Ctrl+Shift+Space | Jump to previous space |
| F11 | Table of contents |
| F3 | Split view — toggle vertical split (GUI only) |
| Alt+Enter | Fullscreen toggle |
| Tab | Insert 4 spaces |
| Shift+↑↓←→ | Extend selection |

**Shortcuts — Browser**

| Key | Action |
|---|---|
| Enter / double-click | Open file |
| n | New file |
| d | Delete file |
| r | Rename file |
| h / Ctrl+H | Help |
| Ctrl+O | Open any file (system dialog) |
| Ctrl+D | Toggle dark/light theme |
| Alt+Enter | Fullscreen toggle |
| q | Quit |


---

## TUI mode (`--no-gui` / `--tui` / `--ng`, pure terminal via ANSI escapes)

**Display**
- Identical feature set to the GUI editor, rendered in the terminal
- Browser with `»` selection marker; section headers for dual-folder mode
- Vim-style navigation (j/k) + arrow keys, Home/End, PgUp/PgDn
- Inline syntax highlighting: headings (bold), comments (dim), bold/italic/underline/strikethrough
- Scroll indicator: `▐/│` bar in the rightmost column when content overflows
- Line numbers: left column (`line_numbers = 1`), shown on first visual row of each paragraph
- Status bar: filename, position, word/char count, clock
- Word and char count also available in help dialog (Ctrl+H)
- Cursor shape configurable: block or bar, blinking or steady (`block_cursor_console`, `blink_cursor`)
- Confirm dialogs centered on screen by default (`console_center_alert = 1`)
- After closing a file, returns to browser if `browser = 1` (default)

**Shortcuts — Editor**

| Key | Action |
|---|---|
| Ctrl+S | Save |
| Ctrl+Q / Esc | Close file, return to browser |
| Ctrl+F | Find (prompt; repeat to find next) |
| Ctrl+R | Find & Replace (global, with replacement counter) |
| Ctrl+Z | Undo (100-state stack) |
| Ctrl+Y | Redo |
| Ctrl+O | Save and return to browser |
| Ctrl+G | Go to line |
| Ctrl+H | Help (includes date/time and file word/char count) |
| Ctrl+L | Toggle line numbers |
| Ctrl+D | Toggle dark/light theme (reverse video) |
| Ctrl+Space | Jump to next space |
| F11 | Table of contents |
| Ctrl+A | Select all |
| Ctrl+K | Toggle sticky selection (first press: set anchor; second press: cancel) |
| Shift+↑↓←→ | Extend selection |
| Ctrl+C | Copy (via xclip / xsel / wl-copy) |
| Ctrl+X | Cut |
| Ctrl+V | Paste (multi-line supported) |
| Tab | Insert 4 spaces |

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

Designed to run on tcl with the help of LLM (Claude Code).


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
