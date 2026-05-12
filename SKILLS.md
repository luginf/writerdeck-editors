# WrithDeck — référence développement

## Version

Format : `vYYYYMMDD` (ex. `v20260511`). Définie ligne ~32 :
```tcl
set ::version "v20260511"
```
Affichée dans l'aide GUI (section DATE & TIME) et l'aide TUI (en-tête en inversé + ligne dessous).

> **Règle** : mettre à jour la version (`set ::version "vYYYYMMDD"`) à chaque modification fonctionnelle, avec la date du jour.

## Structure du code (`writhdeck.tcl`, ~4 700+ lignes)

| Zone | Lignes approx. | Contenu |
|---|---|---|
| Version + Bootstrap | 1–125 | `::version`, shebang, args, détection GUI/TUI |
| Persistance état | 126–272 | `.writhdeck.json`, curseurs, favoris, récents, stats |
| INI / config | 273–835 | `ini-load`, `ini-save`, profils, schemes, clés, i18n |
| Utils partagées | 836–1345 | `list-docs`, `br-dirs`, `do-backup`, `build-extra-entries` |
| **GUI block** (`if {!$::no_gui}`) | 1346–3100+ | Browser, éditeur, dialogs, TOC, split view, typewriter, `profile-config-dialog` |
| TUI — utils | 3100+–3600+ | `tui-getch`, `tui-bar`, `tui-prompt` |
| TUI — browser | 3600+–3750+ | `tui-browser` |
| TUI — éditeur | 3750+–4700+ | `tui-toc`, `tui-editor` |
| Démarrage | 4700+–fin | `tui-main`, entrée GUI/TUI |

## Persistance — `.writhdeck.json`

```json
{
  "cursors": {"chemin": [cy, cx]},
  "favorites": ["chemin"],
  "recent": ["chemin"],
  "daily": ["chemin\tYYYY-MM-DD\tN"]
}
```

- Chargement lazy via `state-load` (guard `$::state_cache_valid`) + `state-parse-array` helper
- Écriture via `state-save` (écrase tout à chaque fois)
- Procs curseurs : `cursor-get/put`
- Procs récents : `recent-push/remove/rename`
- Procs favoris : `toggle-favorite`
- Procs stats : `daily-open`, `daily-today`, `daily-update`, `daily-cleanup`
- Format `daily` : une entrée par fichier `"filepath\tdate1\tN1\tdate2\tN2..."` ; le `\t` est la séquence JSON d'échappement (deux caractères `\t`), pas un tab littéral (invalide en JSON). `state-parse-array` utilise `regexp -indices` pour localiser les chaînes entre guillemets dans le JSON brut, les extrait avec `string range`, puis `state-load` applique `string map [list {\\t} "\t"]` avant le `split`. Cette approche gère correctement les séquences échappées sans tenter de matcher du contenu non-échappé.

> **Règle — chemins absolus** : tous les chemins stockés dans `.writhdeck.json` doivent être absolus. Appeler `file normalize $path` en tête de chaque proc qui lit ou écrit un chemin (`cursor-get/put`, `recent-push/remove/rename`, `toggle-favorite`, `daily-open`, `daily-clear`). `state-load` normalise également à la lecture pour corriger les données existantes.

## Stats d'écriture journalières

