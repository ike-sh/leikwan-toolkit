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
mkdir -p "$LEIKWAN_RUN_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

main_out="$(print_main_menu_options)"
grep -q "Leikwan Toolkit 1.4.8 LTS" <<<"$main_out"
grep -q "1." <<<"$main_out"
grep -q "2." <<<"$main_out"
grep -q "3." <<<"$main_out"
grep -q "4. DDNS" <<<"$main_out"
grep -q "5." <<<"$main_out"
grep -q "6." <<<"$main_out"
grep -q "0." <<<"$main_out"
if grep -Eq '7\.|8\.|9\.' <<<"$main_out"; then
  echo "FAIL: main menu should only expose six core entries" >&2
  echo "$main_out" >&2
  exit 1
fi

ddns_out="$(print_ddns_menu_options)"
grep -q "DDNS" <<<"$ddns_out"
grep -q "1." <<<"$ddns_out"
grep -q "2." <<<"$ddns_out"
grep -q "3." <<<"$ddns_out"
grep -q "4." <<<"$ddns_out"
grep -q "5." <<<"$ddns_out"
grep -q "0." <<<"$ddns_out"

advanced_out="$(print_advanced_menu_options)"
grep -q "EasyTier" <<<"$advanced_out"
grep -q "1." <<<"$advanced_out"
grep -q "2." <<<"$advanced_out"
grep -q "3." <<<"$advanced_out"
grep -q "4." <<<"$advanced_out"
grep -q "5." <<<"$advanced_out"
grep -q "6." <<<"$advanced_out"
grep -q "7." <<<"$advanced_out"
grep -q "0." <<<"$advanced_out"

status_out="$(print_status_diagnostics_menu_options)"
grep -q "1." <<<"$status_out"
grep -q "4." <<<"$status_out"
grep -q "6." <<<"$status_out"

echo "[OK] final menu regression passed"
