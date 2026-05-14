#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p "$ROOT_DIR/.tmp"
TMP_DIR="$(TMPDIR="$ROOT_DIR/.tmp" mktemp -d)"
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
grep -q "4. DDNS" <<<"$main_out"
grep -q "6. 高级维护" <<<"$main_out"
grep -q "0. 退出" <<<"$main_out"

ddns_out="$(print_ddns_menu_options)"
grep -q "1. 开启 / 关闭域名解析变化检测" <<<"$ddns_out"
grep -q "2. 立即检测并刷新" <<<"$ddns_out"
grep -q "3. 查看 DDNS / 域名解析状态" <<<"$ddns_out"
grep -q "4. 查看 DDNS 日志" <<<"$ddns_out"
grep -q "5. 高级设置" <<<"$ddns_out"
grep -q "0. 返回" <<<"$ddns_out"
forbidden_regex="$(printf '%s|%s|%s|%s' "A 端""更新" "B 端""监控" "配置 A 端"" DDNS" "应用公网入口 DDNS ""变化")"
if grep -Eq "$forbidden_regex" <<<"$ddns_out"; then
  echo "FAIL: old DDNS menu wording leaked" >&2
  echo "$ddns_out" >&2
  exit 1
fi

advanced_out="$(printf '0\n' | ddns_advanced_menu 2>&1 || true)"
grep -q "3. 设置 DNS 解析器列表" <<<"$advanced_out"
grep -q "4. 设置 DNS 解析策略" <<<"$advanced_out"
grep -q "5. 查看最近 DNS 分歧" <<<"$advanced_out"
grep -q "9. 兼容旧版 DNS 更新配置" <<<"$advanced_out"

systemctl() { return 0; }
need_root_unless_dry_run() { return 0; }
ddns_install_units() { ok "unit stub"; }
toggle_out="$(printf '1\n\n0\n' | ddns_toggle_menu 2>&1 || true)"
grep -q "域名解析变化检测 timer 已启用" <<<"$toggle_out"
grep -q "将每 5min 执行一次域名解析变化检测与本地刷新" <<<"$toggle_out"
if (( $(grep -c "域名解析变化检测" <<<"$toggle_out") < 2 )); then
  echo "FAIL: DDNS toggle submenu did not stay on current menu" >&2
  echo "$toggle_out" >&2
  exit 1
fi
if ! grep -q "0. 返回" <<<"$toggle_out"; then
  echo "FAIL: DDNS toggle submenu did not render return option after action" >&2
  echo "$toggle_out" >&2
  exit 1
fi

echo "[OK] ddns menu regression passed"
