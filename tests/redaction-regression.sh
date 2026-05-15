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
mkdir -p "$LEIKWAN_RUN_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

fixture="${TMP_DIR}/redact-tree"
mkdir -p "$fixture/status" "$fixture/ddns" "$fixture/update" "$fixture/outputs" "$fixture/debug" "$fixture/entry" "$fixture/logs"
secret_value="abc123456789"
base64_value="QUJDREVGR0hJSktMTU5PUA=="
token_value="token-value-12345"
password_value="password-value-12345"
{
  printf '%s=%s\n' "EASYTIER_NETWORK_SECRET" "$secret_value"
  printf '%s=%s\n' "LEIKWAN_EASYTIER_NETWORK_BASE64" "$base64_value"
  printf '%s=%s\n' "PAIRING_CODE_BASE64" "$base64_value"
  printf '%s=%s\n' "token" "$token_value"
  printf '%s=%s\n' "password" "$password_value"
} >"${fixture}/status/last-config-export.env"
cp "${fixture}/status/last-config-export.env" "${fixture}/ddns/last-ddns.env"
cp "${fixture}/status/last-config-export.env" "${fixture}/update/last-update.env"
cp "${fixture}/status/last-config-export.env" "${fixture}/outputs/forward-endpoints.json"
cp "${fixture}/status/last-config-export.env" "${fixture}/debug/leikwan-debug-report.txt"
{
  printf 'ENTRY_DDNS_UPDATE_URL=https://ddns.example.test/update?%s=%s&domain={host}&ip={ip}\n' "token" "$token_value"
  printf 'ENTRY_DDNS_UPDATE_CMD=/usr/local/bin/update-ddns --%s %s {host} {ip}\n' "token" "$token_value"
} >"${fixture}/entry/ddns.env"
cp "${fixture}/entry/ddns.env" "${fixture}/logs/leikwan-entry-ddns.log"

config_sensitive_redact_tree "$fixture"
for value in "$secret_value" "$base64_value" "$token_value" "$password_value"; do
  if grep -R -- "$value" "$fixture"; then
    echo "FAIL: redaction leaked value: ${value}" >&2
    exit 1
  fi
done
grep -R "REDACTED" "$fixture" >/dev/null

mkdir -p "$EASYTIER_DIR"
cat >"$NETWORK_ENV" <<EOF
ROLE=leikwan-relay
EASYTIER_NETWORK_NAME=test-net
EASYTIER_NETWORK_SECRET=${secret_value}
EOF
status_json="$(bash leikwan-toolkit.sh status --json 2>&1)"
doctor_json="$(bash leikwan-toolkit.sh doctor --json 2>&1)"
if grep -q "$secret_value" <<<"${status_json}${doctor_json}"; then
  echo "FAIL: JSON status/doctor leaked EasyTier secret" >&2
  exit 1
fi
if grep -Eq 'EASYTIER_NETWORK_SECRET|PAIRING_CODE_BASE64|LEIKWAN_[A-Z0-9_]*_BASE64|password=|token=' <<<"${status_json}${doctor_json}"; then
  echo "FAIL: JSON status/doctor leaked sensitive marker" >&2
  exit 1
fi

mkdir -p "$ENTRIES_DIR" "$FORWARDS_DIR" "$PBR_DIR" "$OUTPUT_DIR"
cat >"$ENTRIES_TSV" <<'EOF'
# entry_name	public_host	et_ip	easytier_protocol	easytier_port	weight	enabled
public1	edge.example.test"><script>alert(1)</script>	10.198.1.2	tcp,udp	8301	100	true
EOF
cat >"$FORWARDS_TSV" <<'EOF'
# name	entry_port	target_host	target_port	out_iface	route_table	enabled	comment
hk<script>alert(1)</script>	10001	198.51.100.10	443	eth0	T_CN2	true	<script>alert(1)</script>
EOF

