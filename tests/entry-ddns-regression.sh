#!/usr/bin/env bash
# shellcheck disable=SC2034
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

mkdir -p "$ENTRY_DIR" "$STATUS_DIR"
secret_prefix="tok"
secret_value="${secret_prefix}en-value-12345"
update_url="https://ddns.example.test/update?${secret_prefix}en=${secret_value}&domain={host}&ip={ip}"
update_cmd="/usr/local/bin/update-ddns --${secret_prefix}en ${secret_value} {host} {ip}"

entry_ddns_write_config true home.example.test custom-url "$update_url" "$update_cmd" "$secret_value" "" 5min last
cat >"$ENTRY_DDNS_STATUS_FILE" <<'EOF'
LAST_ENTRY_DDNS_TIME=2026-05-11 12:00:00
LAST_ENTRY_DDNS_RESULT=ok
LAST_ENTRY_DDNS_HOST=home.example.test
LAST_ENTRY_DDNS_PUBLIC_IP=198.51.100.10
LAST_ENTRY_DDNS_RESOLVED_IP=198.51.100.10
LAST_ENTRY_DDNS_CHANGED=false
LAST_ENTRY_DDNS_VERSION=1.4.1
EOF

[[ -f "$ENTRY_DDNS_CONFIG" ]] || { echo "FAIL: entry ddns config not created" >&2; exit 1; }

status_out="$(entry_ddns_status)"
grep -q "兼容 DNS 更新状态" <<<"$status_out"
grep -q "home.example.test" <<<"$status_out"
grep -q "一致性: OK" <<<"$status_out"

summary_out="$(entry_ddns_current_config_summary)"
grep -q "兼容 DNS 更新当前配置" <<<"$summary_out"
grep -q "provider: custom-url" <<<"$summary_out"

safe_url="$(redact_sensitive_inline "$update_url")"
safe_cmd="$(redact_sensitive_inline "$update_cmd")"
if grep -q "$secret_value" <<<"${safe_url}${safe_cmd}"; then
  echo "FAIL: inline redaction leaked custom DDNS secret" >&2
  exit 1
fi

fixture="${TMP_DIR}/redact"
mkdir -p "${fixture}/entry" "${fixture}/logs"
cp "$ENTRY_DDNS_CONFIG" "${fixture}/entry/ddns.env"
printf 'custom-url %s\ncustom-cmd %s\n' "$update_url" "$update_cmd" >"${fixture}/logs/leikwan-entry-ddns.log"
config_sensitive_redact_tree "$fixture"
if grep -R -- "$secret_value" "$fixture"; then
  echo "FAIL: config redaction leaked entry ddns secret" >&2
  exit 1
fi

json_out="$(bash leikwan-toolkit.sh status --json)"
grep -q '"entry_ddns_enabled"' <<<"$json_out"
grep -q '"entry_ddns_host"' <<<"$json_out"
if grep -q "$secret_value" <<<"$json_out"; then
  echo "FAIL: status JSON leaked entry DDNS secret" >&2
  exit 1
fi

no_config_state="${TMP_DIR}/empty-state"
out="$(LEIKWAN_STATE_DIR="$no_config_state" LEIKWAN_RUN_DIR="${TMP_DIR}/run2" LEIKWAN_LOG_DISABLED=1 bash leikwan-toolkit.sh entry ddns status 2>&1)"
grep -q "未配置兼容 DNS 更新入口" <<<"$out"
if grep -q "错误：脚本在第" <<<"$out"; then
  echo "FAIL: entry ddns status triggered global trap" >&2
  echo "$out" >&2
  exit 1
fi

entry_ddns_write_config true home.example.test custom-url "$update_url" "" "$secret_value" "" 5min auto
DRY_RUN=1
detect_public_ipv4() { printf '%s' "198.51.100.10"; }
resolve_ipv4_first() { printf '%s' "198.51.100.10"; }
resolve_domain_ipv4_multi() {
  RESOLVE_SELECTED_IP="198.51.100.10"
  RESOLVE_SELECTED_SOURCE="test"
  RESOLVE_ALL_RESULTS="test -> 198.51.100.10"
  RESOLVE_SPLIT_DETECTED=false
  return 0
}
entry_ddns_run_update() { echo "UPDATE_CALLED"; return 0; }
same_out="$(entry_ddns_run 2>&1)"
grep -q "正在检测当前公网 IPv4" <<<"$same_out"
grep -q "正在解析域名：home.example.test" <<<"$same_out"
grep -q "DDNS 已一致，无需更新" <<<"$same_out"
if grep -q "UPDATE_CALLED" <<<"$same_out"; then
  echo "FAIL: entry ddns run called updater when already consistent" >&2
  echo "$same_out" >&2
  exit 1
fi

echo "[OK] entry ddns regression passed"
