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
unset LEIKWAN_DEBUG
mkdir -p "$LEIKWAN_RUN_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

attempts="${TMP_DIR}/attempts"
risky_calls="${TMP_DIR}/risky"
: >"$attempts"
: >"$risky_calls"

download_github_with_mirrors() {
  printf 'download_github_with_mirrors %s\n' "$*" >>"$risky_calls"
  return 99
}

update_download_asset() {
  printf 'update_download_asset %s\n' "$*" >>"$risky_calls"
  return 99
}

download_large_archive_checked() {
  printf 'download_large_archive_checked %s\n' "$*" >>"$risky_calls"
  return 99
}

download_easytier_archive() {
  printf 'download_easytier_archive %s\n' "$*" >>"$risky_calls"
  return 99
}

curl() {
  local output="" arg url="" effective=0
  while (($# > 0)); do
    arg="$1"
    case "$arg" in
      -o)
        output="$2"
        shift 2
        ;;
      -w)
        effective=1
        shift 2
        ;;
      --connect-timeout|--max-time|--retry|--speed-time|--speed-limit|--range|-r)
        shift 2
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
  if [[ "$url" == *"/VERSION" ]]; then
    printf '<html>bad gateway</html>\n' >"$output"
    return 0
  fi
  if (( effective == 1 )); then
    printf 'https://github.com/ike-sh/leikwan-toolkit/releases'
  fi
  echo "curl: (60) SSL certificate problem: certificate has expired" >&2
  echo "curl: (35) TLS handshake failure" >&2
  echo "curl: (22) The requested URL returned error: 403" >&2
  return 22
}

out="$(update_check 2>&1 || true)"
grep -q "无法快速获取最新版本。" <<<"$out"
[[ ! -s "$risky_calls" ]] || { cat "$risky_calls" >&2; exit 1; }

if grep -Eq 'leikwan-toolkit-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz|sha256|EasyTier' "$attempts"; then
  echo "FAIL: latest check requested risky download URLs" >&2
  cat "$attempts" >&2
  exit 1
fi

if grep -Eq '403|TLS|SSL|certificate' <<<"$out"; then
  echo "FAIL: latest check printed low-level curl errors without debug mode" >&2
  echo "$out" >&2
  exit 1
fi

echo "[OK] latest no risky download regression passed"
