# SSHcontroll Install And Operations Guide

This guide is written for a public-safe GitHub repository. It explains what to
install on the C computer, what to install on the A computer, how the first
connection should be configured, and which security rules must stay in force.

Do not replace the placeholders in this file with real SSH hosts, usernames,
passwords, key paths, IP addresses, or local personal folders before committing
or publishing.

## Computer Roles

- C computer: the Mac that runs SSHcontroll and controls the remote machine.
- A computer: the remote Mac reached over SSH.
- SSHcontroll: the local macOS app in this repository.
- Remote helper: the bundled script copied to the A computer, usually installed
  at `~/.local/bin/a-cockpit-remote`.
- Session: one named workspace that owns its remote directory plus Codex,
  Claude, Shell, Files, and transcript state.

## Repository And Release Rules

- Keep the GitHub repository public-safe: source only, no runtime data.
- Commit source code and documentation only.
- Do not commit generated `.app`, `.pkg`, `.zip`, `.dSYM`, `.build`, or `dist`
  outputs.
- Do not commit `~/Library/Application Support/SSHcontroll/`.
- Do not commit `.ssh`, private keys, password notes, local transcripts, prompt
  attachments, local previews, or local handoff files.
- Run `Scripts/privacy-scan.sh` before every commit.
- For public distribution, use a clean public-history branch or squash/rewrite
  history first, then sign and notarize the app and package.

## C Computer Requirements

Install these on the local controlling Mac:

- macOS 14 or newer.
- Xcode Command Line Tools.
- Git.
- Swift toolchain compatible with the package.
- GitHub CLI if you want to push or inspect public repo state from Terminal.
- Tailscale if the A computer is reached through a tailnet.
- SSH client, included with macOS.

Optional but useful:

- Xcode, if you want to inspect or modify the SwiftUI project.
- A Developer ID / Apple Development certificate, if you want signed packages.
- The Codex desktop app, if you also use Codex locally.

Recommended C setup commands:

```bash
xcode-select --install
git --version
swift --version
ssh -V
```

If using Tailscale:

```bash
open -a Tailscale
tailscale status
```

## Build And Install On The C Computer

Clone the public repo:

```bash
git clone https://github.com/suhan-dev/sshcontroll.git
cd sshcontroll
```

Build and install a release app onto the current user's Desktop:

```bash
Scripts/build-app.sh --release
open "$HOME/Desktop/SSHcontroll.app"
```

Build installer artifacts:

```bash
Scripts/package-macos.sh
```

The package script writes:

```text
dist/SSHcontroll-0.2.0-macOS.pkg
dist/SSHcontroll-0.2.0-macOS.zip
dist/SHA256SUMS.txt
```

Those outputs are ignored by git. Upload them to a GitHub release if
needed, but do not commit them.

## C Computer Runtime Data

SSHcontroll runtime state lives outside the repo:

```text
~/Library/Application Support/SSHcontroll/settings.json
```

This file may contain local SSH target names, selected key paths, remote helper
paths, session metadata, and other private runtime choices. It is intentionally
not part of the repository or installer.

The app also creates local transfer folders with `mkdir -p` behavior:

```text
~/remote/
~/remote/mirror/
~/remote/save/
~/remote/report/
```

## A Computer Requirements

Install or enable these on the remote Mac:

- macOS with Remote Login enabled.
- SSH reachable from the C computer.
- `zsh`.
- `tmux`.
- Standard shell tools: `bash`, `sed`, `awk`, `python3`, `find`, `stat`.
- Codex CLI or Codex.app if the Codex pane will be used.
- Claude Code CLI if the Claude pane will be used.
- Optional: Tailscale.
- Optional: Xcode, Android Studio, Flutter, or project-specific tools for app
  development workflows.
- Optional: Macs Fan Control if Monitor/Fan workflows are desired.

Enable SSH on A:

```text
System Settings > General > Sharing > Remote Login
```

From the C computer, test with placeholders:

```bash
ssh A_USER@A_HOST 'uname -a; tmux -V; zsh --version'
```

Prefer SSH key authentication. If a password is used for a temporary manual
test, type it interactively and never write it into source files, docs, logs,
release notes, or screenshots.

## A Computer Tool Setup

Install Xcode Command Line Tools on A if missing:

