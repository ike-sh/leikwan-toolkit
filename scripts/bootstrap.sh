#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_GITHUB="https://github.com/ike-sh/leikwan-toolkit"
RAW_SCRIPT_URL="https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/leikwan-toolkit.sh"
LEIKWAN_GITHUB_DOWNLOAD_MODE="${LEIKWAN_GITHUB_DOWNLOAD_MODE:-mirror-first}"
LEIKWAN_GITHUB_MIRRORS_DEFAULT="${LEIKWAN_GITHUB_MIRRORS_DEFAULT:-https://gh-proxy.com/,https://gh.llkk.cc/,https://gh.ddlc.top/,https://ghproxy.net/,https://mirror.ghproxy.com/,https://cf.ghproxy.cc/,https://gh.api.99988866.xyz/,https://github.akams.cn/}"
INSTALL_PATH="/root/leikwan-toolkit.sh"
SHORTCUT_PATH="/usr/local/bin/lq"
SHORTCUT_PATH_UPPER="/usr/local/bin/LQ"
RUN_MENU_MODE="auto"
DEFAULT_GITHUB_MIRRORS=(
  "https://gh-proxy.com/"
  "https://gh.llkk.cc/"
  "https://gh.ddlc.top/"
  "https://ghproxy.net/"
  "https://mirror.ghproxy.com/"
  "https://cf.ghproxy.cc/"
  "https://gh.api.99988866.xyz/"
  "https://github.akams.cn/"
)

ok() { echo "[OK] $*"; }
info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
error() { echo "[ERROR] $*" >&2; }
fail() { echo "[FAIL] $*" >&2; }

usage() {
  cat <<'EOF'
Usage: bash bootstrap.sh [--run-menu|--no-run-menu]

--run-menu     安装后进入 lq 菜单；仅在 stdin 是 TTY 时生效
--no-run-menu  只安装，不进入菜单
EOF
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --run-menu) RUN_MENU_MODE="run" ;;
      --no-run-menu) RUN_MENU_MODE="no-run" ;;
      --help|-h) usage; exit 0 ;;
      *) fail "未知参数：$1"; usage; exit 1 ;;
    esac
    shift
  done
}

trim_spaces() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

github_download_mode() {
  local mode="${LEIKWAN_GITHUB_DOWNLOAD_MODE:-mirror-first}"
  case "$mode" in
    mirror-first|origin-first) printf '%s' "$mode" ;;
    *)
      warn "LEIKWAN_GITHUB_DOWNLOAD_MODE 无效：${mode}，使用 mirror-first。"
      printf '%s' "mirror-first"
      ;;
  esac
}

github_mirror_values() {
  local mirrors="${LEIKWAN_GITHUB_MIRRORS:-${LEIKWAN_GITHUB_MIRROR:-}}" mirror
  local -a mirror_list=()
  mirrors="${mirrors//;/,}"
  if [[ -n "$mirrors" ]]; then
    IFS=',' read -r -a mirror_list <<<"$mirrors"
  elif [[ -n "${LEIKWAN_GITHUB_MIRRORS_DEFAULT:-}" ]]; then
    IFS=',' read -r -a mirror_list <<<"$LEIKWAN_GITHUB_MIRRORS_DEFAULT"
  else
    mirror_list=("${DEFAULT_GITHUB_MIRRORS[@]}")
  fi
  for mirror in "${mirror_list[@]}"; do
    mirror="$(trim_spaces "$mirror")"
    [[ -n "$mirror" ]] || continue
    printf '%s\n' "$mirror"
  done
}

