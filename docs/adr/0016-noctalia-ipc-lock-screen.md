# The lock screen is Noctalia's, driven over its IPC

**Status:** accepted (2026-08-22)

`Super+Alt+L` locks the screen with `noctalia msg session lock` (Noctalia's
built-in `ext-session-lock` locker) instead of spawning a standalone locker such
as swaylock. We picked the shell's own locker for a consistent, themed lock
experience with zero extra packages to install or configure — it inherits the
same colors, fonts, and wallpaper as the bar. The previous `spawn "swaylock"`
bind was plain and visually disconnected from the rest of the desktop.

> Noctalia v5 (native binary) replaced v4 (Quickshell); the command changed from
> the v4 form `qs -c noctalia-shell ipc call lockScreen lock` to
> `noctalia msg session lock`. See [ADR 0017](./0017-migrate-noctalia-v4-to-v5.md).
> The decision below is unchanged — only the invocation.

## Considered options

- **Noctalia `session lock` over IPC** — chosen. No new package, matches the
  shell theme automatically, and stays in step with the other Noctalia binds
  (`panel-toggle launcher`, `panel-toggle session`, `settings-toggle`), which all
  route through the same `noctalia msg` mechanism.
- **hyprlock (standalone)** — rejected for now. Attractive and highly themeable,
  works on niri via `ext-session-lock`, and — importantly — is independent of the
  shell's health. Rejected because it adds a package plus a config file to
  maintain and duplicates theming Noctalia already does; revisit if the
  reliability caveat below ever bites.
- **swaylock-effects** — rejected. A modest upgrade over plain swaylock, still a
  standalone package to theme separately, and less polished than the shell's own
  locker.

## Consequences

- **The lock depends on the shell being healthy.** Because the bind shells out to
  `noctalia`, anything that stops the shell from running also stops the screen
  from locking — leaving the machine unlocked. This is not hypothetical: on
  2026-08-22 a `qt6-base` upgrade left the v4 `noctalia-qs` build ABI-broken, so
  every fresh `qs ... ipc call` crashed. During that window `Super+Alt+L` would
  have silently failed to lock. A standalone locker would have been immune. We
  accept this trade-off for the theming and simplicity. (v5 being a native binary
  with no Qt/Quickshell dependency makes _that specific_ failure mode far less
  likely, but the shell-dependence in principle remains.)
- If shell-independent locking ever becomes a hard requirement (e.g. for
  unattended machines), switch the bind to hyprlock — a one-line change plus a
  config file — and supersede this ADR.
