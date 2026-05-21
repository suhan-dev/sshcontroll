# LLM Guide For SSHcontroll

This file is for LLM agents working on the SSHcontroll repository.

## Prime Directive

Keep the repo public-safe. Do not commit personal machine names, SSH targets,
private IPs, usernames, SSH key paths, tokens, transcripts, attachments,
screenshots, local mirrors, generated packages, or runtime settings.

Runtime data belongs outside git:

```text
~/Library/Application Support/SSHcontroll/
~/remote/
```

Legacy local data may exist at:

```text
~/Library/Application Support/AControl/
```

The app migrates legacy files forward when the new SSHcontroll support folder is
empty.

## Project Map

- `Sources/AControlApp/`: SwiftUI app source.
- `Remote/a-cockpit-remote`: bundled helper copied to the A computer.
- `Scripts/build-app.sh`: builds `SSHcontroll.app`.
- `Scripts/package-macos.sh`: builds `.pkg`, `.zip`, and checksums.
- `Scripts/privacy-scan.sh`: scans for private-looking values.
- `Scripts/public-readiness-check.sh`: release/public safety gate.
- `INSTALL_MAC.md`: end-user install steps.
- `docs/INSTALL_AND_OPERATIONS.md`: complete two-machine operations guide.
- `docs/TAILSCALE_SETUP.md`: network route guidance for faster saves.
- `docs/PUBLIC_RELEASE_CHECKLIST.md`: public release checklist.

Internal Swift names such as `AControlApp` and `AControlStyle` are legacy
implementation names. The product, app bundle, package, and user-facing name are
`SSHcontroll`.

## Build

```bash
Scripts/build-app.sh --release
open "$HOME/Desktop/SSHcontroll.app"
```

Package:

```bash
Scripts/package-macos.sh
```

Verify:

```bash
Scripts/public-readiness-check.sh
(cd dist && shasum -a 256 -c SHA256SUMS.txt)
pkgutil --payload-files dist/SSHcontroll-0.2.0-macOS.pkg | head
unzip -l dist/SSHcontroll-0.2.0-macOS.zip | head
```

## Transfer Behavior

Save/upload performance is important. Preserve these rules:

- Use rsync over SSH with compression disabled for file transfers.
- Keep partial-transfer support and explicit timeouts.
- Verify final local/remote file sizes.
- Report interrupted transfers clearly and stop the operation.
- Do not preview large videos in-app; save them locally and open the saved copy.
- Keep Files and Mirror logs scrollable enough to diagnose failed transfers.
- Do not add duplicate transfer paths unless there is a measured reason.

## Tailscale Behavior

When speed is poor, check the network route before rewriting transfer logic:

```bash
tailscale status
tailscale ping <other-mac-tailnet-name-or-ip>
```

Fast transfers usually require a direct path. DERP relay, exit-node routing, or
far-region VPN routing can dominate the bottleneck.

## Verification Standard

Do not call a change done after only reading a diff. For app work, verify the
relevant runtime surface:

- build succeeds,
- package/checksum succeeds for release work,
- app opens with the expected name,
- settings path and local folders are created,
- helper path is bundled,
- Files save/upload works on at least one real file,
- folder save works when that path was touched,
- interrupted transfers show a clear failure log.

For security/public-release work, run:

```bash
Scripts/public-readiness-check.sh
git diff --check
git status --short
```

## Editing Rules

- Prefer the existing SwiftUI style and helper APIs.
- Keep changes scoped to the requested behavior.
- Avoid broad renames of legacy internal Swift type names unless the user asks
  for a source-level rename.
- Use placeholders in docs: `<A-target>`, `<A-tailnet-name-or-ip>`,
  `<owner>/<repo>`.
- Never paste real local secrets into examples, tests, or logs.
