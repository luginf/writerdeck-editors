# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the program

```sh
wish writhdeck.tcl                     # GUI (Tk required)
wish writhdeck.tcl file.txt            # GUI, open file directly
tclsh writhdeck.tcl --tui              # TUI (--cli is an alias)
tclsh writhdeck.tcl --cli file.txt     # TUI, open file directly
./writhdeck.tcl --tui                  # polyglot sh/Tcl bootstrap, TUI mode
```

Build with `make` to generate `writhdeck.tcl` and `writhdeck-cli.tcl` from source modules in `src/`. Both generated files are executable and tracked in git. Dependencies: Tcl/Tk 8.5+ through 9.x (Tk only required for GUI mode).

Run tests to catch regressions:
```sh
make test              # Run all regression tests
make test-i18n        # Validate translations
make test-syntax      # Check Tcl syntax
make test-gui         # Test GUI build
make test-cli         # Test CLI build
```

Generate compact builds (comments, blank lines, and leading whitespace stripped):
```sh
make compact           # writhdeck-compact.tcl + writhdeck-cli-compact.tcl (~-20 to -25%)
make compact-cli       # writhdeck-cli-compact.tcl only
```

## Version

Format `vYYYYMMDD` (e.g. `v20260512`), defined near line 32:
```tcl
set ::version "v20260513"
```
Update it on every functional change.

## Generated file structure

After `make`, the generated `writhdeck.tcl` contains these sections (concatenated from source modules):

| Section     | Source module    | Lines     | Content                                                                    |
| ----------- | ---------------- | --------- | -------------------------------------------------------------------------- |
| Bootstrap   | `src/boot.tcl`   | 1–80      | Polyglot sh/Tcl, args, Tk detection, `::HOME_DIR`, `tilde-expand`          |
| State       | `src/state.tcl`  | 81–228    | `.writhdeck.json` persistence, cursors, favorites, recents, daily stats    |
| Config      | `src/config.tcl` | 229–1033  | INI loading/saving, profiles, schemes, keys, i18n system, theme init       |
| Common      | `src/common.tcl` | 1034–1238 | `list-docs`, `br-dirs`, `do-backup`, `build-extra-entries`, inline parsers |
| **GUI**     | `src/gui.tcl`    | 1239–3240 | Wrapped in `if {!$::no_gui}` — browser, editor, dialogs, TOC, split view   |
| **TUI**     | `src/tui.tcl`    | 3241–4885 | Terminal UI — `tui-init`, `tui-browser`, `tui-editor`, `tui-main`, helpers |
| Entry point | `src/main.tcl`   | 4886–4917 | Dispatch: `if {$::no_gui}` → TUI, else → GUI                               |

The GUI block (`src/gui.tcl`) is wrapped in `if {!$::no_gui} { ... }` at build time, so CLI builds exclude it entirely.

### Section headers

Generated files have readable section headers:
```tcl
# ===================================================================
# state.tcl
# ===================================================================
```
These markers help navigate the ~5000-line file during development.

## Key rules

**Absolute paths everywhere** — all paths stored in `.writhdeck.json` must be absolute. Call `file normalize $path` at the top of any proc that reads or writes a path (`cursor-get/put`, `recent-push/remove/rename`, `toggle-favorite`, `daily-open`, `daily-clear`).

**`tilde-expand` before `file normalize`** — Tcl 9 no longer expands `~` in `file normalize`. Always call `tilde-expand $path` first when the path comes from user input (config file, prompts). The proc is defined after `::HOME_DIR` near line 110.

**Procs shared between GUI and TUI must be defined outside the `if {!$::no_gui}` block.** Currently outside: all `state-*`, `daily-*`, `recent-*`, `build-extra-entries`, `toggle-favorite`, `do-backup`, `get-word-occurrences`.

**`get-word-occurrences {fpath}`** — returns a list of `{word count}` pairs sorted by count descending. Opens with `-encoding utf-8`, reads, and closes the file itself. Callers iterate with `foreach pair $word_data { lassign $pair word count }` — do not re-read the file.

