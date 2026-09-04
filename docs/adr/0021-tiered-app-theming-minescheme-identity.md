# Tiered app theming: MineScheme is the identity, Noctalia renders it

**Status:** accepted (2026-08-23) · amended (2026-08-23: gtk3/gtk4 moved Tier B → Tier A) · complements [ADR 0019](./0019-darkman-owns-mode-noctalia-follows.md)

Every app gets its dark/light theme through one of three tiers, chosen by what the
app can do on its own — not by routing everything through one mechanism:

- **Tier A — own config.** Apps that natively follow the system color-scheme theme
  themselves; their Noctalia template stays **off**. Ghostty (`theme = light:latte,
  dark:dracula`), Zed (`theme.mode: system`), VS Code (`autoDetect`), fish
  (`auto-sync-theme`), **GTK3/GTK4/libadwaita** apps (adw-gtk3 + the appearance
  portal — see the gtk3/gtk4 consequence below), **bat** (`--theme=base16` → the
  terminal's ANSI palette), **starship** (named ANSI colours → the terminal
  palette), and the portal-aware browsers.
- **Tier B — Noctalia template.** Apps that can't self-switch render the Noctalia
  palette per mode: btop, qt, niri, zathura.
- **Tier C — darkman hook.** Only for what a template can't express: fish live
  re-sync across running shells, Zed's per-mode font weight, the Papirus icon
  variant flip, **superfile**'s theme (it has no dark/light auto — the hook
  rewrites its single `theme =` value per mode), and the GTK `gtk-theme` +
  `accent-color` gsettings that steer the Tier-A GTK apps (see below).

The keystone is the **MineScheme custom palette** (`light` = Catppuccin Latte,
`dark` = Dracula). Because Noctalia's own palette _is_ MineScheme
(`[theme] source = "custom"`, `custom_palette = "MineScheme"`), every Tier-B
template emits that exact identity automatically — no per-app Dracula/Latte wiring.

## Considered options

- **Route everything through Noctalia** — rejected: Tier-A apps would be
  double-driven, and bat/starship already track the identity for free via the
  terminal's ANSI palette (which is itself Dracula/Latte from Ghostty).
- **Route everything through darkman hooks** — rejected: it would re-implement, per
  app, what Noctalia templates already do for qt/niri, and lose palette generation.
- **Unify on Catppuccin (drop Dracula)** — rejected: the split identity (Latte
  light / Dracula dark) is deliberate and already wired across Ghostty/fish/Zed.

## Consequences

- **gtk3/gtk4 moved Tier B → Tier A (amendment).** The Noctalia gtk template wrote
  `~/.config/gtk-{3,4}.0/noctalia.css` with `@define-color` overrides that GTK
  reads **only at app launch**. On a **live** toggle libadwaita flips its built-in
  light/dark base immediately, but the stale override rides on top — so an
  already-open Nautilus or ghostty tab-bar **inverted** (light widgets on a dark
  bg) until relaunched. GTK4/libadwaita already self-follow `org.freedesktop.appearance`
  live, and GTK3 follows the `gtk-theme` name, so the template earned nothing but
  the inversion. Fix: drop `gtk3`/`gtk4` from `[theme.templates].builtin_ids`,
  delete the leftover `gtk.css`/`noctalia.css`, and have the darkman hook flip two
  interface gsettings instead — `gtk-theme` (`adw-gtk3`/`adw-gtk3-dark`) and a
  **named** `accent-color` (`purple` dark / `teal` light, the nearest names to the
  Dracula `#bd93f9` / Latte-sapphire `#209fb5` accents). **Trade-off:** GTK app
  _chrome_ no longer carries the exact Dracula/Latte background colours — it uses
  adw-gtk3 + libadwaita's own neutrals — but it now switches **live with no
  relaunch and no inversion**, and the identity survives as the named accent plus
  Noctalia's own bar/niri/qt. Verified live: Nautilus + ghostty tab-bar flip
  correctly both directions with no stale css regenerated.
- **btop returns to a Noctalia template.** The reason it was pulled out to a
  darkman hook (forcing Dracula in dark) evaporates once the palette _is_
  MineScheme; the template's `pkill -SIGUSR2` even live-reloads a running btop,
  which the old sed-swap hook could not.
- **bat stays base16** (Noctalia's community `bat` template disabled): base16 is
  already live + Dracula/Latte via the terminal, and the template would rewrite
  `bat/config` and fight chezmoi.
- **Papirus can't be a Tier-B app.** Noctalia's `papirus-icons` template can't do
  per-mode Catppuccin/Dracula (no `--theme`, stock colours only), so folders go
  Tier C. `dot-setup-papirus` builds **two user-local thin icon themes** under
  `~/.local/share/icons`: `Papirus-Latte` (`Inherits=Papirus-Light` + Catppuccin
  Latte sapphire folders) and `Papirus-Dracula` (`Inherits=Papirus-Dark` + Dracula
  purple folders — matching the light `#209fb5` / dark `#bd93f9` identity accents);
  the darkman hook flips `icon-theme` between them. The first attempt —
  copying the upstream colours straight into the stock `Papirus-Light`/`-Dark` —
  fails: those variants **symlink** most size dirs back to base `Papirus`, so
  `cp -r` hits "cannot overwrite non-directory". Thin inherited themes override
  only the Places folder icons and inherit everything else, and live entirely
  under `$HOME` — so a toggle needs **no sudo** and no `papirus-folders` run.
- **superfile is Tier C, not Tier A.** It looks like a self-theming TUI but has no
  dark/light auto — only one `theme =` in `config.toml`. The darkman hook rewrites
  that line in place (catppuccin-latte / dracula); a running instance picks it up on
  next launch. (yazi, retired in favour of superfile, is dropped from the repo
  entirely — see ADR 0017 for its migration history.)
- **darkman still owns the mode** (ADR 0019) via `noctalia msg theme-mode-set`
  (a _fixed_ mode, which keeps Noctalia's own scheduler inert). v5 has no
  `syncGsettings` knob — the fixed mode alone is what stops Noctalia from fighting.
