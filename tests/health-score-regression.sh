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
export LEIKWAN_NO_CLEAR=1
mkdir -p "$LEIKWAN_RUN_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

[[ "$(health_level 96)" == "excellent" ]] || { echo "FAIL: health 96 should be excellent" >&2; exit 1; }
[[ "$(health_level 80)" == "good" ]] || { echo "FAIL: health 80 should be good" >&2; exit 1; }
[[ "$(health_level 55)" == "warning" ]] || { echo "FAIL: health 55 should be warning" >&2; exit 1; }
[[ "$(health_level 20)" == "critical" ]] || { echo "FAIL: health 20 should be critical" >&2; exit 1; }

json_out="$(bash leikwan-toolkit.sh status --json 2>&1)"
grep -q '"health_score"' <<<"$json_out"
grep -q '"health_level"' <<<"$json_out"
score="$(sed -n 's/.*"health_score": \([0-9][0-9]*\).*/\1/p' <<<"$json_out" | head -1)"
[[ -n "$score" ]] || { echo "FAIL: health_score missing from JSON" >&2; echo "$json_out" >&2; exit 1; }
(( score >= 0 && score <= 100 )) || { echo "FAIL: health_score out of range: ${score}" >&2; exit 1; }

brief_out="$(bash leikwan-toolkit.sh --brief 2>&1)"
grep -Eq 'Health: [0-9]+/100 \((excellent|good|warning|critical)\)' <<<"$brief_out" || {
  echo "FAIL: brief health line missing" >&2
  echo "$brief_out" >&2
  exit 1
}

echo "[OK] health score regression passed"
