 
# WrithDeck 

![WrithDeck Logo](media/writhdeck_logo.png)

[🇫🇷](README.fr.md) — [📖 Manual](writhdeck_MANUAL.md)
 
WrithDeck is a distraction-free text editor designed for writers using a dedicated writerdeck — a DIY prototype or a computer configured specifically for writing. It runs as a graphical application (GUI) or directly in a terminal/TTY (TUI), all from a single executable file with no installation required.

Inline syntax highlighting, file browser, split view, table of contents, fully themeable interface — around 5,000 lines of Tcl/Tk, generated from modular source files.

Whether you're writing on a Raspberry Pi Zero with an E-ink screen, on an Android tablet, over SSH, or on your desktop, WrithDeck stays lightweight and lets you focus on your text.

![WrithDeck Screenshot 01](media/writhdeck_screen01.png)

## Installation

Requires Tcl/Tk on your system:

| Platform | Command |
|---|---|
| Debian/Ubuntu | `apt install tk` |
| Mac OS | `brew install tcl-tk` |
| Windows | [tcl-lang.org/software/tcltk/bindist.html](https://www.tcl-lang.org/software/tcltk/bindist.html) |
| Haiku OS | `pkgman install tcl tk` |

## Quick start

```sh
wish writhdeck.tcl                     # GUI, file browser
wish writhdeck.tcl file.txt            # GUI, open file directly
tclsh writhdeck.tcl --tui              # TUI, file browser (--no-gui, --cli also work)
tclsh writhdeck.tcl --cli file.txt     # TUI, open file directly
./writhdeck.tcl --tui                  # Direct execution, TUI mode
```

You can also copy `writhdeck.tcl` or `writhdeck-cli.tcl` to your PATH (e.g. `/usr/local/bin/`) for direct access from anywhere. The `writhdeck-cli.tcl` version is TUI-only and doesn't require Tk.

📖 See the [manual](writhdeck_MANUAL.md) for configuration, keyboard shortcuts, and all features.

![WrithDeck Screenshot 02](media/writhdeck_screen02.png)

---

## Credits

Based on [writerdeckForCMD](https://github.com/lallero7/writerdeckForCMD),
itself based on [bee-write-back](https://github.com/shmimel/bee-write-back/).

Designed to run in Tcl/Tk with the help of an LLM (Claude Code). [Tcl is a remarkable language!](https://en.wikipedia.org/wiki/Tcl_(programming_language))

## License

Copyright (C) 2026 by Luginfo — Zero-Clause BSD License

Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted. The software is provided "as is" without warranty of any kind.
