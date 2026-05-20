# WrithDeck — Manual / Manuel

[🇬🇧 English](#english) — [🇫🇷 Français](#français)

---

<a name="english"></a>
# English

## Installation

Requires Tcl/Tk on your system.

| Platform          | Command / Source                                        |
| ----------------- | ------------------------------------------------------- |
| Debian/Ubuntu     | `apt install tk`                                        |
| Other Linux/BSD   | refer to your package manager (`tk` or `tcl-tk`)        |
| Mac OS            | `brew install tcl-tk`                                   |
| Windows           | https://www.tcl-lang.org/software/tcltk/bindist.html    |
| Haiku OS          | `pkgman install tcl tk`                                 |

Run WrithDeck:

```sh
wish writhdeck.tcl              # GUI mode
tclsh writhdeck.tcl --tui       # TUI mode
tclsh writhdeck.tcl --cli       # TUI mode (alias)
./writhdeck.tcl --tui           # direct execution (sh/Tcl polyglot)
```

For permanent access, copy to a directory in your PATH:

```sh
cp writhdeck.tcl /usr/local/bin/writhdeck
cp writhdeck-cli.tcl /usr/local/bin/writhdeck-cli  # TUI-only, no Tk required
```

## Command-line options

| Option             | Description                                           |
| ------------------ | ----------------------------------------------------- |
| `--help`, `-h`     | Show help and exit                                    |
| `--gui`            | Force GUI (Tk) mode — skip display server detection   |
| `--tui`            | Force TUI (terminal) mode                             |
| `--cli`            | Alias for `--tui`                                     |
| `--no-gui`, `--ng` | Aliases for `--tui`                                   |

When both `--gui` and `--tui`/`--no-gui` are given, TUI takes precedence.

## Features

- Plain `.txt` file editor focused on distraction-free writing
- Documents stored in `~/Documents/writhdeck/` (auto-created)
- File browser: files sorted by modification date, open / create / rename / delete / scratchpad
- Word-wrapped display with configurable margins
- **Inline syntax highlighting** (GUI and TUI):
  - Headings: configurable marker (`= title =`) and Markdown (`# title`)
  - Comments: lines starting with `%` (configurable `comment_marker`)
  - Bold `**text**`, italic `//text//`, underline `__text__`, strikethrough `--text--` — all markers configurable
  - Marker characters greyed out; styled text in a configurable `color_markup`
- Table of contents overlay: jump to any heading (last selection remembered per session)
- Status bar: fully configurable zones (left / center / right) with tokens: `workspace filename dirty sel ln col words chars goal clock help_bar space`
- **Daily writing stats**: tracks words written per file per day (high-water mark — deletions don't reduce the count); favorites keep full history, other files keep only today's data
- **Word goal** (`goal` status token): shows daily progress vs target, e.g. `47/500`; configurable via `word_goal` in INI or per profile
- Go to line
- UTF-8 input support
- Cursor position restored across sessions (`.writhdeck.json`)
- Configuration reloaded on each new document open (no restart needed)
- Dark/light theme toggle (`Ctrl+D` by default, configurable)
- Interface language: `lang = en` or `fr`
- **Unified browser behavior**: after closing a file, both GUI and TUI return to the file browser (configurable via `browser`)
- **Scratchpad**: temporary in-memory buffer, no disk file until explicitly saved
- **Help dialog**: shows selection word/char count when text is selected (GUI and TUI)
- **Timer and stopwatch**: countdown timer or stopwatch with configurable duration, visual alerts, and audio notifications (bell sound)
- **Modal command mode (ESC key)**: quick access to timer control, writing statistics, word occurrences, and file operations without breaking text focus
- **Second workspace** (F10): switch between two independent editors; each preserves its own file, content, and dirty state; `[1]`/`[2]` indicator in status bar and title bar; in split view (F3), F10 loads the second workspace into the right pane (GUI and TUI)

## Configuration

`~/Documents/writhdeck/writhdeck.ini` — sections: `[editor]`, `[behaviour]`, `[keys]`, `[profiles]`, `[schemes]`

All keyboard shortcuts are configurable via the `[keys]` section.

### `[editor]`

| Key                       | Default       | Description                                                             |
| ------------------------- | ------------- | ----------------------------------------------------------------------- |
| `profile`                 | `default`     | Active profile — must match a `[name]` block in `[profiles]`            |
| `scheme`                  | `default`     | Active color scheme — must match a `[name]` block in `[schemes]`        |
| `docs_dir`                | —             | Optional second documents folder (shown as a second section)            |
| `console_margin_cols`     | `6`           | Horizontal margin in columns (TUI only)                                 |
| `console_margin_rows`     | `4`           | Vertical margin in lines (TUI only)                                     |
| `heading_marker`          | `=`           | Heading delimiter (`= title =`)                                         |
| `comment_marker`          | `%`           | Line comment prefix; set to `0` or leave empty to disable               |
| `bold_marker`             | `**`          | Bold inline marker; set to `0` or leave empty to disable                |
| `italic_marker`           | `//`          | Italic inline marker; set to `0` or leave empty to disable              |
| `underline_marker`        | `__`          | Underline inline marker; set to `0` or leave empty to disable           |
| `strikethrough_marker`    | `--`          | Strikethrough inline marker; set to `0` or leave empty to disable       |

### `[behaviour]`

| Key                       | Default   | Description                                                                                         |
| ------------------------- | --------- | --------------------------------------------------------------------------------------------------- |
| `browser`                 | `yes`     | Return to file browser after closing a file                                                         |
| `watch_file`              | `yes`     | Detect external file modifications and prompt to reload; `no` to disable                            |
| `split_shrink_margin`     | `yes`     | Halve `margin_width` in split view (GUI); `no` to keep the full margin                              |
| `hemingway_mode`          | `no`      | When typewriter mode is active: block arrows, backspace and undo; hide status bar; double margins   |
| `console_center_alert`    | `yes`     | Center confirm dialogs (TUI); `no` = bottom bar                                                     |
| `block_cursor_gui`        | `yes`     | Block cursor in GUI mode                                                                            |
| `block_cursor_console`    | `yes`     | Block cursor in TUI mode                                                                            |
| `blink_cursor`            | `no`      | Blinking cursor                                                                                     |
| `line_numbers`            | `no`      | Show line numbers                                                                                   |
| `cursor_restore`          | `yes`     | Restore cursor position on reopen                                                                   |
| `lang`                    | `en`      | Interface language: `en`, `fr`, `de`, `es`, `ko`, `no`; also selectable in config dialog (c key)    |
| `dark_mode`               | `yes`     | Dark theme; `no` = light                                                                            |
| `word_goal`               | `500`     | Daily word goal shown by the `goal` status token; `0` to disable                                    |
| `timer_duration`          | `25`      | Timer duration in minutes (countdown mode)                                                          |
| `timer_sound`             | `yes`     | Play bell sound when timer finishes; `no` to disable                                                |
| `timer_alert`             | `yes`     | Show alert dialog when timer finishes; `no` to disable                                              |
| `timer_type`              | `countdown` | Timer mode: `countdown` or `stopwatch`                                                            |

### `[keys]`

All actions are rebindable. Use Tk key names (`Control-s`, `Alt-Return`, `F11`, etc.):

`key_save` `key_close` `key_find` `key_replace` `key_goto` `key_open` `key_undo` `key_redo` `key_help` `key_toc` `key_line_numbers` `key_fullscreen` `key_split` `key_split_focus` `key_workspace` (default: `F10`) `key_typewriter` `key_dark_toggle` `key_timer` (default: `Alt-t`)

### `[profiles]`

Named presets for display and behaviour. Each `[name]` block can override margins, fonts, and most behaviour options. Select the active profile with `profile = name` in `[editor]`. The `[default]` profile is always written by WrithDeck.

| Key                          | Default    | Description                                                            |
| ---------------------------- | ---------- | ---------------------------------------------------------------------- |
| `margin_width`               | `60`       | Horizontal padding in pixels (GUI)                                     |
| `margin_height`              | `40`       | Vertical padding in pixels (GUI)                                       |
| `font_size`                  | `13`       | Font size (GUI)                                                        |
| `font_family`                | `Mono`     | Font family; Tk resolves `Mono` to the best available monospace        |
| `bar_font_family`            | `Mono`     | Font family for the status bar (GUI)                                   |
| `line_spacing`               | `100`      | Line spacing in % (GUI)                                                |
| `bar_height`                 | `18`       | Status bar height in pixels (GUI)                                      |
| `word_goal`                  | `500`      | Daily word goal for this profile                                       |
| `dark_mode`                  | —          | Override dark/light theme per profile                                  |
| `lang`                       | —          | Override interface language per profile                                |
| `status_left/center/right`   | —          | Override status bar layout per profile                                 |

Example:

```ini
[editor]
profile = novel

[profiles]

[novel]
margin_width    = 180
margin_height   = 80
font_size       = 18
font_family     = Noto Serif
line_spacing    = 110
bar_height      = 20
word_goal       = 1000
```

### `[schemes]`

Color scheme definitions. Each `[name]` block defines dark and light colors. Select with `scheme = name` in `[editor]`. The `[default]` scheme is always written by WrithDeck.

| Key                                     | Description                             |
| --------------------------------------- | --------------------------------------- |
| `color_bg` / `color_bg_alt`             | Editor background (dark / light)        |
| `color_fg` / `color_fg_alt`             | Editor text (dark / light)              |
| `color_bg_bar` / `color_bg_bar_alt`     | Status bar background (dark / light)    |
| `color_fg_bar` / `color_fg_bar_alt`     | Status bar text (dark / light)          |
| `color_bg_sel` / `color_bg_sel_alt`     | Selection background (dark / light)     |
| `color_heading` / `color_heading_alt`   | Heading color (dark / light)            |
| `color_comment` / `color_comment_alt`   | Comment / dimmed line (dark / light)    |
| `color_markup` / `color_markup_alt`     | Inline markup color (dark / light)      |

Toggle between dark and light with `Ctrl+D` (configurable via `key_dark_toggle`).

Built-in schemes: `solarized`, `gruvbox`, `everforest`, `nord`, `alt01`.

Example — to use Gruvbox, add to your INI:

```ini
[editor]
scheme = gruvbox
```

---

## Timer and Stopwatch

The editor includes a configurable countdown timer and stopwatch mode, with real-time display in the status bar.

### Timer Control

**Starting/toggling:**
- **ESC key** (editor mode): Enter modal command mode, then press `t` to toggle timer on/off
- **Alt+t** (default, configurable via `key_timer`): Toggle timer directly

**Modes:**
- **Countdown** (default): Counts down from `timer_duration` minutes, shows alert on completion
- **Stopwatch**: Counts up indefinitely, no alert on completion

**Status bar display:**
- Format: `m'ss"` (e.g., `4'00"` for 4 minutes)
- Active timer: `[4'00"]` (in brackets)
- Inactive timer: ` 4'00"` (space before)

### Alert Behavior

When countdown reaches zero:
1. **GUI**: Popup dialog with "Timer finished!" message
2. **TUI**: Full-screen overlay with "TIMER FINISHED!" message
3. **Sound**: Bell beep (if `timer_sound = 1` in INI)

The alert respects the `timer_alert` setting in INI. If disabled, the timer stops without visual/audio feedback.

### Modal Command Mode (ESC Key)

Press **ESC** while editing to enter a command mode. This provides quick access to common functions without losing text focus:

| Key | Action |
|-----|--------|
| **ESC** | Exit modal mode (or toggle on/off) |
| **t** | Toggle timer (countdown or stopwatch) |
| **s** | Show daily writing statistics (full-screen) |
| **w** | Show word occurrences in document (full-screen) |
| **q** | Quit / close file (with save prompt if unsaved) |
| **Other keys** | Exit modal, return to normal text entry |

**GUI:** Status bar displays available commands when modal is active.

**TUI:** Message line shows commands and allows navigation with arrow keys (for stats/words screens).

---

## GUI mode

Default mode, requires Tk.

- Configurable pixel margins, font size and family, line spacing, colors
- Inline syntax highlighting: headings, comments, bold, italic, underline, strikethrough
- Line numbers synchronized with scrolling (`line_numbers = 1`)
- Dynamic font resizing: `Ctrl++` / `Ctrl+-`
- Fullscreen toggle (default: `Alt+Enter`)
- Optional second documents folder (`docs_dir`)
- Clock in the status bar: add the `clock` token to a status zone
- Block cursor: inverted-color rectangle (`block_cursor_gui = 1`)
- **Vertical split view** (F3): two independent panes on the same document; F4 cycles focus; active pane highlighted with a border
- **Typewriter / focus mode** (Ctrl+T): keeps cursor vertically centered; dims text outside the current paragraph
- **Hemingway mode** (`hemingway_mode = 1`, activated with Ctrl+T): forward-only writing — arrows, backspace and undo disabled; status bar hidden; margins doubled
- Confirm dialogs: `Tab` to navigate buttons, `Enter` to confirm, `Escape` to cancel, `y` / `n` for direct answer

### Shortcuts — Editor

| Key                        | Action                                                                  |
| -------------------------- | ----------------------------------------------------------------------- |
| Ctrl+S                     | Save                                                                    |
| Ctrl+Shift+S               | Save as… (with overwrite confirmation)                                  |
| Ctrl+Q                     | Close file, return to browser                                           |
| Ctrl+F                     | Find (inline bar, live highlighting, counter)                           |
| Ctrl+R                     | Find & Replace (Enter: replace one, Ctrl+Enter: all)                    |
| Ctrl+Z                     | Undo                                                                    |
| Ctrl+Y                     | Redo                                                                    |
| Ctrl+T                     | Typewriter / focus mode (toggle)                                        |
| Ctrl+O                     | Open any file (system dialog)                                           |
| Ctrl+G                     | Go to line                                                              |
| Ctrl+H                     | Help dialog (date/time, file stats, selection stats if text selected)   |
| Ctrl+L                     | Show/hide line numbers                                                  |
| Ctrl+D                     | Toggle dark/light theme                                                 |
| Ctrl+Up / Ctrl+Down        | Jump to previous / next paragraph                                       |
| Ctrl+Left / Ctrl+Right     | Jump to previous / next word                                            |
| F11                        | Table of contents                                                       |
| F3                         | Toggle split view                                                       |
| F4                         | Split view — cycle focus between panes                                  |
| F10                        | Switch to second workspace (WS1/WS2); in split view: load WS2 into right pane |
| Alt+Enter                  | Fullscreen toggle                                                       |
| Tab                        | Insert literal tab character                                            |
| Shift+Up/Down/Left/Right   | Extend selection                                                        |

### Second workspace notes (GUI)

- **F10** switches between two independent editors (WS1 and WS2); WS2 starts as an empty scratchpad
- The status bar shows `[1]` or `[2]` once both workspaces are active; the window title also shows the indicator
- **Ctrl+O** in WS2 opens a file into WS2 (does not affect WS1)
- **In split view (F3)**: pressing F10 loads WS2 into the right pane as an independent editor; pressing F10 again cycles focus; pressing F3 closes the split and saves WS2 state
- On quit, both workspaces are checked for unsaved changes (prompted separately if dirty)
- `key_workspace = F10` is configurable in the `[keys]` section of the INI

### Shortcuts — Browser

| Key                    | Action                                                                |
| ---------------------- | --------------------------------------------------------------------- |
| Enter / double-click   | Open file                                                             |
| n                      | New file                                                              |
| t                      | Scratchpad (in-memory buffer; Ctrl+S prompts for a name to save)      |
| f                      | Toggle favorite                                                       |
| s                      | Writing stats — daily word counts                                     |
| b                      | Backup — copies to `backups/` with a `name_YYYY-MM-DDTHHhMMmSS` stamp    |
| d                      | Delete file                                                           |
| r                      | Rename file                                                           |
| i                      | Show full path                                                        |
| c                      | Configuration — profiles, fonts, margins, color scheme, language      |
| z                      | Reload — relaunch WrithDeck (returns to browser)                      |
| h / Ctrl+H             | Help                                                                  |
| Ctrl+O                 | Open any file (system dialog)                                         |
| Ctrl+D                 | Toggle dark/light theme                                               |
| Alt+Enter              | Fullscreen toggle                                                     |
| q                      | Quit                                                                  |

### Split view notes

- F3 splits the document into two side-by-side panes; press F3 again to close
- Both panes share the same text — edits are immediately visible in both
- Cursor, scroll position, and undo history are independent per pane
- Find, Replace, Go to line, and TOC operate on the pane that had focus when opened
- Line numbers are hidden while split is active
- **F10 in split view**: replaces the right pane with an independent WS2 editor (different file); F10 again cycles focus between panes; Ctrl+S and Ctrl+O in the right pane operate on WS2

---

## TUI mode

Activated via `--no-gui` / `--tui` / `--ng`, or when no windowing system is available. Pure TTY/terminal via ANSI sequences.

- Same feature set as GUI, rendered in the terminal
- Browser with `»` selection marker; section headers for dual-folder mode
- Vim-style navigation (j/k) + arrow keys, Home/End, PgUp/PgDn
- Scroll indicator: `▐/│` bar in the rightmost column when content overflows
- Line numbers in left column (`line_numbers = 1`), shown on the first visual line of each paragraph
- Configurable cursor shape: block or bar, blinking or steady
- **Vertical split view** (F3): two panes with independent cursor, scroll, and editing; F4 cycles focus; if WS2 was previously activated, F3 opens left=current WS / right=other WS directly
- **Typewriter / focus mode** (Ctrl+T): cursor vertically centered; text outside current paragraph dimmed
- **Hemingway mode** (`hemingway_mode = 1`, activated with Ctrl+T): blocks arrows, backspace and undo; doubles margins

### Shortcuts — Editor

| Key                                     | Action                                                       |
| --------------------------------------- | ------------------------------------------------------------ |
| Ctrl+S                                  | Save (scratchpad: prompts for filename first)                |
| Ctrl+Q / Esc                            | Close file, return to browser                                |
| Ctrl+F                                  | Find (prompt; repeat to find next)                           |
| Ctrl+R                                  | Find & Replace (global, with replacement counter)            |
| Ctrl+Z                                  | Undo (100-state stack)                                       |
| Ctrl+Y                                  | Redo                                                         |
| Ctrl+T                                  | Typewriter / focus mode (toggle)                             |
| Ctrl+O                                  | Save and return to browser (in WS2: opens browser to pick a new file for WS2) |
| Ctrl+G                                  | Go to line                                                   |
| Ctrl+H                                  | Help                                                         |
| Ctrl+L                                  | Show/hide line numbers                                       |
| Ctrl+D                                  | Toggle dark/light theme (reverse video)                      |
| Ctrl+Up / Ctrl+Down                     | Jump to previous / next paragraph (terminal emulator only)   |
| Ctrl+Left / Ctrl+Right or Alt+B / Alt+F | Jump to previous / next word                                 |
| F3                                      | Toggle split view                                            |
| F4                                      | Split view — cycle focus between panes                       |
| F10                                     | Switch to second workspace (WS1/WS2); in split view: load WS2 into right pane |
| F11                                     | Table of contents (Esc / Ctrl+Q to close, Enter to jump)     |
| Ctrl+A                                  | Select all                                                   |
| Ctrl+K                                  | Toggle sticky selection (first: anchor; second: cancel)      |
| Shift+Up/Down/Left/Right                | Extend selection                                             |
| Ctrl+C                                  | Copy (via xclip / xsel / wl-copy)                            |
| Ctrl+X                                  | Cut                                                          |
| Ctrl+V                                  | Paste (multi-line supported)                                 |
| Tab                                     | Insert literal tab character                                 |

### Second workspace notes (TUI)

- **F10** switches between WS1 and WS2; WS2 starts as an empty scratchpad
- **F3** opens a split view: if WS2 was previously activated, left pane = current workspace, right pane = other workspace; otherwise opens a same-file split; **F3** again closes the split
- **F4** cycles focus between panes; both panes are fully independent (cursor, scroll, editing)
- **F10 in split view** (same-file): loads WS2 into the right pane; F10 again cycles focus
- The status bar shows `[1]` or `[2]` once both workspaces are active; the right pane shows a reverse-video header with the workspace number and filename
- **Ctrl+O in WS2**: saves the current WS2 file, opens the browser to select a new file; the chosen file loads into WS2 (WS1 is unaffected)
- On quit (`q` in browser), both workspaces are prompted for unsaved changes
- Note: the right pane shares the undo history with the left pane and has no independent syntax highlighting

### Shortcuts — Browser

| Key            | Action                                                                |
| -------------- | --------------------------------------------------------------------- |
| Enter          | Open file                                                             |
| n              | New file                                                              |
| t              | Scratchpad (in-memory buffer; Ctrl+S prompts for a name to save)      |
| f              | Toggle favorite                                                       |
| s              | Writing stats — daily word counts                                     |
| b              | Backup — copies to `backups/` with a `name_YYYY-MM-DDTHHhMMmSS` stamp    |
| d              | Delete file                                                           |
| r              | Rename file                                                           |
| i              | Show full path                                                        |
| z              | Reload — relaunch WrithDeck (returns to browser)                      |
| h / Ctrl+H     | Help                                                                  |
| q / Ctrl+Q     | Quit                                                                  |

---

## TUI Colors

The TUI editor supports ANSI colors compatible with terminal emulators and Linux TTY. Colors are disabled by default.

### Enabling colors

Add the `[tui_colors]` section to `~/.writhdeck.ini`, then restart WrithDeck:

```ini
[tui_colors]
tui_colors      = yes
tui_col_heading = cyan
tui_col_comment = green
tui_col_markup  = magenta
tui_col_bar_fg  = black
tui_col_bar_bg  = cyan
tui_col_sel_bg  =          # empty = reverse video (default)
```

### Available color names

`black` `red` `green` `yellow` `blue` `magenta` `cyan` `white`
and their bright variants: `bright_black` `bright_red` `bright_green` `bright_yellow` `bright_blue` `bright_magenta` `bright_cyan` `bright_white`

### 256-color mode

Enable with `tui_256colors = yes`. This uses `\033[38;5;N]` codes that guarantee distinct bright variants and accept numeric values 0–255:

```ini
tui_256colors   = yes
tui_col_heading = 214    # amber  #ffaf00
tui_col_comment = 136    # dark amber  #af8700
tui_col_markup  = 172    # orange-brown  #d78700
tui_col_bar_fg  = 220    # gold  #ffd700
tui_col_bar_bg  = 94     # dark brown  #875f00
tui_col_sel_bg  = 52     # dark burgundy  #5f0000
```

Useful warm-tone indices: `52` (dark burgundy), `94` (dark brown), `130` (warm brown), `136` (dark amber), `166` (rust), `172` (orange-brown), `178` (gold), `202` (red-orange), `208` (orange), `214` (amber), `220` (gold), `230` (cream).

> Note: WrithDeck has no `z` (reload) key in TUI mode. Any INI change requires a full restart.

### INI inline comments

Comments are supported on the same line as a key, after a space and `#`:

```ini
tui_colors = yes   # enable TUI colors
tui_col_heading = 214   # amber
```

Values starting with `#` (hex colors) are not affected.

---

## Known bugs and limitations

- In GUI mode, word-wrapped line endings can cause inconsistent block cursor display. Fix: set `block_cursor_gui = no` in the INI.
- In TUI mode, resizing the terminal window may produce artifacts. Opening help with Ctrl+H twice refreshes the screen.
- No no-wrap mode (not planned).
- No tab mode (not planned).
- TUI split view: the right pane shares the undo history with the left pane and has no independent syntax highlighting.
- On very long texts (over 80,000 words) on a slow CPU, cursor and typing may slow down. If needed, remove the `words` and `chars` tokens from the status bar zones.

---
---

<a name="français"></a>
# Français

## Installation

Tcl/Tk doit être installé sur votre système.

| Plateforme         | Commande / Source                                       |
| ------------------ | ------------------------------------------------------- |
| Debian/Ubuntu      | `apt install tk`                                        |
| Autre Linux/BSD    | selon le gestionnaire de paquets (`tk` ou `tcl-tk`)     |
| Mac OS             | `brew install tcl-tk`                                   |
| Windows            | https://www.tcl-lang.org/software/tcltk/bindist.html    |
| Haiku OS           | `pkgman install tcl tk`                                 |

Lancer WrithDeck :

```sh
wish writhdeck.tcl              # mode GUI
tclsh writhdeck.tcl --no-gui    # mode TUI
./writhdeck.tcl                 # exécution directe (polyglot sh/Tcl)
```

Pour un accès permanent, copier dans un dossier du PATH :

```sh
cp writhdeck.tcl /usr/local/bin/writhdeck
```

## Options de ligne de commande

| Option             | Description                                                      |
| ------------------ | ---------------------------------------------------------------- |
| `--help`, `-h`     | Afficher l'aide et quitter                                       |
| `--gui`            | Forcer le mode GUI (Tk) — ignorer la détection de l'affichage    |
| `--no-gui`         | Forcer le mode TUI (terminal)                                    |
| `--tui`, `--ng`    | Alias de `--no-gui`                                              |

Si `--gui` et `--no-gui` sont tous les deux présents, `--no-gui` a la priorité.

## Fonctionnalités

- Éditeur de fichiers `.txt` centré sur l'écriture sans distraction
- Documents stockés dans `~/Documents/writhdeck/` (créé automatiquement)
- Navigateur de fichiers : fichiers triés par date de modification, ouvrir / créer / renommer / supprimer / bloc-notes
- Affichage avec retour à la ligne automatique et marges configurables
- **Coloration syntaxique inline** (GUI et TUI) :
  - Titres : marqueur configurable (`= titre =`) et Markdown (`# titre`)
  - Commentaires : lignes commençant par `%` (`comment_marker` configurable)
  - Gras `**texte**`, italique `//texte//`, souligné `__texte__`, barré `--texte--` — tous les marqueurs configurables
  - Caractères de marquage grisés ; texte mis en forme dans une `color_markup` configurable
- Overlay table des matières : saut vers n'importe quel titre (dernière sélection mémorisée par session)
- Barre de statut : zones entièrement configurables (gauche / centre / droite) avec les jetons : `workspace filename dirty sel ln col words chars goal clock help_bar space`
- **Stats d'écriture journalières** : comptage par fichier par jour (high-water mark — les suppressions ne réduisent pas le compteur) ; les favoris conservent l'historique complet, les autres fichiers gardent seulement les données du jour
- **Objectif de mots** (jeton `goal`) : affiche la progression du jour, ex. `47/500` ; configurable via `word_goal` dans le INI ou par profil
- Aller à la ligne
- Support de la saisie UTF-8
- Position du curseur restaurée entre les sessions (`.writhdeck.json`)
- Configuration rechargée à chaque ouverture de document (pas de redémarrage nécessaire)
- Basculement thème sombre/clair (`Ctrl+D` par défaut, configurable)
- **Support multi-langue** : Anglais, Français, Allemand, Espagnol, Coréen, Norvégien (sélectionnable dans le dialogue config ou via INI)
- **Comportement unifié du navigateur** : après la fermeture d'un fichier, GUI et TUI retournent au navigateur (configurable via `browser`)
- **Bloc-notes** : tampon temporaire en mémoire, pas de fichier disque tant qu'on ne sauvegarde pas explicitement
- **Dialogue d'aide** : affiche le nombre de mots/caractères de la sélection quand du texte est sélectionné (GUI et TUI)
- **Minuterie et chronomètre** : compte à rebours ou chronomètre configurable avec affichage en temps réel et alertes visuelles/sonores
- **Mode commande modal (touche ESC)** : accès rapide à la minuterie, stats, occurrences de mots et opérations fichier sans perdre la focus du texte
- **Second espace de travail** (F10) : bascule entre deux éditeurs indépendants ; chacun préserve son fichier, son contenu et son état de modification ; indicateur `[1]`/`[2]` dans la barre de statut et la barre de titre ; en vue fractionnée (F3), F10 charge le second espace dans le volet droit (GUI et TUI)

## Configuration

`~/Documents/writhdeck/writhdeck.ini` — sections : `[editor]`, `[behaviour]`, `[keys]`, `[profiles]`, `[schemes]`

Tous les raccourcis clavier sont configurables via la section `[keys]`.

### `[editor]`

| Clé                       | Défaut        | Description                                                                |
| ------------------------- | ------------- | -------------------------------------------------------------------------- |
| `profile`                 | `default`     | Profil actif — doit correspondre à un bloc `[nom]` dans `[profiles]`       |
| `scheme`                  | `default`     | Schéma de couleurs actif — doit correspondre à un bloc dans `[schemes]`    |
| `docs_dir`                | —             | Deuxième dossier de documents optionnel (deuxième section du navigateur)   |
| `console_margin_cols`     | `6`           | Marge horizontale en colonnes (TUI uniquement)                             |
| `console_margin_rows`     | `4`           | Marge verticale en lignes (TUI uniquement)                                 |
| `heading_marker`          | `=`           | Délimiteur de titre (`= titre =`)                                          |
| `comment_marker`          | `%`           | Préfixe de commentaire ; mettre `0` ou laisser vide pour désactiver        |
| `bold_marker`             | `**`          | Marqueur gras inline ; mettre `0` ou laisser vide pour désactiver          |
| `italic_marker`           | `//`          | Marqueur italique inline ; mettre `0` ou laisser vide pour désactiver      |
| `underline_marker`        | `__`          | Marqueur souligné inline ; mettre `0` ou laisser vide pour désactiver      |
| `strikethrough_marker`    | `--`          | Marqueur barré inline ; mettre `0` ou laisser vide pour désactiver         |

### `[behaviour]`

| Clé                       | Défaut   | Description                                                                                                          |
| ------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------- |
| `browser`                 | `1`      | Retourner au navigateur après la fermeture d'un fichier                                                              |
| `watch_file`              | `1`      | Détecter les modifications externes et proposer de recharger ; `0` pour désactiver                                   |
| `split_shrink_margin`     | `1`      | Diviser `margin_width` par deux en vue fractionnée (GUI) ; `0` pour conserver la marge complète                      |
| `hemingway_mode`          | `0`      | Quand le mode machine à écrire est actif : bloquer les flèches, la suppression et l'annulation                       |
| `console_center_alert`    | `1`      | Centrer les dialogues de confirmation (TUI) ; `0` = barre du bas                                                     |
| `block_cursor_gui`        | `1`      | Curseur bloc en mode GUI                                                                                             |
| `block_cursor_console`    | `1`      | Curseur bloc en mode TUI                                                                                             |
| `blink_cursor`            | `0`      | Curseur clignotant                                                                                                   |
| `line_numbers`            | `0`      | Afficher les numéros de ligne                                                                                        |
| `cursor_restore`          | `1`      | Restaurer la position du curseur à la réouverture                                                                    |
| `lang`                    | `en`     | Langue de l'interface : `en`, `fr`, `de`, `es`, `ko`, `no` ; aussi sélectionnable dans le dialogue config (touche c) |
| `dark_mode`               | `1`      | Thème sombre ; `0` = clair                                                                                           |
| `word_goal`               | `500`    | Objectif de mots journalier affiché par le jeton `goal` ; `0` pour désactiver                                        |
| `timer_duration`          | `25`     | Durée de la minuterie en minutes (mode compte à rebours)                                                             |
| `timer_sound`             | `1`      | Jouer un bip quand la minuterie se termine ; `0` pour désactiver                                                     |
| `timer_alert`             | `1`      | Afficher une alerte visuelle quand la minuterie se termine ; `0` pour désactiver                                     |
| `timer_type`              | `countdown` | Mode minuterie : `countdown` ou `stopwatch`                                                                          |

### `[keys]`

Toutes les actions sont reconfigurables. Utiliser les noms de touches Tk (`Control-s`, `Alt-Return`, `F11`, etc.) :

`key_save` `key_close` `key_find` `key_replace` `key_goto` `key_open` `key_undo` `key_redo` `key_help` `key_toc` `key_line_numbers` `key_fullscreen` `key_split` `key_split_focus` `key_workspace` (défaut : `F10`) `key_typewriter` `key_dark_toggle` `key_timer` (défaut : `Alt-t`)

### `[profiles]`

Préréglages nommés pour l'affichage et le comportement. Chaque bloc `[nom]` peut surcharger les marges, les polices et la plupart des options. Sélectionner le profil actif avec `profile = nom` dans `[editor]`. Le profil `[default]` est toujours écrit par WrithDeck.

| Clé                          | Défaut    | Description                                                          |
| ---------------------------- | --------- | -------------------------------------------------------------------- |
| `margin_width`               | `60`      | Marge horizontale en pixels (GUI)                                    |
| `margin_height`              | `40`      | Marge verticale en pixels (GUI)                                      |
| `font_size`                  | `13`      | Taille de police (GUI)                                               |
| `font_family`                | `Mono`    | Famille de police ; Tk résout `Mono` vers la meilleure monospace     |
| `bar_font_family`            | `Mono`    | Famille de police pour la barre de statut (GUI)                      |
| `line_spacing`               | `100`     | Interligne en % (GUI)                                                |
| `bar_height`                 | `18`      | Hauteur de la barre de statut en pixels (GUI)                        |
| `word_goal`                  | `500`     | Objectif de mots journalier pour ce profil                           |
| `dark_mode`                  | —         | Surcharger thème sombre/clair par profil                             |
| `lang`                       | —         | Surcharger la langue de l'interface par profil                       |
| `status_left/center/right`   | —         | Surcharger la disposition de la barre de statut par profil           |

Exemple :

```ini
[editor]
profile = roman

[profiles]

[roman]
margin_width    = 180
margin_height   = 80
font_size       = 18
font_family     = Noto Serif
line_spacing    = 110
bar_height      = 20
word_goal       = 1000
```

### `[schemes]`

Définitions de schémas de couleurs. Chaque bloc `[nom]` définit des couleurs pour le mode sombre et le mode clair. Sélectionner avec `scheme = nom` dans `[editor]`. Le schéma `[default]` est toujours écrit par WrithDeck.

| Clé                                     | Description                                      |
| --------------------------------------- | ------------------------------------------------ |
| `color_bg` / `color_bg_alt`             | Fond de l'éditeur (sombre / clair)               |
| `color_fg` / `color_fg_alt`             | Texte de l'éditeur (sombre / clair)              |
| `color_bg_bar` / `color_bg_bar_alt`     | Fond de la barre de statut (sombre / clair)      |
| `color_fg_bar` / `color_fg_bar_alt`     | Texte de la barre de statut (sombre / clair)     |
| `color_bg_sel` / `color_bg_sel_alt`     | Fond de la sélection (sombre / clair)            |
| `color_heading` / `color_heading_alt`   | Couleur des titres (sombre / clair)              |
| `color_comment` / `color_comment_alt`   | Commentaires / lignes estompées (sombre / clair) |
| `color_markup` / `color_markup_alt`     | Couleur du balisage inline (sombre / clair)      |

Basculer entre sombre et clair avec `Ctrl+D` (configurable via `key_dark_toggle`).

Schémas intégrés : `solarized`, `gruvbox`, `everforest`, `nord`, `alt01`.

Exemple — pour utiliser Gruvbox, ajouter dans le INI :

```ini
[editor]
scheme = gruvbox
```

---

## Minuterie et chronomètre

L'éditeur inclut une minuterie compte à rebours et un mode chronomètre configurables, avec affichage en temps réel dans la barre de statut.

### Contrôle de la minuterie

**Démarrage / basculement :**
- **Touche ESC** (mode édition) : Entrer en mode commande modal, puis appuyer sur `t` pour basculer la minuterie
- **Alt+t** (défaut, configurable via `key_timer`) : Basculer la minuterie directement

**Modes :**
- **Compte à rebours** (défaut) : Compte à rebours à partir de `timer_duration` minutes, alerte à la fin
- **Chronomètre** : Compte progressif indéfini, pas d'alerte

**Affichage dans la barre de statut :**
- Format : `m'ss"` (ex. `4'00"` pour 4 minutes)
- Minuterie active : `[4'00"]` (entre crochets)
- Minuterie inactive : ` 4'00"` (espace avant)

### Comportement de l'alerte

Quand le compte à rebours atteint zéro :
1. **GUI** : Dialogue popup avec le message "Timer finished!"
2. **TUI** : Overlay plein écran avec "TIMER FINISHED!"
3. **Son** : Bip (si `timer_sound = yes` dans le INI)

L'alerte respecte le réglage `timer_alert` du INI. Si désactivée, la minuterie s'arrête sans rétroaction visuelle/sonore.

### Mode commande modal (touche ESC)

Appuyer sur **ESC** pendant l'édition pour entrer en mode commande. Cela donne un accès rapide aux fonctions courantes sans perdre la focus du texte :

| Touche | Action |
|--------|--------|
| **ESC** | Quitter le mode modal (ou le basculer) |
| **t** | Basculer la minuterie (compte à rebours ou chronomètre) |
| **s** | Afficher les stats d'écriture journalières (plein écran) |
| **w** | Afficher les occurrences de mots du document (plein écran) |
| **q** | Quitter / fermer le fichier courant (avec prompt de sauvegarde si non sauvegardé) |
| **Autres touches** | Quitter le mode modal, revenir à l'édition normale |

**GUI :** La barre de statut affiche les commandes disponibles quand le mode modal est actif.

**TUI :** La ligne de message affiche les commandes et permet la navigation avec les flèches (pour les écrans stats/mots).

---

## Mode GUI

Mode par défaut, nécessite Tk.

- Marges en pixels, taille et famille de police, interligne, couleurs configurables
- Coloration syntaxique inline : titres, commentaires, gras, italique, souligné, barré
- Numéros de ligne synchronisés avec le défilement (`line_numbers = 1`)
- Redimensionnement dynamique de la police : `Ctrl++` / `Ctrl+-`
- Basculement plein écran (défaut : `Alt+Entrée`)
- Deuxième dossier de documents optionnel (`docs_dir`)
- Horloge dans la barre de statut : ajouter le jeton `clock` à une zone de statut
- Curseur bloc : rectangle avec couleurs inversées (`block_cursor_gui = 1`)
- **Vue fractionnée verticale** (F3) : deux volets indépendants sur le même document ; F4 cycle le focus ; le volet actif est mis en évidence par une bordure
- **Mode machine à écrire / focus** (Ctrl+T) : curseur centré verticalement ; texte hors du paragraphe courant estompé
- **Mode Hemingway** (`hemingway_mode = 1`, s'active avec Ctrl+T) : écriture en avant uniquement — flèches, suppression et annulation désactivés ; barre de statut masquée ; marges doublées
- Dialogues de confirmation : `Tab` pour naviguer, `Entrée` pour confirmer, `Échap` pour annuler, `o` / `n` pour réponse directe

### Raccourcis — Éditeur

| Touche                     | Action                                                                          |
| -------------------------- | ------------------------------------------------------------------------------- |
| Ctrl+S                     | Enregistrer                                                                     |
| Ctrl+Shift+S               | Enregistrer sous… (avec confirmation d'écrasement)                              |
| Ctrl+Q                     | Fermer le fichier, retour au navigateur                                         |
| Ctrl+F                     | Rechercher (barre inline, surbrillance en direct, compteur)                     |
| Ctrl+R                     | Rechercher & Remplacer (Entrée : remplacer un, Ctrl+Entrée : tous)              |
| Ctrl+Z                     | Annuler                                                                         |
| Ctrl+Y                     | Rétablir                                                                        |
| Ctrl+T                     | Mode machine à écrire / focus (bascule)                                         |
| Ctrl+O                     | Ouvrir un fichier quelconque (dialogue système)                                 |
| Ctrl+G                     | Aller à la ligne                                                                |
| Ctrl+H                     | Dialogue d'aide (date/heure, stats du fichier, stats de sélection si texte)     |
| Ctrl+L                     | Afficher/masquer les numéros de ligne                                           |
| Ctrl+D                     | Basculer thème sombre/clair                                                     |
| Ctrl+Up / Ctrl+Down        | Sauter au paragraphe précédent / suivant                                        |
| Ctrl+Left / Ctrl+Right     | Sauter au mot précédent / suivant                                               |
| F11                        | Table des matières                                                              |
| F3                         | Basculer la vue fractionnée                                                     |
| F4                         | Vue fractionnée — cycle du focus entre les volets                               |
| F10                        | Basculer le second espace de travail (ES1/ES2) ; en vue fractionnée : charge ES2 dans le volet droit |
| Alt+Entrée                 | Basculer le plein écran                                                         |
| Tab                        | Insérer une tabulation littérale                                                |
| Shift+Up/Down/Left/Right   | Étendre la sélection                                                            |

### Notes sur le second espace de travail (GUI)

- **F10** bascule entre deux éditeurs indépendants (ES1 et ES2) ; ES2 démarre comme un bloc-notes vide
- La barre de statut affiche `[1]` ou `[2]` dès que les deux espaces sont actifs ; la barre de titre aussi
- **Ctrl+O** dans ES2 ouvre un fichier dans ES2 (n'affecte pas ES1)
- **En vue fractionnée (F3)** : F10 charge ES2 dans le volet droit comme éditeur indépendant ; F10 à nouveau cycle le focus ; F3 ferme le split en sauvegardant l'état ES2
- À la fermeture, les deux espaces sont vérifiés pour des modifications non sauvegardées
- `key_workspace = F10` est configurable dans la section `[keys]` du INI

### Raccourcis — Navigateur

| Touche                 | Action                                                                     |
| ---------------------- | -------------------------------------------------------------------------- |
| Entrée / double-clic   | Ouvrir le fichier                                                          |
| n                      | Nouveau fichier                                                            |
| t                      | Bloc-notes (tampon en mémoire ; Ctrl+S demande un nom pour enregistrer)    |
| f                      | Basculer favori                                                            |
| s                      | Stats d'écriture — comptages journaliers                                   |
| b                      | Sauvegarder — copie dans `backups/` avec horodatage `nom_YYYY-MM-DDTHHhMMmSS` |
| d                      | Supprimer le fichier                                                       |
| r                      | Renommer le fichier                                                        |
| i                      | Afficher le chemin complet                                                 |
| c                      | Configuration — profils, polices, marges, couleurs, langue                 |
| z                      | Recharger — relancer WrithDeck (retour au browser)                         |
| h / Ctrl+H             | Aide                                                                       |
| Ctrl+O                 | Ouvrir un fichier quelconque (dialogue système)                            |
| Ctrl+D                 | Basculer thème sombre/clair                                                |
| Alt+Entrée             | Basculer le plein écran                                                    |
| q                      | Quitter                                                                    |

### Notes sur la vue fractionnée

- F3 divise le document en deux volets côte à côte ; appuyer à nouveau sur F3 pour fermer
- Les deux volets partagent le même texte — les modifications sont immédiatement visibles dans les deux
- Le curseur, la position de défilement et l'historique d'annulation sont indépendants par volet
- Recherche, Remplacement, Aller à la ligne et la table des matières opèrent sur le volet actif
- Les numéros de ligne sont masqués quand la vue fractionnée est active
- **F10 en vue fractionnée** : remplace le volet droit par un éditeur ES2 indépendant (fichier différent) ; F10 à nouveau cycle le focus ; Ctrl+S et Ctrl+O dans le volet droit opèrent sur ES2

---

## Mode TUI

Activé via `--no-gui` / `--tui` / `--ng`, ou si aucun système de fenêtrage n'est disponible. TTY/terminal pur via séquences ANSI.

- Ensemble de fonctionnalités identique au mode GUI, rendu dans le terminal
- Navigateur avec marqueur de sélection `»` ; en-têtes de section pour le mode double-dossier
- Navigation style Vim (j/k) + touches fléchées, Début/Fin, PgPréc/PgSuiv
- Indicateur de défilement : barre `▐/│` dans la colonne de droite quand le contenu déborde
- Numéros de ligne en colonne de gauche (`line_numbers = 1`), sur la première ligne visuelle de chaque paragraphe
- Forme du curseur configurable : bloc ou barre, clignotant ou fixe
- **Vue fractionnée verticale** (F3) : deux volets avec curseur, défilement et édition indépendants ; F4 cycle le focus ; si ES2 était déjà activé, F3 ouvre directement volet gauche = ES courant / volet droit = autre ES
- **Mode machine à écrire / focus** (Ctrl+T) : curseur centré verticalement ; texte hors du paragraphe courant estompé
- **Mode Hemingway** (`hemingway_mode = 1`, s'active avec Ctrl+T) : bloque les flèches, la suppression et l'annulation ; double les marges

### Raccourcis — Éditeur

| Touche                                  | Action                                                              |
| --------------------------------------- | ------------------------------------------------------------------- |
| Ctrl+S                                  | Enregistrer (bloc-notes : demande un nom de fichier d'abord)        |
| Ctrl+Q / Échap                          | Fermer le fichier, retour au navigateur                             |
| Ctrl+F                                  | Rechercher (invite ; répéter pour trouver le suivant)               |
| Ctrl+R                                  | Rechercher & Remplacer (global, avec compteur de remplacements)     |
| Ctrl+Z                                  | Annuler (pile de 100 états)                                         |
| Ctrl+Y                                  | Rétablir                                                            |
| Ctrl+T                                  | Mode machine à écrire / focus (bascule)                             |
| Ctrl+O                                  | Enregistrer et retourner au navigateur (en ES2 : ouvre le navigateur pour choisir un nouveau fichier pour ES2) |
| Ctrl+G                                  | Aller à la ligne                                                    |
| Ctrl+H                                  | Aide                                                                |
| Ctrl+L                                  | Afficher/masquer les numéros de ligne                               |
| Ctrl+D                                  | Basculer thème sombre/clair (vidéo inverse)                         |
| Ctrl+Up / Ctrl+Down                     | Sauter au paragraphe précédent / suivant (émulateur uniquement)     |
| Ctrl+Left / Ctrl+Right ou Alt+B / Alt+F | Sauter au mot précédent / suivant                                   |
| F3                                      | Basculer la vue fractionnée                                         |
| F4                                      | Vue fractionnée — cycle le focus entre les volets                   |
| F10                                     | Basculer le second espace de travail (ES1/ES2) ; en vue fractionnée : charge ES2 dans le volet droit |
| F11                                     | Table des matières (Échap / Ctrl+Q pour fermer, Entrée pour sauter) |
| Ctrl+A                                  | Tout sélectionner                                                   |
| Ctrl+K                                  | Sélection collante (1er appui : ancre ; 2e appui : annuler)         |
| Shift+Up/Down/Left/Right                | Étendre la sélection                                                |
| Ctrl+C                                  | Copier (via xclip / xsel / wl-copy)                                 |
| Ctrl+X                                  | Couper                                                              |
| Ctrl+V                                  | Coller (multiligne supporté)                                        |
| Tab                                     | Insérer tabulation littérale                                        |

### Notes sur le second espace de travail (TUI)

- **F10** bascule entre ES1 et ES2 ; ES2 démarre comme un bloc-notes vide
- **F3** ouvre une vue fractionnée : si ES2 était déjà activé, volet gauche = espace courant, volet droit = autre espace ; sinon, split même-fichier ; **F3** à nouveau ferme le split
- **F4** cycle le focus entre les volets ; les deux volets sont entièrement indépendants (curseur, défilement, édition)
- **F10 en vue fractionnée** (même-fichier) : charge ES2 dans le volet droit ; F10 à nouveau cycle le focus
- La barre de statut affiche `[1]` ou `[2]` dès que les deux espaces sont actifs ; le volet droit affiche un en-tête en vidéo inverse avec le numéro d'espace et le nom de fichier
- **Ctrl+O dans ES2** : enregistre le fichier ES2 courant, ouvre le navigateur pour en choisir un nouveau ; le fichier choisi se charge dans ES2 (ES1 n'est pas affecté)
- À la fermeture (`q` dans le navigateur), les deux espaces sont vérifiés pour des modifications non sauvegardées
- Remarque : le volet droit partage l'historique d'annulation du volet gauche et n'a pas de coloration syntaxique indépendante

### Raccourcis — Navigateur

| Touche         | Action                                                                     |
| -------------- | -------------------------------------------------------------------------- |
| Entrée         | Ouvrir le fichier                                                          |
| n              | Nouveau fichier                                                            |
| t              | Bloc-notes (tampon en mémoire ; Ctrl+S demande un nom pour enregistrer)    |
| f              | Basculer favori                                                            |
| s              | Stats d'écriture — comptages journaliers                                   |
| b              | Sauvegarder — copie dans `backups/` avec horodatage `nom_YYYY-MM-DDTHHhMMmSS` |
| d              | Supprimer le fichier                                                       |
| r              | Renommer le fichier                                                        |
| i              | Afficher le chemin complet                                                 |
| c              | Configuration — profils, polices, marges, couleurs, langue                 |
| z              | Recharger — relancer WrithDeck (retour au browser)                         |
| h / Ctrl+H     | Aide                                                                       |
| q / Ctrl+Q     | Quitter                                                                    |

---

## Bugs connus et limitations

## Couleurs TUI

L'éditeur TUI supporte les couleurs ANSI compatibles avec les émulateurs de terminal et le TTY Linux. Les couleurs sont désactivées par défaut.

### Activer les couleurs

Ajouter la section `[tui_colors]` dans `~/.writhdeck.ini`, puis relancer WrithDeck :

```ini
[tui_colors]
tui_colors      = yes
tui_col_heading = cyan
tui_col_comment = green
tui_col_markup  = magenta
tui_col_bar_fg  = black
tui_col_bar_bg  = cyan
tui_col_sel_bg  =          # vide = vidéo inverse (défaut)
```

### Noms de couleurs disponibles

`black` `red` `green` `yellow` `blue` `magenta` `cyan` `white`
et leurs variantes lumineuses : `bright_black` `bright_red` `bright_green` `bright_yellow` `bright_blue` `bright_magenta` `bright_cyan` `bright_white`

### Mode 256 couleurs

Activer avec `tui_256colors = yes`. Garantit des variantes bright distinctes et accepte les valeurs numériques 0–255 :

```ini
tui_256colors   = yes
tui_col_heading = 214    # ambre  #ffaf00
tui_col_comment = 136    # ambre sombre  #af8700
tui_col_markup  = 172    # orange brun  #d78700
tui_col_bar_fg  = 220    # or  #ffd700
tui_col_bar_bg  = 94     # brun sombre  #875f00
tui_col_sel_bg  = 52     # bordeaux sombre  #5f0000
```

> Note : WrithDeck n'a pas de touche `z` (rechargement) en mode TUI. Tout changement de INI nécessite un redémarrage complet.

---

## Bugs connus et limitations

- En mode GUI, les fins de ligne dans un texte avec retour à la ligne automatique peuvent entraîner un affichage incohérent du curseur bloc. Correctif : `block_cursor_gui = no` dans le INI.
- En mode TUI, lors du redimensionnement de la fenêtre de terminal, des artefacts peuvent apparaître. Ouvrir l'aide avec Ctrl+H deux fois rafraîchit l'écran.
- Pas de mode sans retour à la ligne (non prévu).
- Pas de mode tabulation (non prévu).
- Vue fractionnée TUI : le volet droit partage l'historique d'annulation avec le volet gauche et n'a pas de coloration syntaxique indépendante.
- Sur des textes très longs (plus de 80 000 mots) et un CPU lent, le curseur et la frappe peuvent ralentir. Si nécessaire, retirer les jetons `words` et `chars` des zones de la barre de statut.
