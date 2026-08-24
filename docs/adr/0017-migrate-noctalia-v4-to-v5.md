# Migrate Noctalia v4 (Quickshell) → v5 (native binary)

**Status:** accepted (2026-08-22)

Noctalia was rewritten between major versions. **v4** was a Quickshell/QML shell
run by a custom Quickshell fork (`noctalia-qs`) plus `noctalia-shell`, started
with `qs -c noctalia-shell` and scripted over `qs … ipc call <target> <function>`.
**v5** (`extra/noctalia`, `5.0.0_beta.9` at time of writing) is a native
C++/meson binary named `noctalia` with **no Quickshell or Qt dependency**,
started with `spawn-at-startup "noctalia"` and scripted over `noctalia msg
<command>`. We migrate to v5 because **v4 is unmaintained and its AUR packages
(`noctalia-shell`, `noctalia-shell-git`, and the `noctalia-qs` fork) have been
removed** — it cannot be reinstalled or rebuilt, and it broke on the 2026-08-22
`qt6-base` ABI bump with no upstream fix path.

The trigger: after that Qt upgrade, every fresh `qs … ipc call` crashed
(`undefined symbol … Qt_6_PRIVATE_API`), so the launcher, session menu, settings,
and lock binds all silently did nothing. The v4 fix would have been to rebuild
`noctalia-qs` — impossible now that the package is gone.

## What changed in this repo

- niri `spawn-at-startup "qs" "-c" "noctalia-shell"` → `spawn-at-startup "noctalia"`.
- All keybinds re-pointed from `qs … ipc call …` to `noctalia msg …`
  (`panel-toggle launcher` / `panel-toggle clipboard` / `panel-toggle session` /
  `settings-toggle` / `session lock`). Keys are unchanged.
- Added the upstream-recommended floating window rule for `app-id
  "dev.noctalia.Noctalia"` (settings window) and the `debug {
  honor-xdg-activation-with-invalid-serial }` flag Noctalia needs for
  notification actions / window activation.
- Removed `xdg-desktop-portal-wlr`: niri isn't wlroots-based and upstream routes
  screencast through `xdg-desktop-portal-gnome` (kept, alongside `-gtk`).

## Considered options

- **Migrate to v5** — chosen. The only maintained, installable path; it's in the
  official `extra` repo (no AUR rebuild churn, which is what bit us) and drops the
  Qt/Quickshell dependency that caused the outage. Cost: v5 is officially
  labelled "Beta", and it is a **fresh install** — v4 settings/theming do not
  migrate.
- **Resurrect v4** — rejected. Would mean building the deleted `noctalia-qs` from
  a git checkout and/or pinning Qt back: unmaintained, breaks on every Qt bump,
  and a dead end since upstream has moved on.
- **Switch shells entirely** (e.g. Waybar + fuzzel + a standalone locker) —
  rejected. A larger rewrite than the migration, and Noctalia v5 preserves the
  integrated bar/launcher/session/lock model already wired into these dotfiles.

## Consequences

- **v5 config/theming is deliberately deferred.** v5 stores config separately
  from v4 and does not read v4's `~/.config/noctalia/settings.json`, so the
  tracked v4 snapshot under `home/dot_config/noctalia/**` (per
  [ADR 0012](./0012-noctalia-config-tracked-as-app-owned-snapshot.md)) no longer
  applies. The v4 tree is left in place for now; **ADR 0012 must be revisited**
  once v5 is running and its real config format is known, along with re-doing the
  colorscheme and checking whether v5 has a template/color-export equivalent to
  re-wire the btop/yazi themes (see [theme-sync.md](../theme-sync.md)). This is a
  follow-up, not part of this change.
- **Running on a Beta.** v5 is the maintained line but pre-1.0; expect config
  churn across beta bumps. Acceptable because v4 is not an option.
- **The lock-screen trade-off in
  [ADR 0016](./0016-noctalia-ipc-lock-screen.md) still holds** — the command
  changed, the shell-dependence did not.
- Packages: `noctalia` moves the shell from AUR to the official repo, so
  `packages/aur.txt` / `packages/pacman-explicit.txt` snapshots change; regenerate
  them after the install lands.
