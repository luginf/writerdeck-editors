# WrithDeck — référence développement

## Version

Format : `vYYYYMMDD` (ex. `v20260512`). Définie ligne ~32 :
```tcl
set ::version "v20260513"
```
Affichée dans l'aide GUI (section DATE & TIME) et l'aide TUI (en-tête en inversé + ligne dessous).

> **Règle** : mettre à jour la version (`set ::version "vYYYYMMDD"`) à chaque modification fonctionnelle, avec la date du jour.

## Structure modulaire (généré via Makefile)

Le code est organisé en modules dans `src/`, concaténés par `make` pour générer les fichiers exécutables. Lecture des fichiers source pour développement ; lecture des fichiers générés (`writhdeck.tcl`, `writhdeck-cli.tcl`) pour comprendre l'ordre d'exécution.

| Module | Lignes | Contenu |
|---|---|---|
| `src/boot.tcl` | ~80 | Polyglot sh/Tcl, args, détection Tk, `::HOME_DIR`, `tilde-expand` |
| `src/boot-cli.tcl` | ~80 | Variante CLI : pas de Tk, force `::no_gui 1` |
| `src/state.tcl` | ~147 | `.writhdeck.json`, curseurs, favoris, récents, stats quotidiennes |
| `src/config.tcl` | ~804 | INI, profils, thèmes, clés, système i18n complet, `proc t` |
| `src/common.tcl` | ~204 | `list-docs`, `br-dirs`, `do-backup`, `build-extra-entries`, parseurs |
| `src/gui.tcl` | ~2001 | Bloc GUI (Tk) entier enveloppé dans `if {!$::no_gui}` |
| `src/tui.tcl` | ~1644 | Interface TUI — `tui-init`, `tui-browser`, `tui-editor`, `tui-main` |
| `src/main.tcl` | ~31 | Dispatch final : GUI ou TUI selon `$::no_gui` |
| `src/main-cli.tcl` | ~2 | Entry point CLI : appelle `tui-main` directement |

**Fichiers générés** (~5000 lignes) :
- `writhdeck.tcl` — version complète GUI+TUI avec tous les modules + marqueurs de section
- `writhdeck-cli.tcl` — version TUI seule (sans `src/gui.tcl`, pas de chargement Tk)

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

## Timer et chronomètre

Minuterie compte à rebours et chronomètre (stopwatch) configurables, accessibles via le mode modal ESC ou la touche ALT+t.

**Configuration** (`src/config.tcl`):
- `cfg_timer_duration` — durée par défaut en minutes (25 par défaut)
- `cfg_timer_sound` — jouer un bip à la fin (booléen, sauvegardé en INI)
- `cfg_timer_type` — "countdown" ou "stopwatch"
- `cfg_timer_alert` — afficher une alerte visuelle à la fin (booléen)

**Affichage dans la status bar** :
- Format `m'ss"` (ex. `4'00"` pour 4 minutes)
- Timer actif : `[4'00"]`, inactif : ` 4'00"`
- Géré par `status-build` dans `src/common.tcl` (token : "timer")

**Procs contrôle** (`src/config.tcl`):
- `timer-start` — démarre compte à rebours/chronomètre
- `timer-pause` — pause le timer
- `timer-reset` — réinitialise à la durée configurée
- `timer-tick` — mise à jour en arrière-plan (appelée par `after` chaque seconde)
- `timer-alert` — alerte visuelle + bip quand compte à rebours = 0

**Implémentation alerte** :
- **GUI** (`timer-alert-gui`): Dialog Toplevel avec message "Timer finished!" + commande `bell`
- **TUI** (`tui-timer-alert`): Overlay plein écran avec message "TIMER FINISHED!" + commande `bell`
- Son contrôlé par `$::cfg_timer_sound`

## Mode commande modal (touche ESC)

Mode activé en appuyant sur ESC dans l'éditeur (GUI ou TUI). Permet un accès rapide aux fonctions courantes sans perdre la focus du texte.

