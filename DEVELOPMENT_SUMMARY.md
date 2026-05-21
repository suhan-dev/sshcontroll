# SSHcontroll Development Summary

SSHcontroll is a native macOS control app for a remote Mac reached over SSH. It
provides Shell, Codex, Claude, Files, Monitor, Mirror, Settings, helper install,
permission guidance, and Tailscale status workflows.

## Current Public-Facing Names

- App: `SSHcontroll.app`
- Package: `SSHcontroll-0.2.0-macOS.pkg`
- Zip: `SSHcontroll-0.2.0-macOS.zip`
- Bundle identifier default: `dev.suhan.sshcontroll`
- Swift package product: `SSHcontroll`

Some Swift source names still use legacy internal names such as `AControlApp`.
Those are implementation details and are intentionally left stable to avoid a
large source-only rename.

## Storage

Runtime data:

```text
~/Library/Application Support/SSHcontroll/
~/remote/
```

Legacy migration source:

```text
~/Library/Application Support/AControl/
```

Repository contents should remain source, scripts, and generic docs only.

## Build And Release

```bash
Scripts/public-readiness-check.sh
Scripts/build-app.sh --release
Scripts/package-macos.sh
```

Expected release artifacts are written to `dist/` and ignored by git.

## Transfer Performance

Save/upload/folder-save flows are tuned for large files:

- rsync over SSH,
- compression disabled,
- partial transfers enabled,
- explicit timeout cleanup,
- final size verification,
- scrollable operation logs,
- large videos saved locally instead of previewed.

Network route quality still matters. For Tailscale, prefer a direct route and
avoid exit-node or distant DERP relay routing when moving large media files.

## Security Gate

Before commit, publish, or release:

```bash
Scripts/public-readiness-check.sh
git status --short
```

For full context, read:

```text
SECURITY.md
LLM.md
docs/PUBLIC_RELEASE_CHECKLIST.md
```
