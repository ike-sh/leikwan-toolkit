#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/tests/test-lib.sh"

TMP_DIR="$(test_mktemp_dir "$ROOT_DIR")"
export TMPDIR="$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

export LEIKWAN_STATE_DIR="${TMP_DIR}/state"
export LEIKWAN_BACKUP_DIR="${TMP_DIR}/backups"
export LEIKWAN_RUN_DIR="${TMP_DIR}/run"
export LEIKWAN_LOG_DISABLED=1
export LEIKWAN_NO_CLEAR=1
mkdir -p "$LEIKWAN_RUN_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"
trap - ERR

need_root_unless_dry_run() { :; }
apply_nft_rules() {
  [[ "${1:-}" == "cloud-entry" ]] || return 1
  printf 'applied\n' >"${TMP_DIR}/nft-applied"
  return 0
}
auto_snapshot_or_confirm() { return 0; }

mkdir -p "$ENTRIES_DIR" "$FORWARDS_DIR" "$PBR_DIR" "$OUTPUT_DIR" "$EASYTIER_DIR" "$ENTRY_DIR" "$NFT_DIR"
printf '%s\n' 'RELAY_ET_IP=10.198.1.1' >"$NETWORK_ENV"
printf '%b' '# name\tentry_port\ttarget_host\ttarget_port\tout_iface\troute_table\tenabled\tcomment\nsvc1\t10001\t198.51.100.10\t443\teth0\tT_CN2\ttrue\tmain-rule\nsvc2\t10002\t198.51.100.20\t8443\teth1\t\tfalse\tspare\n' >"$FORWARDS_TSV"
forwards_rows | awk -F'\t' '$7=="true"{f=1} END{exit !f}' || {
  echo "FAIL: fixture forwards.tsv missing enabled row" >&2
  forwards_rows >&2
  exit 1
}

rules="$(build_forward_bundle_rules_tsv "")"
grep -q $'svc1\t10001\t198.51.100.10\t443\ttrue\tmain-rule' <<<"$rules" || {
  echo "FAIL: build_forward_bundle_rules_tsv should export enabled rules only" >&2
  echo "$rules" >&2
  exit 1
}
grep -q 'svc2' <<<"$rules" && {
  echo "FAIL: disabled forward svc2 should not be exported" >&2
  exit 1
}

printf '%s\n' 'ENTRY_MODE=bundle' 'RELAY_ET_IP=10.198.1.1' 'ENABLED=true' >"$ENTRY_EXPOSE_ENV"

nft_content="$(render_nft_cloud 2>/dev/null)"
grep -q 'tcp dport 10001 dnat ip to 10.198.1.1' <<<"$nft_content" || {
  echo "FAIL: bundle render_nft_cloud missing tcp dnat for 10001" >&2
  echo "$nft_content" >&2
  exit 1
}
grep -q 'udp dport 10001 dnat ip to 10.198.1.1' <<<"$nft_content" || {
  echo "FAIL: bundle render_nft_cloud missing udp dnat for 10001" >&2
  exit 1
}
grep -q '10001-19999' <<<"$nft_content" && {
  echo "FAIL: bundle render_nft_cloud should not use port pool range" >&2
  exit 1
}

bundle_rules=$'svc1\t10001\t198.51.100.10\t443\ttrue\tmain-rule'
bundle_b64="$(printf '%s\n' "$bundle_rules" | base64 | tr -d '\n')"
bundle_raw="$(test_mktemp_file "$ROOT_DIR" 'bundle.XXXXXX')"
{
  echo "-----BEGIN LEIKWAN FORWARD BUNDLE-----"
  printf 'FORWARD_BUNDLE_VERSION=0.5\nRELAY_ET_IP=10.198.1.99\nRULE_COUNT=1\nRULES_B64=%s\n' "$bundle_b64"
  echo "-----END LEIKWAN FORWARD BUNDLE-----"
} >"$bundle_raw"

before_forwards="$(cat "$FORWARDS_TSV")"
set +e
printf 'n\ny\n' | import_forward_bundle_apply "$bundle_raw" >/dev/null 2>&1
mismatch_rc=$?
set -e
(( mismatch_rc != 0 )) || {
  echo "FAIL: mismatched RELAY_ET_IP import should abort when user declines" >&2
  exit 1
}
[[ "$(cat "$FORWARDS_TSV")" == "$before_forwards" ]] || {
  echo "FAIL: forwards.tsv changed after declined mismatched relay import" >&2
  exit 1
}

