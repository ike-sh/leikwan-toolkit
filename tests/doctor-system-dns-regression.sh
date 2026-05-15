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
export LEIKWAN_RESOLVED_CONF="${TMP_DIR}/resolved.conf.d/99-leikwan-dns.conf"
export LEIKWAN_RESOLV_CONF="${TMP_DIR}/resolv.conf"
mkdir -p "$LEIKWAN_RUN_DIR" "$(dirname "$LEIKWAN_RESOLVED_CONF")"

cat >"$LEIKWAN_RESOLVED_CONF" <<'EOF'
[Resolve]
DNS=8.8.8.8 1.1.1.1
FallbackDNS=8.8.4.4 1.0.0.1
LLMNR=no
MulticastDNS=no
EOF
printf 'nameserver 127.0.0.53\n' >"$LEIKWAN_RESOLV_CONF"
cat >"$LEIKWAN_GAI_CONF" <<'EOF'
# BEGIN LEIKWAN IPV4 PREFER
precedence ::ffff:0:0/96  100
# END LEIKWAN IPV4 PREFER
EOF

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

systemctl() {
  case "$*" in
    "is-active --quiet systemd-resolved") return 0 ;;
    "list-unit-files --no-legend systemd-resolved.service") echo "systemd-resolved.service enabled"; return 0 ;;
    *) return 0 ;;
  esac
}
sysctl() {
  case "$*" in
    "-n net.ipv4.tcp_congestion_control") echo "bbr" ;;
    "-n net.core.default_qdisc") echo "fq" ;;
    *) return 1 ;;
  esac
}
dnsutils_auto_install() { :; }
doctor_dependency_tools() { :; }
doctor_fake_ip_dns() { :; }
doctor_apt_sources() { :; }
detect_role() { printf 'unknown'; }
report_ddns_global_state() { :; }
doctor_print_summary() { :; }
write_status_cache() { :; }

status_out="$(system_dns_status)"
grep -q "系统 DNS: 8.8.8.8,1.1.1.1" <<<"$status_out"
grep -q "Fallback DNS: 8.8.4.4,1.0.0.1" <<<"$status_out"

doctor_out="$(doctor 2>&1 || true)"
grep -q "系统 DNS 已使用 Leikwan 推荐国外 DNS" <<<"$doctor_out"
if grep -q "当前系统 DNS 非 Leikwan 推荐国外 DNS" <<<"$doctor_out"; then
  echo "FAIL: doctor misjudged managed recommended system DNS" >&2
  echo "$doctor_out" >&2
  exit 1
fi

grep -q "DNS=8.8.8.8 1.1.1.1" "$LEIKWAN_RESOLVED_CONF"
grep -q "FallbackDNS=8.8.4.4 1.0.0.1" "$LEIKWAN_RESOLVED_CONF"

cat >"$LEIKWAN_RESOLVED_CONF" <<'EOF'
[Resolve]
DNS=8.8.8.8 1.1.1.1 8.8.4.4
FallbackDNS=9.9.9.9 223.5.5.5
LLMNR=no
MulticastDNS=no
EOF

legacy_status="$(system_dns_status 2>&1)"
grep -q "DNS 配置: managed-legacy" <<<"$legacy_status"
legacy_doctor_out="$(doctor 2>&1 || true)"
grep -q "检测到旧版 Leikwan DNS 配置" <<<"$legacy_doctor_out"
if grep -q "当前系统 DNS 非 Leikwan 推荐国外 DNS" <<<"$legacy_doctor_out"; then
  echo "FAIL: doctor should report legacy managed DNS instead of generic non-target DNS" >&2
  echo "$legacy_doctor_out" >&2
  exit 1
fi

echo "[OK] doctor system DNS regression passed"
