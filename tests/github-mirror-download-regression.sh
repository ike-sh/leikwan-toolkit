#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p "$ROOT_DIR/.tmp"
TMP_DIR="$(TMPDIR="$ROOT_DIR/.tmp" mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export LEIKWAN_STATE_DIR="${TMP_DIR}/state"
export LEIKWAN_BACKUP_DIR="${TMP_DIR}/backups"
export LEIKWAN_RUN_DIR="${TMP_DIR}/run"
export LEIKWAN_LOG_DISABLED=1
export LEIKWAN_NO_CLEAR=1
export LEIKWAN_GITHUB_MIRRORS="https://mirror.example/"
mkdir -p "$LEIKWAN_RUN_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

attempts="${TMP_DIR}/attempts"
dest="${TMP_DIR}/asset"

curl() {
  local output="" arg url
  while (($# > 0)); do
    arg="$1"
    case "$arg" in
      -o)
        output="$2"
        shift 2
        ;;
      --retry|--retry-delay|--connect-timeout|--max-time|-C)
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
  if [[ "$url" == https://github.com/* || "$url" == https://raw.githubusercontent.com/* || "$url" == https://api.github.com/* ]]; then
    return 22
  fi
  printf 'ok\n' >"$output"
  return 0
}

out="$(download_with_fallback "https://github.com/ike-sh/leikwan-toolkit/releases/download/v1.4.5/leikwan-toolkit-1.4.5.tar.gz" "$dest" 2>&1)"
grep -q "GitHub 直连失败，正在自动切换镜像" <<<"$out"
grep -q "正在尝试镜像：https://mirror.example/https://github.com/ike-sh/leikwan-toolkit/releases/download/v1.4.5/leikwan-toolkit-1.4.5.tar.gz" <<<"$out"
grep -q "镜像下载成功：https://mirror.example/https://github.com/ike-sh/leikwan-toolkit/releases/download/v1.4.5/leikwan-toolkit-1.4.5.tar.gz" <<<"$out"
grep -q '^ok$' "$dest"

first_attempt="$(sed -n '1p' "$attempts")"
second_attempt="$(sed -n '2p' "$attempts")"
[[ "$first_attempt" == "https://github.com/ike-sh/leikwan-toolkit/releases/download/v1.4.5/leikwan-toolkit-1.4.5.tar.gz" ]]
[[ "$second_attempt" == "https://mirror.example/https://github.com/ike-sh/leikwan-toolkit/releases/download/v1.4.5/leikwan-toolkit-1.4.5.tar.gz" ]]

mapfile -t raw_candidates < <(github_url_candidates "https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/scripts/bootstrap.sh")
[[ "${raw_candidates[0]}" == "https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/scripts/bootstrap.sh" ]]
[[ "${raw_candidates[1]}" == "https://mirror.example/https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/scripts/bootstrap.sh" ]]

mapfile -t api_candidates < <(github_url_candidates "https://api.github.com/repos/ike-sh/leikwan-toolkit/releases/latest")
[[ "${api_candidates[0]}" == "https://api.github.com/repos/ike-sh/leikwan-toolkit/releases/latest" ]]
[[ "${api_candidates[1]}" == "https://mirror.example/https://api.github.com/repos/ike-sh/leikwan-toolkit/releases/latest" ]]

grep -q "GitHub 直连失败，正在自动切换镜像" scripts/bootstrap.sh
grep -q "镜像下载成功" scripts/bootstrap.sh

echo "[OK] GitHub mirror download regression passed"
