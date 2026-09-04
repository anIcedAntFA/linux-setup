# Does Discord on Linux/Wayland follow the XDG appearance portal?

Research note — investigated 2026-08-23. Question: does Discord's "Sync with
computer" theme honour `org.freedesktop.appearance` `color-scheme` on
Linux/Wayland, and if not, why? Machine context (already verified, not
re-investigated): niri compositor, `xdg-desktop-portal-gtk` provides the
Settings portal, Discord runs native Wayland, and `dbus-monitor` confirms the
portal broadcasts `SettingChanged org.freedesktop.appearance color-scheme = 2`
on a `darkman` toggle — so the portal/broadcast side is proven working.

> Portal value legend (freedesktop spec): `0` = no preference, `1` = prefer
> dark, `2` = prefer light. So `color-scheme = 2` means the OS asked for **light**.
> Source:
> <https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.Settings.html>

## TL;DR

Yes, in principle. Discord ("Sync with computer") is Electron; Electron/Chromium
read the appearance portal via Chromium's `DarkModeManagerLinux`, which landed
in Electron via PR #38977 (merged 2023-09-27, backported to Electron 25/26/27).
Current Discord ships **Electron 35.1.5** — comfortably new enough. The portal
detection is therefore present and working on the startup path. The weak spot is
**live/runtime switching while Discord is already open**: this has been flaky and
environment-dependent for years and is not guaranteed by any official Discord
doc. It works live on some setups and only-at-startup on others.

## 1. Does "Sync with computer" honour the portal, and since when?

- "Sync with computer" is a real, documented Discord theme (Light / Ash / Dark /
  Onyx / Sync with computer) that "matches Discord's appearance to your operating
  system's theme."
  <https://support.discord.com/hc/en-us/articles/207260127-How-to-Change-Discord-Color-Themes-and-Customize-Appearance-Settings>
- Discord's UI is entirely web content (Chromium renderer), so "Sync with
  computer" ultimately tracks Chromium's color-scheme state / the
  `prefers-color-scheme` media query, which on Linux is fed by the appearance
  portal. Chromium began honouring `org.freedesktop.appearance` `color-scheme`
  for `prefers-color-scheme` in **Chromium 114** (needs `xdg-desktop-portal` +
  a backend running).
  <https://bbs.archlinux.org/viewtopic.php?id=298088>
- Confirmation it does work: the Flathub Discord maintainer demonstrated live
  Sync-with-computer switching working on Discord 0.70.0 / Plasma 6.1.5
  (2024-10-02), noting it fails only on "old LTS distros" or DEs whose portal
  doesn't implement the interface — "likely not something we can fix on this
  package."
  <https://github.com/flathub/com.discordapp.Discord/issues/184>

## 2. Which Electron reads the portal, and does current Discord ship it?

- **Historically broken:** Electron shipped an old GTK-only workaround
  (`electron_browser_main_parts.cc`) that _overrode_ Chromium's (by-then correct)
  portal detection, so `nativeTheme` / `prefers-color-scheme` could not work on
  portal-only systems (Fedora/GNOME etc.). Detailed root-cause analysis by
  @Igetin (2023-07-07):
  <https://github.com/electron/electron/issues/33635#issuecomment-1624975665>
  (issue: <https://github.com/electron/electron/issues/33635>)
- **Fixed by PR #38977** — "feat: enable dark mode on GTK UIs", release note
  _"Honor XDG dark theme preferences on Linux."_ It ports Chromium's
  `DarkModeManagerLinux` and reads dark-mode via the XDG Settings portal,
  replacing the old workaround. Merged **2023-09-27**, backported to
  **Electron 25 / 26 / 27**.
  <https://github.com/electron/electron/pull/38977>
- **Current Discord ships Electron 35.1.5** (Linux UA:
  `... discord/0.0.670 Chrome/134.0.6998.179 Electron/35.1.5 ...`).
  <https://docs.discord.food/reference>
  Electron 35 >> 27, so the portal-reading `DarkModeManagerLinux` is present.
  The Flathub repo's old `set-gtk-dark-theme.py` startup shim (referenced by a
  maintainer in 2021) has since been removed — Electron now handles it natively.
- **Caveat / future risk — open regression:** Electron **v39** (Chromium 142)
  regressed runtime color-scheme resolution on Wayland (KDE, Sway, Hyprland,
  Arch) — `shouldUseDarkColors` computed incorrectly at runtime; still **open**.
  <https://github.com/electron/electron/issues/48736>
  This does **not** affect stock Discord (Electron 35) today, but _would_ bite
  if you run Discord on a system Electron 39+ (e.g. `discord_arch_electron`).

## 3. Flags / workarounds / client-mod approaches

- **Portal backend matters.** `xdg-desktop-portal-gtk` (what this machine uses)
  is the recommended backend for Chromium/Electron color-scheme; the KDE backend
  has caused runtime-detection misses. Igetin/others: switching a session to the
  GTK portal is a common fix for the Electron runtime bug.
  <https://github.com/electron/electron/issues/48736> ,
  <https://bbs.archlinux.org/viewtopic.php?id=298088>
- **GTK theme variant.** For native GTK chrome (menus), Electron's
  `DarkModeManagerLinux` also expects `org.gnome.desktop.interface gtk-theme` set
  to a matching variant (Adwaita / Adwaita-dark). Discord's own UI is web content
  so this mostly affects incidental native widgets, not the main window.
  <https://github.com/electron/electron/pull/38977>