```bash
xcode-select --install
```

Install `tmux` if it is missing. With Homebrew:

```bash
brew install tmux
```

Codex path options:

```text
/Applications/Codex.app/Contents/Resources/codex
codex on PATH
custom path entered in Settings
```

Claude path options:

```text
claude on PATH
custom path entered in Settings
```

If using Flutter/mobile development on A, verify the required stack there:

```bash
flutter doctor
xcodebuild -version
adb version
```

Those tools are optional for SSHcontroll itself; they are only required for
projects that need them.

## First SSHcontroll Setup

Open SSHcontroll on the C computer and go to Settings.

Fill in:

- SSH Target: SSH config alias, host, or `A_USER@A_HOST`.
- SSH Port: leave empty for default SSH unless a custom port is needed.
- SSH Key Path: choose a local private key only through the file picker.
- Remote Home: `~` unless the remote account needs a custom path.
- Remote Helper: `~/.local/bin/a-cockpit-remote`.
- Codex Path: leave auto-detected or set an explicit remote Codex path.
- Claude Path: leave auto-detected or set an explicit remote Claude path.
- Explorer Root: the remote folder to open first for sessions.
- Mirror Base on C: local mirror/cache folder outside this repository.

Then run these Settings actions:

1. Check Connection.
2. Install Helper.
3. Detect Tools or Check Plugins.
4. Check Permissions.
5. Open Remote Folder if you need to confirm the target workspace.

## Session Workflow

Use sessions as the unit of work:

1. Create a named session.
2. Select the remote directory for that session.
3. Choose Codex, Claude, or both if needed.
4. Use Shell, Codex, Claude, Files, Monitor, and Mirror within that session.

Good session hygiene:

- One project directory per session.
- Do not let a test session reuse a production project directory by accident.
- Delete throwaway sessions after testing.
- Keep Codex and Claude history tied to the same session card.
- Confirm the left sidebar indicator represents real work, not just selection.

## Codex And Claude Setup

Codex and Claude run on the A computer through the helper and tmux.

Codex should support:

- creating or resuming a session,
- model selection,
- separate reasoning depth selection,
- Send for new work,
- Steer for additional instructions during an active run,
- queue display for pending prompts,
- readable transcript rows,
- file chips for real referenced files,
- image/PDF/text previews when the file exists.

Claude should support:

- creating or resuming a session,
- raw transcript display,
- attachments passed as real remote files,
- clear working indicators.

If Send appears to return to the input box without running, check:

- helper installed on A,
- `tmux` is installed,
- Codex/Claude path is valid,
- active session has a real remote directory,
- current task is not stuck in a failed queue state.

## Files And Attachments

Prompt attachments are uploaded to the remote working folder:

```text
<remote working folder>/.acontrol_attachments/<timestamp>/
```

The prompt references the remote file paths so Codex or Claude can read them
directly. Do not use clipboard-only handoff for private files.

File previews should support:

- text files,
- images,
- PDFs.

Large videos should be saved locally instead of previewed in the app. Previewing
and saving the same video at the same time can compete for bandwidth and make
the transfer look broken.

Save/upload paths use rsync over SSH with compression disabled, partial-transfer
support, explicit timeout handling, and final size verification.

Downloaded previews and caches must stay outside the repository.

## macOS Permissions On A

SSHcontroll cannot grant macOS privacy permissions by itself. It can open panes,
run checks, and guide setup, but the final toggle is manual.

Common panes:

```text
System Settings > Privacy & Security > Accessibility
System Settings > Privacy & Security > Screen & System Audio Recording
System Settings > Privacy & Security > Input Monitoring
System Settings > Privacy & Security > Automation
System Settings > Privacy & Security > Full Disk Access
```

Common targets:

- SSHcontroll, on the C computer, only for local app needs.
- Terminal, if Terminal-owned capture workflows are used on A.
- Codex.app, for desktop app workflows.
- Codex Computer Use helper, for real Computer Use workflows.
- Codex CLI Permission Host, for CLI-side screenshot and Apple Events workflows.
- A-Cockpit Permission Host, if the remote helper asks for a stable host app.

Do not assume permissions granted to `Codex.app` automatically apply to the
Codex CLI binary or Computer Use helper. macOS privacy grants are attached to
the actual controlling app or binary identity.