generate_forward_outputs 1 >/dev/null
err_trap="$(trap -p ERR || true)"
trap - ERR
set +e
json_pretty="${TMP_DIR}/forward-endpoints.pretty.json"
json_err_file="${TMP_DIR}/forward-endpoints.json.err"
if command -v jq >/dev/null 2>&1; then
  jq . <"$FORWARD_JSON" >"$json_pretty" 2>"$json_err_file"
  json_rc=$?
elif command -v node >/dev/null 2>&1; then
  node -e 'const fs=require("fs"); JSON.parse(fs.readFileSync(0,"utf8"));' <"$FORWARD_JSON" >"$json_pretty" 2>"$json_err_file"
  json_rc=$?
else
  printf '%s\n' "missing jq or node" >"$json_err_file"
  json_rc=1
fi
json_error="$(cat "$json_err_file")"
set -e
[[ -n "$err_trap" ]] && eval "$err_trap"
if (( json_rc != 0 )); then
  echo "FAIL: endpoint JSON is invalid" >&2
  echo "$json_error" >&2
  sed -n '1,120p' "$FORWARD_JSON" >&2
  exit 1
fi

if grep -q '<script>alert(1)</script>' "$FORWARD_HTML"; then
  echo "FAIL: HTML output contains unescaped script tag" >&2
  exit 1
fi
grep -q '&lt;script&gt;alert(1)&lt;/script&gt;' "$FORWARD_HTML"

if grep -R -E 'EASYTIER_NETWORK_SECRET|PAIRING_CODE_BASE64|LEIKWAN_[A-Z0-9_]*_BASE64|password=|token=' "$OUTPUT_DIR"; then
  echo "FAIL: endpoint outputs leaked sensitive markers" >&2
  exit 1
fi

qr_out="$(output_qr 2>&1 || true)"
if ! command -v qrencode >/dev/null 2>&1; then
  grep -q "未安�?qrencode" <<<"$qr_out"
fi

printf 'bad\n' >"${TMP_DIR}/evil-source"
tar -czf "${TMP_DIR}/evil-dotdot.tar.gz" -C "$TMP_DIR" --transform='s#evil-source#../../evil#' evil-source
tar --absolute-names -czf "${TMP_DIR}/evil-absolute.tar.gz" -C "$TMP_DIR" --transform='s#evil-source#/etc/passwd#' evil-source
evil_packages=("${TMP_DIR}/evil-dotdot.tar.gz" "${TMP_DIR}/evil-absolute.tar.gz")
if ln -s /root/.ssh/authorized_keys "${TMP_DIR}/evil-link" 2>/dev/null; then
  tar -czf "${TMP_DIR}/evil-symlink.tar.gz" -C "$TMP_DIR" evil-link
  evil_packages+=("${TMP_DIR}/evil-symlink.tar.gz")
else
  echo "[INFO] 当前文件系统不支持创�?symlink，跳�?symlink tar 构造�?
fi

for evil in "${evil_packages[@]}"; do
  err_trap="$(trap -p ERR || true)"
  trap - ERR
  set +e
  inspect_out="$(bash leikwan-toolkit.sh config inspect "$evil" 2>&1)"
  inspect_rc=$?
  import_out="$(bash leikwan-toolkit.sh --dry-run config import "$evil" 2>&1)"
  import_rc=$?
  set -e
  [[ -n "$err_trap" ]] && eval "$err_trap"
  (( inspect_rc != 0 )) || { echo "FAIL: evil package inspect succeeded: ${evil}" >&2; exit 1; }
  (( import_rc != 0 )) || { echo "FAIL: evil package import succeeded: ${evil}" >&2; exit 1; }
  grep -Eq "不安全路径|symlink|hardlink|拒绝|不是有效" <<<"${inspect_out}${import_out}" || {
    echo "FAIL: evil package was not rejected clearly: ${evil}" >&2
    echo "$inspect_out" >&2
    echo "$import_out" >&2
    exit 1
  }
  if grep -q "错误：脚本在�? <<<"${inspect_out}${import_out}"; then
    echo "FAIL: global trap triggered for evil package: ${evil}" >&2
    exit 1
  fi
done

bash scripts/check-redaction.sh

echo "[OK] redaction regression passed"
