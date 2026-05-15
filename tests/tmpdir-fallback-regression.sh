#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/tests/test-lib.sh"

mkdir -p "$ROOT_DIR/.tmp"
bad_tmp="${ROOT_DIR}/.tmp/not-a-dir"
printf 'not a directory\n' >"$bad_tmp"

TMPDIR="$bad_tmp"
tmp_dir="$(test_mktemp_dir "$ROOT_DIR")"
case "$tmp_dir" in
  "$ROOT_DIR"/.tmp/*) ;;
  *) echo "FAIL: TMPDIR fallback did not use repo .tmp: ${tmp_dir}" >&2; exit 1 ;;
esac

tmp_file="$(test_mktemp_file "$ROOT_DIR" "tmpdir-fallback.XXXXXX")"
case "$tmp_file" in
  "$ROOT_DIR"/.tmp/*) ;;
  *) echo "FAIL: temp file fallback did not use repo .tmp: ${tmp_file}" >&2; exit 1 ;;
esac

rm -rf "$tmp_dir" "$tmp_file" "$bad_tmp"

echo "[OK] tmpdir fallback regression passed"
