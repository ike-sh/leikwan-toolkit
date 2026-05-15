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
export LEIKWAN_RESOLVED_CONF="${TMP_DIR}/resolved.conf.d/99-leikwan-dns.conf"
export LEIKWAN_IPV6_DISABLE_CONF="${TMP_DIR}/sysctl.d/99-leikwan-disable-ipv6.conf"
export LEIKWAN_PROC_IPV6_CONF_DIR="${TMP_DIR}/proc/sys/net/ipv6/conf"
export LEIKWAN_IPV6_NFT_SERVICE="${TMP_DIR}/leikwan-ipv6-lockdown.service"
mkdir -p "$LEIKWAN_RUN_DIR" "$LEIKWAN_PROC_IPV6_CONF_DIR"/{all,default,lo}
printf 'nameserver 9.9.9.9\n' >"$LEIKWAN_RESOLV_CONF"
printf '0\n' >"$LEIKWAN_PROC_IPV6_CONF_DIR/all/disable_ipv6"
printf '0\n' >"$LEIKWAN_PROC_IPV6_CONF_DIR/default/disable_ipv6"
printf '0\n' >"$LEIKWAN_PROC_IPV6_CONF_DIR/lo/disable_ipv6"

run_cli() {
  bash "$ROOT_DIR/leikwan-toolkit.sh" --dry-run "$@" >/dev/null
}

run_cli system network status
run_cli system network prepare
run_cli system ipv4-prefer status
run_cli system ipv4-prefer enable
run_cli system ipv4-prefer disable
run_cli system dns status
run_cli system dns set 8.8.8.8,1.1.1.1
run_cli system dns restore
run_cli system ipv6 status
run_cli system ipv6 disable
run_cli system ipv6 restore
run_cli system ipv6 lockdown
run_cli system bbr status
run_cli system bbr enable
run_cli system bbr restore

help_out="$(bash "$ROOT_DIR/leikwan-toolkit.sh" --help)"
grep -q "system network status" <<<"$help_out"
grep -q "system dns status" <<<"$help_out"
grep -q "system ipv6 status" <<<"$help_out"

echo "[OK] system network CLI regression passed"