**`do-backup {dir name}`** — copies to `$DOCS_DIR/backups/` with timestamp `%Y-%m-%dT%Hh%Mm%S` (includes seconds). Returns the full destination path `$dst`. Success message shows `[string map [list $::HOME_DIR ~] [file dirname $dst]]` (the backup folder path with ~ substitution).

**i18n — always add both languages.** Any new string key must appear in both `en {}` and `fr {}` blocks of `::i18n`. Use `proc t {key args}` to retrieve.

**`chan configure` not `fconfigure`.** The codebase uses `chan configure` throughout (Tcl 8.5+ compatible, not deprecated in Tcl 9).

| **No Unicode symbols or em-dashes in user-visible strings.** Use ASCII equivalents: `->` not `→`, `-` not `—`, `[+]`/`[-]` not `★`/`☆`, ` | ` not `·`, etc. French accented characters (é, à, è, ê, É…) are the only intentional non-ASCII. This applies to i18n strings, help text, status bar, and all TUI output. |

## Browser shortcuts and status bar

The browser status bar displays shortcuts with bold formatting on the first character:
- `h:help`, `n:new`, `t:scratchpad`, etc. — letter is bold, colon and label follow
- Built using a hardcoded foreach loop inserting pairs of bold key + label text
- Click handler uses `.br.bar.help tag bind` for each shortcut to invoke the command
- Cursor changes to hand2 on hover (Enter/Leave bindings)

Current browser keys (12 total): h (help), n (new), t (scratchpad), f (favorite), s (stats), b (backup), d (delete), r (rename), i (info), c (config), z (reload), q (quit).

## Adding a new browser key

6 places to update:
1. `br_help_gui` i18n (EN + FR)
2. `br_help_tui` i18n (EN + FR)
3. Add to the status bar foreach loop in browser frame init (`.br.bar.help`)
4. `bind .br.mid.lst <x>` in the GUI block (for keyboard binding)
5. `switch -- $key` in `tui-browser`
6. BROWSER section of `help-dialog`
7. Browser shortcut tables in `README.md` and `README.fr.md`

## Profile configuration dialog

Accessible via `c` key in browser. Invoked by `profile-config-dialog` proc:
- **Global settings frame**: Dropdown to select active profile + dropdown to select color scheme
- **Profile settings frame**: Controls for font family (listbox), font size (spinbox), margin width (spinbox), margin height (spinbox)
- **Font preview**: Real-time Text widget showing sample text in selected font
- **Apply button**: Saves settings to `$::cfg_profiles[$profile]` dict, applies to editor if active, and triggers browser reload

Per-profile configuration stored in `::cfg_profiles` dict with keys: `font_family`, `font_size`, `margin_width`, `margin_height`. Values persist across sessions via `.writhdeck.json` (loaded by `ini-load`).

Key implementation details:
- Uses `-command` option on spinbox to trigger preview updates on button clicks (not just keyboard entry)
- `profile-apply-fonts` helper saves to dict and applies to editor frame
- `br-refresh` called after apply to reload browser with fresh configuration
- Dialog created inside a toplevel window with grid layout, destroyed after user closes

## State persistence (`.writhdeck.json`)

Hand-rolled JSON (no external parser):
```json
{
  "cursors":   {"path": [cy, cx]},
  "favorites": ["path"],
  "recent":    ["path"],
  "daily":     ["path\tYYYY-MM-DD\tN\tYYYY-MM-DD\tN..."]
}
```
- One `daily` entry per file; all its dates packed as `\t`-separated pairs after the path.
- `\t` is written as the two-char JSON escape sequence `\t`, not a literal tab (which is invalid JSON).
- `state-parse-array` uses `regexp -indices` to find quoted strings in raw JSON, extracts them using `string range`, then `state-load` calls `string map [list {\t} "\t"]` before `split`. This correctly handles escape sequences without attempting to match unescaped content. Note: `{\t}` in Tcl braces is 2 chars (backslash + t), not 1 — do not write `{\\t}` (3 chars) by mistake.
- `state-load` / `state-save` rewrite the whole file each time.
- `state-load` has a guard (`$::state_cache_valid`) — call `set ::state_cache_valid 0` to force reload.
- Daily stats use a high-water mark: word deletions never reduce the count.

