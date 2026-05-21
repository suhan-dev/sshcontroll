#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export COPYFILE_DISABLE=1
export COPY_EXTENDED_ATTRIBUTES_DISABLE=1

VERSION="${SSHCONTROLL_VERSION:-${ACONTROL_VERSION:-0.2.0}}"
IDENTIFIER="${SSHCONTROLL_PKG_IDENTIFIER:-${ACONTROL_PKG_IDENTIFIER:-dev.suhan.sshcontroll.pkg}}"
APP_NAME="${SSHCONTROLL_APP_NAME:-SSHcontroll}"
DIST="${SSHCONTROLL_DIST:-$ROOT/dist}"
PKG_ROOT="$ROOT/.build/pkgroot"
APP="$ROOT/.build/$APP_NAME.app"
PKG="$DIST/$APP_NAME-$VERSION-macOS.pkg"
ZIP="$DIST/$APP_NAME-$VERSION-macOS.zip"
SUMS="$DIST/SHA256SUMS.txt"

"$ROOT/Scripts/public-readiness-check.sh"
"$ROOT/Scripts/build-app.sh" --release --no-install

rm -rf "$DIST" "$PKG_ROOT"
mkdir -p "$DIST" "$PKG_ROOT"

xattr -cr "$APP" 2>/dev/null || true
find "$APP" -name '._*' -delete

/usr/bin/ditto --noextattr --noacl "$APP" "$PKG_ROOT/$APP_NAME.app"
xattr -cr "$PKG_ROOT/$APP_NAME.app" 2>/dev/null || true
find "$PKG_ROOT" -name '._*' -delete

pkgbuild \
  --root "$PKG_ROOT" \
  --install-location "/Applications" \
  --identifier "$IDENTIFIER" \
  --version "$VERSION" \
  "$PKG"

(
  cd "$APP/.."
  COPYFILE_DISABLE=1 /usr/bin/ditto -c -k --norsrc --noextattr --noacl --keepParent "$APP_NAME.app" "$ZIP"
)

(
  cd "$DIST"
  shasum -a 256 "$(basename "$PKG")" "$(basename "$ZIP")" > "$(basename "$SUMS")"
)

printf 'Built installer: %s\n' "$PKG"
printf 'Built zip:       %s\n' "$ZIP"
printf 'Checksums:       %s\n' "$SUMS"
