#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

escape_ere() {
  printf '%s' "$1" | sed -E 's/[][(){}.^$*+?|\/\\]/\\&/g'
}

CURRENT_USER="$(id -un 2>/dev/null || true)"
HOME_PATH="${HOME:-}"
PATTERNS=(
  'gho_[A-Za-z0-9_]+'
  'github_pat_[A-Za-z0-9_]+'
  'BEGIN [A-Z ]*PRIVATE[[:space:]]KEY'
  'PRIVATE[[:space:]]KEY-----'
  'BEGIN OPENSSH PRIVATE KEY'
  'ssh-(rsa|ed25519)[[:space:]]+AAAA[A-Za-z0-9+/=]+'
  'ChatGPT-Account-Id'
  'account_id[[:space:]]*[=:][[:space:]]*[A-Za-z0-9-]{8,}'
  'sk-[A-Za-z0-9_-]{20,}'
  'password[[:space:]]*[=:][[:space:]]*["'\''][^"'\'']{4,}'
  'api[_-]?secret[[:space:]]*[=:]'
  'api[_-]?token[[:space:]]*[=:]'
  'access[_-]?token[[:space:]]*[=:]'
)

if [[ -n "$CURRENT_USER" ]]; then
  PATTERNS+=("$(escape_ere "$CURRENT_USER")")
fi

if [[ -n "$HOME_PATH" ]]; then
  PATTERNS+=("$(escape_ere "$HOME_PATH")")
fi

if [[ -n "${SSHCONTROLL_PRIVACY_EXTRA_PATTERNS:-}" ]]; then
  PATTERNS+=("$SSHCONTROLL_PRIVACY_EXTRA_PATTERNS")
fi

if [[ -n "${ACONTROL_PRIVACY_EXTRA_PATTERNS:-}" ]]; then
  PATTERNS+=("$ACONTROL_PRIVACY_EXTRA_PATTERNS")
fi

PATTERN="$(IFS='|'; printf '%s' "${PATTERNS[*]}")"

TMP_GIT="$(mktemp)"
TMP_WORKTREE="$(mktemp)"
cleanup() {
  rm -f "$TMP_GIT" "$TMP_WORKTREE"
}
trap cleanup EXIT

if git grep -n -I -E "$PATTERN" -- \
  . \
  ':(exclude)Scripts/privacy-scan.sh' \
  ':(exclude).build' \
  ':(exclude).git' \
  ':(exclude)dist' \
  ':(exclude)*.png' \
  ':(exclude)*.jpg' \
  ':(exclude)*.jpeg' \
  ':(exclude)*.icns' >"$TMP_GIT"; then
  cat "$TMP_GIT" >&2
  printf 'Privacy scan failed: tracked files contain private-looking values.\n' >&2
  exit 1
fi

if command -v rg >/dev/null 2>&1; then
  if rg -n -I --hidden \
    -g '!.git' \
    -g '!.build' \
    -g '!dist' \
    -g '!Scripts/privacy-scan.sh' \
    -g '!*.png' \
    -g '!*.jpg' \
    -g '!*.jpeg' \
    -g '!*.icns' \
    -g '!*.app/**' \
    -e "$PATTERN" >"$TMP_WORKTREE"; then
    cat "$TMP_WORKTREE" >&2
    printf 'Privacy scan failed: worktree files contain private-looking values.\n' >&2
    exit 1
  fi
fi

printf 'Privacy scan passed.\n'
