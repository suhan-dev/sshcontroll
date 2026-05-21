# SSHcontroll Build And Release Report

## Summary

SSHcontroll is packaged as a macOS SwiftUI app for controlling a remote Mac over
SSH. The current release uses the user-facing name `SSHcontroll`, bundles the
remote helper, and keeps all runtime settings outside the repository.

## Release Packaging

`Scripts/build-app.sh --release` builds:

```text
.build/SSHcontroll.app
```

By default it installs a development copy at:

```text
~/Desktop/SSHcontroll.app
```

`Scripts/package-macos.sh` builds:

```text
dist/SSHcontroll-0.2.0-macOS.pkg
dist/SSHcontroll-0.2.0-macOS.zip
dist/SHA256SUMS.txt
```

The package installs:

```text
/Applications/SSHcontroll.app
```

## Runtime Data

Runtime files are not part of the package or repository:

```text
~/Library/Application Support/SSHcontroll/
~/remote/
```

Legacy `AControl` Application Support data is copied forward on first launch
when the new SSHcontroll support directory is empty.

## Transfer Notes

File save/upload paths use rsync over SSH with compression disabled, partial
transfer support, timeout handling, and size verification. Large videos are
saved locally instead of being loaded into the preview pane.

## Validation Commands

```bash
Scripts/public-readiness-check.sh
swift build -c release
Scripts/package-macos.sh
(cd dist && shasum -a 256 -c SHA256SUMS.txt)
pkgutil --payload-files dist/SSHcontroll-0.2.0-macOS.pkg | head
unzip -l dist/SSHcontroll-0.2.0-macOS.zip | head
```