- **Restart = reliable.** Fully quitting and relaunching Discord after a theme
  toggle reliably re-reads the current portal value (startup detection is the
  robust path). This is the long-standing community workaround.
  <https://github.com/flathub/com.discordapp.Discord/issues/184>
- **Client mods (Vesktop / Vencord / Equicord):**
  - Vencord themes support `@light` / `@dark` link prefixes that follow
    _Discord's active theme_, and QuickCSS can use
    `@media (prefers-color-scheme: dark)` — but these still ride on Chromium's
    portal detection, so they share the same live-switch limitation.
    <https://vencord.dev/faq/>
  - For _guaranteed_ switching independent of the portal, the **AutoThemeSwitcher**
    Vencord plugin flips between two themes on a time schedule (DE-independent,
    fully reliable, but time-based rather than portal-driven).
    <https://github.com/maddie480/Vencord-AutoThemeSwitcher>
  - No Vencord/Equicord plugin was found that subscribes to the freedesktop
    portal `SettingChanged` signal for live OS-driven switching.
- **No official Discord CLI/flag** exists to flip the theme externally, so a
  `darkman` hook cannot directly push a theme change into the stock client.

## 4. Is this a confirmed upstream _Discord_ limitation?

Nuanced — not a hard, permanent Discord limitation:

- The historical failure was an **Electron** override bug (#33635), now fixed
  upstream (#38977) and present in the Electron Discord ships.
- The remaining live-switch flakiness is a mix of (a) DE/portal-backend
  behaviour and (b) whether Discord's renderer re-renders on Electron's
  `nativeTheme` `updated` event. The classic complaint — "recognises the theme at
  startup but ignores changes while open" — dates to 2020-2021 and was reported
  against Electron itself (`updated` not firing at runtime), then partially fixed;
  it has never been guaranteed by a Discord support doc.
  <https://github.com/electron/electron/issues/23861> ,
  <https://github.com/flathub/com.discordapp.Discord/issues/184>
- The Flathub maintainer's position is that when it fails it's a
  DE/portal/upstream matter, "not something we can fix on this package."

**Verdict on the machine's symptom (portal says light, Discord stays dark):**
Because this Electron (35) _does_ read the portal and the portal _is_
broadcasting, the most likely cause is the renderer applying the theme only on
(re)launch rather than reacting live to `SettingChanged` — the known,
environment-dependent live-switch gap — not a total failure to detect. First
diagnostic: confirm Appearance → **Sync with computer** is actually selected,
then fully quit + relaunch after a `darkman` toggle. If the correct theme then
appears at launch, detection works and only _live_ switching is the gap.

## Verdict + recommendation for this dotfiles setup

- **Accept the limitation for the stock client, and set "Sync with computer."**
  Startup detection via the portal is reliable on Electron 35; live switching
  while open is best-effort and not worth fighting on the official client.
- **Nothing to change on the portal side** — `xdg-desktop-portal-gtk` is the
  right backend and is already proven broadcasting correctly.
- **If live OS-driven switching is a must-have**, the pragmatic route is a client
  mod: **Vesktop/Vencord** with a `@media (prefers-color-scheme)` QuickCSS theme
  (portal-driven, same caveat) or, for guaranteed switching, the time-based
  **AutoThemeSwitcher** plugin. Given this repo's tiered app-theming approach
  (ADR 0021) and `darkman`-owns-mode model (ADR 0019), a time-based or
  mod-driven switch is the only way to get deterministic Discord light/dark that
  matches `darkman` — but it duplicates state rather than following the portal.
- **Watch Electron 39+ (#48736)** before adopting `discord_arch_electron` on a
  system Electron: the Chromium 142 regression breaks runtime color-scheme on
  Wayland and is still open.

### Sources

- Discord Appearance / Sync with computer — <https://support.discord.com/hc/en-us/articles/207260127-How-to-Change-Discord-Color-Themes-and-Customize-Appearance-Settings>
- Flathub Discord #184 (Sync-with-computer live failure; maintainer confirms works on 0.70.0/Plasma) — <https://github.com/flathub/com.discordapp.Discord/issues/184>
- Electron #33635 + Igetin root-cause — <https://github.com/electron/electron/issues/33635> / <https://github.com/electron/electron/issues/33635#issuecomment-1624975665>
- Electron PR #38977 "Honor XDG dark theme preferences on Linux" (Electron 25/26/27) — <https://github.com/electron/electron/pull/38977>
- Electron #23861 (`updated` not firing at runtime, 2020) — <https://github.com/electron/electron/issues/23861>
- Electron #48736 (v39 / Chromium 142 Wayland regression, open) — <https://github.com/electron/electron/issues/48736>
- Electron nativeTheme docs — <https://www.electronjs.org/docs/latest/api/native-theme>
- XDG portal Settings spec (color-scheme 0/1/2) — <https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.Settings.html>
- Chromium 114 portal color-scheme default (Arch forum) — <https://bbs.archlinux.org/viewtopic.php?id=298088>
- Current Discord Linux UA / Electron 35.1.5 — <https://docs.discord.food/reference>
- Vencord theme system / FAQ — <https://vencord.dev/faq/>
- Vencord AutoThemeSwitcher (time-based) — <https://github.com/maddie480/Vencord-AutoThemeSwitcher>
