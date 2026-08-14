# gnome-keyring as the Secret Service, auto-unlocked via greetd PAM

**Status:** accepted

A niri session launched by [greetd](../greetd.md) ships **no Secret Service**
(`org.freedesktop.secrets`): nothing installs or unlocks one. Apps that persist
credentials in the system keychain therefore have nowhere to write — the symptom
is a re-prompt on **every launch**. Concretely, Zed fetches a GitHub sign-in token
fine but cannot store it, so each `zed` relaunch is signed out; the same gap would
drop AI provider API keys. We close it with
[gnome-keyring](https://wiki.archlinux.org/title/GNOME/Keyring) unlocked by PAM at
login: three `optional` `pam_gnome_keyring.so` lines in
[`etc/pam.d/greetd`](../../etc/pam.d/greetd) stash the password already typed into
tuigreet and use it to unlock the `login` keyring at session open. (The daemon itself
is systemd **socket-activated** via `gnome-keyring-daemon.socket`, not launched by
PAM — the `auto_start` keyword is a harmless fallback here.) The keyring password never
diverges from the login password, so there is no second prompt.

## Considered options

- **gnome-keyring + PAM auto-unlock** — chosen. The lightest drop-in Secret
  Service for a non-GNOME session, and PAM unlock is what makes it seamless (sign
  in once, persists across relaunches and reboots) — matching how the other
  machine already behaves. The PAM lines are `optional`, so a missing or broken
  module can never lock login out.
- **gnome-keyring, daemon-only (no PAM)** — rejected. Avoids touching the
  login-critical PAM stack, but then the keyring is either prompted for once per
  session (defeating "it just works") or created with an empty password (secrets
  stored unencrypted at rest). The seamless, encrypted path needs PAM.
- **KWallet as the provider** — rejected. Also speaks the Secret Service API, but
  pulls a KDE/Qt stack into an otherwise GTK/Wayland-minimal box for no other gain.
- **`pass-secret-service` backed by the gopass [Store](../../CONTEXT.md)** —
  **viable, deferred** (not rejected as impractical). Philosophically the best fit:
  one secret store, the GPG one we already trust. And it can be made just as seamless
  — `pam_gnupg` presets the login password into `gpg-agent` at login, the exact
  analog of what `pam_gnome_keyring` does here, so no pinentry fires in-session. Two
  concrete reasons hold it back, both deliberate rather than "too hard": (1) it would
  sync **app/OAuth tokens into the git-versioned Store** — undesirable, since those
  are per-device and a leaked machine would then expose every machine's live
  sessions; gnome-keyring's machine-local keyring is a _feature_ here. (2) more moving
  parts (a daemon, `pam_gnupg`, a GUI pinentry for cache expiry, a systemd
  startup-delay workaround) for a marginal gain. Full blueprint and trade-off table:
  [secret-service.md](../secret-service.md). Revisit if single-backend consolidation
  ever outweighs those two points.
- **Do nothing / sign in each launch** — rejected. That is the status quo being
  fixed; it also silently affects every future keychain-using app, not just Zed.

## The security trade-off

PAM auto-unlock deliberately couples the keyring password to the **login**
password: unlocking one unlocks the other. That is the accepted cost of a
no-second-prompt flow — the same model GDM/SDDM use. Anyone who has the login
password already has the session; the keyring adds no weaker link. Auto-unlock only
ever touches the keyring named **`login`**; a keyring named anything else (e.g. the
`Default Keyring` a prompt-per-session setup creates) is never auto-unlocked — that
naming fact is the whole difference from the other machine's behaviour. A stale
`~/.local/share/keyrings/*` from an earlier setup can also carry a _different_
password, in which case auto-unlock silently no-ops — the documented recovery is
to delete those files and log in again so a fresh `login` keyring is keyed to the
current password.

## Consequences

- `etc/pam.d/greetd` is now a **tracked** system file, applied by hand
  (`sudo cp`) like the rest of `etc/` — it is not chezmoi-managed. `gnome-keyring`
  must be installed (it provides `pam_gnome_keyring.so`) and added to
  `packages/pacman-explicit.txt`.
- Any app using `org.freedesktop.secrets` now persists on this box — the fix is
  not Zed-specific. `docs/zed.md`'s "API keys live in the system keychain" claim
  becomes true here rather than aspirational.
- On current Arch the daemon ships with **SSH disabled** (moved to `gcr-ssh-agent`)
  and no GPG agent, so it provides `secrets`/`pkcs11` only and does **not** hijack
  `SSH_AUTH_SOCK` or contend with the `gpg-agent` behind [gopass](../gopass.md). No
  extra `--components` tuning needed.
- Reverting is removing the three PAM lines (login falls back to the distro
  default) and, if desired, uninstalling `gnome-keyring`; nothing else depends on
  it.
