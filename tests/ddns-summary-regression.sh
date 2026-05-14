#!/usr/bin/env bash
# shellcheck disable=SC2034
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export LEIKWAN_STATE_DIR="${TMP_DIR}/state"
export LEIKWAN_BACKUP_DIR="${TMP_DIR}/backups"
export LEIKWAN_RUN_DIR="${TMP_DIR}/run"
export LEIKWAN_LOG_DISABLED=1
export LEIKWAN_NO_CLEAR=1
mkdir -p "$LEIKWAN_RUN_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

DRY_RUN=1
DDNS_FORWARD_CHECKED=4
DDNS_FORWARD_DOMAIN_COUNT=1
DDNS_FORWARD_CHANGED_COUNT=0
DDNS_FORWARD_FAILED_COUNT=0
DDNS_ENTRY_DOMAIN_COUNT=0
DDNS_ENTRY_CHANGED_COUNT=0
DDNS_ENTRY_FAILED_COUNT=0
DDNS_PBR_DOMAIN_COUNT=0
DDNS_PBR_CHANGED_COUNT=0
DDNS_PBR_FAILED_COUNT=0
DDNS_NFT_APPLIED=false
DDNS_PBR_APPLIED=false
DDNS_RELAY_RESTART_NEEDED=false
DDNS_RELAY_RESTARTED=false

summary="$(ddns_print_summary ok)"
grep -q "全局 IP 变化检测摘要" <<<"$summary"
grep -q "后端转发：" <<<"$summary"
grep -q -- "- 检查 4" <<<"$summary"
grep -q "公网入口：" <<<"$summary"
grep -q -- "- 无需刷新" <<<"$summary"
grep -q "域名 PBR：" <<<"$summary"
grep -q -- "- 未配置" <<<"$summary"
grep -q "系统动作：" <<<"$summary"
grep -q "DDNS 状态：OK" <<<"$summary"
if grep -q "summary scope=" <<<"$summary"; then
  echo "FAIL: old machine-style DDNS summary leaked" >&2
  echo "$summary" >&2
  exit 1
fi

echo "[OK] ddns summary regression passed"