## Codex CLI Permission Host

For CLI-side screenshot or Apple Events work, use the stable helper app:

```text
~/Applications/Codex CLI Permission Host.app
```

Expected bundle id:

```text
local.codex.cli-permission-host
```

Important helper files, when present in the remote project:

```text
tools/permission_host/CodexCLIPermissionHost.m
tools/permission_host/Info.plist
tools/permission_host/build_permission_host.sh
tools/macos_permission_bridge.sh
```

Preferred bridge commands on A:

```bash
tools/macos_permission_bridge.sh host-request
tools/macos_permission_bridge.sh capture .codex_tmp/permission_bridge/verify.png
tools/macos_permission_bridge.sh status
```

If direct CLI `screencapture` fails with `could not create image from display`,
do not keep toggling only `Codex.app`. Use the permission host bridge and grant
the exact helper target in macOS Privacy settings.

## Computer Use And Plugins

Codex Computer Use is separate from the CLI Permission Host. Computer Use can be
blocked even when the CLI host can capture screenshots. Treat these as separate
checks:

- Codex app/plugin availability.
- Computer Use helper process health.
- macOS Accessibility permission.
- Screen & System Audio Recording permission.
- Automation permission.
- The active Codex session transport.

Plugins such as Browser, GitHub, Documents, Spreadsheets, Presentations, Figma,
or Computer Use are not implemented by SSHcontroll itself. SSHcontroll should
surface useful prompt snippets and status checks, while the actual plugin
runtime remains the Codex app or Codex CLI environment on the machine that runs
the task.

## Security Checklist Before Commit Or Push

Run:

```bash
Scripts/privacy-scan.sh
git status --short
git diff --check
git grep -n -I -E 'BEGIN [A-Z ]*PRIVATE|github_pat_|gho_|password[[:space:]]*[=:]|api[_-]?token[[:space:]]*[=:]' -- .
```

Also scan for any private local tokens you know should never enter the repo:

```bash
SSHCONTROLL_PRIVACY_EXTRA_PATTERNS='PRIVATE_HOST|PRIVATE_USER|PRIVATE_PASSWORD_FRAGMENT' Scripts/privacy-scan.sh
```

Replace the placeholders above locally when running the command. Do not commit
the real values.

## Release Checklist

- `swift build` passes.
- `Scripts/privacy-scan.sh` passes.
- Extra local-secret scan passes.
- `git diff --check` passes.
- `Scripts/package-macos.sh` passes if release assets are needed.
- `codesign --verify --deep --strict` passes on installed app when signing is
  expected.
- Install or open the app locally and spot-check:
  - Home
  - Settings
  - Shell
  - Codex
  - Claude
  - Files
  - Monitor
  - Mirror
- Confirm generated artifacts stay ignored or are uploaded only to a GitHub
  release.

## Troubleshooting

SSH connection fails:

- Confirm A is awake and reachable.
- Confirm Remote Login is enabled on A.
- Confirm Tailscale or direct network route is active.
- Confirm the SSH config alias works outside the app.
- Confirm the selected SSH key has correct permissions.

Helper missing:

- Press Install Helper in Settings.
- Confirm `~/.local/bin/a-cockpit-remote` exists on A.
- Confirm it is executable.

Codex missing:

- Install Codex.app on A or put `codex` on PATH.
- Set the explicit Codex Path in Settings if auto-detection is wrong.

Claude missing:

- Install Claude Code on A.
- Set the explicit Claude Path in Settings if auto-detection is wrong.

Screen capture blocked:

- Use Settings permission checks.
- Use the CLI Permission Host bridge when the workflow is CLI-owned.
- Grant the exact helper app shown by the bridge, not only Codex.app.

Transcript confusing:

- Refresh the transcript.
- Confirm the session's remote directory and history id.
- Confirm queue state is not failed.
- Open Files side preview for referenced image/PDF/text artifacts.

## What Must Never Be Published

- Real SSH password.
- SSH private key or public/private key pair.
- Real host/IP if it identifies a private machine.
- Local personal usernames.
- Private Codex/Claude transcripts.
- Prompt attachments containing personal work.
- `~/Library/Application Support/SSHcontroll/settings.json`.
- Generated local handoff files.
- Local mirrors or preview caches.
