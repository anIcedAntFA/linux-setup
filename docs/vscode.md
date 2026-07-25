# VS Code — themes, custom CSS, extension enablement

How this repo's VS Code config is organized: the settings/extensions snapshots,
the per-color-scheme font weight hack, and the "always on vs on demand"
extension model.

## Light/dark theme

VS Code follows the system color-scheme natively — no script. `settings.json`:

```jsonc
"window.autoDetectColorScheme": true,
"workbench.preferredLightColorTheme": "Github Light Theme",
"workbench.preferredDarkColorTheme": "Dracula Theme",
```

darkman drives the color-scheme; see [theme-sync.md](theme-sync.md).

## Per-color-scheme font weight (custom.css)

VS Code has **no native** per-theme `editor.fontWeight`
([issue #184404](https://github.com/microsoft/vscode/issues/184404)). It's done
with a small CSS injection via the
[Custom CSS and JS Loader](https://marketplace.visualstudio.com/items?itemName=be5invis.vscode-custom-css)
extension, pointed at a chezmoi-managed
[`custom.css`](../home/dot_config/Code/User/custom.css.tmpl):

```jsonc
"vscode_custom_css.imports": ["file://${userHome}/.config/Code/User/custom.css"]
```

`${userHome}` is expanded by the extension, so the path stays machine-independent.
The CSS branches on the `.vs` (light) / `.vs-dark` (dark) body class: dark stays
at the `editor.fontWeight` baseline (300); light bumps to 400, easier to read on
a bright background.

A depth texture reusing Ghostty's background images was tried here and
**abandoned** — see [ADR 0011](adr/0011-vscode-custom-css-for-font-weight.md).

> [!WARNING]
> Custom CSS **patches VS Code's own files**. The costs, accepted deliberately
> (see [ADR 0011](adr/0011-vscode-custom-css-for-font-weight.md)):
>
> 1. **Enable it:** Command Palette → **Enable Custom CSS and JS**, then reload.
>    Re-run this **after every VS Code update** (the patch is wiped and the
>    extension silently disables) **and after every edit to `custom.css`** — the
>    extension inlines the file's _contents_ into `workbench.html` at enable
>    time, so Reload Window alone keeps showing the previously inlined copy.
> 2. **Write access to the patched file** (Linux) — the `chown` below. A package
>    update resets the ownership, so this is a **per-update** step, not a
>    one-time one.
> 3. VS Code will warn **"Your installation appears to be corrupt"** after
>    patching — that's expected; dismiss it.

On Arch with `visual-studio-code-bin`, the file the extension patches is exactly:

```sh
sudo chown "$USER" \
  /usr/share/code/resources/app/out/vs/code/electron-browser/workbench \
  /usr/share/code/resources/app/out/vs/code/electron-browser/workbench/workbench.html
```

> [!CAUTION]
> Type that path **literally**. Do not derive it from `readlink -f "$(command -v
> code)"`: `/usr/bin/code` is a shell wrapper that `exec`s
> `/usr/share/code/bin/code`, so `readlink -f` resolves to `/usr/bin/code` and a
> `dirname …/..` on it yields **`/usr`**. Running `chown -R` on that re-owns the
> whole system and strips the setuid bit from `sudo`, `su` and `pkexec`, which
> costs a boot into `init=/bin/bash` to repair. Never `chown` under `/usr`
> except a literal, non-recursive path. (`/opt/visual-studio-code` is the old AUR
> layout and `/usr/lib/code` is Code-OSS; neither exists here.)

To back out: Command Palette → **Disable Custom CSS and JS**, remove the
extension and the `vscode_custom_css.imports` line.

## Format on save

`settings.json` has **no global `editor.defaultFormatter`** — formatting is routed
per language, because a global default pointing at a single-purpose formatter
makes saves in every other language either no-op or pop _"Biome is configured as
formatter but it cannot format 'Markdown'-files"_.

| Languages                              | Formatter                  |
| -------------------------------------- | -------------------------- |
| js, jsx, ts, tsx, json, jsonc          | `biomejs.biome`            |
| markdown, yaml, toml                   | `dprint.dprint`            |
| shellscript / fish                     | shell-format / vscode-fish |
| dockercompose, github-actions-workflow | `redhat.vscode-yaml`       |

Both biome and dprint are **project-scoped**: in a project with no `biome.json` /
`dprint.json` the pinned formatter simply doesn't run.

A repo can override any of these from its own `.vscode/settings.json`, but **only
with a per-language block** — a language-specific default in _user_ settings
outranks a plain `editor.defaultFormatter` set at _workspace_ scope. This repo's
[`.vscode/settings.json`](../.vscode/settings.json) does exactly that, including a
`[github-actions-workflow]` pin: `.github/workflows/*.yml` gets that languageId
rather than `yaml`, so without it the user-scope redhat pin would win and a save
would fail `dprint check` in CI.

Markdown is **linted, not auto-fixed**, on save: dprint formats, `rvben.rumdl`
only shows diagnostics. That mirrors the toolchain exactly — `just fmt` runs
dprint alone and `just check` runs `rumdl check` with no `--fix` — so the editor
and CI can never disagree. Fix violations deliberately via **rumdl: Fix all** or
Quick Fix.

## Extension enablement — always on vs on demand

VS Code cannot "install an extension disabled," so this is a curation +
manual-enable model, not automation.
[`packages/vscode-extensions.txt`](../packages/vscode-extensions.txt) is split
into two commented groups:

- **Always on** — editor-wide / language-agnostic tools (themes, GitLens,
  formatters, icons, spell check, error lens, markdown, shell) — enabled globally.
- **On demand** — language/framework/tool-specific (rust-analyzer, Go, Vue,
  Svelte, Tailwind, Docker, ESLint…) — kept globally **disabled**, enabled
  per project.

The install script installs **all** of them (the grouping is documentation). To
apply the intent:

1. In VS Code, for each **on demand** extension: gear → **Disable** (global).
2. Per project: open the folder → gear → **Enable (Workspace)** for the ones that
   project needs. The choice persists for that workspace.

Move lines between the groups freely; it changes nothing at install time.

## Settings notes

- **`js/ts.*` unified keys.** VS Code merged the per-language `javascript.*` /
  `typescript.*` settings into one `js/ts.*` namespace and deprecated the old
  ones. This repo uses the unified form
  (`js/ts.inlayHints.parameterNames.enabled`, `js/ts.preferences.quoteStyle`,
  `js/ts.updateImportsOnFileMove.enabled`). Note the `.enabled` suffix — bare
  `js/ts.inlayHints.parameterNames` is not a real key and silently does nothing.
- The definitive way to spot a stale/invalid setting is VS Code's own squiggle in
  `settings.json` — it validates against the live schema of your installed version
  and extensions.

## Install

Extensions are installed on `chezmoi apply` (if `installPackages` was enabled) by
[`run_onchange_install-vscode-extensions.sh.tmpl`](../home/.chezmoiscripts/run_onchange_install-vscode-extensions.sh.tmpl),
or by hand:

```sh
grep -vE '^\s*(#|$)' packages/vscode-extensions.txt | xargs -L1 code --install-extension
```
