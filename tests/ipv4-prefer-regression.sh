#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=tests/test-lib.sh
source "$ROOT_DIR/tests/test-lib.sh"

TMP_DIR="$(test_mktemp_dir "$ROOT_DIR")"
trap 'rm -rf "$TMP_DIR"' EXIT

export LEIKWAN_STATE_DIR="${TMP_DIR}/state"
export LEIKWAN_BACKUP_DIR="${TMP_DIR}/backups"
export LEIKWAN_RUN_DIR="${TMP_DIR}/run"
export LEIKWAN_LOG_DISABLED=1
export LEIKWAN_NO_CLEAR=1
export LEIKWAN_GAI_CONF="${TMP_DIR}/gai.conf"
mkdir -p "$LEIKWAN_RUN_DIR"
printf '# user gai setting\nlabel ::1/128 0\n' >"$LEIKWAN_GAI_CONF"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

need_root_unless_dry_run() { :; }

system_ipv4_prefer_enable >/dev/null
grep -q "# BEGIN LEIKWAN IPV4 PREFER" "$LEIKWAN_GAI_CONF"
grep -q "precedence ::ffff:0:0/96  100" "$LEIKWAN_GAI_CONF"
grep -q "# END LEIKWAN IPV4 PREFER" "$LEIKWAN_GAI_CONF"
grep -q "# user gai setting" "$LEIKWAN_GAI_CONF"

system_ipv4_prefer_enable >/dev/null
[[ "$(grep -c "# BEGIN LEIKWAN IPV4 PREFER" "$LEIKWAN_GAI_CONF")" -eq 1 ]] || {
  echo "FAIL: IPv4 prefer block duplicated" >&2
  exit 1
}

status_out="$(system_ipv4_prefer_status)"
grep -q "IPv4 优先: enabled" <<<"$status_out"
grep -q "gai.conf: managed" <<<"$status_out"

system_ipv4_prefer_disable >/dev/null
if grep -q "LEIKWAN IPV4 PREFER" "$LEIKWAN_GAI_CONF"; then
  echo "FAIL: managed block was not removed" >&2
  exit 1
fi
grep -q "# user gai setting" "$LEIKWAN_GAI_CONF"

echo "[OK] IPv4 prefer regression passed"
