#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/tests/test-lib.sh"

version="$(awk -F= '$1=="TOOL_VERSION" {gsub(/"/, "", $2); print $2; exit}' leikwan-toolkit.sh)"
mkdir -p "$ROOT_DIR/.tmp"
out="$(test_mktemp_file "$ROOT_DIR" "build-release-test.out.XXXXXX")"
list="$(test_mktemp_file "$ROOT_DIR" "build-release-list.XXXXXX")"
trap 'rm -f "$list" "$out"' EXIT

bash scripts/build-release.sh "$version" >"$out"

pkg="dist/leikwan-toolkit-${version}.tar.gz"
sha="${pkg}.sha256"
[[ -f "$pkg" ]] || { echo "FAIL: missing package: ${pkg}" >&2; exit 1; }
[[ -f "$sha" ]] || { echo "FAIL: missing sha256: ${sha}" >&2; exit 1; }

tar -tzf "$pkg" >"$list"

grep -q "leikwan-toolkit-${version}/README.md" "$list"
grep -q "leikwan-toolkit-${version}/leikwan-toolkit.sh" "$list"
grep -q "leikwan-toolkit-${version}/scripts/bootstrap.sh" "$list"
grep -q "leikwan-toolkit-${version}/scripts/build-release.sh" "$list"
grep -q "leikwan-toolkit-${version}/docs/" "$list"
grep -q "leikwan-toolkit-${version}/tests/" "$list"

if grep -Eq '(^|/)(panel|controller|agent|web|edge-tunnel-panel)(/|$)' "$list"; then
  echo "FAIL: release package contains excluded app directories" >&2
  grep -En '(^|/)(panel|controller|agent|web|edge-tunnel-panel)(/|$)' "$list" >&2
  exit 1
fi

grep -q "${pkg##*/}" "$sha"
if grep -Eq '^[A-Fa-f0-9]{64}[[:space:]]+/' "$sha"; then
  echo "FAIL: sha256 file contains absolute path" >&2
  cat "$sha" >&2
  exit 1
fi
absolute_path_pattern='/mnt/ho''st|/ho''me/|^[A-Fa-f0-9]{64}[[:space:]]+.*[\\/]'
if grep -Eq "$absolute_path_pattern" "$sha"; then
  echo "FAIL: sha256 file should use basename only" >&2
  cat "$sha" >&2
  exit 1
fi

echo "[OK] build release regression passed"
