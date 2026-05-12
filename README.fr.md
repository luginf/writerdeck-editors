 
# WrithDeck 

![WrithDeck Logo](media/writhdeck_logo.png)

[🇬🇧](README.md) — [📖 Manuel](writhdeck_MANUAL.md)

WrithDeck est un éditeur de texte sans distraction conçu pour les auteurs utilisant un writerdeck dédié — prototype fait maison ou ordinateur configuré spécifiquement pour l'écriture. Il fonctionne comme une application graphique (GUI) ou directement dans un terminal/TTY (TUI), le tout depuis un seul fichier exécutable sans installation.

Coloration syntaxique inline, navigateur de fichiers, vue fractionnée, table des matières, interface entièrement thémable — environ 5 000 lignes de Tcl/Tk, générées à partir de modules source.

Que vous écriviez sur un Raspberry Pi Zero avec un écran E-ink, sur une tablette Android, en SSH, ou sur votre bureau, WrithDeck reste léger et vous laisse vous concentrer sur votre texte.

![WrithDeck Screenshot 01](media/writhdeck_screen01.png)

## Installation

Tcl/Tk doit être installé sur votre système :

| Plateforme | Commande |
|---|---|
| Debian/Ubuntu | `apt install tk` |
| Mac OS | `brew install tcl-tk` |
| Windows | [tcl-lang.org/software/tcltk/bindist.html](https://www.tcl-lang.org/software/tcltk/bindist.html) |
| Haiku OS | `pkgman install tcl tk` |

## Démarrage rapide

```sh
wish writhdeck.tcl                     # GUI, navigateur de fichiers
wish writhdeck.tcl file.txt            # GUI, ouvrir un fichier directement
tclsh writhdeck.tcl --tui              # TUI, navigateur de fichiers (--no-gui, --cli aussi acceptés)
tclsh writhdeck.tcl --cli file.txt     # TUI, ouvrir un fichier directement
./writhdeck.tcl --tui                  # Exécution directe, mode TUI
```

Vous pouvez aussi copier `writhdeck.tcl` ou `writhdeck-cli.tcl` dans votre PATH (par exemple `/usr/local/bin/`) pour un accès direct depuis n'importe où. La version `writhdeck-cli.tcl` est TUI uniquement et ne nécessite pas Tk.

📖 Voir le [manuel](writhdeck_MANUAL.md) pour la configuration, les raccourcis clavier et toutes les fonctionnalités.

![WrithDeck Screenshot 02](media/writhdeck_screen02.png)

---

## Crédits

Basé sur [writerdeckForCMD](https://github.com/lallero7/writerdeckForCMD),
lui-même basé sur [bee-write-back](https://github.com/shmimel/bee-write-back/).

Conçu pour fonctionner en Tcl/Tk avec l'aide d'un LLM (Claude Code). [Tcl est un langage remarquable !](https://en.wikipedia.org/wiki/Tcl_(programming_language))

## Licence

Copyright (C) 2026 par Luginfo — Licence BSD Zero Clause

Permission d'utiliser, copier, modifier et/ou distribuer ce logiciel à toute fin avec ou sans frais est accordée. Le logiciel est fourni « en l'état » sans garantie d'aucune sorte.