**Fonctionnalités du mode modal** :
- **ESC** — basculer modal on/off (double ESC = quitter)
- **t** — basculer timer on/off
- **s** — afficher stats d'écriture quotidiennes (overlay plein écran)
- **w** — afficher occurrences de mots (overlay TUI, dialog GUI)
- **q** — quitter/fermer fichier courant (avec prompt de sauvegarde si modifié)
- **Autres touches** — quitter modal, revenir à l'édition normale

**Détails implémentation** :
- État tracé par `$::gui_cmd_mode` (GUI) et `$::tui_cmd_mode` (TUI)
- Message modal affiché dans `::ed_bar_center` (GUI) ou ligne de message (TUI)
- Keybindings vérifient l'état modal avant traiter l'input normal
- Logique ESC en TUI : vérifier d'abord si déjà EN mode modal (prévient entrée accidentelle)

## Procs partagées GUI/TUI

- `build-extra-entries {shown}` — construit les entrées favoris+récents, filtre `shown`
- `toggle-favorite {path}` — bascule dans `::favorites_list` + `state-save`
- `do-backup {dir name}` — copie vers `$DOCS_DIR/backups/nom_YYYY-MM-DDTHHhMMmSS.ext` (timestamp avec secondes), retourne le chemin complet `$dst`. Le message de succès affiche `[file dirname $dst]` avec `~` pour le HOME.
- `get-word-occurrences {fpath}` — ouvre avec `-encoding utf-8`, retourne des paires `{mot count}` triées par count décroissant.
- `daily-clear {filepath}` — efface toutes les stats d'un fichier + `state-save`

> **Règle** : toute proc appelée depuis `tui-browser` doit être définie **hors du bloc `if {!$::no_gui}`** (qui se termine ligne ~2934). Actuellement hors du bloc : `build-extra-entries`, `toggle-favorite`, `do-backup`, `daily-clear`, toutes les procs `daily-*`, `recent-*`, `state-*`.

## Procs TUI — dialogs et overlays

Définies dans `src/tui.tcl`, toutes suivent le pattern no-flicker :

| Proc | Description |
|---|---|
| `tui-info-dialog {text rows cols}` | Overlay centré en reverse-video, attend n'importe quelle touche |
| `tui-stats-dialog {filepath rows cols}` | Stats d'écriture : tri décroissant, total, `c` clear, `q` fermer. Retourne `[t br_stats_no_data]` si vide |
| `tui-word-occurrences {fpath rows cols}` | Occurrences de mots scrollables (UP/DOWN/HOME/END), `q` fermer |
| `tui-config-dialog {rows cols}` | Config timer/chronomètre |
| `tui-help-dialog {rows cols wc cc ...}` | Aide scrollable |

