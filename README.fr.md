 
# WrithDeck 

![WrithDeck Logo](media/writhdeck_logo.png)

[🇬🇧](README.md) 

WrithDeck est un éditeur de texte sans distraction conçu pour les auteurs utilisant un writerdeck dédié, qu'il s'agisse d'un prototype fait maison ou d'un ordinateur configuré spécifiquement à cet effet. Il est rapide et facile à personnaliser. WrithDeck peut fonctionner comme une application graphique épurée ou directement dans un terminal ou un TTY, le tout depuis un seul fichier sans installation.

Il inclut une coloration syntaxique inline configurable, un navigateur de fichiers, une vue fractionnée, la navigation par chapitres via une table des matières, et une interface entièrement thémable, le tout en environ 4 000 lignes (174 Ko) de Tcl/Tk.

Que vous écriviez sur un Raspberry Pi Zero avec un écran E-ink, sur une tablette Android, en SSH, ou sur votre bureau, WrithDeck reste léger et vous laisse vous concentrer sur votre texte.

Il dispose d'un double mode GUI et TUI au comportement similaire, et est entièrement configurable.

![WrithDeck Screenshot 01](media/writhdeck_screen01.png)

## Utilisation

Tcl/Tk doit être installé sur votre système.

Sur les systèmes Debian :

``apt install tk``

Sur les autres Linux / BSD, référez-vous à votre documentation, l'installation devrait être triviale.

Sur Windows, des binaires pour le runtime Tcl sont disponibles ici : https://www.tcl-lang.org/software/tcltk/bindist.html

