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
export LEIKWAN_RESOLV_CONF="${TMP_DIR}/resolv.conf"
mkdir -p "$LEIKWAN_RUN_DIR"
printf 'nameserver 9.9.9.9\n' >"$LEIKWAN_RESOLV_CONF"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

need_root_unless_dry_run() { :; }
systemctl() { return 1; }

out="$(system_network_prepare 2>&1)"
grep -q "正在执行系统网络预处理：IPv4 优先 + 国外 DNS" <<<"$out"
grep -q "已开启 IPv4 优先" <<<"$out"
grep -q "已设置系统 DNS：8.8.8.8,1.1.1.1" <<<"$out"

declare -f quick_generate_network_pairing | grep -q "system_network_prepare"
declare -f quick_deploy_entry_from_network_pairing | grep -q "system_network_prepare"
declare -f init_relay_wizard | grep -q "system_network_prepare"

steps_out="$(print_quick_networking_steps)"
grep -q "快速组网会自动执行系统网络预处理" <<<"$steps_out"
grep -q "8.8.8.8 / 1.1.1.1" <<<"$steps_out"
legacy_phrase="可选修复 DNS / IPv4"
legacy_phrase="${legacy_phrase} 优先"
if grep -q "$legacy_phrase" <<<"$steps_out"; then
  echo "FAIL: quickstart still describes DNS / IPv4 as optional" >&2
  exit 1
fi

echo "[OK] quickstart network prepare regression passed"