## Browser entry types (`::br_entries`)

| Type       | Notes                                                                                                |
| ---------- | ---------------------------------------------------------------------------------------------------- |
| `header`   | Section separator. `dir=""` → label = `name` field (Favorites, Recents). `dir≠""` → abbreviated path |
| `file`     | File in a watched folder                                                                             |
| `favorite` | Pinned file (any folder)                                                                             |
| `recent`   | Recent file outside watched folders (deduplicated)                                                   |

Section order: `DOCS_DIR_DEFAULT` → `DOCS_DIR` (if custom) → Favorites → Recents.
`br-active-dir` walks up to the nearest `header`; if `dir=""` returns `DOCS_DIR_DEFAULT`.

## GUI-specific patterns

**Help dialog close** — use `after idle [list destroy $w]; break` on keyboard bindings inside the Text widget; plain `destroy` triggers `<<TkTextBackspace>>` on the already-destroyed widget.

**`grab $w` after `update`** — in Toplevel dialogs, `grab $w` must be called only after `update` and after all widgets are packed. Calling it immediately after `toplevel $w` (before any widgets exist) fails with "grab failed: window not viewable".

| **`quit-app`** — only prompts to save if `$::filename ne "" |  | $::scratchpad`. |

**`open-file-dialog`** — uses `[file dirname $::filename]` as `initialdir` when a file is open, otherwise `DOCS_DIR_DEFAULT`.

## Editor behavior

**Tab key** — inserts a literal tab character (`\t`), not spaces. Both GUI and TUI preserve tabs in files. In split pane bindings, always use `{%W insert insert "\t"; break}` — **never** `[list $w insert insert {\t}]` which would insert the 2-char literal `\t` instead (braces prevent escape interpretation).

**Reload (z key)** — closes current editor/scratchpad and returns to browser. Always relaunches the program without arguments, even if a file was open. Uses platform-specific process launching (Windows `start` command, Unix shell background execution). Configuration apply button also triggers reload.

**GUI copy/cut** — `bind $w <c>` in `bind-cmd-mode` intercepted Ctrl+C because in Tk a modifier-less binding matches all modifier states, and widget-level bindings override class-level `<<Copy>>`. Fix: explicit `<$::cfg_key_copy>` and `<$::cfg_key_cut>` bindings registered both on `.ed.t` (main section) and inside `bind-cmd-mode` (covers split/WS2 panes). Uses `tk_textCopy %W` / `tk_textCut %W`.

## INI parser

**Inline comments** — `regsub {\s+#.*$}` is applied on the already-trimmed value: `set v [regsub {\s+#.*$} [string trim $val] {}]`. Trim first, then strip — this preserves values that start with `#` (hex colors like `#1a1a1a`) while stripping `# comment` that follows whitespace.

**Boolean values** — `ini-save` writes `yes`/`no` for all 17 boolean settings using `[expr {$::cfg_xxx ? "yes" : "no"}]`. All forms are accepted on load via `string is true $v`: `yes`, `no`, `1`, `0`, `true`, `false`, `on`, `off`.

## Timer and stopwatch

Configurable countdown timer and stopwatch accessible via modal command mode or ALT+t keybinding:

**Configuration** (`src/config.tcl`):
- `cfg_timer_duration` — default duration in minutes (25 default)
- `cfg_timer_sound` — play bell sound on completion (boolean)
- `cfg_timer_type` — "countdown" or "stopwatch"
- `cfg_timer_alert` — show alert dialog on completion (boolean)

