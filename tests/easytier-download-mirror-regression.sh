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
export LEIKWAN_GITHUB_MIRRORS="https://bad-mirror.example/,https://good-mirror.example/"
export LEIKWAN_DOWNLOAD_CACHE_DIR="${TMP_DIR}/cache"
unset LEIKWAN_GITHUB_DOWNLOAD_MODE
mkdir -p "$LEIKWAN_RUN_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

archive_integrity_ok() {
  return 0
}

attempts="${TMP_DIR}/attempts"
downloads="${TMP_DIR}/downloads"
outputs="${TMP_DIR}/outputs"
args_log="${TMP_DIR}/args"

curl() {
  local output="" arg url="" max_time="" connect_timeout="" retry="" speed_time="" speed_limit="" is_probe=0
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
      --speed-time)
        speed_time="$2"
        shift 2
        ;;
      --speed-limit)
        speed_limit="$2"
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
  printf 'url=%s connect=%s max=%s retry=%s speed_time=%s speed_limit=%s probe=%s output=%s\n' "$url" "$connect_timeout" "$max_time" "$retry" "$speed_time" "$speed_limit" "$is_probe" "$output" >>"$args_log"
  if (( is_probe == 1 )); then
    return 0
  fi
  printf '%s\n' "$url" >>"$downloads"
  printf '%s\n' "$output" >>"$outputs"
  if [[ "$url" == *api.github.com* ]]; then
    echo "FAIL: EasyTier should not call GitHub API before deterministic assets succeed" >&2
    return 22
  fi
  if [[ "$url" == https://bad-mirror.example/* ]]; then
    return 22
  fi
  if [[ "$url" == https://good-mirror.example/* && "$url" == *".zip" ]]; then
    printf '<html>bad gateway</html>\n' >"$output"
    truncate -s 10485761 "$output"
    return 0
  fi
  if [[ "$url" == https://good-mirror.example/* && "$url" == *".tar.gz" ]]; then
    truncate -s 1024 "$output"
    return 0
  fi
  if [[ "$url" == https://good-mirror.example/* && "$url" == *".tgz" ]]; then
    truncate -s 10485761 "$output"
    return 0
  fi
  return 22
}

dest="${TMP_DIR}/easytier.pkg"
out="$(download_easytier_archive "$dest" 2>&1)"
grep -Eq 'EasyTier .*mirror-first' <<<"$out"
grep -Eq 'GitHub .*mirror-first' <<<"$out"
grep -q "当前源下载失败，已丢弃该源临时文件，切换下一个源。" <<<"$out"
grep -q "疑似 HTML" <<<"$out"
grep -q "小于 10MB" <<<"$out"
grep -q "EasyTier 下载和校验完成。" <<<"$out"

first_download="$(sed -n '1p' "$downloads")"
[[ "$first_download" == https://bad-mirror.example/https://github.com/EasyTier/EasyTier/releases/download/v2.4.5/* ]]
[[ "$first_download" != https://github.com/* ]]

grep -q '.zip' "$downloads"
grep -q '.tar.gz' "$downloads"
grep -q '.tgz' "$downloads"
grep -q 'https://bad-mirror.example/' "$downloads"
grep -q 'https://good-mirror.example/' "$downloads"
grep -q 'connect=10 max=120 retry=0 speed_time=30 speed_limit=10240' "$args_log"

bad_max_time='--max-time 6''00'
bad_retry='--retry ''3'
if grep -q -- "$bad_max_time" leikwan-toolkit.sh || grep -q -- "$bad_retry" leikwan-toolkit.sh; then
  echo "FAIL: EasyTier download still contains slow retry path" >&2
  exit 1
fi
resume_pattern='Resuming trans''fer|--continue''-at|-C ''-'
if grep -R -Eq -- "$resume_pattern" leikwan-toolkit.sh scripts tests; then
  echo "FAIL: cross-source resume path still exists" >&2
  exit 1
fi

first_output="$(sed -n '1p' "$outputs")"
second_output="$(sed -n '2p' "$outputs")"
[[ -n "$first_output" && -n "$second_output" && "$first_output" != "$second_output" ]]
grep -q '.part.' "$outputs"

grep -q "choose_local_easytier_archive" leikwan-toolkit.sh
grep -q "easytier_store_archive_cache" leikwan-toolkit.sh

cache_file="${LEIKWAN_DOWNLOAD_CACHE_DIR}/easytier-linux-x86_64-v2.4.5.tgz"
[[ -f "$cache_file" ]]

: >"$downloads"
second_dest="${TMP_DIR}/easytier-cached.pkg"
cached_out="$(download_large_archive_checked "https://github.com/EasyTier/EasyTier/releases/download/v2.4.5/easytier-linux-x86_64-v2.4.5.tgz" "$second_dest" 2>&1)"
grep -q "复用已缓存 EasyTier 安装包" <<<"$cached_out"
[[ -f "$second_dest" ]]
[[ ! -s "$downloads" ]]

printf '<html>cached error</html>\n' >"$cache_file"
truncate -s 10485761 "$cache_file"
: >"$downloads"
redownload_dest="${TMP_DIR}/easytier-redownload.pkg"
redownload_out="$(download_large_archive_checked "https://github.com/EasyTier/EasyTier/releases/download/v2.4.5/easytier-linux-x86_64-v2.4.5.tgz" "$redownload_dest" 2>&1)"
grep -q "删除后重新下载" <<<"$redownload_out"
[[ -s "$downloads" ]]
[[ -f "$redownload_dest" ]]

echo "[OK] EasyTier mirror download regression passed"
