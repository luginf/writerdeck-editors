# WrithDeck — référence développement

## Version

Format : `vYYYYMMDD` (ex. `v20260507`). Définie ligne ~32 :
```tcl
set ::version "v20260507"
```
Affichée dans l'aide GUI (section DATE & TIME) et l'aide TUI (en-tête en inversé + ligne dessous).

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
{"cursors":{"chemin":[cy,cx]},"favorites":["chemin"],"recent":["chemin"]}
```

- Chargement lazy via `state-load` (guard `$::state_cache_valid`)
- Écriture via `state-save` (écrase tout à chaque fois)
- Procs : `cursor-get/put`, `recent-push/remove/rename`, `toggle-favorite`, `recent-rename`
- Migration `.cursors.json` supprimée (pas de rétro-compat)

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

- `build-extra-entries {shown}` — construit les entrées favoris+récents, filtre `shown` — **définie hors du bloc GUI** (nécessaire pour `tui-browser`)
- `toggle-favorite {path}` — bascule dans `::favorites_list` + `state-save`
- `do-backup {dir name}` — copie vers `$DOCS_DIR/backups/nom_YYYY-MM-DDTHHhMM.ext`, retourne le nom

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

## Idées non implémentées (depuis `writhdeck-info.txt`)

- **Auto-save** : sauvegarder après N secondes d'inactivité (`after` Tcl)
- **Objectif de mots** : barre de progression dans la status bar
- **Statistiques de session** : temps d'écriture, mots ajoutés
- **Recherche dans tous les fichiers** : grep sur le dossier depuis le browser (touche `g` ?)
- **Export HTML** : conversion headings + texte
- **Mouse support TUI** : `\033[?1000h` pour clic-positionnement
- **Presse-papiers interne** : historique des N derniers copier-coller
- **Typewriter scrolling** : curseur centré verticalement (`yview moveto`) — jugé le plus utile
