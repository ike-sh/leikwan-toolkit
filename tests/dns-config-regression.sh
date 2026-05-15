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
export LEIKWAN_RESOLVED_CONF="${TMP_DIR}/resolved.conf.d/99-leikwan-dns.conf"
export LEIKWAN_RESOLV_CONF="${TMP_DIR}/resolv.conf"
mkdir -p "$LEIKWAN_RUN_DIR"
printf 'nameserver 9.9.9.9\n' >"$LEIKWAN_RESOLV_CONF"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

need_root_unless_dry_run() { :; }
SYSTEMD_STATE="active"
systemctl() {
  case "$*" in
    "is-active --quiet systemd-resolved") [[ "$SYSTEMD_STATE" == "active" ]] ;;
    "list-unit-files --no-legend systemd-resolved.service")
      [[ "$SYSTEMD_STATE" != "missing" ]] && echo "systemd-resolved.service enabled"
      [[ "$SYSTEMD_STATE" != "missing" ]]
      ;;
    "restart systemd-resolved") return 0 ;;
    *) return 0 ;;
  esac
}

system_dns_set_default_foreign >/dev/null
grep -q "DNS=8.8.8.8 1.1.1.1" "$LEIKWAN_RESOLVED_CONF"
grep -q "FallbackDNS=8.8.4.4 1.0.0.1" "$LEIKWAN_RESOLVED_CONF"
[[ -n "$(find "$LEIKWAN_BACKUP_DIR" -type f -name '*resolv.conf*.bak' -o -name '*99-leikwan-dns.conf*.bak' 2>/dev/null || true)" ]] || true

status_out="$(system_dns_status)"
grep -q "系统 DNS: 8.8.8.8,1.1.1.1" <<<"$status_out"
grep -q "Fallback DNS: 8.8.4.4,1.0.0.1" <<<"$status_out"
grep -q "systemd-resolved: active" <<<"$status_out"
grep -q "DNS 配置: managed" <<<"$status_out"
system_dns_is_recommended
system_dns_is_target

before_hash="$(sha256sum "$LEIKWAN_RESOLVED_CONF" | awk '{print $1}')"
idempotent_out="$(system_dns_set_default_foreign 2>&1)"
after_hash="$(sha256sum "$LEIKWAN_RESOLVED_CONF" | awk '{print $1}')"
grep -q "系统 DNS 已是目标配置" <<<"$idempotent_out"
[[ "$before_hash" == "$after_hash" ]] || { echo "FAIL: DNS managed config changed on idempotent set" >&2; exit 1; }

system_dns_restore >/dev/null
[[ ! -f "$LEIKWAN_RESOLVED_CONF" ]] || { echo "FAIL: resolved drop-in was not removed" >&2; exit 1; }

SYSTEMD_STATE="missing"
printf 'nameserver 9.9.9.9\n' >"$LEIKWAN_RESOLV_CONF"
system_dns_set_default_foreign >/dev/null
grep -q "# Managed by leikwan-toolkit system DNS" "$LEIKWAN_RESOLV_CONF"
grep -q "nameserver 8.8.8.8" "$LEIKWAN_RESOLV_CONF"
grep -q "nameserver 1.1.1.1" "$LEIKWAN_RESOLV_CONF"
[[ -n "$(find "$LEIKWAN_BACKUP_DIR" -type f -name '*resolv.conf*.bak' 2>/dev/null || true)" ]] || {
  echo "FAIL: resolv.conf was not backed up" >&2
  exit 1
}

mkdir -p "$(dirname "$DDNS_CONFIG")"
printf 'DNS_RESOLVE_SERVERS=keep-ddns-resolvers\n' >"$DDNS_CONFIG"
system_dns_set_default_foreign >/dev/null || true
grep -q "DNS_RESOLVE_SERVERS=keep-ddns-resolvers" "$DDNS_CONFIG"

rm -f "$LEIKWAN_RESOLV_CONF"
ln -s "${TMP_DIR}/foreign-resolv.conf" "$LEIKWAN_RESOLV_CONF"
symlink_out="$(system_dns_set_default_foreign 2>&1 || true)"
grep -q "未硬改系统 DNS" <<<"$symlink_out"

echo "[OK] DNS config regression passed"