github_raw_to_github_url() {
  local url="$1"
  if [[ "$url" =~ ^https://raw\.githubusercontent\.com/([^/]+)/([^/]+)/([^/]+)/(.*)$ ]]; then
    printf 'https://github.com/%s/%s/raw/%s/%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}"
    return 0
  fi
  return 1
}

mirror_url_for() {
  local mirror="$1" raw_url="$2" github_url
  mirror="${mirror%/}"
  if [[ "$mirror" == *"{url}"* ]]; then
    printf '%s\n' "${mirror//\{url\}/$raw_url}"
    return 0
  fi
  if [[ "$mirror" == */https://github.com ]]; then
    if [[ "$raw_url" == https://github.com/* ]]; then
      printf '%s/%s\n' "$mirror" "${raw_url#https://github.com/}"
      return 0
    fi
    if github_url="$(github_raw_to_github_url "$raw_url")"; then
      printf '%s/%s\n' "$mirror" "${github_url#https://github.com/}"
      return 0
    fi
  fi
  printf '%s/%s\n' "$mirror" "$raw_url"
}

github_url_candidates() {
  local raw_url="$1" mode mirror candidate seen_line
  local -a mirrors=() ordered=() seen=()
  mode="$(github_download_mode)"
  while IFS= read -r mirror; do
    [[ -n "$mirror" ]] || continue
    candidate="$(mirror_url_for "$mirror" "$raw_url")"
    mirrors+=("$candidate")
  done < <(github_mirror_values)
  if [[ "$mode" == "origin-first" ]]; then
    ordered+=("$raw_url")
    ordered+=("${mirrors[@]}")
  else
    ordered+=("${mirrors[@]}")
    ordered+=("$raw_url")
  fi
  for candidate in "${ordered[@]}"; do
    [[ -n "$candidate" ]] || continue
    for seen_line in "${seen[@]}"; do
      [[ "$seen_line" == "$candidate" ]] && continue 2
    done
    seen+=("$candidate")
    printf '%s\n' "$candidate"
  done
}

github_candidate_kind() {
  local candidate="$1" raw_url="$2"
  if [[ "$candidate" == "$raw_url" ]]; then
    printf '%s' "origin"
  else
    printf '%s' "mirror"
  fi
}

download_github_with_mirrors() {
  local raw_url="$1" dest_file="$2" type="${3:-raw}" mode candidate kind tmp
  local connect_timeout max_time
  mode="$(github_download_mode)"
  tmp="${dest_file}.tmp.$$"
  rm -f "$tmp"
  info "GitHub 下载策略：${mode}"
  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    kind="$(github_candidate_kind "$candidate" "$raw_url")"
    if [[ "$kind" == "mirror" ]]; then
      info "正在尝试镜像：${candidate}"
    else
      info "正在尝试 GitHub 官方：${candidate}"
    fi
    case "$type" in
      release|large) connect_timeout=10; max_time=120 ;;
      api|raw|small|sha256|*) connect_timeout=8; max_time=30 ;;
    esac
    if [[ "$kind" == "origin" && ( "$type" == "release" || "$type" == "large" ) ]]; then
      connect_timeout=8
      max_time=60
    fi
    if curl -fL --retry 0 --connect-timeout "$connect_timeout" --max-time "$max_time" -o "$tmp" "$candidate"; then
      mv -f "$tmp" "$dest_file"
      if [[ "$kind" == "mirror" ]]; then
        ok "镜像下载成功：${candidate}"
      else
        ok "GitHub 官方下载成功：${candidate}"
      fi
      return 0
    fi
    rm -f "$tmp"
    warn "当前下载源失败，正在切换下一个源。"
  done < <(github_url_candidates "$raw_url")
  rm -f "$tmp"
  error "所有 GitHub 下载源均失败。"
  return 1
}

download_with_fallback() {
  local raw_url="$1" dest_file="$2" type="${3:-raw}"
  download_github_with_mirrors "$raw_url" "$dest_file" "$type"
}

try_install_jq() {
  if command -v jq >/dev/null 2>&1; then
    ok "jq 已存在。"
    return 0
  fi
  if command -v apt-get >/dev/null 2>&1; then
    info "检测到缺少 jq，正在尝试使用 apt-get 安装。"
    if apt-get update && apt-get install -y jq; then
      ok "jq 安装完成。"
      return 0
    fi
    warn "jq 自动安装失败，请稍后手动安装：apt-get install -y jq"
    return 0
  fi
  if command -v apt >/dev/null 2>&1; then
    info "检测到缺少 jq，正在尝试使用 apt 安装。"
    if apt update && apt install -y jq; then
      ok "jq 安装完成。"
      return 0
    fi
    warn "jq 自动安装失败，请稍后手动安装：apt install -y jq"
    return 0
  fi
  warn "未找到 apt/apt-get，跳过 jq 自动安装。"
}

install_tool() {
  command -v curl >/dev/null 2>&1 || { fail "缺少 curl，请先安装 curl。"; exit 1; }
  local tmp
  try_install_jq
  tmp="$(mktemp)"
  download_with_fallback "$RAW_SCRIPT_URL" "$tmp"
  install -m 755 "$tmp" "$INSTALL_PATH"
  rm -f "$tmp"
  ln -sf "$INSTALL_PATH" "$SHORTCUT_PATH"
  ln -sf "$INSTALL_PATH" "$SHORTCUT_PATH_UPPER"
  ok "安装完成。"
  ok "脚本：${INSTALL_PATH}"
  ok "快捷命令：${SHORTCUT_PATH}"
  ok "快捷命令：${SHORTCUT_PATH_UPPER}"
  echo
  echo "下一步："
  echo "  lq init      # 启动初始化向导"
  echo "  lq status    # 查看当前状态"
}

maybe_run_menu() {
  case "$RUN_MENU_MODE" in
    no-run)
      return 0
      ;;
    run)
      if [[ -t 0 ]]; then
        exec bash "$INSTALL_PATH"
      fi
      warn "当前不是交互终端，无法进入菜单，请手动执行：lq"
      return 0
      ;;
    auto)
      return 0
      ;;
  esac
}

main() {
  parse_args "$@"
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    fail "请使用 root 运行，例如：curl -fsSL ${PROJECT_GITHUB}/raw/main/scripts/bootstrap.sh | sudo bash"
    exit 1
  fi
  install_tool
  maybe_run_menu
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
