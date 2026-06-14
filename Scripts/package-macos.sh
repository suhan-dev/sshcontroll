#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export COPYFILE_DISABLE=1
export COPY_EXTENDED_ATTRIBUTES_DISABLE=1

VERSION="${SSHCONTROLL_VERSION:-${ACONTROL_VERSION:-0.2.1}}"
IDENTIFIER="${SSHCONTROLL_PKG_IDENTIFIER:-${ACONTROL_PKG_IDENTIFIER:-dev.suhan.sshcontroll.pkg}}"
APP_NAME="${SSHCONTROLL_APP_NAME:-SSHcontroll}"
DIST="${SSHCONTROLL_DIST:-$ROOT/dist}"
PKG_ROOT="$ROOT/.build/pkgroot"
PKG_EXPANDED="$ROOT/.build/pkg-expanded-clean"
APP="$ROOT/.build/$APP_NAME.app"
PKG="$DIST/$APP_NAME-$VERSION-macOS.pkg"
ZIP="$DIST/$APP_NAME-$VERSION-macOS.zip"
SUMS="$DIST/SHA256SUMS.txt"

"$ROOT/Scripts/public-readiness-check.sh"
"$ROOT/Scripts/build-app.sh" --release --no-install

rm -rf "$DIST" "$PKG_ROOT"
mkdir -p "$DIST" "$PKG_ROOT"

xattr -cr "$APP" 2>/dev/null || true
xattr -dr com.apple.provenance "$APP" 2>/dev/null || true
find "$APP" -name '._*' -delete

/usr/bin/ditto --noextattr --noacl "$APP" "$PKG_ROOT/$APP_NAME.app"
xattr -cr "$PKG_ROOT/$APP_NAME.app" 2>/dev/null || true
xattr -dr com.apple.provenance "$PKG_ROOT/$APP_NAME.app" 2>/dev/null || true
dot_clean -m "$PKG_ROOT/$APP_NAME.app" 2>/dev/null || true
find "$PKG_ROOT" -name '._*' -delete

pkgbuild \
  --root "$PKG_ROOT" \
  --install-location "/Applications" \
  --identifier "$IDENTIFIER" \
  --version "$VERSION" \
  "$PKG"

rm -rf "$PKG_EXPANDED"
pkgutil --expand "$PKG" "$PKG_EXPANDED"
(
  cd "$PKG_ROOT"
  COPYFILE_DISABLE=1 find . -print \
    | COPYFILE_DISABLE=1 cpio -o --format odc --owner 0:0 \
    | gzip -c > "$PKG_EXPANDED/Payload"
)
mkbom "$PKG_ROOT" "$PKG_EXPANDED/Bom"
PAYLOAD_FILE_COUNT="$(cd "$PKG_ROOT" && find . -print | wc -l | tr -d '[:space:]')"
PAYLOAD_INSTALL_KB="$(du -sk "$PKG_ROOT" | awk '{print $1}')"
PAYLOAD_FILE_COUNT="$PAYLOAD_FILE_COUNT" PAYLOAD_INSTALL_KB="$PAYLOAD_INSTALL_KB" \
  perl -0pi -e \
  's/<payload numberOfFiles="[^"]+" installKBytes="[^"]+"\/>/<payload numberOfFiles="$ENV{PAYLOAD_FILE_COUNT}" installKBytes="$ENV{PAYLOAD_INSTALL_KB}"\/>/g' \
  "$PKG_EXPANDED/PackageInfo"
pkgutil --flatten "$PKG_EXPANDED" "$PKG.clean"
mv "$PKG.clean" "$PKG"
rm -rf "$PKG_EXPANDED"

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