- `::session_file` + `::session_baseline` + `::session_max_today` — état de la session courante
- `daily-open {filepath wc}` : calcule le baseline (wc - prior_today), initialise session_max_today = prior_today
- `daily-today {wc}` : retourne le max jamais atteint aujourd'hui (**high-water mark** — les suppressions ne réduisent pas le compteur). Met à jour `::session_max_today` en place.
- `daily-update {wc}` : appelle `daily-today`, sauvegarde dans `::daily_data` et `state-save`
- `daily-cleanup` : retire les entrées périmées pour les non-favoris (garde seulement aujourd'hui)
- Nettoyage lancé à la fin de `state-load`
- `daily-update` appelé à : `save-file`, `close-editor`, `quit-app` (GUI) et aux 3 `return` de `tui-editor`

## Browser — types d'entrées (`::br_entries`)

| Type | Usage |
|---|---|
| `header` | Séparateur de section. `dir=""` → label = champ `name` (Favoris, Récents). `dir≠""` → label = path abrégé |
| `file` | Fichier du dossier surveillé |
| `favorite` | Fichier épinglé (peut être dans n'importe quel dossier) |
| `recent` | Fichier récent hors dossiers surveillés (dédupliqué) |

Ordre des sections : `DOCS_DIR_DEFAULT` → `DOCS_DIR` (si custom) → Favoris → Récents

`br-selected` accepte les types `file`, `favorite`, `recent`.
`br-active-dir` remonte jusqu'au `header` le plus proche ; si `dir=""` → `DOCS_DIR_DEFAULT`.

## Dialogue de configuration des profils

Accessible via la touche `c` dans le browser. Invoqué par la proc `profile-config-dialog` :
- **Frame global** : dropdown pour sélectionner le profil actif + dropdown pour sélectionner le scheme de couleurs
- **Frame profil** : contrôles pour famille de police (listbox), taille (spinbox), marges largeur/hauteur (spinbox)
- **Preview** : widget Text affichant un exemple de texte dans la police sélectionnée (mis à jour en temps réel)
- **Bouton Apply** : sauvegarde dans `$::cfg_profiles[$profile]`, applique à l'éditeur si actif, recharge le browser

Configuration par profil stockée dans le dict `::cfg_profiles` avec clés : `font_family`, `font_size`, `margin_width`, `margin_height`. Les valeurs persistent via `.writhdeck.json`.

Détails clés :
- `-command` sur spinbox pour mettre à jour le preview sur clic des boutons (pas juste clavier)
- Proc helper `profile-apply-fonts` pour sauvegarder et appliquer à l'éditeur
- `br-refresh` appelée après Apply pour recharger le browser avec la nouvelle config
- Dialog détruite après fermeture par l'utilisateur

## Barres de raccourcis browser et status bar

La status bar du browser affiche les raccourcis avec mise en gras du premier caractère :
- Format : `h:help`, `n:new`, `t:scratchpad`, etc. — la lettre est en gras, le deux-points et le label suivent
- Construction via une boucle foreach codée en dur qui insère des paires clé-gras + label-texte
- Gestionnaire clic utilise `.br.bar.help tag bind` pour chaque raccourci et appelle la commande
- Le curseur change en main2 au survol (bindings Enter/Leave)

Touches browser actuelles (12 total) : h (help), n (new), t (scratchpad), f (favorite), s (stats), b (backup), d (delete), r (rename), i (info), c (config), z (reload), q (quit).

**Pour ajouter une nouvelle touche browser (8 endroits)** :
1. `br_help_gui` i18n (EN + FR)
2. `br_help_tui` i18n (EN + FR)
3. Ajouter à la boucle foreach de la status bar (`.br.bar.help`)
4. `bind .br.mid.lst <x>` dans le bloc GUI
5. `switch -- $key` dans `tui-browser`
6. Section BROWSER de `help-dialog`
7. Tableaux dans `README.md` et `README.fr.md`

## Procs partagées GUI/TUI

- `build-extra-entries {shown}` — construit les entrées favoris+récents, filtre `shown`
- `toggle-favorite {path}` — bascule dans `::favorites_list` + `state-save`
- `do-backup {dir name}` — copie vers `$DOCS_DIR/backups/nom_YYYY-MM-DDTHHhMM.ext`, retourne le nom
- `daily-clear {filepath}` — efface toutes les stats d'un fichier + `state-save`

> **Règle** : toute proc appelée depuis `tui-browser` doit être définie **hors du bloc `if {!$::no_gui}`** (qui se termine ligne ~2934). Actuellement hors du bloc : `build-extra-entries`, `toggle-favorite`, `do-backup`, `daily-clear`, toutes les procs `daily-*`, `recent-*`, `state-*`.

## Patterns à respecter

**Pas de symboles Unicode ni de tirets quadratins dans les strings visibles par l'utilisateur.** Utiliser des équivalents ASCII : `->` et non `→`, `-` et non `—`, `[+]`/`[-]` et non `★`/`☆`, `|` et non `·`, etc. Seuls les caractères accentués français (é, à, è, ê, É...) sont intentionnellement non-ASCII.

**i18n** — toujours ajouter les deux langues (EN + FR) :
```tcl
br_ma_cle    "My string"    # dans le bloc en {}
br_ma_cle    "Ma chaîne"    # dans le bloc fr {}
```

**Nouvelles touches browser** — 4 endroits à mettre à jour :
1. `br_help_gui` (i18n EN + FR)
2. `br_help_tui` (i18n EN + FR)
3. `bind .br.mid.lst <x>` (GUI)
4. `switch -- $key` dans `tui-browser` (TUI)
5. Section BROWSER de `help-dialog`
6. Tableaux dans `README.md` et `README.fr.md`

**Dialogue de confirmation** — `quit-app` ne demande de sauvegarder que si `$::filename ne "" || $::scratchpad`.

**Aide GUI** — fermeture uniquement par `q`, `Ctrl+H` ou bouton Close (pas Escape/Return). Utiliser `after idle [list destroy $w]` + `break` pour les bindings clavier sur le widget texte, sinon Tk tente d'accéder au widget détruit via `<<TkTextBackspace>>`.

**Aide TUI** — boucle scroll : `q` ou `$::cfg_tui_help` pour quitter, `UP`/`DOWN` pour défiler.

**Ctrl+O** — `open-file-dialog` utilise le dossier du fichier en cours (`$::filename`) si appelée sans argument, sinon `DOCS_DIR_DEFAULT`.

## Limites connues

- **Emoji** : non supportés en GUI (limitation Tk 8.6 / rendu couleur). TUI dépend du terminal.
- **Font bold** : `font_weight` non exposé dans l'INI (retiré, ne fonctionnait pas de façon fiable). Utiliser le nom complet de la famille si la variante bold est enregistrée séparément.
- **TUI Windows** : mode TUI bloqué explicitement (`stty` absent).

## Déjà implémenté (suite)

- **Navigation sections browser (F11)** : `br-toc-show` / `br-toc-jump` (GUI) — popup listbox des en-têtes de section du browser (dossiers + Favoris + Récents) ; TUI — overlay numéroté, touche 1–9 pour sauter à la section. Binding : `bind .br.mid.lst <$::cfg_key_toc>`. `br_help_gui` utilise maintenant `%s` pour `cfg_lbl_toc` → formater avec `[format [t br_help_gui] $::cfg_lbl_toc]`.
- **Dialogue de configuration des profils (c)** : Accès complet aux paramètres de police par profil (famille, taille, marges), sélection du profil par défaut, sélection du scheme de couleurs, preview en temps réel. Stockage persistent dans `.writhdeck.json` via le dict `::cfg_profiles`.
- **Raccourcis browser en gras (status bar GUI)** : Affichage des 12 touches avec la première lettre en gras et cliquable (h:help, n:new, t:scratchpad, f:favorite, s:stats, b:backup, d:delete, r:rename, i:info, c:config, z:reload, q:quit).

## Modularisation et construction

Le code est organisé en modules dans le dossier `src/` et construit via un `Makefile` :

| Module | Lignes | Contenu |
|---|---|---|
| `src/boot.tcl` | ~80 | Polyglot sh/Tcl, parsing args, détection Tk, setup HOME_DIR |
| `src/boot-cli.tcl` | ~80 | Variante CLI : sans chargement Tk, force `::no_gui 1` |
| `src/state.tcl` | ~147 | Persistance JSON, curseurs, favoris, récents, stats quotidiennes |
| `src/config.tcl` | ~804 | Chargement INI, profils, thèmes, clés, i18n, init thème |
| `src/common.tcl` | ~204 | Listing docs, backup, parseurs inline, construction entrées browser |
| `src/gui.tcl` | ~2001 | Bloc GUI (Tk) complet — enveloppé dans `if {!$::no_gui}` |
| `src/tui.tcl` | ~1644 | Code mode TUI — interface terminal, browser, éditeur |
| `src/main.tcl` | ~31 | Point d'entrée dispatch (GUI ou TUI selon `$::no_gui`) |
| `src/main-cli.tcl` | ~2 | Point d'entrée CLI (appelle toujours `tui-main`) |

**Cibles de construction** (via `make`) :
- `writhdeck.tcl` — version complète (GUI+TUI, ~4979 lignes avec marqueurs de section)
- `writhdeck-cli.tcl` — TUI seul (~2899 lignes, sans chargement Tk)
- `make clean` — supprime les fichiers générés

Les deux fichiers générés sont exécutables, trackés dans git, et ont des marqueurs de section (`# === state.tcl ===`) pour la lisibilité.

**Ajustement après modularisation** :
- Les deux fichiers générés **remplacent** l'ancien `writhdeck.tcl` monolithique
- `src/` est la source of truth ; les fichiers générés sont des artefacts de build trackés
- Toute modification fonctionnelle se fait dans `src/` puis `make` régénère les exécutables

## Idées non implémentées

- **Filtre browser** : taper des lettres filtre les fichiers en temps réel (~20 lignes)
- **Temps de lecture** : `words/200` affiché dans le dialogue d'aide (1 ligne)
- **Auto-save** : sauvegarder après N secondes d'inactivité (`after` Tcl, `autosave_delay` dans INI)
- **Renommer depuis l'éditeur** : `Ctrl+Shift+R` sans passer par le browser
- **Recherche dans tous les fichiers** : grep sur le dossier depuis le browser (touche `g` ?)
- **Focus phrase** : estomper tout sauf la phrase courante (plus fin que le focus paragraphe)
- **Export HTML** : conversion headings + marqueurs inline → HTML
- **Mouse support TUI** : `\033[?1000h` pour clic-positionnement
- **Presse-papiers interne** : historique des N derniers copier-coller
- **Statistiques de session** : temps d'écriture, mots ajoutés depuis l'ouverture 

## Récemment implémenté

- **Vraies tabulations** : Tab insère `\t` au lieu de 4 espaces (GUI et TUI)
- **Reload retourne au browser** : `br-reload` (touche `z`) relance sans arguments, revenant toujours au browser
- **Titre du browser** : Affiche "Writhdeck Browser" au lieu de "Writhdeck"
- **Alias `--cli`** : `--cli` est un alias de `--tui` pour le mode terminal
- **Makefile robuste** : Détecte les changements des sources et régénère même si les fichiers existent

## Déjà implémenté (à ne pas re-suggérer)

- **Typewriter scrolling** : `typewriter-center`, `typewriter-tick`, mode Hemingway (`Ctrl+T`)
- **Dialogue config profils** : Accès complet aux paramètres de police par profil (famille, taille, marges), sélection du profil par défaut, sélection du scheme de couleurs, preview en temps réel
