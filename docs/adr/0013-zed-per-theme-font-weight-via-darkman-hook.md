# Zed per-color-scheme font weight via the darkman hook

**Status:** accepted

Zed has no native way to vary `buffer_font_weight` by light/dark theme (desired:
400 in light, 200 in dark). Unlike VS Code, Zed also has no CSS-injection escape
hatch — the editor cannot load a user stylesheet at all. So the per-mode weight
has to come from _outside_ Zed. We drive it from the same
[darkman](https://darkman.whynothugo.nl/) transition hook that already re-themes
every other app: [`set-color-scheme`](../../home/dot_local/share/darkman/executable_set-color-scheme)
appends a `sed` that rewrites `buffer_font_weight` in Zed's `settings.json`, which
Zed hot-reloads. This makes Zed one more consumer in
[docs/theme-sync.md](../theme-sync.md), alongside VS Code, Ghostty and fish.

This is the Zed counterpart of [ADR 0011](0011-vscode-custom-css-for-font-weight.md)
(VS Code's per-theme weight via Custom CSS) — same goal, cheaper mechanism: no
patched application files, no per-update re-enable ritual, no "corrupt
installation" warning. It reuses the writer/broadcaster model from
[ADR 0010](0010-darkman-behind-gtk-portal.md).

## Considered options

- **darkman hook rewrites `buffer_font_weight`** — chosen. The only mechanism
  that yields a true global weight (base text _and_ syntax) that flips with the
  system mode, with no external editor patching. It reuses infrastructure that
  already exists and already fires on both the sunrise/sunset schedule and the
  `Mod+Shift+D` toggle.
- **`experimental.theme_overrides` keyed by theme name** — rejected. Pure config
  and chezmoi-clean, but it can only set `font_weight` per _syntax scope_, not one
  global weight. Matching the intent ("everything lighter in dark") means
  enumerating every scope per theme, it leaves non-tokenised text on the global
  weight, and the `experimental.` prefix is unstable.
- **Custom forked theme files with baked-in weights** — rejected. Same
  syntax-scope-only limitation as above, plus it forks Dracula / Catppuccin Latte
  and takes on drift from upstream theme updates.
- **A single compromise weight (e.g. 300) for both modes** — rejected. Clean and
  native, but drops the light-vs-dark difference that motivated the request — the
  same call rejected in ADR 0011.

## The chezmoi ↔ external-writer trade-off

The hook edits the _live_ `settings.json`, but chezmoi owns that file. They are
reconciled by making the source hold the **light baseline (400)**: after a
`chezmoi apply`, the file is correct in light mode and merely stale in dark mode
(shows 400 until the next transition or a manual `Mod+Shift+D`). We accept that
transient rather than reaching for a `run_after` re-sync script or a
`modify_`-managed file, because a wrong weight for a few seconds after an apply is
cosmetic and self-healing.

`sed` is used deliberately over `jq`: the file is JSONC (comments and trailing
commas), which `jq` cannot parse. The cost is a coupling — `buffer_font_weight`
must stay a single-line integer key — noted in both files.

The edit must also be **in place (truncate + rewrite the same inode)**, not a
`sed -i` atomic rename. Zed watches `settings.json` by inode; a rename points the
watch at a now-deleted inode and edits go unnoticed until Zed restarts. So the
hook writes via a temp file + `cat >`. Consequence: Zed must be **restarted once**
after first install to bind the watch, and settings should be edited as text —
using Zed's Settings UI rewrites the file to a new inode (and re-serialises the
weight to `400.0`), re-breaking the watch until the next restart.

## Consequences

- The apparatus buys exactly one thing: a 200-unit weight difference between
  light and dark. If it ever stops being worth it, delete the appended block in
  `set-color-scheme` and pick a single weight in `settings.json`; nothing else
  depends on it.
- `settings.json` stays un-templated and machine-independent — the weight is
  runtime state, not a chezmoi variable.
- Requires the font to ship a weight-200 instance. JetBrainsMonoNL Nerd Font Mono
  does (ExtraLight); a font without one would fall back and defeat the effect.
- Editing `buffer_font_weight` by hand, or letting a formatter reflow it onto
  multiple lines, will break the `sed`. Keep it as one line.
