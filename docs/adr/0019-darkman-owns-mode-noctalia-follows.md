# darkman owns dark/light; Noctalia follows

**Status:** accepted (2026-08-22)

darkman remains the **single writer and scheduler** of the system color-scheme
(the `org.gnome.desktop.interface color-scheme` gsetting). Noctalia v5 is made a
**follower**: its `colorSchemes.syncGsettings` is set to `false`, and darkman's
`set-color-scheme` hook drives Noctalia's shell to match with
`noctalia msg theme-mode-set <dark|light>`. This preserves the theme-sync model in
[ADR 0010](./0010-darkman-behind-gtk-portal.md) and
[theme-sync.md](../theme-sync.md).

The trigger: Noctalia v5 also wants to own dark/light. It writes the same gsetting,
and — verified empirically on the installed `5.0.0_beta.9` — with
`syncGsettings:true` it **actively re-asserts its own mode**, reverting any
external write (darkman's) within a couple of seconds. Two uncoordinated writers of
one key is a fight: whichever ran last wins, and the shell and the rest of the
desktop drift out of sync.

Empirically (on this exact build):

- `noctalia msg theme-mode-set dark` writes `prefer-dark` to the gsetting.
- With `syncGsettings:true`, an external `prefer-light` write is reverted to
  `prefer-dark` — Noctalia clobbers darkman.
- With `syncGsettings:false`, the external write **sticks** — Noctalia stops
  re-asserting, so darkman can own the key again.
- `theme-mode-set dark|light` is a **fixed** mode (vs `auto`), which also leaves
  Noctalia's own sunrise/sunset scheduler inert — darkman stays the sole scheduler.

So darkman's hook sets Noctalia's mode **first**, then writes the gsetting: setting
the mode first means the subsequent gsettings write already agrees with Noctalia,
so there is no window in which Noctalia sees a disagreement and bounces the value.
An end-to-end `darkman toggle` was verified stable (gsetting, Noctalia, btop theme,
and Zed font weight all switch together and hold at t+4s).

## Considered options

- **darkman owns, Noctalia follows** — chosen. One-line addition to an existing
  hook plus one settings flag. Keeps darkman's schedule + `Mod+Shift+D` toggle,
  the `Settings=gtk` portal broadcast, and every downstream follower (fish, Zed
  font weight, btop, and all portal-aware apps) exactly as they were. Honours the
  CONTEXT.md invariant that darkman is the single writer. Cost: relies on
  `syncGsettings:false`, a beta.9 key that upstream may remove in a later beta
  (see below).
- **Noctalia owns, retire darkman** — rejected. Noctalia would become the source
  of truth (its own schedule + a `theme-mode-set` toggle bind), but the Zed
  font-weight swap and the btop theme swap — both riding darkman's hook — would
  need re-homing onto a new trigger, and `theme-sync.md` + ADR 0010 would be
  rewritten. More moving parts, and it discards a working, well-documented
  mechanism to solve a conflict a single flag already resolves.
- **Leave `syncGsettings:true` and let them fight** — rejected. The shell and the
  apps visibly disagree until the next write; unacceptable.

## Consequences

- **Two theme-linked hooks now hang off darkman.** `set-color-scheme` (mode +
  Noctalia sync + Zed weight + Papirus/superfile) and `set-wallpaper` (per-monitor,
  per-mode wallpaper). darkman runs every executable in `~/.local/share/darkman/`,
  so **adding a hook needs a `darkman` restart** (or a re-login) before it is picked
  up.
- **The hooks must self-heal `WAYLAND_DISPLAY`.** `darkman.service` can start
  _before_ niri exports `WAYLAND_DISPLAY` into the systemd user environment, so
  darkman's own process env lacks it. `noctalia msg` derives its socket name
  (`noctalia-${WAYLAND_DISPLAY}.sock`) from that var — without it, every _scheduled_
  transition silently fails ("noctalia is not running", swallowed by `|| true`) and
  Noctalia's mode never follows, even though a manual `noctalia msg …` from a shell
  works. Both hooks now pull `WAYLAND_DISPLAY` from `systemctl --user
  show-environment` (the manager env _does_ have it once niri is up) when their own
  env is missing it. This is why "auto dark at sunset" looked broken after a reboot
  while a hand-run toggle worked.
- **Beta coupling.** `syncGsettings` exists in `5.0.0_beta.9`. Upstream `main` has
  begun a config migration (`config.toml`) where this key is reworked; a future
  beta bump may change or drop it. If Noctalia starts clobbering darkman again
  after an upgrade, re-check this flag first. (See the research note referenced
  from the migration work in [ADR 0017](./0017-migrate-noctalia-v4-to-v5.md).)
- **btop left the Noctalia template set** — it is themed by the darkman hook now
  (Catppuccin Latte / Dracula), so its Noctalia `activeTemplates` entry is
  disabled. This is intentional de-integration, not drift.
- **`syncGsettings` is gone in `5.0.0_beta.10`.** The beta coupling above came
  true: the beta.9 `colorSchemes.syncGsettings` flag did not survive the migration
  to the `settings.toml` config — there is no such key now. In its place, verified
  on beta.10: a Noctalia held at a **fixed** `[theme] mode` (never `auto`) does
  **not** continuously re-assert the gsetting — an external `prefer-*` write holds.
  So the fixed-mode choice above is what keeps darkman the owner now; the flag was
  only ever needed to suppress the extra re-assertion beta.9 did. (`auto` is
  different: it runs Noctalia's own scheduler and _does_ rewrite the gsetting — the
  dual-writer fight — so it stays off.)
- **Boot-time reconcile — `dot-theme-reconcile`.** The `WAYLAND_DISPLAY` guard
  fixes _scheduled_ transitions (Noctalia already running), but not **boot**:
  `darkman.service` starts before Noctalia's IPC, so darkman's hook can't reach it,
  and Noctalia then asserts its persisted `[theme] mode` **once at startup**,
  writing the color-scheme gsetting to that (possibly stale) value. Shut down in
  light, boot after sunset, and the desktop comes up light; because darkman's
  _internal_ mode is already dark, the first `Mod+Shift+D` is a visual no-op and it
  takes two presses to flip. Fix: niri spawns
  [`dot-theme-reconcile`](../../home/dot_local/bin/executable_dot-theme-reconcile)
  right after Noctalia — it waits for Noctalia's socket, then pushes
  `noctalia msg theme-mode-set "$(darkman get)"` until the gsetting agrees
  (bounded ~8 s). Since fixed-mode Noctalia doesn't re-assert, the correction
  holds. darkman stays the sole scheduler; this only re-delivers its truth once
  Noctalia can receive it.
- **The reconcile also re-drives the wallpaper — because the wallpaper can't
  self-heal.** A real light→dark reboot (shut down light, boot after sunset) proved
  the mode reconcile above only covered _one_ of darkman's two channels. The mode has
  a compositor-independent fallback: `set-color-scheme` writes the gsetting directly,
  so even with Noctalia down at boot the schedule-correct mode lands, and the loop
  above merely re-pushes it into the shell. The **wallpaper has no such fallback** —
  `set-wallpaper` drives it _only_ through `noctalia msg wallpaper-set`, which fails
  silently when IPC isn't up yet; darkman then won't re-fire the hook (no transition),
  and Noctalia asserts its stale persisted image. Result: **dark mode under a light
  wallpaper**. A hook-level socket-wait wouldn't fix it — Noctalia's one-shot startup
  assertion lands _after_ the early hook and would clobber it — which is exactly why
  the reconcile is the right layer: it runs _after_ Noctalia is up. So
  `dot-theme-reconcile` now, once the mode loop has converged (proof the startup
  assertion is done), re-runs `set-wallpaper "$(darkman get)"` once; a single
  post-startup `wallpaper-set` sticks (verified), so no wallpaper poll is needed. See
  the **Wallpaper** term in [CONTEXT.md](../../CONTEXT.md) and docs/theme-sync.md.
- The lock-screen shell-dependence from
  [ADR 0016](./0016-noctalia-ipc-lock-screen.md) is unaffected.
