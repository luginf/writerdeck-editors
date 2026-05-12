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

Build with `make` to generate `writhdeck.tcl` and `writhdeck-cli.tcl` from source modules in `src/`. Both generated files are executable and tracked in git. There are no tests, no dependencies beyond Tcl/Tk 8.6+.

## Version

Format `vYYYYMMDD` (e.g. `v20260508`), defined near line 32:
```tcl
set ::version "v20260509"
```
Update it on every functional change.

## Code structure

The file has two major runtime branches controlled by `$::no_gui`:

| Zone | Lines (approx.) | Content |
|---|---|---|
| Bootstrap | 1–125 | Polyglot sh/Tcl, args, Tk detection, `::HOME_DIR`, `tilde-expand` |
| State persistence | 126–272 | `.writhdeck.json`, cursors, favorites, recents, daily stats |
| INI / config | 273–835 | `ini-load`, `ini-save`, profiles, schemes, keys, i18n |
| Shared utils | 836–1345 | `list-docs`, `br-dirs`, `do-backup`, `build-extra-entries`, inline parsers |
| **GUI block** (`if {!$::no_gui}`) | 1346–3100+ | Browser frame, editor frame, dialogs (help, config, info, backup, etc.), TOC, split view, typewriter |
| TUI core | 3100+–3600+ | `tui-init`, `tui-getch`, `tui-bar`, word-wrap, layout |
| TUI helpers | 3600+–3750+ | Prompt, clipboard, selection |
| TUI browser | 3750+–4050+ | `tui-browser` |
| TUI editor | 4050+–4700+ | `tui-toc`, `tui-editor`, `tui-main` |
| Entry point | 4700+–end | Dispatch GUI / TUI |

The GUI block is a single `if {!$::no_gui} { ... } ;# end if {!$::no_gui}` spanning most of the GUI-related code.

## Key rules

**Absolute paths everywhere** — all paths stored in `.writhdeck.json` must be absolute. Call `file normalize $path` at the top of any proc that reads or writes a path (`cursor-get/put`, `recent-push/remove/rename`, `toggle-favorite`, `daily-open`, `daily-clear`).

**`tilde-expand` before `file normalize`** — Tcl 9 no longer expands `~` in `file normalize`. Always call `tilde-expand $path` first when the path comes from user input (config file, prompts). The proc is defined after `::HOME_DIR` near line 110.

**Procs shared between GUI and TUI must be defined outside the `if {!$::no_gui}` block.** Currently outside: all `state-*`, `daily-*`, `recent-*`, `build-extra-entries`, `toggle-favorite`, `do-backup`.

**i18n — always add both languages.** Any new string key must appear in both `en {}` and `fr {}` blocks of `::i18n`. Use `proc t {key args}` to retrieve.

**`chan configure` not `fconfigure`.** The codebase uses `chan configure` throughout (Tcl 8.5+ compatible, not deprecated in Tcl 9).

**No Unicode symbols or em-dashes in user-visible strings.** Use ASCII equivalents: `->` not `→`, `-` not `—`, `[+]`/`[-]` not `★`/`☆`, `|` not `·`, etc. French accented characters (é, à, è, ê, É…) are the only intentional non-ASCII. This applies to i18n strings, help text, status bar, and all TUI output.

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

| Type | Notes |
|---|---|
| `header` | Section separator. `dir=""` → label = `name` field (Favorites, Recents). `dir≠""` → abbreviated path |
| `file` | File in a watched folder |
| `favorite` | Pinned file (any folder) |
| `recent` | Recent file outside watched folders (deduplicated) |

Section order: `DOCS_DIR_DEFAULT` → `DOCS_DIR` (if custom) → Favorites → Recents.
`br-active-dir` walks up to the nearest `header`; if `dir=""` returns `DOCS_DIR_DEFAULT`.

## GUI-specific patterns

**Help dialog close** — use `after idle [list destroy $w]; break` on keyboard bindings inside the Text widget; plain `destroy` triggers `<<TkTextBackspace>>` on the already-destroyed widget.

**`quit-app`** — only prompts to save if `$::filename ne "" || $::scratchpad`.

**`open-file-dialog`** — uses `[file dirname $::filename]` as `initialdir` when a file is open, otherwise `DOCS_DIR_DEFAULT`.

## Editor behavior

**Tab key** — inserts a literal tab character (`\t`), not spaces. Both GUI and TUI preserve tabs in files.

**Reload (z key)** — closes current editor/scratchpad and returns to browser. Always relaunches the program without arguments, even if a file was open.

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

| Module | Lines | Content |
|---|---|---|
| `src/boot.tcl` | ~80 | Polyglot sh/Tcl, args parsing, Tk detection, HOME_DIR setup |
| `src/boot-cli.tcl` | ~80 | CLI variant: no Tk loading, forces `::no_gui 1` |
| `src/state.tcl` | ~147 | JSON state persistence, cursors, favorites, recents, daily stats |
| `src/config.tcl` | ~804 | INI loading/saving, profiles, color schemes, keys, i18n, theme init |
| `src/common.tcl` | ~204 | Docs listing, backup, inline parsers, browser entry building |
| `src/gui.tcl` | ~2001 | Full GUI (Tk) block — wrapped in `if {!$::no_gui}` |
| `src/tui.tcl` | ~1644 | TUI mode code — terminal UI, browser, editor |
| `src/main.tcl` | ~31 | Entry point dispatch (GUI or TUI based on `$::no_gui`) |
| `src/main-cli.tcl` | ~2 | CLI entry point (always calls `tui-main`) |

**Build targets** (via `make`):
- `writhdeck.tcl` — full version (GUI+TUI, ~4979 lines with section headers)
- `writhdeck-cli.tcl` — CLI-only (TUI, ~2899 lines, no Tk loading)
- `make clean` — remove generated files

Both generated files are executable, tracked in git, and have section headers (`# === state.tcl ===`) for readability.

## SKILLS.md

`SKILLS.md` in the repo root is the developer reference in French. It contains detailed rules, patterns, and a list of ideas not yet implemented — consult it before adding features.
