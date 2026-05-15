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
  case "${SCENARIO:-api}" in
    api)
      if [[ "$url" == *api.github.com*/releases/latest* && "$effective" == 0 ]]; then
        printf '{"tag_name":"v1.4.6"}\n' >"$output"
        return 0
      fi
      ;;
    redirect)
      if [[ "$url" == *api.github.com*/releases/latest* && "$effective" == 0 ]]; then
        printf '<html>bad gateway</html>\n' >"$output"
        return 0
      fi
      if [[ "$url" == *github.com*/releases/latest* && "$effective" == 1 ]]; then
        printf 'https://github.com/ike-sh/leikwan-toolkit/releases/tag/v1.4.6'
        return 0
      fi
      ;;
    tags)
      if [[ "$url" == *api.github.com*/releases/latest* && "$effective" == 0 ]]; then
        : >"$output"
        return 0
      fi
      if [[ "$url" == *github.com*/releases/latest* && "$effective" == 1 ]]; then
        printf 'https://github.com/ike-sh/leikwan-toolkit/releases'
        return 0
      fi
      if [[ "$url" == *api.github.com*/tags* && "$effective" == 0 ]]; then
        printf '[{"name":"v1.4.5"},{"name":"v1.4.7"},{"name":"v1.4.6"},{"name":"not-semver"}]\n' >"$output"
        return 0
      fi
      ;;
    fail)
      return 22
      ;;
  esac
  return 22
}

SCENARIO=api
: >"$attempts"
[[ "$(get_latest_release_version)" == "1.4.6" ]]
[[ "$(sed -n '1p' "$attempts")" == "https://mirror.example/https://api.github.com/repos/ike-sh/leikwan-toolkit/releases/latest" ]]

LEIKWAN_GITHUB_DOWNLOAD_MODE=origin-first
: >"$attempts"
[[ "$(get_latest_release_version)" == "1.4.6" ]]
[[ "$(sed -n '1p' "$attempts")" == "https://api.github.com/repos/ike-sh/leikwan-toolkit/releases/latest" ]]
LEIKWAN_GITHUB_DOWNLOAD_MODE=mirror-first

SCENARIO=redirect
[[ "$(get_latest_release_version)" == "1.4.6" ]]

SCENARIO=tags
[[ "$(get_latest_release_version)" == "1.4.7" ]]

SCENARIO=fail
out="$(update_check 2>&1 || true)"
grep -q "无法获取最新版本：GitHub API / latest redirect / tags 均失败。" <<<"$out"
if grep -Eq '最新版本：[[:space:]]*$' <<<"$out"; then
  echo "FAIL: update check printed an empty latest version" >&2
  echo "$out" >&2
  exit 1
fi

echo "[OK] latest version regression passed"
