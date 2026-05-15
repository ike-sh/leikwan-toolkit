#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/tests/test-lib.sh"

mkdir -p "$ROOT_DIR/.tmp"
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

[[ -n "${PUBLIC_IP_CHECK_URLS_DEFAULT:-}" ]] || {
  echo "FAIL: PUBLIC_IP_CHECK_URLS_DEFAULT missing" >&2
  exit 1
}

grep -q "api.ipify.org" <<<"$PUBLIC_IP_CHECK_URLS_DEFAULT"
grep -q "ifconfig.me/ip" <<<"$PUBLIC_IP_CHECK_URLS_DEFAULT"
grep -q "ipv4.icanhazip.com" <<<"$PUBLIC_IP_CHECK_URLS_DEFAULT"
grep -q "4.ipw.cn" <<<"$PUBLIC_IP_CHECK_URLS_DEFAULT"
grep -q "ip.3322.net" <<<"$PUBLIC_IP_CHECK_URLS_DEFAULT"
grep -q "myip.ipip.net" <<<"$PUBLIC_IP_CHECK_URLS_DEFAULT"

[[ "$(extract_first_ipv4 "Current IP Address: 203.0.113.42")" == "203.0.113.42" ]]
[[ "$(extract_first_ipv4 $'198.51.100.8\n')" == "198.51.100.8" ]]
[[ -z "$(extract_first_ipv4 "no public address here" || true)" ]]
[[ -z "$(extract_first_ipv4 "999.1.1.1" || true)" ]]

custom="$(public_ip_check_urls " https://a.example/ip ,https://b.example/ip")"
grep -qx "https://a.example/ip" <<<"$custom"
grep -qx "https://b.example/ip" <<<"$custom"

curl() {
  case "$*" in
    *https://a.example/ip*) return 28 ;;
    *https://b.example/ip*) printf '%s\n' "198.51.100.77" ;;
    *) return 1 ;;
  esac
}

detected_file="${TMP_DIR}/detected-ip.txt"
detect_public_ipv4 "https://a.example/ip,https://b.example/ip" >"$detected_file" 2>/dev/null || true
detected="$(cat "$detected_file")"
[[ "$detected" == "198.51.100.77" ]]
[[ "$DDNS_PUBLIC_IP" == "198.51.100.77" ]]
[[ "$DDNS_PUBLIC_IP_SOURCE" == "https://b.example/ip" ]]
[[ "$DDNS_PUBLIC_IP_FAILED" == "false" ]]

echo "[OK] public IP source regression passed"
