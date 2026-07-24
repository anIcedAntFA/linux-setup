# VS Code Custom CSS for per-color-scheme font weight

**Status:** accepted

VS Code has no native way to vary `editor.fontWeight` by light/dark theme
(desired: 400 in light, 300 in dark). The only mechanisms are CSS injection via
the `be5invis.vscode-custom-css` extension, or a compromise single weight. We
accept the injection, driven by a chezmoi-managed
[`custom.css`](../../home/dot_config/Code/User/custom.css.tmpl) branching on the
`.vs`/`.vs-dark` body class.

This is a **deliberate reversal** of the call made for VS Code window
transparency, where the same Custom-CSS class was **rejected**. The difference is
payoff: light-mode font weight is a daily eye-comfort win, whereas transparency
revealed only a flat colour on the wallpaper-less Noctalia desktop (see
[docs/theme-sync.md](../theme-sync.md) and the note in `ghostty/config`).

## Considered options

- **Custom CSS injection** — chosen. Only way to get true per-theme font weight
  automatically. Accepts real costs: it patches VS Code's own files, so it must be
  re-enabled from the Command Palette after every VS Code update, needs write
  access to the patched file (a `chown` on Linux, repeated per update), and
  triggers a "corrupt installation" warning. Documented in
  [docs/vscode.md](../vscode.md).
- **Compromise single weight** (e.g. 350/400 for both themes) — rejected. Clean
  and native, but doesn't deliver the light-vs-dark difference that motivated the
  request.
- **Keep 300 everywhere** — rejected. The status quo the request set out to fix.

## The depth texture, tried and abandoned

Since the extension was already present for font weight, a subtle depth texture
rode along on the same file — a faint overlay of Ghostty's per-mode background
images, so editor and terminal would match. It **never rendered** and was removed.

Two things were learned and are worth not rediscovering:

- The workbench is served from the `vscode-file://vscode-app` origin, and Chromium
  refuses `file://` subresources from a non-`file` origin. A
  `url("file:///home/…")` in injected CSS silently loads nothing, with no error
  surfaced anywhere in the UI.
- Re-pointing it at VS Code's own `vscode-file://` protocol only works for paths
  under that protocol's allow-list (app root, `~/.vscode/extensions`,
  `globalStorage`), and inlining the images as base64 `data:` URIs — which does
  dodge the origin rule entirely, at ~700 KB of generated CSS — still produced
  nothing visible.

That last point is the reason for abandoning rather than iterating: with `data:`
the resource can't be blocked, so the remaining fault is in the selector or the
compositing of `.monaco-editor-background`, and the cost of finding it (each
attempt needs a `chown`, a re-patch and a reload) exceeded the value of a texture
at 6% opacity. Ghostty keeps its background images; VS Code does without.

## Consequences

- After a VS Code update the styling silently disappears until **Enable Custom CSS
  and JS** is re-run — an accepted recurring manual step, not a bug. The same
  re-run is needed after any edit to `custom.css`, since the extension inlines the
  file's contents into `workbench.html` at enable time.
- The write access this needs is a **per-update** `chown`, not the one-time cost
  first assumed: a package update restores root ownership of the patched file.
  The path must be typed literally
  (`/usr/share/code/resources/app/out/vs/code/electron-browser/workbench`);
  deriving it from `command -v code` resolves to `/usr` and a recursive `chown`
  there strips setuid from `sudo`/`su`/`pkexec`. See the caution in
  [docs/vscode.md](../vscode.md). This is the sharpest cost of the option chosen
  here, and the strongest argument for a user-space VS Code if it ever grates.
- With the texture gone, the whole apparatus buys exactly one thing — a 100-unit
  font-weight difference in light mode. If the per-update ritual ever stops being
  worth that, drop the extension and pick a single compromise weight; nothing else
  depends on it.
- `settings.json` stays machine-independent: the import uses the extension's
  `${userHome}` variable, so nothing here is templated per machine.
