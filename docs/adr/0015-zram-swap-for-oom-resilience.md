# zram compressed swap for OOM resilience

**Status:** accepted

This desktop runs with **31 GiB RAM and, until now, zero swap** — the Arch/
EndeavourOS default is no swap at all. A daily workload of Electron chat apps
(Slack, Teams), a browser, Zed's node language servers, Docker, and Claude Code
agents sits around ~25 GiB used. With no swap, there is no soft cushion: the first
allocation spike over the line invokes the kernel OOM killer, which reaps the
fattest low-priority processes. Observed concretely — `containerd` (a Docker
container) invoked the OOM killer and the kernel killed `slack`, then
`teams-for-linux` core-dumped; both windows vanished mid-session with no warning.

We add **zram** — a compressed block device in RAM used as swap
([zram-generator](https://github.com/systemd/zram-generator)) — sized at
`min(ram/2, 16 GiB)` with `zstd`. Cold anonymous pages compress into it (~2–4×)
instead of triggering an instant kill, turning a hard OOM into graceful slowdown
and reclaim. Config lives in [`etc/systemd/zram-generator.conf`](../../etc/systemd/zram-generator.conf)
with VM tuning in [`etc/sysctl.d/99-zram.conf`](../../etc/sysctl.d/99-zram.conf);
both are applied by hand like the rest of `etc/` (not chezmoi-managed).

## Considered options

- **zram (compressed RAM swap)** — chosen. Fast (RAM-speed, no seek), no SSD write
  wear, no disk footprint, and standard on Arch/Fedora desktops. The trade-off is
  it consumes some RAM and CPU for (de)compression — bounded by the 16 GiB cap and
  cheap with `zstd`. Best fit for a machine that is RAM-pressured but not
  disk-starved.
- **Disk swapfile** — rejected as the primary. Survives reboots and is dead simple,
  but slow (defeats the "graceful, not painful" goal), and writes swap churn to the
  SSD. Fine as a future add-on for hibernation, which zram cannot back.
- **Cap Docker memory + OOM score adjust only** — rejected as a _sole_ fix, kept as
  a complement. Limiting containers (`--memory` / compose `mem_limit`) and biasing
  `OOMScoreAdjust` so Docker dies before GUI apps addresses _this_ trigger, but not
  the underlying fragility: any other spike (a runaway node LSP, a big build) still
  finds zero cushion. Swap fixes the class of problem; the cap fixes one instance.
- **Do nothing / more RAM** — rejected. "Just don't run so much" is not a config,
  and 31 GiB is already ample — the gap is the absence of a cushion, not capacity.

## The tuning trade-off

`vm.swappiness = 180` (well above the default 60) is deliberate: with RAM-backed
swap the "avoid swap, it's slow" heuristic is wrong, so we bias toward compressing
cold pages over evicting file cache. `vm.page-cluster = 0` disables swap readahead
(no seek latency to amortise in RAM). These only make sense _because_ the swap is
zram; they would be poor settings for a disk swapfile — which is one more reason
the two are documented together and applied as a pair.

## Consequences

- New tracked system files: `etc/systemd/zram-generator.conf` and
  `etc/sysctl.d/99-zram.conf`, applied by hand (`sudo cp` + `sysctl --system` +
  `systemctl start systemd-zram-setup@zram0.service`). `zram-generator` must be
  installed and added to `packages/pacman-explicit.txt` (by hand — see the
  snapshot-drift policy in [packages](../../packages)).
- No hibernation: zram cannot hold a hibernation image. If suspend-to-disk is ever
  wanted, add a disk swapfile alongside — the two coexist.
- Reverting is `systemctl stop systemd-zram-setup@zram0.service`, removing the two
  files, and `sysctl --system`; nothing else depends on it.
- Complementary, not covered here: per-container Docker memory limits remain the
  right hygiene for the specific workload that triggered the first OOM.