**Status bar display:**
- Timer displays as `m'ss"` format (e.g., `4'00"` for 4 minutes)
- Active timer shows as `[4'00"]`, inactive as ` 4'00"`
- Handled by `status-build` proc in `src/common.tcl` (token: "timer")

**Timer control procs** (`src/config.tcl`):
- `timer-start` — start countdown/stopwatch
- `timer-pause` — pause timer (resume with timer-start)
- `timer-reset` — reset to configured duration
- `timer-tick` — background update (called by `after` every second)
- `timer-alert` — show alert when countdown reaches zero

**Alert implementation:**
- **GUI** (`timer-alert-gui`): Toplevel dialog with "Timer finished!" message + `bell` command
- **TUI** (`tui-timer-alert`): Full-screen overlay with "TIMER FINISHED!" message + `bell` command
- Sound controlled by `$::cfg_timer_sound` setting

## TUI dialogs — pattern no-flicker

TUI dialogs (config, help, stats, words) must not clear the screen on each redraw. The correct pattern:
1. `puts -nonewline "\033\[2J\033\[H"; flush stdout` — once **before** the `while 1` loop (clears previous content)
2. `puts -nonewline "\033\[H"` — inside the loop (cursor home, no erase; lines are overwritten with `\033\[K`)
3. No `\033\[2J` after the loop — the caller (browser or editor) redraws its own content

**`tui-getch` blocking** — when called with default argument (no timer active), performs a true blocking `read stdin 1` instead of returning `""` immediately. This keeps the cursor visible until the user types. When timer is active (`cfg_chrono_show`), uses 50ms poll to allow timer display updates.

**TUI dialog procs** (defined in `src/tui.tcl`):
- `tui-info-dialog {text rows cols}` — centered reverse-video overlay, waits for any key. Used by browser `i` key (full path) and `tui-word-occurrences` (no words found).
- `tui-stats-dialog {filepath rows cols}` — writing stats overlay: sorted by date descending, reverse-video headers, total line, `c` to clear, `q`/Ctrl+H to close. Returns `[t br_stats_no_data]` if no data (caller sets status message).
- `tui-word-occurrences {fpath rows cols}` — scrollable word occurrences overlay (UP/DOWN/HOME/END), `q` to close. Scroll bounds: `max(0, total - usable)` to avoid negative indices when content fits on one screen.

**Browser `i` key (TUI)** — calls `tui-info-dialog` (persistent overlay) instead of setting the `msg` variable. `msg` is cleared after one loop tick; for persistent display an overlay is required.

## Modal command mode

Editor mode activated by pressing the command-mode key (default: ESC) in the editor (GUI or TUI). Allows quick access to common functions without breaking focus from text.

**Configurable key** — set `key_cmd_mode` in `[keys]` section of `~/.writhdeck.ini` (default: `Escape`). Uses the same Tk key name format as other keys (`Control-e`, `F12`, etc.). The INI value maps through `tk-key-to-tui` → `$::cfg_tui_cmd_mode` (TUI) and `<$::cfg_key_cmd_mode>` binding (GUI). Label for display: `$::cfg_lbl_cmd_mode`.

**Modal mode features:**
- **cmd-mode key** — toggle modal on/off (press again to exit)
- **t** — toggle timer on/off
- **s** — show daily writing statistics (calls `daily-update` first to include unsaved words, then `tui-stats-dialog` / `file-stats-dialog`)
- **w** — show word occurrences — calls `tui-word-occurrences` (same overlay as browser `w`)
- **q** — quit/close current file (with save prompt if dirty)
- **Other keys** — exit modal, revert to normal text entry

