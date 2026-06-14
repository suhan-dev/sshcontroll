#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG="${SSHCONTROLL_CONFIG:-${ACONTROL_CONFIG:-release}}"
VERSION="${SSHCONTROLL_VERSION:-${ACONTROL_VERSION:-0.2.1}}"
BUILD_NUMBER="${SSHCONTROLL_BUILD_NUMBER:-1}"
BUNDLE_IDENTIFIER="${SSHCONTROLL_BUNDLE_IDENTIFIER:-dev.suhan.sshcontroll}"
APP_NAME="${SSHCONTROLL_APP_NAME:-SSHcontroll}"
EXECUTABLE_NAME="${SSHCONTROLL_EXECUTABLE_NAME:-SSHcontroll}"
INSTALL=1
OPEN_APP=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      CONFIG="debug"
      ;;
    --release)
      CONFIG="release"
      ;;
    --no-install)
      INSTALL=0
      ;;
    --open)
      OPEN_APP=1
      ;;
    -h|--help)
      cat <<'HELP'
Usage: Scripts/build-app.sh [--debug|--release] [--no-install] [--open]

By default this builds an optimized app and installs it to ~/Desktop/SSHcontroll.app.

Environment:
  SSHCONTROLL_VERSION=0.2.1
  SSHCONTROLL_BUILD_NUMBER=1
  SSHCONTROLL_BUNDLE_IDENTIFIER=dev.suhan.sshcontroll
  SSHCONTROLL_EXECUTABLE_NAME=SSHcontroll
  SSHCONTROLL_INSTALL_PATH=/Applications/SSHcontroll.app
HELP
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

CPU_COUNT="$(sysctl -n hw.activecpu 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || printf '4')"
JOBS="${SSHCONTROLL_JOBS:-${ACONTROL_JOBS:-$CPU_COUNT}}"
swift build -c "$CONFIG" -j "$JOBS"

APP="$ROOT/.build/$APP_NAME.app"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
BIN="$BIN_DIR/$EXECUTABLE_NAME"
ICONSET="$ROOT/Resources/AControl.iconset"
ICON="$ROOT/Resources/AControl.icns"
REMOTE_HELPER="$ROOT/Remote/a-cockpit-remote"

if [[ ! -f "$REMOTE_HELPER" ]]; then
  printf 'Missing remote helper: %s\n' "$REMOTE_HELPER" >&2
  exit 66
fi

if [[ ! -f "$ICON" || "$ROOT/Scripts/generate-icon.swift" -nt "$ICON" ]]; then
  /usr/bin/swift "$ROOT/Scripts/generate-icon.swift" "$ICONSET"
  /usr/bin/iconutil -c icns "$ICONSET" -o "$ICON"
fi

mkdir -p "$ROOT/.build"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$EXECUTABLE_NAME"
if [[ "$CONFIG" == "release" ]]; then
  strip -S -x "$APP/Contents/MacOS/$EXECUTABLE_NAME" 2>/dev/null || true
fi
cp "$ICON" "$APP/Contents/Resources/AControl.icns"
cp "$REMOTE_HELPER" "$APP/Contents/Resources/a-cockpit-remote"
chmod 755 "$APP/Contents/Resources/a-cockpit-remote"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_IDENTIFIER</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AControl</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if [[ "$CONFIG" == "release" ]]; then
  dot_clean -m "$APP" 2>/dev/null || true
  xattr -cr "$APP" 2>/dev/null || true
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
fi

printf 'Built %s\n' "$APP"

if [[ "$INSTALL" == "1" ]]; then
  TARGET="${SSHCONTROLL_INSTALL_PATH:-${ACONTROL_INSTALL_PATH:-$HOME/Desktop/$APP_NAME.app}}"
  mkdir -p "$(dirname "$TARGET")"
  if [[ "$TARGET" == "$HOME/Desktop/$APP_NAME.app" ]]; then
    mkdir -p "$HOME/Desktop"
    find "$HOME/Desktop" -maxdepth 1 \( -name 'SSHcontroll*.app' -o -name 'A Control*.app' -o -name 'AControl*.app' \) -exec rm -rf {} +
  else
    rm -rf "$TARGET"
  fi
  COPYFILE_DISABLE=1 /usr/bin/ditto --noextattr --noacl "$APP" "$TARGET"
  dot_clean -m "$TARGET" 2>/dev/null || true
  xattr -cr "$TARGET" 2>/dev/null || true
  xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null || true
  if [[ "$CONFIG" == "release" ]]; then
    codesign --force --deep --sign - "$TARGET" >/dev/null 2>&1 || true
  fi
  printf 'Installed %s\n' "$TARGET"
fi

if [[ "$OPEN_APP" == "1" ]]; then
  if [[ "$INSTALL" == "1" ]]; then
    open "${SSHCONTROLL_INSTALL_PATH:-${ACONTROL_INSTALL_PATH:-$HOME/Desktop/$APP_NAME.app}}"
  else
    open "$APP"
  fi
fi
