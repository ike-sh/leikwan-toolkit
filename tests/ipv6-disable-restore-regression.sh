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
export LEIKWAN_IPV6_DISABLE_CONF="${TMP_DIR}/sysctl.d/99-leikwan-disable-ipv6.conf"
export LEIKWAN_PROC_IPV6_CONF_DIR="${TMP_DIR}/proc/sys/net/ipv6/conf"
export LEIKWAN_SYSCTL_DIRS="${TMP_DIR}/sysctl.d"
mkdir -p "$LEIKWAN_RUN_DIR" "$LEIKWAN_PROC_IPV6_CONF_DIR"/{all,default,lo} "$TMP_DIR/sysctl.d"
printf '0\n' >"$LEIKWAN_PROC_IPV6_CONF_DIR/all/disable_ipv6"
printf '0\n' >"$LEIKWAN_PROC_IPV6_CONF_DIR/default/disable_ipv6"
printf '0\n' >"$LEIKWAN_PROC_IPV6_CONF_DIR/lo/disable_ipv6"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

need_root_unless_dry_run() { :; }
sysctl() {
  case "${1:-}" in
    -p)
      printf '1\n' >"$LEIKWAN_PROC_IPV6_CONF_DIR/all/disable_ipv6"
      printf '1\n' >"$LEIKWAN_PROC_IPV6_CONF_DIR/default/disable_ipv6"
      printf '1\n' >"$LEIKWAN_PROC_IPV6_CONF_DIR/lo/disable_ipv6"
      ;;
    -w)
      shift
      local item value scope
      for item in "$@"; do
        value="${item##*=}"
        scope="${item#net.ipv6.conf.}"
        scope="${scope%%.disable_ipv6=*}"
        [[ -d "$LEIKWAN_PROC_IPV6_CONF_DIR/$scope" ]] && printf '%s\n' "$value" >"$LEIKWAN_PROC_IPV6_CONF_DIR/$scope/disable_ipv6"
      done
      ;;
    --system) return 0 ;;
  esac
}

printf 'net.ipv6.conf.all.disable_ipv6=0\n' >"${TMP_DIR}/sysctl.d/10-user.conf"
out="$(system_ipv6_disable 2>&1)"
grep -q "disable_ipv6=0" <<<"$out"
grep -q "IPv6 已禁用" <<<"$out"
grep -q "net.ipv6.conf.all.disable_ipv6=1" "$LEIKWAN_IPV6_DISABLE_CONF"
grep -q "net.ipv6.conf.default.disable_ipv6=1" "$LEIKWAN_IPV6_DISABLE_CONF"
grep -q "net.ipv6.conf.lo.disable_ipv6=1" "$LEIKWAN_IPV6_DISABLE_CONF"

status_out="$(system_ipv6_status)"
grep -q "IPv6: disabled" <<<"$status_out"
grep -q "IPv6 配置: managed" <<<"$status_out"

restore_out="$(system_ipv6_restore 2>&1)"
grep -q "IPv6 已恢复" <<<"$restore_out"
[[ ! -f "$LEIKWAN_IPV6_DISABLE_CONF" ]] || { echo "FAIL: IPv6 managed sysctl file still exists" >&2; exit 1; }
grep -q '^0$' "$LEIKWAN_PROC_IPV6_CONF_DIR/all/disable_ipv6"
grep -q '^0$' "$LEIKWAN_PROC_IPV6_CONF_DIR/default/disable_ipv6"
grep -q '^0$' "$LEIKWAN_PROC_IPV6_CONF_DIR/lo/disable_ipv6"

echo "[OK] IPv6 disable / restore regression passed"
