#!/usr/bin/env bash
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
mkdir -p "$ENTRIES_DIR"

cat >"$ENTRIES_TSV" <<'EOF'
# entry_name	public_host	et_ip	easytier_protocol	easytier_port	weight	enabled
public3	home.example.test	10.198.1.4	tcp,udp	8303	100	true
EOF

ddns_timer_state() { printf 'active'; }
ddns_config_value() {
  case "$1" in
    DDNS_GLOBAL_ENABLED) printf 'true' ;;
    *) printf '%s' "${2:-}" ;;
  esac
}
command() {
  if [[ "${1:-}" == "-v" && "${2:-}" == "dig" ]]; then
    return 1
  fi
  builtin command "$@"
}
install_packages() {
  printf '[MOCK] apt-get update\n'
  printf '[MOCK] apt-get install -y %s\n' "$*"
  return 0
}

LQ_AUTO_FIX_INSTALL_DNSUTILS=true
out="$(doctor_auto_fix_dnsutils 2>&1)"
grep -q "\[MOCK\] apt-get install -y dnsutils" <<<"$out"
grep -q "dnsutils 已安装" <<<"$out"

echo "[OK] doctor autofix dnsutils regression passed"