**Pattern no-flicker pour les dialogs TUI** :
1. `puts -nonewline "\033\[2J\033\[H"; flush stdout` — une seule fois **avant** la boucle `while 1`
2. `puts -nonewline "\033\[H"` — **dans** la boucle (repositionne le curseur sans effacer)
3. Chaque ligne se termine par `\033\[K` (efface jusqu'à fin de ligne)
4. Pas de `\033\[2J` après la boucle — le browser/éditeur redessine lui-même

**`tui-getch` — comportement bloquant** :
- Sans timer actif : lecture bloquante `read stdin 1` → curseur reste visible jusqu'au prochain appui
- Avec timer actif (`cfg_chrono_show`) : poll 50ms → retourne `""` si pas de touche (le timer se met à jour)
- Appel explicite `tui-getch 0` : non-bloquant, retourne `""` immédiatement

**Scroll dans les overlays** : toujours borner avec `max(0, total - usable)` pour éviter les indices négatifs quand le contenu tient en une page (`lindex list -N` retourne `""` en Tcl).

**Browser touche `i`** : appelle `tui-info-dialog` (overlay persistant). Ne jamais utiliser `set msg $path` pour les infos qui doivent rester visibles — `msg` est effacé après un seul tick de boucle.

**GUI `profile-config-dialog`** : `grab $w` uniquement après `update` et création de tous les widgets. Un `grab` prématuré (avant que la fenêtre soit visible) lève "grab failed: window not viewable".

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

## Tests de régression

Les tests préviennent les bugs et assurent la cohérence. Lancés automatiquement via `make test`.

**Tests disponibles** :
- `make test-i18n` — Valide les traductions (clés complètes, format strings cohérents)
- `make test-syntax` — Vérifie la syntaxe Tcl via `info complete`
- `make test-gui` — Teste le chargement de `writhdeck.tcl` en mode GUI
- `make test-cli` — Teste le chargement de `writhdeck-cli.tcl` en mode CLI
- `make test-langs` — Teste différentes combinaisons LANGUAGES
- `make test` — Lance tous les tests

Stockés dans `tests/` :
- `tests/test-i18n.tcl` — Validation des dictionnaires i18n
- `tests/test-syntax.tcl` — Vérification syntaxe Tcl
- `tests/README.md` — Documentation des tests

Avant de committer, s'assurer que `make test` passe sans erreur.

## Système i18n (6 langues)

Stocké dans `src/i18n/`, chaque fichier définit les traductions d'une langue (122 clés).

**Langues supportées** :
- `en.tcl` — English (fallback, toujours incluse)
- `fr.tcl` — Français
- `de.tcl` — Deutsch
- `es.tcl` — Español
- `ko.tcl` — 한국어
- `no.tcl` — Norsk

**Récupérer une traduction dans le code** :
```tcl
set msg [t br_help_gui]                          # "h:help  n:new  ..."
set msg [format [t help_cur_time] "12:30"]      # Avec arguments
```

La proc `t {key args}` (dans `src/config.tcl`) consulte `::i18n[$::cfg_lang]` et retourne le contenu anglais en fallback si la clé manque.

**Construire avec une sélection de langues** :
```bash
make LANGUAGES="en"                 # Minimal : 95 KB
make LANGUAGES="en fr"              # Standard : 131 KB
make LANGUAGES="en fr de es ko no"  # Complet : 280 KB
```

Le Makefile détecte automatiquement tous les fichiers `src/i18n/*.tcl` via `AVAILABLE_LANGS`. Ajouter une langue : créer `src/i18n/XX.tcl` avec les 122 clés, puis `make` l'inclut automatiquement.

**Validation des traductions** :
```bash
make test-i18n    # Vérifie : toutes les clés présentes, pas de doublons, format strings cohérents
```

Voir `src/i18n/README.md` pour le guide complet (format, ajout de langue, format strings `%s`/`%d`, validation).

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
- **Correction `get-word-occurrences`** : retourne des paires `{mot count}`, ouvre avec `-encoding utf-8`. Itération : `foreach pair $word_data { lassign $pair word count }`
- **No-flicker TUI** : `tui-config-dialog`, `tui-help-dialog`, `tui-word-occurrences` — clear unique avant boucle, `\033[H` dans la boucle
- **`tui-getch` bloquant** : sans timer, lecture bloquante au lieu de spin → curseur stable
- **`tui-stats-dialog`** : proc extraite du browser, réutilisée par modal ESC+s
- **`tui-info-dialog`** : overlay persistant pour browser `i` et message "no words"
- **`tui-word-occurrences` scroll fix** : `max(0, total - usable)` évite les indices négatifs
- **Backup timestamp** : inclut les secondes (`%Hh%Mm%S`), message affiche le dossier de sauvegarde
- **GUI config grab fix** : `grab $w` déplacé après `update` et création des widgets

## Déjà implémenté (à ne pas re-suggérer)

- **Typewriter scrolling** : `typewriter-center`, `typewriter-tick`, mode Hemingway (`Ctrl+T`)
- **Dialogue config profils** : Accès complet aux paramètres de police par profil (famille, taille, marges), sélection du profil par défaut, sélection du scheme de couleurs, preview en temps réel
