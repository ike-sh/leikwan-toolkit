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
trap - ERR

capture_prompt() {
  local input="$1" prompt="$2" default="$3" out rc
  set +e
  out="$(printf '%b' "$input" | prompt_yes_no "$prompt" "$default" 2>&1)"
  rc=$?
  set -e
  printf '%s\n' "$rc" >"${TMP_DIR}/prompt.rc"
  printf '%s' "$out" >"${TMP_DIR}/prompt.out"
}

capture_prompt '\n' "是否继续前台执行？" "Y"
[[ "$(cat "${TMP_DIR}/prompt.rc")" == "0" ]]
if grep -q "请输入 y 或 n" "${TMP_DIR}/prompt.out"; then
  echo "FAIL: [Y/n] blank input was treated as invalid" >&2
  cat "${TMP_DIR}/prompt.out" >&2
  exit 1
fi

capture_prompt '\n' "是否继续？" "N"
[[ "$(cat "${TMP_DIR}/prompt.rc")" == "1" ]]
if grep -q "请输入 y 或 n" "${TMP_DIR}/prompt.out"; then
  echo "FAIL: [y/N] blank input was treated as invalid" >&2
  cat "${TMP_DIR}/prompt.out" >&2
  exit 1
fi

capture_prompt 'Y\n' "是否应用 nftables？" "N"
[[ "$(cat "${TMP_DIR}/prompt.rc")" == "0" ]]

capture_prompt 'n\n' "是否应用 nftables？" "Y"
[[ "$(cat "${TMP_DIR}/prompt.rc")" == "1" ]]

capture_prompt '\n' "是否继续前台执行？" "yes"
[[ "$(cat "${TMP_DIR}/prompt.rc")" == "0" ]]

grep -q 'prompt_yes_no "是否继续前台执行？" "Y"' leikwan-toolkit.sh

echo "[OK] confirm default regression passed"
