# darkman drives the color-scheme behind the gtk portal, rather than being the portal

**Status:** accepted

We want VS Code (and Ghostty, Chrome, fish) to follow the system light/dark
color-scheme, switched **both** automatically at sunrise/sunset **and** manually
by a keybind. [darkman](https://darkman.whynothugo.nl/) is the obvious engine —
it ships a sunrise/sunset scheduler, a `darkman toggle` CLI, and hooks. The
non-obvious part is _how_ it plugs in. darkman is built to be an XDG **Settings
portal** (it implements `org.freedesktop.impl.portal.Settings` and can serve the
`color-scheme` value directly). We deliberately **do not** use it that way.

Instead: `portal: false`, and darkman's transition hook
(`~/.local/share/darkman/set-color-scheme`) writes the
`org.gnome.desktop.interface color-scheme` gsetting. Our existing gtk portal
(`portals.conf` routes `Settings` → gtk, see
[the xdg-environment guide](../xdg-environment.md)) broadcasts that key to every
portal-aware app. darkman becomes the single **writer/scheduler**; the gtk portal
stays the **broadcaster**. The manual keybind (`dot-theme-toggle` → `darkman
toggle`) and the schedule both flow through darkman to the same gsetting.

## Considered options

- **darkman writes gsettings; gtk keeps serving the Settings portal** — chosen.
  Nothing downstream changes: the color-scheme key is exactly what apps already
  read, `fish`'s `auto-sync-theme` (which reads the dconf key directly, not the
  portal) keeps working unmodified, and the just-committed `Settings=gtk` routing
  and its GTK/xsettings theme bridge stay intact. darkman is a purely additive
  writer + scheduler.
- **darkman becomes the Settings portal (`portal: true`,
  `Settings=darkman`)** — rejected. It would override the `Settings=gtk` routing,
  taking the whole Settings namespace away from gtk for one key; and because
  `fish` reads the dconf key rather than the portal, fish would still need a
  separate mirror script. More moving parts, and it undoes recent work, for no
  gain here.

## Consequences

- Location for the schedule is supplied as chezmoi-templated `lat`/`lng` from the
  gitignored `chezmoi.toml` (not geoclue): a home location is private data and
  must not enter this public repo, and geoclue on Wayland/niri has no standard
  agent. The trade-off is that a box that physically moves keeps stale coordinates
  until re-`chezmoi init`ed — acceptable, since sunrise/sunset barely shift within
  a region.
- The manual keybind is an **override until the next scheduled transition**, not a
  lock — darkman has no "pause auto" concept and we chose not to build one.
- If darkman is uninstalled or its service stops, the color-scheme key simply
  stops changing (whatever it last held persists); apps keep reading it. Nothing
  breaks, switching just goes static.
