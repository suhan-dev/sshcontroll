# Install SSHcontroll For macOS

This page explains how to install SSHcontroll from a release package and finish
the first two-machine setup.

## What To Download

Download these release assets from GitHub:

- `SSHcontroll-<version>-macOS.pkg`
- `SHA256SUMS.txt`

The package installs:

```text
/Applications/SSHcontroll.app
```

It does not include saved SSH targets, SSH keys, settings, sessions,
transcripts, attachments, screenshots, or local user folders.

## Verify

From the folder containing the downloaded files:

```bash
shasum -a 256 -c SHA256SUMS.txt
```

If the package was downloaded without a checksum file, compare manually:

```bash
shasum -a 256 SSHcontroll-<version>-macOS.pkg
```

## Install

1. Open `SSHcontroll-<version>-macOS.pkg`.
2. Follow the installer.
3. Open `/Applications/SSHcontroll.app`.
4. Go to `Settings`.
5. Fill in your SSH target.
6. Press `Install Helper`.
7. Press `Check Connection`.

If macOS reports that the package or app is from an unidentified developer, the
release is unsigned or not notarized. For local testing, open it from Finder with
Right Click > Open. For public distribution, sign with a Developer ID Installer
certificate and notarize before release.

## First Settings

Fill these fields:

- `Remote Label`: a short display name, for example `A`.
- `SSH Target`: SSH config alias, hostname, or `user@host`.
- `SSH Key Path`: optional private key selected with `Choose`.
- `SSH Port`: leave empty unless the remote SSH server uses a custom port.
- `Remote Home`: usually `~`.
- `Remote Helper`: `~/.local/bin/a-cockpit-remote`.
- `Explorer Root`: remote folder shown first in Files.
- `Mirror Base on C`: local transfer folder, default `~/remote`.
- `Latency Target`: optional Tailscale hostname/IP for latency checks.

The app creates local folders automatically:

```text
~/remote/
~/remote/mirror/
~/remote/save/
~/remote/report/
```

The helper install flow creates the remote helper directory before copying:

```bash
mkdir -p ~/.local/bin
```

## Remote Mac Requirements

On the A computer:

- Enable `System Settings > General > Sharing > Remote Login`.
- Install or enable `zsh`, `bash`, `python3`, standard BSD tools, and `tmux`.
- Optional: install Tailscale, Codex CLI/Codex.app, Claude Code, Macs Fan
  Control, Xcode, Android/Flutter tools.

Quick manual SSH smoke test:

```bash
ssh <A-target> 'uname -a; tmux -V; zsh --version'
```

Then use `Install Helper` from SSHcontroll instead of copying helper scripts by
hand.

## Tailscale

For large saves and uploads, a direct Tailscale path matters more than almost
any app setting.

On both Macs:

```bash
tailscale status
tailscale ping <other-mac-tailnet-name-or-ip>
```

Prefer output that says `direct`. If it says DERP relay, exit node, or a far
region, see [docs/TAILSCALE_SETUP.md](docs/TAILSCALE_SETUP.md).

## Runtime Data

SSHcontroll stores runtime data outside the repository and outside the
installer:

```text
~/Library/Application Support/SSHcontroll/
```

Older local data under the legacy path is copied forward on first launch if the
new folder is empty:

```text
~/Library/Application Support/AControl/
```

Do not upload either folder. They may contain local settings, SSH targets,
sessions, transcripts, prompt attachments, or previews.

## Build The Package Yourself

From the repository root:

```bash
Scripts/package-macos.sh
```

Generated files:

```text
dist/SSHcontroll-0.2.1-macOS.pkg
dist/SSHcontroll-0.2.1-macOS.zip
dist/SHA256SUMS.txt
```

Verify the generated release:

```bash
(cd dist && shasum -a 256 -c SHA256SUMS.txt)
pkgutil --payload-files dist/SSHcontroll-0.2.1-macOS.pkg | head
unzip -l dist/SSHcontroll-0.2.1-macOS.zip | head
```
