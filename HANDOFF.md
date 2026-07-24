# Handoff — VS Code theme auto-sync + transparency

Two threads from this session. Thread 1 is **done and committed** (in this
commit). Thread 2 is **mid-grilling** — the plan is decided down to a couple of
open details, no files touched yet.

There's also a stale zellij note preserved at the bottom.

## Thread 1 — VS Code settings/extensions backfill (DONE, in this commit)

Backfilled the repo's curated VS Code config from the company machine, additively
(no curated choices overwritten). Already applied to:

- `packages/vscode-extensions.txt` — 31 → 66 extensions (+35). Deliberately
  **excluded**: `ms-vscode-remote.remote-wsl`, `oxc.oxc-vscode`,
  `ritwickdey.liveserver` (kept `yandeu.five-server`), `esbenp.prettier-vscode`
  (biome-first, see below).
- `home/dot_config/Code/User/settings.json` — +19 lines: rust-analyzer (×3),
  js/ts inlayHints + `quoteStyle:single`, `tailwindCSS.includeLanguages`,
  copilot autoCompletions, `mdx.validate.*` (×5), `makefile.configureOnOpen`.

Decisions locked: **biome-first** formatting kept (no prettier ext/settings);
**Dracula theme + fontWeight 300** kept (not the machine's Github Light). Skipped
machine-specific/experimental: `background.*` (hardcoded wallpaper path),
glassit, `animations.Install-Method`, orphaned `tabnine`, `liveServer`. `just
check` passed clean (gitleaks OK). See the diff in this commit for specifics.

## Thread 2 — theme auto-sync + transparency (IN PROGRESS)

User's ask (VN): VS Code should follow system light/dark — **light → Github Light
Theme, dark → Dracula**; if not natively possible, a script/cron. Separately,
wants **transparent background** like Ghostty (niri whole-window opacity "ko work
như ghostty").

### Branch A — theme auto-sync (decided, ready to implement)

Verified facts:

- `portals.conf` already routes `Settings` → **gtk** portal, which serves
  `org.freedesktop.appearance color-scheme`. Confirmed live:
  `gdbus … Settings.Read appearance color-scheme` → `1` (prefer-dark).
- VS Code **1.129.1** supports `window.autoDetectColorScheme`. So the fix is
  **native, no script/cron**. Add to `settings.json`:

  ```jsonc
  "window.autoDetectColorScheme": true,
  "workbench.preferredLightColorTheme": "Github Light Theme",
  "workbench.preferredDarkColorTheme": "Dracula Theme",
  ```

  (The static `workbench.colorTheme` is ignored under autoDetect — keep or drop.)
- **Gap:** nothing toggles the system scheme — `gsettings color-scheme` is static
  `prefer-dark`; no darkman/matugen/Noctalia key. **Decision: manual keybind
  toggle** that flips `gsettings … color-scheme` prefer-dark ↔ prefer-light. All
  portal-aware apps (VS Code, Ghostty, Chrome) + the existing
  `home/dot_config/fish/functions/auto-sync-theme.fish` (fish theme: Dracula
  Official ↔ Catppuccin Latte) react.

**Open (was mid-question when interrupted):**

- **Keybind** — recommended `Mod+Shift+D` (free; alts `Mod+Ctrl+T`,
  `Mod+Shift+L`). Taken: `Mod+Shift+{T,C,S}`.
- **Notification** — recommend yes: one-shot `notify-send` on toggle (use a fresh
  one-shot, not `--replace-id`, per the Noctalia daemon quirk in memory).
- **GTK3 app theming** — recommend skip (needs adw-gtk3 + gtk-theme; the named
  targets are all portal-aware already).
- **Toggle script placement** — undecided: standalone `executable_*` script vs a
  fish function alongside `auto-sync-theme.fish`. niri `spawn` runs it directly.

### Branch B — transparency (NOT yet grilled; analysis only)

No decisions yet. My read: Ghostty transparency is native renderer alpha
(background-only, text opaque) — **not cleanly replicable in Electron/VS Code on
Wayland**. Options are all compromised:

- niri `window-rule { opacity … }` = whole-window (text translucent too) — the
  thing the user already rejected.
- Real bg transparency needs a transparent Electron window (not enabled by
  default) + Custom CSS/JS Loader — fragile, breaks on VS Code updates, "corrupt
  installation" nag.
- **GlassIt-VSC is X11-only → won't work on Wayland/niri** (explains why glassit
  never worked here).

Next session should set expectations honestly and get a call: accept whole-window
niri opacity, attempt the fragile Custom-CSS hack, or drop it.

## Suggested skills

- `grill-with-docs` — resume the interview: finish Branch A open details, then
  grill Branch B (transparency feasibility/compromise).
- `git-workflow` — for the follow-up commit once Branch A is implemented.

---

## (Stale) Handoff — zellij validation

Preserved from before; verify whether still outstanding and delete if done.

zellij artifacts were written from docs alone before zellij was installed
(0.44.3 now). Test: layout `~` cwd expansion in `_template.kdl`; the `zj` picker
flow; `theme_dark` / `theme_light`. See
[ADR 0008](docs/adr/0008-terminal-workspace-model.md),
[docs/zellij.md](docs/zellij.md).
