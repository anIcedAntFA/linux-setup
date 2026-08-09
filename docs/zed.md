# Zed

[Zed](https://zed.dev/) editor config, tracked so a fresh machine comes up
identical. Everything lives under `~/.config/zed/` and is chezmoi-managed from
[`home/dot_config/zed/`](../home/dot_config/zed):

| File            | Purpose                                                      |
| --------------- | ------------------------------------------------------------ |
| `settings.json` | Curated overrides only (not a dump of defaults) + extensions |
| `keymap.json`   | Custom key bindings on top of the VS Code base keymap        |

Project-scoped settings for a specific repo live in that repo's own `.zed/`
(committed to its git, not chezmoi) — see [Global vs project](#global-vs-project-settings-zed).

Only **intentional overrides** are tracked. To see everything Zed defaults to,
run `zed: open default settings` from the command palette (`Ctrl+Shift+P`); do
not copy it in — defaults drift between versions.

## Install & apply

```sh
chezmoi apply            # writes ~/.config/zed/*
```

On first launch Zed reads `auto_install_extensions` in `settings.json` and pulls
every listed extension automatically — no manual install list to maintain.

External formatters must be on `PATH` (mise provides them): **dprint**, **shfmt**,
**fish_indent**. **Biome** is fetched by its extension, so it needs nothing on
`PATH`. Go needs **gopls** (+ **dlv** for debugging) on `PATH` — `mise` / `just setup`.

## Per-color-scheme font weight (400 light / 200 dark)

Zed has **no native per-theme font weight** and no CSS injection, so the weight is
driven from outside the editor — by the same darkman transition hook that
re-themes everything else (see [theme-sync.md](theme-sync.md)). The hook
[`set-color-scheme`](../home/dot_local/share/darkman/executable_set-color-scheme)
`sed`-rewrites `buffer_font_weight` in `settings.json` (200 in dark, 400 in
light); Zed hot-reloads it.

The source keeps the **400 light baseline**, so a `chezmoi apply` while in dark
mode shows 400 until the next transition or a manual `Mod+Shift+D` — an accepted,
self-healing transient. Full rationale and alternatives:
[ADR 0013](adr/0013-zed-per-theme-font-weight-via-darkman-hook.md) (the Zed
counterpart of [ADR 0011](adr/0011-vscode-custom-css-for-font-weight.md)).

> Keep `buffer_font_weight` a single-line integer key — the hook edits it by
> regex.

**Restart Zed once after installing.** Zed watches `settings.json` by _inode_, so
the hook rewrites the file **in place** (truncate + rewrite, same inode) rather
than `sed -i` (which renames to a new inode and silently breaks the watch). A
fresh Zed start binds the watch to the current inode; after that, toggles
hot-reload the weight live. Corollary: changing a setting through Zed's **Settings
UI** rewrites the file to a new inode (you'll see `buffer_font_weight` become
`400.0`) and re-breaks the watch until the next restart — so edit settings as
**text**, not via the UI.

## Extensions — VS Code parity

Zed bundles a lot that needs an extension in VS Code, so the extension list is
short. What each VS Code extension maps to:

| Need                     | Zed                                                             |
| ------------------------ | --------------------------------------------------------------- |
| HTML / CSS / SCSS        | **built-in**                                                    |
| JS / TS / TSX / JSX      | **built-in** (+ `tsgo` language server)                         |
| Go                       | **built-in** (gopls) + `golangci-lint`, `templ`                 |
| Rust                     | **built-in** (rust-analyzer)                                    |
| Tailwind                 | **built-in**                                                    |
| ESLint                   | **built-in** (diagnostics; `code_action: source.fixAll.eslint`) |
| auto-rename-tag          | **built-in** (`linked_edits`)                                   |
| Error Lens               | **built-in** (`diagnostics.inline`)                             |
| EditorConfig             | `editorconfig` extension                                        |
| Markdown preview / lint  | **built-in** preview + `markdown-oxide`                         |
| MDX                      | `mdx` extension (srazzak) — TS-in-MDX on via `lsp.mdx-analyzer` |
| GitLens                  | `git-firefly` (blame / history) + native git — see Git, below   |
| Astro / Svelte / Vue     | `astro` / `svelte` / `vue` extensions                           |
| Dockerfile               | `dockerfile` extension                                          |
| Fish                     | `fish` extension (+ `fish_indent` formatter)                    |
| Just / TOML              | `just` / `toml` extensions                                      |
| Biome                    | `biome` extension (LSP + formatter)                             |
| Material icons / Dracula | `material-icon-theme` / `dracula` extensions                    |
| Catppuccin Latte (light) | `catppuccin` extension                                          |

### Gaps (no Zed extension yet)

- **PandaCSS** — no Zed extension exists. `.ts` files using Panda still get the
  full TypeScript LSP; only Panda's token autocomplete / config awareness is
  missing. Writing one means wrapping Panda's own language server
  ([`@pandacss/language-server`](https://github.com/chakra-ui/panda)) in a Zed
  extension (Rust → WASM) per the
  [Language Extensions guide](https://zed.dev/docs/extensions/languages). Deferred
  — revisit when there's time to build it or a community one appears.
- **pretty-ts-errors** — no equivalent; Zed's TS diagnostics are decent but not
  prettified.

## Formatting & linting

Mirrors the VS Code per-language split. `format_on_save` is `"on"` globally;
languages with no explicit formatter fall back to their language server (gopls,
rust-analyzer, …).

| Language      | Formatter              | Notes                       |
| ------------- | ---------------------- | --------------------------- |
| JS / TS / TSX | Biome (LSP)            | + fixAll + organize imports |
| JSON / JSONC  | Biome (LSP)            |                             |
| Markdown      | dprint (external)      | trailing whitespace kept    |
| YAML / TOML   | dprint (external)      |                             |
| Shell         | shfmt (external)       |                             |
| Fish          | fish_indent (external) |                             |
| Go            | gopls (gofumpt)        | organize imports first      |

ESLint is **diagnostics-only** (for legacy repos that still ship an ESLint
config); new code uses Biome + oxlint, so there is deliberately no
`source.fixAll.eslint` on save.

### Go

`lsp.gopls.initialization_options` turns on `gofumpt`, `staticcheck`, a few
`analyses` (unusedwrite / useany / nilness), and inlay `hints` — mirroring the VS
Code Go setup. Inlay hints only render because `inlay_hints.enabled` is on
globally (Zed has no per-language enable). The per-project import grouping
(`"local": "<module>"`) is deliberately **not** global — it belongs in each Go
repo's own `.zed/settings.json`.

## AI

Two independent layers:

- **Edit predictions** (inline tab completion) — default **Zeta** (Zed's own
  model: no monthly cap, works on any machine signed into a Zed account). On the
  work machine switch to Copilot Enterprise by hand:
  `"edit_predictions": { "provider": "copilot" }`. Note a later `chezmoi apply`
  resets it to `"zed"` — re-edit, or template it later if that grates. Claude is
  too slow for this layer.
- **Agents (ACP)** — `claude-acp` is registered for the personal Claude Agent.
  Add a Copilot agent from the extension panel on the work machine when needed.
  Each agent is its own thread.

API keys are stored in the **system keychain**, never in `settings.json`, so this
config is safe in a public repo.

## Git

Native git covers the daily loop by keyboard: Git panel, Project Diff (split /
unified, editable hunks), per-hunk staging, inline blame, file history, commit,
branch/stash, push/pull/fetch, and button-driven conflict resolution.
`git-firefly` adds GitLens-style blame and history on top (current-line
`inline_blame` is on). What's still missing vs GitLens: interactive rebase UI,
history-graph, and a full repo explorer; the conflict UI is less polished than a
3-pane merge tool.

Heavy git (commit, rebase, conflict resolution) is done in the **terminal**;
Zed's role is reviewing diffs/changes in-editor (`Ctrl+G D`, the Git panel). The
integrated terminal's `EDITOR` is set to `zed --wait`, so a terminal `git commit`
opens its message back in this Zed.

## Keymap cheat-sheet

Base keymap is **VS Code**, so muscle memory carries over. Modifiers: `Ctrl` /
`Alt` / `Shift` are Zed's; **`Super` is niri's** and is never used here (niri
grabs it first). `⭑` = custom binding added in `keymap.json`; the rest are VS Code
base defaults.

### Navigation & files

| Keys           | Action                         |
| -------------- | ------------------------------ |
| `Ctrl+P`       | Quick-open file (fuzzy)        |
| `Ctrl+Shift+P` | Command palette                |
| `Ctrl+Shift+E` | Focus project panel (files)    |
| `Ctrl+B`       | Toggle project panel (sidebar) |
| `Ctrl+\``      | Toggle terminal                |
| `Ctrl+N`       | New file                       |
| `F2`           | Rename symbol                  |
| `Ctrl+Click`   | Go to definition               |

### Tabs & panes

| Keys                | Action                   |
| ------------------- | ------------------------ |
| `Ctrl+Tab`          | Next tab                 |
| `Ctrl+Shift+Tab`    | Previous tab             |
| `Ctrl+W`            | Close tab                |
| `Ctrl+\`            | Split pane               |
| `Ctrl+K` then arrow | Move focus between panes |

### Search

| Keys           | Action                    |
| -------------- | ------------------------- |
| `Ctrl+F`       | Find in file              |
| `Ctrl+H`       | Find & replace in file    |
| `Ctrl+Shift+F` | Find in project           |
| `Ctrl+Shift+H` | Find & replace in project |

### Editing

| Keys            | Action                     |
| --------------- | -------------------------- |
| `Ctrl+D`        | Add next occurrence        |
| `Ctrl+/`        | Toggle line comment        |
| `Alt+↑ / Alt+↓` | Move line up / down        |
| `Ctrl+.`        | Quick fix / code actions   |
| `F8 / Shift+F8` | Next / previous diagnostic |

### Git actions

| Keys               | Action                                      |
| ------------------ | ------------------------------------------- |
| `Ctrl+Shift+G` ⭑   | Focus the Git panel                         |
| `Ctrl+G` `D`       | Project Diff (all changes)                  |
| `Ctrl+Y` / `Alt+Y` | Stage hunk & move to next (in Project Diff) |
| `Ctrl+G` `↑ / ↓`   | Push / pull                                 |

Discover any binding with `Ctrl+K Ctrl+S` (open keymap) or the command palette;
the authoritative action list is [zed.dev/docs/all-actions](https://zed.dev/docs/all-actions).

## Global vs project settings (.zed)

Two settings layers, two portability channels:

| Layer       | Location          | Travels via         | Applies to             |
| ----------- | ----------------- | ------------------- | ---------------------- |
| **Global**  | `~/.config/zed/*` | chezmoi (dotfiles)  | every project, per box |
| **Project** | `<repo>/.zed/`    | that repo's own git | only that repo         |

A project `.zed/settings.json` **overrides** the global one for files opened in
that repo (more specific wins — like VS Code workspace vs user). It is committed
to the repo's git, so it clones with the repo — it is **not** chezmoi-managed and
never reaches `$HOME`.

Rule of thumb: **about you** → global (fonts, theme, keymap, AI, your default
tooling). **About the project** → `.zed/` (formatter routing that differs from
your global default, gopls `local` import grouping, repo-specific exclusions).
Only put the _deltas_ there — everything else is inherited from global.

This repo ships its own [`.zed/settings.json`](../.zed/settings.json), the
counterpart of [`.vscode/settings.json`](../.vscode/settings.json): global Zed
formats JSON with Biome, but this repo must use **dprint** (its CI enforces it),
so `.zed/` re-pins md/json/jsonc/yaml/toml → dprint, shell → shfmt, fish →
fish_indent. It is written self-contained (every language explicit) so any
contributor formats it correctly regardless of their own global config.

## Gotchas

- **Font weight not changing?** See the restart-once + inode note under
  [Per-color-scheme font weight](#per-color-scheme-font-weight-400-light--200-dark).
  Short version: restart Zed once after install, and edit settings as **text**,
  not via the Settings UI. The swap only fires on a transition, so right after a
  `chezmoi apply` toggle `Mod+Shift+D` once.
- **Saving `home/dot_config/zed/*.json` doesn't reformat it** — and that's
  expected. Those source files are excluded from dprint (they're hand-maintained
  JSONC with trailing commas), so in this repo the dprint formatter no-ops on
  them. The _live_ `~/.config/zed/settings.json` (outside the repo) formats fine
  because it falls under the global Biome routing instead.
- `home/dot_config/zed/**` is excluded from dprint (JSONC with trailing commas),
  so `just fmt` won't touch the global config. The repo-root `.zed/` is **not**
  excluded — it's kept dprint-clean (no trailing commas) like `.vscode/`.
