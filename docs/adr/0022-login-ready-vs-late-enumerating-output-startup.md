# Startup spawn strategy keys on the output, not the app

**Status:** accepted (2026-08-29)

An app auto-started at login is spawned one of two ways, decided **solely by which
output its pinned `terminal`/`coding`/… workspace lives on**. On a **login-ready
output** (the primary — it already has a logical position the instant niri comes
up) the app **plain-spawns** (`spawn-at-startup "app"`) and the window-rule's
`open-on-workspace` routes it. On a **late-enumerating output** (a secondary
monitor that gets its logical position _after_ login) the app goes through
[`dot-niri-startup`](../../home/dot_local/bin/executable_dot-niri-startup), which
polls until that output is positioned, then launches its batch in order. This
supersedes the ghostty half of the reasoning in
[niri-config.md](../niri-config.md)'s two earlier revisions.

## Why this is written down

The rule was re-derived wrong **three times** before it was named, each time
because "which output?" was never made the deciding question:

1. ghostty plain-spawned everywhere → it **misrouted** off `terminal` on the
   secondary-monitor boxes (window painted before that output was positioned), so
   plain spawn was deleted and a gate on _"a named workspace reports that output"_
   was added.
2. That gate **stalled**: niri doesn't surface an empty persistent workspace on its
   monitor until a window occupies it — chicken-and-egg on the very workspace the
   gated app was meant to fill — so the poll burned its whole budget. Re-based the
   gate on _output enumeration_ (a non-null logical position) instead.
3. The output-gate is a **structural no-op on the primary** (`gate=ready after 0
   polls`, always — the primary is up at login). So gating ghostty on the primary
   protected nothing, while its `setsid -f … >/dev/null 2>&1` wrapper **discarded
   ghostty's stderr**. When ghostty then failed to appear at boot, the evidence was
   in `/dev/null` and the failure looked like the old misroute but wasn't (there was
   **no** window at all, not a misplaced one). → this ADR.

The governing distinction is the **output's readiness at login**, not the app.
Naming it (login-ready vs late-enumerating — see [CONTEXT.md](../../CONTEXT.md))
stops the next session from re-litigating ghostty's spawn line.

## Consequences

- **ghostty plain-spawns on `work` (HDMI-A-2) and `home` (HDMI-A-1)** — both its
  primary outputs — matching `zeditor` (which already plain-spawned there and never
  misrouted) and single-monitor `laptop`. Only the genuinely late secondary batch
  (`work` → `DP-1`, `home` → `DP-3`) still routes through `dot-niri-startup`.
- **Observability comes back for free.** A plain `spawn-at-startup` runs under
  niri's own `app-niri-<app>.scope`, so the app's stderr reaches the journal
  (`journalctl --user -b`). The `dot-niri-startup` path's `setsid -f … >/dev/null`
  deliberately does not — fine for apps it's proven to launch (the secondary batch),
  but it hid why ghostty died. If autostart ghostty ever misses `terminal` again,
  the journal + `niri msg windows` now show whether it crashed or misrouted.
- **Latent risk accepted.** Plain ghostty _could_ re-expose the original
  fast-window race (ghostty paints before `terminal` binds) that `zeditor`'s slow
  cold start hides. Accepted rather than pre-guarded: the observed failure is
  _absence_, not misroute, and the journal will catch a regression. Re-add an
  ordering nudge (spawn ghostty after `zeditor`, or a small one-shot delay) only if
  a boot actually shows it on the wrong workspace.
- **`dot-niri-startup` keeps its per-boot trace** (`~/.local/state/niri-startup.log`)
  — it still guards the secondary batch, so the diagnostic stays until that path has
  a few clean boots on record.

## Amendment (2026-08-29) — the primary-ghostty half was falsified

The plain-spawn decision above rests on two claims that a **real light→dark reboot**
(shut down light, boot 23:29 after sunset — the strict test this ADR was written
without) has now **disproved** for the primary:

1. _"The observed failure is absence, not misroute, and the journal will catch a
   regression."_ It didn't. Boot ghostty (`pid 1706`, plain `spawn-at-startup`) started
   at 23:29:06 and **exited 0** — no window, **no stderr in the journal**, no coredump.
   Restoring stderr (the whole point of dropping the `setsid … >/dev/null` wrapper)
   surfaced **nothing**, because ghostty logs nothing on this exit. The safety net this
   ADR relied on does not exist for this failure mode.
2. _Implicitly, that a login-ready output is a sufficient precondition for ghostty._
   It isn't. niri had already positioned **both** outputs (`HDMI-A-1` at 06.482,
   `DP-3` at 06.483) **before** ghostty spawned (~06.5) — so output readiness was
   satisfied and ghostty **still** left no window. The failure is therefore
   **orthogonal** to the login-ready vs late-enumerating distinction, which remains
   correct for the secondary batch but does **not** govern ghostty on the primary.

Also ruled out this session: single-instance (`gtk-single-instance=false`), a
self-exiting shell (`command=/bin/bash`), and a crash (exit 0, no core). What's left
is a **silent early exit against a session that isn't fully ready** (portal / dbus /
`graphical-session.target` still settling ~0.5 s in); a hand-opened ghostty seconds
later always works, and `zeditor` survives only because its slow cold start misses the
window. This is the "fast-window race" this ADR flagged as a _latent_ risk — it was
already real, just mis-attributed to output timing.

**Decision (this amendment):** take the ordering nudge this ADR deferred, paired with
real instrumentation so it fixes-or-explains in one reboot. ghostty is wrapped in
[`dot-spawn-ghostty`](../../home/dot_local/bin/executable_dot-spawn-ghostty) on every
box: a short settle delay (the working-hypothesis fix — a fixed nudge, **not** a
readiness gate, because we still don't know _which_ signal is the missing precondition
and gating on the wrong one is the trap that made three earlier fixes wrong), plus
capture of ghostty's stderr + exit code to `~/.local/state/ghostty-boot.log`. Next boot,
an early `exit rc=0` line = still reproduced (delay didn't help, look deeper); no such
line = fixed. The wrapper is temporary — once a few boots confirm it, revert to a plain
`spawn-at-startup "ghostty"`. The output-gate reasoning above stands unchanged for the
secondary (`dot-niri-startup`) batch.
