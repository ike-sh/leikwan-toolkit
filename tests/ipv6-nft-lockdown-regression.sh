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
export LEIKWAN_IPV6_NFT_SERVICE="${TMP_DIR}/leikwan-ipv6-lockdown.service"
mkdir -p "$LEIKWAN_RUN_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

need_root_unless_dry_run() { :; }
install_packages() { :; }
nft() {
  case "$*" in
    "-f "*|"list table inet leikwan_ipv6_lockdown") return 0 ;;
    *) return 0 ;;
  esac
}
systemctl() { return 0; }

out="$(ipv6_nft_lockdown 2>&1)"
grep -q "IPv6 入站收口 nftables 已应用" <<<"$out"
grep -q "这不是禁用 IPv6" <<<"$out"

grep -q "table inet leikwan_ipv6_lockdown" "$IPV6_NFT_LOCK_FILE"
grep -q "ip6 nexthdr ipv6-icmp accept" "$IPV6_NFT_LOCK_FILE"
grep -q "iif lo accept" "$IPV6_NFT_LOCK_FILE"
grep -q "ct state established,related accept" "$IPV6_NFT_LOCK_FILE"
grep -q "tcp dport 22 accept" "$IPV6_NFT_LOCK_FILE"
grep -q "meta nfproto ipv6 drop" "$IPV6_NFT_LOCK_FILE"

old_cmd_a='ip6''tables'
old_cmd_b='iptables''-persistent'
old_cmd_c='rules.''v6'
old_cmd_d='V6_''LOCKDOWN'
if declare -f ipv6_nft_lockdown | grep -Eq "${old_cmd_a}|${old_cmd_b}|${old_cmd_c}|${old_cmd_d}"; then
  echo "FAIL: IPv6 lockdown still contains legacy command path" >&2
  exit 1
fi

echo "[OK] IPv6 nft lockdown regression passed"
