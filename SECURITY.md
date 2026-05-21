# Security Policy

SSHcontroll is designed for public source distribution while keeping every
operator-specific value outside the repository.

## Repository Mode

The public repository should contain source code, scripts, and generic
documentation only. Release artifacts belong in GitHub Releases, not in git.

Before changing a private repository to public visibility:

1. Run `Scripts/public-readiness-check.sh`.
2. Review current tracked files for hostnames, usernames, private paths, keys,
   screenshots, transcripts, and generated artifacts.
3. Review git history if the repository was ever used privately.
4. Rewrite or squash history before public release if private values were ever
   committed.
5. Publish signed/notarized release artifacts when possible.

## Never Commit

- SSH passwords.
- SSH private keys or `.ssh` directories.
- Private key paths that identify a workstation.
- GitHub tokens or API tokens.
- Real private hostnames or IP addresses.
- Personal local usernames or home folder paths.
- Codex or Claude transcript dumps.
- Prompt attachments.
- Local previews, screenshots, generated mirrors, or save folders.
- Runtime settings.
- Generated `.app`, `.pkg`, `.zip`, `.dSYM`, `.build`, or `dist/` outputs.

Runtime data lives here:

```text
~/Library/Application Support/SSHcontroll/
~/remote/
```

Legacy installs may also have:

```text
~/Library/Application Support/AControl/
```

Do not upload those folders.

## Checks

Run before pushing:

```bash
Scripts/public-readiness-check.sh
```

For local values only you know, add extra patterns without committing them:

```bash
SSHCONTROLL_PRIVACY_EXTRA_PATTERNS='PRIVATE_HOST|PRIVATE_USER|PRIVATE_PASSWORD_FRAGMENT' Scripts/privacy-scan.sh
```

The older `ACONTROL_PRIVACY_EXTRA_PATTERNS` environment variable is still
accepted for compatibility.

## macOS Permission Model

SSHcontroll can guide permission setup but cannot silently grant macOS privacy
permissions. The user must approve final toggles in System Settings.

Important permission categories:

- Accessibility.
- Screen & System Audio Recording.
- Input Monitoring.
- Automation.
- Full Disk Access only when a workflow genuinely needs protected folders.

Target identity matters:

- SSHcontroll is the local controller app.
- Codex.app is the desktop Codex app.
- The Codex CLI binary may have a different permission identity.
- Codex Computer Use helper processes have their own identity.
- A stable permission host helper may be needed for CLI-owned screenshots or
  Apple Events workflows.

Do not claim a permission is granted until the operation owner has been checked.

## Transfer Security

File save/upload flows use SSH and rsync. SSHcontroll does not implement a
custom network protocol and does not store passwords. Prefer SSH keys and
Tailscale or another trusted private route. Keep exit-node/VPN choices explicit
because relay routing can reduce transfer speed.

## Reporting A Security Issue

Open a GitHub security advisory or contact the repository owner directly. Do
not include real passwords, private keys, tokens, or private hostnames in issue
text.
