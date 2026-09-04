# Screen recording — gpu-screen-recorder

Video counterpart to [screenshot.md](screenshot.md). Where screenshots are a
one-shot grab, a recording is a **long-running process**: you start it, it runs,
you stop it later — so the wiring is a little different.

## Why gpu-screen-recorder

[gpu-screen-recorder](https://git.dec05eba.com/gpu-screen-recorder/) captures the
screen via **DRM/KMS** and encodes on the GPU — **NVENC** on NVIDIA, **VA-API** on
Intel/AMD — so it stays cheap on CPU and battery even at high resolution. It
captures a **region** (via `slurp`, exactly like the screenshot flow) or a **single
output**, with optional audio.

It replaced [wl-screenrec](https://github.com/russelltg/wl-screenrec), which
**cannot record on the NVIDIA home box at all**: the only VA-API driver for NVIDIA
(`nvidia-vaapi-driver`) is decode-only, and wl-screenrec imports the capture
buffers through a VA-API frame context regardless of encoder, so it dies the
instant it starts (`Failed to create vaapi frame context … Unsupported format:
bgr0`). gpu-screen-recorder's KMS capture + NVENC sidesteps VA-API entirely. Since
it is cross-vendor, the whole repo uses the one tool rather than templating the
script per GPU. Full reasoning in
[ADR 0018](adr/0018-gpu-screen-recorder-for-nvidia.md).

Two things it deliberately does _not_ do here, which shape the script below:

- **No window capture** — `dot-screenrec` records a rectangle or an output,
  nothing that follows a window.
- **One output at a time** — a single recording targets one monitor (or one
  region), not a span across monitors.

## Install

```sh
sudo pacman -S --needed gpu-screen-recorder slurp jq libnotify
```

- `gpu-screen-recorder` — the recorder. It ships a setuid `gsr-kms-server` helper
  so KMS capture works without running the whole thing as root.
- `slurp` — draw the region rectangle (shared with the screenshot pipeline).
- `jq` — read the focused output name from `niri msg --json`.
- `libnotify` — `notify-send`, the only signal a recording is live.

> [!NOTE]
> **No screencast portal needed for recording.** Monitor capture goes straight
> through DRM/KMS, so `dot-screenrec` works even while the screencast _portal_ is
> misconfigured. Screen **sharing** (a browser/app screencast) is the separate
> concern that needs `xdg-desktop-portal-gnome` — see
> [ADR 0017](adr/0017-migrate-noctalia-v4-to-v5.md).

## GPU / hardware encoding

gpu-screen-recorder picks the encoder from the GPU automatically:

- **NVIDIA** (home box, RTX 3060) → **NVENC** (`h264_nvenc`). No VA-API involved;
  this is the path that made wl-screenrec unusable and gpu-screen-recorder the fix.
- **Intel / AMD** (work / laptop) → **VA-API** on the GPU. The same script and
  keybinds; only the encoder differs. (Not yet re-verified on those boxes — they
  previously ran wl-screenrec; confirm with `gpu-screen-recorder -w <connector> -o
  /tmp/t.mp4` producing a non-empty file.)

Quick check that capture works at all:

```sh
gpu-screen-recorder --list-monitors        # connector names + resolutions
gpu-screen-recorder -w DP-3 -o /tmp/t.mp4  # Ctrl-C after a second; /tmp/t.mp4 should be non-empty
```

## The `dot-screenrec` script

[`home/dot_local/bin/executable_dot-screenrec`](../home/dot_local/bin/executable_dot-screenrec)
wraps the tool. Because a niri keybind has no terminal to `Ctrl-C`, **stopping is
a separate command** that sends `SIGINT` to the running recorder
(gpu-screen-recorder finalises the `.mp4` — writes the moov atom — on that signal):

```sh
dot-screenrec region          # slurp a rectangle, then record it
dot-screenrec screen          # record the focused monitor
dot-screenrec stop            # finish & save the running recording

dot-screenrec region audio    # add desktop audio (opt-in)
dot-screenrec screen audio
```

How it behaves:

- **Single instance.** State (PID + target path) lives in
  `$XDG_RUNTIME_DIR/dot-screenrec.state`. Starting a mode while a recording is
  already running is refused with a notification — stop the current one first.
- **Silent by default.** Audio is opt-in via a trailing `audio` arg (adds
  `-a default_output`, i.e. desktop sound), so a public repo never captures audio
  by accident.
- **Web-ready output.** Files are `.mp4` with h264 (`-k h264`), which plays inline
  in any browser `<video>` — no transcode before a blog embed. They land in
  `$XDG_VIDEOS_DIR` as `Screencast from <timestamp>.mp4`.
- **Fail-fast.** After launch it waits 0.5 s and confirms the recorder PID is
  still alive before writing the statefile and claiming success — so a missing
  NVENC or an inaccessible KMS device shows a "Recording failed to start" toast
  instead of a false success that a later `stop` reports as "Nothing is recording."
- **Feedback.** `notify-send` fires a fresh notification on start
  (`● Recording — region`) and on stop (the saved path).

## Keybinds

The `Mod+Backslash` family, parallel to the `Mod+S` screenshot family (see
[niri-keybindings.md](niri-keybindings.md#screenshots--capture)). `Backslash`
rather than `Print` so it works on keyboards without a dedicated `Print` key:

| Keybind               | Command                | Action                 |
| --------------------- | ---------------------- | ---------------------- |
| `Mod+Backslash`       | `dot-screenrec region` | Start: select a region |
| `Mod+Shift+Backslash` | `dot-screenrec screen` | Start: focused monitor |
| `Mod+Ctrl+Backslash`  | `dot-screenrec stop`   | Stop & save            |

Audio variants aren't bound by default — run them from a terminal, or add a bind
passing the `audio` arg if you record talking demos often.

## References

- [gpu-screen-recorder](https://git.dec05eba.com/gpu-screen-recorder/) · `man gpu-screen-recorder.1`
- [slurp](https://github.com/emersion/slurp)
- [ADR 0018](adr/0018-gpu-screen-recorder-for-nvidia.md) — why this tool over wl-screenrec
