# Public Release Checklist

Use this checklist before turning the repository public or publishing a new
release.

## Source Tree

Run:

```bash
Scripts/public-readiness-check.sh
git status --short
```

Confirm no tracked file contains:

- personal usernames or home folders,
- private SSH hosts or IP addresses,
- SSH key paths,
- API tokens,
- Codex/Claude transcript dumps,
- screenshots or prompt attachments,
- generated `.app`, `.pkg`, `.zip`, `.dSYM`, `.build`, or `dist/` outputs.

If this repository has private history, scan history before making it public.
If private data was ever committed, rewrite or squash history first.

## Build

Run:

```bash
swift build -c release
Scripts/package-macos.sh
```

Verify:

```bash
(cd dist && shasum -a 256 -c SHA256SUMS.txt)
pkgutil --payload-files dist/SSHcontroll-0.2.0-macOS.pkg | head
unzip -l dist/SSHcontroll-0.2.0-macOS.zip | head
```

Optional signing/notarization:

```bash
codesign --verify --deep --strict .build/SSHcontroll.app
pkgutil --check-signature dist/SSHcontroll-0.2.0-macOS.pkg
```

Unsigned local packages are acceptable for private testing. Public releases
should be Developer ID signed and notarized.

## Runtime Smoke Test

Open the built app and check:

- app name is `SSHcontroll`,
- Settings loads and saves,
- local folders exist under `~/remote`,
- `Install Helper` creates `~/.local/bin` on A and copies the bundled helper,
- `Check Connection` reaches A,
- Files can list a remote folder,
- a small image/text preview loads,
- a large video is saved locally rather than previewed,
- folder save produces the expected local files,
- failed/interrupted transfers are reported clearly.

## Tailscale

Check both directions:

```bash
tailscale ping <A-tailnet-name-or-ip>
```

Prefer `direct`. Avoid exit-node or far DERP relay paths for large saves.

## GitHub

Before changing visibility to public:

```bash
gh repo view --json nameWithOwner,visibility
```

Only after source and history are clean:

```bash
gh repo edit <owner>/<repo> --visibility public --accept-visibility-change-consequences
```

Upload release assets from `dist/` to GitHub Releases instead of committing
them.
