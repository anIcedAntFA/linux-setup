# Noctalia config tracked as an app-owned snapshot, not templated

**Status:** accepted

Noctalia _owns_ its config: the shell rewrites `~/.config/noctalia/settings.json`
whenever a setting changes or the app upgrades, reformatting the whole file and
migrating its schema (observed `settingsVersion` climbing 53 → 59, with keys added
and removed across the jump). This makes it the opposite of the niri case in
[ADR 0006](./0006-per-machine-niri-via-chezmoi-template.md), where niri only _reads_
a plain-KDL config we own. So we track `home/dot_config/noctalia/**` as a **single
canonical snapshot** of one box (work, which is identical to home), copied by hand
from the live config when it's in a state worth keeping, and **not** a chezmoi
template. It's already excluded from `dprint` (the app's own formatting is the
source of truth). Per-machine differences are deliberately _not_ encoded in the
tracked file.

## Considered options

- **Track one canonical `settings.json`, sync manually, no templating** — chosen.
  The file is app-owned and self-migrating, so the source can only ever be a
  point-in-time snapshot; a plain copy is honest about that and survives schema
  bumps untouched. Cost: the tracked file lags the live one until a manual `cp`,
  and a fresh machine reproduces the work/home layout but not the laptop's tweaks.
- **chezmoi template keyed on `machine`** (the niri approach) — rejected. Noctalia
  rewrites the target file continuously, so every app-side change or schema
  migration would fight the template: `chezmoi diff` would be permanently noisy and
  each upstream key addition could break the render. Templating a 25 KB
  app-reformatted JSON is high-maintenance for little gain.
- **Stop tracking `settings.json` (chezmoiignore), keep only the stable sidecars**
  — rejected. Clean, but a fresh checkout would then reproduce _no_ layout at all;
  the snapshot is worth keeping even if it lags.

## Consequences

- **Laptop scale/size is machine-local.** The laptop applies the canonical file
  then hand-tweaks the handful of scale keys in the Noctalia GUI (`general.scaleRatio`,
  `general.animationSpeed`, `ui.fontDefaultScale`/`fontFixedScale`,
  `bar.fontScale`/`density`/`frameThickness`/`margin*`). Those edits live only on the
  laptop and are never synced back; a laptop reinstall redoes them by hand.
- **Sync is a manual `cp live → home/dot_config/noctalia/`**, done from work when the
  config is worth committing. Only `settings.json` and `plugins.json` tend to drift;
  `colors.json`, `user-templates.toml`, and `colorschemes/` stay stable.
- **Absolute paths are baked in.** `general.avatarImage` and `wallpaper.directory`
  hard-code the repo clone path (`/home/ngockhoi96/workspace/.../linux-setup/images/…`),
  which is only valid while every machine shares that username and clone location.
  This is the price of a plain snapshot over a template; revisit if a machine ever
  diverges on ghqRoot or username.
- `plugins.json` reflects the live state, which currently enables no plugins (the
  clipboard uses Noctalia's built-in launcher, not the Clipper plugin).
