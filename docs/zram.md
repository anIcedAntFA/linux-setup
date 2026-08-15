# zram — compressed RAM swap

## Why

Arch/EndeavourOS installs with **no swap at all**. On a box with plenty of RAM
that seems fine — until it isn't. With zero swap there is **no soft cushion**: the
moment allocations cross the physical limit, the kernel's **OOM killer** fires and
reaps whichever big, low-priority process it picks — usually a GUI app you were
using, with no warning.

This machine (31 GiB RAM) hit exactly that. A Docker container spiked memory and
the kernel killed Slack and Teams outright:

```text
containerd invoked oom-killer ... global_oom ... task=slack,pid=16200
Out of memory: Killed process 16200 (slack)
```

The daily mix here — Electron chat apps, a browser, Zed's Node language servers,
Docker, and Claude Code agents — routinely sits near the ceiling, so a single
spike was enough. **zram** adds a compressed swap device that lives _in RAM_: cold
pages get compressed instead of the system falling off a cliff, turning a hard
OOM-kill into graceful slowdown-and-reclaim. No disk, no SSD wear.

For **why zram** over a disk swapfile or just capping Docker, see
[ADR 0015](adr/0015-zram-swap-for-oom-resilience.md).

## Install

```sh
yay -S --needed zram-generator
```

[zram-generator](https://github.com/systemd/zram-generator) is a systemd
**generator**: it reads a small config and creates the zram swap unit at every
boot. There is nothing to `systemctl enable` — see [Apply](#apply).

## Configure

Two **system** files (tracked here, applied by hand — not chezmoi-managed):

**[`etc/systemd/zram-generator.conf`](../etc/systemd/zram-generator.conf)** — the
device itself:

```ini
[zram0]
zram-size = min(ram / 2, 16384)
compression-algorithm = zstd
```

- `zram-size = min(ram / 2, 16384)` — half of RAM, capped at 16 GiB (MiB units).
  zstd compresses ~2–4×, so the _effective_ cushion is larger than the nominal
  size; the cap stops zram from ever eating the RAM it exists to protect.
- `compression-algorithm = zstd` — best ratio-for-speed on a modern CPU.

**[`etc/sysctl.d/99-zram.conf`](../etc/sysctl.d/99-zram.conf)** — VM tuning that
only makes sense _because_ the swap is RAM-fast:

```ini
vm.swappiness = 180          # bias toward compressing cold pages, not evicting file cache
vm.page-cluster = 0          # no swap readahead — there is no seek latency to amortise
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
```

`swappiness = 180` (vs the default 60) is deliberate: the "avoid swap, it's slow"
heuristic is wrong for zram. These would be _poor_ settings for a disk swapfile,
which is why the two files are applied as a pair.

## Apply

```sh
sudo cp etc/systemd/zram-generator.conf /etc/systemd/zram-generator.conf
sudo cp etc/sysctl.d/99-zram.conf       /etc/sysctl.d/99-zram.conf
sudo sysctl --system                    # load the VM tuning now
sudo systemctl daemon-reload
sudo systemctl start systemd-zram-setup@zram0.service   # create the device now
```

No reboot needed — this brings zram up immediately, and the generator recreates
it on every subsequent boot on its own.

## Verify

```sh
swapon --show
# NAME       TYPE       SIZE USED PRIO
# /dev/zram0 partition 15,6G   0B  100      <- device is live, priority 100

zramctl
# NAME       ALGORITHM DISKSIZE ... MOUNTPOINT
# /dev/zram0 zstd         15,6G ... [SWAP]   <- zstd, in use as swap

sysctl vm.swappiness                          # -> 180
```

`USED 0B` right after setup is **correct**, not a failure — with RAM to spare
nothing has been swapped yet. To watch it actually engage:

```sh
timeout 20 tail /dev/zero | head -c 22G >/dev/null &   # allocate ~GBs briefly
watch -n1 'swapon --show; echo; zramctl'               # USED climbs, then release
```

You'll see swap fill and — the whole point — **no app gets OOM-killed**.

## Reading the numbers (important)

`swapon` and `zramctl` measure different things, and the gap between them is where
people get confused:

```text
swapon --show
NAME       TYPE       SIZE  USED PRIO
/dev/zram0 partition 15,6G  5,9G  100        <- kernel swapped out 5.9 GB of pages

zramctl
NAME       ALGORITHM DISKSIZE DATA  COMPR TOTAL STREAMS MOUNTPOINT
/dev/zram0 zstd         15,6G 968K 333,4K  1,6M         [SWAP]
```

| Field           | Means                                                    |
| --------------- | -------------------------------------------------------- |
| `swapon USED`   | swap space the kernel considers occupied (pages spilled) |
| `zramctl DATA`  | uncompressed size of data zram is storing                |
| `zramctl COMPR` | that data after compression                              |
| `zramctl TOTAL` | **actual RAM** zram consumed to hold it                  |

Above, the kernel "used" 5.9 GB of swap but zram spent only **1.6 MB of real RAM**.
That is not magic — it's the trap in the test command:

> [!WARNING]
> `tail /dev/zero` produces **all-zero pages**. zram has a **same-filled-page**
> optimisation: a page that is entirely one repeated byte is stored as a tiny
> marker, not as compressed data. So zeros compress essentially infinitely, which
> is why `DATA`/`TOTAL` stay in KB while `USED` shows GB.
>
> **Real memory is not zeros.** Browser/Electron/Node heaps compress ~**2–4×** with
> zstd, not ∞×. So in practice, budget e.g. ~4 GB of cold pages → ~1–2 GB of zram
> RAM, not a few KB. The `/dev/zero` test proves the _mechanism_ (pages spill to
> zram, the box survives), **not** a realistic compression ratio.

Swapped pages linger in zram until something faults them back in, so `USED` staying
non-zero after the test is normal and near-free (the real cost is `TOTAL`). It
clears on `swapoff` or reboot.

## Troubleshooting & revert

- **`swapon` shows nothing** — the generator didn't run. Re-check the conf path,
  then `sudo systemctl daemon-reload && sudo systemctl restart systemd-zram-setup@zram0.service`.
- **Sysctls didn't stick** — confirm with `sysctl vm.swappiness`; re-run
  `sudo sysctl --system`. `/etc/sysctl.d/99-*` loads last, so it wins over distro
  defaults.
- **Hibernation** — zram **cannot** hold a suspend-to-disk image. If you ever want
  hibernation, add a real disk swapfile alongside; the two coexist.
- **Revert** — `sudo systemctl stop systemd-zram-setup@zram0.service`, remove the
  two files, `sudo sysctl --system`. Nothing else depends on it.

Remember to add `zram-generator` to
[`packages/pacman-explicit.txt`](../packages/pacman-explicit.txt) (by hand — see
the [packages guide](packages.md) on snapshot drift).

## References

- [zram-generator](https://github.com/systemd/zram-generator) ·
  [`zram-generator.conf(5)`](https://man.archlinux.org/man/zram-generator.conf.5)
- [Arch Wiki — zram](https://wiki.archlinux.org/title/Zram)
- Decision & alternatives: [ADR 0015](adr/0015-zram-swap-for-oom-resilience.md)
