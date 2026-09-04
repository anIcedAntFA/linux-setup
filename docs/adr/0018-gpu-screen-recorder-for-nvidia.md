# Screen recording via gpu-screen-recorder (NVIDIA), not wl-screenrec

**Status:** accepted (2026-08-22)

`dot-screenrec` records the screen with
[gpu-screen-recorder](https://git.dec05eba.com/gpu-screen-recorder/) (NVENC)
instead of [wl-screenrec](https://github.com/russelltg/wl-screenrec) (VA-API).
The keybind interface is unchanged (`region` / `screen` / `stop`).

The trigger: on the home box (NVIDIA GeForce RTX 3060) `wl-screenrec` cannot
record at all. It panics the instant it starts:

```text
[AVHWFramesContext] Unsupported format: bgr0.
failed to create encoder(s): Failed to create vaapi frame context for capture
surfaces of format DmabufFormat { fourcc: DrmFourcc(XR24) }
```

The root cause is NVIDIA + VA-API. The only VA-API driver for NVIDIA is
`nvidia-vaapi-driver`, which is **decode-only** — `vainfo` lists `VAEntrypointVLD`
(decode) for H.264 and **no `VAEntrypointEncSlice`** (encode). wl-screenrec imports
the wlroots screen-capture dmabufs into a **VA-API frame context regardless of
encoder**, so the failure is at the capture-import stage, not the encoder:
forcing software (`--no-hw`) or NVENC (`--ffmpeg-encoder h264_nvenc`) both fail
identically. wl-screenrec is structurally a VA-API tool and VA-API is a dead end on
this GPU.

> This supersedes the earlier diagnosis (a missing `libavutil.so.60` after an
> ffmpeg 8→9 bump, "fixed" by rebuilding `wl-screenrec-git`). The rebuild _was_
> done and the libs are fine; the VA-API wall is the real, unfixable blocker on
> NVIDIA.

gpu-screen-recorder captures through **DRM/KMS** and encodes with **NVENC**
directly — no VA-API anywhere — and needs **no screencast portal** for monitor
capture. Verified: `gpu-screen-recorder -w DP-3` produces a valid h264 mp4.

## Considered options

- **gpu-screen-recorder (NVENC)** — chosen. Purpose-built for exactly this
  (NVIDIA on Wayland); already in the official channels; KMS capture sidesteps
  both the VA-API wall and the portal. Region via `-w region -region` (geometry
  from `slurp`), focused monitor via `-w <connector>`, stop via SIGINT (it
  finalises the mp4). Cost: a different tool to learn, and KMS capture leans on
  the setuid `gsr-kms-server` helper the package installs.
- **wl-screenrec** — rejected. Cannot encode on NVIDIA (above). It still works on
  the Intel boxes, but `dot-screenrec` is a single shared script, and
  gpu-screen-recorder is **cross-vendor** (NVENC on NVIDIA, VA-API on Intel/AMD).
  Standardising every machine on the one tool is simpler than templating the
  script by GPU, so wl-screenrec is dropped repo-wide rather than kept for Intel.
- **wf-recorder** — rejected. CPU-bound by default; NVENC support is fiddlier and
  it is less Wayland/NVIDIA-focused than gpu-screen-recorder.
- **OBS** — rejected for a keybind-driven one-shot recorder: a GUI/daemon is
  overkill for "slurp a rectangle, record, stop."

## Consequences

- **One recorder across machines.** `dot-screenrec` stays a single, untemplated
  script; gpu-screen-recorder auto-selects the encoder (NVENC on the NVIDIA home
  box, VA-API on the Intel work/laptop boxes). Only the NVIDIA path is verified so
  far — the Intel boxes previously used wl-screenrec and should be re-checked when
  next in use (`gpu-screen-recorder -w <connector>` producing a valid mp4).
- **No portal dependency for recording.** Monitor capture is DRM/KMS; screen
  _sharing_ (browser/app screencast) is a separate concern routed through
  `xdg-desktop-portal-gnome` (see [ADR 0017](./0017-migrate-noctalia-v4-to-v5.md)).
- **Packages change.** `wl-screenrec-git` (AUR) is dropped in favour of
  `gpu-screen-recorder`; regenerate the `packages/*.txt` snapshots.
- The dead-encoder guard in `dot-screenrec` (launch, sleep, confirm the PID is
  still alive before claiming success) is kept — it now catches a missing NVENC
  or an inaccessible KMS device instead of an ABI-broken ffmpeg link.
