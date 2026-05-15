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

brief_out="$(bash leikwan-toolkit.sh --brief 2>&1)"
grep -q "Leikwan Status" <<<"$brief_out"
grep -q "Role:" <<<"$brief_out"
grep -q "Health:" <<<"$brief_out"
if grep -q "下一步建�? <<<"$brief_out"; then
  echo "FAIL: brief status printed full next-step section" >&2
  echo "$brief_out" >&2
  exit 1
fi

status_out="$(LEIKWAN_BRIEF=1 bash leikwan-toolkit.sh status 2>&1)"
grep -q "Leikwan Status" <<<"$status_out"

doctor_out="$(LEIKWAN_BRIEF=1 bash leikwan-toolkit.sh --doctor 2>&1)"
grep -q "诊断结果摘要" <<<"$doctor_out"
if grep -Eq '^\[INFO\]|^\[OK\]' <<<"$doctor_out"; then
  echo "FAIL: brief doctor printed OK/INFO detail lines" >&2
  echo "$doctor_out" >&2
  exit 1
fi

json_out="$(LEIKWAN_BRIEF=1 bash leikwan-toolkit.sh status --json 2>&1)"
grep -q '"health_score"' <<<"$json_out"
if command -v jq >/dev/null 2>&1; then
  jq . >/dev/null <<<"$json_out"
elif command -v node >/dev/null 2>&1; then
  node -e 'const fs=require("fs"); JSON.parse(fs.readFileSync(0,"utf8"));' >/dev/null <<<"$json_out"
fi

echo "[OK] compact output regression passed"
