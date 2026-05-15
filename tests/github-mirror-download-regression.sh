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
export LEIKWAN_GITHUB_MIRRORS="https://mirror.example/"
unset LEIKWAN_GITHUB_DOWNLOAD_MODE
mkdir -p "$LEIKWAN_RUN_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

attempts="${TMP_DIR}/attempts"
download_attempts="${TMP_DIR}/download-attempts"
args_log="${TMP_DIR}/args"

curl() {
  local output="" arg url="" max_time="" connect_timeout="" retry="" is_probe=0
  while (($# > 0)); do
    arg="$1"
    case "$arg" in
      -o)
        output="$2"
        shift 2
        ;;
      --connect-timeout)
        connect_timeout="$2"
        shift 2
        ;;
      --max-time)
        max_time="$2"
        shift 2
        ;;
      --retry)
        retry="$2"
        shift 2
        ;;
      --speed-time|--speed-limit)
        shift 2
        ;;
      --range|-r)
        is_probe=1
        shift 2
        ;;
      -*I*)
        is_probe=1
        shift
        ;;
      -*)
        shift
        ;;
      *)
        url="$arg"
        shift
        ;;
    esac
  done
  printf '%s\n' "$url" >>"$attempts"
  printf 'url=%s connect=%s max=%s retry=%s probe=%s\n' "$url" "$connect_timeout" "$max_time" "$retry" "$is_probe" >>"$args_log"
  if (( is_probe == 1 )); then
    return 0
  fi
  printf '%s\n' "$url" >>"$download_attempts"
  if [[ "${ALL_FAIL:-0}" == "1" ]]; then
    return 22
  fi
  if [[ "$url" == https://mirror.example/* ]]; then
    printf 'ok\n' >"$output"
    return 0
  fi
  return 22
}

[[ "$(github_download_mode)" == "mirror-first" ]]

mapfile -t mirror_first < <(github_url_candidates "https://github.com/ike-sh/leikwan-toolkit/releases/download/v1.4.7/leikwan-toolkit-1.4.7.tar.gz")
[[ "${mirror_first[0]}" == "https://mirror.example/https://github.com/ike-sh/leikwan-toolkit/releases/download/v1.4.7/leikwan-toolkit-1.4.7.tar.gz" ]]
[[ "${mirror_first[1]}" == "https://github.com/ike-sh/leikwan-toolkit/releases/download/v1.4.7/leikwan-toolkit-1.4.7.tar.gz" ]]

LEIKWAN_GITHUB_DOWNLOAD_MODE=origin-first
mapfile -t origin_first < <(github_url_candidates "https://github.com/ike-sh/leikwan-toolkit/releases/download/v1.4.7/leikwan-toolkit-1.4.7.tar.gz")
[[ "${origin_first[0]}" == "https://github.com/ike-sh/leikwan-toolkit/releases/download/v1.4.7/leikwan-toolkit-1.4.7.tar.gz" ]]
[[ "${origin_first[1]}" == "https://mirror.example/https://github.com/ike-sh/leikwan-toolkit/releases/download/v1.4.7/leikwan-toolkit-1.4.7.tar.gz" ]]
LEIKWAN_GITHUB_DOWNLOAD_MODE=mirror-first

dest="${TMP_DIR}/release.tar.gz"
out="$(download_github_with_mirrors "https://github.com/ike-sh/leikwan-toolkit/releases/download/v1.4.7/leikwan-toolkit-1.4.7.tar.gz" "$dest" release 2>&1)"
grep -Eq 'GitHub .*mirror-first' <<<"$out"
grep -q "https://mirror.example/https://github.com/ike-sh/leikwan-toolkit/releases/download/v1.4.7/leikwan-toolkit-1.4.7.tar.gz" <<<"$out"
grep -q "[OK]" <<<"$out"
grep -q '^ok$' "$dest"
[[ "$(sed -n '1p' "$download_attempts")" == "https://mirror.example/https://github.com/ike-sh/leikwan-toolkit/releases/download/v1.4.7/leikwan-toolkit-1.4.7.tar.gz" ]]

: >"$download_attempts"
download_github_with_mirrors "https://github.com/ike-sh/leikwan-toolkit/releases/download/v1.4.7/leikwan-toolkit-1.4.7.tar.gz.sha256" "${TMP_DIR}/sha256" sha256 >/dev/null 2>&1
[[ "$(sed -n '1p' "$download_attempts")" == "https://mirror.example/https://github.com/ike-sh/leikwan-toolkit/releases/download/v1.4.7/leikwan-toolkit-1.4.7.tar.gz.sha256" ]]

: >"$download_attempts"
download_github_with_mirrors "https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/scripts/bootstrap.sh" "${TMP_DIR}/raw" raw >/dev/null 2>&1
[[ "$(sed -n '1p' "$download_attempts")" == "https://mirror.example/https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/scripts/bootstrap.sh" ]]

: >"$download_attempts"
: >"$args_log"
download_github_with_mirrors "https://api.github.com/repos/ike-sh/leikwan-toolkit/releases/latest" "${TMP_DIR}/api" api >/dev/null 2>&1
[[ "$(sed -n '1p' "$download_attempts")" == "https://mirror.example/https://api.github.com/repos/ike-sh/leikwan-toolkit/releases/latest" ]]
grep -q 'connect=8 max=30 retry=0' "$args_log"

ALL_FAIL=1
if out="$(download_github_with_mirrors "https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/missing" "${TMP_DIR}/missing" raw 2>&1)"; then
  echo "FAIL: expected all GitHub sources to fail" >&2
  exit 1
fi
grep -Eq '\[ERROR\].*GitHub' <<<"$out"

grep -q "update_verify_sha256" leikwan-toolkit.sh
grep -q 'update_download_asset "$sha_url" "$sha_file" sha256' leikwan-toolkit.sh

echo "[OK] GitHub mirror download regression passed"
