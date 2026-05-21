# SSHcontroll

SSHcontroll is a macOS SwiftUI control panel for working with a remote Mac over
SSH. It wraps the daily remote workflow into one local app: Shell, Codex,
Claude, Files, Monitor, Mirror, Tailscale checks, helper installation, and
permission guidance.

The repository is public-safe by design. It does not include saved SSH hosts,
private keys, settings, transcripts, attachments, screenshots, or local mirror
folders. Runtime state is created locally after installation.

## Quick Install

Download the latest release assets:

- `SSHcontroll-<version>-macOS.pkg`
- `SHA256SUMS.txt`

Verify and install:

```bash
shasum -a 256 -c SHA256SUMS.txt
open SSHcontroll-<version>-macOS.pkg
```

The package installs:

```text
/Applications/SSHcontroll.app
```

Open the app, go to `Settings`, enter your SSH target, then run `Install Helper`
and `Check Connection`.

See [INSTALL_MAC.md](INSTALL_MAC.md) for the full installation flow.

## Build From Source

Requirements:

- macOS 14 or newer.
- Swift 6 toolchain.
- SSH access to the remote Mac.
- `tmux` on the remote Mac for Shell/Codex/Claude transcript capture.
- Optional: Tailscale, Codex CLI, Claude Code CLI, Macs Fan Control.

Build and install a local development app:

```bash
Scripts/build-app.sh --release
open "$HOME/Desktop/SSHcontroll.app"
```

Create distributable assets:

```bash
Scripts/package-macos.sh
```

Release files are written to `dist/`:

```text
dist/SSHcontroll-0.2.0-macOS.pkg
dist/SSHcontroll-0.2.0-macOS.zip
dist/SHA256SUMS.txt
```

`dist/` is ignored by git. Upload release artifacts to GitHub Releases; do not
commit them.

## First Setup

Open `Settings` and configure:

- `SSH Target`: SSH config alias, hostname, or `user@host`.
- `SSH Key Path`: optional private key path selected with `Choose`.
- `SSH Port`: optional SSH port; leave empty for default SSH.
- `Remote Home`: usually `~`.
- `Remote Helper`: usually `~/.local/bin/a-cockpit-remote`.
- `Explorer Root`: the remote folder SSHcontroll opens first.
- `Mirror Base on C`: local transfer root, default `~/remote`.
- `Latency Target`: optional Tailscale or network target for checks.

Then press:

1. `Install Helper`
2. `Check Connection`
3. `Check A Permissions` if Codex, screenshots, or GUI automation are needed

The app creates local transfer folders with `mkdir -p` behavior:

```text
~/remote/
~/remote/mirror/
~/remote/save/
~/remote/report/
```

## Transfer Model

Files and folders are copied through SSH using the bundled remote helper plus a
fast rsync path with compression disabled, partial-transfer support, explicit
timeouts, and size verification. Large videos are saved locally instead of being
previewed in the app so preview loading does not compete with the download.

Generated previews, prompt attachments, settings, session files, and local
mirror data live outside the repository:

```text
~/Library/Application Support/SSHcontroll/
~/remote/
```

Older installs that used `~/Library/Application Support/AControl/` are migrated
on first launch when the new SSHcontroll folder is empty.

## Tailscale

For the best save/upload speed, keep both Macs in the same tailnet and prefer a
direct Tailscale path over DERP relay routing.

```bash
tailscale status
tailscale ping <A-tailnet-name-or-ip>
```

A fast path usually says `direct` with a local endpoint. If it says a DERP
region, exit node, VPN, or relay, transfer speed can drop sharply. See
[docs/TAILSCALE_SETUP.md](docs/TAILSCALE_SETUP.md).

## Security

Before pushing or publishing:

```bash
Scripts/public-readiness-check.sh
```

At minimum, this runs the privacy scan and checks that generated artifacts or
runtime files are not tracked. See [SECURITY.md](SECURITY.md) and
[docs/PUBLIC_RELEASE_CHECKLIST.md](docs/PUBLIC_RELEASE_CHECKLIST.md).

## LLM Handoff

For agents working on this repository, read [LLM.md](LLM.md). It describes the
public-safe development rules, build/package commands, transfer model, and
verification checklist.
