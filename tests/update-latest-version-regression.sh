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
export LEIKWAN_GITHUB_MIRRORS="https://download-one.example/,https://download-two.example/"
unset LEIKWAN_GITHUB_DOWNLOAD_MODE
unset LEIKWAN_GITHUB_METADATA_MODE
unset LEIKWAN_GITHUB_METADATA_MIRRORS
mkdir -p "$LEIKWAN_RUN_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

attempts="${TMP_DIR}/attempts"
args_log="${TMP_DIR}/args"

curl() {
  local output="" arg url="" effective=0 max_time="" connect_timeout="" retry=""
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
      --speed-time|--speed-limit|--range|-r)
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
  printf 'url=%s connect=%s max=%s retry=%s effective=%s\n' "$url" "$connect_timeout" "$max_time" "$retry" "$effective" >>"$args_log"
  case "${SCENARIO:-version}" in
    version)
      if [[ "$url" == *"/VERSION" ]]; then
        printf '1.4.9\n' >"$output"
        return 0
      fi
      ;;
    api)
      if [[ "$url" == *"/VERSION" ]]; then
        printf '<html>bad gateway</html>\n' >"$output"
        return 0
      fi
      if [[ "$url" == "https://api.github.com/repos/ike-sh/leikwan-toolkit/releases/latest" && "$effective" == 0 ]]; then
        printf '{"tag_name":"v1.4.9"}\n' >"$output"
        return 0
      fi
      ;;
    redirect)
      if [[ "$url" == *"/VERSION" ]]; then
        : >"$output"
        return 0
      fi
      if [[ "$url" == "https://api.github.com/repos/ike-sh/leikwan-toolkit/releases/latest" && "$effective" == 0 ]]; then
        printf '<html>bad gateway</html>\n' >"$output"
        return 0
      fi
      if [[ "$url" == "https://github.com/ike-sh/leikwan-toolkit/releases/latest" && "$effective" == 1 ]]; then
        printf 'https://github.com/ike-sh/leikwan-toolkit/releases/tag/v1.4.9'
        return 0
      fi
      ;;
    tags)
      if [[ "$url" == *"/VERSION" ]]; then
        return 22
      fi
      if [[ "$url" == *"/releases/latest" && "$effective" == 0 ]]; then
        : >"$output"
        return 0
      fi
      if [[ "$url" == *"/releases/latest" && "$effective" == 1 ]]; then
        printf 'https://github.com/ike-sh/leikwan-toolkit/releases'
        return 0
      fi
      if [[ "$url" == "https://api.github.com/repos/ike-sh/leikwan-toolkit/tags" && "$effective" == 0 ]]; then
        printf '[{"name":"v1.4.6"},{"name":"v1.4.9"},{"name":"v1.4.7"},{"name":"not-semver"}]\n' >"$output"
        return 0
      fi
      ;;
    fail)
      return 22
      ;;
  esac
  return 22
}

SCENARIO=version
: >"$attempts"
: >"$args_log"
[[ "$(get_latest_release_version)" == "1.4.9" ]]
grep -q '/VERSION' "$attempts"
! grep -q 'api.github.com' "$attempts"

SCENARIO=api
: >"$attempts"
[[ "$(get_latest_release_version)" == "1.4.9" ]]
first_api="$(grep 'api.github.com' "$attempts" | sed -n '1p')"
[[ "$first_api" == "https://api.github.com/repos/ike-sh/leikwan-toolkit/releases/latest" ]]
api_host_pattern='api.github.com'
proxy_pattern='download-one|download-two|gh-pro''xy|gh.ll''kk|gh''proxy'
if grep "$api_host_pattern" "$attempts" | grep -Eq "$proxy_pattern"; then
  echo "FAIL: fast metadata mode proxied GitHub API through download mirrors" >&2
  cat "$attempts" >&2
  exit 1
fi

SCENARIO=redirect
: >"$attempts"
[[ "$(get_latest_release_version)" == "1.4.9" ]]
grep -q 'https://github.com/ike-sh/leikwan-toolkit/releases/latest' "$attempts"

SCENARIO=tags
: >"$attempts"
[[ "$(get_latest_release_version)" == "1.4.9" ]]

SCENARIO=fail
out="$(update_check 2>&1 || true)"
grep -q "无法快速获取最新版本。" <<<"$out"
if grep -Eq '最新版本：[[:space:]]*$' <<<"$out"; then
  echo "FAIL: update check printed an empty latest version" >&2
  echo "$out" >&2
  exit 1
fi

SCENARIO=fail
LEIKWAN_GITHUB_METADATA_MODE=full
LEIKWAN_GITHUB_METADATA_TIMEOUT=9
: >"$args_log"
get_latest_release_version >/dev/null 2>&1 || true
grep -q 'max=8' "$args_log"
if awk -F'max=' 'NF > 1 {split($2,a," "); if (a[1] > 8) exit 1}' "$args_log"; then
  :
else
  echo "FAIL: metadata curl max-time exceeded short timeout" >&2
  cat "$args_log" >&2
  exit 1
fi

echo "[OK] latest version regression passed"
