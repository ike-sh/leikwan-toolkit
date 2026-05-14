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

state_file_manifest() {
  find "$LEIKWAN_STATE_DIR" -type f -print 2>/dev/null | sort | while IFS= read -r file; do
    size="$(wc -c <"$file" 2>/dev/null || printf '0')"
    printf '%s %s\n' "${file#"$LEIKWAN_STATE_DIR"/}" "$size"
  done
}

mkdir -p "$ENTRIES_DIR" "$ENTRY_DIR" "$STATUS_DIR"
cat >"$ENTRIES_TSV" <<'EOF'
# entry_name	public_host	et_ip	easytier_protocol	easytier_port	weight	enabled
public2	home.example.test	10.198.1.4	tcp,udp	8303	100	true
EOF
cat >"$RESOLVED_ENTRIES_TSV" <<'EOF'
# name	public_host	resolved_ip	last_checked	last_changed
public2	home.example.test	198.51.100.10	2026-05-11 12:00:00	2026-05-11 12:00:00
EOF
entry_ddns_write_config true home.example.test custom-url "" "" "" "" 5min last
cat >"$ENTRY_DDNS_STATUS_FILE" <<'EOF'
LAST_ENTRY_DDNS_TIME=2026-05-11 12:00:00
LAST_ENTRY_DDNS_RESULT=ok
LAST_ENTRY_DDNS_HOST=home.example.test
LAST_ENTRY_DDNS_PUBLIC_IP=198.51.100.10
LAST_ENTRY_DDNS_RESOLVED_IP=198.51.100.10
LAST_ENTRY_DDNS_CHANGED=false
LAST_ENTRY_DDNS_PROVIDER=custom-url
LAST_ENTRY_DDNS_VERSION=1.4.1
EOF

resolve_ipv4_first() { printf '%s' "198.51.100.10"; }

before="$(state_file_manifest)"
out="$(ddns_check_consistency)"
after="$(state_file_manifest)"

grep -q "DDNS / 域名解析一致性检查" <<<"$out"
grep -q "public2 home.example.test resolved=198.51.100.10 cache=198.51.100.10 OK" <<<"$out"
grep -q "host=home.example.test" <<<"$out"
grep -q "match=OK" <<<"$out"
grep -q "结果: OK" <<<"$out"
[[ "$before" == "$after" ]] || {
  echo "FAIL: ddns check-consistency modified state" >&2
  diff -u <(printf '%s\n' "$before") <(printf '%s\n' "$after") >&2 || true
  exit 1
}

empty_out="$(LEIKWAN_STATE_DIR="${TMP_DIR}/empty" LEIKWAN_RUN_DIR="${TMP_DIR}/run2" LEIKWAN_LOG_DISABLED=1 bash leikwan-toolkit.sh ddns check-consistency 2>&1)"
grep -q "公网入口缓存:" <<<"$empty_out"
grep -q "未配置" <<<"$empty_out"
grep -q "兼容 DNS 更新配置:" <<<"$empty_out"
if grep -q "错误：脚本在第" <<<"$empty_out"; then
  echo "FAIL: ddns check-consistency triggered global trap" >&2
  echo "$empty_out" >&2
  exit 1
fi

echo "[OK] ddns consistency regression passed"
