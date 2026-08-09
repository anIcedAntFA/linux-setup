# Theme sync — darkman · gtk portal · per-app themes

Make every app follow one system **light/dark color-scheme** — switched both
**automatically** at sunrise/sunset and **manually** by a keybind — without each
app growing its own theme-switcher.

## The one idea

There is a single source of truth: the `org.gnome.desktop.interface color-scheme`
gsetting (`prefer-dark` / `prefer-light`). Everything else either **writes** it or
**reads** it.

```text
sunrise/sunset schedule ─┐
                         ├─► darkman ─► set-color-scheme hook ─► gsettings color-scheme
Mod+Shift+D (toggle) ────┘   (writer)   (gsettings set …)              │
                                                                       ▼
                                                       gtk XDG portal (Settings=gtk)
                                                                       │  broadcasts
                            ┌──────────────────────────┬───────────────┴───────────┐
                            ▼                          ▼                            ▼
                      VS Code (autoDetect)        Ghostty / Chrome / Zed      fish auto-sync-theme
                      Dracula ↔ Github Light      (portal-aware)              Dracula ↔ Catppuccin Latte

               Zed's font weight is the exception: it rides the set-color-scheme hook, not the portal.
```

[darkman](https://darkman.whynothugo.nl/) is the **writer and scheduler**; the gtk
portal is the **broadcaster**. See
[ADR 0010](adr/0010-darkman-behind-gtk-portal.md) for why darkman writes the
gsetting instead of being the Settings portal itself (short version: it keeps the
`Settings=gtk` routing and lets `fish`, which reads the dconf key directly, work
unchanged).

The **color-scheme** (the dark/light _mode_) and a **theme** (an app's actual
palette for that mode) are different things — see
[CONTEXT.md](../CONTEXT.md#appearance).

## The two triggers

| Trigger        | What runs                                                                                  | Notifies?   |
| -------------- | ------------------------------------------------------------------------------------------ | ----------- |
| Sunrise/sunset | `darkman` service, from `lat`/`lng` in the config                                          | no          |
| `Mod+Shift+D`  | [`dot-theme-toggle`](../home/dot_local/bin/executable_dot-theme-toggle) → `darkman toggle` | yes (toast) |

A manual toggle is an **override, not a lock**: it flips the mode now, and the
schedule reclaims control at the next sunrise/sunset. darkman has no "pause auto"
mode, and we deliberately didn't build one.

## Pieces in this repo

- [`home/dot_config/darkman/config.yaml.tmpl`](../home/dot_config/darkman/config.yaml.tmpl)
  — `lat`/`lng` (from the gitignored `chezmoi.toml`, a home location is private),
  `usegeoclue: false`, `portal: false`.
- [`home/dot_local/share/darkman/executable_set-color-scheme`](../home/dot_local/share/darkman/executable_set-color-scheme)
  — darkman's transition hook; `$1` is `dark`/`light`, it runs `gsettings set …
  color-scheme prefer-*`. Runs on **both** the schedule and manual toggles. It
  also `sed`-swaps Zed's `buffer_font_weight` (200 dark / 400 light), since Zed
  has no native per-theme weight — see [zed.md](zed.md) and
  [ADR 0013](adr/0013-zed-per-theme-font-weight-via-darkman-hook.md).
- [`home/dot_local/bin/executable_dot-theme-toggle`](../home/dot_local/bin/executable_dot-theme-toggle)
  — the `Mod+Shift+D` target: `darkman toggle` + a one-shot `notify-send`.
- `window.autoDetectColorScheme` + `workbench.preferred{Light,Dark}ColorTheme` in
  [VS Code settings](../home/dot_config/Code/User/settings.json) — native follow,
  no script.
- [`fish/functions/auto-sync-theme.fish`](../home/dot_config/fish/functions/auto-sync-theme.fish)
  — reads the same color-scheme key on shell start and picks the fish theme.
- `theme.mode: "system"` in [Zed settings](../home/dot_config/zed/settings.json)
  — native portal follow (Dracula ↔ Catppuccin Latte); its per-mode font weight
  rides the `set-color-scheme` hook above. See [zed.md](zed.md).

## Install

darkman is in [`packages/pacman-explicit.txt`](../packages/pacman-explicit.txt):

```sh
yay -S --needed darkman
```

The user service is enabled automatically on `chezmoi apply` by
[`run_onchange_after_enable-darkman-service.sh.tmpl`](../home/.chezmoiscripts/run_onchange_after_enable-darkman-service.sh.tmpl).
To do it by hand:

```sh
systemctl --user enable --now darkman.service
```

Set this machine's coordinates when prompted at `chezmoi init` (`lat`/`lng`); one
or two decimals is plenty ([relevant xkcd](https://xkcd.com/2170/)).

Don't know them off-hand? Ask your IP — city-level precision is all darkman needs:

```sh
curl -s ipinfo.io   # read the "loc" field: "10.82,106.63" = lat,lng
```

Run it **off the work VPN**. Over GlobalProtect (or any VPN) `ipinfo.io` returns
the exit datacenter's location, not yours — darkman would then flip light/dark on
the wrong schedule. See [vpn.md](vpn.md).

## Verify

```sh
darkman get                                                   # current mode
gsettings get org.gnome.desktop.interface color-scheme        # what apps read
darkman toggle                                                # flip and watch apps follow
systemctl --user status darkman.service                       # scheduler alive?
```

VS Code, Ghostty, and Chrome should re-theme live on a toggle; a fish shell picks
up the new theme on its next launch.

## References

- [darkman](https://darkman.whynothugo.nl/) · `man darkman`, `man darkman.conf`
- [Portal configuration for darkman](https://whynothugo.nl/journal/2024/04/09/darkman-portal-configuration/)
- [xdg-environment.md](xdg-environment.md) — how `Settings` is routed to the gtk portal
