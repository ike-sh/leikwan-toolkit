#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p "$ROOT_DIR/.tmp"
TMP_DIR="$(TMPDIR="$ROOT_DIR/.tmp" mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export LEIKWAN_GITHUB_MIRRORS="https://bootstrap-mirror.example/"
unset LEIKWAN_GITHUB_DOWNLOAD_MODE

# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/bootstrap.sh"

attempts="${TMP_DIR}/attempts"

curl() {
  local output="" arg url=""
  while (($# > 0)); do
    arg="$1"
    case "$arg" in
      -o)
        output="$2"
        shift 2
        ;;
      --connect-timeout|--max-time|--retry)
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
  if [[ "$url" == https://bootstrap-mirror.example/* ]]; then
    printf 'ok\n' >"$output"
    return 0
  fi
  return 22
}

[[ "$(github_download_mode)" == "mirror-first" ]]

mapfile -t candidates < <(github_url_candidates "https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/leikwan-toolkit.sh")
[[ "${candidates[0]}" == "https://bootstrap-mirror.example/https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/leikwan-toolkit.sh" ]]
[[ "${candidates[1]}" == "https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/leikwan-toolkit.sh" ]]

export LEIKWAN_GITHUB_MIRRORS="https://override-one.example/,https://override-two.example/"
mapfile -t override_candidates < <(github_url_candidates "https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/leikwan-toolkit.sh")
[[ "${override_candidates[0]}" == "https://override-one.example/https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/leikwan-toolkit.sh" ]]
[[ "${override_candidates[1]}" == "https://override-two.example/https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/leikwan-toolkit.sh" ]]

export LEIKWAN_GITHUB_MIRRORS="https://bootstrap-mirror.example/"
download_github_with_mirrors "https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/leikwan-toolkit.sh" "${TMP_DIR}/tool" raw >/dev/null 2>&1
[[ "$(sed -n '1p' "$attempts")" == "https://bootstrap-mirror.example/https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/leikwan-toolkit.sh" ]]

grep -q "LEIKWAN_GITHUB_DOWNLOAD_MODE=mirror-first" README.md
grep -q "https://gh-proxy.com/https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/scripts/bootstrap.sh" README.md
grep -q "LEIKWAN_GITHUB_MIRRORS_DEFAULT" scripts/bootstrap.sh

echo "[OK] bootstrap mirror-first regression passed"