{
  echo "-----BEGIN LEIKWAN FORWARD BUNDLE-----"
  printf 'FORWARD_BUNDLE_VERSION=0.5\nRELAY_ET_IP=10.198.1.1\nRULE_COUNT=1\nRULES_B64=%s\n' "$bundle_b64"
  echo "-----END LEIKWAN FORWARD BUNDLE-----"
} >"$bundle_raw"

rm -f "${TMP_DIR}/nft-applied"
printf 'y\ny\n' | import_forward_bundle_apply "$bundle_raw" >/dev/null
[[ -f "${TMP_DIR}/nft-applied" ]] || {
  echo "FAIL: matched relay import should apply cloud-entry nftables" >&2
  exit 1
}
grep -q 'svc1' "$FORWARDS_TSV" || {
  echo "FAIL: forwards.tsv missing imported svc1" >&2
  exit 1
}
[[ "$(env_file_get "$ENTRY_EXPOSE_ENV" ENTRY_MODE)" == "bundle" ]] || {
  echo "FAIL: expose.env ENTRY_MODE should be bundle after import" >&2
  exit 1
}

grep -q 'forward bundle-export' <(bash leikwan-toolkit.sh --help) || {
  echo "FAIL: --help missing forward bundle-export" >&2
  exit 1
}

printf '%s\n' 'ENTRY_MODE=bundle' 'RELAY_ET_IP=10.198.1.1' 'ENABLED=true' >"$ENTRY_EXPOSE_ENV"
bundle_warn_out="$(warn_if_forward_port_outside_expose 25000 2>&1)"
grep -q '转发接入码模式' <<<"$bundle_warn_out" || {
  echo "FAIL: bundle mode warn_if_forward_port_outside_expose should skip port pool check" >&2
  echo "$bundle_warn_out" >&2
  exit 1
}
grep -q '不在入口端口池' <<<"$bundle_warn_out" && {
  echo "FAIL: bundle mode should not warn about port pool range" >&2
  echo "$bundle_warn_out" >&2
  exit 1
}

bad_rules=$'evil\t25000\t10.0.0.1\t443\ttrue\tok\ninjected\t10003\tbad\thost\t8443\ttrue\tnote'
bad_b64="$(printf '%s\n' "$bad_rules" | base64 | tr -d '\n')"
{
  echo "-----BEGIN LEIKWAN FORWARD BUNDLE-----"
  printf 'FORWARD_BUNDLE_VERSION=0.5\nRELAY_ET_IP=10.198.1.1\nRULE_COUNT=2\nRULES_B64=%s\n' "$bad_b64"
  echo "-----END LEIKWAN FORWARD BUNDLE-----"
} >"$bundle_raw"
set +e
printf 'y\n' | import_forward_bundle_apply "$bundle_raw" >/dev/null 2>&1
bad_import_rc=$?
set -e
(( bad_import_rc != 0 )) || {
  echo "FAIL: bundle import with TAB-injected target_host should be rejected" >&2
  exit 1
}

tab_comment_rules=$'svc3\t10003\t198.51.100.30\t443\ttrue\tbad'"$'\t'"'injected'
tab_b64="$(printf '%s\n' "$tab_comment_rules" | base64 | tr -d '\n')"
{
  echo "-----BEGIN LEIKWAN FORWARD BUNDLE-----"
  printf 'FORWARD_BUNDLE_VERSION=0.5\nRELAY_ET_IP=10.198.1.1\nRULE_COUNT=1\nRULES_B64=%s\n' "$tab_b64"
  echo "-----END LEIKWAN FORWARD BUNDLE-----"
} >"$bundle_raw"
rm -f "${TMP_DIR}/nft-applied"
printf 'y\n' | import_forward_bundle_apply "$bundle_raw" >/dev/null
grep -q 'svc3' "$FORWARDS_TSV" || {
  echo "FAIL: sanitized comment import missing svc3" >&2
  exit 1
}
grep -Fq $'bad\tinjected' "$FORWARDS_TSV" && {
  echo "FAIL: comment TAB injection was not sanitized in forwards.tsv" >&2
  cat "$FORWARDS_TSV" >&2
  exit 1
}

