# SSHcontroll LLM Program Guide

This guide is the long-lived pointer for agents and maintainers. The current
authoritative agent guide is [LLM.md](LLM.md).

## Read Order

1. [LLM.md](LLM.md)
2. [README.md](README.md)
3. [INSTALL_MAC.md](INSTALL_MAC.md)
4. [docs/INSTALL_AND_OPERATIONS.md](docs/INSTALL_AND_OPERATIONS.md)
5. [docs/TAILSCALE_SETUP.md](docs/TAILSCALE_SETUP.md)
6. [docs/PUBLIC_RELEASE_CHECKLIST.md](docs/PUBLIC_RELEASE_CHECKLIST.md)

## Stable Architecture

SSHcontroll has two halves:

- a local macOS SwiftUI/AppKit app,
- a remote helper script installed on the A computer.

The local app owns UI, settings, SSH execution, preview/download/upload flows,
and helper installation. The helper owns remote shell/tmux/Codex/Claude/files/
monitor commands.

Public-facing names are `SSHcontroll`, `SSHcontroll.app`, and
`SSHcontroll-<version>-macOS.pkg`. Legacy internal Swift names such as
`AControlApp` and `AControlStyle` may remain until a deliberate source-level
rename is scheduled.

## Current Release Commands

```bash
Scripts/public-readiness-check.sh
Scripts/build-app.sh --release
Scripts/package-macos.sh
```

Expected release assets:

```text
dist/SSHcontroll-0.2.0-macOS.pkg
dist/SSHcontroll-0.2.0-macOS.zip
dist/SHA256SUMS.txt
```

## Public-Safe Rule

Never add real private machine data to this guide. Use placeholders such as
`<A-target>`, `<A-tailnet-name-or-ip>`, and `<owner>/<repo>`.
