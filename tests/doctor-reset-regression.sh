#!/usr/bin/env bash
# shellcheck disable=SC2034
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
mkdir -p "$LEIKWAN_RUN_DIR" "${LEIKWAN_STATE_DIR}/status"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

REPORT_WARN_COUNT=7
REPORT_FAIL_COUNT=3
DOCTOR_SUMMARY_OVERALL="FAIL"
DOCTOR_SUMMARY_WARNINGS=7
DOCTOR_SUMMARY_FAILURES=3
STATUS_OVERVIEW_RESULT="fail"
cat >"${STATUS_DIR}/last-doctor.env" <<'EOF'
LAST_DOCTOR_TIME=2026-05-11 12:00:00
LAST_DOCTOR_RESULT=fail
LAST_DOCTOR_VERSION=1.4.0
EOF

doctor_reset_state
[[ "$REPORT_WARN_COUNT" == "0" ]] || { echo "FAIL: warn count was not reset" >&2; exit 1; }
[[ "$REPORT_FAIL_COUNT" == "0" ]] || { echo "FAIL: fail count was not reset" >&2; exit 1; }
[[ -z "$DOCTOR_SUMMARY_OVERALL" ]] || { echo "FAIL: summary cache was not reset" >&2; exit 1; }
[[ "$STATUS_OVERVIEW_RESULT" == "ok" ]] || { echo "FAIL: status aggregate was not reset" >&2; exit 1; }

report WARN "temporary warning" >/dev/null
[[ "$REPORT_WARN_COUNT" == "1" ]] || { echo "FAIL: report did not increment warning" >&2; exit 1; }
doctor_reset_state
[[ "$REPORT_WARN_COUNT" == "0" && "$REPORT_FAIL_COUNT" == "0" ]] || {
  echo "FAIL: second reset retained transient state" >&2
  exit 1
}

summary="$(LEIKWAN_BRIEF=1 doctor 2>&1 || true)"
grep -q "诊断结果摘要" <<<"$summary" || { echo "FAIL: doctor summary missing after reset" >&2; echo "$summary" >&2; exit 1; }
if grep -q "LAST_DOCTOR_RESULT=fail" <<<"$summary"; then
  echo "FAIL: doctor output inherited last-doctor.env" >&2
  echo "$summary" >&2
  exit 1
fi

echo "[OK] doctor reset regression passed"