**Implementation details:**
- State tracked by `$::gui_cmd_mode` (GUI) and `$::tui_cmd_mode` (TUI)
- Status message: `"$::cfg_lbl_cmd_mode: exit mode  t: timer  q: quit  s: stats  w: words"`
- GUI binding: `proc bind-cmd-mode {w}` in `src/gui.tcl` — sets all command-mode bindings (cfg_key_cmd_mode, t/T/c/C/q/Q/s/S/w/W, Alt-t, Any-KeyPress) on widget `$w`. Called for `.ed.t`, `split-make-pane` peer panes, and `split-ws2-open` independent pane.
- TUI: `$key eq $::cfg_tui_cmd_mode` in editor key handler
- After closing `s`/`w` overlay: `set wrap_dirty 1` forces editor redraw (TUI)

## Second workspace (F10)

Two independent editor workspaces accessible via `key_workspace` (default F10). Only one workspace is visible at a time in the editor; the other is preserved in memory.

**State variables** (`src/config.tcl`):
- `::ws_n` — active workspace number (1 or 2)
- `::ws_dual_mode` — set to 1 the first time F10 is pressed; controls `[1]`/`[2]` display in status bar and title
- `::ws1_filename`, `::ws1_scratchpad`, `::ws1_dirty`, `::ws1_content`, `::ws1_cursor`, `::ws1_file_mtime` — saved state of WS1 when WS2 is active
- `::ws2_*` — same set for WS2 (initialized with `ws2_scratchpad=1` so WS2 starts as empty scratchpad)
- `::split_ws2_mode` — 1 when right split pane shows WS2 independently

**GUI — key procs** (`src/gui.tcl`):
- `workspace-toggle` — saves active workspace to ws{n}_*, loads other workspace into `.ed.t`; in split mode redirects to `split-ws2-open`/`split-cycle-focus`; sets `ws_dual_mode=1`; cancels/restarts watch-file timer with correct `file_mtime_known`
- `ed-update-title` — shows `[1]`/`[2]` in window title when `ws_dual_mode==1`
- `split-pane-padding` — returns `{padx_in padx_out pady_in pady_out}` for pane widgets; shared by `split-make-pane` and `split-ws2-open`
- `split-ws2-open` — replaces the right peer pane with an independent `text` widget loaded with WS2 content; sets `split_ws2_mode=1`; has own save/open/close bindings
- `split-ws2-save`, `split-ws2-save-as`, `split-ws2-load-file`, `split-ws2-save-state` — WS2 pane operations
- `ws-check-inactive-dirty` — called by `quit-app`; prompts to save the inactive workspace if dirty; writes directly from `ws{n}_content`
- `open-file-dialog` — detects `split_ws2_mode && focus eq .ed.pw.r.t` and routes Ctrl+O to WS2

**Status bar token** `workspace` (`src/common.tcl`): appends `[ws_n] ` when `ws_dual_mode==1`; added at front of `cfg_status_left` default.

**Quit handling:**
- `quit-app` calls `ws-check-inactive-dirty` after the active-workspace prompt
- Browser `q` and status bar `q` button call `quit-app` (not `exit` directly)
- ESC+q modal calls `close-editor` (returns to browser in same process); quit-app is called when user quits from browser
- `br-reload` uses `after 200 exit` for app restart — never call it for close-editor flow

**Rules:**
- `show-editor` resets `ws_n=1` only when `.br` is mapped (`winfo ismapped .br`)
- `close-editor` saves WS2 state if `ws_n==2` but does NOT reset `ws_n` (preserves context for quit-app to check inactive workspace)
- `open-scratchpad` always resets `ws_n=1`

**TUI — key procs** (`src/tui.tcl`):
- `tui-ws-run {fp}` — wrapper loop; handles `__ws_toggle__` (F10) and `__ws2_open__` (Ctrl+O in WS2); sets `ws_dual_mode=1` on first toggle
- `tui-editor` returns `"__ws_toggle__"` on F10, `"__ws2_open__"` on Ctrl+O when `ws_n==2`
- On `__ws2_open__`: `tui-ws-run` shows browser, user picks file, re-enters `tui-editor` with `ws_n` still 2
- `tui-ws-check-inactive-dirty {rows cols}` — TUI counterpart of `ws-check-inactive-dirty`; called in browser `q`, editor Ctrl+W, and editor ESC+q
- `tui-split-save-right` — saves the right pane state (split_r_*) to ws1_*/ws2_* before closing split or returning from editor

