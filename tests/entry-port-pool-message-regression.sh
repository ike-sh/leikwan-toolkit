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
mkdir -p "$LEIKWAN_RUN_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

need_root_unless_dry_run() { :; }
ss() {
  case "$1" in
    -lntH) printf 'LISTEN 0 128 0.0.0.0:15888 0.0.0.0:*\n' ;;
    -lunH) printf 'UNCONN 0 0 0.0.0.0:15889 0.0.0.0:*\n' ;;
    *) return 1 ;;
  esac
}
apply_nft_rules() {
  [[ "${1:-}" == "cloud-entry" ]] || return 1
  printf 'applied\n' >"${TMP_DIR}/applied"
  ok "公网入口端口池 nftables 规则已应用。"
}

out="$(printf 'y\ny\n' | entry_expose_range --range 10000-19999 --relay-ip 10.198.1.1 2>&1)"

old_six="第 6"; old_six="${old_six} 项"
old_seven="第 7"; old_seven="${old_seven} 项"
old_choose="选择"; old_choose="${old_choose}第"
if grep -Eq "${old_six}|${old_seven}|${old_choose}" <<<"$out"; then
  echo "FAIL: entry port pool prompt still contains fixed menu number" >&2
  echo "$out" >&2
  exit 1
fi

grep -q "利群主机 B" <<<"$out"
grep -q "PBR / 出口策略" <<<"$out"
grep -Eq "后端转发目标|转发管理" <<<"$out"
grep -q "DNAT 接管" <<<"$out"
grep -q "本机原服务可能无法从公网访问" <<<"$out"
grep -q "10000-15887" <<<"$out"
grep -q "15889-19999" <<<"$out"
grep -q "公网入口端口池 nftables 规则已应用" <<<"$out"
[[ -f "${TMP_DIR}/applied" ]] || { echo "FAIL: user chose continue but nftables apply was not called" >&2; exit 1; }

fn="$(declare -f entry_expose_range)"
if grep -Eq "${old_six}|${old_seven}|${old_choose}" <<<"$fn"; then
  echo "FAIL: entry_expose_range contains fixed menu number" >&2
  exit 1
fi

echo "[OK] entry port pool message regression passed"
