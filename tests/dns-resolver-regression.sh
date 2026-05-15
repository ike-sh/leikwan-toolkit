#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=/dev/null
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

DDNS_LOG_FILE="${TMP_DIR}/ddns.log"
ORIGINAL_PATH="$PATH"
mkdir -p "$STATUS_DIR"

[[ "$DNS_RESOLVE_SERVERS_DEFAULT" == "1.1.1.1,8.8.8.8,223.5.5.5,119.29.29.29" ]]
[[ "$DNS_RESOLVE_STRATEGY_DEFAULT" == "first-success" ]]
[[ "$DNS_RESOLVE_WARN_ON_SPLIT_DEFAULT" == "true" ]]

dig() {
  local server="${4#@}"
  case "$server" in
    1.1.1.1|8.8.8.8) printf '%s\n' "1.1.1.1" ;;
    223.5.5.5|119.29.29.29) printf '%s\n' "211.158.46.251" ;;
    *) return 1 ;;
  esac
}

getent() {
  case "$1" in
    ahostsv4|ahosts) printf '%s STREAM home.example.test\n' "211.158.46.251" ;;
    *) return 1 ;;
  esac
}

resolve_domain_ipv4_multi home.example.test >"${TMP_DIR}/split.out" 2>&1
[[ "$RESOLVE_SELECTED_IP" == "1.1.1.1" ]]
[[ "$RESOLVE_SELECTED_SOURCE" == "1.1.1.1" ]]
[[ "$RESOLVE_SPLIT_DETECTED" == "true" ]]
grep -q "1.1.1.1 -> 1.1.1.1" <<<"$RESOLVE_ALL_RESULTS"
grep -q "223.5.5.5 -> 211.158.46.251" <<<"$RESOLVE_ALL_RESULTS"

cat >"$DDNS_STATUS_FILE" <<EOF
LAST_DDNS_TIME=2026-05-14 12:00:00
LAST_DDNS_RESULT=ok
LAST_DDNS_SCOPE=all
LAST_DDNS_PUBLIC_IP=203.0.113.9
LAST_DDNS_PUBLIC_IP_SOURCE=https://4.ipw.cn
LAST_DDNS_FORWARD_CHECKED=0
LAST_DDNS_FORWARD_FAILED_COUNT=0
LAST_DDNS_ENTRY_CHECKED=0
LAST_DDNS_ENTRY_FAILED_COUNT=0
LAST_DDNS_PBR_CHECKED=0
LAST_DDNS_PBR_FAILED_COUNT=0
LAST_DDNS_RELAY_RESTART_NEEDED=false
LAST_DDNS_NFT_APPLIED=false
LAST_DDNS_PBR_APPLIED=false
LAST_DDNS_RELAY_RESTARTED=false
LAST_DDNS_DNS_STRATEGY=first-success
LAST_DDNS_DNS_SERVERS=${DNS_RESOLVE_SERVERS_DEFAULT}
LAST_DDNS_DNS_SPLIT_DETECTED=true
LAST_DDNS_DNS_INCOMPLETE_DETECTED=false
LAST_DDNS_DNS_SPLIT_DOMAIN=home.example.test
LAST_DDNS_DNS_SPLIT_RESULTS=${RESOLVE_ALL_RESULTS}
LAST_DDNS_DNS_SELECTED_IP=${RESOLVE_SELECTED_IP}
LAST_DDNS_DNS_SELECTED_SOURCE=${RESOLVE_SELECTED_SOURCE}
LAST_DDNS_VERSION=1.4.7
EOF

status_out="$(ddns_status)"
grep -q "home.example.test" <<<"$status_out"
grep -q "1.1.1.1" <<<"$status_out"
grep -q "https://4.ipw.cn" <<<"$status_out"

dig() { return 127; }
nslookup() { return 127; }
host() { return 127; }
command() {
  if [[ "${1:-}" == "-v" ]]; then
    case "${2:-}" in
      dig|nslookup|host) return 1 ;;
    esac
  fi
  builtin command "$@"
}
dnsutils_auto_install() { return 1; }
getent() {
  case "$1" in
    ahostsv4|ahosts) printf '%s STREAM home.example.test\n' "211.158.46.251" ;;
    *) return 1 ;;
  esac
}
DDNS_DNS_DIG_WARNED=false
DDNS_DNS_INCOMPLETE_DETECTED=false
resolve_domain_ipv4_multi home.example.test >"${TMP_DIR}/fallback.out" 2>&1
[[ "$RESOLVE_SELECTED_IP" == "211.158.46.251" ]]
[[ "$RESOLVE_SELECTED_SOURCE" == "system" ]]
[[ "$RESOLVE_INCOMPLETE_DETECTED" == "true" ]]
[[ "$DDNS_DNS_INCOMPLETE_DETECTED" == "true" ]]
grep -q "system -> 211.158.46.251" <<<"$RESOLVE_ALL_RESULTS"

cat >"$DDNS_STATUS_FILE" <<EOF
LAST_DDNS_TIME=2026-05-15 12:00:00
LAST_DDNS_RESULT=ok
LAST_DDNS_SCOPE=all
LAST_DDNS_DNS_STRATEGY=first-success
LAST_DDNS_DNS_SERVERS=${DNS_RESOLVE_SERVERS_DEFAULT}
LAST_DDNS_DNS_SPLIT_DETECTED=false
LAST_DDNS_DNS_INCOMPLETE_DETECTED=true
LAST_DDNS_RELAY_RESTART_NEEDED=false
LAST_DDNS_NFT_APPLIED=false
LAST_DDNS_PBR_APPLIED=false
LAST_DDNS_RELAY_RESTARTED=false
EOF
status_incomplete="$(ddns_status)"
grep -q "DNS" <<<"$status_incomplete"

unset -f dig nslookup host getent command
PATH="$ORIGINAL_PATH"
DNS_RESOLVE_STRATEGY="majority"
ddns_config_value() {
  case "$1" in
    DNS_RESOLVE_STRATEGY) printf '%s' "majority" ;;
    DNS_RESOLVE_SERVERS) printf '%s' "$DNS_RESOLVE_SERVERS_DEFAULT" ;;
    DNS_RESOLVE_WARN_ON_SPLIT) printf '%s' "true" ;;
    *) printf '%s' "${2:-}" ;;
  esac
}
dig() {
  local server="${4#@}"
  case "$server" in
    1.1.1.1) printf '%s\n' "1.1.1.1" ;;
    8.8.8.8|223.5.5.5|119.29.29.29) printf '%s\n' "211.158.46.251" ;;
    *) return 1 ;;
  esac
}
resolve_domain_ipv4_multi home.example.test >/dev/null
[[ "$RESOLVE_SELECTED_IP" == "211.158.46.251" ]]

echo "[OK] DNS resolver regression passed"
