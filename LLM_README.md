# LLM README

This file is kept for backward compatibility with older agent prompts.

For current SSHcontroll development, setup, transfer, packaging, and public
release rules, read:

```text
LLM.md
docs/INSTALL_AND_OPERATIONS.md
docs/TAILSCALE_SETUP.md
docs/PUBLIC_RELEASE_CHECKLIST.md
```

Short version:

- Do not commit secrets, hostnames, private IPs, local paths, transcripts,
  attachments, generated packages, or runtime settings.
- Build with `Scripts/build-app.sh --release`.
- Package with `Scripts/package-macos.sh`.
- Run `Scripts/public-readiness-check.sh` before publishing.
- Keep large video files on the Save path instead of adding large video preview
  behavior.
