# WrithDeck — référence développement

## Version

Format : `vYYYYMMDD` (ex. `v20260508`). Définie ligne ~32 :
```tcl
set ::version "v20260508"
```
Affichée dans l'aide GUI (section DATE & TIME) et l'aide TUI (en-tête en inversé + ligne dessous).

> **Règle** : mettre à jour la version (`set ::version "vYYYYMMDD"`) à chaque modification fonctionnelle.

## Structure du code (`writhdeck.tcl`, ~4 300 lignes)

| Zone | Lignes approx. | Contenu |
|---|---|---|
| Version + Bootstrap | 1–125 | `::version`, shebang, args, détection GUI/TUI |
| Persistance état | 126–245 | `.writhdeck.json`, curseurs, favoris, récents |
| INI / config | 241–680 | `ini-load`, `ini-save`, profils, schemes |
| i18n | 660–820 | dict `::i18n`, proc `t` |
| Utils / docs | 820–960 | `list-docs`, `br-dirs`, `fmt-meta` |
| GUI — browser | 960–1 520 | frame `.br`, `br-refresh`, bindings |
| GUI — éditeur | 1 520–2 200 | frame `.ed`, status bar, load/save |
| GUI — dialogs | 2 200–2 430 | `help-dialog`, `info-dialog`, etc. |
| GUI — features | 2 430–2 750 | split view, TOC, typewriter, search |
| TUI — utils | 2 750–3 340 | `tui-getch`, `tui-bar`, `tui-prompt` |
| TUI — browser | 3 340–3 500 | `tui-browser` |
| TUI — éditeur | 3 500–4 200 | `tui-editor` |
| Démarrage | 4 200–fin | `tui-main`, entrée GUI/TUI |

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
- Format `daily` : tableau de strings `"filepath\tdate\tN"` (tab comme séparateur)

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

## Procs partagées GUI/TUI

- `build-extra-entries {shown}` — construit les entrées favoris+récents, filtre `shown`
- `toggle-favorite {path}` — bascule dans `::favorites_list` + `state-save`
- `do-backup {dir name}` — copie vers `$DOCS_DIR/backups/nom_YYYY-MM-DDTHHhMM.ext`, retourne le nom
- `daily-clear {filepath}` — efface toutes les stats d'un fichier + `state-save`

> **Règle** : toute proc appelée depuis `tui-browser` doit être définie **hors du bloc `if {!$::no_gui}`** (qui se termine ligne ~2934). Actuellement hors du bloc : `build-extra-entries`, `toggle-favorite`, `do-backup`, `daily-clear`, toutes les procs `daily-*`, `recent-*`, `state-*`.

## Patterns à respecter

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

## Déjà implémenté (à ne pas re-suggérer)

- **Typewriter scrolling** : `typewriter-center`, `typewriter-tick`, mode Hemingway (`Ctrl+T`)