rm -f "$ENTRY_EXPOSE_ENV"
printf '%s\n' 'ROLE=leikwan-relay' 'RELAY_ET_IP=10.198.1.1' >"$NETWORK_ENV"
relay_warn_out="$(warn_if_forward_port_outside_expose 25000 2>&1)"
grep -q '利群主机侧' <<<"$relay_warn_out" || {
  echo "FAIL: relay role should skip default port pool warning" >&2
  echo "$relay_warn_out" >&2
  exit 1
}
grep -q '不在默认推荐范围' <<<"$relay_warn_out" && {
  echo "FAIL: relay role should not warn about default port pool" >&2
  echo "$relay_warn_out" >&2
  exit 1
}

dup_rules=$'dup-a\t10005\t198.51.100.40\t443\ttrue\tone\ndup-b\t10005\t198.51.100.41\t8443\ttrue\ttwo'
dup_b64="$(printf '%s\n' "$dup_rules" | base64 | tr -d '\n')"
{
  echo "-----BEGIN LEIKWAN FORWARD BUNDLE-----"
  printf 'FORWARD_BUNDLE_VERSION=0.5\nRELAY_ET_IP=10.198.1.1\nRULE_COUNT=2\nRULES_B64=%s\n' "$dup_b64"
  echo "-----END LEIKWAN FORWARD BUNDLE-----"
} >"$bundle_raw"
set +e
printf 'y\n' | import_forward_bundle_apply "$bundle_raw" >/dev/null 2>&1
dup_rc=$?
set -e
(( dup_rc != 0 )) || {
  echo "FAIL: duplicate entry_port bundle import should be rejected" >&2
  exit 1
}

bad_enabled_rules=$'svc4\t10004\t198.51.100.50\t443\tmaybe\tnote'
bad_enabled_b64="$(printf '%s\n' "$bad_enabled_rules" | base64 | tr -d '\n')"
{
  echo "-----BEGIN LEIKWAN FORWARD BUNDLE-----"
  printf 'FORWARD_BUNDLE_VERSION=0.5\nRELAY_ET_IP=10.198.1.1\nRULE_COUNT=1\nRULES_B64=%s\n' "$bad_enabled_b64"
  echo "-----END LEIKWAN FORWARD BUNDLE-----"
} >"$bundle_raw"
set +e
printf 'y\n' | import_forward_bundle_apply "$bundle_raw" >/dev/null 2>&1
bad_enabled_rc=$?
set -e
(( bad_enabled_rc != 0 )) || {
  echo "FAIL: invalid enabled value should be rejected" >&2
  exit 1
}

{
  echo "-----BEGIN LEIKWAN FORWARD BUNDLE-----"
  printf 'FORWARD_BUNDLE_VERSION=0.5\nRELAY_ET_IP=10.198.1.1\nRULE_COUNT=9\nRULES_B64=%s\n' "$bundle_b64"
  echo "-----END LEIKWAN FORWARD BUNDLE-----"
} >"$bundle_raw"
set +e
printf 'y\n' | import_forward_bundle_apply "$bundle_raw" >/dev/null 2>&1
count_rc=$?
set -e
(( count_rc != 0 )) || {
  echo "FAIL: RULE_COUNT mismatch should be rejected" >&2
  exit 1
}

printf '%s\n' 'ROLE=cloud-entry' >"$NETWORK_ENV"
set +e
printf 'n\n' | import_forward_bundle_apply "$bundle_raw" >/dev/null 2>&1
no_relay_rc=$?
set -e
(( no_relay_rc != 0 )) || {
  echo "FAIL: import without local relay IP should abort when user declines" >&2
  exit 1
}
printf '%s\n' 'ROLE=cloud-entry' 'EASYTIER_RELAY_ET_IP=10.198.1.1' >"$NETWORK_ENV"

printf '%s\n' 'ENTRY_MODE=bundle' 'RELAY_ET_IP=10.198.1.1' 'ENABLED=true' >"$ENTRY_EXPOSE_ENV"
printf 'n\n' | entry_expose_range --range 10000-19999 --relay-ip 10.198.1.1 --no-apply >/dev/null 2>&1
[[ "$(env_file_get "$ENTRY_EXPOSE_ENV" ENTRY_MODE)" == "bundle" ]] || {
  echo "FAIL: declined port pool switch should keep bundle expose.env" >&2
  exit 1
}
grep -q 'ENTRY_EXPOSE_START' "$ENTRY_EXPOSE_ENV" && {
  echo "FAIL: declined port pool switch should not write port pool fields" >&2
  cat "$ENTRY_EXPOSE_ENV" >&2
  exit 1
}

echo "[OK] forward bundle regression passed"
