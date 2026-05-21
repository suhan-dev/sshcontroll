#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

"$ROOT/Scripts/privacy-scan.sh"

if git diff --check; then
  :
else
  printf 'Whitespace check failed.\n' >&2
  exit 1
fi

tracked_files="$(mktemp)"
cleanup() {
  rm -f "$tracked_files"
}
trap cleanup EXIT

while IFS= read -r -d '' file; do
  if [[ -e "$file" ]]; then
    printf '%s\n' "$file"
  fi
done < <(git ls-files -z) >"$tracked_files"

tracked_runtime="$(
  rg -n \
    '(^dist/|\.pkg$|\.zip$|\.app/|\.dSYM/|(^|/)settings\.json$|(^|/)sessions\.json$|Prompt Attachments|(^|/)Previews/|(^|/)\.env($|\.)|(^|/)\.ssh/|(^|/)id_(rsa|ed25519)$)' \
    "$tracked_files" \
    || true
)"

if [[ -n "$tracked_runtime" ]]; then
  printf '%s\n' "$tracked_runtime" >&2
  printf 'Public readiness failed: generated/runtime/secret-like files are tracked.\n' >&2
  exit 1
fi

private_file_pattern='(^|/)PRIVATE_|PRIVATE_''INSTALL_AND_OPERATIONS'
tracked_private_docs="$(rg -n "$private_file_pattern" "$tracked_files" || true)"

if [[ -n "$tracked_private_docs" ]]; then
  printf '%s\n' "$tracked_private_docs" >&2
  printf 'Public readiness failed: private handoff/install files are tracked.\n' >&2
  exit 1
fi

printf 'Public readiness check passed.\n'
