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
grep -q "Leikwan Toolkit 1.4.5 LTS" <<<"$main_out"
grep -q "1. 快速组网" <<<"$main_out"
grep -q "2. 利群主机 B" <<<"$main_out"
grep -q "3. 公网入口 A" <<<"$main_out"
grep -q "4. DDNS" <<<"$main_out"
grep -q "5. 状态 / 诊断" <<<"$main_out"
grep -q "6. 高级维护" <<<"$main_out"
grep -q "0. 退出" <<<"$main_out"
if grep -Eq '7\.|8\.|9\.' <<<"$main_out"; then
  echo "FAIL: main menu should only expose six core entries" >&2
  echo "$main_out" >&2
  exit 1
fi

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

advanced_out="$(print_advanced_menu_options)"
grep -q "高级维护" <<<"$advanced_out"
grep -q "1. EasyTier 服务管理" <<<"$advanced_out"
grep -q "2. 配置备份 / 快照 / 回滚" <<<"$advanced_out"
grep -q "3. 配置导入 / 导出" <<<"$advanced_out"
grep -q "4. 自更新" <<<"$advanced_out"
grep -q "5. 端点输出" <<<"$advanced_out"
grep -q "6. 调试报告" <<<"$advanced_out"
grep -q "7. 卸载" <<<"$advanced_out"
grep -q "0. 返回" <<<"$advanced_out"

status_out="$(print_status_diagnostics_menu_options)"
grep -q "状态 / 诊断" <<<"$status_out"
grep -q "4. 自动修复常见问题" <<<"$status_out"
grep -q "6. 查看日志" <<<"$status_out"

echo "[OK] final menu regression passed"