Sur Mac OS, utilisez ``brew install tcl-tk`` si vous avez [homebrew](https://brew.sh/).

Sur Haiku OS, Tcl/Tk est disponible via HaikuPorts (``pkgman install tcl tk``). Les modes GUI et TUI fonctionnent tous les deux.

Puis :

```
wish writhdeck.tcl                     # GUI, navigateur de fichiers
wish writhdeck.tcl file.txt            # GUI, ouvrir un fichier directement
tclsh writhdeck.tcl --no-gui           # TUI, navigateur de fichiers
tclsh writhdeck.tcl --no-gui file.txt  # TUI, ouvrir un fichier directement
```

Vous pouvez aussi le lancer depuis le terminal avec ./writhdeck.tcl ou, mieux, le copier dans votre PATH (dans /usr/local/bin/ par exemple) pour un accès direct.


## Options de ligne de commande

| Option | Description |
|---|---|
| `--help`, `-h` | Afficher l'aide et quitter |
| `--gui` | Forcer le mode GUI (Tk) — ignorer la détection du serveur d'affichage |
| `--no-gui` | Forcer le mode TUI (terminal) |
| `--tui`, `--ng` | Alias de `--no-gui` |

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
- Barre de statut : zones entièrement configurables (gauche / centre / droite) avec les jetons : `filename dirty sel ln col words chars clock help_bar space`
- Aller à la ligne
- Support de la saisie UTF-8
- Position du curseur restaurée entre les sessions (`.cursors.json`)
- Configuration rechargée à chaque ouverture de document (pas de redémarrage nécessaire)
- Basculement thème sombre/clair (`Ctrl+D` par défaut, configurable)
- Langue de l'interface : `lang = en` ou `fr`
- **Comportement unifié du navigateur** : après la fermeture d'un fichier, GUI et TUI retournent au navigateur de fichiers (configurable via `browser`)
- **Bloc-notes** : tampon temporaire en mémoire, pas de fichier disque tant qu'on ne sauvegarde pas explicitement
- **Dialogue d'aide** : affiche le nombre de mots/caractères de la sélection quand du texte est sélectionné (GUI et TUI)


![WrithDeck Screenshot 02](media/writhdeck_screen02.png)

---

## Configuration

`~/Documents/writhdeck/writhdeck.ini` — sections : `[editor]`, `[behaviour]`, `[keys]`, `[profiles]`, `[schemes]`

Tous les raccourcis clavier sont configurables via la section `[keys]`.

### Options INI principales

**`[editor]`**

| Clé | Défaut | Description |
|---|---|---|
| `profile` | `default` | Profil actif — doit correspondre à un bloc `[nom]` dans `[profiles]` |
| `scheme` | `default` | Schéma de couleurs actif — doit correspondre à un bloc `[nom]` dans `[schemes]` |
| `console_margin_cols` | `6` | Marge horizontale en colonnes (TUI uniquement) |
| `console_margin_rows` | `4` | Marge verticale en lignes (TUI uniquement) |
| `heading_marker` | `=` | Délimiteur de titre (`= titre =`) |
| `comment_marker` | `%` | Préfixe de commentaire de ligne ; mettre `0` ou laisser vide pour désactiver |
| `bold_marker` | `**` | Marqueur gras inline ; mettre `0` ou laisser vide pour désactiver |
| `italic_marker` | `//` | Marqueur italique inline ; mettre `0` ou laisser vide pour désactiver |
| `underline_marker` | `__` | Marqueur souligné inline ; mettre `0` ou laisser vide pour désactiver |
| `strikethrough_marker` | `--` | Marqueur barré inline ; mettre `0` ou laisser vide pour désactiver |

**`[behaviour]`**

| Clé | Défaut | Description |
|---|---|---|
| `browser` | `1` | Retourner au navigateur de fichiers après la fermeture d'un fichier |
| `watch_file` | `1` | Détecter les modifications externes et proposer de recharger ; `0` pour désactiver |
| `split_shrink_margin` | `1` | Diviser `margin_width` par deux en vue fractionnée (GUI) ; `0` pour conserver la marge complète |
| `hemingway_mode` | `0` | Quand le mode machine à écrire est actif : bloquer les flèches, la suppression et l'annulation ; masquer la barre de statut ; doubler les marges |
| `console_center_alert` | `1` | Centrer les dialogues de confirmation (TUI) ; `0` = barre du bas |
| `block_cursor_gui` | `1` | Curseur bloc en mode GUI |
| `block_cursor_console` | `1` | Curseur bloc en mode TUI |
| `blink_cursor` | `0` | Curseur clignotant |
| `line_numbers` | `0` | Afficher les numéros de ligne |
| `cursor_restore` | `1` | Restaurer la position du curseur à la réouverture |
| `lang` | `en` | Langue de l'interface (`en` ou `fr`) |
| `dark_mode` | `1` | Thème sombre ; `0` = clair (style Solarized) |

**`[keys]`** — toutes les actions sont reconfigurables : `key_save`, `key_close`, `key_find`, `key_replace`, `key_goto`, `key_open`, `key_undo`, `key_redo`, `key_help`, `key_toc`, `key_line_numbers`, `key_fullscreen`, `key_split`, `key_split_focus`, `key_typewriter`, `key_dark_toggle`. Utiliser les noms de touches Tk (`Control-s`, `Alt-Return`, `F11`, etc.).

**`[profiles]`** — préréglages nommés pour l'affichage GUI. Chaque bloc `[nom]` définit les marges, les polices et l'interligne. Sélectionner le profil actif avec `profile = nom` dans `[editor]`. Le profil `[default]` est toujours écrit par WrithDeck.

| Clé | Défaut | Description |
|---|---|---|
| `margin_width` | `60` | Marge horizontale en pixels (GUI) |
| `margin_height` | `40` | Marge verticale en pixels (GUI) |
| `font_size` | `13` | Taille de police (GUI) |
| `font_family` | `Mono` | Famille de police (GUI) ; Tk résout `Mono` vers la meilleure police monospace disponible sur l'OS |
| `bar_font_family` | `Mono` | Famille de police pour la barre de statut (GUI) |
| `line_spacing` | `100` | Interligne en % (GUI) |
| `bar_height` | `18` | Hauteur de la barre de statut en pixels (GUI) |

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
```

**`[schemes]`** — définitions de schémas de couleurs. Chaque bloc `[nom]` à l'intérieur de `[schemes]` définit un schéma avec des couleurs pour le mode sombre et le mode clair. Sélectionner le schéma actif avec `scheme = nom` dans `[editor]`. Le schéma `[default]` est toujours écrit par WrithDeck et contient les couleurs courantes.

Clés de couleur par schéma :

| Clé | Description |
|---|---|
| `color_bg` / `color_bg_alt` | Fond de l'éditeur (sombre / clair) |
| `color_fg` / `color_fg_alt` | Texte de l'éditeur (sombre / clair) |
| `color_bg_bar` / `color_bg_bar_alt` | Fond de la barre de statut (sombre / clair) |
| `color_fg_bar` / `color_fg_bar_alt` | Texte de la barre de statut (sombre / clair) |
| `color_bg_sel` / `color_bg_sel_alt` | Fond de la sélection (sombre / clair) |
| `color_heading` / `color_heading_alt` | Couleur des titres (sombre / clair) |
| `color_comment` / `color_comment_alt` | Couleur des commentaires/lignes estompées (sombre / clair) |
| `color_markup` / `color_markup_alt` | Couleur du balisage inline (sombre / clair) |

Basculer entre sombre et clair avec `Ctrl+D` (configurable via `key_dark_toggle`).

Exemple — pour utiliser Solarized, ajouter `scheme = solarized` dans `[editor]`, puis ce bloc :

```ini
[schemes]

[default]
# … (écrit automatiquement par WrithDeck)

[solarized]
# mode sombre
color_bg       = #002b36
color_fg       = #839496
color_bg_bar   = #073642
color_fg_bar   = #657b83
color_bg_sel   = #586e75
color_heading  = #b58900
color_comment  = #586e75
color_markup   = #268bd2
# mode clair
color_bg_alt      = #fdf6e3
color_fg_alt      = #657b83
color_bg_bar_alt  = #eee8d5
color_fg_bar_alt  = #93a1a1
color_bg_sel_alt  = #d3cbb7
color_heading_alt = #b58900
color_comment_alt = #93a1a1
color_markup_alt  = #268bd2

[gruvbox]
# mode sombre
color_bg       = #282828
color_fg       = #ebdbb2
color_bg_bar   = #1d2021
color_fg_bar   = #a89984
color_bg_sel   = #504945
color_heading  = #fabd2f
color_comment  = #928374
color_markup   = #83a598
# mode clair
color_bg_alt      = #fbf1c7
color_fg_alt      = #3c3836
color_bg_bar_alt  = #ebdbb2
color_fg_bar_alt  = #7c6f64
color_bg_sel_alt  = #d5c4a1
color_heading_alt = #b57614
color_comment_alt = #a89984
color_markup_alt  = #076678

[everforest]
# dark mode
color_bg       = #2b3339
color_fg       = #d3c6aa
color_bg_bar   = #1e2326
color_fg_bar   = #a7c080
color_bg_sel   = #3a464c
color_heading  = #a7c080
color_comment  = #7a8478
color_markup   = #7fbbb3

# light mode
color_bg_alt      = #fdf6e3
color_fg_alt      = #5c6a72
color_bg_bar_alt  = #efead4
color_fg_bar_alt  = #8da101
color_bg_sel_alt  = #e6e2cc
color_heading_alt = #8da101
color_comment_alt = #a6b0a0
color_markup_alt  = #3a94c5

[nord]
# dark mode
color_bg       = #2e3440
color_fg       = #d8dee9
color_bg_bar   = #3b4252
color_fg_bar   = #81a1c1
color_bg_sel   = #434c5e
color_heading  = #88c0d0
color_comment  = #616e88
color_markup   = #8fbcbb

# light mode
color_bg_alt      = #eceff4
color_fg_alt      = #2e3440
color_bg_bar_alt  = #e5e9f0
color_fg_bar_alt  = #5e81ac
color_bg_sel_alt  = #d8dee9
color_heading_alt = #5e81ac
color_comment_alt = #4c566a
color_markup_alt  = #5e81ac

[alt01]
# mode sombre
color_bg       = #1a1214
color_fg       = #e8dcc8
color_bg_bar   = #241820
color_fg_bar   = #9e8878
color_bg_sel   = #521828
color_heading  = #e63060
color_comment  = #6e5858
color_markup   = #c24868
# mode clair
color_bg_alt      = #fffde9
color_fg_alt      = #363c42
color_bg_bar_alt  = #eee8d5
color_fg_bar_alt  = #93a1a1
color_bg_sel_alt  = #f0e7c1
color_heading_alt = #c8064a
color_comment_alt = #aaaaaa
color_markup_alt  = #7e1c3e
```


---

## Mode GUI

C'est le mode par défaut, il nécessite Tk.

**Affichage**
- Fenêtre graphique avec éditeur défilant et navigateur de fichiers
- Marges en pixels, taille et famille de police, interligne, couleurs configurables (via INI)
- Coloration syntaxique inline : titres, commentaires, gras, italique, souligné, barré
- Numéros de ligne : synchronisés avec le défilement (`line_numbers = 1`)
- Redimensionnement dynamique de la police : Ctrl++ / Ctrl+- (clavier et pavé numérique)
- Basculement plein écran (défaut : Alt+Entrée, configurable)
- Thème clair intégré (basculer avec `dark_mode` ou `Ctrl+D`)
- Deuxième dossier de documents optionnel (`docs_dir`), affiché comme deux sections dans le navigateur
- Horloge (HH:MM) dans la barre de statut : ajouter le jeton `clock` à une zone de statut
- Curseur bloc : rectangle avec couleurs inversées (`block_cursor_gui = 1`)
- Hauteur de barre de statut configurable (`bar_height`) ; la taille de police s'adapte automatiquement
- **Vue fractionnée verticale** (F3) : divise l'éditeur en deux volets indépendants sur le même document ; chaque volet défile et positionne le curseur indépendamment ; F4 cycle le focus entre les volets ; le volet actif est mis en évidence par une bordure
- **Mode machine à écrire / focus** (Ctrl+T, GUI et TUI) : maintient le curseur centré verticalement pendant la frappe ; estompe tout le texte hors du paragraphe courant pour réduire les distractions
- **Mode Hemingway** (`hemingway_mode = 1` dans le INI, s'active avec Ctrl+T) : écriture en avant uniquement — les flèches, la suppression et l'annulation sont désactivés ; la barre de statut est masquée ; les marges sont doublées. « Écrivez ivre, éditez sobre ! »
- Dialogues de confirmation : `Tab` pour naviguer entre les boutons, `Entrée` pour confirmer, `Échap` pour annuler, `o` / `n` pour réponse directe

**Raccourcis — Éditeur**

Ce sont les touches par défaut. La plupart sont entièrement configurables dans le fichier writhdeck.ini !

| Touche | Action |
|---|---|
| Ctrl+S | Enregistrer |
| Ctrl+Shift+S | Enregistrer sous… (avec confirmation d'écrasement) |
| Ctrl+Q | Fermer le fichier, retour au navigateur |
| Ctrl+F | Rechercher (barre inline, surbrillance en direct, compteur) — opère sur le volet actif en vue fractionnée |
| Ctrl+R | Rechercher & Remplacer (barre inline ; Entrée : remplacer un, Ctrl+Entrée : tous) |
| Ctrl+Z | Annuler |
| Ctrl+Y | Rétablir |
| Ctrl+T | Mode machine à écrire / focus (bascule) |
| Ctrl+O | Ouvrir un fichier quelconque (dialogue système) |
| Ctrl+G | Aller à la ligne — saute dans le volet actif |
| Ctrl+H | Dialogue d'aide (date/heure, stats du fichier, stats de sélection si texte sélectionné) |
| Ctrl+L | Afficher/masquer les numéros de ligne |
| Ctrl+D | Basculer thème sombre/clair |
| Ctrl+↑ / Ctrl+↓ | Sauter au paragraphe précédent / suivant |
| Ctrl+← / Ctrl+→ | Sauter au mot précédent / suivant |
| F11 | Table des matières — saute dans le volet actif |
| F3 | Basculer la vue fractionnée (GUI uniquement) |
| F4 | Vue fractionnée — cycle du focus entre les volets |
| Alt+Entrée | Basculer le plein écran |
| Tab | Insérer 4 espaces |
| Shift+↑↓←→ | Étendre la sélection |

**Raccourcis — Navigateur**

| Touche | Action |
|---|---|
| Entrée / double-clic | Ouvrir le fichier |
| n | Nouveau fichier |
| t | Bloc-notes (tampon en mémoire, pas de fichier disque ; Ctrl+S demande un nom pour enregistrer) |
| d | Supprimer le fichier |
| r | Renommer le fichier |
| z | Recharger — relancer WrithDeck avec la configuration `.ini` courante |
| h / Ctrl+H | Aide |
| Ctrl+O | Ouvrir un fichier quelconque (dialogue système) |
| Ctrl+D | Basculer thème sombre/clair |
| Alt+Entrée | Basculer le plein écran |
| q | Quitter |

**Notes sur la vue fractionnée**
- F3 divise le document en deux volets côte à côte ; appuyer à nouveau sur F3 pour fermer la vue fractionnée
- F4 cycle le focus entre les deux volets (configurable via `key_split_focus`)
- Le volet actif est mis en évidence par une bordure colorée ; le volet inactif n'en a pas
- Les deux volets partagent le même texte — les modifications dans l'un sont immédiatement visibles dans l'autre
- Le curseur, la position de défilement et l'historique d'annulation sont indépendants par volet
- Recherche, Remplacement, Aller à la ligne et la table des matières opèrent sur le volet qui avait le focus à leur ouverture
- Les numéros de ligne sont masqués quand la vue fractionnée est active


---

## Mode TUI

Activé via `--no-gui` / `--tui` / `--ng`, ou si aucun système de fenêtrage n'est disponible. C'est du TTY/terminal pur via des séquences ANSI.


**Affichage**
- Ensemble de fonctionnalités identique à l'éditeur GUI, rendu dans le terminal
- Navigateur avec marqueur de sélection `»` ; en-têtes de section pour le mode double-dossier
- Navigation style Vim (j/k) + touches fléchées, Début/Fin, PgPréc/PgSuiv
- Coloration syntaxique inline : titres (gras), commentaires (estompé), gras/italique/souligné/barré
- Indicateur de défilement : barre `▐/│` dans la colonne la plus à droite quand le contenu déborde
- Numéros de ligne : colonne de gauche (`line_numbers = 1`), affichés sur la première ligne visuelle de chaque paragraphe
- Barre de statut : nom de fichier, position, nombre de mots/caractères, horloge
- Le dialogue d'aide affiche le nombre de mots/caractères de la sélection quand du texte est sélectionné
- Forme du curseur configurable : bloc ou barre, clignotant ou fixe (`block_cursor_console`, `blink_cursor`)
- Dialogues de confirmation centrés à l'écran par défaut (`console_center_alert = 1`)
- Dialogues de confirmation : `o` / `n` pour répondre directement, `Échap` pour annuler, `Entrée` pour confirmer le bouton actif
- **Mode machine à écrire / focus** (Ctrl+T) : curseur centré verticalement ; texte hors du paragraphe courant estompé
- **Mode Hemingway** (`hemingway_mode = 1`) : s'active avec Ctrl+T — bloque les flèches, la suppression et l'annulation ; double les marges
- Après la fermeture d'un fichier, retour au navigateur si `browser = 1` (défaut)

**Raccourcis — Éditeur**

| Touche | Action |
|---|---|
| Ctrl+S | Enregistrer (bloc-notes : demande un nom de fichier, puis enregistre sur disque) |
| Ctrl+Q / Échap | Fermer le fichier, retour au navigateur |
| Ctrl+F | Rechercher (invite ; répéter pour trouver le suivant) |
| Ctrl+R | Rechercher & Remplacer (global, avec compteur de remplacements) |
| Ctrl+Z | Annuler (pile de 100 états) |
| Ctrl+Y | Rétablir |
| Ctrl+T | Mode machine à écrire / focus (bascule) |
| Ctrl+O | Enregistrer et retourner au navigateur |
| Ctrl+G | Aller à la ligne |
| Ctrl+H | Aide (date/heure, stats du fichier, stats de sélection si texte sélectionné) |
| Ctrl+L | Afficher/masquer les numéros de ligne |
| Ctrl+D | Basculer thème sombre/clair (vidéo inverse) |
| Ctrl+↑ / Ctrl+↓ | Sauter au paragraphe précédent / suivant (émulateur de terminal uniquement ; intercepté par la console TTY) |
| Ctrl+← / Ctrl+→ ou Alt+B / Alt+F | Sauter au mot précédent / suivant |
| F11 | Table des matières (Échap / Ctrl+Q pour fermer, Entrée pour sauter) |
| Ctrl+A | Tout sélectionner |
| Ctrl+K | Basculer la sélection collante (premier appui : ancre ; deuxième appui : annuler) |
| Shift+↑↓←→ | Étendre la sélection |
| Ctrl+C | Copier (via xclip / xsel / wl-copy) |
| Ctrl+X | Couper |
| Ctrl+V | Coller (multiligne supporté) |
| Tab | Insérer 4 espaces |

**Raccourcis — Navigateur**

| Touche | Action |
|---|---|
| Entrée | Ouvrir le fichier |
| n | Nouveau fichier |
| t | Bloc-notes (tampon en mémoire, pas de fichier disque ; Ctrl+S demande un nom pour enregistrer) |
| d | Supprimer le fichier |
| r | Renommer le fichier |
| h / Ctrl+H | Aide |
| q / Ctrl+Q | Quitter |


---

## Captures d'écran

WrithDeck sur un Raspberry Zero W (mode aller au chapitre) :

![WrithDeck Screenshot 03](media/writhdeck_screen03.jpg)

WrithDeck dans Termux sur une liseuse Android Meebook M6, avec un clavier Bluetooth :

![WrithDeck Screenshot 04](media/writhdeck_screen04.jpg)


## Bugs connus et limitations

- En mode GUI, les fins de ligne dans un texte avec retour à la ligne automatique peuvent entraîner un affichage incohérent du curseur bloc. Pour y remédier, utiliser le curseur non-bloc dans le fichier .ini (block_cursor_gui = 0).
- Il y a parfois un léger délai pour afficher les lettres inversées sous le curseur bloc en mode GUI. Voir le correctif ci-dessus ou utiliser le mode TUI.
- En mode TUI, lors du redimensionnement de la fenêtre de terminal, des artefacts peuvent apparaître. Ouvrir l'aide avec Ctrl+H deux fois rafraîchit l'écran.
- Il n'y a pas de mode sans retour à la ligne (et ce n'est pas une fonctionnalité prévue).
- Il n'y a pas de mode tabulation (et ce n'est pas une fonctionnalité prévue).
- La vue fractionnée est uniquement disponible en GUI (une adaptation en TUI est possible ultérieurement).
- Sur des textes très longs (plus de 80 000 mots) et un ordinateur à CPU lent (Celeron 1,1 GHz de 2013), le curseur et la frappe peuvent ralentir. Des optimisations ont été apportées par rapport à la première version, mais si nécessaire, désactivez le comptage des mots et des caractères dans la barre de statut. Les statistiques d'écriture restent accessibles dans l'aide.


## Crédits

Basé sur <https://github.com/lallero7/writerdeckForCMD>,
lui-même basé sur <https://github.com/shmimel/bee-write-back/>

Conçu pour fonctionner en Tcl/Tk avec l'aide d'un LLM (Claude Code).

Tcl est un langage remarquable ! https://en.wikipedia.org/wiki/Tcl_(programming_language)


Nano, micro ou scite sont aussi d'excellents outils pour un writerdeck simple.

  
## Licence

Copyright (C) 2026 par Luginfo

    Licence BSD Zero Clause

    Permission d'utiliser, copier, modifier et/ou distribuer ce logiciel à toute fin
    avec ou sans frais est accordée par la présente.

    LE LOGICIEL EST FOURNI « EN L'ÉTAT » ET L'AUTEUR DÉCLINE TOUTE GARANTIE
    CONCERNANT CE LOGICIEL, Y COMPRIS TOUTES LES GARANTIES IMPLICITES
    DE QUALITÉ MARCHANDE ET D'ADÉQUATION. EN AUCUN CAS L'AUTEUR NE SERA
    RESPONSABLE DE TOUT DOMMAGE SPÉCIAL, DIRECT, INDIRECT OU CONSÉCUTIF,
    NI D'AUCUN DOMMAGE RÉSULTANT D'UNE PERTE D'UTILISATION, DE DONNÉES
    OU DE BÉNÉFICES, QUE CE SOIT DANS LE CADRE D'UN CONTRAT, D'UNE NÉGLIGENCE
    OU DE TOUT AUTRE ACTE DÉLICTUEL, DÉCOULANT DE OU EN RELATION AVEC
    L'UTILISATION OU LES PERFORMANCES DE CE LOGICIEL.
