# WrithDeck 

![WrithDeck Logo](media/writhdeck_logo.png)

[🇫🇷](README.fr.md) — [📖 Manual](writhdeck_MANUAL.md) — [🌍 i18n Guide](src/i18n/README.md)
 
WrithDeck is a distraction-free text editor designed for writers using a dedicated writerdeck — a DIY prototype or a computer configured specifically for writing. It runs as a graphical application (GUI) or directly in a terminal/TTY (TUI), all from a single executable file with no installation required.

**Features:**
- Inline syntax highlighting with support for markdown markers
- File browser with favorites and recent files
- Split view editing (GUI only)
- Table of contents with heading navigation
- Fully themeable interface (dark/light mode, 6 built-in color schemes)
- Multi-language support (English, French, German, Spanish, Korean, Norwegian)
- Clickable toolbar shortcuts
- Writing statistics and daily progress tracking
- Configurable timer (countdown) and stopwatch with visual alerts and audio notifications
- Modal command mode (ESC key) for quick access to timer, stats, and word occurrences
- ~5,000 lines of Tcl/Tk, generated from modular source files

Whether you're writing on a Raspberry Pi Zero with an E-ink screen, on an Android tablet, over SSH, or on your desktop, WrithDeck stays lightweight and lets you focus on your text.

![WrithDeck Screenshot 01](media/writhdeck_screen01.png)

## Installation

Requires Tcl/Tk 8.6+ on your system:

| Platform      | Command                                                                                          |
| ------------- | ------------------------------------------------------------------------------------------------ |
| Debian/Ubuntu | `apt install tk`                                                                                 |
| Mac OS        | `brew install tcl-tk`                                                                            |
| Windows       | [tcl-lang.org/software/tcltk/bindist.html](https://www.tcl-lang.org/software/tcltk/bindist.html) |
| Haiku OS      | `pkgman install tcl tk`                                                                          |

## Quick Start

```sh
wish writhdeck.tcl                     # GUI, file browser
wish writhdeck.tcl file.txt            # GUI, open file directly
tclsh writhdeck.tcl --tui              # TUI, file browser (--no-gui, --cli aliases)
tclsh writhdeck.tcl --cli file.txt     # TUI, open file directly
./writhdeck.tcl --tui                  # Direct execution, TUI mode
```

You can also copy `writhdeck.tcl` or `writhdeck-cli.tcl` to your PATH (e.g. `/usr/local/bin/`) for direct access from anywhere. The `writhdeck-cli.tcl` version is TUI-only and doesn't require Tk.

📖 See the [manual](writhdeck_MANUAL.md) for configuration, keyboard shortcuts, and all features.

![WrithDeck Screenshot 02](media/writhdeck_screen02.png)

## Building from Source

The repository contains modular source files in `src/`:

```bash
make                              # Build with all available languages
make LANGUAGES="en"               # Build English only (~95KB)
make LANGUAGES="en fr de es"      # Build specific languages
make clean                        # Remove generated files
make test                         # Run regression tests (i18n, syntax, builds)
```

**Output files:**
- `writhdeck.tcl` — Full GUI+TUI version with all selected languages
- `writhdeck-cli.tcl` — TUI-only version (no Tk dependency)

Both files are executable and can be distributed as-is.

## Internationalization

WrithDeck supports **6 languages** out of the box:
- 🇬🇧 English
- 🇫🇷 French
- 🇩🇪 German
- 🇪🇸 Spanish
- 🇰🇷 Korean
- 🇳🇴 Norwegian

Each language can be independently selected via `~/.writhdeck.ini`. To add a new language, see [src/i18n/README.md](src/i18n/README.md).

## Code Structure

```
src/
├── boot.tcl            # Polyglot sh/Tcl bootstrap
├── boot-cli.tcl        # TUI-only bootstrap
├── state.tcl           # JSON state persistence (cursors, favorites, stats)
├── config.tcl          # INI file loading, theme system, i18n
├── common.tcl          # Shared utilities (backup, inline parsing)
├── gui.tcl             # GUI (Tk) implementation
├── tui.tcl             # Terminal UI implementation
├── main.tcl            # GUI/TUI dispatch
├── main-cli.tcl        # CLI entry point
└── i18n/
    ├── en.tcl          # English translations
    ├── fr.tcl, de.tcl, es.tcl, ko.tcl, no.tcl
    └── README.md       # i18n guide

tests/
├── test-i18n.tcl       # Translation validation
├── test-syntax.tcl     # Tcl syntax checking
└── README.md           # Test suite documentation

Makefile                # Build system, test targets
```

## Testing

Comprehensive regression tests prevent bugs and ensure code quality:

```bash
make test           # Run all tests
make test-i18n      # Test translations
make test-syntax    # Test Tcl syntax
make test-gui       # Test GUI build
make test-cli       # Test CLI build
make test-langs     # Test language combinations
```

Tests automatically detect:
- Missing or incomplete translations
- Format string mismatches
- Tcl syntax errors
- Build failures with different language combinations

See [tests/README.md](tests/README.md) for details.

## Development

The project uses Claude Code for development:

```bash
# Run interactive editor
claude-code .

# Run with fast mode (faster output)
/fast
```

See [CLAUDE.md](CLAUDE.md) for coding guidelines and conventions.

## Configuration

WrithDeck stores configuration in `~/.writhdeck.ini`:

```ini
[editor]
profile = default
scheme = dark
lang = en

[behaviour]
line_numbers = true
cursor_restore = true
dark_mode = true

[keys]
key_save = Control-s
key_open = Control-o
# ... (all shortcuts configurable)
```

Full documentation: See the in-app help (Ctrl+H) or [writhdeck_MANUAL.md](writhdeck_MANUAL.md).

## Performance

- **Size:** 95KB (English only) to 280KB (all 6 languages)
- **Memory:** Minimal footprint, suitable for Raspberry Pi and embedded systems
- **Startup:** <1 second on modern hardware
- **Syntax highlighting:** Real-time, with zero lag even on 100KB+ files

## Compatibility

- **Tcl/Tk:** 8.6+ (all platforms)
- **GUI (wish):** X11 (Linux), Aqua (macOS), Win32 (Windows)
- **TUI (tclsh):** All platforms, works over SSH
- **Tested on:** Debian, Ubuntu, macOS 12+, Windows 10+, Raspberry Pi OS

**Not supported:**
- Windows TUI (no `stty` command)
- macOS < 10.14

---

## Credits

Based on [writerdeckForCMD](https://github.com/lallero7/writerdeckForCMD),
itself based on [bee-write-back](https://github.com/shmimel/bee-write-back/).

Designed to run in Tcl/Tk with the help of an LLM (Claude Code). [Tcl is a remarkable language!](https://en.wikipedia.org/wiki/Tcl_(programming_language))

## License

Copyright (C) 2026 by Luginfo — Zero-Clause BSD License

Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted. The software is provided "as is" without warranty of any kind.
