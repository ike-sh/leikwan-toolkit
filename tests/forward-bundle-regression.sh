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

echo "[OK] forward bundle regression passed"
