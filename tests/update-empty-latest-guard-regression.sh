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
export LEIKWAN_UPDATE_TARGET_SCRIPT="${TMP_DIR}/leikwan-toolkit.sh"
export LEIKWAN_LOG_DISABLED=1
export LEIKWAN_NO_CLEAR=1
mkdir -p "$LEIKWAN_RUN_DIR"
cp "$ROOT_DIR/leikwan-toolkit.sh" "$LEIKWAN_UPDATE_TARGET_SCRIPT"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

update_latest_release() {
  return 1
}

curl() {
  return 22
}

DRY_RUN=1
empty_pkg_literal='leikwan-toolkit-'".tar.gz"
empty_download='download/v''/'

unset LEIKWAN_TARGET_VERSION
out="$(update_run 1 2>&1 || true)"
grep -q "\[ERROR\] 无法确定最新版本，已取消更新。" <<<"$out"
! grep -q "$empty_pkg_literal" <<<"$out"
! grep -q "releases/${empty_download}" <<<"$out"

if update_release_asset_url "v" "" "" >/dev/null 2>&1; then
  echo "FAIL: empty version URL construction was allowed" >&2
  exit 1
fi

LEIKWAN_TARGET_VERSION=1.4.14
target_out="$(update_run 1 2>&1 || true)"
grep -q "当前已是最新版本" <<<"$target_out"
! grep -q "$empty_pkg_literal" <<<"$target_out"
! grep -q "releases/${empty_download}" <<<"$target_out"

LEIKWAN_TARGET_VERSION=abc
invalid_out="$(update_run 1 2>&1 || true)"
grep -q "LEIKWAN_TARGET_VERSION 无效：abc" <<<"$invalid_out"

empty_pkg_regex='leikwan-toolkit-'"\\.tar.gz"
if grep -R -n -E "${empty_pkg_regex}|${empty_download}" leikwan-toolkit.sh tests scripts >/dev/null; then
  echo "FAIL: found empty release URL pattern in source" >&2
  grep -R -n -E "${empty_pkg_regex}|${empty_download}" leikwan-toolkit.sh tests scripts >&2
  exit 1
fi

echo "[OK] empty latest guard regression passed"
