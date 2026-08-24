# Noctalia v5 config tracked as TOML (base + per-machine), palette as a file

**Status:** accepted (2026-08-23) · **supersedes [ADR 0012](./0012-noctalia-config-tracked-as-app-owned-snapshot.md)**

Noctalia **v5.0.0 no longer reads `~/.config/noctalia/settings.json`.** It uses a
TOML model: built-in defaults → every `~/.config/noctalia/*.toml` (hand-curated,
loaded alphabetically) → `~/.local/state/noctalia/settings.toml` (the app/GUI
override layer, which wins conflicts). `noctalia config validate` reads **only** the
TOML set. ADR 0012 was therefore tracking a **dead v4 file** — proven live: the
`settings.json` on this box said `light`/`MineScheme` while the effective
`settings.toml` said `dark`/`custom`, and the two disagreed on almost everything.

So we now track a **curated TOML layer**, split for multi-machine:

- `home/dot_config/noctalia/00-base.toml` — machine-agnostic (theme, templates,
  bar layout, shell, plugins). Tracked on **every** profile.
- `home/dot_config/noctalia/10-machine.toml.tmpl` — per-machine, branched on
  `.machine` (monitors, wallpaper, DPI, lockscreen widget positions). home/work
  share DP-3 + HDMI-A-1; laptop gets an eDP-1 placeholder.
- `home/dot_config/noctalia/palettes/MineScheme.json` — the custom palette (the
  Catppuccin-Latte/Dracula identity — [ADR 0021](./0021-tiered-app-theming-minescheme-identity.md)).
  In v5 custom palettes live in `palettes/`, **not** the v4 `colorschemes/<name>/`.

## Considered options

- **Keep snapshotting `settings.json`** (ADR 0012) — rejected: v5 doesn't read it.
- **Track a base + per-machine TOML split** — chosen. v5's alphabetical `*.toml`
  merge makes this a first-class mechanism, and it isolates the machine-specific
  noise (connectors, absolute paths) from the shareable identity.
- **Home-profile-only** (ADR 0012's scoping) — rejected now that work and laptop
  also run Arch/niri/Noctalia: the base + palette are shared, only the thin
  machine layer branches.

## Consequences

- **The GUI/state layer wins.** The tracked `*.toml` is the low-precedence base;
  GUI edits land in the untracked `~/.local/state/noctalia/settings.toml`. To sync
  them back: ⋯ menu → **Export Config → Merged User Config** (the re-importable TOML
  format; "Full Effective Config" freezes defaults and is inspection-only), then
  fold the diff into `00-base.toml` / `10-machine.toml.tmpl`.
- **Fresh machine.** Drop the tracked `*.toml` in and do **not** carry over
  `settings.toml` (let it regenerate), so the tracked base actually takes effect.
- **Dead v4 files removed** from the repo: `settings.json`, `colors.json`,
  `colorschemes/`, `user-templates.toml` (a stub v5's validator rejects), and
  `plugins.json` (plugins now live in `[plugins]` — `bongocat`, `screen_recorder`).
- **`set-wallpaper` no longer `jq`s the dead JSON** for `wallpaper.directory`; the
  path is baked in via chezmoi and the hook is now a `.tmpl` branched per machine.
