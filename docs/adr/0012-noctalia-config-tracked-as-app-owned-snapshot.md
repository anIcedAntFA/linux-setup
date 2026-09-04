# Noctalia config tracked as an app-owned snapshot, not templated

**Status:** **superseded by [ADR 0020](./0020-noctalia-v5-config-tracked-as-toml-base-plus-machine.md)** (2026-08-23)

> **Superseded.** This ADR assumed v5 still reads `~/.config/noctalia/settings.json`.
> It does **not** — v5.0.0 uses a TOML model (`~/.config/noctalia/*.toml` +
> `~/.local/state/noctalia/settings.toml`), and `settings.json` is a dead v4 file.
> The snapshot approach and home-only scoping are replaced by a tracked base +
> per-machine TOML split; see [ADR 0020](./0020-noctalia-v5-config-tracked-as-toml-base-plus-machine.md).
> The rest of this file is kept for history.
>
> **v5 revision (historical).** The Noctalia v4→v5 migration ([ADR 0017](./0017-migrate-noctalia-v4-to-v5.md))
> does **not** overturn this decision: v5 still _owns_ `~/.config/noctalia/settings.json`
> and rewrites it on every change. What changed is (1) v5 splits **config**
> (`~/.config/noctalia/settings.json`, tracked) from **app state**
> (`~/.local/state/noctalia/settings.toml`, e.g. the active per-monitor wallpaper —
> **not** tracked); and (2) the snapshot is now **home-profile-only**, because the
> live config embeds this box's monitor connectors (`DP-3`, `HDMI-A-1`) and
> absolute wallpaper paths. See the home-scoping note below.

Noctalia _owns_ its config: the shell rewrites `~/.config/noctalia/settings.json`
whenever a setting changes or the app upgrades, reformatting the whole file and
migrating its schema. This makes it the opposite of the niri case in
[ADR 0006](./0006-per-machine-niri-via-chezmoi-template.md), where niri only _reads_
a plain-KDL config we own. So we track `home/dot_config/noctalia/**` as a **single
canonical snapshot**, copied by hand from the live config when it's in a state worth
keeping, and **not** a chezmoi template. It's already excluded from `dprint` (the
app's own formatting is the source of truth).

## Considered options

- **Track one canonical `settings.json`, sync manually, no templating** — chosen.
  The file is app-owned and self-migrating, so the source can only ever be a
  point-in-time snapshot; a plain copy is honest about that and survives schema
  bumps untouched. Cost: the tracked file lags the live one until a manual `cp`.
- **chezmoi template keyed on `machine`** (the niri approach) — rejected. Noctalia
  rewrites the target file continuously, so every app-side change or schema
  migration would fight the template: `chezmoi diff` would be permanently noisy and
  each upstream key addition could break the render. Templating a ~26 KB
  app-reformatted JSON is high-maintenance for little gain.
- **Stop tracking `settings.json` (chezmoiignore), keep only the stable sidecars**
  — rejected. Clean, but a fresh checkout would then reproduce _no_ layout at all;
  the snapshot is worth keeping even if it lags.

## Consequences

- **Home-profile-only.** The tracked config embeds home-specific monitor
  connectors and absolute paths, so `.chezmoiignore` excludes
  `.config/noctalia` (and the per-monitor wallpaper hook
  `.local/share/darkman/set-wallpaper`) on the `work` and `laptop` profiles. A
  non-home box runs Noctalia with its own fresh config, untracked. If Noctalia is
  ever wanted on another profile, that profile gets its own snapshot rather than
  sharing this one.
- **Config vs state.** Only `~/.config/noctalia/settings.json` (widget/bar layout,
  `colorSchemes`, `templates`, `wallpaper.directory`, favorites) is tracked. The
  **active per-monitor wallpaper** lives in `~/.local/state/noctalia/settings.toml`
  and is set imperatively (`noctalia msg wallpaper-set <connector> <path>`); it is
  reproduced by the darkman `set-wallpaper` hook, not by the snapshot.
- **Sync is a manual `cp live → home/dot_config/noctalia/`**, done when the config
  is worth committing. Only `settings.json` and `plugins.json` tend to drift;
  `colors.json`, `user-templates.toml`, and `colorschemes/` stay stable.
- **Absolute paths are baked in.** `general.avatarImage` and `wallpaper.directory`
  hard-code the repo clone path (`/home/ngockhoi96/workspace/.../dotfiles/images/…`,
  renamed from the old `linux-setup`), valid only while the box keeps that username
  and clone location. This is the price of a plain snapshot over a template.
- **The theme knobs are captured here.** `colorSchemes.syncGsettings:false`
  (Noctalia follows darkman — [ADR 0019](./0019-darkman-owns-mode-noctalia-follows.md)),
  the custom `MineScheme` palette (`predefinedScheme`, with both dark and light
  variants), and the disabled `btop` template all live in this snapshot.