**TUI split view — état actuel et limitations** (`src/tui.tcl`):
- F3 ouvre le split : si `ws_dual_mode==1` (WS2 déjà activé), charge WS2 directement dans le panneau droit (`split_ws2_mode=1`) comme en GUI ; sinon, split même-fichier
- F4 bascule le focus entre les deux panneaux (quel côté reçoit le curseur)
- Les deux panneaux sont **indépendants** : curseurs et scrolls distincts. En mode même-fichier, taper du texte modifie le contenu partagé à la position du curseur actif.
- F10 en split (mode même-fichier) charge WS2 dans le panneau droit (`split_ws2_mode=1`) ; F10 en split+WS2 cycle le focus
- **`_fswap`** : quand `split_focus==2`, échange le contexte de navigation (`cy/cx/vrows/ish_cache/isd_cache/scroll_y/layout_cache/tw`) plus le contenu (`lines/dirty/filepath`) en mode WS2, avant le traitement des touches. Valeur : `1` (même-fichier) ou `2` (WS2). Les appels `tui-split-save-right` dans les handlers terminaux utilisent `$_fswap==2 ? $lines : $split_r_lines` pour extraire les bonnes données.
- **Limitation connue : pas d'undo stack propre au panneau droit** (WS2 et même-fichier partagent l'undo stack du panneau gauche).
- **Limitation connue : pas de coloration syntaxique indépendante** dans le panneau droit (contrairement au GUI).
- Variables état split TUI (locales à `tui-editor`) : `split`, `split_ws2_mode`, `split_focus`, `split_r_lines`, `split_r_cy/cx/scroll/dirty/fp/vrows/ish/isd/layout/prev_tw/wrap_dirty`, `split_r_vi`, `split_r_scx`, `_fswap`

## Color schemes

Scheme files live in `src/schemes/` — one `.tcl` file per scheme, auto-detected by the Makefile (`AVAILABLE_SCHEMES`). Each file calls `dict set ::scheme_defs NAME { ... }` with 18 color keys:

| Key | Description |
|-----|-------------|
| `color_bg` / `color_bg_alt` | Background (dark / light) |
| `color_fg` / `color_fg_alt` | Text foreground (dark / light) |
| `color_bg_bar` / `color_bg_bar_alt` | Status bar background |
| `color_fg_bar` / `color_fg_bar_alt` | Status bar foreground |
| `color_bg_sel` / `color_bg_sel_alt` | Selection background |
| `color_heading` / `color_heading_alt` | Heading color |
| `color_comment` / `color_comment_alt` | Comment/dim color |
| `color_markup` / `color_markup_alt` | Inline markup color |
| `color_bg2` / `color_bg2_alt` | Editor frame outer background (falls back to `color_bg` if absent) |

**Available schemes and their canonical references:**

