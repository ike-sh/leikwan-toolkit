#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/tests/test-lib.sh"

bash scripts/package-release.sh

version="$(awk -F= '$1=="TOOL_VERSION" {gsub(/"/, "", $2); print $2; exit}' leikwan-toolkit.sh)"
pkg="dist/leikwan-toolkit-${version}.tar.gz"
sha="${pkg}.sha256"
[[ -f "$pkg" ]] || { echo "FAIL: missing package: ${pkg}" >&2; exit 1; }
[[ -f "$sha" ]] || { echo "FAIL: missing sha256: ${sha}" >&2; exit 1; }

list="$(test_mktemp_file "$ROOT_DIR" "package-list.XXXXXX")"
trap 'rm -f "$list"' EXIT
tar -tzf "$pkg" >"$list"

deny='(^|/)(\.git|dist)(/|$)|wg-toolkit\.sh|uninstall\.sh|leikwan-debug-report|/tmp/|tests/tmp|\.log$'
if grep -E "$deny" "$list"; then
  echo "FAIL: release package contains denied path" >&2
  exit 1
fi

grep -q "leikwan-toolkit-${version}/leikwan-toolkit.sh" "$list"
grep -q "leikwan-toolkit-${version}/scripts/verify-release.sh" "$list"
grep -q "leikwan-toolkit-${version}/tests/smoke.sh" "$list"

echo "[OK] package regression passed"
