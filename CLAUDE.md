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

Build with `make` to generate `writhdeck.tcl` and `writhdeck-cli.tcl` from source modules in `src/`. Both generated files are executable and tracked in git. Dependencies: Tcl/Tk 8.6+ (Tk only required for GUI mode).

Run tests to catch regressions:
```sh
make test              # Run all regression tests
make test-i18n        # Validate translations
make test-syntax      # Check Tcl syntax
make test-gui         # Test GUI build
make test-cli         # Test CLI build
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

**`get-word-occurrences {fpath}`** — returns a list of `{word count}` pairs sorted by count descending. Opens, reads, and closes the file itself. Callers iterate with `foreach pair $word_data { lassign $pair word count }` — do not re-read the file.

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

| **`quit-app`** — only prompts to save if `$::filename ne "" |  | $::scratchpad`. |

**`open-file-dialog`** — uses `[file dirname $::filename]` as `initialdir` when a file is open, otherwise `DOCS_DIR_DEFAULT`.

## Editor behavior

**Tab key** — inserts a literal tab character (`\t`), not spaces. Both GUI and TUI preserve tabs in files.

**Reload (z key)** — closes current editor/scratchpad and returns to browser. Always relaunches the program without arguments, even if a file was open. Uses platform-specific process launching (Windows `start` command, Unix shell background execution). Configuration apply button also triggers reload.

## Timer and stopwatch

Configurable countdown timer and stopwatch accessible via ESC modal mode or ALT+t keybinding:

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

## Modal command mode (ESC key)

Editor mode activated by pressing ESC in editor (GUI or TUI). Allows quick access to common functions without breaking focus from text.

**Modal mode features:**
- **ESC** — toggle modal on/off (double ESC exits)
- **t** — toggle timer on/off
- **s** — show daily writing statistics (full-screen overlay)
- **w** — show word occurrences (full-screen overlay in TUI, dialog in GUI)
- **q** — quit/close current file (with save prompt if dirty)
- **Other keys** — exit modal, revert to normal text entry

**Implementation details:**
- State tracked by `$::gui_cmd_mode` (GUI) and `$::tui_cmd_mode` (TUI)
- Status message displayed in `::ed_bar_center` (GUI) or message line (TUI)
- Keybindings check modal state before processing normal input
- ESC logic in TUI editor: first check if already in modal mode (prevents accidental re-entry)

## Known limitations

- No emoji support in GUI (Tk 8.6 color font limitation)
- TUI mode blocked on Windows (`stty` absent)
- No no-wrap mode (not planned)
- Split view GUI only (TUI adaptation not planned yet)
- `font_weight` not exposed in INI (removed, unreliable across fonts)

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
- `make clean` — remove generated files
- `make test` — run regression tests
- `make test-i18n` — validate translations only
- `make test-syntax` — check Tcl syntax only

The Makefile uses `AVAILABLE_LANGS` to auto-detect all `src/i18n/*.tcl` files, so new language files are automatically included in builds. English is always prepended (even if not listed).

Both generated files are:
- Executable (with shebang, +x mode)
- Tracked in git (not ignored)
- Have section headers (`# === state.tcl ===`) for readability during debugging

## Internationalization (i18n)

Modular language system with 6 supported languages. Store translations in `src/i18n/`:

**Language files** (122 keys each):
- `src/i18n/en.tcl` — English (always included, fallback language)
- `src/i18n/fr.tcl` — Français
- `src/i18n/de.tcl` — Deutsch
- `src/i18n/es.tcl` — Español
- `src/i18n/ko.tcl` — 한국어 (Korean)
- `src/i18n/no.tcl` — Norsk (Norwegian)

Each file defines `dict set ::i18n LANG { key "value" ... }` with all 122 keys required for completeness.

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