| Scheme | Reference | Notes |
|--------|-----------|-------|
| `default` | WrithDeck built-in | Defined in `src/schemes/default.tcl` and written to INI by `ini-save` |
| `solarized` | Ethan Schoonover — ethanschoonover.com/solarized | All base colors canonical; `color_bg_sel` (#004555) is a custom choice |
| `gruvbox` | morhetz — github.com/morhetz/gruvbox | Fully canonical |
| `everforest` | sainnhe — github.com/sainnhepark/everforest | Dark medium variant; comment greys are reasonable approximations |
| `nord` | Arctic Ice Studio — nordtheme.com | Fully canonical (nord0–nord10 palette) |
| `alt01` | WrithDeck built-in | Dark red/bordeaux palette |
| `alt02` | WrithDeck built-in | Warm brown/orange palette (derived from alt01 variant) |
| `retro` | WrithDeck built-in | Dark: phosphor green (#33ff33) on near-black (#0a0a0a); light: black on white |

**RULE — never modify color values without asking the user explicitly.** Color choices are deliberate aesthetic decisions. When working on scheme files, only change what the user has explicitly approved.

**Selection text color** — always pair `-selectbackground $bg_sel` with `-selectforeground $fg` on every Tk Text widget. Without `-selectforeground`, Tk inverts the text color in dark mode, making selected text unreadable. Required on all Text widget creations: `.br.mid.lst`, `.br.bar.help`, `.ed.t`, `.ed.ln`, dialog text widgets (`$w.t` in info/stats/help dialogs), `split-make-pane` peer widgets, `split-ws2-open` independent widget. Also needed in `theme-reload` configure calls (~lines 1303, 1336).

## TUI colors (`[tui_colors]` INI section)

ANSI 16-color palette for TUI/TTY mode. Disabled by default (`tui_colors = no`).

**Config keys** (`src/config.tcl` defaults, `[tui_colors]` section in INI):
- `tui_colors` — `yes`/`no` master switch
- `tui_col_heading` — heading lines (`#` marker) → default `cyan`
- `tui_col_comment` — comment/dim lines (`//`, `>`) → default `green`
- `tui_col_markup` — inline bold/italic markers → default `magenta`
- `tui_col_bar_fg` / `tui_col_bar_bg` — status bar fg/bg → default `black` / `cyan`
- `tui_col_sel_bg` — selection background (empty = reverse video) → default empty

**Color names**: `black red green yellow blue magenta cyan white` + `bright_black bright_red bright_green bright_yellow bright_blue bright_magenta bright_cyan bright_white`.

**Implementation** (`src/tui.tcl`):
- `tui-ansi-color {name is_bg}` — converts color name or numeric index to ANSI escape. In 16-color mode: `3x`/`9x` fg, `4x`/`10x` bg. In 256-color mode: `38;5;N` fg, `48;5;N` bg. Returns `""` for unknown names.
- `tui-attr heading` / `tui-attr dim-text` — emit color when `cfg_tui_colors` is on
- `tui-attr sel` — emits `sel_bg` color or falls back to reverse video (`\033[7m`)
- `tui-bar` — uses `bar_fg`/`bar_bg` colors instead of reverse video
- `tui-inline-esc` — includes `markup` color in inline span escapes; uses `sel_bg` for selection instead of code 7

**256-color mode** (`tui_256colors = yes`): uses `\033[38;5;Nm]` / `\033[48;5;Nm]`. Named colors map to indices 0-15 (same palette, always distinct). Numeric values 0-255 accepted directly in INI (e.g. `tui_col_heading = 214` for orange). Note: `bright_*` in 16-color mode may look identical to the normal variant on some TTY (terminal-palette dependent); 256-color mode guarantees the distinction.

**RULE** — `tui-attr dim` (typewriter focus, line numbers, separators) is always dim regardless of color settings. Only `dim-text` (comment marker lines) uses the comment color.

**Activation** — éditer `~/.writhdeck.ini` manuellement (`tui_colors = yes`) puis relancer le programme. La touche `z` (reload) n'existe que dans le browser GUI ; le TUI n'a pas d'équivalent — tout changement INI nécessite un redémarrage complet.

## Known limitations

- No emoji support in GUI (Tk 8.6 color font limitation)
- TUI mode blocked on Windows (`stty` absent)
- No no-wrap mode (not planned)
- Split view GUI only (TUI adaptation not planned yet)
- `font_weight` not exposed in INI (removed, unreliable across fonts)
- TUI split view : l'affichage du panneau droit peut être perturbé si le fichier contient des tabulations (les tabs sont expansés en 4 espaces dans le panneau gauche mais pas compensés dans le rendu droit)

## Git & commits

**Never commit on behalf of the user.** Always let the user decide when and how to commit. Prepare changes but wait for explicit instruction before running `git commit`.

## Module structure and builds

The codebase is organized in `src/` directory and built via `Makefile`:

| Module             | Lines | Content                                                             |
| ------------------ | ----- | ------------------------------------------------------------------- |
| `src/boot.tcl`     | ~80   | Polyglot sh/Tcl, args parsing, Tk detection, HOME_DIR setup         |
| `src/boot-cli.tcl` | ~80   | CLI variant: no Tk loading, forces `::no_gui 1`                     |
| `src/state.tcl`    | ~147  | JSON state persistence, cursors, favorites, recents, daily stats    |
| `src/config.tcl`   | ~804  | INI loading/saving, profiles, color schemes, keys, i18n, theme init |
| `src/common.tcl`   | ~204  | Docs listing, backup, inline parsers, browser entry building        |
| `src/gui.tcl`      | ~2001 | Full GUI (Tk) block — wrapped in `if {!$::no_gui}`                  |
| `src/tui.tcl`      | ~1644 | TUI mode code — terminal UI, browser, editor                        |
| `src/main.tcl`     | ~31   | Entry point dispatch (GUI or TUI based on `$::no_gui`)              |
| `src/main-cli.tcl` | ~2    | CLI entry point (always calls `tui-main`)                           |

**Build targets** (via `make`):
- `make` or `make all` — generate both files with all available languages
- `make LANGUAGES="en"` — build with English only
- `make LANGUAGES="en fr de es ko"` — build with specific languages
- `make compact` — generate `writhdeck-compact.tcl` + `writhdeck-cli-compact.tcl` (stripped, ~-20 to -25%)
- `make compact-cli` — generate `writhdeck-cli-compact.tcl` only
- `make clean` — remove generated files (includes compact variants)
- `make test` — run regression tests
- `make test-i18n` — validate translations only
- `make test-syntax` — check Tcl syntax only

`tools/tcl-compact.tcl` — compact filter script. Uses a character-level context scanner to safely strip comments, blank lines, and leading whitespace from all code lines. Preserves content inside `"..."` strings (including those nested inside `{...}` blocks) where indentation is semantically significant.

The Makefile uses `AVAILABLE_LANGS` to auto-detect all `src/i18n/*.tcl` files, so new language files are automatically included in builds. English is always prepended (even if not listed).

Both generated files are:
- Executable (with shebang, +x mode)
- Tracked in git (not ignored)
- Have section headers (`# === state.tcl ===`) for readability during debugging

## Internationalization (i18n)

Modular language system with 6 supported languages. Store translations in `src/i18n/`:

**Language files** (135 keys each):
- `src/i18n/en.tcl` — English (always included, fallback language)
- `src/i18n/fr.tcl` — Français
- `src/i18n/de.tcl` — Deutsch
- `src/i18n/es.tcl` — Español
- `src/i18n/ko.tcl` — 한국어 (Korean)
- `src/i18n/no.tcl` — Norsk (Norwegian)

Each file defines `dict set ::i18n LANG { key "value" ... }` with all 135 keys required for completeness.

**Build with specific languages:**
```bash
make LANGUAGES="en"              # English only (~95KB)
make LANGUAGES="en fr de es"     # Selected languages (~250KB)
make                             # All available languages (~280KB) — auto-detected
```

English is always included as a fallback language (for missing keys in other languages).

**Using translations in code:**
```tcl
set msg [t help_date_time]              # Retrieves from ::i18n[$::cfg_lang]
set msg [format [t help_cur_time] "12:30"]  # With arguments
```

The proc `t {key args}` (in `src/config.tcl`) falls back to English if a key is missing. Users select language via `lang = CODE` in `~/.writhdeck.ini` or the language dropdown in the config dialog (`c` key in browser).

**Testing translations:**
```bash
make test-i18n    # Validates all languages have complete keys + matching format strings
```

See `src/i18n/README.md` for adding new languages and comprehensive i18n documentation.

## SKILLS.md

`SKILLS.md` in the repo root is the developer reference in French. It contains detailed rules, patterns, and a list of ideas not yet implemented — consult it before adding features.
