#!/usr/bin/env bash
set -Eeuo pipefail

TOOL_VERSION="1.4.18"
RELEASE_CHANNEL="LTS"
PROJECT_NAME="leikwan-toolkit"
PROJECT_TITLE="利群快速组网工具"
PROJECT_GITHUB="https://github.com/ike-sh/leikwan-toolkit"
LEIKWAN_GITHUB_DOWNLOAD_MODE="${LEIKWAN_GITHUB_DOWNLOAD_MODE:-mirror-first}"
LEIKWAN_GITHUB_METADATA_MODE="${LEIKWAN_GITHUB_METADATA_MODE:-fast}"
LEIKWAN_GITHUB_MIRRORS_DEFAULT="${LEIKWAN_GITHUB_MIRRORS_DEFAULT:-https://gh-proxy.com/,https://gh.llkk.cc/,https://gh.ddlc.top/,https://ghproxy.net/,https://mirror.ghproxy.com/,https://cf.ghproxy.cc/,https://gh.api.99988866.xyz/,https://github.akams.cn/}"

DRY_RUN=0
VERBOSE_DOCTOR=0
DEPS_APT_UPDATED=0
DEPS_INSTALLED_THIS_RUN=""
LOG_DISABLED="${LEIKWAN_LOG_DISABLED:-0}"
MENU_ACTION_PAUSE_DONE=0
DOCTOR_INTERACTIVE_FIX=0
APPLY_NFT_LAST_STATUS=""
LEIKWAN_LOCK_CONFLICT=0
REPORT_WARN_COUNT=0
REPORT_FAIL_COUNT=0
PORT_CHECK_RESULT="ok"
STATUS_OVERVIEW_RESULT="ok"
LATEST_METADATA_STARTED_AT=0
LATEST_METADATA_BUDGET=20
LEIKWAN_GLOBAL_LOCK_TOKEN=""
UPDATE_RELOAD_AFTER_ACTION=0
DOCTOR_SUMMARY_OVERALL=""
DOCTOR_SUMMARY_WARNINGS=0
DOCTOR_SUMMARY_FAILURES=0
DDNS_FORWARD_CHECKED=0
DDNS_FORWARD_DOMAIN_COUNT=0
DDNS_FORWARD_CHANGED_COUNT=0
DDNS_FORWARD_FAILED_COUNT=0
DDNS_ENTRY_CHECKED=0
DDNS_ENTRY_DOMAIN_COUNT=0
DDNS_ENTRY_CHANGED_COUNT=0
DDNS_ENTRY_FAILED_COUNT=0
DDNS_PBR_DOMAIN_COUNT=0
DDNS_PBR_CHANGED_COUNT=0
DDNS_PBR_FAILED_COUNT=0
DDNS_GLOBAL_DOMAIN_COUNT=0
DDNS_GLOBAL_CHANGED_COUNT=0
DDNS_GLOBAL_FAILED_COUNT=0
DDNS_PUBLIC_IP=""
DDNS_PUBLIC_IP_SOURCE=""
DDNS_PUBLIC_IP_FAILED=false
RESOLVE_SELECTED_IP=""
RESOLVE_SELECTED_SOURCE=""
RESOLVE_ALL_RESULTS=""
RESOLVE_SPLIT_DETECTED=false
RESOLVE_INCOMPLETE_DETECTED=false
DDNS_DNS_SPLIT_DETECTED=false
DDNS_DNS_INCOMPLETE_DETECTED=false
DDNS_DNS_DIG_WARNED=false
DDNS_DNS_SPLIT_DOMAIN=""
DDNS_DNS_SPLIT_RESULTS=""
DDNS_DNS_SPLIT_SELECTED_IP=""
DDNS_DNS_SPLIT_SELECTED_SOURCE=""
DDNS_ENTRY_RECENT_EVENTS=""
DDNS_ENTRY_RECENT_ACTION=""
DDNS_FORWARD_RECENT_EVENTS=""
DDNS_FORWARD_RECENT_ACTION=""
DDNS_PBR_RECENT_EVENTS=""
DDNS_PBR_RECENT_ACTION=""
DDNS_RELAY_RESTARTED_AT=""
DDNS_RELAY_RESTART_SKIPPED_COOLDOWN=false
DDNS_DNSUTILS_INSTALL_ATTEMPTED=false

LOG_FILE="${LEIKWAN_LOG_FILE:-/var/log/leikwan-toolkit.log}"
STATE_DIR="${LEIKWAN_STATE_DIR:-/etc/leikwan-toolkit}"
BACKUP_DIR="${LEIKWAN_BACKUP_DIR:-/var/backups/leikwan-toolkit}"
OLD_LOG_FILE="/var/log/leikwan-wg-toolkit.log"
OLD_STATE_DIR="/etc/leikwan-wg-toolkit"
OLD_BACKUP_DIR="/var/backups/leikwan-wg-toolkit"
OLD_ROOT_SCRIPT="/root/wg-${PROJECT_NAME#leikwan-}.sh"
OUTPUT_DIR="${STATE_DIR}/outputs"
NFT_DIR="${STATE_DIR}/nft"
ENTRY_DIR="${STATE_DIR}/entry"
ENTRIES_DIR="${STATE_DIR}/entries"
FORWARDS_DIR="${STATE_DIR}/forwards"
PBR_DIR="${STATE_DIR}/pbr"
EASYTIER_DIR="${STATE_DIR}/easytier"
DOWNLOAD_CACHE_DIR="${LEIKWAN_DOWNLOAD_CACHE_DIR:-/var/cache/leikwan-toolkit/downloads}"
STATUS_DIR="${STATE_DIR}/status"
SNAPSHOT_DIR="${STATE_DIR}/snapshots"
AUTO_SNAPSHOT_DIR="${SNAPSHOT_DIR}/auto"
REPORT_FILE="${LEIKWAN_REPORT_FILE:-/root/leikwan-debug-report.txt}"
APPLY_RELAY_LOG="${LEIKWAN_APPLY_RELAY_LOG:-/root/lq-apply-relay.log}"
DDNS_CONFIG="${STATE_DIR}/ddns-global.env"
DDNS_LEGACY_CONFIG="${STATE_DIR}/ddns.env"
DDNS_LOG_FILE="/var/log/leikwan-ddns-refresh.log"
DDNS_STATUS_FILE="${STATUS_DIR}/last-ddns.env"
DDNS_GLOBAL_RESOLVED_TSV="${STATUS_DIR}/resolved-ddns-domains.tsv"
DDNS_SERVICE_NAME="leikwan-ddns-refresh"
DDNS_SERVICE="/etc/systemd/system/${DDNS_SERVICE_NAME}.service"
DDNS_TIMER="/etc/systemd/system/${DDNS_SERVICE_NAME}.timer"
ENTRY_DDNS_CONFIG="${ENTRY_DIR}/ddns.env"
ENTRY_DDNS_LOG_FILE="/var/log/leikwan-entry-ddns.log"
ENTRY_DDNS_STATUS_FILE="${STATUS_DIR}/last-entry-ddns.env"
ENTRY_DDNS_SERVICE_NAME="leikwan-entry-ddns"
ENTRY_DDNS_SERVICE="/etc/systemd/system/${ENTRY_DDNS_SERVICE_NAME}.service"
ENTRY_DDNS_TIMER="/etc/systemd/system/${ENTRY_DDNS_SERVICE_NAME}.timer"
LEIKWAN_RUN_DIR="${LEIKWAN_RUN_DIR:-/run}"
LEIKWAN_LOCK_PATH="${LEIKWAN_LOCK_PATH:-${LEIKWAN_RUN_DIR}/leikwan-toolkit.lock}"
DDNS_LOCK_PATH="${DDNS_LOCK_PATH:-${LEIKWAN_RUN_DIR}/leikwan-ddns-refresh.lock}"
UPDATE_LOCK_PATH="${UPDATE_LOCK_PATH:-${LEIKWAN_RUN_DIR}/leikwan-update.lock}"
CONFIG_LOCK_PATH="${CONFIG_LOCK_PATH:-${LEIKWAN_RUN_DIR}/leikwan-config.lock}"
UPDATE_STATUS_FILE="${STATUS_DIR}/last-update.env"
UPDATE_TARGET_SCRIPT="${LEIKWAN_UPDATE_TARGET_SCRIPT:-/root/leikwan-toolkit.sh}"
UPDATE_REPO="ike-sh/leikwan-toolkit"

ENTRIES_TSV="${ENTRIES_DIR}/entries.tsv"
PENDING_ENTRIES_TSV="${ENTRIES_DIR}/pending-entries.tsv"
RESOLVED_ENTRIES_TSV="${ENTRIES_DIR}/resolved-entries.tsv"
FORWARDS_TSV="${FORWARDS_DIR}/forwards.tsv"
RESOLVED_TSV="${FORWARDS_DIR}/resolved.tsv"
FORWARD_TXT="${OUTPUT_DIR}/forward-endpoints.txt"
FORWARD_TSV="${OUTPUT_DIR}/forward-endpoints.tsv"
FORWARD_JSON="${OUTPUT_DIR}/forward-endpoints.json"
FORWARD_HTML="${OUTPUT_DIR}/forward-endpoints.html"
FORWARD_QR_DIR="${OUTPUT_DIR}/qr"
ENTRY_EXPOSE_ENV="${ENTRY_DIR}/expose.env"
NETWORK_ENV="${EASYTIER_DIR}/network.env"
NETWORK_PAIRING_FILE="${OUTPUT_DIR}/easytier-network-code.env"
ENTRY_PAIRING_FILE="${OUTPUT_DIR}/easytier-entry-code.env"
DEPS_MARKER="${STATE_DIR}/.deps-installed"

ET_NET="10.198.1.0/24"
RELAY_ET_IP="10.198.1.1"
ENTRY_ET_IP_DEFAULT="10.198.1.2"
ENTRY_EXPOSE_START_DEFAULT="10000"
ENTRY_EXPOSE_END_DEFAULT="19999"
FORWARD_ENTRY_PORT_FALLBACK_START="10001"
FORWARD_ENTRY_PORT_FALLBACK_END="19999"
DEFAULT_TCP_MSS_CLAMP="1320"
ENABLE_MSS_CLAMP="true"
EASYTIER_VERSION="${EASYTIER_VERSION:-v2.4.5}"
EASYTIER_CORE_BIN="/usr/local/bin/easytier-core"
EASYTIER_CLI_BIN="/usr/local/bin/easytier-cli"
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
FAST_PORT_RANGE_START="8000"
FAST_PORT_RANGE_END="9000"
DEFAULT_EASYTIER_PORT="8301"
EASYTIER_PORT_DEFAULT="$DEFAULT_EASYTIER_PORT"
EASYTIER_PROTOCOL_DEFAULT="tcp"
EASYTIER_PROTOCOLS_DEFAULT="tcp,udp"
EASYTIER_RELAY_SERVICE_NAME="easytier-relay"
EASYTIER_RELAY_SERVICE="/etc/systemd/system/${EASYTIER_RELAY_SERVICE_NAME}.service"

NFT_RULE_FILE="${NFT_DIR}/leikwan-forward.nft"
MSS_CONFIG="${NFT_DIR}/mss.env"
NFT_SERVICE_NAME="leikwan-nft-forward"
NFT_SERVICE="/etc/systemd/system/${NFT_SERVICE_NAME}.service"
FORWARD_SYSCTL="/etc/sysctl.d/99-leikwan-forward.conf"

PBR_STATIC_CONF="${PBR_DIR}/static-routes.conf"
PBR_DOMAIN_TSV="${PBR_DIR}/domain-routes.tsv"
PBR_RESOLVED_DOMAIN_TSV="${PBR_DIR}/resolved-pbr-domains.tsv"
PBR_RT_TABLES="/etc/iproute2/rt_tables"
PBR_PRIORITY="15000"
DDNS_REFRESH_INTERVAL_DEFAULT="5min"
DDNS_REFRESH_FORWARDS_DEFAULT="true"
DDNS_REFRESH_ENTRIES_DEFAULT="true"
DDNS_REFRESH_PBR_DEFAULT="true"
DDNS_AUTO_APPLY_DEFAULT="true"
DDNS_AUTO_FIX_ROUTE_DEFAULT="false"
DDNS_AUTO_SYNC_FORWARD_PBR_DEFAULT="true"
DDNS_AUTO_SYNC_DOMAIN_PBR_DEFAULT="true"
DDNS_ENTRY_AUTO_RESTART_RELAY_DEFAULT="false"
DDNS_KEEP_OLD_ON_FAIL_DEFAULT="true"
DDNS_GLOBAL_ENABLED_DEFAULT="false"
DDNS_GLOBAL_INTERVAL_DEFAULT="5min"
DDNS_AUTO_SYNC_PBR_DEFAULT="true"
DDNS_AUTO_RESTART_RELAY_DEFAULT="false"
DDNS_RESTART_RELAY_COOLDOWN_DEFAULT="300"
DDNS_CHANGE_CONFIRM_COUNT_DEFAULT="1"
DDNS_UPDATE_DNS_RECORD_DEFAULT="false"
PUBLIC_IP_CHECK_URLS_DEFAULT="https://api.ipify.org,https://ifconfig.me/ip,https://ipv4.icanhazip.com,https://4.ipw.cn,https://ip.3322.net,https://myip.ipip.net"
DNS_RESOLVE_SERVERS_DEFAULT="1.1.1.1,8.8.8.8,223.5.5.5,119.29.29.29"
DNS_RESOLVE_STRATEGY_DEFAULT="first-success"
DNS_RESOLVE_WARN_ON_SPLIT_DEFAULT="true"
ENTRY_DDNS_ENABLED_DEFAULT="false"
ENTRY_DDNS_PROVIDER_DEFAULT="custom-url"
ENTRY_DDNS_INTERVAL_DEFAULT="5min"
ENTRY_DDNS_IP_SOURCE_DEFAULT="auto"

BBR_SYSCTL_CONF="/etc/sysctl.d/99-leikwan-bbr.conf"
LEIKWAN_SYSTEM_DNS_PRIMARY="${LEIKWAN_SYSTEM_DNS_PRIMARY:-8.8.8.8 1.1.1.1}"
LEIKWAN_SYSTEM_DNS_FALLBACK="${LEIKWAN_SYSTEM_DNS_FALLBACK:-8.8.4.4 1.0.0.1}"
SYSTEM_DNS_TARGET_CSV="${LEIKWAN_SYSTEM_DNS:-${LEIKWAN_SYSTEM_DNS_PRIMARY// /,}}"
SYSTEM_DNS_FALLBACK_SPACE="$LEIKWAN_SYSTEM_DNS_FALLBACK"
SYSTEM_DNS_FALLBACK_CSV="${LEIKWAN_SYSTEM_DNS_FALLBACK// /,}"
SYSTEM_GAI_CONF="${LEIKWAN_GAI_CONF:-/etc/gai.conf}"
SYSTEM_RESOLV_CONF="${LEIKWAN_RESOLV_CONF:-/etc/resolv.conf}"
DNS_RESOLVED_CONF="${LEIKWAN_RESOLVED_CONF:-/etc/systemd/resolved.conf.d/99-leikwan-dns.conf}"
IPV6_DISABLE_SYSCTL_CONF="${LEIKWAN_IPV6_DISABLE_CONF:-/etc/sysctl.d/99-leikwan-disable-ipv6.conf}"
IPV6_PROC_CONF_DIR="${LEIKWAN_PROC_IPV6_CONF_DIR:-/proc/sys/net/ipv6/conf}"
IPV6_NFT_LOCK_FILE="${NFT_DIR}/leikwan-ipv6-lockdown.nft"
IPV6_NFT_SERVICE_NAME="leikwan-ipv6-lockdown"
IPV6_NFT_SERVICE="${LEIKWAN_IPV6_NFT_SERVICE:-/etc/systemd/system/${IPV6_NFT_SERVICE_NAME}.service}"
SHORTCUT_LQ="/usr/local/bin/lq"
SHORTCUT_LQ_UPPER="/usr/local/bin/LQ"

if [[ -t 1 ]]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BLUE=$'\033[34m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; BLUE=""; BOLD=""; RESET=""
fi

on_error() {
  local rc=$?
  echo "${RED}错误：脚本在第 ${1:-unknown} 行退出，状态 ${rc}${RESET}" >&2
  exit "$rc"
}
trap 'on_error "$LINENO"' ERR

log() {
  (( LOG_DISABLED == 1 )) && return 0
  [[ ${EUID:-$(id -u)} -eq 0 ]] || return 0
  mkdir -p "$(dirname "$LOG_FILE")"
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" >>"$LOG_FILE"
}

ok() { echo "${GREEN}[OK]${RESET} $*"; log "OK $*"; }
info() { echo "${BLUE}[INFO]${RESET} $*"; log "INFO $*"; }
warn() { echo "${YELLOW}[WARN]${RESET} $*"; log "WARN $*"; }
fail() { echo "${RED}[FAIL]${RESET} $*" >&2; log "FAIL $*"; }

need_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    fail "请使用 root 运行，例如：sudo bash leikwan-toolkit.sh"
    exit 1
  fi
}

need_root_unless_dry_run() {
  (( DRY_RUN == 1 )) && return 0
  need_root
}

normalize_menu_choice() {
  local s="$1"
  s="${s//$'\r'/}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

prompt_menu_choice() {
  local prompt="$1" value
  if ! read -r -p "$prompt" value; then
    info "检测到非交互输入结束，已退出菜单。"
    exit 0
  fi
  normalize_menu_choice "$value"
}

prompt_value() {
  local prompt="$1" default="${2:-}" value
  if [[ -n "$default" ]]; then
    read -r -p "${prompt} [${default}]: " value || value=""
    value="$(normalize_menu_choice "$value")"
    printf '%s' "${value:-$default}"
  else
    read -r -p "${prompt}: " value || value=""
    normalize_menu_choice "$value"
  fi
}

prompt_yes_no() {
  local prompt="$1" default="${2:-N}" answer suffix
  case "${default,,}" in
    y|yes) default="Y" ;;
    *) default="N" ;;
  esac
  [[ "$default" =~ ^[Yy]$ ]] && suffix="[Y/n]" || suffix="[y/N]"
  while true; do
    if [[ -t 0 ]]; then
      read -r -p "${prompt} ${suffix} " answer || answer=""
    else
      printf '%s %s ' "$prompt" "$suffix" >&2
      read -r answer || answer=""
      printf '\n' >&2
    fi
    answer="$(normalize_menu_choice "$answer")"
    answer="${answer:-$default}"
    answer="${answer,,}"
    case "$answer" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *) echo "请输入 y 或 n。" ;;
    esac
  done
}

prompt_enabled_value() {
  local prompt="$1" default="${2:-true}"
  if prompt_yes_no "$prompt" "$(bool_to_default "$default")"; then
    printf 'true'
  else
    printf 'false'
  fi
}

is_interactive() {
  [[ -t 0 && -t 1 ]]
}

clear_screen_if_interactive() {
  [[ "${LEIKWAN_NO_CLEAR:-0}" == "1" ]] && return 0
  [[ -t 1 ]] || return 0
  if command -v tput >/dev/null 2>&1 && [[ -n "${TERM:-}" && "${TERM:-}" != "dumb" ]]; then
    tput clear || printf '\033[H\033[2J'
  else
    printf '\033[H\033[2J'
  fi
}

wait_enter_to_return() {
  is_interactive || return 0
  printf '\n按回车继续...'
  local _answer
  IFS= read -r _answer || true
}

terminal_cols() {
  if [[ -n "${LEIKWAN_COLUMNS:-}" && "${LEIKWAN_COLUMNS}" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$LEIKWAN_COLUMNS"
    return 0
  fi
  if is_interactive && command -v tput >/dev/null 2>&1 && [[ -n "${TERM:-}" && "${TERM:-}" != "dumb" ]]; then
    tput cols 2>/dev/null || printf '80\n'
  else
    printf '120\n'
  fi
}

display_width() {
  local value="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys, unicodedata; s=sys.argv[1]; print(sum(0 if unicodedata.combining(ch) else 2 if unicodedata.east_asian_width(ch) in ("F", "W") else 1 for ch in s))' "$value" 2>/dev/null && return 0
  fi
  printf '%s' "$value" | awk '{print length($0)}'
}

pad_display_width() {
  local value="$1" width="$2" current
  current="$(display_width "$value")"
  printf '%s' "$value"
  if [[ "$current" =~ ^[0-9]+$ ]] && (( current < width )); then
    printf '%*s' "$((width - current))" ''
  fi
}

should_render_table() {
  local min_cols="$1" cols
  [[ "${LEIKWAN_COMPACT:-0}" == "1" || "${LEIKWAN_BRIEF:-0}" == "1" ]] && return 1
  cols="$(terminal_cols)"
  if [[ "${LEIKWAN_TABLE:-0}" == "1" ]]; then
    (( cols >= min_cols )) && return 0
    return 1
  fi
  (( cols >= min_cols ))
}

is_brief_mode() {
  [[ "${LEIKWAN_BRIEF:-0}" == "1" ]]
}

render_tsv_compact() {
  local labels="$1"
  awk -F'\t' -v labels="$labels" '
    BEGIN { split(labels, label, "\t") }
    NF {
      print $1 " " $2
      for (i = 3; i <= NF; i++) {
        value = ($i == "" ? "-" : $i)
        print "   " label[i] ": " value
      }
      print ""
    }
  '
}

render_tsv_table() {
  local min_cols="$1" labels="$2" rows cols tmp
  rows="$(cat || true)"
  [[ -n "$rows" ]] || return 0
  cols="$(terminal_cols)"
  if should_render_table "$min_cols" && command -v python3 >/dev/null 2>&1; then
    tmp="$(mktemp)"
    printf '%s\n' "$rows" >"$tmp"
    if python3 - "$labels" "$cols" "$tmp" <<'PY'
import sys
import unicodedata

labels = sys.argv[1].split("\t")
cols = int(sys.argv[2])
path = sys.argv[3]

with open(path, "r", encoding="utf-8", errors="replace") as fh:
    rows = [line.rstrip("\n").split("\t") for line in fh if line.strip()]

if not rows:
    sys.exit(0)

columns = len(labels)
for row in rows:
    if len(row) < columns:
        row.extend([""] * (columns - len(row)))

def cell_width(value):
    total = 0
    for ch in value:
        if unicodedata.combining(ch):
            continue
        total += 2 if unicodedata.east_asian_width(ch) in ("F", "W") else 1
    return total

def pad(value, width):
    return value + " " * max(width - cell_width(value), 0)

widths = []
for idx, label in enumerate(labels):
    widths.append(max([cell_width(label)] + [cell_width(row[idx]) for row in rows]))

total_width = sum(widths) + (2 * (columns - 1))
if total_width > cols:
    sys.exit(2)

print("  ".join(pad(labels[idx], widths[idx]) for idx in range(columns)))
for row in rows:
    print("  ".join(pad(row[idx], widths[idx]) for idx in range(columns)))
PY
    then
      rm -f "$tmp"
      return 0
    fi
    rm -f "$tmp"
  fi
  render_tsv_compact "$labels" <<<"$rows"
}

print_compact_header() {
  local title="$1"
  echo
  echo "${BOLD}${title}${RESET}"
  echo "----------------------------------------"
}

print_menu_header() {
  local title="$1"
  clear_screen_if_interactive
  print_compact_header "$title"
}

menu_input_required() {
  warn "请输入选项编号。"
  wait_enter_to_return
}

menu_invalid_choice() {
  warn "无效选择。"
  wait_enter_to_return
}

warn_and_pause() {
  warn "$1"
  pause_after_action
}

pause_after_action() {
  if (( MENU_ACTION_PAUSE_DONE == 1 )); then
    MENU_ACTION_PAUSE_DONE=0
    return 0
  fi
  wait_enter_to_return
}

run_menu_action_pause() {
  local rc
  LEIKWAN_LOCK_CONFLICT=0
  set +e
  "$@"
  rc=$?
  set -e
  if (( rc != 0 && LEIKWAN_LOCK_CONFLICT == 1 )); then
    info "操作已跳过，当前已有 Leikwan 任务运行。"
    info "可稍后重试，或执行：lq task status。"
    LEIKWAN_LOCK_CONFLICT=0
    rc=0
  fi
  pause_after_action
  return "$rc"
}

run_menu_action() {
  run_menu_action_pause "$@"
}

run_cli_action() {
  local rc err_trap
  err_trap="$(trap -p ERR || true)"
  trap - ERR
  set +e
  "$@"
  rc=$?
  set -e
  [[ -n "$err_trap" ]] && eval "$err_trap"
  exit "$rc"
}

is_port() {
  local p="$1"
  [[ "$p" =~ ^[0-9]+$ ]] && (( p >= 1 && p <= 65535 ))
}

is_easytier_protocol() {
  case "$1" in
    tcp|udp|ws|wss) return 0 ;;
    *) return 1 ;;
  esac
}

normalize_easytier_protocols() {
  local value="$1"
  value="$(normalize_menu_choice "$value")"
  value="${value,,}"
  value="${value//[[:space:]]/}"
  value="${value//+/,}"
  case "$value" in
    tcp,udp|udp,tcp|dual|both) printf '%s' "tcp,udp" ;;
    tcp|udp) printf '%s' "$value" ;;
    *) return 1 ;;
  esac
}

easytier_protocols_display() {
  local protocols
  protocols="$(normalize_easytier_protocols "$1" 2>/dev/null || printf '%s' "$1")"
  case "$protocols" in
    tcp,udp) printf '%s' "tcp+udp" ;;
    *) printf '%s' "$protocols" ;;
  esac
}

easytier_legacy_protocol() {
  local protocols
  protocols="$(normalize_easytier_protocols "$1")" || return 1
  case ",${protocols}," in
    *,tcp,*) printf '%s' "tcp" ;;
    *,udp,*) printf '%s' "udp" ;;
    *) return 1 ;;
  esac
}

easytier_protocols_has() {
  local protocols="$1" proto="$2"
  protocols="$(normalize_easytier_protocols "$protocols")" || return 1
  [[ ",${protocols}," == *",${proto},"* ]]
}

easytier_urls() {
  local host="$1" protocols="$2" port="$3"
  protocols="$(normalize_easytier_protocols "$protocols")" || return 1
  if easytier_protocols_has "$protocols" tcp; then
    printf 'tcp://%s:%s\n' "$host" "$port"
  fi
  if easytier_protocols_has "$protocols" udp; then
    printf 'udp://%s:%s\n' "$host" "$port"
  fi
}

looks_like_domain() {
  local value="$1"
  [[ "$value" =~ [A-Za-z] && "$value" == *.* ]]
}

is_domain_name() {
  local value="$1"
  [[ -n "$value" && ! "$value" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ && "$value" =~ [A-Za-z] ]]
}

prompt_port() {
  local prompt="$1" default="$2" value
  while true; do
    value="$(prompt_value "$prompt" "$default")"
    is_port "$value" && printf '%s' "$value" && return 0
    echo "端口必须是 1-65535。"
  done
}

prompt_required_port() {
  local prompt="$1" value
  while true; do
    if ! read -r -p "${prompt}: " value; then
      info "检测到非交互输入结束，已退出。"
      exit 0
    fi
    value="$(normalize_menu_choice "$value")"
    if [[ -z "$value" ]]; then
      echo "[WARN] 后端目标端口不能为空，请输入 1-65535。" >&2
      continue
    fi
    is_port "$value" && printf '%s' "$value" && return 0
    echo "[WARN] 端口必须是 1-65535。" >&2
  done
}

prompt_easytier_ip() {
  local prompt="$1" default="$2" value
  while true; do
    value="$(prompt_value "$prompt" "$default")"
    if is_ipv4 "$value"; then
      printf '%s' "$value"
      return 0
    fi
    if looks_like_domain "$value"; then
      warn "你输入的是域名，不是 EasyTier 虚拟 IP。请填写 10.198.1.x 这类虚拟 IP。"
      warn "这里必须填写 EasyTier 虚拟 IP，例如 ${default}；DDNS 域名请在后面的 本机公网 IP / 域名 填写。"
    else
      warn "EasyTier IP 必须是 IPv4：${value}"
      warn "这里必须填写 EasyTier 虚拟 IP，例如 ${default}；DDNS 域名请在后面的 本机公网 IP / 域名 填写。"
    fi
  done
}

prompt_easytier_protocols() {
  local prompt="$1" default="$2" value
  while true; do
    value="$(prompt_value "$prompt" "$(easytier_protocols_display "$default")")"
    if value="$(normalize_easytier_protocols "$value")"; then
      printf '%s' "$value"
      return 0
    fi
    warn "EasyTier 传输模式无效。请输入 tcp、udp 或 tcp+udp。"
  done
}

prompt_easytier_protocol() {
  prompt_easytier_protocols "$@"
}

is_ipv4() {
  local ip="$1" a b c d
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS=. read -r a b c d <<<"$ip"
  for x in "$a" "$b" "$c" "$d"; do (( x >= 0 && x <= 255 )) || return 1; done
}

normalize_ipv4_cidr() {
  local value="$1" ip prefix
  value="$(normalize_menu_choice "$value")"
  [[ -n "$value" ]] || return 1
  if [[ "$value" == */* ]]; then
    ip="${value%/*}"
    prefix="${value#*/}"
    is_ipv4 "$ip" || return 1
    [[ "$prefix" =~ ^[0-9]+$ ]] || return 1
    (( prefix >= 0 && prefix <= 32 )) || return 1
    printf '%s/%s' "$ip" "$prefix"
  else
    is_ipv4 "$value" || return 1
    printf '%s/32' "$value"
  fi
}

prompt_host() {
  local prompt="$1" default="${2:-}" value
  while true; do
    value="$(prompt_value "$prompt" "$default")"
    [[ -n "$value" && ! "$value" =~ [[:space:]/] ]] && printf '%s' "$value" && return 0
    echo "请输入 IP 或域名，不要包含协议、端口或空格。"
  done
}

safe_name() {
  local name="$1"
  name="$(normalize_menu_choice "$name")"
  if [[ "$name" =~ ^公网([0-9]+)$ ]]; then
    printf 'public%s' "${BASH_REMATCH[1]}"
    return 0
  fi
  name="${name// /-}"
  name="$(printf '%s' "$name" | sed -E 's/[^A-Za-z0-9_.-]+/-/g; s/^-+//; s/-+$//')"
  [[ -n "$name" ]] || name="default"
  printf '%s' "$name"
}

entry_display_name() {
  local name="$1"
  if [[ "$name" =~ ^public([0-9]+)$ ]]; then
    printf '公网%s' "${BASH_REMATCH[1]}"
  else
    printf '%s' "$name"
  fi
}

entry_label() {
  local name="$1" display
  display="$(entry_display_name "$name")"
  if [[ "$display" != "$name" ]]; then
    printf '%s(%s)' "$display" "$name"
  else
    printf '%s' "$name"
  fi
}

normalize_entry_selector() {
  local value="$1"
  value="$(normalize_menu_choice "$value")"
  if [[ "$value" =~ ^公网([0-9]+)$ ]]; then
    printf 'public%s' "${BASH_REMATCH[1]}"
  else
    printf '%s' "$value"
  fi
}

backup_safe_name() {
  local path="$1" safe
  safe="${path#/}"
  safe="${safe//\//__}"
  printf '%s' "$safe"
}

latest_backup_for_file() {
  local path="$1" safe latest
  safe="$(backup_safe_name "$path")"
  latest="$(find "$BACKUP_DIR" -maxdepth 1 -type f -name "${safe}.*.bak" -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR==1 {sub(/^[^ ]+ /,""); print}' || true)"
  [[ -n "$latest" ]] && printf '%s' "$latest"
}

latest_backup_any() {
  local latest
  latest="$(find "$BACKUP_DIR" -maxdepth 1 -type f -name '*.bak' -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR==1 {sub(/^[^ ]+ /,""); print}' || true)"
  [[ -n "$latest" ]] && printf '%s' "$latest" || printf '-'
}

backup_file() {
  local path="$1" safe dest
  [[ -e "$path" ]] || return 0
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] 备份 ${path}"
    return 0
  fi
  mkdir -p "$BACKUP_DIR"
  safe="$(backup_safe_name "$path")"
  dest="${BACKUP_DIR}/${safe}.$(date '+%Y%m%d-%H%M%S').bak"
  cp -a "$path" "$dest"
  ok "已备份 ${path} -> ${dest}"
}

write_file() {
  local path="$1" content="$2" mode="${3:-600}" tmp dir
  if (( DRY_RUN == 1 )); then
    echo
    echo "${BOLD}[DRY-RUN] ${path}${RESET}"
    printf '%s\n' "$content"
    return 0
  fi
  dir="$(dirname "$path")"
  mkdir -p "$dir"
  tmp="$(mktemp "${dir}/.tmp.$(basename "$path").XXXXXX")"
  printf '%s\n' "$content" >"$tmp"
  if [[ -f "$path" ]] && cmp -s "$tmp" "$path"; then
    rm -f "$tmp"
    return 0
  fi
  backup_file "$path"
  if ! install -m "$mode" "$tmp" "$path"; then
    rm -f "$tmp"
    return 1
  fi
  rm -f "$tmp"
  ok "已写入 ${path}"
}

write_file_from_path() {
  local path="$1" source="$2" mode="${3:-600}" tmp dir
  if (( DRY_RUN == 1 )); then
    echo
    echo "${BOLD}[DRY-RUN] ${path}${RESET}"
    cat "$source" 2>/dev/null || true
    return 0
  fi
  dir="$(dirname "$path")"
  mkdir -p "$dir"
  tmp="$(mktemp "${dir}/.tmp.$(basename "$path").XXXXXX")"
  if ! cp "$source" "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  if [[ -f "$path" ]] && cmp -s "$tmp" "$path"; then
    rm -f "$tmp"
    return 0
  fi
  backup_file "$path"
  if ! install -m "$mode" "$tmp" "$path"; then
    rm -f "$tmp"
    return 1
  fi
  rm -f "$tmp"
  ok "已写入 ${path}"
}

make_state_tmp() {
  local dir="$1" prefix="${2:-tmp}"
  mkdir -p "$dir"
  mktemp "${dir}/.tmp.${prefix}.XXXXXX"
}

make_temp_file() {
  local prefix="${1:-leikwan}" dir tmp
  for dir in "${TMPDIR:-}" /tmp "${LEIKWAN_TMP_DIR:-}" "${PWD}/.tmp" "${STATE_DIR}/tmp"; do
    [[ -n "$dir" ]] || continue
    mkdir -p "$dir" 2>/dev/null || continue
    [[ -w "$dir" ]] || continue
    tmp="$(mktemp "${dir}/${prefix}.XXXXXX" 2>/dev/null)" && { printf '%s' "$tmp"; return 0; }
  done
  mktemp
}

make_temp_dir() {
  local prefix="${1:-leikwan}" dir tmp
  for dir in "${TMPDIR:-}" /tmp "${LEIKWAN_TMP_DIR:-}" "${PWD}/.tmp" "${STATE_DIR}/tmp"; do
    [[ -n "$dir" ]] || continue
    mkdir -p "$dir" 2>/dev/null || continue
    [[ -w "$dir" ]] || continue
    tmp="$(mktemp -d "${dir}/${prefix}.XXXXXX" 2>/dev/null)" && { printf '%s' "$tmp"; return 0; }
  done
  mktemp -d
}

confirm_summary() {
  local title="$1" summary="$2"
  echo
  echo "${BOLD}${title}${RESET}"
  echo "----------------------------------------"
  printf '%b\n' "$summary"
  echo "----------------------------------------"
  if (( DRY_RUN == 1 )); then
    prompt_yes_no "确认生成以上预览吗？" "Y"
  else
    prompt_yes_no "确认写入 / 执行吗？" "N"
  fi
}

print_banner() {
  cat <<EOF
Leikwan Toolkit $(tool_version_label)
${PROJECT_TITLE}
GitHub: ${PROJECT_GITHUB}
-------------------------------------------------
EOF
}

print_help() {
  cat <<EOF
${PROJECT_NAME} $(tool_version_label)

用法：
  sudo bash leikwan-toolkit.sh
  sudo bash leikwan-toolkit.sh init [--dry-run|--plan]
  sudo bash leikwan-toolkit.sh wizard
  sudo bash leikwan-toolkit.sh quickstart
  sudo bash leikwan-toolkit.sh plan
  sudo bash leikwan-toolkit.sh status
  sudo bash leikwan-toolkit.sh status --verbose
  sudo bash leikwan-toolkit.sh status --brief
  sudo bash leikwan-toolkit.sh --brief
  sudo bash leikwan-toolkit.sh status --json
  sudo bash leikwan-toolkit.sh --status
  sudo bash leikwan-toolkit.sh --status-json
  sudo bash leikwan-toolkit.sh --doctor
  sudo bash leikwan-toolkit.sh --doctor --auto-fix
  sudo bash leikwan-toolkit.sh --doctor --verbose
  sudo bash leikwan-toolkit.sh doctor --auto-fix
  sudo bash leikwan-toolkit.sh doctor --json
  sudo bash leikwan-toolkit.sh --doctor-auto-fix
  sudo bash leikwan-toolkit.sh --doctor-json
  sudo bash leikwan-toolkit.sh port check
  sudo bash leikwan-toolkit.sh --port-check
  sudo bash leikwan-toolkit.sh config export [--full|--redacted]
  sudo bash leikwan-toolkit.sh config inspect /path/to/leikwan-config.tar.gz
  sudo bash leikwan-toolkit.sh config import /path/to/leikwan-config.tar.gz [--mode config-only|apply|full] [--yes]
  sudo bash leikwan-toolkit.sh config list
  sudo bash leikwan-toolkit.sh output generate|show|json|html|qr
  sudo bash leikwan-toolkit.sh pair relay-init
  sudo bash leikwan-toolkit.sh pair entry-join [pairing-file|-]
  sudo bash leikwan-toolkit.sh pair relay-join [pairing-file|-]
  sudo bash leikwan-toolkit.sh pair status
  sudo bash leikwan-toolkit.sh system network status
  sudo bash leikwan-toolkit.sh system network prepare
  sudo bash leikwan-toolkit.sh system ipv4-prefer enable|disable|status
  sudo bash leikwan-toolkit.sh system dns status|set 8.8.8.8,1.1.1.1|restore
  sudo bash leikwan-toolkit.sh system ipv6 status|disable|restore|lockdown
  sudo bash leikwan-toolkit.sh system bbr status|enable|restore
  sudo bash leikwan-toolkit.sh entry expose-range [--range 10000-19999] [--relay-ip 10.198.1.1]
  sudo bash leikwan-toolkit.sh entry ddns status|setup|run|enable|disable|logs
  sudo bash leikwan-toolkit.sh forward add
  sudo bash leikwan-toolkit.sh forward edit [name]
  sudo bash leikwan-toolkit.sh forward delete [name]
  sudo bash leikwan-toolkit.sh forward list
  sudo bash leikwan-toolkit.sh forward bundle-export
  sudo bash leikwan-toolkit.sh forward import [pairing-file|-]
  sudo bash leikwan-toolkit.sh entry import [pairing-file|-]
  sudo bash leikwan-toolkit.sh forward apply-relay
  sudo bash leikwan-toolkit.sh forward apply-relay --auto-fix-route
  sudo bash leikwan-toolkit.sh pbr delete 203.0.113.10/32
  sudo bash leikwan-toolkit.sh pbr edit [cidr-or-index]
  sudo bash leikwan-toolkit.sh pbr sync-from-forwards
  sudo bash leikwan-toolkit.sh pbr domain add|list|delete|sync
  sudo bash leikwan-toolkit.sh update        # 等价于 update run
  sudo bash leikwan-toolkit.sh update check
  sudo bash leikwan-toolkit.sh update run
  sudo bash leikwan-toolkit.sh update status
  sudo bash leikwan-toolkit.sh update rollback
  sudo bash leikwan-toolkit.sh task status
  sudo bash leikwan-toolkit.sh task unlock-stale
  sudo bash leikwan-toolkit.sh ddns run
  sudo bash leikwan-toolkit.sh ddns run --global
  sudo bash leikwan-toolkit.sh ddns run --scope forwards|entries|pbr|all
  sudo bash leikwan-toolkit.sh ddns overview
  sudo bash leikwan-toolkit.sh ddns apply-entries
  sudo bash leikwan-toolkit.sh ddns check-consistency
  sudo bash leikwan-toolkit.sh ddns entry status|setup|run|enable|disable|logs
  sudo bash leikwan-toolkit.sh ddns status
  sudo bash leikwan-toolkit.sh ddns enable
  sudo bash leikwan-toolkit.sh ddns disable
  sudo bash leikwan-toolkit.sh ddns logs
  sudo bash leikwan-toolkit.sh logs [ddns|entry-ddns|apply|update|doctor|clean]
  sudo bash leikwan-toolkit.sh --self-update
  sudo bash leikwan-toolkit.sh --update-check
  sudo bash leikwan-toolkit.sh --ddns-run
  sudo bash leikwan-toolkit.sh --pbr-apply
  sudo bash leikwan-toolkit.sh --pbr-delete 203.0.113.10/32
  sudo bash leikwan-toolkit.sh uninstall [normal|deep]
  sudo bash leikwan-toolkit.sh --uninstall
  bash leikwan-toolkit.sh --help
  bash leikwan-toolkit.sh --version

定位：
  公网入口 + 利群主机 + 后端目标的三段 TCP/UDP 转发组网工具。
  传输层使用 EasyTier，转发层使用 nftables。
  默认 EasyTier 虚拟网段：${ET_NET}，relay：${RELAY_ET_IP}。
  默认 EasyTier 传输：TCP+UDP / ${DEFAULT_EASYTIER_PORT}，位于利群推荐白名单 ${FAST_PORT_RANGE_START}-${FAST_PORT_RANGE_END}。
  DDNS 是域名解析变化自动刷新：定时解析公网入口、转发目标和 PBR 域名，并刷新本地转发 / PBR；默认不修改 DNS 服务商记录。
  自更新只从 GitHub Release 包更新，并校验 sha256。
  不部署后端协议，不生成代理客户端链接。

一键安装：
  curl -fsSL -o /tmp/lq-bootstrap.sh https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/scripts/bootstrap.sh
  bash /tmp/lq-bootstrap.sh

国内推荐：
  export LEIKWAN_GITHUB_DOWNLOAD_MODE=mirror-first
  export LEIKWAN_GITHUB_MIRRORS="${LEIKWAN_GITHUB_MIRRORS_DEFAULT}"
  curl -fsSL -o /tmp/lq-bootstrap.sh https://gh-proxy.com/https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/scripts/bootstrap.sh
  bash /tmp/lq-bootstrap.sh

GitHub 下载策略：
  默认 LEIKWAN_GITHUB_DOWNLOAD_MODE=mirror-first，先尝试镜像池，官方 GitHub 兜底。
  如需改回官方优先，可设置 LEIKWAN_GITHUB_DOWNLOAD_MODE=origin-first。
EOF
}

migrate_legacy_paths() {
  (( DRY_RUN == 1 )) && return 0
  if [[ -d "$OLD_STATE_DIR" ]]; then
    if [[ ! -e "$STATE_DIR" ]]; then
      mkdir -p "$(dirname "$STATE_DIR")"
      mv "$OLD_STATE_DIR" "$STATE_DIR"
      ok "已迁移状态目录：${OLD_STATE_DIR} -> ${STATE_DIR}"
    else
      warn "检测到旧状态目录 ${OLD_STATE_DIR}；当前优先使用 ${STATE_DIR}，确认无用后可清理旧目录。"
    fi
  fi
  if [[ -d "$OLD_BACKUP_DIR" ]]; then
    if [[ ! -e "$BACKUP_DIR" ]]; then
      mkdir -p "$(dirname "$BACKUP_DIR")"
      mv "$OLD_BACKUP_DIR" "$BACKUP_DIR"
      ok "已迁移备份目录：${OLD_BACKUP_DIR} -> ${BACKUP_DIR}"
    else
      warn "检测到旧备份目录 ${OLD_BACKUP_DIR}；当前优先使用 ${BACKUP_DIR}。"
    fi
  fi
  if [[ -f "$OLD_LOG_FILE" ]]; then
    if [[ ! -e "$LOG_FILE" ]]; then
      mkdir -p "$(dirname "$LOG_FILE")"
      mv "$OLD_LOG_FILE" "$LOG_FILE"
      ok "已迁移日志文件：${OLD_LOG_FILE} -> ${LOG_FILE}"
    else
      warn "检测到旧日志文件 ${OLD_LOG_FILE}；当前优先使用 ${LOG_FILE}。"
    fi
  fi
}

ensure_base_dirs() {
  if (( DRY_RUN == 0 )); then
    migrate_legacy_paths
    if ! install -d -m 700 "$STATE_DIR" "$ENTRY_DIR" "$ENTRIES_DIR" "$FORWARDS_DIR" "$OUTPUT_DIR" "$NFT_DIR" "$PBR_DIR" "$EASYTIER_DIR" "$STATUS_DIR" "$SNAPSHOT_DIR" "$AUTO_SNAPSHOT_DIR" 2>/dev/null; then
      mkdir -p "$STATE_DIR" "$ENTRY_DIR" "$ENTRIES_DIR" "$FORWARDS_DIR" "$OUTPUT_DIR" "$NFT_DIR" "$PBR_DIR" "$EASYTIER_DIR" "$STATUS_DIR" "$SNAPSHOT_DIR" "$AUTO_SNAPSHOT_DIR"
      chmod 700 "$STATE_DIR" "$ENTRY_DIR" "$ENTRIES_DIR" "$FORWARDS_DIR" "$OUTPUT_DIR" "$NFT_DIR" "$PBR_DIR" "$EASYTIER_DIR" "$STATUS_DIR" "$SNAPSHOT_DIR" "$AUTO_SNAPSHOT_DIR" 2>/dev/null || true
    fi
  fi
}

package_command() {
  case "$1" in
    iproute2) printf '%s' ip ;;
    curl) printf '%s' curl ;;
    jq) printf '%s' jq ;;
    tar) printf '%s' tar ;;
    unzip) printf '%s' unzip ;;
    nftables) printf '%s' nft ;;
    netcat-openbsd) printf '%s' nc ;;
    dnsutils) printf '%s' dig ;;
    ca-certificates) printf '%s' "" ;;
    coreutils) printf '%s' base64 ;;
    openssl) printf '%s' openssl ;;
    *) printf '%s' "$1" ;;
  esac
}

install_packages() {
  local packages=("$@") missing=() pkg cmd
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] apt-get install ${packages[*]}"
    return 0
  fi
  for pkg in "${packages[@]}"; do
    case " ${DEPS_INSTALLED_THIS_RUN} " in *" ${pkg} "*) continue ;; esac
    cmd="$(package_command "$pkg")"
    if [[ -n "$cmd" ]] && command -v "$cmd" >/dev/null 2>&1; then
      continue
    fi
    if [[ -z "$cmd" && -f "$DEPS_MARKER" ]]; then
      continue
    fi
    missing+=("$pkg")
  done
  ((${#missing[@]} > 0)) || return 0
  if ! command -v apt-get >/dev/null 2>&1; then
    warn "未找到 apt-get，无法自动安装依赖：${missing[*]}"
    return 1
  fi
  ensure_base_dirs
  export DEBIAN_FRONTEND=noninteractive
  if (( DEPS_APT_UPDATED == 0 )); then
    if ! apt-get update; then
      warn "apt-get update 失败，依赖无法自动安装：${missing[*]}"
      warn "如果 apt 源返回 403 或 mirror sync in progress，请换源、稍后重试，或手动安装对应 deb 包后重试。"
      return 1
    fi
    DEPS_APT_UPDATED=1
  fi
  if ! apt-get install -y "${missing[@]}"; then
    warn "apt 安装依赖失败：${missing[*]}"
    warn "如果 apt 源返回 403 或 mirror sync in progress，请换源、稍后重试，或手动安装对应 deb 包后重试。"
    return 1
  fi
  for pkg in "${missing[@]}"; do
    cmd="$(package_command "$pkg")"
    [[ -z "$cmd" ]] && continue
    if ! command -v "$cmd" >/dev/null 2>&1; then
      warn "依赖 ${pkg} 安装后仍未找到命令：${cmd}"
      return 1
    fi
  done
  for pkg in "${missing[@]}"; do
    DEPS_INSTALLED_THIS_RUN="${DEPS_INSTALLED_THIS_RUN} ${pkg}"
  done
  date '+%F %T' >"$DEPS_MARKER"
}

doctor_should_offer_dnsutils() {
  local timer_state ddns_enabled
  command -v dig >/dev/null 2>&1 && return 1
  ddns_enabled="$(ddns_config_value DDNS_GLOBAL_ENABLED "$DDNS_GLOBAL_ENABLED_DEFAULT")"
  timer_state="$(ddns_timer_state 2>/dev/null || true)"
  [[ "${ddns_enabled,,}" == "true" || "$timer_state" == "active" ]] && return 0
  (( $(ddns_domain_forward_count 2>/dev/null || printf '0') + $(ddns_domain_entry_count 2>/dev/null || printf '0') + $(ddns_domain_pbr_count 2>/dev/null || printf '0') > 0 ))
}

doctor_auto_fix_dnsutils() {
  command -v dig >/dev/null 2>&1 && return 0
  dnsutils_auto_install "doctor" "true" "plain" || true
}

dnsutils_emit_line() {
  local emitter="$1" level="$2" message="$3"
  case "$emitter" in
    ddns)
      ddns_emit "$level" "$message"
      ;;
    plain)
      case "$level" in
        OK) ok "$message" ;;
        WARN) warn "$message" ;;
        FAIL) fail "$message" ;;
        *) info "$message" ;;
      esac
      ;;
    *)
      case "$level" in
        OK) ok "$message" ;;
        WARN) warn "$message" ;;
        FAIL) fail "$message" ;;
        *) info "$message" ;;
      esac
      ;;
  esac
}

dnsutils_auto_install() {
  local _context="${1:-ddns}" force="${2:-false}" emitter="${3:-ddns}"
  command -v dig >/dev/null 2>&1 && return 0
  if [[ "${DDNS_DNSUTILS_INSTALL_ATTEMPTED:-false}" == "true" && "$force" != "true" ]]; then
    return 1
  fi
  DDNS_DNSUTILS_INSTALL_ATTEMPTED=true
  if [[ "$force" == "true" ]] || { [[ ${EUID:-$(id -u)} -eq 0 ]] && command -v apt-get >/dev/null 2>&1; }; then
    dnsutils_emit_line "$emitter" WARN "dig 不存在，正在安装 dnsutils 以启用多 DNS 解析器检测..."
    if install_packages dnsutils; then
      dnsutils_emit_line "$emitter" OK "dnsutils 已安装。"
      return 0
    fi
    dnsutils_emit_line "$emitter" WARN "dnsutils 安装失败，将使用 nslookup / host / getent fallback。"
    return 1
  fi
  dnsutils_emit_line "$emitter" WARN "dig 不存在，无法自动安装 dnsutils（需要 root + apt-get），将使用 nslookup / host / getent fallback。"
  return 1
}

extract_first_ipv4() {
  local input="$1"
  while IFS= read -r ip; do
    if is_ipv4 "$ip"; then
      printf '%s' "$ip"
      return 0
    fi
  done < <(printf '%s\n' "$input" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' 2>/dev/null || true)
}

extract_first_ipv4_except() {
  local input="$1" skip="$2" ip
  while IFS= read -r ip; do
    if is_ipv4 "$ip" && [[ "$ip" != "$skip" ]]; then
      printf '%s' "$ip"
      return 0
    fi
  done < <(printf '%s\n' "$input" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' 2>/dev/null || true)
}

public_ip_check_urls() {
  local value="${1:-}" url
  local -a urls
  [[ -n "$value" ]] || value="$(ddns_config_value PUBLIC_IP_CHECK_URLS "$PUBLIC_IP_CHECK_URLS_DEFAULT" 2>/dev/null || printf '%s' "$PUBLIC_IP_CHECK_URLS_DEFAULT")"
  value="${value//$'\n'/,}"
  value="${value//$'\r'/,}"
  IFS=',' read -ra urls <<<"$value"
  for url in "${urls[@]}"; do
    url="$(trim_spaces "$url")"
    [[ -n "$url" ]] && printf '%s\n' "$url"
  done
}

detect_public_ipv4() {
  local urls="${1:-}" url response ip rc reason found_failure=0
  DDNS_PUBLIC_IP=""
  DDNS_PUBLIC_IP_SOURCE=""
  DDNS_PUBLIC_IP_FAILED=false
  if ! command -v curl >/dev/null 2>&1; then
    DDNS_PUBLIC_IP_FAILED=true
    ddns_log_quiet WARN "公网 IP 检测失败：缺少 curl。"
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    if is_ipv4 "$ip"; then
      DDNS_PUBLIC_IP="$ip"
      DDNS_PUBLIC_IP_SOURCE="hostname -I"
      printf '%s' "$ip"
      return 0
    fi
    return 1
  fi
  while IFS= read -r url; do
    [[ -n "$url" ]] || continue
    response="$(curl -4 -fsS --connect-timeout 5 --max-time 5 "$url" 2>&1)"
    rc=$?
    if (( rc == 0 )); then
      ip="$(extract_first_ipv4 "$response")"
      if [[ -n "$ip" ]]; then
        DDNS_PUBLIC_IP="$ip"
        DDNS_PUBLIC_IP_SOURCE="$url"
        printf '%s' "$ip"
        return 0
      fi
      found_failure=1
      ddns_log_quiet WARN "公网 IP 检测源返回无效响应：${url}"
    else
      found_failure=1
      reason="$(printf '%s' "$response" | tr '\r\n' '  ' | cut -c1-160)"
      ddns_log_quiet WARN "公网 IP 检测源失败：${url} ${reason:-curl rc=${rc}}"
    fi
  done < <(public_ip_check_urls "$urls")
  DDNS_PUBLIC_IP_FAILED=true
  (( found_failure == 1 )) && ddns_log_quiet WARN "公网 IP 检测全部失败；保留现有配置。"
  return 1
}

env_file_get() {
  local file="$1" key="$2"
  [[ -f "$file" ]] || return 0
  awk -F= -v k="$key" '
    $1 == k {
      sub(/^[^=]*=/, "")
      gsub(/\r$/, "")
      print
      exit
    }
  ' "$file" 2>/dev/null || true
}

status_now() {
  date '+%F %T'
}

write_status_cache() {
  local kind="$1" result="$2" action="${3:-}" file prefix
  (( DRY_RUN == 1 )) && return 0
  [[ ${EUID:-$(id -u)} -eq 0 ]] || return 0
  [[ -d "$STATE_DIR" ]] || return 0
  mkdir -p "$STATUS_DIR" 2>/dev/null || return 0
  case "$kind" in
    apply) file="${STATUS_DIR}/last-apply.env"; prefix="LAST_APPLY" ;;
    doctor) file="${STATUS_DIR}/last-doctor.env"; prefix="LAST_DOCTOR" ;;
    status) file="${STATUS_DIR}/last-status.env"; prefix="LAST_STATUS" ;;
    *) return 0 ;;
  esac
  {
    printf '%s_TIME=%s\n' "$prefix" "$(status_now)"
    [[ -n "$action" ]] && printf '%s_ACTION=%s\n' "$prefix" "$action"
    printf '%s_RESULT=%s\n' "$prefix" "$result"
    printf '%s_VERSION=%s\n' "$prefix" "$TOOL_VERSION"
  } >"$file"
  chmod 600 "$file" 2>/dev/null || true
}

write_named_status() {
  local file="$1" prefix="$2" result="$3" mode="${4:-}" path="${5:-}"
  (( DRY_RUN == 1 )) && return 0
  [[ ${EUID:-$(id -u)} -eq 0 ]] || return 0
  mkdir -p "$STATUS_DIR" 2>/dev/null || return 0
  {
    printf '%s_TIME=%s\n' "$prefix" "$(status_now)"
    [[ -n "$mode" ]] && printf '%s_MODE=%s\n' "$prefix" "$mode"
    [[ -n "$path" ]] && printf '%s_PATH=%s\n' "$prefix" "$path"
    printf '%s_RESULT=%s\n' "$prefix" "$result"
    printf '%s_VERSION=%s\n' "$prefix" "$TOOL_VERSION"
  } >"$file"
  chmod 600 "$file" 2>/dev/null || true
}

status_result_from_counts() {
  if (( REPORT_FAIL_COUNT > 0 )); then
    printf 'fail'
  elif (( REPORT_WARN_COUNT > 0 )); then
    printf 'warn'
  else
    printf 'ok'
  fi
}

status_result_display() {
  case "${1,,}" in
    ok) printf 'OK' ;;
    warn) printf 'WARN' ;;
    fail) printf 'FAIL' ;;
    *) printf '%s' "${1:-unknown}" ;;
  esac
}

tool_version_label() {
  if [[ -n "${RELEASE_CHANNEL:-}" ]]; then
    printf '%s %s' "$TOOL_VERSION" "$RELEASE_CHANNEL"
  else
    printf '%s' "$TOOL_VERSION"
  fi
}

pid_is_alive() {
  local pid="$1"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

process_cmdline() {
  local pid="$1" cmd=""
  if [[ -r "/proc/${pid}/cmdline" ]]; then
    cmd="$(tr '\0' ' ' <"/proc/${pid}/cmdline" 2>/dev/null | sed 's/[[:space:]]*$//')"
  fi
  if [[ -z "$cmd" ]] && command -v ps >/dev/null 2>&1; then
    cmd="$(ps -p "$pid" -o args= 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  fi
  printf '%s' "${cmd:-未知}"
}

process_elapsed_seconds() {
  local pid="$1" elapsed=""
  if command -v ps >/dev/null 2>&1; then
    elapsed="$(ps -p "$pid" -o etimes= 2>/dev/null | tr -d '[:space:]')"
  fi
  [[ "$elapsed" =~ ^[0-9]+$ ]] || elapsed=""
  printf '%s' "$elapsed"
}

format_duration_seconds() {
  local seconds="${1:-}"
  [[ "$seconds" =~ ^[0-9]+$ ]] || { printf '%s' "-"; return 0; }
  if (( seconds < 60 )); then
    printf '%ss' "$seconds"
  elif (( seconds < 3600 )); then
    printf '%sm%ss' "$((seconds / 60))" "$((seconds % 60))"
  else
    printf '%sh%sm%ss' "$((seconds / 3600))" "$(((seconds % 3600) / 60))" "$((seconds % 60))"
  fi
}

process_is_leikwan_task() {
  local pid="$1" cmd
  cmd="$(process_cmdline "$pid")"
  case "$cmd" in
    *leikwan-toolkit*|*" lq "*|*/lq*|*bash*|*sh*) return 0 ;;
    *) return 1 ;;
  esac
}

lock_read_pid() {
  local lock_path="$1" pid=""
  if [[ -f "${lock_path}.pid" ]]; then
    pid="$(head -n 1 "${lock_path}.pid" 2>/dev/null || true)"
  elif [[ -f "${lock_path}.d/pid" ]]; then
    pid="$(head -n 1 "${lock_path}.d/pid" 2>/dev/null || true)"
  fi
  pid="$(normalize_menu_choice "$pid")"
  printf '%s' "$pid"
}

lock_files_exist() {
  local lock_path="$1"
  [[ -e "$lock_path" || -e "${lock_path}.pid" || -e "${lock_path}.meta" || -d "${lock_path}.d" ]]
}

lock_is_stale() {
  local lock_path="$1" pid
  lock_files_exist "$lock_path" || return 1
  pid="$(lock_read_pid "$lock_path")"
  [[ -n "$pid" && "$pid" =~ ^[0-9]+$ ]] || return 0
  pid_is_alive "$pid" || return 0
  process_is_leikwan_task "$pid" || return 0
  return 1
}

lock_remove_files() {
  local lock_path="$1"
  rm -f "$lock_path" "${lock_path}.pid" "${lock_path}.meta" 2>/dev/null || true
  rm -rf "${lock_path}.d" 2>/dev/null || true
}

lock_current_command() {
  local cmd
  cmd="$(process_cmdline "$$")"
  [[ "$cmd" != "未知" && -n "$cmd" ]] || cmd="${0:-leikwan-toolkit.sh} $*"
  printf '%s' "$cmd"
}

lock_log_hint_for_cmd() {
  local cmd="$1" label="${2:-}" hints=()
  case "${cmd} ${label}" in
    *apply-relay*|*"转发"*|*"PBR"*) hints+=("$APPLY_RELAY_LOG") ;;
  esac
  case "${cmd} ${label}" in
    *ddns*|*"DDNS"*) hints+=("$DDNS_LOG_FILE") ;;
  esac
  case "${cmd} ${label}" in
    *update*|*"更新"*) hints+=("$LOG_FILE") ;;
  esac
  case "${cmd} ${label}" in
    *doctor*|*"诊断"*) hints+=("$LOG_FILE") ;;
  esac
  (( ${#hints[@]} > 0 )) || hints+=("$LOG_FILE")
  local out="" item
  for item in "${hints[@]}"; do
    [[ -n "$item" ]] || continue
    [[ ",${out}," == *",${item},"* ]] && continue
    out="${out:+${out},}${item}"
  done
  printf '%s' "$out"
}

lock_write_owner_meta() {
  local lock_path="$1" label="$2" cmd
  cmd="$(lock_current_command)"
  {
    printf 'PID=%s\n' "$$"
    printf 'LABEL=%s\n' "$label"
    printf 'STARTED_AT=%s\n' "$(status_now)"
    printf 'COMMAND=%s\n' "$cmd"
    printf 'LOG_HINT=%s\n' "$(lock_log_hint_for_cmd "$cmd" "$label")"
  } >"${lock_path}.meta" 2>/dev/null || true
}

lock_meta_value() {
  local lock_path="$1" key="$2"
  [[ -f "${lock_path}.meta" ]] || return 1
  awk -F= -v k="$key" '$1==k {sub(/^[^=]*=/, ""); print; exit}' "${lock_path}.meta" 2>/dev/null
}

lock_owner_command() {
  local lock_path="$1" pid="$2" cmd
  cmd="$(lock_meta_value "$lock_path" COMMAND 2>/dev/null || true)"
  [[ -n "$cmd" ]] || cmd="$(process_cmdline "$pid")"
  printf '%s' "${cmd:-未知}"
}

lock_owner_log_hint() {
  local lock_path="$1" label="${2:-}" cmd="$3" hint
  hint="$(lock_meta_value "$lock_path" LOG_HINT 2>/dev/null || true)"
  [[ -n "$hint" ]] || hint="$(lock_log_hint_for_cmd "$cmd" "$label")"
  printf '%s' "$hint"
}

lock_owner_inline() {
  local lock_path="$1" label="${2:-任务}" pid cmd elapsed
  pid="$(lock_read_pid "$lock_path")"
  if [[ -z "$pid" ]]; then
    printf 'PID=未知 command=未知'
    return 0
  fi
  cmd="$(lock_owner_command "$lock_path" "$pid")"
  elapsed="$(format_duration_seconds "$(process_elapsed_seconds "$pid")")"
  printf 'PID=%s command=%s elapsed=%s' "$pid" "$cmd" "$elapsed"
}

lock_print_owner_info() {
  local lock_path="$1" label="${2:-任务}" pid cmd elapsed hint
  info "锁文件：${lock_path}"
  pid="$(lock_read_pid "$lock_path")"
  if [[ -n "$pid" ]]; then
    info "持有进程：PID=${pid}"
    cmd="$(lock_owner_command "$lock_path" "$pid")"
    info "命令：${cmd}"
    elapsed="$(format_duration_seconds "$(process_elapsed_seconds "$pid")")"
    info "已运行：${elapsed}"
    hint="$(lock_owner_log_hint "$lock_path" "$label" "$cmd")"
    [[ -n "$hint" ]] && info "可查看日志：${hint}"
  else
    info "持有进程：未知（缺少 PID）"
  fi
  info "稍后重试，或执行：lq task status"
}

lock_cleanup_stale_if_possible() {
  local lock_path="$1"
  if lock_is_stale "$lock_path"; then
    lock_remove_files "$lock_path"
    warn "检测到遗留任务锁，已自动清理。"
    return 0
  fi
  return 0
}

lock_acquire() {
  local lock_path="$1" label="$2" out_var="$3" fd token lock_dir pid
  mkdir -p "$(dirname "$lock_path")" 2>/dev/null || true
  lock_cleanup_stale_if_possible "$lock_path"
  if command -v flock >/dev/null 2>&1; then
    exec {fd}>"$lock_path"
    if flock -n "$fd"; then
      printf '%s\n' "$$" >"${lock_path}.pid" 2>/dev/null || true
      lock_write_owner_meta "$lock_path" "$label"
      printf -v "$out_var" 'flock:%s:%s' "$fd" "$lock_path"
      return 0
    fi
    pid="$(head -n 1 "${lock_path}.pid" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && ! pid_is_alive "$pid"; then
      warn "检测到 stale lock，已清理。"
      rm -f "$lock_path" "${lock_path}.pid" 2>/dev/null || true
      eval "exec ${fd}>&-" 2>/dev/null || true
      exec {fd}>"$lock_path"
      if flock -n "$fd"; then
        printf '%s\n' "$$" >"${lock_path}.pid" 2>/dev/null || true
        lock_write_owner_meta "$lock_path" "$label"
        printf -v "$out_var" 'flock:%s:%s' "$fd" "$lock_path"
        return 0
      fi
    fi
    eval "exec ${fd}>&-"
  else
    lock_dir="${lock_path}.d"
    if mkdir "$lock_dir" 2>/dev/null; then
      printf '%s\n' "$$" >"${lock_dir}/pid" 2>/dev/null || true
      lock_write_owner_meta "$lock_path" "$label"
      printf -v "$out_var" 'mkdir:%s' "$lock_dir"
      return 0
    fi
    pid="$(head -n 1 "${lock_dir}/pid" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && ! pid_is_alive "$pid"; then
      warn "检测到 stale lock，已清理。"
      rm -rf "$lock_dir" 2>/dev/null || true
      if mkdir "$lock_dir" 2>/dev/null; then
        printf '%s\n' "$$" >"${lock_dir}/pid" 2>/dev/null || true
        lock_write_owner_meta "$lock_path" "$label"
        printf -v "$out_var" 'mkdir:%s' "$lock_dir"
        return 0
      fi
    fi
  fi
  LEIKWAN_LOCK_CONFLICT=1
  warn "已有 Leikwan 任务运行中，当前操作已跳过。"
  lock_print_owner_info "$lock_path" "$label"
  return 1
}

lock_release() {
  local token="$1" rest fd lock_dir lock_path
  [[ -n "$token" ]] || return 0
  case "$token" in
    flock:*)
      rest="${token#flock:}"
      fd="${rest%%:*}"
      lock_path="${rest#*:}"
      eval "exec ${fd}>&-" 2>/dev/null || true
      rm -f "$lock_path" "${lock_path}.pid" "${lock_path}.meta" 2>/dev/null || true
      ;;
    mkdir:*)
      lock_dir="${token#mkdir:}"
      rm -rf "$lock_dir"
      rm -f "${lock_dir%.d}.meta" 2>/dev/null || true
      ;;
  esac
}

global_lock_acquire() {
  if [[ -n "$LEIKWAN_GLOBAL_LOCK_TOKEN" ]]; then
    return 0
  fi
  lock_acquire "$LEIKWAN_LOCK_PATH" "任务" LEIKWAN_GLOBAL_LOCK_TOKEN
}

global_lock_release() {
  [[ -n "$LEIKWAN_GLOBAL_LOCK_TOKEN" ]] || return 0
  lock_release "$LEIKWAN_GLOBAL_LOCK_TOKEN"
  LEIKWAN_GLOBAL_LOCK_TOKEN=""
}

lock_path_active_state() {
  local lock_path="$1" fd pid
  if command -v flock >/dev/null 2>&1; then
    [[ -e "$lock_path" ]] || return 1
    exec {fd}<>"$lock_path" || return 1
    if flock -n "$fd"; then
      flock -u "$fd" 2>/dev/null || true
      eval "exec ${fd}>&-" 2>/dev/null || true
      return 1
    fi
    eval "exec ${fd}>&-" 2>/dev/null || true
    return 0
  fi
  if [[ -d "${lock_path}.d" ]]; then
    pid="$(head -n 1 "${lock_path}.d/pid" 2>/dev/null || true)"
    [[ -n "$pid" ]] && pid_is_alive "$pid" && return 0
    return 2
  fi
  return 1
}

status_lock_lines() {
  local rows=() stale=() label path
  while IFS=$'\t' read -r label path; do
    [[ -n "$path" ]] || continue
    if lock_path_active_state "$path"; then
      rows+=("${label}:${path}")
    else
      case $? in
        2) stale+=("${path}") ;;
      esac
    fi
  done <<EOF
toolkit	${LEIKWAN_LOCK_PATH}
ddns-refresh	${DDNS_LOCK_PATH}
update	${UPDATE_LOCK_PATH}
config	${CONFIG_LOCK_PATH}
EOF
  if (( ${#rows[@]} == 0 && ${#stale[@]} == 0 )); then
    echo "运行中任务: 无"
    echo "锁状态: OK"
    return 0
  fi
  if (( ${#rows[@]} > 0 )); then
    local tasks="" locks="" item
    for item in "${rows[@]}"; do
      tasks="${tasks:+${tasks}, }${item%%:*}"
      locks="${locks:+${locks}, }${item#*:}"
    done
    echo "运行中任务: ${tasks}"
    echo "锁状态: ${locks}"
  else
    echo "运行中任务: 无"
  fi
  if (( ${#stale[@]} > 0 )); then
    echo "锁状态: WARN stale ${stale[*]}"
    status_mark_result warn
  fi
}

task_status() {
  local lock_path="$LEIKWAN_LOCK_PATH" pid cmd elapsed hint
  if ! lock_files_exist "$lock_path"; then
    ok "当前没有 Leikwan 任务运行。"
    return 0
  fi
  if lock_is_stale "$lock_path"; then
    warn "检测到遗留任务锁。"
    info "锁文件：${lock_path}"
    pid="$(lock_read_pid "$lock_path")"
    [[ -n "$pid" ]] && info "记录 PID：${pid}"
    info "可执行：lq task unlock-stale"
    return 0
  fi
  pid="$(lock_read_pid "$lock_path")"
  if [[ -n "$pid" ]]; then
    cmd="$(lock_owner_command "$lock_path" "$pid")"
    elapsed="$(format_duration_seconds "$(process_elapsed_seconds "$pid")")"
    hint="$(lock_owner_log_hint "$lock_path" "任务" "$cmd")"
    warn "已有 Leikwan 任务运行中。"
    info "锁文件：${lock_path}"
    info "持有进程：PID=${pid}"
    info "命令：${cmd}"
    info "已运行：${elapsed}"
    [[ -n "$hint" ]] && info "可查看日志：${hint}"
  else
    warn "检测到任务锁，但无法读取 PID。"
    info "锁文件：${lock_path}"
  fi
}

task_unlock_stale() {
  local lock_path="$LEIKWAN_LOCK_PATH"
  if ! lock_files_exist "$lock_path"; then
    ok "当前没有 Leikwan 任务运行。"
    return 0
  fi
  if lock_is_stale "$lock_path"; then
    lock_remove_files "$lock_path"
    ok "已清理遗留任务锁。"
    return 0
  fi
  warn "锁仍由活进程持有，未删除。"
  lock_print_owner_info "$lock_path" "任务"
}

ensure_nc_for_test() {
  command -v nc >/dev/null 2>&1 && return 0
  if is_interactive; then
    warn "未找到 nc，链路测试需要 netcat-openbsd。"
    if prompt_yes_no "是否现在安装 netcat-openbsd？" "Y"; then
      install_packages netcat-openbsd || true
      command -v nc >/dev/null 2>&1 && return 0
    fi
  else
    warn "未找到 nc，请执行：apt-get install -y netcat-openbsd"
  fi
  return 1
}

tcp_reachable() {
  local host="$1" port="$2"
  command -v nc >/dev/null 2>&1 || return 2
  nc -vz -w 3 "$host" "$port" >/dev/null 2>&1
}

tcp_reachable_status() {
  local rc=0
  tcp_reachable "$@" || rc=$?
  printf '%s' "$rc"
}

udp_probe() {
  local host="$1" port="$2"
  command -v nc >/dev/null 2>&1 || return 2
  nc -uvz -w 3 "$host" "$port" >/dev/null 2>&1
}

udp_probe_status() {
  local rc=0
  udp_probe "$@" || rc=$?
  printf '%s' "$rc"
}

is_fast_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ ]] && (( port >= FAST_PORT_RANGE_START && port <= FAST_PORT_RANGE_END ))
}

warn_if_slow_easytier_port() {
  local port="$1"
  if ! is_fast_port "$port"; then
    warn "当前 EasyTier 端口 ${port} 不在利群推荐白名单 ${FAST_PORT_RANGE_START}-${FAST_PORT_RANGE_END}，可能导致高延迟。"
    return 1
  fi
  return 0
}

confirm_easytier_port() {
  local port="$1"
  warn_if_slow_easytier_port "$port" && return 0
  prompt_yes_no "是否继续使用该端口？" "N"
}

normalize_easytier_port() {
  local port="$1"
  if [[ "$port" == "11010" ]]; then
    warn "检测到旧配对码使用 11010，不在利群推荐白名单 ${FAST_PORT_RANGE_START}-${FAST_PORT_RANGE_END}。"
    if prompt_yes_no "是否自动改为推荐白名单端口 ${DEFAULT_EASYTIER_PORT}？" "Y"; then
      port="$DEFAULT_EASYTIER_PORT"
    fi
  fi
  confirm_easytier_port "$port" || return 1
  printf '%s' "$port"
}

easytier_protocols_from_env() {
  local file="$1" protocols_key="$2" protocol_key="$3" default="${4:-$EASYTIER_PROTOCOLS_DEFAULT}" value
  value="$(env_file_get "$file" "$protocols_key")"
  if [[ -n "$value" ]]; then
    normalize_easytier_protocols "$value"
    return
  fi
  value="$(env_file_get "$file" "$protocol_key")"
  if [[ -n "$value" ]]; then
    normalize_easytier_protocols "$value"
    return
  fi
  normalize_easytier_protocols "$default"
}

easytier_port_from_env() {
  local file="$1" protocols="$2" tcp_key="$3" udp_key="$4" legacy_key="$5"
  local tcp_port udp_port port
  tcp_port="$(env_file_get "$file" "$tcp_key")"
  udp_port="$(env_file_get "$file" "$udp_key")"
  port="$(env_file_get "$file" "$legacy_key")"
  if easytier_protocols_has "$protocols" tcp && [[ -n "$tcp_port" ]]; then
    port="$tcp_port"
  elif easytier_protocols_has "$protocols" udp && [[ -n "$udp_port" ]]; then
    port="$udp_port"
  fi
  [[ -n "$port" ]] || port="$EASYTIER_PORT_DEFAULT"
  if easytier_protocols_has "$protocols" tcp && easytier_protocols_has "$protocols" udp &&
     [[ -n "$tcp_port" && -n "$udp_port" && "$tcp_port" != "$udp_port" ]]; then
    fail "当前 entries.tsv 只支持 TCP/UDP 使用同一个 EasyTier 端口：tcp=${tcp_port} udp=${udp_port}"
    return 1
  fi
  normalize_easytier_port "$port"
}

random_hex() {
  local bytes="${1:-16}"
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex "$bytes"
  else
    od -An -N "$bytes" -tx1 /dev/urandom | tr -d ' \n'
  fi
}

ensure_tsv_files() {
  ensure_base_dirs
  [[ -f "$ENTRIES_TSV" ]] || write_file "$ENTRIES_TSV" $'# entry_name\tpublic_host\tet_ip\teasytier_protocol\teasytier_port\tweight\tenabled' 600
  [[ -f "$RESOLVED_ENTRIES_TSV" ]] || write_file "$RESOLVED_ENTRIES_TSV" $'# name\tpublic_host\tresolved_ip\tlast_checked\tlast_changed' 600
  [[ -f "$FORWARDS_TSV" ]] || write_file "$FORWARDS_TSV" $'# name\tentry_port\ttarget_host\ttarget_port\tout_iface\troute_table\tenabled\tcomment' 600
  [[ -f "$PBR_DOMAIN_TSV" ]] || write_file "$PBR_DOMAIN_TSV" $'# name\thost\troute_table\tenabled\tcomment' 600
  [[ -f "$PBR_RESOLVED_DOMAIN_TSV" ]] || write_file "$PBR_RESOLVED_DOMAIN_TSV" $'# name\thost\tresolved_ip\troute_table\tlast_checked\tlast_changed' 600
}

resolve_ipv4_first() {
  local host="$1"
  if is_ipv4 "$host"; then printf '%s' "$host"; return 0; fi
  getent ahostsv4 "$host" 2>/dev/null | awk '$1 ~ /^[0-9]+\./ {print $1; exit}' ||
    getent ahosts "$host" 2>/dev/null | awk '$1 ~ /^[0-9]+\./ {print $1; exit}'
}

dns_resolve_servers() {
  local value="${1:-}" server
  local -a servers
  [[ -n "$value" ]] || value="$(ddns_config_value DNS_RESOLVE_SERVERS "$DNS_RESOLVE_SERVERS_DEFAULT" 2>/dev/null || printf '%s' "$DNS_RESOLVE_SERVERS_DEFAULT")"
  value="${value//$'\n'/,}"
  value="${value//$'\r'/,}"
  IFS=',' read -ra servers <<<"$value"
  for server in "${servers[@]}"; do
    server="$(trim_spaces "$server")"
    [[ -n "$server" ]] && printf '%s\n' "$server"
  done
}

dns_server_query_tool_available() {
  command -v dig >/dev/null 2>&1 ||
    command -v nslookup >/dev/null 2>&1 ||
    command -v host >/dev/null 2>&1
}

normalize_dns_resolve_strategy() {
  case "${1,,}" in
    first-success|system-first|majority) printf '%s' "${1,,}" ;;
    *) printf '%s' "$DNS_RESOLVE_STRATEGY_DEFAULT" ;;
  esac
}

dns_resolve_one_ipv4() {
  local host="$1" source="$2" output ip
  if [[ "$source" == "system" ]]; then
    ip="$(resolve_ipv4_first "$host" 2>/dev/null || true)"
    [[ -n "$ip" ]] && { printf '%s' "$ip"; return 0; }
    return 1
  fi
  if command -v dig >/dev/null 2>&1; then
    output="$(dig +short "$host" A @"$source" 2>/dev/null || true)"
    ip="$(extract_first_ipv4 "$output")"
  elif command -v nslookup >/dev/null 2>&1; then
    output="$(nslookup "$host" "$source" 2>/dev/null || true)"
    ip="$(extract_first_ipv4_except "$output" "$source")"
  elif command -v host >/dev/null 2>&1; then
    output="$(host "$host" "$source" 2>/dev/null || true)"
    ip="$(extract_first_ipv4_except "$output" "$source")"
  else
    return 1
  fi
  [[ -n "$ip" ]] && { printf '%s' "$ip"; return 0; }
  return 1
}

dns_result_escape() {
  local value="$1"
  value="${value//$'\n'/ }"
  printf '%s' "$value"
}

ddns_note_dns_split() {
  local domain="$1" results="$2" selected_ip="$3" selected_source="$4" strategy="$5" line
  local -a _dns_split_lines
  RESOLVE_SPLIT_DETECTED=true
  DDNS_DNS_SPLIT_DETECTED=true
  DDNS_DNS_SPLIT_DOMAIN="$domain"
  DDNS_DNS_SPLIT_RESULTS="$results"
  DDNS_DNS_SPLIT_SELECTED_IP="$selected_ip"
  DDNS_DNS_SPLIT_SELECTED_SOURCE="$selected_source"
  if ddns_config_bool DNS_RESOLVE_WARN_ON_SPLIT "$DNS_RESOLVE_WARN_ON_SPLIT_DEFAULT"; then
    ddns_emit WARN "域名 ${domain} DNS 解析结果不一致："
    IFS=';' read -ra _dns_split_lines <<<"$results"
    for line in "${_dns_split_lines[@]}"; do
      [[ -n "$line" ]] && ddns_emit WARN "  ${line}"
    done
    ddns_emit INFO "按 DNS_RESOLVE_STRATEGY=${strategy} 选择：${selected_ip}（source=${selected_source}）"
  fi
}

resolve_domain_ipv4_multi() {
  local host="$1" strategy configured_servers source ip selected_ip="" selected_source="" result_text="" unique_ips=""
  local best_ip="" best_count=0 current_ip current_count line any_success=0 split_count=0
  local -a sources ips labels
  RESOLVE_SELECTED_IP=""
  RESOLVE_SELECTED_SOURCE=""
  RESOLVE_ALL_RESULTS=""
  RESOLVE_SPLIT_DETECTED=false
  RESOLVE_INCOMPLETE_DETECTED=false
  if is_ipv4 "$host"; then
    RESOLVE_SELECTED_IP="$host"
    RESOLVE_SELECTED_SOURCE="literal"
    RESOLVE_ALL_RESULTS="literal -> ${host}"
    return 0
  fi
  if ! command -v dig >/dev/null 2>&1; then
    dnsutils_auto_install "ddns-run" "false" "ddns" || true
  fi
  if ! command -v dig >/dev/null 2>&1 && [[ "${DDNS_DNS_DIG_WARNED:-false}" != "true" ]]; then
    DDNS_DNS_DIG_WARNED=true
    ddns_emit WARN "dig 不存在，多 DNS 解析器检测能力受限，将尝试 fallback。"
  fi
  if ! dns_server_query_tool_available; then
    RESOLVE_INCOMPLETE_DETECTED=true
    DDNS_DNS_INCOMPLETE_DETECTED=true
  fi
  configured_servers="$(ddns_config_value DNS_RESOLVE_SERVERS "$DNS_RESOLVE_SERVERS_DEFAULT")"
  strategy="$(normalize_dns_resolve_strategy "$(ddns_config_value DNS_RESOLVE_STRATEGY "$DNS_RESOLVE_STRATEGY_DEFAULT")")"
  case "$strategy" in
    system-first) sources=("system") ;;
    *) sources=() ;;
  esac
  while IFS= read -r source; do
    [[ -n "$source" ]] && sources+=("$source")
  done < <(dns_resolve_servers "$configured_servers")
  [[ "$strategy" == "system-first" ]] || sources+=("system")
  for source in "${sources[@]}"; do
    [[ -n "$source" ]] || continue
    if ip="$(dns_resolve_one_ipv4 "$host" "$source")"; then
      any_success=1
      ips+=("$ip")
      labels+=("$source")
      result_text="${result_text:+${result_text};}${source} -> ${ip}"
      case "$strategy" in
        first-success|system-first)
          if [[ -z "$selected_ip" ]]; then
            selected_ip="$ip"
            selected_source="$source"
          fi
          ;;
      esac
    else
      result_text="${result_text:+${result_text};}${source} -> fail"
    fi
  done
  (( any_success == 1 )) || return 1
  if [[ "$strategy" == "majority" ]]; then
    for current_ip in "${ips[@]}"; do
      current_count=0
      for ip in "${ips[@]}"; do
        [[ "$ip" == "$current_ip" ]] && current_count=$((current_count + 1))
      done
      if (( current_count > best_count )); then
        best_count="$current_count"
        best_ip="$current_ip"
      fi
    done
    selected_ip="$best_ip"
    for i in "${!ips[@]}"; do
      if [[ "${ips[$i]}" == "$selected_ip" ]]; then
        selected_source="${labels[$i]}"
        break
      fi
    done
  fi
  [[ -n "$selected_ip" ]] || { selected_ip="${ips[0]}"; selected_source="${labels[0]}"; }
  for ip in "${ips[@]}"; do
    if [[ ";${unique_ips};" != *";${ip};"* ]]; then
      unique_ips="${unique_ips:+${unique_ips};}${ip}"
      split_count=$((split_count + 1))
    fi
  done
  RESOLVE_SELECTED_IP="$selected_ip"
  RESOLVE_SELECTED_SOURCE="$selected_source"
  RESOLVE_ALL_RESULTS="$(dns_result_escape "$result_text")"
  if (( split_count > 1 )); then
    ddns_note_dns_split "$host" "$RESOLVE_ALL_RESULTS" "$selected_ip" "$selected_source" "$strategy"
  fi
  return 0
}

resolve_domain_ipv4_multi_value() {
  resolve_domain_ipv4_multi "$1" >/dev/null || return 1
  printf '%s' "$RESOLVE_SELECTED_IP"
}

resolve_domain_ipv4_for_forward_context() {
  local host="$1" context="${2:-转发/PBR}" configured_servers source ip selected_ip="" selected_source=""
  local result_text="" any_success=0 unique_ips="" split_count=0 best_ip="" best_count=0 current_ip current_count tie_count=0
  local i line
  local -a sources ips labels lines
  RESOLVE_SELECTED_IP=""
  RESOLVE_SELECTED_SOURCE=""
  RESOLVE_ALL_RESULTS=""
  RESOLVE_SPLIT_DETECTED=false
  RESOLVE_INCOMPLETE_DETECTED=false
  if is_ipv4 "$host"; then
    RESOLVE_SELECTED_IP="$host"
    RESOLVE_SELECTED_SOURCE="literal"
    RESOLVE_ALL_RESULTS="literal -> ${host}"
    return 0
  fi
  if ! command -v dig >/dev/null 2>&1; then
    dnsutils_auto_install "forward-pbr" "false" "ddns" || true
  fi
  configured_servers="$(ddns_config_value DNS_RESOLVE_SERVERS "$DNS_RESOLVE_SERVERS_DEFAULT")"
  while IFS= read -r source; do
    [[ -n "$source" ]] && sources+=("$source")
  done < <(dns_resolve_servers "$configured_servers")
  sources+=("system")
  for source in "${sources[@]}"; do
    [[ -n "$source" ]] || continue
    if ip="$(dns_resolve_one_ipv4 "$host" "$source")"; then
      any_success=1
      ips+=("$ip")
      labels+=("$source")
      lines+=("${source} -> ${ip}")
      result_text="${result_text:+${result_text};}${source} -> ${ip}"
    else
      lines+=("${source} -> fail")
      result_text="${result_text:+${result_text};}${source} -> fail"
    fi
  done
  (( any_success == 1 )) || return 1
  for current_ip in "${ips[@]}"; do
    current_count=0
    for ip in "${ips[@]}"; do
      [[ "$ip" == "$current_ip" ]] && current_count=$((current_count + 1))
    done
    if (( current_count > best_count )); then
      best_count="$current_count"
      best_ip="$current_ip"
    fi
  done
  for current_ip in "${ips[@]}"; do
    if [[ ";${unique_ips};" != *";${current_ip};"* ]]; then
      unique_ips="${unique_ips:+${unique_ips};}${current_ip}"
      split_count=$((split_count + 1))
      current_count=0
      for ip in "${ips[@]}"; do
        [[ "$ip" == "$current_ip" ]] && current_count=$((current_count + 1))
      done
      (( current_count == best_count )) && tie_count=$((tie_count + 1))
    fi
  done
  if (( best_count >= 2 && tie_count == 1 )); then
    selected_ip="$best_ip"
    for i in "${!ips[@]}"; do
      if [[ "${ips[$i]}" == "$selected_ip" ]]; then
        selected_source="${labels[$i]}"
        break
      fi
    done
    RESOLVE_SELECTED_IP="$selected_ip"
    RESOLVE_SELECTED_SOURCE="$selected_source"
    RESOLVE_ALL_RESULTS="$(dns_result_escape "$result_text")"
    if (( split_count > 1 )); then
      RESOLVE_SPLIT_DETECTED=true
      warn "域名 ${host} DNS 解析结果不一致："
      for line in "${lines[@]}"; do
        warn "  ${line}"
      done
      info "${context} 场景按多数结果选择：${selected_ip}"
    fi
    return 0
  fi
  resolve_domain_ipv4_multi "$host"
}

resolve_domain_ipv4_for_forward() {
  resolve_domain_ipv4_for_forward_pbr "$1"
}

resolve_domain_ipv4_for_pbr() {
  resolve_domain_ipv4_for_forward_pbr "$1"
}

resolve_domain_ipv4_for_forward_pbr() {
  resolve_domain_ipv4_for_forward_context "$1" "转发/PBR"
}

easytier_validate_help() {
  "$EASYTIER_CORE_BIN" --help >/dev/null 2>&1 || return 1
  "$EASYTIER_CLI_BIN" --help >/dev/null 2>&1 || return 1
}

easytier_help_has() {
  "$EASYTIER_CORE_BIN" --help 2>&1 | grep -q -- "$1"
}

easytier_help_text() {
  "$EASYTIER_CORE_BIN" --help 2>&1 || true
}

easytier_disable_listener_arg() {
  local help opt
  help="$(easytier_help_text)"
  for opt in --no-listener --no-listeners --disable-listener --disable-listeners; do
    if grep -Fq -- "$opt" <<<"$help"; then
      printf '%q ' "$opt"
      return 0
    fi
  done
  return 1
}

easytier_arch_family() {
  case "$(uname -m)" in
    x86_64|amd64) printf '%s' 'x86_64' ;;
    aarch64|arm64) printf '%s' 'aarch64' ;;
    *) fail "暂不支持自动安装 EasyTier 的架构：$(uname -m)"; return 1 ;;
  esac
}

easytier_asset_names() {
  local version="$1" no_v="${1#v}" with_v arch="$2"
  with_v="v${no_v}"
  case "$arch" in
    x86_64)
      printf '%s\n' \
        "easytier-linux-x86_64-${with_v}.zip" \
        "easytier-linux-x86_64-${no_v}.zip" \
        "easytier-linux-x86_64-${with_v}.tar.gz" \
        "easytier-linux-x86_64-${no_v}.tar.gz" \
        "easytier-linux-x86_64-${with_v}.tgz" \
        "easytier-linux-x86_64-${no_v}.tgz" \
        "easytier-linux-amd64-${version}.zip" \
        "easytier_${no_v}_linux_amd64.tar.gz" \
        "easytier-${version}-linux-amd64.tar.gz"
      ;;
    aarch64)
      printf '%s\n' \
        "easytier-linux-aarch64-${with_v}.zip" \
        "easytier-linux-aarch64-${no_v}.zip" \
        "easytier-linux-aarch64-${with_v}.tar.gz" \
        "easytier-linux-aarch64-${no_v}.tar.gz" \
        "easytier-linux-aarch64-${with_v}.tgz" \
        "easytier-linux-aarch64-${no_v}.tgz" \
        "easytier-linux-arm64-${version}.zip" \
        "easytier_${no_v}_linux_arm64.tar.gz" \
        "easytier-${version}-linux-arm64.tar.gz"
      ;;
  esac
}

dl_info() { printf '[INFO] %s\n' "$*" >&2; }
dl_warn() { printf '[WARN] %s\n' "$*" >&2; }
dl_ok() { printf '[OK] %s\n' "$*" >&2; }
dl_fail() { printf '[FAIL] %s\n' "$*" >&2; }
dl_error() { printf '[ERROR] %s\n' "$*" >&2; }
dl_debug() {
  [[ "${LEIKWAN_DEBUG:-0}" == "1" ]] || return 0
  printf '[DEBUG] %s\n' "$*" >&2
}

easytier_api_asset_url() {
  local version="$1" arch="$2" api re tmp result
  if ! command -v jq >/dev/null 2>&1; then
    dl_warn "未安装 jq，跳过 GitHub release metadata，将使用内置候选 URL。"
    return 1
  fi
  api="https://api.github.com/repos/EasyTier/EasyTier/releases/tags/${version}"
  case "$arch" in
    x86_64) re='linux.*(x86_64|amd64).*\.(zip|tar\.gz|tgz)$' ;;
    aarch64) re='linux.*(aarch64|arm64).*\.(zip|tar\.gz|tgz)$' ;;
    *) return 1 ;;
  esac
  tmp="$(make_temp_file leikwan-easytier-api)"
  dl_info "正在获取 EasyTier release 信息：${api}"
  if ! download_github_with_mirrors "$api" "$tmp" api; then
    dl_warn "无法获取 GitHub release metadata，将使用内置候选 URL。"
    rm -f "$tmp"
    return 1
  fi
  if ! result="$(jq -r --arg re "$re" '.assets[]? | select(.name | test($re; "i")) | .browser_download_url' "$tmp" | head -n 1)"; then
    rm -f "$tmp"
    return 1
  fi
  rm -f "$tmp"
  [[ -n "$result" && "$result" != "null" ]] || return 1
  printf '%s\n' "$result"
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
      dl_warn "LEIKWAN_GITHUB_DOWNLOAD_MODE 无效：${mode}，使用 mirror-first。"
      printf '%s' "mirror-first"
      ;;
  esac
}

github_metadata_mode() {
  local mode="${LEIKWAN_GITHUB_METADATA_MODE:-fast}"
  case "$mode" in
    fast|full) printf '%s' "$mode" ;;
    *)
      dl_warn "LEIKWAN_GITHUB_METADATA_MODE 无效：${mode}，使用 fast。"
      printf '%s' "fast"
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

github_type_timeouts() {
  local type="$1" kind="$2"
  case "$type" in
    large|release)
      if [[ "$kind" == "origin" ]]; then
        printf '%s\t%s\t%s\t%s\n' 8 60 20 10240
      else
        printf '%s\t%s\t%s\t%s\n' 10 120 30 10240
      fi
      ;;
    api|raw|small|sha256|*)
      printf '%s\t%s\t%s\t%s\n' 8 30 "" ""
      ;;
  esac
}

downloaded_file_looks_like_html() {
  local file="$1" prefix lower
  [[ -s "$file" ]] || return 1
  prefix="$(LC_ALL=C dd if="$file" bs=512 count=1 2>/dev/null | tr -d '\000' || true)"
  lower="${prefix,,}"
  [[ "$lower" == *"<!doctype html"* || "$lower" == *"<html"* || "$lower" == *"<title>"* || "$lower" == *"</html>"* ]]
}

github_download_output_valid() {
  local file="$1" type="$2" source_url="$3" min_bytes="${LEIKWAN_DOWNLOAD_MIN_BYTES:-0}" size
  if [[ ! -s "$file" ]]; then
    dl_warn "下载结果为空，继续尝试下一个源。"
    return 1
  fi
  if [[ "$type" == "large" || "$type" == "release" ]]; then
    if downloaded_file_looks_like_html "$file"; then
      dl_warn "下载结果疑似 HTML 错误页，继续尝试下一个源。"
      return 1
    fi
  fi
  if [[ "$min_bytes" =~ ^[0-9]+$ ]] && (( min_bytes > 0 )); then
    size="$(wc -c <"$file")"
    if (( size < min_bytes )); then
      dl_warn "下载文件小于 $((min_bytes / 1024 / 1024))MB，判定为坏包，继续尝试下一个源。"
      return 1
    fi
  fi
  if [[ "${LEIKWAN_DOWNLOAD_VALIDATE_ARCHIVE:-0}" == "1" ]]; then
    if ! declare -F archive_integrity_ok >/dev/null 2>&1; then
      dl_warn "缺少压缩包校验函数，继续尝试下一个源。"
      return 1
    fi
    if ! archive_integrity_ok "$file" "$source_url"; then
      dl_warn "压缩包完整性校验失败，继续尝试下一个源。"
      return 1
    fi
  fi
}

github_probe_source() {
  local url="$1" kind="$2" type="$3" probe_tmp
  [[ "$type" == "large" || "$type" == "release" ]] || return 0
  command -v curl >/dev/null 2>&1 || return 0
  if curl -fsSLI --connect-timeout 5 --max-time 8 -o /dev/null "$url" >/dev/null 2>&1; then
    [[ "$kind" == "mirror" ]] && dl_info "镜像预检通过：${url}"
    return 0
  fi
  probe_tmp="$(make_temp_file leikwan-github-probe)"
  if curl -fsSL --range 0-1023 --connect-timeout 5 --max-time 10 -o "$probe_tmp" "$url" >/dev/null 2>&1; then
    rm -f "$probe_tmp"
    [[ "$kind" == "mirror" ]] && dl_info "镜像预检通过：${url}"
    return 0
  fi
  rm -f "$probe_tmp"
  if [[ "$kind" == "mirror" ]]; then
    dl_warn "镜像预检失败，跳过：${url}"
  else
    dl_warn "GitHub 官方预检失败，跳过：${url}"
  fi
  return 1
}

github_fetch_to_file() {
  local url="$1" output="$2" type="$3" kind="$4" mode="$5"
  local connect_timeout max_time speed_time speed_limit
  IFS=$'\t' read -r connect_timeout max_time speed_time speed_limit < <(github_type_timeouts "$type" "$kind" "$mode")
  if command -v curl >/dev/null 2>&1; then
    if [[ -n "$speed_time" && -n "$speed_limit" ]]; then
      curl -fL --retry 0 --connect-timeout "$connect_timeout" --max-time "$max_time" --speed-time "$speed_time" --speed-limit "$speed_limit" -o "$output" "$url"
    else
      curl -fL --retry 0 --connect-timeout "$connect_timeout" --max-time "$max_time" -o "$output" "$url"
    fi
    return $?
  fi
  if command -v wget >/dev/null 2>&1; then
    wget --timeout=30 --tries=1 -O "$output" "$url"
    return $?
  fi
  dl_error "缺少 curl 或 wget，无法下载 GitHub 资源。"
  return 127
}

download_github_with_mirrors() {
  local raw_url="$1" dest_file="$2" type="${3:-small}" mode candidate kind tmp source_key
  mode="$(github_download_mode)"
  dl_info "GitHub 下载策略：${mode}"
  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    source_key="$(printf '%s' "$candidate" | cksum | awk '{print $1}')"
    tmp="${dest_file}.part.${source_key}.$$"
    rm -f "$tmp"
    kind="$(github_candidate_kind "$candidate" "$raw_url")"
    if [[ "$kind" == "mirror" ]]; then
      dl_info "正在尝试镜像：${candidate}"
    else
      dl_info "正在尝试 GitHub 官方：${candidate}"
    fi
    if ! github_probe_source "$candidate" "$kind" "$type"; then
      dl_warn "当前下载源失败，正在切换下一个源。"
      rm -f "$tmp"
      continue
    fi
    if github_fetch_to_file "$candidate" "$tmp" "$type" "$kind" "$mode" &&
       github_download_output_valid "$tmp" "$type" "$candidate"; then
      mv -f "$tmp" "$dest_file"
      GITHUB_DOWNLOAD_LAST_SOURCE="$candidate"
      GITHUB_DOWNLOAD_LAST_KIND="$kind"
      if [[ "$kind" == "mirror" ]]; then
        dl_ok "镜像下载成功：${candidate}"
      else
        dl_ok "GitHub 官方下载成功：${candidate}"
      fi
      return 0
    fi
    rm -f "$tmp"
    dl_warn "当前源下载失败，已丢弃该源临时文件，切换下一个源。"
    dl_warn "当前下载源失败，正在切换下一个源。"
  done < <(github_url_candidates "$raw_url")
  dl_error "所有 GitHub 下载源均失败。"
  return 1
}

download_with_fallback() {
  local raw_url="$1" dest_file="$2" type="${3:-small}"
  download_github_with_mirrors "$raw_url" "$dest_file" "$type"
}

download_github_asset() {
  local raw_url="$1" dest_file="$2" type="${3:-release}"
  download_github_with_mirrors "$raw_url" "$dest_file" "$type"
}

normalize_version() {
  local version="$1"
  version="${version#v}"
  version="${version#V}"
  if [[ "$version" =~ ^([0-9]+)(\.([0-9]+))?(\.([0-9]+))?$ ]]; then
    printf '%s.%s.%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[3]:-0}" "${BASH_REMATCH[5]:-0}"
    return 0
  fi
  return 1
}

version_eq() {
  local left right
  left="$(normalize_version "$1" 2>/dev/null)" || return 1
  right="$(normalize_version "$2" 2>/dev/null)" || return 1
  [[ "$left" == "$right" ]]
}

version_gt() {
  local left right l1 l2 l3 r1 r2 r3
  left="$(normalize_version "$1" 2>/dev/null)" || return 1
  right="$(normalize_version "$2" 2>/dev/null)" || return 1
  IFS=. read -r l1 l2 l3 <<<"$left"
  IFS=. read -r r1 r2 r3 <<<"$right"
  (( l1 > r1 )) && return 0
  (( l1 < r1 )) && return 1
  (( l2 > r2 )) && return 0
  (( l2 < r2 )) && return 1
  (( l3 > r3 ))
}

release_version_from_tag() {
  local tag="$1"
  tag="${tag#v}"
  tag="${tag#V}"
  [[ "$tag" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
  printf '%s' "$tag"
}

latest_parse_json_tag() {
  local file="$1" tag version
  [[ -s "$file" ]] || return 1
  downloaded_file_looks_like_html "$file" && return 1
  if command -v jq >/dev/null 2>&1; then
    tag="$(jq -r '.tag_name // empty' "$file" 2>/dev/null || true)"
  else
    tag="$(grep -Eo '"tag_name"[[:space:]]*:[[:space:]]*"v?[0-9]+\.[0-9]+\.[0-9]+"' "$file" 2>/dev/null | head -n 1 | sed 's/.*:[[:space:]]*"//;s/"$//')"
  fi
  version="$(release_version_from_tag "$tag" 2>/dev/null || true)"
  [[ -n "$version" ]] || return 1
  printf '%s' "$version"
}

latest_parse_tags_json() {
  local file="$1" tag version best=""
  [[ -s "$file" ]] || return 1
  downloaded_file_looks_like_html "$file" && return 1
  if command -v jq >/dev/null 2>&1; then
    while IFS= read -r tag; do
      version="$(release_version_from_tag "$tag" 2>/dev/null || true)"
      [[ -n "$version" ]] || continue
      if [[ -z "$best" ]] || version_gt "$version" "$best"; then
        best="$version"
      fi
    done < <(jq -r '.[].name // empty' "$file" 2>/dev/null || true)
  else
    while IFS= read -r tag; do
      version="$(release_version_from_tag "$tag" 2>/dev/null || true)"
      [[ -n "$version" ]] || continue
      if [[ -z "$best" ]] || version_gt "$version" "$best"; then
        best="$version"
      fi
    done < <(grep -Eo '"name"[[:space:]]*:[[:space:]]*"v?[0-9]+\.[0-9]+\.[0-9]+"' "$file" 2>/dev/null | sed 's/.*:[[:space:]]*"//;s/"$//')
  fi
  [[ -n "$best" ]] || return 1
  printf '%s' "$best"
}

latest_parse_release_html() {
  local file="$1" tag version best=""
  [[ -s "$file" ]] || return 1
  while IFS= read -r tag; do
    version="$(release_version_from_tag "$tag" 2>/dev/null || true)"
    [[ -n "$version" ]] || continue
    if [[ -z "$best" ]] || version_gt "$version" "$best"; then
      best="$version"
    fi
  done < <(grep -Eo '/releases/tag/v?[0-9]+\.[0-9]+\.[0-9]+' "$file" 2>/dev/null | sed 's#^.*/tag/##' | sort -u)
  [[ -n "$best" ]] || return 1
  printf '%s' "$best"
}

latest_parse_version_file() {
  local file="$1" version
  [[ -s "$file" ]] || return 1
  downloaded_file_looks_like_html "$file" && return 1
  version="$(head -n 1 "$file" 2>/dev/null | tr -d '\r' | awk '{$1=$1; print}')"
  release_version_from_tag "$version"
}

metadata_time_budget() {
  local mode="$1" budget
  if [[ -n "${LEIKWAN_GITHUB_METADATA_TIMEOUT:-}" && "${LEIKWAN_GITHUB_METADATA_TIMEOUT}" =~ ^[0-9]+$ ]]; then
    budget="$LEIKWAN_GITHUB_METADATA_TIMEOUT"
  elif [[ "$mode" == "full" ]]; then
    budget=20
  else
    budget=20
  fi
  (( budget < 1 )) && budget=1
  printf '%s' "$budget"
}

metadata_remaining_seconds() {
  local now deadline remaining
  now="$(date +%s)"
  deadline=$(( LATEST_METADATA_STARTED_AT + LATEST_METADATA_BUDGET ))
  remaining=$(( deadline - now ))
  (( remaining > 0 )) || return 1
  printf '%s' "$remaining"
}

metadata_curl_max_time() {
  local desired="${1:-8}" remaining
  remaining="$(metadata_remaining_seconds)" || return 1
  (( remaining < desired )) && desired="$remaining"
  (( desired > 0 )) || return 1
  printf '%s' "$desired"
}

metadata_mirror_values() {
  local mode="$1" purpose="${2:-api}" mirrors mirror
  local -a mirror_list=()
  mirrors="${LEIKWAN_GITHUB_METADATA_MIRRORS:-}"
  mirrors="${mirrors//;/,}"
  if [[ -n "$mirrors" ]]; then
    IFS=',' read -r -a mirror_list <<<"$mirrors"
  elif [[ "$purpose" == "version" && "$mode" == "fast" ]]; then
    mirror_list=("https://gh-proxy.com/" "https://gh.llkk.cc/")
  elif [[ "$mode" == "full" ]]; then
    while IFS= read -r mirror; do
      [[ -n "$mirror" ]] && mirror_list+=("$mirror")
    done < <(github_mirror_values)
  fi
  for mirror in "${mirror_list[@]}"; do
    mirror="$(trim_spaces "$mirror")"
    [[ -n "$mirror" ]] || continue
    printf '%s\n' "$mirror"
  done
}

github_metadata_candidates() {
  local raw_url="$1" purpose="$2" mode="$3" mirror candidate seen_line
  local -a ordered=() seen=()
  if [[ "$purpose" == "version" ]]; then
    while IFS= read -r mirror; do
      [[ -n "$mirror" ]] || continue
      ordered+=("$(mirror_url_for "$mirror" "$raw_url")")
    done < <(metadata_mirror_values "$mode" "$purpose")
    ordered+=("$raw_url")
  else
    ordered+=("$raw_url")
    if [[ -n "${LEIKWAN_GITHUB_METADATA_MIRRORS:-}" || "$mode" == "full" ]]; then
      while IFS= read -r mirror; do
        [[ -n "$mirror" ]] || continue
        candidate="$(mirror_url_for "$mirror" "$raw_url")"
        ordered+=("$candidate")
      done < <(metadata_mirror_values "$mode" "$purpose")
    fi
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

metadata_fetch_to_file() {
  local url="$1" output="$2" label="${3:-metadata}" timeout err rc
  command -v curl >/dev/null 2>&1 || return 127
  timeout="$(metadata_curl_max_time 8)" || return 124
  err="$(make_temp_file leikwan-metadata-curl)"
  if curl -fsSL --retry 0 --connect-timeout 5 --max-time "$timeout" -o "$output" "$url" 2>"$err"; then
    rm -f "$err"
    return 0
  fi
  rc=$?
  dl_debug "${label} 请求失败(${rc})：${url} $(head -n 1 "$err" 2>/dev/null || true)"
  rm -f "$err"
  return "$rc"
}

metadata_fetch_effective_url() {
  local url="$1" label="${2:-redirect}" timeout err effective rc
  command -v curl >/dev/null 2>&1 || return 127
  timeout="$(metadata_curl_max_time 8)" || return 124
  err="$(make_temp_file leikwan-metadata-redirect)"
  effective="$(curl -fsSLI --retry 0 --connect-timeout 5 --max-time "$timeout" -o /dev/null -w '%{url_effective}' "$url" 2>"$err")"
  rc=$?
  if (( rc == 0 )) && [[ -n "$effective" ]]; then
    rm -f "$err"
    printf '%s' "$effective"
    return 0
  fi
  dl_debug "${label} 请求失败(${rc})：${url} $(head -n 1 "$err" 2>/dev/null || true)"
  rm -f "$err"
  return "$rc"
}

latest_release_from_version_file() {
  local mode="$1" raw_url candidate tmp version
  raw_url="https://raw.githubusercontent.com/${UPDATE_REPO}/main/VERSION"
  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    metadata_remaining_seconds >/dev/null || return 1
    tmp="$(make_temp_file leikwan-version)"
    dl_info "正在读取 VERSION：${candidate}"
    if metadata_fetch_to_file "$candidate" "$tmp" VERSION; then
      version="$(latest_parse_version_file "$tmp" 2>/dev/null || true)"
      rm -f "$tmp"
      [[ -n "$version" ]] && { printf '%s' "$version"; return 0; }
      dl_debug "VERSION 内容无法解析：${candidate}"
    else
      rm -f "$tmp"
    fi
  done < <(github_metadata_candidates "$raw_url" version "$mode")
  return 1
}

latest_release_from_api_latest() {
  local mode="${1:-fast}" api candidate tmp version
  api="https://api.github.com/repos/${UPDATE_REPO}/releases/latest"
  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    metadata_remaining_seconds >/dev/null || return 1
    tmp="$(make_temp_file leikwan-latest-api)"
    dl_debug "正在请求 GitHub API latest：${candidate}"
    if metadata_fetch_to_file "$candidate" "$tmp" api-latest; then
      version="$(latest_parse_json_tag "$tmp" 2>/dev/null || true)"
      rm -f "$tmp"
      [[ -n "$version" ]] && { printf '%s' "$version"; return 0; }
      dl_debug "GitHub API latest 内容无法解析：${candidate}"
    else
      rm -f "$tmp"
    fi
  done < <(github_metadata_candidates "$api" api "$mode")
  return 1
}

latest_release_from_redirect() {
  local mode="${1:-fast}" raw_url candidate effective version tag
  command -v curl >/dev/null 2>&1 || return 1
  raw_url="https://github.com/${UPDATE_REPO}/releases/latest"
  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    metadata_remaining_seconds >/dev/null || return 1
    dl_debug "正在解析 latest redirect：${candidate}"
    effective="$(metadata_fetch_effective_url "$candidate" latest-redirect || true)"
    tag="$(printf '%s' "$effective" | sed -n 's#.*\/releases\/tag\/\(v\{0,1\}[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*#\1#p' | head -n 1)"
    version="$(release_version_from_tag "$tag" 2>/dev/null || true)"
    [[ -n "$version" ]] && { printf '%s' "$version"; return 0; }
    dl_debug "latest redirect 无法解析版本：${candidate}"
  done < <(github_metadata_candidates "$raw_url" redirect "$mode")
  return 1
}

latest_release_from_tags_api() {
  local mode="${1:-fast}" api candidate tmp version
  api="https://api.github.com/repos/${UPDATE_REPO}/tags"
  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    metadata_remaining_seconds >/dev/null || return 1
    tmp="$(make_temp_file leikwan-tags-api)"
    dl_debug "正在请求 GitHub tags API：${candidate}"
    if metadata_fetch_to_file "$candidate" "$tmp" tags-api; then
      version="$(latest_parse_tags_json "$tmp" 2>/dev/null || true)"
      rm -f "$tmp"
      [[ -n "$version" ]] && { printf '%s' "$version"; return 0; }
      dl_debug "GitHub tags API 内容无法解析：${candidate}"
    else
      rm -f "$tmp"
    fi
  done < <(github_metadata_candidates "$api" api "$mode")
  return 1
}

latest_release_from_html() {
  local url tmp version
  url="https://github.com/${UPDATE_REPO}/releases"
  tmp="$(make_temp_file leikwan-releases-html)"
  dl_info "正在尝试 GitHub releases HTML：${url}"
  if download_github_with_mirrors "$url" "$tmp" raw; then
    version="$(latest_parse_release_html "$tmp" 2>/dev/null || true)"
    rm -f "$tmp"
    [[ -n "$version" ]] && { printf '%s' "$version"; return 0; }
  else
    rm -f "$tmp"
  fi
  dl_warn "当前源无法解析 latest，切换下一路径。"
  return 1
}

get_latest_release_version() {
  local version mode
  mode="$(github_metadata_mode)"
  LATEST_METADATA_STARTED_AT="$(date +%s)"
  LATEST_METADATA_BUDGET="$(metadata_time_budget "$mode")"
  dl_info "正在获取最新版本，模式：${mode}"
  version="$(latest_release_from_version_file "$mode" || true)"
  [[ -n "$version" ]] && { printf '%s' "$version"; return 0; }
  version="$(latest_release_from_api_latest "$mode" || true)"
  [[ -n "$version" ]] && { printf '%s' "$version"; return 0; }
  version="$(latest_release_from_redirect "$mode" || true)"
  [[ -n "$version" ]] && { printf '%s' "$version"; return 0; }
  version="$(latest_release_from_tags_api "$mode" || true)"
  [[ -n "$version" ]] && { printf '%s' "$version"; return 0; }
  if [[ "$mode" == "fast" ]]; then
    dl_warn "无法快速获取最新版本。"
    dl_info "可直接选择“更新到最新版本”，或设置 LEIKWAN_TARGET_VERSION=1.4.17 后重试。"
    dl_info "如需完整探测，可设置 LEIKWAN_GITHUB_METADATA_MODE=full。"
  else
    dl_warn "无法获取最新版本。"
    dl_info "可设置 LEIKWAN_TARGET_VERSION=1.4.17 后重试，或检查网络 / 镜像配置。"
  fi
  return 1
}

update_latest_release() {
  local version
  version="$(get_latest_release_version)" || return 1
  [[ -n "$version" ]] || return 1
  printf 'v%s\t%s\n' "$version" "$version"
}

update_release_asset_url() {
  local tag="$1" version="$2" suffix="$3"
  if ! release_version_from_tag "$version" >/dev/null 2>&1; then
    fail "release 版本为空或无效，拒绝构造下载 URL。"
    return 1
  fi
  if ! release_version_from_tag "$tag" >/dev/null 2>&1; then
    fail "release tag 为空或无效，拒绝构造下载 URL。"
    return 1
  fi
  printf 'https://github.com/%s/releases/download/%s/leikwan-toolkit-%s.tar.gz%s\n' "$UPDATE_REPO" "$tag" "$version" "$suffix"
}

update_download_asset() {
  local raw_url="$1" dest_file="$2" type="${3:-release}"
  download_github_with_mirrors "$raw_url" "$dest_file" "$type"
}

file_sha256() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    fail "缺少 sha256sum 或 shasum，无法校验 release 包。"
    return 1
  fi
}

update_verify_sha256() {
  local archive="$1" sha_file="$2" expected actual
  expected="$(awk 'NF {print $1; exit}' "$sha_file" 2>/dev/null || true)"
  [[ "$expected" =~ ^[A-Fa-f0-9]{64}$ ]] || { fail "sha256 文件格式无效。"; return 1; }
  actual="$(file_sha256 "$archive")" || return 1
  if [[ "${actual,,}" == "${expected,,}" ]]; then
    ok "sha256 校验通过。"
    return 0
  fi
  fail "sha256 校验失败，已取消更新。"
  return 1
}

update_write_status() {
  local result="$1" from="$2" to="$3" backup="$4" source="$5"
  (( DRY_RUN == 1 )) && return 0
  mkdir -p "$STATUS_DIR"
  {
    printf 'LAST_UPDATE_TIME=%s\n' "$(status_now)"
    printf 'LAST_UPDATE_FROM=%s\n' "$from"
    printf 'LAST_UPDATE_TO=%s\n' "$to"
    printf 'LAST_UPDATE_RESULT=%s\n' "$result"
    printf 'LAST_UPDATE_BACKUP=%s\n' "$backup"
    printf 'LAST_UPDATE_SOURCE=%s\n' "$source"
    printf 'LAST_UPDATE_VERSION=%s\n' "$TOOL_VERSION"
  } >"$UPDATE_STATUS_FILE"
  chmod 600 "$UPDATE_STATUS_FILE" 2>/dev/null || true
}

update_status_line() {
  local time from to result
  time="$(env_file_get "$UPDATE_STATUS_FILE" LAST_UPDATE_TIME)"
  from="$(env_file_get "$UPDATE_STATUS_FILE" LAST_UPDATE_FROM)"
  to="$(env_file_get "$UPDATE_STATUS_FILE" LAST_UPDATE_TO)"
  result="$(env_file_get "$UPDATE_STATUS_FILE" LAST_UPDATE_RESULT)"
  if [[ -z "$time" ]]; then
    printf '无记录'
  else
    printf '%s / %s -> %s / %s' "$time" "${from:-?}" "${to:-?}" "$(status_result_display "$result")"
  fi
}

script_version_from_file() {
  local script="$1" version
  [[ -f "$script" ]] || return 1
  version="$(bash "$script" --version 2>/dev/null | awk '{print $2; exit}' || true)"
  [[ -n "$version" ]] || return 1
  printf '%s' "$version"
}

update_installed_version() {
  local version
  version="$(script_version_from_file "$UPDATE_TARGET_SCRIPT" 2>/dev/null || true)"
  if [[ -n "$version" ]]; then
    printf '%s' "$version"
  else
    printf '%s' "$TOOL_VERSION"
  fi
}

update_shortcut_line() {
  local target raw wrapper_target
  if [[ -e "$SHORTCUT_LQ" || -L "$SHORTCUT_LQ" ]]; then
    raw="$(readlink "$SHORTCUT_LQ" 2>/dev/null || true)"
    target="$(readlink -f "$SHORTCUT_LQ" 2>/dev/null || true)"
    [[ -n "$target" && "$target" != "$SHORTCUT_LQ" ]] || target="$raw"
    if [[ -z "$target" && -f "$SHORTCUT_LQ" ]]; then
      wrapper_target="$(sed -n 's/^exec bash[[:space:]]\+\(.*\)[[:space:]]"\$@".*/\1/p' "$SHORTCUT_LQ" 2>/dev/null | head -n 1)"
      wrapper_target="${wrapper_target#\'}"
      wrapper_target="${wrapper_target%\'}"
      wrapper_target="${wrapper_target#\"}"
      wrapper_target="${wrapper_target%\"}"
      [[ -n "$wrapper_target" ]] && target="$wrapper_target"
    fi
    if [[ -n "$target" ]]; then
      printf '%s -> %s' "$SHORTCUT_LQ" "$target"
    else
      printf '%s -> unknown' "$SHORTCUT_LQ"
    fi
  else
    printf '%s -> missing' "$SHORTCUT_LQ"
  fi
}

update_versions_differ() {
  local installed="$1" running="$2"
  ! version_eq "$installed" "$running" 2>/dev/null
}

update_install_shortcuts() {
  need_root_unless_dry_run
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] ln -sfn ${UPDATE_TARGET_SCRIPT} ${SHORTCUT_LQ}"
    echo "[DRY-RUN] ln -sfn ${UPDATE_TARGET_SCRIPT} ${SHORTCUT_LQ_UPPER}"
    return 0
  fi
  ln -sfn "$UPDATE_TARGET_SCRIPT" "$SHORTCUT_LQ"
  ln -sfn "$UPDATE_TARGET_SCRIPT" "$SHORTCUT_LQ_UPPER"
}

update_validate_installed_for_reload() {
  local expected_version="$1" installed_version shortcut_target shortcut_raw target_resolved wrapper_target
  if [[ ! -f "$UPDATE_TARGET_SCRIPT" ]]; then
    warn "自动重新载入失败：新脚本不存在：${UPDATE_TARGET_SCRIPT}"
    return 1
  fi
  if [[ ! -x "$UPDATE_TARGET_SCRIPT" ]]; then
    warn "自动重新载入失败：新脚本不可执行：${UPDATE_TARGET_SCRIPT}"
    return 1
  fi
  if ! bash -n "$UPDATE_TARGET_SCRIPT"; then
    warn "自动重新载入失败：新脚本 bash -n 校验未通过。"
    return 1
  fi
  installed_version="$(script_version_from_file "$UPDATE_TARGET_SCRIPT" 2>/dev/null || true)"
  if [[ -z "$installed_version" ]] || ! version_eq "$installed_version" "$expected_version"; then
    warn "自动重新载入失败：安装脚本版本 ${installed_version:-unknown}，期望 ${expected_version}。"
    return 1
  fi
  shortcut_raw="$(readlink "$SHORTCUT_LQ" 2>/dev/null || true)"
  shortcut_target="$(readlink -f "$SHORTCUT_LQ" 2>/dev/null || true)"
  target_resolved="$(readlink -f "$UPDATE_TARGET_SCRIPT" 2>/dev/null || printf '%s' "$UPDATE_TARGET_SCRIPT")"
  if [[ -f "$SHORTCUT_LQ" ]]; then
    wrapper_target="$(sed -n 's/^exec bash[[:space:]]\+\(.*\)[[:space:]]"\$@".*/\1/p' "$SHORTCUT_LQ" 2>/dev/null | head -n 1)"
    wrapper_target="${wrapper_target#\'}"
    wrapper_target="${wrapper_target%\'}"
    wrapper_target="${wrapper_target#\"}"
    wrapper_target="${wrapper_target%\"}"
  fi
  if [[ "$shortcut_target" != "$target_resolved" && "$shortcut_raw" != "$UPDATE_TARGET_SCRIPT" && "$shortcut_raw" != "$target_resolved" ]]; then
    if [[ "$wrapper_target" != "$UPDATE_TARGET_SCRIPT" && "$wrapper_target" != "$target_resolved" ]]; then
      warn "自动重新载入失败：${SHORTCUT_LQ} 未指向 ${UPDATE_TARGET_SCRIPT}。"
      return 1
    fi
  fi
  return 0
}

update_maybe_reload_after_change() {
  local installed_version="$1" action="${2:-update}" reload_text prompt_text
  [[ -n "$installed_version" ]] || installed_version="$(update_installed_version)"
  if ! update_versions_differ "$installed_version" "$TOOL_VERSION"; then
    return 0
  fi
  if (( UPDATE_RELOAD_AFTER_ACTION == 1 )); then
    if [[ "$action" == "rollback" ]]; then
      reload_text="当前菜单进程仍是回滚前版本，正在重新载入..."
    else
      reload_text="当前菜单进程仍是旧版本，正在重新载入新版本..."
    fi
    info "$reload_text"
    if update_validate_installed_for_reload "$installed_version"; then
      if [[ "${LEIKWAN_DISABLE_UPDATE_EXEC:-0}" == "1" ]]; then
        info "已跳过自动 exec（测试模式），请重新执行 lq 使用当前安装版本。"
        return 0
      fi
      exec bash "$UPDATE_TARGET_SCRIPT"
    fi
    warn "自动重新载入失败，请手动执行：lq"
    return 0
  fi
  if [[ "$action" == "rollback" ]]; then
    prompt_text="请重新执行 lq 使用回滚后的版本。"
  else
    prompt_text="请重新执行 lq 使用新版本。"
  fi
  info "$prompt_text"
}

update_check() {
  local latest_version installed_version installed_norm running_norm
  installed_version="$(update_installed_version)"
  installed_norm="$(normalize_version "$installed_version" 2>/dev/null || true)"
  running_norm="$(normalize_version "$TOOL_VERSION" 2>/dev/null || true)"
  info "当前安装版本：${installed_version}"
  info "当前运行进程：${TOOL_VERSION}"
  latest_version="$(get_latest_release_version)" || return 1
  if [[ -z "$latest_version" ]]; then
    warn "无法快速获取最新版本。"
    info "可直接选择“更新到最新版本”，或设置 LEIKWAN_TARGET_VERSION=1.4.17 后重试。"
    info "如需完整探测，可设置 LEIKWAN_GITHUB_METADATA_MODE=full。"
    return 1
  fi
  if [[ -z "$installed_norm" ]]; then
    warn "当前安装版本无法解析：${installed_version}"
    info "最新版本：${latest_version}"
    return 0
  fi
  info "最新版本：${latest_version}"
  if [[ -n "$running_norm" ]] && update_versions_differ "$installed_version" "$TOOL_VERSION"; then
    warn "当前运行进程版本与已安装脚本版本不一致。"
    info "建议重新进入菜单：lq"
  fi
  if version_gt "$latest_version" "$installed_version"; then
    info "发现新版本：${latest_version}"
    info "可执行：lq update run"
  else
    ok "当前已是最新版本。"
    if [[ -n "$running_norm" ]] && update_versions_differ "$installed_version" "$TOOL_VERSION"; then
      info "当前菜单仍在旧进程中运行，退出后重新执行 lq 即可使用新版本。"
    fi
  fi
}

update_status() {
  local time from to result backup source installed_version shortcut_line
  time="$(env_file_get "$UPDATE_STATUS_FILE" LAST_UPDATE_TIME)"
  from="$(env_file_get "$UPDATE_STATUS_FILE" LAST_UPDATE_FROM)"
  to="$(env_file_get "$UPDATE_STATUS_FILE" LAST_UPDATE_TO)"
  result="$(env_file_get "$UPDATE_STATUS_FILE" LAST_UPDATE_RESULT)"
  backup="$(env_file_get "$UPDATE_STATUS_FILE" LAST_UPDATE_BACKUP)"
  source="$(env_file_get "$UPDATE_STATUS_FILE" LAST_UPDATE_SOURCE)"
  installed_version="$(update_installed_version)"
  shortcut_line="$(update_shortcut_line)"
  echo "脚本更新状态"
  echo "----------------------------------------"
  echo "当前运行版本: ${TOOL_VERSION}"
  echo "当前安装版本: ${installed_version}"
  echo "快捷命令: ${shortcut_line}"
  if [[ -z "$time" ]]; then
    echo "最近更新: 无记录"
    if update_versions_differ "$installed_version" "$TOOL_VERSION"; then
      warn "当前运行进程版本与已安装脚本版本不一致。"
      info "建议重新进入菜单：lq"
    fi
    return 0
  fi
  echo "最近更新: ${from:-?} -> ${to:-?} / $(status_result_display "$result")"
  echo "更新时间: ${time}"
  echo "from: ${from:-"-"}"
  echo "to: ${to:-"-"}"
  echo "result: ${result:-"-"}"
  echo "backup: ${backup:-"-"}"
  echo "source: ${source%%\?*}"
  if update_versions_differ "$installed_version" "$TOOL_VERSION"; then
    warn "当前运行进程版本与已安装脚本版本不一致。"
    info "建议重新进入菜单：lq"
  fi
}

update_prepare_script_from_archive() {
  local archive="$1" dest="$2" extract script
  extract="$(make_temp_dir leikwan-update-extract)"
  tar -xzf "$archive" -C "$extract"
  script="$(find "$extract" -type f -name 'leikwan-toolkit.sh' | head -n 1)"
  if [[ -z "$script" ]]; then
    rm -rf "$extract"
    fail "release 包中未找到 leikwan-toolkit.sh。"
    return 1
  fi
  cp -a "$script" "$dest"
  rm -rf "$extract"
}

update_backup_current_script() {
  local dest
  mkdir -p "$BACKUP_DIR"
  dest="${BACKUP_DIR}/root__leikwan-toolkit.sh.$(date '+%Y%m%d-%H%M%S').bak"
  if [[ -f "$UPDATE_TARGET_SCRIPT" ]]; then
    cp -a "$UPDATE_TARGET_SCRIPT" "$dest"
  else
    cp -a "$0" "$dest"
  fi
  printf '%s' "$dest"
}

update_restore_backup() {
  local backup="$1"
  [[ -f "$backup" ]] || { fail "备份脚本不存在：${backup}"; return 1; }
  bash -n "$backup" || { fail "备份脚本 bash -n 校验失败，拒绝回滚。"; return 1; }
  install -m 755 "$backup" "$UPDATE_TARGET_SCRIPT"
  update_install_shortcuts
}

update_run() {
  local force="${1:-0}" update_lock="" tmp="" latest tag latest_version package_url sha_url archive sha_file new_script
  local new_version backup="" old_version installed_version lq_version rc
  local release_global_lock=0
  need_root_unless_dry_run
  command -v curl >/dev/null 2>&1 || { fail "缺少 curl，无法执行自更新。"; return 1; }
  command -v tar >/dev/null 2>&1 || { fail "缺少 tar，无法解压 release 包。"; return 1; }
  if ! lock_acquire "$UPDATE_LOCK_PATH" "更新任务" update_lock; then
    warn "已有更新任务运行中，请稍后再试。"
    return 1
  fi
  if [[ -z "$LEIKWAN_GLOBAL_LOCK_TOKEN" ]]; then
    if ! global_lock_acquire; then
      lock_release "$update_lock"
      return 1
    fi
    release_global_lock=1
  fi
  old_version="$(update_installed_version)"
  tmp="$(make_temp_dir leikwan-update)"
  set +e
  (
    if [[ -n "${LEIKWAN_TARGET_VERSION:-}" ]]; then
      latest_version="$(release_version_from_tag "$LEIKWAN_TARGET_VERSION" 2>/dev/null || true)"
      [[ -n "$latest_version" ]] || { fail "LEIKWAN_TARGET_VERSION 无效：${LEIKWAN_TARGET_VERSION}"; exit 1; }
      tag="v${latest_version}"
    else
      latest="$(update_latest_release)" || { dl_error "无法确定最新版本，已取消更新。"; dl_info "可设置 LEIKWAN_TARGET_VERSION=1.4.17 后重试。"; exit 1; }
      IFS=$'\t' read -r tag latest_version <<<"$latest"
    fi
    if [[ -z "${latest_version:-}" ]] || ! release_version_from_tag "$latest_version" >/dev/null 2>&1; then
      dl_error "无法确定最新版本，已取消更新。"
      dl_info "可设置 LEIKWAN_TARGET_VERSION=1.4.17 后重试。"
      exit 1
    fi
    if [[ -z "${tag:-}" ]] || ! release_version_from_tag "$tag" >/dev/null 2>&1; then
      tag="v${latest_version}"
    fi
    if normalize_version "$old_version" >/dev/null 2>&1; then
      if ! version_gt "$latest_version" "$old_version"; then
        ok "当前已是最新版本：${old_version}"
        exit 0
      fi
    else
      warn "当前安装版本无法解析：${old_version}"
      if is_interactive && [[ "$force" != "1" ]]; then
        prompt_yes_no "是否继续更新到 ${latest_version}？" "N" || exit 0
      fi
    fi
    warn "即将替换 ${UPDATE_TARGET_SCRIPT}。"
    info "当前配置目录 ${STATE_DIR} 不会被删除。"
    if is_interactive && [[ "$force" != "1" ]]; then
      prompt_yes_no "是否继续更新？" "N" || exit 0
    fi
    package_url="$(update_release_asset_url "$tag" "$latest_version" "")" || exit 1
    sha_url="$(update_release_asset_url "$tag" "$latest_version" ".sha256")" || exit 1
    archive="${tmp}/leikwan-toolkit-${latest_version}.tar.gz"
    sha_file="${archive}.sha256"
    new_script="${tmp}/leikwan-toolkit.sh"
    update_download_asset "$package_url" "$archive" release || exit 1
    update_download_asset "$sha_url" "$sha_file" sha256 || exit 1
    update_verify_sha256 "$archive" "$sha_file" || exit 1
    update_prepare_script_from_archive "$archive" "$new_script" || exit 1
    bash -n "$new_script" || { fail "新脚本 bash -n 校验失败，已取消更新。"; exit 1; }
    new_version="$(bash "$new_script" --version 2>/dev/null | awk '{print $2; exit}')"
    if ! version_eq "$new_version" "$latest_version"; then
      fail "新脚本版本不符合预期：${new_version:-unknown}，期望 ${latest_version}。"
      exit 1
    fi
    backup="$(update_backup_current_script)" || exit 1
    install -m 755 "$new_script" "$UPDATE_TARGET_SCRIPT" || exit 1
    update_install_shortcuts || exit 1
    installed_version="$(bash "$UPDATE_TARGET_SCRIPT" --version 2>/dev/null | awk '{print $2; exit}')"
    if ! version_eq "$installed_version" "$latest_version"; then
      warn "替换后版本不符合预期，正在自动恢复备份。"
      update_restore_backup "$backup" || true
      update_write_status "fail" "$old_version" "$latest_version" "$backup" "$package_url"
      exit 1
    fi
    if command -v lq >/dev/null 2>&1; then
      lq_version="$(lq --version 2>/dev/null | awk '{print $2; exit}')"
      if ! version_eq "$lq_version" "$latest_version"; then
        warn "lq --version 未返回新版本，正在自动恢复备份。"
        update_restore_backup "$backup" || true
        update_write_status "fail" "$old_version" "$latest_version" "$backup" "$package_url"
        exit 1
      fi
    fi
    update_write_status "ok" "$old_version" "$latest_version" "$backup" "$package_url"
    ok "已更新到版本：${latest_version}"
    bash "$UPDATE_TARGET_SCRIPT" --version || true
  )
  rc=$?
  set -e
  rm -rf "$tmp"
  (( release_global_lock == 1 )) && global_lock_release
  lock_release "$update_lock"
  if (( rc == 0 )); then
    update_maybe_reload_after_change "$(update_installed_version)" "update"
  fi
  return "$rc"
}

update_rollback() {
  local backup from to current_version update_lock="" release_global_lock=0
  need_root_unless_dry_run
  if ! lock_acquire "$UPDATE_LOCK_PATH" "更新任务" update_lock; then
    return 1
  fi
  if ! global_lock_acquire; then
    lock_release "$update_lock"
    return 1
  fi
  release_global_lock=1
  backup="$(env_file_get "$UPDATE_STATUS_FILE" LAST_UPDATE_BACKUP)"
  from="$(env_file_get "$UPDATE_STATUS_FILE" LAST_UPDATE_FROM)"
  to="$(env_file_get "$UPDATE_STATUS_FILE" LAST_UPDATE_TO)"
  [[ -n "$backup" ]] || { warn "没有可回滚的更新备份记录。"; global_lock_release; lock_release "$update_lock"; return 0; }
  [[ -f "$backup" ]] || { fail "备份脚本不存在：${backup}"; global_lock_release; lock_release "$update_lock"; return 1; }
  warn "即将用备份脚本恢复 ${UPDATE_TARGET_SCRIPT}。"
  warn "备份：${backup}"
  prompt_yes_no "第一次确认：继续回滚？" "N" || { global_lock_release; lock_release "$update_lock"; return 0; }
  prompt_yes_no "第二次确认：确实恢复上一个脚本版本？" "N" || { global_lock_release; lock_release "$update_lock"; return 0; }
  update_restore_backup "$backup" || { global_lock_release; lock_release "$update_lock"; return 1; }
  current_version="$(bash "$UPDATE_TARGET_SCRIPT" --version 2>/dev/null | awk '{print $2; exit}')"
  update_write_status "rollback" "${to:-$TOOL_VERSION}" "${current_version:-$from}" "$backup" "rollback"
  ok "已回滚到版本：${current_version:-unknown}"
  command -v lq >/dev/null 2>&1 && lq --version || true
  (( release_global_lock == 1 )) && global_lock_release
  lock_release "$update_lock"
  update_maybe_reload_after_change "${current_version:-$(update_installed_version)}" "rollback"
}

update_menu_run() {
  local rc
  UPDATE_RELOAD_AFTER_ACTION=1
  update_run
  rc=$?
  UPDATE_RELOAD_AFTER_ACTION=0
  return "$rc"
}

update_menu_rollback() {
  local rc
  UPDATE_RELOAD_AFTER_ACTION=1
  update_rollback
  rc=$?
  UPDATE_RELOAD_AFTER_ACTION=0
  return "$rc"
}

update_menu() {
  local choice
  while true; do
    print_menu_header "脚本更新"
    echo "1. 检查最新版本"
    echo "2. 更新到最新版本"
    echo "3. 查看最近更新状态"
    echo "4. 回滚到上一个脚本版本"
    echo "0. 返回"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) run_menu_action_pause update_check ;;
      2) run_menu_action_pause update_menu_run ;;
      3) run_menu_action_pause update_status ;;
      4) run_menu_action_pause update_menu_rollback ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

archive_integrity_ok() {
  local archive="$1" source="${2:-$1}"
  case "$source" in
    *.zip)
      if ! command -v unzip >/dev/null 2>&1; then
        dl_warn "未安装 unzip，无法校验 zip 包。请先安装 unzip，或使用 tar.gz 包 / 本地二进制。"
        return 2
      fi
      unzip -tqq "$archive" >/dev/null 2>&1
      ;;
    *.tar.gz|*.tgz)
      if ! command -v tar >/dev/null 2>&1; then
        dl_warn "未安装 tar，无法校验 tar.gz 包。请先安装 tar，或上传本地 EasyTier 二进制。"
        return 2
      fi
      tar -tzf "$archive" >/dev/null 2>&1
      ;;
    *)
      if command -v tar >/dev/null 2>&1 && tar -tzf "$archive" >/dev/null 2>&1; then
        return 0
      fi
      if command -v unzip >/dev/null 2>&1 && unzip -tqq "$archive" >/dev/null 2>&1; then
        return 0
      fi
      if ! command -v unzip >/dev/null 2>&1; then
        dl_warn "未安装 unzip，无法校验 zip 包。请先安装 unzip，或使用 tar.gz 包 / 本地二进制。"
        return 2
      fi
      return 1
      ;;
  esac
}

easytier_cache_path_for_url() {
  local url="$1" name
  name="${url##*/}"
  [[ -n "$name" && "$name" != "$url" ]] || name="easytier-linux-${EASYTIER_VERSION}.pkg"
  printf '%s/%s\n' "$DOWNLOAD_CACHE_DIR" "$name"
}

easytier_cached_archive_valid() {
  local cache_file="$1" source="$2"
  [[ -f "$cache_file" ]] || return 1
  if (( $(wc -c <"$cache_file") < 10485760 )); then
    dl_warn "已缓存 EasyTier 安装包小于 10MB，删除后重新下载：${cache_file}"
    rm -f "$cache_file"
    return 1
  fi
  if downloaded_file_looks_like_html "$cache_file"; then
    dl_warn "已缓存 EasyTier 安装包疑似 HTML 错误页，删除后重新下载：${cache_file}"
    rm -f "$cache_file"
    return 1
  fi
  if ! archive_integrity_ok "$cache_file" "$source"; then
    dl_warn "已缓存 EasyTier 安装包校验失败，删除后重新下载：${cache_file}"
    rm -f "$cache_file"
    return 1
  fi
  return 0
}

easytier_try_cached_archive() {
  local raw_url="$1" dest_file="$2" cache_file
  cache_file="$(easytier_cache_path_for_url "$raw_url")"
  if easytier_cached_archive_valid "$cache_file" "$raw_url"; then
    cp -a "$cache_file" "$dest_file"
    EASYTIER_ARCHIVE_CACHE_PATH="$cache_file"
    EASYTIER_ARCHIVE_FROM_CACHE=1
    dl_ok "复用已缓存 EasyTier 安装包：${cache_file}"
    return 0
  fi
  return 1
}

easytier_store_archive_cache() {
  local archive="$1" raw_url="$2" cache_file
  [[ -f "$archive" ]] || return 0
  if (( $(wc -c <"$archive") < 10485760 )); then
    return 0
  fi
  downloaded_file_looks_like_html "$archive" && return 0
  cache_file="$(easytier_cache_path_for_url "$raw_url")"
  mkdir -p "$DOWNLOAD_CACHE_DIR" 2>/dev/null || return 0
  if cp -f "$archive" "$cache_file" 2>/dev/null; then
    EASYTIER_ARCHIVE_CACHE_PATH="$cache_file"
    EASYTIER_ARCHIVE_FROM_CACHE=0
  fi
}

download_large_archive_checked() {
  local raw_url="$1" dest_file="$2" part size_mb
  part="${dest_file}.part"
  rm -f "$part"
  if [[ "$raw_url" == *.zip ]] && ! command -v unzip >/dev/null 2>&1; then
    dl_warn "当前系统缺少 unzip，暂不尝试 zip 包：${raw_url}"
    return 1
  fi
  if [[ "$raw_url" == *.tar.gz || "$raw_url" == *.tgz ]] && ! command -v tar >/dev/null 2>&1; then
    dl_warn "当前系统缺少 tar，暂不尝试 tar.gz 包：${raw_url}"
    return 1
  fi
  EASYTIER_DOWNLOAD_ATTEMPTS+=("$raw_url")
  EASYTIER_ARCHIVE_CACHE_PATH=""
  EASYTIER_ARCHIVE_FROM_CACHE=0
  if [[ "${EASYTIER_SKIP_CACHE:-0}" != "1" ]] && easytier_try_cached_archive "$raw_url" "$dest_file"; then
    return 0
  fi
  dl_info "正在下载 EasyTier：${raw_url}"
  if LEIKWAN_DOWNLOAD_MIN_BYTES=10485760 LEIKWAN_DOWNLOAD_VALIDATE_ARCHIVE=1 download_github_with_mirrors "$raw_url" "$part" release; then
    mv -f "$part" "$dest_file"
    size_mb="$(du -m "$dest_file" | awk '{print $1}')"
    dl_ok "EasyTier 下载成功：${dest_file}，大小 ${size_mb} MB"
    easytier_store_archive_cache "$dest_file" "$raw_url"
    return 0
  fi
  rm -f "$part"
  return 1
}

choose_local_easytier_archive() {
  local dest="$1" choice path i=0
  local files=()
  is_interactive || return 1
  while IFS= read -r path; do
    [[ -f "$path" ]] && files+=("$path")
  done < <(find /root . -maxdepth 1 -type f \( -name 'easytier*.tar.gz' -o -name 'easytier*.tgz' -o -name 'easytier*.zip' \) 2>/dev/null | sort -u)
  if ((${#files[@]} > 0)); then
    echo "发现本地 EasyTier 包："
    for path in "${files[@]}"; do
      i=$((i + 1))
      echo "${i}. ${path}"
    done
    echo "0. 手动输入其它路径 / 取消"
    choice="$(prompt_menu_choice "请选择：")"
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#files[@]} )); then
      path="${files[$((choice - 1))]}"
      if (( $(wc -c <"$path") < 10485760 )); then
        fail "本地 EasyTier 包小于 10MB，疑似半截文件：${path}"
        return 1
      fi
      if ! archive_integrity_ok "$path" "$path"; then
        fail "本地 EasyTier 包完整性校验失败：${path}"
        return 1
      fi
      cp -a "$path" "$dest"
      return 0
    fi
  fi
  path="$(prompt_value "请输入本地 EasyTier zip/tar.gz/tgz 路径，留空取消" "")"
  [[ -n "$path" && -f "$path" ]] || return 1
  if (( $(wc -c <"$path") < 10485760 )); then
    fail "本地 EasyTier 包小于 10MB，疑似半截文件：${path}"
    return 1
  fi
  if ! archive_integrity_ok "$path" "$path"; then
    fail "本地 EasyTier 包完整性校验失败：${path}"
    return 1
  fi
  cp -a "$path" "$dest"
}

download_easytier_archive() {
  local dest="$1" version="$EASYTIER_VERSION" arch api_url release_base name url seen_url
  local urls=()
  EASYTIER_DOWNLOAD_ATTEMPTS=()
  EASYTIER_ARCHIVE_CACHE_PATH=""
  EASYTIER_ARCHIVE_FROM_CACHE=0
  arch="$(easytier_arch_family)" || return 1
  release_base="https://github.com/EasyTier/EasyTier/releases/download/${version}"
  dl_info "EasyTier 下载策略：$(github_download_mode)"
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    url="${release_base}/${name}"
    for seen_url in "${urls[@]}"; do
      [[ "$seen_url" == "$url" ]] && continue 2
    done
    urls+=("$url")
  done < <(easytier_asset_names "$version" "$arch")
  for url in "${urls[@]}"; do
    if download_large_archive_checked "$url" "$dest"; then
      dl_ok "EasyTier 下载和校验完成。"
      return 0
    fi
  done
  api_url="$(easytier_api_asset_url "$version" "$arch" || true)"
  if [[ -n "$api_url" && "$api_url" != "null" ]]; then
    for seen_url in "${urls[@]}"; do
      [[ "$seen_url" == "$api_url" ]] && api_url="" && break
    done
  fi
  if [[ -n "$api_url" ]]; then
    if download_large_archive_checked "$api_url" "$dest"; then
      dl_ok "EasyTier 下载和校验完成。"
      return 0
    fi
  fi
  dl_fail "EasyTier 自动下载失败。"
  if ((${#EASYTIER_DOWNLOAD_ATTEMPTS[@]} > 0)); then
    printf '已尝试：\n' >&2
    printf '  %s\n' "${EASYTIER_DOWNLOAD_ATTEMPTS[@]}" >&2
  fi
  printf '%s\n' "解决方式：" >&2
  printf '%s\n' "- 先执行 lq system network prepare（IPv4 优先 + 国外 DNS）" >&2
  printf '%s\n' "- 设置 LEIKWAN_GITHUB_MIRRORS" >&2
  printf '%s\n' "- 手动下载 EasyTier tar.gz/tgz/zip 后输入本地路径" >&2
  printf '%s\n' "- 如果无法安装 unzip，请优先使用 tar.gz/tgz，或上传本地 easytier-core / easytier-cli 二进制" >&2
  choose_local_easytier_archive "$dest" || { fail "未提供可用 EasyTier 安装包。"; return 1; }
}

extract_archive() {
  local archive="$1" dest="$2"
  case "$archive" in
    *.zip)
      command -v unzip >/dev/null 2>&1 || { warn "未安装 unzip，无法解压 zip 包。请使用 tar.gz 包或本地二进制。"; return 1; }
      unzip -q "$archive" -d "$dest"
      ;;
    *.tar.gz|*.tgz)
      command -v tar >/dev/null 2>&1 || { warn "未安装 tar，无法解压 tar.gz 包。"; return 1; }
      tar -xzf "$archive" -C "$dest"
      ;;
    *)
      if command -v tar >/dev/null 2>&1 && tar -xzf "$archive" -C "$dest" 2>/dev/null; then
        return 0
      fi
      command -v unzip >/dev/null 2>&1 || { warn "未安装 unzip，无法尝试解压 zip 包。请使用 tar.gz 包或本地二进制。"; return 1; }
      unzip -q "$archive" -d "$dest"
      ;;
  esac
}

archive_listing() {
  local archive="$1"
  case "$archive" in
    *.zip) command -v unzip >/dev/null 2>&1 && unzip -l "$archive" 2>/dev/null | sed -n '1,50p' ;;
    *) tar -tzf "$archive" 2>/dev/null | sed -n '1,50p' || { command -v unzip >/dev/null 2>&1 && unzip -l "$archive" 2>/dev/null | sed -n '1,50p'; } ;;
  esac
}

install_local_easytier_binaries() {
  local core cli
  is_interactive || return 1
  warn "可以改用本地 EasyTier 二进制继续安装。"
  core="$(prompt_value "请输入本地 easytier-core 路径，输入 0 取消" "/root/easytier-core")"
  [[ "$core" == "0" ]] && return 1
  cli="$(prompt_value "请输入本地 easytier-cli 路径，输入 0 取消" "/root/easytier-cli")"
  [[ "$cli" == "0" ]] && return 1
  [[ -f "$core" && -f "$cli" ]] || { warn "未找到 easytier-core / easytier-cli 本地文件。"; return 1; }
  backup_file "$EASYTIER_CORE_BIN"; backup_file "$EASYTIER_CLI_BIN"
  install -m 755 "$core" "$EASYTIER_CORE_BIN"
  install -m 755 "$cli" "$EASYTIER_CLI_BIN"
  easytier_validate_help || { fail "本地 EasyTier 二进制校验失败。"; return 1; }
  ok "已安装本地 EasyTier 二进制。"
}

install_easytier_binary() {
  local mode="${1:-auto}"
  if [[ -x "$EASYTIER_CORE_BIN" && -x "$EASYTIER_CLI_BIN" ]] && easytier_validate_help; then
    if ! command -v jq >/dev/null 2>&1; then
      info "jq 缺失只影响 GitHub release metadata 获取，不影响当前已安装 EasyTier 运行。"
    fi
    if [[ "$mode" == "repair" ]]; then
      if ! prompt_yes_no "检测到可用 EasyTier 二进制，是否重新安装 / 修复？" "N"; then
        ok "复用已安装 EasyTier：${EASYTIER_CORE_BIN}"
        return 0
      fi
    else
      ok "复用已安装 EasyTier：${EASYTIER_CORE_BIN}"
      return 0
    fi
  fi
  if ! install_packages curl jq ca-certificates tar unzip; then
    warn "依赖安装未完成，将在已有工具条件下继续尝试。"
    warn "如果 apt 源返回 403 或 mirror sync in progress，请换源、稍后重试，或手动安装 curl/jq/tar/unzip/ca-certificates。"
  fi
  if ! command -v curl >/dev/null 2>&1; then
    fail "缺少 curl，无法自动下载 EasyTier。请先安装 curl 或上传本地二进制。"
    install_local_easytier_binaries
    return $?
  fi
  if ! command -v tar >/dev/null 2>&1 && ! command -v unzip >/dev/null 2>&1; then
    warn "系统缺少 tar 和 unzip，无法解压 EasyTier 安装包。"
    install_local_easytier_binaries
    return $?
  fi
  local tmpdir archive core cli list
  confirm_summary "EasyTier 安装摘要" "版本：${EASYTIER_VERSION}\n目标：${EASYTIER_CORE_BIN} / ${EASYTIER_CLI_BIN}\n下载：${LEIKWAN_GITHUB_DOWNLOAD_MODE:-mirror-first}，镜像池优先 / 官方 GitHub 兜底 + 本地包 fallback\n缓存：${DOWNLOAD_CACHE_DIR}" || return 0
  (( DRY_RUN == 1 )) && return 0
  tmpdir="$(mktemp -d)"
  archive="${tmpdir}/easytier.pkg"
  if ! download_easytier_archive "$archive"; then
    install_local_easytier_binaries && { rm -rf "$tmpdir"; return 0; }
    rm -rf "$tmpdir"
    return 1
  fi
  if ! extract_archive "$archive" "$tmpdir"; then
    if [[ "${EASYTIER_ARCHIVE_FROM_CACHE:-0}" == "1" && -n "${EASYTIER_ARCHIVE_CACHE_PATH:-}" ]]; then
      warn "缓存 EasyTier 安装包解压失败，删除缓存后重新下载：${EASYTIER_ARCHIVE_CACHE_PATH}"
      rm -f "$EASYTIER_ARCHIVE_CACHE_PATH"
      rm -rf "$tmpdir"
      tmpdir="$(mktemp -d)"
      archive="${tmpdir}/easytier.pkg"
      if EASYTIER_SKIP_CACHE=1 download_easytier_archive "$archive" && extract_archive "$archive" "$tmpdir"; then
        :
      else
        fail "EasyTier 安装包解压失败。"
        archive_listing "$archive" >&2 || true
        rm -rf "$tmpdir"
        return 1
      fi
    else
      fail "EasyTier 安装包解压失败。"
      archive_listing "$archive" >&2 || true
      rm -rf "$tmpdir"
      return 1
    fi
  fi
  core="$(find "$tmpdir" -type f -name easytier-core -perm -111 | head -n 1)"
  cli="$(find "$tmpdir" -type f -name easytier-cli -perm -111 | head -n 1)"
  if [[ -z "$core" || -z "$cli" ]]; then
    fail "安装包中未找到 easytier-core / easytier-cli。"
    list="$(archive_listing "$archive" || find "$tmpdir" -maxdepth 4 -type f)"
    printf '%s\n' "$list" >&2
    rm -rf "$tmpdir"
    return 1
  fi
  backup_file "$EASYTIER_CORE_BIN"; backup_file "$EASYTIER_CLI_BIN"
  install -m 755 "$core" "$EASYTIER_CORE_BIN"
  install -m 755 "$cli" "$EASYTIER_CLI_BIN"
  rm -rf "$tmpdir"
  easytier_validate_help || { fail "easytier --help 校验失败。"; return 1; }
  ok "EasyTier 安装完成。"
}

core_common_args() {
  local ip="$1" peers="${2:-}" args=()
  local network_name network_secret
  network_name="$(env_file_get "$NETWORK_ENV" EASYTIER_NETWORK_NAME)"
  network_secret="$(env_file_get "$NETWORK_ENV" EASYTIER_NETWORK_SECRET)"
  [[ -n "$network_name" && -n "$network_secret" ]] || { fail "缺少 EasyTier network.env，请先生成网络码。"; return 1; }
  easytier_help_has '--network-name' || { fail "当前 easytier-core 不支持 --network-name"; return 1; }
  easytier_help_has '--network-secret' || { fail "当前 easytier-core 不支持 --network-secret"; return 1; }
  easytier_help_has '--ipv4' || { fail "当前 easytier-core 不支持 --ipv4"; return 1; }
  args+=("--network-name" "$network_name" "--network-secret" "$network_secret" "--ipv4" "$ip")
  if [[ -n "$peers" ]]; then
    while read -r peer; do
      [[ -n "$peer" ]] && args+=("-p" "$peer")
    done <<<"$peers"
  fi
  printf '%q ' "${args[@]}"
}

entry_service_name() {
  printf 'easytier-entry-%s' "$(safe_name "$1")"
}

entry_service_path() {
  printf '/etc/systemd/system/%s.service' "$(entry_service_name "$1")"
}

render_entry_service() {
  local name="$1" et_ip="$2" proto="$3" port="$4" args listener_args listener
  args="$(core_common_args "$et_ip")" || return 1
  confirm_easytier_port "$port" || return 1
  easytier_help_has '--listeners' || { fail "当前 easytier-core 不支持 --listeners"; return 1; }
  proto="$(normalize_easytier_protocols "$proto")" || { fail "EasyTier 传输模式无效：${proto}"; return 1; }
  listener_args=""
  while IFS= read -r listener; do
    [[ -n "$listener" ]] && listener_args="${listener_args}$(printf '%q ' --listeners "$listener")"
  done < <(easytier_urls "0.0.0.0" "$proto" "$port")
  cat <<EOF
# Managed by leikwan-toolkit ${TOOL_VERSION}
[Unit]
Description=Leikwan EasyTier Entry ${name}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${EASYTIER_CORE_BIN} ${args}${listener_args}
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
}

enabled_entry_peers() {
  local name public_host et_ip proto port weight enabled
  while IFS=$'\t' read -r name public_host et_ip proto port weight enabled; do
    [[ "$enabled" == "true" ]] || continue
    easytier_urls "$public_host" "$proto" "$port"
  done < <(entries_rows)
}

render_relay_service() {
  local args peers listener_args listener
  peers="$(enabled_entry_peers)"
  args="$(core_common_args "$RELAY_ET_IP" "$peers")" || return 1
  if listener_args="$(easytier_disable_listener_arg)"; then
    :
  else
    easytier_help_has '--listeners' || { fail "当前 easytier-core 不支持禁用 listener，也不支持 --listeners，无法避免默认 11010/11011/11012。"; return 1; }
    listener_args=""
    while IFS= read -r listener; do
      [[ -n "$listener" ]] && listener_args="${listener_args}$(printf '%q ' --listeners "$listener")"
    done < <(easytier_urls "0.0.0.0" "$EASYTIER_PROTOCOLS_DEFAULT" "$DEFAULT_EASYTIER_PORT")
  fi
  cat <<EOF
# Managed by leikwan-toolkit ${TOOL_VERSION}
[Unit]
Description=Leikwan EasyTier Relay
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${EASYTIER_CORE_BIN} ${args}${listener_args}
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
}

start_service_file() {
  local service_name="$1"
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] systemctl enable --now ${service_name}.service"
    return 0
  fi
  systemctl daemon-reload
  systemctl enable "${service_name}.service"
  systemctl restart "${service_name}.service"
}

et_iface_by_ip() {
  local ip="$1"
  ip -o -4 addr show 2>/dev/null | awk -v ip="$ip" '$4 ~ "^"ip"/" {print $2; exit}'
}

et_ip_present() {
  local ip="$1"
  [[ -n "$(et_iface_by_ip "$ip")" ]]
}

wait_et_ip() {
  local ip="$1" timeout="${2:-15}" i
  for i in $(seq 1 "$timeout"); do
    if et_ip_present "$ip"; then return 0; fi
    sleep 1
  done
  return 1
}

wait_systemd_active() {
  local service_name="$1" timeout="${2:-15}" i
  (( DRY_RUN == 1 )) && return 0
  command -v systemctl >/dev/null 2>&1 || return 0
  for i in $(seq 1 "$timeout"); do
    if systemctl is-active --quiet "${service_name}.service"; then
      return 0
    fi
    sleep 1
  done
  return 1
}

easytier_cli_peer_text() {
  "$EASYTIER_CLI_BIN" peer 2>/dev/null || "$EASYTIER_CLI_BIN" node 2>/dev/null || true
}

pairing_base64() {
  base64 "$1" | tr -d '\n'
}

decode_pairing_base64() {
  local payload="$1" dest="$2" decoded
  decoded="$(mktemp)"
  if printf '%s' "$payload" | base64 -d >"$decoded" 2>/dev/null &&
    grep -qx 'PAIRING_VERSION=0.4' "$decoded" &&
    grep -q '^ROLE=' "$decoded"; then
    cp -a "$decoded" "$dest"
    rm -f "$decoded"
    return 0
  fi
  rm -f "$decoded"
  return 1
}

decode_env_base64() {
  local payload="$1" dest="$2" required_key="$3" decoded
  decoded="$(mktemp)"
  if printf '%s' "$payload" | base64 -d >"$decoded" 2>/dev/null &&
    grep -q "^${required_key}=" "$decoded"; then
    cp -a "$decoded" "$dest"
    rm -f "$decoded"
    return 0
  fi
  rm -f "$decoded"
  return 1
}

print_pairing_code() {
  local title="$1" begin="$2" end="$3" file="$4" one_line_key="$5" next_step="${6:-}"
  echo
  echo "${BOLD}${title}${RESET}"
  echo "----------------------------------------"
  echo "$begin"
  cat "$file"
  echo "$end"
  if [[ -n "$next_step" ]]; then
    echo
    echo "下一步：${next_step}"
  fi
  echo
  echo "单行码（复制这一行也可以）："
  printf '%s=%s\n' "$one_line_key" "$(pairing_base64 "$file")"
}

wait_pairing_code_confirm() {
  local ans
  is_interactive || return 0
  echo
  echo "请确认已经复制上面的单行码。"
  echo "直接回车不会返回菜单。"
  echo "输入 y 后回车：返回菜单"
  echo "输入 r 后回车：重新显示单行码"
  echo "输入 p 后回车：显示保存路径"
  while true; do
    read -r -p "请选择 [y/r/p]: " ans || ans=""
    ans="$(normalize_menu_choice "$ans")"
    ans="${ans,,}"
    case "$ans" in
      y|yes) return 0 ;;
      r|redisplay) return 2 ;;
      p|path) return 3 ;;
      "") echo "为避免手滑，直接回车不会返回菜单。请输入 y 返回，或 r 重显。" ;;
      *) echo "请输入 y / r / p。" ;;
    esac
  done
}

show_pairing_code_and_confirm() {
  local title="$1" begin="$2" end="$3" file="$4" one_line_key="$5" next_step="${6:-}"
  local rc
  while true; do
    print_pairing_code "$title" "$begin" "$end" "$file" "$one_line_key" "$next_step"
    is_interactive || return 0
    set +e
    wait_pairing_code_confirm
    rc=$?
    set -e
    case "$rc" in
      0) MENU_ACTION_PAUSE_DONE=1; return 0 ;;
      2) continue ;;
      3) echo "保存路径：${file}" ;;
    esac
  done
}

wait_file_output_confirm() {
  local label="$1" path="$2" ans
  is_interactive || return 0
  echo
  echo "${label} 已输出。"
  echo "输入 y 后回车：返回菜单"
  echo "输入 p 后回车：显示保存路径"
  while true; do
    read -r -p "请选择 [y/p]: " ans || ans=""
    ans="$(normalize_menu_choice "$ans")"
    ans="${ans,,}"
    case "$ans" in
      y|yes) MENU_ACTION_PAUSE_DONE=1; return 0 ;;
      p|path) echo "保存路径：${path}" ;;
      "") echo "为避免手滑，直接回车不会返回菜单。请输入 y 返回。" ;;
      *) echo "请输入 y / p。" ;;
    esac
  done
}

parse_pairing_raw() {
  local raw="$1" dest="$2" base64_key="$3" line payload
  : >"$dest"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(normalize_menu_choice "$line")"
    [[ -n "$line" ]] || continue
    case "$line" in
      "-----BEGIN LEIKWAN "*|"-----END LEIKWAN "*) continue ;;
    esac
    if [[ "$line" == "${base64_key}="* || "$line" == LEIKWAN_EASYTIER_*_BASE64=* ]]; then
      payload="${line#*=}"
      if ! decode_pairing_base64 "$payload" "$dest"; then
        fail "一行配对码解码失败，请重新复制完整内容。"
        return 1
      fi
      return 0
    fi
    if [[ "$line" =~ ^[A-Za-z0-9+/]+={0,2}$ ]] && ((${#line} >= 40)); then
      if decode_pairing_base64 "$line" "$dest"; then
        return 0
      fi
    fi
    if [[ "$line" == *=* ]]; then
      printf '%s\n' "$line" >>"$dest"
    fi
  done <"$raw"
  [[ -s "$dest" ]] || { fail "没有读到有效 KEY=VALUE 配对内容。"; return 1; }
}

read_pairing_code() {
  local dest="$1" label="$2" end_marker="$3" base64_key="$4" source="${5:-}"
  local raw line has_content=0
  raw="$(mktemp)"
  if [[ -n "$source" ]]; then
    if [[ "$source" == "-" ]]; then
      cat >"$raw"
    elif [[ -f "$source" ]]; then
      cp -a "$source" "$raw"
    else
      printf '%s\n' "$source" >"$raw"
    fi
  else
    echo "请粘贴从 ${label} 复制的整段配对码，包含 BEGIN/END 行。"
    echo "粘贴完成后按回车，遇到 END 行会自动继续。"
    echo "如果只粘贴 KEY=VALUE 内容，请用空行结束。"
    while IFS= read -r line; do
      line="$(normalize_menu_choice "$line")"
      if [[ -z "$line" ]]; then
        (( has_content == 1 )) && break
        continue
      fi
      has_content=1
      printf '%s\n' "$line" >>"$raw"
      [[ "$line" == "$end_marker" ]] && break
      [[ "$line" == "${base64_key}="* || "$line" == LEIKWAN_EASYTIER_*_BASE64=* ]] && break
      [[ "$line" =~ ^[A-Za-z0-9+/]+={0,2}$ ]] && ((${#line} >= 40)) && break
    done
  fi
  parse_pairing_raw "$raw" "$dest" "$base64_key"
  rm -f "$raw"
}

require_pairing_fields() {
  local file="$1" missing=() key value
  shift
  for key in "$@"; do
    value="$(env_file_get "$file" "$key")"
    [[ -n "$value" ]] || missing+=("$key")
  done
  if ((${#missing[@]} > 0)); then
    fail "配对码缺少 ${missing[*]}，请重新复制完整内容。"
    return 1
  fi
}

require_env_fields() {
  local file="$1" missing=() key value
  shift
  for key in "$@"; do
    value="$(env_file_get "$file" "$key")"
    [[ -n "$value" ]] || missing+=("$key")
  done
  if ((${#missing[@]} > 0)); then
    fail "配置码缺少 ${missing[*]}，请重新复制完整内容。"
    return 1
  fi
}

machine_has_relay_network() {
  local role
  role="$(env_file_get "$NETWORK_ENV" ROLE)"
  [[ "$role" == "leikwan-relay" ]] && return 0
  role="$(env_file_get "$NETWORK_PAIRING_FILE" ROLE)"
  [[ "$role" == "leikwan-relay" ]]
}

machine_looks_like_relay() {
  machine_has_relay_network && return 0
  systemctl list-unit-files --type=service --no-legend "${EASYTIER_RELAY_SERVICE_NAME}.service" 2>/dev/null | grep -q . && return 0
  et_ip_present "$RELAY_ET_IP"
}

machine_has_entry_service() {
  if compgen -G "/etc/systemd/system/easytier-entry-*.service" >/dev/null; then
    return 0
  fi
  systemctl list-unit-files --type=service --no-legend 'easytier-entry-*.service' 2>/dev/null | grep -q .
}

machine_looks_like_entry() {
  local role
  role="$(env_file_get "$NETWORK_ENV" ROLE)"
  [[ "$role" == "cloud-entry" ]] && return 0
  machine_has_entry_service && return 0
  [[ -f "$ENTRY_PAIRING_FILE" ]]
}

guard_entry_join_role() {
  if machine_has_relay_network; then
    warn "当前机器看起来是 B 利群主机，不应该执行 A 公网入口部署。"
    warn "正确操作是选择：4. B 利群主机：粘贴入口码，完成组网。"
    prompt_yes_no "是否仍然继续？" "N" || return 1
  fi
}

guard_relay_join_role() {
  if machine_has_entry_service; then
    warn "当前机器看起来是 A 公网入口，不应该执行 B 接入。"
    warn "正确操作是在 B 利群主机执行该步骤。"
    prompt_yes_no "是否仍然继续？" "N" || return 1
  fi
}

entries_rows() {
  [[ -f "$ENTRIES_TSV" ]] || return 0
  awk -F'\t' '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    function norm_proto(s) {
      s=tolower(trim(s))
      gsub(/[[:space:]]+/, "", s)
      gsub(/\+/, ",", s)
      if (s=="dual" || s=="both" || s=="udp,tcp") s="tcp,udp"
      return s
    }
    { gsub(/\r/, "") }
    NF == 0 { next }
    $1 ~ /^#/ { next }
    {
      name=trim($1)
      public_host=trim($2)
      et_ip=trim($3)
      proto=norm_proto($4)
      port=trim($5)
      weight=trim($6)
      enabled=trim($7)
      if (name=="" || public_host=="" || et_ip=="" || proto=="" || port=="" || enabled=="") next
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", name, public_host, et_ip, proto, port, weight, enabled
    }
  ' "$ENTRIES_TSV"
}

pending_entries_rows() {
  [[ -f "$PENDING_ENTRIES_TSV" ]] || return 0
  awk -F'\t' '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    function norm_proto(s) {
      s=tolower(trim(s))
      gsub(/[[:space:]]+/, "", s)
      gsub(/\+/, ",", s)
      if (s=="dual" || s=="both" || s=="udp,tcp") s="tcp,udp"
      return s
    }
    { gsub(/\r/, "") }
    NF == 0 { next }
    $1 ~ /^#/ { next }
    {
      name=trim($1)
      et_ip=trim($2)
      proto=norm_proto($3)
      port=trim($4)
      created_at=trim($5)
      if (name=="" || et_ip=="" || proto=="" || port=="") next
      printf "%s\t%s\t%s\t%s\t%s\n", name, et_ip, proto, port, created_at
    }
  ' "$PENDING_ENTRIES_TSV"
}

resolved_entries_rows() {
  [[ -f "$RESOLVED_ENTRIES_TSV" ]] || return 0
  awk -F'\t' '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    { gsub(/\r/, "") }
    NF == 0 { next }
    $1 ~ /^#/ { next }
    {
      name=trim($1)
      public_host=trim($2)
      resolved_ip=trim($3)
      last_checked=trim($4)
      last_changed=trim($5)
      if (name=="" || public_host=="") next
      printf "%s\t%s\t%s\t%s\t%s\n", name, public_host, resolved_ip, last_checked, last_changed
    }
  ' "$RESOLVED_ENTRIES_TSV"
}

entries_rows_sorted() {
  entries_rows | sort -t$'\t' -k6,6nr -k1,1
}

enabled_entries_sorted() {
  entries_rows | awk -F'\t' '$7=="true"' | sort -t$'\t' -k6,6nr -k1,1
}

forwards_rows() {
  [[ -f "$FORWARDS_TSV" ]] || return 0
  # Normalize forwards.tsv rows:
  # - tolerate CRLF / trailing spaces
  # - tolerate missing comment (NF>=7)
  # - tolerate extra columns (NF>8)
  # - always output 8 tab-separated fields
  awk -F'\t' '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    { gsub(/\r/, "") }
    NF == 0 { next }
    $1 ~ /^#/ { next }
    {
      name=trim($1)
      entry_port=trim($2)
      target_host=trim($3)
      target_port=trim($4)
      out_iface=trim($5)
      route_table=trim($6)
      enabled=trim($7)
      comment=""
      if (NF >= 8) comment=$8
      comment=trim(comment)
      if (name=="" || entry_port=="" || target_host=="" || target_port=="" || enabled=="") next
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", name, entry_port, target_host, target_port, out_iface, route_table, enabled, comment
    }
  ' "$FORWARDS_TSV"
}

forwards_rows_usv() {
  forwards_rows | awk -F'\t' 'BEGIN{OFS=sprintf("%c", 28)} NF>=7 {print $1,$2,$3,$4,$5,$6,$7,$8}'
}

last_resolved_ip_for_forward() {
  local name="$1"
  resolved_rows | awk -F'\t' -v n="$name" '$1==n && $4!="" {print $4; exit}'
}

display_entries() {
  ensure_tsv_files
  local only_enabled="${1:-all}" labels
  labels=$'编号\t名称\t公网地址\tEasyTier IP\t协议\t端口\t权重\t启用'
  entries_rows_sorted | awk -F'\t' -v only="$only_enabled" '
    function proto_display(s) { return s=="tcp,udp" ? "tcp+udp" : s }
    function display_name(n) {
      if (n ~ /^public[0-9]+$/) return "公网" substr(n, 7) "(" n ")"
      return n
    }
    only=="enabled" && $7!="true" {next}
    {
      printf "%d)\t%s\t%s\t%s\t%s\t%s\tweight=%s\t%s\n", ++i, display_name($1), $2, $3, proto_display($4), $5, $6, ($7=="true" ? "enabled" : "disabled")
    }
  ' | render_tsv_table 112 "$labels"
}

select_entry_name() {
  local only_enabled="${1:-all}" prompt="${2:-请输入编号或名称，直接回车返回}" choice query name count
  ensure_tsv_files >/dev/null
  count="$(entries_rows | awk -F'\t' -v only="$only_enabled" 'only=="enabled" && $7!="true"{next} {c++} END{print c+0}')"
  if (( count == 0 )); then
    warn "当前没有公网入口。" >&2
    return 1
  fi
  display_entries "$only_enabled" >&2
  while true; do
    choice="$(prompt_value "$prompt")"
    [[ -z "$choice" ]] && return 1
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
      name="$(entries_rows_sorted | awk -F'\t' -v idx="$choice" -v only="$only_enabled" 'only=="enabled" && $7!="true"{next} {i++} i==idx {print $1; exit}')"
    else
      query="$(normalize_entry_selector "$choice")"
      name="$(entries_rows | awk -F'\t' -v n="$query" -v only="$only_enabled" 'only=="enabled" && $7!="true"{next} $1==n {print $1; exit}')"
    fi
    if [[ -n "$name" ]]; then
      printf '%s' "$name"
      return 0
    fi
    warn "入口不存在或编号无效：${choice}" >&2
  done
}

display_forwards() {
  local only_enabled="${1:-all}" resolved_source="/dev/null" labels
  ensure_tsv_files >/dev/null
  resolve_forwards >/dev/null 2>&1 || true
  [[ -f "$RESOLVED_TSV" ]] && resolved_source="$RESOLVED_TSV"
  labels=$'编号\t名称\t入口端口\t后端目标\t当前解析 IP\t出口接口\t路由表\t启用\t备注'
  awk -F'\t' -v only="$only_enabled" '
    NR==FNR {
      if ($1 !~ /^#/ && NF >= 4) ip[$1]=$4
      next
    }
    $1 ~ /^#/ || NF < 7 {next}
    only=="enabled" && $7!="true" {next}
    {
      resolved=(ip[$1] != "" ? ip[$1] : "-")
      comment=(NF>=8 && $8!="" ? $8 : "-")
      printf "%d)\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", ++i, $1, $2, $3 ":" $4, resolved, ($5!="" ? $5 : "-"), ($6!="" ? $6 : "-"), ($7=="true" ? "enabled" : "disabled"), comment
    }
  ' "$resolved_source" "$FORWARDS_TSV" | render_tsv_table 112 "$labels"
}

display_forward_selection_list() {
  local only_enabled="${1:-all}" title="${2:-当前转发目标：}"
  echo
  echo "$title"
  display_forwards "$only_enabled"
  echo
}

select_forward_name() {
  local only_enabled="${1:-all}" title="${2:-当前转发目标：}" choice name count
  ensure_tsv_files >/dev/null
  count="$(forwards_rows | awk -F'\t' -v only="$only_enabled" 'only=="enabled" && $7!="true"{next} {c++} END{print c+0}')"
  if (( count == 0 )); then
    if [[ "$only_enabled" == "enabled" ]]; then
      warn "当前没有启用的转发目标，请先添加或启用转发目标。" >&2
    else
      warn "当前没有转发目标。" >&2
    fi
    return 1
  fi
  display_forward_selection_list "$only_enabled" "$title" >&2
  while true; do
    choice="$(prompt_value "请输入编号或名称，直接回车返回")"
    [[ -z "$choice" ]] && return 1
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
      name="$(forwards_rows | awk -F'\t' -v idx="$choice" -v only="$only_enabled" 'only=="enabled" && $7!="true"{next} {i++} i==idx {print $1; exit}')"
      if [[ -z "$name" ]]; then
        warn "编号无效，请重新选择。" >&2
        continue
      fi
    else
      name="$(forwards_rows | awk -F'\t' -v n="$choice" -v only="$only_enabled" 'only=="enabled" && $7!="true"{next} $1==n {print $1; exit}')"
    fi
    if [[ -n "$name" ]]; then
      printf '%s' "$name"
      return 0
    fi
    warn "转发不存在：${choice}" >&2
  done
}

entry_pool_for_prompt() {
  local start end
  if [[ -f "$ENTRY_EXPOSE_ENV" ]]; then
    start="$(entry_expose_start)"
    end="$(entry_expose_end)"
    if is_port "$start" && is_port "$end" && (( start <= end )); then
      printf 'pool\t%s\t%s\n' "$start" "$end"
      return 0
    fi
  fi
  printf 'fallback\t%s\t%s\n' "$FORWARD_ENTRY_PORT_FALLBACK_START" "$FORWARD_ENTRY_PORT_FALLBACK_END"
}

next_available_forward_entry_port() {
  local start="$1" end="$2" port
  for ((port=start; port<=end; port++)); do
    if forward_entry_port_available_for_recommend "$port"; then
      printf '%s' "$port"
      return 0
    fi
  done
  return 1
}

prompt_forward_entry_port() {
  local current_name="${1:-}" current_port="${2:-}" kind start end recommended default prompt value conflict
  IFS=$'\t' read -r kind start end <<<"$(entry_pool_for_prompt)"
  recommended="$(next_available_forward_entry_port "$start" "$end" 2>/dev/null || true)"
  if [[ -z "$recommended" ]]; then
    if [[ -n "$current_port" ]] && port_in_range "$current_port" "$start" "$end"; then
      recommended="$current_port"
    else
      fail "业务入口端口池已无可推荐端口，请调整端口池或清理旧转发目标。"
      return 1
    fi
  fi
  default="${current_port:-$recommended}"
  if [[ "$kind" == "pool" ]]; then
    prompt="公网入口端口，入口端口池 ${start}-${end}，推荐 ${recommended}"
  else
    prompt="公网入口端口，常见范围 ${start}-${end}，推荐 ${recommended}"
  fi
  while true; do
    value="$(prompt_value "$prompt" "$default")"
    if ! is_port "$value"; then
      warn "公网入口端口必须是 1-65535。"
      continue
    fi
    if ! port_in_range "$value" "$start" "$end"; then
      warn "公网入口端口 ${value} 不在 ${start}-${end} 范围内。"
      continue
    fi
    conflict="$(forward_entry_port_conflict_message "$value" "$current_name" "$current_port" || true)"
    if [[ -n "$conflict" ]]; then
      warn "端口 ${value} ${conflict}。"
      prompt_yes_no "是否重新输入？" "Y" || return 1
      default="$recommended"
      continue
    fi
    printf '%s' "$value"
    return 0
  done
}

validate_forwards_tsv() {
  local file="${1:-$FORWARDS_TSV}"
  [[ "$file" == "$FORWARDS_TSV" ]] && ensure_tsv_files
  [[ -f "$file" ]] || { fail "forwards.tsv 不存在：${file}"; return 1; }
  local line_no=0 bad=0 line nf name entry_port target_host target_port _out_iface _route_table enabled _comment
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))
    line="${line%$'\r'}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    nf="$(awk -F'\t' '{print NF}' <<<"$line")"
    if (( nf < 7 )); then
      fail "第 ${line_no} 行字段数错误：至少 7 列（备注可为空），实际 ${nf} 列。"
      echo "当前行内容：${line}" >&2
      echo "请使用 TAB 分隔字段；建议通过菜单 添加转发目标 生成，不要用空格对齐。" >&2
      bad=1
      continue
    fi
    name="$(awk -F'\t' '{print $1}' <<<"$line")"
    entry_port="$(awk -F'\t' '{print $2}' <<<"$line")"
    target_host="$(awk -F'\t' '{print $3}' <<<"$line")"
    target_port="$(awk -F'\t' '{print $4}' <<<"$line")"
    enabled="$(awk -F'\t' '{print $7}' <<<"$line")"
    name="$(normalize_menu_choice "$name")"
    enabled="$(normalize_menu_choice "$enabled")"
    if [[ -z "$name" || -z "$entry_port" || -z "$target_host" || -z "$target_port" || -z "$enabled" ]]; then
      fail "第 ${line_no} 行存在必填字段为空。"
      echo "当前行内容：${line}" >&2
      bad=1
      continue
    fi
    if ! is_port "$entry_port"; then
      fail "第 ${line_no} 行 entry_port 非法：${entry_port}"
      bad=1
    fi
    if ! is_port "$target_port"; then
      fail "第 ${line_no} 行 target_port 非法：${target_port}"
      bad=1
    fi
    case "$enabled" in
      true|false) ;;
      *) fail "第 ${line_no} 行 enabled 必须是 true 或 false：${enabled}"; bad=1 ;;
    esac
  done <"$file"
  (( bad == 0 ))
}

enabled_forwards_count() {
  validate_forwards_tsv >/dev/null || return 1
  forwards_rows | awk -F'\t' '$7=="true"{c++} END{print c+0}'
}

nft_project_table_text() {
  command -v nft >/dev/null 2>&1 || return 0
  nft list table inet leikwan_forward 2>/dev/null || true
}

nft_has_dnat_rules() {
  nft_project_table_text | awk '
    {
      line = " " $0 " "
      gsub(/[[:space:]]+/, " ", line)
      if (line ~ / dnat( |$)/) found = 1
    }
    END { exit !found }
  '
}

nft_has_cloud_dnat() {
  local proto="$1" relay_ip="$2" entry_port="$3"
  nft_project_table_text | awk -v proto="$proto" -v dport="$entry_port" -v target="$relay_ip" '
    {
      line = " " $0 " "
      gsub(/[[:space:]]+/, " ", line)
      if (index(line, " " proto " dport " dport) && index(line, " dnat ") && index(line, target)) found = 1
    }
    END { exit !found }
  '
}

nft_has_relay_dnat() {
  local proto="$1" entry_port="$2" target_ip="$3" target_port="$4"
  local target="${target_ip}:${target_port}"
  nft_project_table_text | awk -v proto="$proto" -v dport="$entry_port" -v target="$target" '
    {
      line = " " $0 " "
      gsub(/[[:space:]]+/, " ", line)
      if (index(line, " " proto " dport " dport) && index(line, " dnat ") && index(line, target)) found = 1
    }
    END { exit !found }
  '
}

nft_existing_project_chains() {
  nft_project_table_text | awk '
    /^[[:space:]]*chain[[:space:]]+/ && $2 != "" && !seen[$2]++ { print $2 }
  '
}

is_mss_value() {
  local value="$1"
  [[ "$value" =~ ^[0-9]+$ ]] && (( value >= 500 && value <= 1460 ))
}

mss_clamp_enabled() {
  local config_value value
  config_value="$(env_file_get "$MSS_CONFIG" ENABLE_MSS_CLAMP)"
  value="${LEIKWAN_ENABLE_MSS_CLAMP:-${config_value:-$ENABLE_MSS_CLAMP}}"
  case "$value" in
    true|TRUE|yes|YES|1|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

tcp_mss_clamp_value() {
  local config_value value
  config_value="$(env_file_get "$MSS_CONFIG" TCP_MSS_CLAMP)"
  [[ -n "$config_value" ]] || config_value="$(env_file_get "$MSS_CONFIG" DEFAULT_TCP_MSS_CLAMP)"
  value="${LEIKWAN_TCP_MSS_CLAMP:-${TCP_MSS_CLAMP:-${config_value:-$DEFAULT_TCP_MSS_CLAMP}}}"
  if is_mss_value "$value"; then
    printf '%s' "$value"
  else
    printf '%s' "$DEFAULT_TCP_MSS_CLAMP"
  fi
}

nft_has_mss_clamp() {
  local mss
  mss="$(tcp_mss_clamp_value)"
  nft_project_table_text | awk -v mss="$mss" '
    {
      line = " " $0 " "
      gsub(/[[:space:]]+/, " ", line)
      if (index(line, " tcp ") && index(line, " maxseg ") && index(line, " size set ")) {
        if (index(line, " " mss " ") || line ~ / maxseg size set( |$)/) found = 1
      }
    }
    END { exit !found }
  '
}

ss_port_listening() {
  local proto="$1" port="$2" opt
  command -v ss >/dev/null 2>&1 || return 1
  case "$proto" in
    tcp) opt="-lntH" ;;
    udp) opt="-lunH" ;;
    *) return 1 ;;
  esac
  ss "$opt" 2>/dev/null | awk -v p=":${port}" '$4 ~ p"$" {found=1} END{exit !found}'
}

port_listening_any() {
  local port="$1"
  ss_port_listening tcp "$port" || ss_port_listening udp "$port"
}

nft_ruleset_text() {
  command -v nft >/dev/null 2>&1 || return 0
  nft list ruleset 2>/dev/null || true
}

nft_text_has_dport() {
  local port="$1" proto="${2:-}" source="${3:-project}" text
  if [[ "$source" == "ruleset" ]]; then
    text="$(nft_ruleset_text)"
  else
    text="$(nft_project_table_text)"
  fi
  awk -v p="$port" -v proto="$proto" '
    function token_match(t, r) {
      gsub(/[,{};]/, " ", t)
      if (t ~ /^[0-9]+$/) return t == p
      if (t ~ /^[0-9]+-[0-9]+$/) {
        split(t, r, "-")
        return p >= r[1] && p <= r[2]
      }
      return 0
    }
    {
      if (proto != "" && $0 !~ proto "[[:space:]]+dport") next
      n = split($0, parts, /dport[[:space:]]+/)
      for (i = 2; i <= n; i++) {
        rest = parts[i]
        gsub(/[{};,]/, " ", rest)
        split(rest, tokens, /[[:space:]]+/)
        for (j in tokens) {
          if (token_match(tokens[j])) found = 1
        }
      }
    }
    END { exit !found }
  ' <<<"$text"
}

nft_project_has_dport() {
  nft_text_has_dport "$1" "${2:-}" project
}

nft_ruleset_has_dport() {
  nft_text_has_dport "$1" "${2:-}" ruleset
}

easytier_port_conflict_message() {
  local port="$1" current_name="${2:-}" name _public_host _et_ip _proto _port _weight _enabled
  local pending_name _pending_ip _pending_proto _pending_port _pending_created_at
  if [[ -n "$current_name" ]] && entries_rows | awk -F'\t' -v n="$current_name" -v p="$port" '$1==n && $5==p {found=1} END{exit !found}'; then
    return 1
  fi
  while IFS=$'\t' read -r name _public_host _et_ip _proto _port _weight _enabled; do
    [[ "$_port" == "$port" && "$name" != "$current_name" ]] || continue
    printf '已被公网入口 %s 使用' "$(entry_label "$name")"
    return 0
  done < <(entries_rows)
  while IFS=$'\t' read -r pending_name _pending_ip _pending_proto _pending_port _pending_created_at; do
    [[ "$_pending_port" == "$port" && "$pending_name" != "$current_name" ]] || continue
    printf '已被 pending 公网入口 %s 预占' "$(entry_label "$pending_name")"
    return 0
  done < <(pending_entries_rows)
  if port_listening_any "$port"; then
    printf '已被本机监听进程占用'
    return 0
  fi
  if nft_ruleset_has_dport "$port"; then
    printf '已出现在 nftables dport 规则中'
    return 0
  fi
  return 1
}

easytier_port_available_for_recommend() {
  local port="$1" conflict
  is_fast_port "$port" || return 1
  conflict="$(easytier_port_conflict_message "$port" "" || true)"
  [[ -z "$conflict" ]]
}

forward_entry_port_conflict_message() {
  local port="$1" current_name="${2:-}" current_port="${3:-}"
  local name _port _target_host _target_port _out_iface _route_table _enabled _comment
  while IFS=$'\t' read -r name _port _target_host _target_port _out_iface _route_table _enabled _comment; do
    [[ "$_port" == "$port" && "$name" != "$current_name" ]] || continue
    printf '已被转发目标 %s 使用' "$name"
    return 0
  done < <(forwards_rows)
  if [[ "$port" == "$current_port" ]]; then
    return 1
  fi
  if port_listening_any "$port"; then
    printf '已被本机监听进程占用'
    return 0
  fi
  if nft_ruleset_has_dport "$port"; then
    printf '已出现在 nftables dport 规则中'
    return 0
  fi
  return 1
}

forward_entry_port_available_for_recommend() {
  local port="$1" conflict
  conflict="$(forward_entry_port_conflict_message "$port" "" "" || true)"
  [[ -z "$conflict" ]]
}

entry_exists() {
  local name="$1"
  entries_rows | awk -F'\t' -v n="$name" '$1==n {found=1} END{exit !found}'
}

pending_entries_count() {
  pending_entries_rows | awk 'END{print NR+0}'
}

display_pending_entries() {
  local labels
  labels=$'编号\t名称\tEasyTier IP\t协议\t端口\tcreated_at'
  pending_entries_rows | awk -F'\t' '
    function display_name(n) {
      if (n ~ /^public[0-9]+$/) return "公网" substr(n, 7) "(" n ")"
      return n
    }
    {
      proto=($3=="tcp,udp" ? "tcp+udp" : $3)
      printf "%d)\t%s\t%s\t%s\t%s\t%s\n", ++i, display_name($1), $2, proto, $4, ($5!="" ? $5 : "-")
    }
  ' | render_tsv_table 88 "$labels"
}

entry_reserved_count() {
  { entries_rows; pending_entries_rows; } | awk 'END{print NR+0}'
}

entry_name_reserved() {
  local name="$1"
  entries_rows | awk -F'\t' -v n="$name" '$1==n {found=1} END{exit !found}' && return 0
  pending_entries_rows | awk -F'\t' -v n="$name" '$1==n {found=1} END{exit !found}'
}

entry_et_ip_reserved() {
  local et_ip="$1"
  entries_rows | awk -F'\t' -v ip="$et_ip" '$3==ip {found=1} END{exit !found}' && return 0
  pending_entries_rows | awk -F'\t' -v ip="$et_ip" '$2==ip {found=1} END{exit !found}'
}

entry_easytier_port_reserved() {
  local port="$1"
  entries_rows | awk -F'\t' -v p="$port" '$5==p {found=1} END{exit !found}' && return 0
  pending_entries_rows | awk -F'\t' -v p="$port" '$4==p {found=1} END{exit !found}'
}

pending_entry_is_stale() {
  local created_at="$1" now created_epoch
  [[ -n "$created_at" ]] || return 1
  now="$(date -u '+%s')"
  created_epoch="$(date -u -d "$created_at" '+%s' 2>/dev/null || true)"
  [[ -n "$created_epoch" ]] && (( now - created_epoch > 86400 ))
}

pending_entries_have_stale() {
  local _name _et_ip _proto _port created_at
  while IFS=$'\t' read -r _name _et_ip _proto _port created_at; do
    if pending_entry_is_stale "$created_at"; then
      return 0
    fi
  done < <(pending_entries_rows)
  return 1
}

clean_stale_pending_entries() {
  local tmp name et_ip proto port created_at
  [[ -f "$PENDING_ENTRIES_TSV" ]] || return 0
  tmp="$(mktemp)"
  while IFS=$'\t' read -r name et_ip proto port created_at; do
    pending_entry_is_stale "$created_at" && continue
    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$et_ip" "$proto" "$port" "$created_at" >>"$tmp"
  done < <(pending_entries_rows)
  if [[ -s "$tmp" ]]; then
    write_file "$PENDING_ENTRIES_TSV" "$(cat "$tmp")" 600
  else
    rm -f "$PENDING_ENTRIES_TSV"
  fi
  rm -f "$tmp"
}

prompt_pending_entries_before_generation() {
  local count
  count="$(pending_entries_count)"
  (( count > 0 )) || return 0
  info "当前未完成的公网入口接入码："
  display_pending_entries
  if pending_entries_have_stale; then
    warn "存在超过 24 小时的未完成入口接入码。"
    if prompt_yes_no "是否清理过期 pending 记录？" "Y"; then
      clean_stale_pending_entries
    fi
  fi
  count="$(pending_entries_count)"
  (( count == 0 )) && return 0
  prompt_yes_no "是否继续生成下一个入口码？" "N"
}

reserve_pending_entry() {
  local name="$1" et_ip="$2" protocols="$3" port="$4" created_at tmp
  ensure_base_dirs
  protocols="$(normalize_easytier_protocols "$protocols")" || return 1
  created_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  tmp="$(mktemp)"
  pending_entries_rows | awk -F'\t' -v n="$name" -v ip="$et_ip" -v p="$port" '
    $1==n || ($2==ip && $4==p) {next}
    {print}
  ' >"$tmp"
  printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$et_ip" "$protocols" "$port" "$created_at" >>"$tmp"
  write_file "$PENDING_ENTRIES_TSV" "$(cat "$tmp")" 600
  rm -f "$tmp"
}

clear_pending_entry_reservation() {
  local name="$1" et_ip="$2" port="$3" tmp
  [[ -f "$PENDING_ENTRIES_TSV" ]] || return 0
  tmp="$(mktemp)"
  pending_entries_rows | awk -F'\t' -v n="$name" -v ip="$et_ip" -v p="$port" '
    $1==n || ($2==ip && $4==p) {next}
    {print}
  ' >"$tmp"
  if [[ -s "$tmp" ]]; then
    write_file "$PENDING_ENTRIES_TSV" "$(cat "$tmp")" 600
  else
    rm -f "$PENDING_ENTRIES_TSV"
  fi
  rm -f "$tmp"
}

clear_pending_entry_exact() {
  local name="$1" et_ip="$2" port="$3" tmp
  [[ -f "$PENDING_ENTRIES_TSV" ]] || return 0
  tmp="$(mktemp)"
  pending_entries_rows | awk -F'\t' -v n="$name" -v ip="$et_ip" -v p="$port" '
    $1==n && $2==ip && $4==p {next}
    {print}
  ' >"$tmp"
  if [[ -s "$tmp" ]]; then
    write_file "$PENDING_ENTRIES_TSV" "$(cat "$tmp")" 600
  else
    rm -f "$PENDING_ENTRIES_TSV"
  fi
  rm -f "$tmp"
}

forward_exists() {
  local name="$1"
  forwards_rows | awk -F'\t' -v n="$name" '$1==n {found=1} END{exit !found}'
}

next_entry_name() {
  local slot
  slot="$(next_entry_slot)" || return 1
  printf 'public%s' "$slot"
}

next_entry_et_ip() {
  local prefix="10.198.1" slot ip
  slot="$(next_entry_slot)" || return 1
  for ((; slot<=253; slot++)); do
    ip="${prefix}.$((slot + 1))"
    if ! entry_et_ip_reserved "$ip"; then
      printf '%s' "$ip"
      return 0
    fi
  done
  return 1
}

next_entry_easytier_port() {
  local slot port
  slot="$(next_entry_slot)" || return 1
  for ((; slot<=253; slot++)); do
    port=$((DEFAULT_EASYTIER_PORT + slot - 1))
    (( port <= FAST_PORT_RANGE_END )) || break
    if easytier_port_available_for_recommend "$port"; then
      printf '%s' "$port"
      return 0
    fi
  done
  for ((port=FAST_PORT_RANGE_START; port<DEFAULT_EASYTIER_PORT; port++)); do
    if easytier_port_available_for_recommend "$port"; then
      printf '%s' "$port"
      return 0
    fi
  done
  return 1
}

entry_slot_from_fields() {
  local name="$1" et_ip="$2" port="$3" slot
  if [[ "$name" =~ ^public([0-9]+)$ ]]; then
    slot="${BASH_REMATCH[1]}"
    (( slot >= 1 && slot <= 253 )) && printf '%s\n' "$slot"
  fi
  if [[ "$et_ip" =~ ^10\.198\.1\.([0-9]+)$ ]]; then
    slot=$((BASH_REMATCH[1] - 1))
    (( slot >= 1 && slot <= 253 )) && printf '%s\n' "$slot"
  fi
  if [[ "$port" =~ ^[0-9]+$ ]]; then
    slot=$((port - DEFAULT_EASYTIER_PORT + 1))
    (( slot >= 1 && slot <= 253 )) && printf '%s\n' "$slot"
  fi
}

entry_reserved_slots() {
  local name public_host et_ip proto port weight enabled created_at
  while IFS=$'\t' read -r name public_host et_ip proto port weight enabled; do
    entry_slot_from_fields "$name" "$et_ip" "$port"
  done < <(entries_rows)
  while IFS=$'\t' read -r name et_ip proto port created_at; do
    entry_slot_from_fields "$name" "$et_ip" "$port"
  done < <(pending_entries_rows)
}

highest_reserved_entry_slot() {
  entry_reserved_slots | awk 'BEGIN{m=0} $1 ~ /^[0-9]+$/ && $1>m {m=$1} END{print m+0}'
}

next_entry_slot() {
  local slot
  slot="$(highest_reserved_entry_slot)"
  slot=$((slot + 1))
  (( slot >= 1 && slot <= 253 )) || return 1
  printf '%s' "$slot"
}

relay_network_env_ready() {
  local role network_name network_secret
  [[ -f "$NETWORK_ENV" ]] || return 1
  role="$(env_file_get "$NETWORK_ENV" ROLE)"
  network_name="$(env_file_get "$NETWORK_ENV" EASYTIER_NETWORK_NAME)"
  network_secret="$(env_file_get "$NETWORK_ENV" EASYTIER_NETWORK_SECRET)"
  [[ "$role" == "leikwan-relay" && -n "$network_name" && -n "$network_secret" ]]
}

validate_entry_official_fields() {
  local name="$1" et_ip="$2" port="$3" current_name="${4:-}" used_by
  [[ -n "$name" ]] || { warn "公网入口名称不能为空。"; return 1; }
  [[ -n "$et_ip" ]] || { warn "EasyTier IP 不能为空。"; return 1; }
  if ! is_ipv4 "$et_ip"; then
    if looks_like_domain "$et_ip"; then
      warn "你输入的是域名，不是 EasyTier 虚拟 IP。请填写 10.198.1.x 这类虚拟 IP。"
      warn "DDNS 域名请在后面的 本机公网 IP / 域名 填写。"
    else
      warn "EasyTier IP 必须是 IPv4：${et_ip}"
    fi
    return 1
  fi
  is_fast_port "$port" || { warn "EasyTier 端口必须位于 ${FAST_PORT_RANGE_START}-${FAST_PORT_RANGE_END}。"; return 1; }
  if entries_rows | awk -F'\t' -v n="$name" -v cur="$current_name" '$1==n && $1!=cur {found=1} END{exit !found}'; then
    warn "公网入口名称已存在：${name}"
    return 1
  fi
  if entries_rows | awk -F'\t' -v ip="$et_ip" -v cur="$current_name" '$3==ip && $1!=cur {found=1} END{exit !found}'; then
    warn "EasyTier IP 已被使用：${et_ip}"
    return 1
  fi
  used_by="$(entries_rows | awk -F'\t' -v p="$port" -v cur="$current_name" '$5==p && $1!=cur {print $1; exit}')"
  if [[ -n "$used_by" ]]; then
    warn "端口 ${port} 已被公网入口 $(entry_label "$used_by") 使用。"
    prompt_yes_no "是否重新输入？" "Y" || return 1
    return 1
  fi
  return 0
}

validate_unique_entry_fields() {
  local name="$1" et_ip="$2" port="$3" current_name="${4:-}" conflict used_by
  validate_entry_official_fields "$name" "$et_ip" "$port" "$current_name" || return 1
  if pending_entries_rows | awk -F'\t' -v n="$name" '$1==n {found=1} END{exit !found}'; then
    warn "公网入口名称已被未完成接入码预占：${name}"
    return 1
  fi
  if pending_entries_rows | awk -F'\t' -v ip="$et_ip" '$2==ip {found=1} END{exit !found}'; then
    warn "EasyTier IP 已被未完成接入码预占：${et_ip}"
    return 1
  fi
  used_by="$(pending_entries_rows | awk -F'\t' -v p="$port" '$4==p {print $1; exit}')"
  if [[ -n "$used_by" ]]; then
    warn "端口 ${port} 已被 pending 公网入口 $(entry_label "$used_by") 预占。"
    prompt_yes_no "是否重新输入？" "Y" || return 1
    return 1
  fi
  conflict="$(easytier_port_conflict_message "$port" "$current_name" || true)"
  if [[ -n "$conflict" ]]; then
    warn "端口 ${port} ${conflict}。"
    prompt_yes_no "是否重新输入？" "Y" || return 1
    return 1
  fi
  return 0
}

pending_entry_by_ip_port() {
  local et_ip="$1" port="$2"
  pending_entries_rows | awk -F'\t' -v ip="$et_ip" -v p="$port" '$2==ip && $4==p {print; exit}'
}

pending_entry_by_name() {
  local name="$1"
  pending_entries_rows | awk -F'\t' -v n="$name" '$1==n {print; exit}'
}

replace_entry_row() {
  local row="$1" name old_name tmp
  name="${row%%$'\t'*}"
  old_name="${2:-$name}"
  ensure_tsv_files
  tmp="$(mktemp "${ENTRIES_DIR}/.tmp.entries.XXXXXX")"
  awk -F'\t' -v n="$name" -v old="$old_name" '$1==n || $1==old {next} {print}' "$ENTRIES_TSV" >"$tmp"
  printf '%s\n' "$row" >>"$tmp"
  write_file "$ENTRIES_TSV" "$(cat "$tmp")" 600
  rm -f "$tmp"
}

replace_forward_row() {
  local row="$1" name entry_port _rest tmp
  IFS=$'\t' read -r name entry_port _rest <<<"$row"
  ensure_tsv_files
  tmp="$(mktemp)"
  awk -F'\t' -v n="$name" -v p="$entry_port" '$1==n || $2==p {next} {print}' "$FORWARDS_TSV" >"$tmp"
  printf '%s\n' "$row" >>"$tmp"
  write_file "$FORWARDS_TSV" "$(cat "$tmp")" 600
  rm -f "$tmp"
}

quick_generate_network_pairing() {
  need_root_unless_dry_run
  ensure_base_dirs
  system_network_prepare || true
  install_packages openssl coreutils
  local network_name network_secret suggested_name suggested_ip suggested_protocols suggested_proto suggested_port has_network=0
  local candidate_name candidate_ip candidate_proto candidate_port
  prompt_pending_entries_before_generation || return 0
  if relay_network_env_ready; then
    network_name="$(env_file_get "$NETWORK_ENV" EASYTIER_NETWORK_NAME)"
    network_secret="$(env_file_get "$NETWORK_ENV" EASYTIER_NETWORK_SECRET)"
    has_network=1
    info "检测到已有 EasyTier 网络，正在复用现有 network name / secret。"
    info "本操作只生成新公网入口接入码，不会重启 relay，不会影响已接入入口。"
  else
    network_name="leikwan-$(random_hex 4)"
    network_secret="$(random_hex 32)"
  fi
  suggested_name="$(next_entry_name)"
  suggested_ip="$(next_entry_et_ip 2>/dev/null || printf '%s' "$ENTRY_ET_IP_DEFAULT")"
  suggested_protocols="$EASYTIER_PROTOCOLS_DEFAULT"
  suggested_proto="$EASYTIER_PROTOCOL_DEFAULT"
  suggested_port="$(next_entry_easytier_port 2>/dev/null || printf '%s' "$EASYTIER_PORT_DEFAULT")"
  echo
  echo "${BOLD}新增公网入口建议：${RESET}"
  echo "- 名称：$(entry_label "$suggested_name")"
  echo "- EasyTier IP：${suggested_ip}"
  echo "- EasyTier 监听：$(easytier_protocols_display "$suggested_protocols") / ${suggested_port}"
  echo
  if ! prompt_yes_no "是否使用以上推荐？" "Y"; then
    while true; do
      candidate_name="$(safe_name "$(prompt_value "公网入口名称" "$suggested_name")")"
      candidate_ip="$(prompt_easytier_ip "EasyTier IP" "$suggested_ip")"
      candidate_proto="$(prompt_easytier_protocols "EasyTier 传输模式" "$suggested_protocols")"
      candidate_port="$(prompt_port "EasyTier 监听端口（TCP+UDP，同端口，白名单 8000-9000）" "$suggested_port")"
      if validate_unique_entry_fields "$candidate_name" "$candidate_ip" "$candidate_port" ""; then
        suggested_name="$candidate_name"
        suggested_ip="$candidate_ip"
        suggested_protocols="$candidate_proto"
        suggested_proto="$(easytier_legacy_protocol "$suggested_protocols")"
        suggested_port="$candidate_port"
        break
      fi
    done
  else
    validate_unique_entry_fields "$suggested_name" "$suggested_ip" "$suggested_port" "" || return 0
  fi
  if (( has_network == 0 )); then
    write_file "$NETWORK_ENV" "ROLE=leikwan-relay
EASYTIER_NETWORK_NAME=${network_name}
EASYTIER_NETWORK_SECRET=${network_secret}
EASYTIER_LISTEN_PORT=${suggested_port}
EASYTIER_PROTOCOLS=${suggested_protocols}
EASYTIER_TCP_PORT=${suggested_port}
EASYTIER_UDP_PORT=${suggested_port}
EASYTIER_PROTOCOL=${suggested_proto}
EASYTIER_RELAY_ET_IP=${RELAY_ET_IP}" 600
  fi
  write_file "$NETWORK_PAIRING_FILE" "PAIRING_VERSION=0.4
ROLE=leikwan-relay
EASYTIER_NETWORK_NAME=${network_name}
EASYTIER_NETWORK_SECRET=${network_secret}
RELAY_ET_IP=${RELAY_ET_IP}
SUGGESTED_ENTRY_NAME=${suggested_name}
SUGGESTED_ENTRY_DISPLAY_NAME=$(entry_display_name "$suggested_name")
SUGGESTED_ENTRY_ET_IP=${suggested_ip}
SUGGESTED_EASYTIER_PROTOCOLS=${suggested_protocols}
SUGGESTED_EASYTIER_TCP_PORT=${suggested_port}
SUGGESTED_EASYTIER_UDP_PORT=${suggested_port}
SUGGESTED_EASYTIER_PROTOCOL=${suggested_proto}
SUGGESTED_EASYTIER_PORT=${suggested_port}" 600
  reserve_pending_entry "$suggested_name" "$suggested_ip" "$suggested_protocols" "$suggested_port"
  echo
  echo "${BOLD}公网入口接入码摘要${RESET}"
  echo "- 公网入口：$(entry_label "$suggested_name")"
  echo "- EasyTier IP：${suggested_ip}"
  echo "- EasyTier 监听：$(easytier_protocols_display "$suggested_protocols")/${suggested_port}"
  show_pairing_code_and_confirm "公网入口接入码" \
    "-----BEGIN LEIKWAN EASYTIER NETWORK-----" \
    "-----END LEIKWAN EASYTIER NETWORK-----" \
    "$NETWORK_PAIRING_FILE" \
    "LEIKWAN_EASYTIER_NETWORK_BASE64" \
    "去 A 公网入口机，进入快速组网，选择粘贴网络码部署入口。"
}

quick_deploy_entry_from_network_pairing() {
  need_root_unless_dry_run
  ensure_base_dirs
  guard_entry_join_role || return 0
  system_network_prepare || true
  local source="${1:-}" tmp role network_name network_secret relay_ip name et_ip proto port public_host detected service service_name legacy_proto
  tmp="$(mktemp)"
  read_pairing_code "$tmp" "B 利群主机" "-----END LEIKWAN EASYTIER NETWORK-----" "LEIKWAN_EASYTIER_NETWORK_BASE64" "$source" || { rm -f "$tmp"; return 1; }
  role="$(env_file_get "$tmp" ROLE)"
  case "$role" in
    leikwan-relay) ;;
    cloud-entry) fail "你粘贴的是入口码，需要回到 B 利群主机，进入“快速组网”，选择“粘贴入口返回码完成接入”。"; rm -f "$tmp"; return 1 ;;
    *) fail "这不是 EasyTier 网络码，请确认粘贴的是 B 生成的那段。"; rm -f "$tmp"; return 1 ;;
  esac
  require_pairing_fields "$tmp" PAIRING_VERSION ROLE EASYTIER_NETWORK_NAME EASYTIER_NETWORK_SECRET RELAY_ET_IP SUGGESTED_ENTRY_NAME SUGGESTED_ENTRY_ET_IP || { rm -f "$tmp"; return 1; }
  network_name="$(env_file_get "$tmp" EASYTIER_NETWORK_NAME)"
  network_secret="$(env_file_get "$tmp" EASYTIER_NETWORK_SECRET)"
  relay_ip="$(env_file_get "$tmp" RELAY_ET_IP)"
  name="$(safe_name "$(env_file_get "$tmp" SUGGESTED_ENTRY_NAME)")"
  et_ip="$(env_file_get "$tmp" SUGGESTED_ENTRY_ET_IP)"
  proto="$(easytier_protocols_from_env "$tmp" SUGGESTED_EASYTIER_PROTOCOLS SUGGESTED_EASYTIER_PROTOCOL "$EASYTIER_PROTOCOLS_DEFAULT")" || { fail "网络码里的 EasyTier 传输模式无效。"; rm -f "$tmp"; return 1; }
  port="$(easytier_port_from_env "$tmp" "$proto" SUGGESTED_EASYTIER_TCP_PORT SUGGESTED_EASYTIER_UDP_PORT SUGGESTED_EASYTIER_PORT)" || { rm -f "$tmp"; return 1; }
  local default_name="$name" default_et_ip="$et_ip" default_proto="$proto" default_port="$port"
  local candidate_name candidate_ip candidate_proto candidate_port
  while true; do
    candidate_name="$(safe_name "$(prompt_value "本机公网入口名称" "$default_name")")"
    candidate_ip="$(prompt_easytier_ip "本机 EasyTier IP" "$default_et_ip")"
    candidate_proto="$(prompt_easytier_protocols "EasyTier 传输模式" "$default_proto")"
    candidate_port="$(prompt_port "EasyTier 监听端口（TCP+UDP，同端口，白名单 8000-9000）" "$default_port")"
    if validate_unique_entry_fields "$candidate_name" "$candidate_ip" "$candidate_port" "$candidate_name"; then
      name="$candidate_name"
      et_ip="$candidate_ip"
      proto="$candidate_proto"
      port="$candidate_port"
      break
    fi
  done
  detected="$(detect_public_ipv4 || true)"
  public_host="$(prompt_value "请输入本机公网 IP / 域名，用于 B 连接 EasyTier" "$detected")"
  [[ -n "$public_host" ]] || public_host="$(prompt_host "请输入本机公网 IP / 域名")"
  confirm_summary "entry 快速部署摘要" "入口名称：${name}\n公网地址：${public_host}\nEasyTier IP：${et_ip}\nEasyTier 监听：$(easytier_protocols_display "$proto")/${port}\nRelay EasyTier IP：${relay_ip}" || { rm -f "$tmp"; return 0; }
  legacy_proto="$(easytier_legacy_protocol "$proto")" || { rm -f "$tmp"; return 1; }
  write_file "$NETWORK_ENV" "ROLE=cloud-entry
ENTRY_NAME=${name}
ENTRY_DISPLAY_NAME=$(entry_display_name "$name")
ENTRY_ET_IP=${et_ip}
EASYTIER_NETWORK_NAME=${network_name}
EASYTIER_NETWORK_SECRET=${network_secret}
EASYTIER_LISTEN_PORT=${port}
EASYTIER_PROTOCOLS=${proto}
EASYTIER_TCP_PORT=${port}
EASYTIER_UDP_PORT=${port}
EASYTIER_PROTOCOL=${legacy_proto}
EASYTIER_RELAY_ET_IP=${relay_ip}" 600
  install_easytier_binary || { rm -f "$tmp"; return 1; }
  service="$(render_entry_service "$name" "$et_ip" "$proto" "$port")" || { rm -f "$tmp"; return 1; }
  service_name="$(entry_service_name "$name")"
  write_file "$(entry_service_path "$name")" "$service" 644
  start_service_file "$service_name"
  wait_et_ip "$et_ip" 15 || warn "15 秒内未检测到 EasyTier IP：${et_ip}"
  if easytier_protocols_has "$proto" tcp; then
    if ss -lntH 2>/dev/null | awk -v p=":${port}" '$4 ~ p"$" {found=1} END{exit !found}'; then ok "EasyTier TCP ${port} 已监听"; else warn "EasyTier TCP ${port} 未监听"; fi
  fi
  if easytier_protocols_has "$proto" udp; then
    if ss -lunH 2>/dev/null | awk -v p=":${port}" '$4 ~ p"$" {found=1} END{exit !found}'; then ok "EasyTier UDP ${port} 已监听"; else warn "EasyTier UDP ${port} 未监听"; fi
  fi
  replace_entry_row "${name}"$'\t'"${public_host}"$'\t'"${et_ip}"$'\t'"${proto}"$'\t'"${port}"$'\t'"100"$'\t'"true"
write_file "$ENTRY_PAIRING_FILE" "PAIRING_VERSION=0.4
ROLE=cloud-entry
ENTRY_NAME=${name}
ENTRY_DISPLAY_NAME=$(entry_display_name "$name")
ENTRY_PUBLIC_HOST=${public_host}
ENTRY_ET_IP=${et_ip}
EASYTIER_PROTOCOLS=${proto}
EASYTIER_TCP_PORT=${port}
EASYTIER_UDP_PORT=${port}
EASYTIER_PROTOCOL=${legacy_proto}
EASYTIER_PORT=${port}
WEIGHT=100
ENABLED=true" 600
  rm -f "$tmp"
  echo
  echo "${BOLD}公网入口返回码摘要${RESET}"
  echo "- 公网入口：$(entry_label "$name")"
  echo "- 公网地址：${public_host}"
  echo "- EasyTier IP：${et_ip}"
  echo "- EasyTier 监听：$(easytier_protocols_display "$proto")/${port}"
  info "如果 A 在家宽 / NAT 后面，请在路由器中同时映射 TCP 和 UDP ${port} 到本机。"
  info "如果只映射 TCP，则 UDP peer 不会生效，但 TCP 仍可用。"
  info "如果只映射 UDP，则 TCP peer 不会生效，但 UDP 仍可用。"
  show_pairing_code_and_confirm "公网入口返回码" \
    "-----BEGIN LEIKWAN EASYTIER ENTRY-----" \
    "-----END LEIKWAN EASYTIER ENTRY-----" \
    "$ENTRY_PAIRING_FILE" \
    "LEIKWAN_EASYTIER_ENTRY_BASE64" \
    "回到 B 利群主机，选择粘贴入口返回码完成接入。"
}

quick_deploy_relay_from_entry_pairing() {
  need_root_unless_dry_run
  ensure_base_dirs
  guard_relay_join_role || return 0
  [[ -f "$NETWORK_ENV" ]] || { fail "缺少 ${NETWORK_ENV}，请先在 B 执行 pair relay-init。"; return 0; }
  local source="${1:-}" tmp role name public_host et_ip proto port weight enabled row
  local pending_match pending_same_name pending_name pending_et_ip _pending_proto pending_port _pending_created_at
  local same_name pending_same_et_ip pending_same_proto pending_same_port _pending_same_created_at
  tmp="$(mktemp)"
  read_pairing_code "$tmp" "A 公网入口机" "-----END LEIKWAN EASYTIER ENTRY-----" "LEIKWAN_EASYTIER_ENTRY_BASE64" "$source" || { rm -f "$tmp"; return 0; }
  role="$(env_file_get "$tmp" ROLE)"
  case "$role" in
    cloud-entry) ;;
    leikwan-relay) fail "你粘贴的是网络码，需要回到 A 公网入口，进入“快速组网”，选择“粘贴接入码并部署入口”。"; rm -f "$tmp"; return 0 ;;
    *) fail "这不是 EasyTier 入口码，请确认粘贴的是 A 生成的那段。"; rm -f "$tmp"; return 0 ;;
  esac
  require_pairing_fields "$tmp" PAIRING_VERSION ROLE ENTRY_NAME ENTRY_PUBLIC_HOST ENTRY_ET_IP || { rm -f "$tmp"; return 0; }
  name="$(safe_name "$(env_file_get "$tmp" ENTRY_NAME)")"
  public_host="$(env_file_get "$tmp" ENTRY_PUBLIC_HOST)"
  et_ip="$(env_file_get "$tmp" ENTRY_ET_IP)"
  proto="$(easytier_protocols_from_env "$tmp" EASYTIER_PROTOCOLS EASYTIER_PROTOCOL "$EASYTIER_PROTOCOLS_DEFAULT")" || { fail "入口码里的 EasyTier 传输模式无效。"; rm -f "$tmp"; return 0; }
  port="$(easytier_port_from_env "$tmp" "$proto" EASYTIER_TCP_PORT EASYTIER_UDP_PORT EASYTIER_PORT)" || { rm -f "$tmp"; return 0; }
  pending_match="$(pending_entry_by_ip_port "$et_ip" "$port")"
  pending_same_name="$(pending_entry_by_name "$name")"
  if [[ -n "$pending_same_name" ]]; then
    IFS=$'\t' read -r same_name pending_same_et_ip pending_same_proto pending_same_port _pending_same_created_at <<<"$pending_same_name"
    if [[ "$pending_same_et_ip" != "$et_ip" || "$pending_same_port" != "$port" ]]; then
      warn "未完成接入码同名但 EasyTier IP / 端口不同：${same_name} ${pending_same_et_ip} $(easytier_protocols_display "$pending_same_proto")/${pending_same_port}"
      warn "ENTRY 返回码为：${name} ${et_ip}/${port}。"
      if ! prompt_yes_no "是否忽略这条 pending 并继续保存 ENTRY？" "N"; then
        rm -f "$tmp"
        return 0
      fi
    fi
  fi
  if ! validate_entry_official_fields "$name" "$et_ip" "$port" "$name"; then
    rm -f "$tmp"
    return 0
  fi
  weight="$(env_file_get "$tmp" WEIGHT)"; weight="${weight:-100}"
  enabled="$(env_file_get "$tmp" ENABLED)"; enabled="${enabled:-true}"
  confirm_summary "relay 接入入口摘要" "入口名称：${name}\n入口公网：${public_host}:${port}\n入口 EasyTier 监听：$(easytier_protocols_display "$proto")/${port}\n入口 EasyTier IP：${et_ip}\nRelay EasyTier IP：${RELAY_ET_IP}" || { rm -f "$tmp"; return 0; }
  row="${name}"$'\t'"${public_host}"$'\t'"${et_ip}"$'\t'"${proto}"$'\t'"${port}"$'\t'"${weight}"$'\t'"${enabled}"
  replace_entry_row "$row"
  if [[ -n "$pending_match" ]]; then
    IFS=$'\t' read -r pending_name pending_et_ip _pending_proto pending_port _pending_created_at <<<"$pending_match"
    clear_pending_entry_exact "$pending_name" "$pending_et_ip" "$pending_port"
    ok "已清理未完成接入码预占：${pending_name} / ${pending_et_ip} / ${pending_port}"
    if [[ "$pending_name" != "$name" ]]; then
      info "ENTRY 名称 ${name} 与 pending 名称 ${pending_name} 不同，已按返回码名称保存。"
    fi
  fi
  ok "已保存入口配置：${name}。"
  prompt_apply_relay_after_entry_change || { rm -f "$tmp"; return 1; }
  info "下一步：在 B 添加后端转发目标并生成转发接入码，A 粘贴接入码即可（无需手填端口池）。"
  rm -f "$tmp"
}

pairing_status() {
  echo "network.env：$([[ -f "$NETWORK_ENV" ]] && echo 存在 || echo 不存在) ${NETWORK_ENV}"
  echo "network code：$([[ -f "$NETWORK_PAIRING_FILE" ]] && echo 存在 || echo 不存在) ${NETWORK_PAIRING_FILE}"
  echo "entry code：$([[ -f "$ENTRY_PAIRING_FILE" ]] && echo 存在 || echo 不存在) ${ENTRY_PAIRING_FILE}"
  echo "entries："
  list_entries
}

pairing_menu() {
  local choice
  while true; do
    print_menu_header "快速配对"
    echo "1. 在 B 运行：生成给 A 的网络码"
    echo "2. 在 A 运行：粘贴 B 的网络码，部署 A"
    echo "3. 在 B 运行：粘贴 A 的入口码，完成接入"
    echo "4. 查看 EasyTier 配对状态"
    echo "0. 返回"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) run_menu_action quick_generate_network_pairing ;;
      2) run_menu_action quick_deploy_entry_from_network_pairing ;;
      3) run_menu_action quick_deploy_relay_from_entry_pairing ;;
      4) run_menu_action pairing_status ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

add_entry() {
  need_root_unless_dry_run
  ensure_tsv_files
  local name public_host et_ip proto port weight enabled row default_ip default_port
  name="$(safe_name "$(prompt_value "入口名称（内部 ASCII，例如 public1 / public2）")")"
  entry_exists "$name" && warn "入口已存在，将覆盖。"
  public_host="$(prompt_host "入口公网 IP 或域名")"
  default_ip="$(next_entry_et_ip 2>/dev/null || printf '%s' "$ENTRY_ET_IP_DEFAULT")"
  default_port="$(next_entry_easytier_port 2>/dev/null || printf '%s' "$EASYTIER_PORT_DEFAULT")"
  while true; do
    et_ip="$(prompt_easytier_ip "入口 EasyTier IP" "$default_ip")"
    proto="$(prompt_easytier_protocols "EasyTier 传输模式" "$EASYTIER_PROTOCOLS_DEFAULT")"
    port="$(prompt_port "EasyTier 监听端口（TCP+UDP，同端口，白名单 8000-9000）" "$default_port")"
    validate_unique_entry_fields "$name" "$et_ip" "$port" "$name" && break
  done
  weight="$(prompt_value "权重" "100")"
  enabled="$(prompt_enabled_value "是否启用公网入口？" "true")"
  row="${name}"$'\t'"${public_host}"$'\t'"${et_ip}"$'\t'"${proto}"$'\t'"${port}"$'\t'"${weight}"$'\t'"${enabled}"
  confirm_summary "添加入口摘要" "name=${name}\npublic_host=${public_host}\net_ip=${et_ip}\nprotocols=${proto}\nlisten=$(easytier_protocols_display "$proto")/${port}\nport=${port}\nweight=${weight}\nenabled=${enabled}" || return 0
  replace_entry_row "$row"
  clear_pending_entry_reservation "$name" "$et_ip" "$port"
  ok "已保存公网入口：${name}"
  prompt_apply_relay_after_entry_change
}

edit_entry() {
  need_root_unless_dry_run
  ensure_tsv_files
  local name row old_name old_public_host old_et_ip old_proto old_port old_weight old_enabled
  local new_name public_host et_ip proto port weight enabled new_row
  name="$(select_entry_name)" || return 0
  row="$(entries_rows | awk -F'\t' -v n="$name" '$1==n {print; found=1} END{exit !found}')"
  [[ -n "$row" ]] || { warn "入口不存在。"; return 0; }
  IFS=$'\034' read -r old_name old_public_host old_et_ip old_proto old_port old_weight old_enabled <<<"$(awk -F'\t' 'BEGIN{OFS=sprintf("%c", 28)} {print $1,$2,$3,$4,$5,$6,$7}' <<<"$row")"
  while true; do
    new_name="$(safe_name "$(prompt_value "入口名称" "$old_name")")"
    public_host="$(prompt_host "公网 IP / 域名" "$old_public_host")"
    et_ip="$(prompt_easytier_ip "EasyTier IP" "$old_et_ip")"
    proto="$(prompt_easytier_protocols "EasyTier 传输模式" "$old_proto")"
    port="$(prompt_port "EasyTier 监听端口（TCP+UDP，同端口，白名单 8000-9000）" "$old_port")"
    weight="$(prompt_value "权重" "$old_weight")"
    enabled="$(prompt_enabled_value "是否启用公网入口 ${new_name}？" "$old_enabled")"
    [[ "$weight" =~ ^[0-9]+$ ]] || { warn "权重必须是非负整数。"; continue; }
    [[ "$enabled" == "true" || "$enabled" == "false" ]] || { warn "enabled 必须是 true 或 false。"; continue; }
    validate_unique_entry_fields "$new_name" "$et_ip" "$port" "$old_name" && break
  done
  new_row="${new_name}"$'\t'"${public_host}"$'\t'"${et_ip}"$'\t'"${proto}"$'\t'"${port}"$'\t'"${weight}"$'\t'"${enabled}"
  confirm_summary "修改公网入口摘要" "name=${new_name}\npublic_host=${public_host}\net_ip=${et_ip}\nprotocols=${proto}\nlisten=$(easytier_protocols_display "$proto")/${port}\nweight=${weight}\nenabled=${enabled}" || return 0
  replace_entry_row "$new_row" "$old_name"
  clear_pending_entry_reservation "$new_name" "$et_ip" "$port"
  ok "已修改公网入口：${old_name} -> ${new_name}"
  prompt_apply_relay_after_entry_change
}

list_entries() {
  display_entries
}

delete_entry() {
  need_root_unless_dry_run
  local name tmp
  name="$(select_entry_name)" || return 0
  prompt_yes_no "确认删除入口 ${name}？" "N" || return 0
  auto_snapshot_or_confirm "delete-entry" || return 0
  tmp="$(mktemp)"
  awk -F'\t' -v n="$name" '$1==n {next} {print}' "$ENTRIES_TSV" >"$tmp"
  write_file "$ENTRIES_TSV" "$(cat "$tmp")" 600
  rm -f "$tmp"
  ok "已删除公网入口：${name}"
  prompt_apply_relay_after_entry_change
}

set_entry_enabled() {
  need_root_unless_dry_run
  local name enabled row old_enabled public_host
  name="$(select_entry_name)" || return 0
  old_enabled="$(entries_rows | awk -F'\t' -v n="$name" '$1==n {print $7; exit}')"
  public_host="$(entries_rows | awk -F'\t' -v n="$name" '$1==n {print $2; exit}')"
  if [[ "${old_enabled:-false}" == "true" ]]; then
    if prompt_yes_no "是否禁用公网入口 ${name}？" "N"; then
      enabled="false"
    else
      info "已保持公网入口启用：${name}"
      return 0
    fi
  else
    if prompt_yes_no "是否启用公网入口 ${name}？" "Y"; then
      enabled="true"
    else
      info "已保持公网入口禁用：${name}"
      return 0
    fi
  fi
  row="$(entries_rows | awk -F'\t' -v n="$name" -v e="$enabled" 'BEGIN{OFS="\t"} $1==n {$7=e; print; found=1} END{exit !found}')"
  [[ -n "$row" ]] || { warn "入口不存在。"; return 0; }
  replace_entry_row "$row"
  if [[ "$enabled" == "true" ]]; then
    ok "已启用公网入口：${name}"
  else
    ok "已禁用公网入口：${name}"
  fi
  refresh_entry_ddns_cache_after_entry_change "$name" "$public_host" || true
  prompt_apply_relay_after_entry_change
}

set_entry_weight() {
  need_root_unless_dry_run
  local name weight row
  name="$(select_entry_name)" || return 0
  weight="$(prompt_value "新权重" "100")"
  [[ "$weight" =~ ^[0-9]+$ ]] || { warn "权重必须是非负整数。"; return 0; }
  row="$(entries_rows | awk -F'\t' -v n="$name" -v w="$weight" 'BEGIN{OFS="\t"} $1==n {$6=w; print; found=1} END{exit !found}')"
  [[ -n "$row" ]] || { warn "入口不存在。"; return 0; }
  replace_entry_row "$row"
  ok "已更新公网入口权重：${name} weight=${weight}"
  prompt_apply_relay_after_entry_change
}

switch_primary_entry() {
  need_root_unless_dry_run
  ensure_tsv_files
  local name choice max_weight new_weight content
  name="$(select_entry_name all "请选择要作为主入口的编号或名称，直接回车返回")" || return 0
  echo
  echo "${BOLD}切换模式：${RESET}"
  echo "1. 只启用 ${name}，禁用其它入口（推荐用于手动切换）"
  echo "2. 启用 ${name}，并保留其它入口 enabled（用于多入口备用 / 输出清单）"
  echo "0. 返回"
  choice="$(prompt_menu_choice "请选择：")"
  case "$choice" in
    1)
      content="$(entries_rows | awk -F'\t' -v n="$name" 'BEGIN{OFS="\t"} {$7=($1==n ? "true" : "false"); if ($1==n) $6=100; print}')"
      write_file "$ENTRIES_TSV" "$content" 600
      ok "已切换主公网入口：${name}"
      info "手动切换模式：应用 relay 后只保留 ${name} peer。"
      refresh_entry_ddns_cache_after_entries_change || true
      prompt_apply_relay_after_entry_change
      ;;
    2)
      max_weight="$(entries_rows | awk -F'\t' 'BEGIN{m=0} $6 ~ /^[0-9]+$/ && $6>m {m=$6} END{print m+0}')"
      if (( max_weight < 1000 )); then new_weight=1000; else new_weight=$((max_weight + 10)); fi
      content="$(entries_rows | awk -F'\t' -v n="$name" -v w="$new_weight" 'BEGIN{OFS="\t"} $1==n {$6=w; $7="true"} {print}')"
      write_file "$ENTRIES_TSV" "$content" 600
      ok "已切换主公网入口：${name}"
      info "主备推荐模式：应用 relay 后保留所有 enabled peer，${name} 会在输出清单中标记 PRIMARY。"
      refresh_entry_ddns_cache_after_entries_change || true
      prompt_apply_relay_after_entry_change
      ;;
    3|0|"") return 0 ;;
    *) menu_invalid_choice ;;
  esac
}

bulk_entry_enable_menu() {
  need_root_unless_dry_run
  ensure_tsv_files
  local choice name content count
  count="$(entries_rows | awk 'END{print NR+0}')"
  (( count > 0 )) || { warn "当前没有公网入口。"; return 0; }
  while true; do
    print_menu_header "批量操作"
    echo "1. 启用所有公网入口"
    echo "2. 禁用所有公网入口"
    echo "3. 只保留一个入口 enabled，其它全部 disabled"
    echo "0. 返回"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1)
        prompt_yes_no "是否启用所有公网入口？" "Y" || return 0
        content="$(entries_rows | awk -F'\t' 'BEGIN{OFS="\t"} {$7="true"; print}')"
        write_file "$ENTRIES_TSV" "$content" 600
        ok "已启用所有公网入口。"
        refresh_entry_ddns_cache_after_entries_change || true
        prompt_apply_relay_after_entry_change
        pause_after_action
        return 0
        ;;
      2)
        warn "禁用所有入口会导致 relay 没有公网入口 peer。"
        prompt_yes_no "是否禁用所有公网入口？" "N" || return 0
        auto_snapshot_or_confirm "bulk-disable-entries" || return 0
        content="$(entries_rows | awk -F'\t' 'BEGIN{OFS="\t"} {$7="false"; print}')"
        write_file "$ENTRIES_TSV" "$content" 600
        ok "已禁用所有公网入口。"
        refresh_entry_ddns_cache_after_entries_change || true
        prompt_apply_relay_after_entry_change
        pause_after_action
        return 0
        ;;
      3)
        name="$(select_entry_name all "请选择要保留 enabled 的编号或名称，直接回车返回")" || return 0
        prompt_yes_no "是否只启用公网入口 ${name}，并禁用其它公网入口？" "Y" || return 0
        auto_snapshot_or_confirm "bulk-disable-entries" || return 0
        content="$(entries_rows | awk -F'\t' -v n="$name" 'BEGIN{OFS="\t"} {$7=($1==n ? "true" : "false"); print}')"
        write_file "$ENTRIES_TSV" "$content" 600
        ok "已只保留公网入口 enabled：${name}"
        refresh_entry_ddns_cache_after_entries_change || true
        prompt_apply_relay_after_entry_change
        pause_after_action
        return 0
        ;;
      4|0|"") return 0 ;;
      *) menu_invalid_choice ;;
    esac
  done
}

select_pending_entry() {
  local count choice row
  count="$(pending_entries_count)"
  (( count > 0 )) || { warn "当前没有未完成接入码。" >&2; return 1; }
  echo >&2
  echo "未完成接入码：" >&2
  display_pending_entries >&2
  echo >&2
  choice="$(prompt_menu_choice "请输入编号、名称或 EasyTier IP，直接回车返回:")"
  choice="$(normalize_menu_choice "$choice")"
  [[ -n "$choice" ]] || return 1
  if [[ "$choice" =~ ^[0-9]+$ ]]; then
    row="$(pending_entries_rows | awk -v n="$choice" 'NR==n {print; found=1} END{exit !found}')"
    [[ -n "$row" ]] || { warn "编号无效，请重新选择。" >&2; return 1; }
  else
    row="$(pending_entries_rows | awk -F'\t' -v q="$choice" '$1==q || $2==q {print; found=1; exit} END{exit !found}')"
    [[ -n "$row" ]] || { warn "未完成接入码不存在：${choice}" >&2; return 1; }
  fi
  printf '%s\n' "$row"
}

pending_entries_menu() {
  need_root_unless_dry_run
  ensure_base_dirs
  local choice row name et_ip proto port created_at count
  while true; do
    print_menu_header "未完成接入码"
    if (( $(pending_entries_count) > 0 )); then
      display_pending_entries
    else
      warn "当前没有未完成接入码。"
    fi
    echo
    echo "1. 清理指定未完成接入码"
    echo "2. 清理所有未完成接入码"
    echo "0. 返回"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1)
        if row="$(select_pending_entry)"; then
          IFS=$'\t' read -r name et_ip proto port created_at <<<"$row"
          if prompt_yes_no "确认清理未完成接入码预占 ${name} / ${et_ip} / ${port}？" "N"; then
            clear_pending_entry_exact "$name" "$et_ip" "$port"
            ok "已清理未完成接入码预占：${name} / ${et_ip} / ${port}"
          fi
          pause_after_action
        fi
        ;;
      2)
        count="$(pending_entries_count)"
        (( count > 0 )) || { warn "当前没有未完成接入码可清理。"; continue; }
        if prompt_yes_no "确认清理所有未完成接入码预占？" "N"; then
          rm -f "$PENDING_ENTRIES_TSV"
          ok "已清理所有未完成接入码预占。"
        fi
        pause_after_action
        ;;
      0|"") return 0 ;;
      *) menu_invalid_choice ;;
    esac
  done
}

entry_peer_text_matches() {
  local peer_text="$1" name="$2" public_host="$3" et_ip="$4" proto="$5" port="$6" peer_url
  grep -Fq "$et_ip" <<<"$peer_text" && return 0
  grep -Fq "$public_host" <<<"$peer_text" && return 0
  while IFS= read -r peer_url; do
    [[ -n "$peer_url" ]] || continue
    grep -Fq "$peer_url" <<<"$peer_text" && return 0
  done < <(easytier_urls "$public_host" "$proto" "$port")
  grep -Fq "$name" <<<"$peer_text" && return 0
  return 1
}

wait_entry_peer_visible() {
  local name="$1" public_host="$2" et_ip="$3" proto="$4" port="$5" attempts="${6:-8}" interval="${7:-1}"
  local i peer_text
  for i in $(seq 1 "$attempts"); do
    peer_text="$(easytier_cli_peer_text)"
    if entry_peer_text_matches "$peer_text" "$name" "$public_host" "$et_ip" "$proto" "$port"; then
      return 0
    fi
    sleep "$interval"
  done
  return 1
}

emit_entry_peer_targets() {
  local name="$1" public_host="$2" proto="$3" port="$4" mode="${5:-plain}" peer_url
  emit_status "$mode" INFO "入口 ${name} peer 目标："
  while IFS= read -r peer_url; do
    [[ -n "$peer_url" ]] && emit_status "$mode" INFO "  * ${peer_url}"
  done < <(easytier_urls "$public_host" "$proto" "$port")
}

check_entry_peer_connectivity() {
  local name="$1" public_host="$2" et_ip="$3" proto="$4" port="$5" mode="${6:-plain}"
  if wait_entry_peer_visible "$name" "$public_host" "$et_ip" "$proto" "$port"; then
    emit_status "$mode" OK "入口 ${name} peer 可见：${et_ip}"
    ping_entry_et_ip "$name" "$et_ip" "$mode" || true
    return 0
  fi
  if ping_entry_et_ip "$name" "$et_ip" "$mode"; then
    emit_status "$mode" INFO "easytier-cli peer 列表暂未显示 ${name}，但 EasyTier IP ping 成功，视为已连通。"
    return 0
  fi
  emit_status "$mode" WARN "入口 ${name} peer 未确认，且 EasyTier IP ping 失败。"
  return 1
}

test_entry_row() {
  local name="$1" public_host="$2" et_ip="$3" proto="$4" port="$5" enabled="$6" ping_mode="${7:-yes}"
  echo
  echo "入口：${name}"
  [[ "$enabled" == "true" ]] || warn "该公网入口当前 disabled，仅执行连通性测试。"
  if easytier_protocols_has "$proto" tcp; then
    case "$(tcp_reachable_status "$public_host" "$port")" in
      0) ok "入口 ${name} TCP 可达：${public_host}:${port}" ;;
      2) warn "未找到 nc，无法测试入口 ${name} TCP；请安装 netcat-openbsd" ;;
      *) warn "入口 ${name} TCP 不可达：${public_host}:${port}" ;;
    esac
  fi
  if easytier_protocols_has "$proto" udp; then
    case "$(udp_probe_status "$public_host" "$port")" in
      0) ok "入口 ${name} UDP 探测完成：${public_host}:${port}" ;;
      2) warn "未找到 nc，无法测试入口 ${name} UDP；请安装 netcat-openbsd" ;;
      *) warn "入口 ${name} UDP 探测未确认。UDP 无连接探测可能不可靠，请结合 EasyTier peer / ping 判断。" ;;
    esac
  fi
  [[ "$ping_mode" == "yes" ]] && ping_entry_et_ip "$name" "$et_ip" plain || true
}

test_entries() {
  local name public_host et_ip proto port _weight enabled
  name="$(select_entry_name)" || return 0
  while IFS=$'\t' read -r name public_host et_ip proto port _weight enabled; do
    test_entry_row "$name" "$public_host" "$et_ip" "$proto" "$port" "$enabled"
    return 0
  done < <(entries_rows | awk -F'\t' -v n="$name" '$1==n')
}

entry_connectivity_ready_once() {
  local name="$1" public_host="$2" et_ip="$3" proto="$4" port="$5"
  local peer_ok=1 ping_ok=1 tcp_ok=0
  wait_entry_peer_visible "$name" "$public_host" "$et_ip" "$proto" "$port" 1 0 && peer_ok=0
  ping -c 1 -W 2 "$et_ip" >/dev/null 2>&1 && ping_ok=0
  if easytier_protocols_has "$proto" tcp; then
    [[ "$(tcp_reachable_status "$public_host" "$port")" == "0" ]] || tcp_ok=1
  fi
  (( ping_ok == 0 && tcp_ok == 0 )) && return 0
  (( peer_ok == 0 && ping_ok == 0 )) && return 0
  return 1
}

test_enabled_entry_with_retry() {
  local name="$1" public_host="$2" et_ip="$3" proto="$4" port="$5" enabled="$6" attempts="${7:-10}" interval="${8:-3}"
  local i
  echo
  emit_entry_peer_targets "$name" "$public_host" "$proto" "$port" plain
  for ((i=1; i<=attempts; i++)); do
    info "等待入口 ${name} 连通：第 ${i}/${attempts} 次..."
    if entry_connectivity_ready_once "$name" "$public_host" "$et_ip" "$proto" "$port"; then
      ok "入口 ${name} 已连通。"
      check_entry_peer_connectivity "$name" "$public_host" "$et_ip" "$proto" "$port" plain || true
      test_entry_row "$name" "$public_host" "$et_ip" "$proto" "$port" "$enabled" no
      return 0
    fi
    (( i < attempts )) && sleep "$interval"
  done
  check_entry_peer_connectivity "$name" "$public_host" "$et_ip" "$proto" "$port" plain || true
  test_entry_row "$name" "$public_host" "$et_ip" "$proto" "$port" "$enabled" no
}

test_all_enabled_entries() {
  local attempts="${1:-10}" interval="${2:-3}"
  local name public_host et_ip proto port _weight enabled tested=0
  ensure_nc_for_test || true
  while IFS=$'\t' read -r name public_host et_ip proto port _weight enabled; do
    [[ "$enabled" == "true" ]] || continue
    tested=1
    test_enabled_entry_with_retry "$name" "$public_host" "$et_ip" "$proto" "$port" "$enabled" "$attempts" "$interval"
  done < <(entries_rows)
  (( tested == 1 )) || warn "没有 enabled 公网入口可测试。"
}

enabled_entries_count() {
  entries_rows | awk -F'\t' '$7=="true"{c++} END{print c+0}'
}

apply_easytier_entry_services() {
  need_root_unless_dry_run
  if machine_looks_like_relay; then
    warn "当前机器看起来是 B 利群主机，不应该启动 entry 服务。"
    warn "如需重启 B，请选择：启动 / 重启 relay 服务。"
    prompt_yes_no "是否仍然继续？" "N" || return 0
  fi
  install_easytier_binary
  local name public_host et_ip proto port weight enabled service
  while IFS=$'\t' read -r name public_host et_ip proto port weight enabled; do
    [[ "$enabled" == "true" ]] || continue
    service="$(render_entry_service "$name" "$et_ip" "$proto" "$port")" || return 1
    write_file "$(entry_service_path "$name")" "$service" 644
    start_service_file "$(entry_service_name "$name")"
    ok "EasyTier entry 已配置：${name} ${et_ip} $(easytier_protocols_display "$proto")/${port} weight=${weight}"
  done < <(entries_rows)
}

apply_easytier_relay_service() {
  need_root_unless_dry_run
  local confirm_mode="${1:-ask}" service enabled_count skip_snapshot=0
  if [[ "$confirm_mode" == "confirmed-no-snapshot" ]]; then
    confirm_mode="confirmed"
    skip_snapshot=1
  fi
  if machine_looks_like_entry; then
    warn "当前机器看起来是 A 公网入口，不应该启动 relay 服务。"
    warn "如需重启 A，请选择：启动 / 重启 entry 服务。"
    [[ "$confirm_mode" == "confirmed" ]] && return 1
    prompt_yes_no "是否仍然继续？" "N" || return 0
  fi
  enabled_count="$(enabled_entries_count)"
  if [[ "$confirm_mode" != "confirmed" ]] && (( enabled_count > 0 )); then
    warn "重启 EasyTier relay 会短暂中断所有已接入公网入口。"
    if ! prompt_yes_no "是否继续？" "N"; then
      info "已取消重启 EasyTier relay。"
      return 0
    fi
  fi
  if (( skip_snapshot == 0 )); then
    auto_snapshot_or_confirm "restart-relay" || return 0
  fi
  install_easytier_binary
  service="$(render_relay_service)" || return 1
  write_file "$EASYTIER_RELAY_SERVICE" "$service" 644
  start_service_file "$EASYTIER_RELAY_SERVICE_NAME"
  ok "EasyTier relay 已配置。"
  wait_systemd_active "$EASYTIER_RELAY_SERVICE_NAME" 15 || warn "15 秒内 easytier-relay.service 未进入 active 状态。"
  wait_et_ip "$RELAY_ET_IP" 15 || warn "15 秒内未检测到 Relay EasyTier IP：${RELAY_ET_IP}"
  test_all_enabled_entries
}

prompt_apply_relay_after_entry_change() {
  info "已更新公网入口配置，但尚未应用到 EasyTier relay。"
  warn "应用公网入口变更需要重启 EasyTier relay，现有入口会短暂中断。"
  if prompt_yes_no "是否现在重启 relay？" "N"; then
    apply_easytier_relay_service confirmed
  else
    info "请在维护窗口执行：利群主机 -> EasyTier 组网管理 -> 启动 / 重启 relay 服务"
  fi
}

refresh_entry_ddns_cache_after_entry_change() {
  local name="$1" public_host="$2" result="ok"
  [[ -n "$public_host" ]] || return 0
  is_domain_name "$public_host" || return 0
  info "检测到公网入口使用域名，正在刷新解析缓存..."
  DDNS_FORWARD_CHANGED=""; DDNS_FORWARD_FAILED=""
  DDNS_ENTRY_CHANGED=""; DDNS_ENTRY_FAILED=""
  DDNS_PBR_CHANGED=""; DDNS_PBR_FAILED=""
  DDNS_RELAY_RESTART_NEEDED=false
  DDNS_NFT_APPLIED=false; DDNS_PBR_APPLIED=false; DDNS_RELAY_RESTARTED=false
  DDNS_ENTRY_REPORT_BLOCKS=""
  DDNS_ENTRY_RECENT_EVENTS=""
  DDNS_ENTRY_RECENT_ACTION=""
  DDNS_FORWARD_RECENT_EVENTS=""
  DDNS_FORWARD_RECENT_ACTION=""
  DDNS_PBR_RECENT_EVENTS=""
  DDNS_PBR_RECENT_ACTION=""
  DDNS_ENTRY_CHECKED=0; DDNS_ENTRY_DOMAIN_COUNT=0; DDNS_ENTRY_CHANGED_COUNT=0; DDNS_ENTRY_FAILED_COUNT=0
  DDNS_DNS_SPLIT_DETECTED=false
  DDNS_DNS_INCOMPLETE_DETECTED=false
  DDNS_DNS_DIG_WARNED=false
  DDNS_DNS_SPLIT_DOMAIN=""
  DDNS_DNS_SPLIT_RESULTS=""
  DDNS_DNS_SPLIT_SELECTED_IP=""
  DDNS_DNS_SPLIT_SELECTED_SOURCE=""
  dnsutils_auto_install "entry-refresh" "false" "plain" || true
  if ! ddns_ensure_config || ! ddns_refresh_entries_scope; then
    warn "公网入口 ${name} 解析缓存刷新失败，请稍后执行：lq ddns run --scope entries"
    result="warn"
  fi
  if [[ -n "$DDNS_ENTRY_RECENT_EVENTS" ]]; then
    DDNS_ENTRY_RECENT_ACTION="已写入缓存"
  fi
  ddns_write_last_status "$result" "entries" "" "" "$DDNS_ENTRY_CHANGED" "$DDNS_ENTRY_FAILED" "" "" false false false false
  return 0
}

refresh_entry_ddns_cache_after_entries_change() {
  local has_domain
  has_domain="$(entries_rows | awk -F'\t' '$7=="true" && $2 !~ /^([0-9]{1,3}\.){3}[0-9]{1,3}$/ && $2 ~ /[A-Za-z]/ {print $1; exit}')"
  [[ -n "$has_domain" ]] || return 0
  refresh_entry_ddns_cache_after_entry_change "$has_domain" "$(entries_rows | awk -F'\t' -v n="$has_domain" '$1==n {print $2; exit}')"
}

reserved_entry_port() {
  case "$1" in
    22|80|443|8301|11010) return 0 ;;
    *) return 1 ;;
  esac
}

route_table_name_from_id() {
  local table="$1"
  [[ -n "$table" ]] || return 1
  if [[ "$table" =~ ^[0-9]+$ && -f "$PBR_RT_TABLES" ]]; then
    awk -v id="$table" '$1==id {print $2; found=1; exit} END{exit !found}' "$PBR_RT_TABLES" 2>/dev/null || printf '%s' "$table"
  else
    printf '%s' "$table"
  fi
}

route_table_display() {
  local table="$1"
  case "$table" in
    ""|main|254) printf '%s' "-" ;;
    *) printf '%s' "$table" ;;
  esac
}

route_table_same() {
  local configured="$1" actual="$2"
  configured="$(normalize_menu_choice "$configured")"
  actual="$(normalize_menu_choice "$actual")"
  [[ "$configured" == "-" ]] && configured=""
  [[ "$actual" == "-" ]] && actual=""
  [[ "$configured" == "254" ]] && configured="main"
  [[ "$actual" == "254" ]] && actual="main"
  [[ -z "$configured" && ( -z "$actual" || "$actual" == "main" ) ]] && return 0
  [[ "$configured" == "$actual" ]]
}

detect_target_route() {
  local host="$1" preferred_table="${2:-}" target_ip route_line dev table src via
  target_ip="$(resolve_ipv4_first "$host" 2>/dev/null || true)"
  [[ -n "$target_ip" ]] || target_ip="$host"
  if [[ -n "$preferred_table" && "$preferred_table" != "-" && "$preferred_table" != "main" ]]; then
    route_line="$(ip route get "$target_ip" table "$preferred_table" 2>/dev/null | head -n 1 || true)"
  else
    route_line=""
  fi
  [[ -n "$route_line" ]] || route_line="$(ip route get "$target_ip" 2>/dev/null | head -n 1 || true)"
  [[ -n "$route_line" ]] || return 1
  dev="$(awk '{for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1); exit}}' <<<"$route_line")"
  table="$(awk '{for (i=1; i<=NF; i++) if ($i=="table") {print $(i+1); exit}}' <<<"$route_line")"
  table="$(route_table_name_from_id "$table" 2>/dev/null || true)"
  src="$(awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}' <<<"$route_line")"
  via="$(awk '{for (i=1; i<=NF; i++) if ($i=="via") {print $(i+1); exit}}' <<<"$route_line")"
  printf '%s\034%s\034%s\034%s\034%s\034%s\n' "$target_ip" "$dev" "$table" "$src" "$via" "$route_line"
}

detect_forward_route_defaults() {
  local host="$1" route_info target_ip dev table _src _via _line
  route_info="$(detect_target_route "$host" 2>/dev/null || true)"
  IFS=$'\034' read -r target_ip dev table _src _via _line <<<"$route_info"
  printf '%s\t%s\n' "$dev" "$table"
}

prompt_forward_route_choice() {
  local target_host="$1" current_iface="${2:-}" current_table="${3:-}" route_info target_ip actual_dev actual_table actual_src actual_via route_line
  route_info="$(detect_target_route "$target_host" "$current_table" 2>/dev/null || true)"
  IFS=$'\034' read -r target_ip actual_dev actual_table actual_src actual_via route_line <<<"$route_info"
  if [[ -n "$actual_dev" ]]; then
    echo >&2
    echo "检测到后端目标 ${target_host} 的实际出口：" >&2
    echo "- 目标 IPv4：${target_ip}" >&2
    echo "- 路由表：$(route_table_display "$actual_table")" >&2
    echo "- 出口接口：${actual_dev}" >&2
    echo "- 源地址：${actual_src:-未知}" >&2
    [[ -n "$actual_via" ]] && echo "- 网关：${actual_via}" >&2
    if route_table_same "" "$actual_table"; then
      echo "[INFO] 已检测到实际出口 ${actual_dev}。如你希望固定走 CN2 / 9929，请先配置 PBR，再重新应用转发规则。" >&2
    fi
    if prompt_yes_no "是否使用该出口配置？" "Y"; then
      printf '%s\t%s\n' "$actual_dev" "$actual_table"
      return 0
    fi
  else
    printf '[WARN] 无法通过 ip route get 自动识别 %s 的出口，将进入高级手动输入。\n' "$target_host" >&2
  fi
  local manual_iface manual_table
  manual_iface="$(prompt_value "出口接口 out_iface" "$current_iface")"
  manual_table="$(prompt_value "出口路由表 route_table，留空表示 main/自动" "$current_table")"
  if [[ -n "$manual_table" && "$manual_table" != "-" ]]; then
    route_info="$(detect_target_route "$target_host" "$manual_table" 2>/dev/null || true)"
    IFS=$'\034' read -r _target_ip actual_dev actual_table _actual_src _actual_via _route_line <<<"$route_info"
    if [[ -n "$actual_dev" && "$actual_dev" != "$manual_iface" ]]; then
      printf '[WARN] 路由表 %s 下实际出口接口是 %s，将自动同步 out_iface。\n' "$manual_table" "$actual_dev" >&2
      manual_iface="$actual_dev"
      manual_table="$actual_table"
    fi
  fi
  printf '%s\t%s\n' "$manual_iface" "$manual_table"
}

forward_route_mismatch_text() {
  local name="$1" target_host="$2" configured_iface="$3" configured_table="$4" actual_dev="$5" actual_table="$6"
  if [[ -n "$configured_iface" && "$configured_iface" != "$actual_dev" ]]; then
    cat <<EOF
转发目标 ${name} 出口配置可能错误：
配置 out_iface=${configured_iface:-"-"} route_table=$(route_table_display "$configured_table")
实际路由 dev=${actual_dev:-"-"} table=$(route_table_display "$actual_table")
nftables 规则依赖 oifname=${configured_iface}，实际出口是 ${actual_dev}，这可能导致 A 入口端口可以到 B，但无法转发到后端。
EOF
  else
    cat <<EOF
转发目标 ${name} 路由表元数据可同步：
配置 out_iface=${configured_iface:-"-"} route_table=$(route_table_display "$configured_table")
实际路由 dev=${actual_dev:-"-"} table=$(route_table_display "$actual_table")
出口接口一致；这通常不会单独导致转发失败，但建议同步 route_table 元数据，方便后续诊断和自动修正。
EOF
  fi
}

report_forward_route_consistency() {
  local name="$1" target_host="$2" configured_iface="$3" configured_table="$4"
  local route_info target_ip actual_dev actual_table actual_src actual_via route_line
  route_info="$(detect_target_route "$target_host" 2>/dev/null || true)"
  IFS=$'\034' read -r target_ip actual_dev actual_table actual_src actual_via route_line <<<"$route_info"
  if [[ -z "$actual_dev" ]]; then
    report WARN "转发目标 ${name} 出口无法识别：${target_host}"
    return 0
  fi
  if [[ -n "$configured_iface" && "$configured_iface" != "$actual_dev" ]]; then
    report WARN "转发目标 ${name} 出口接口不一致：配置 ${configured_iface}/$(route_table_display "$configured_table")，实际 ${actual_dev}/$(route_table_display "$actual_table")，可能导致 nft oifname 不匹配。"
  elif ! route_table_same "$configured_table" "$actual_table"; then
    if [[ -n "$configured_table" && "$configured_table" != "-" && -z "$actual_table" ]]; then
      report INFO "转发目标 ${name} route_table 元数据保留为 $(route_table_display "$configured_table")；实际路由暂时未返回表名，可能是 PBR 未正确应用或域名解析分歧导致。"
    else
      report INFO "转发目标 ${name} 出口接口一致但 route_table 元数据不同：配置 $(route_table_display "$configured_table")，实际 $(route_table_display "$actual_table")。可用 auto-fix-route 同步。"
    fi
  else
    report OK "转发目标 ${name} 出口一致：${actual_dev} / $(route_table_display "$actual_table")"
  fi
}

sync_forward_routes_if_needed() {
  local auto_fix="${1:-0}" row name entry_port target_host target_port out_iface route_table enabled comment
  local route_info target_ip actual_dev actual_table actual_src actual_via route_line mismatch fixed=0 tmp content
  validate_forwards_tsv || return 1
  content=$'# name\tentry_port\ttarget_host\ttarget_port\tout_iface\troute_table\tenabled\tcomment'
  while IFS=$'\034' read -r name entry_port target_host target_port out_iface route_table enabled comment; do
    mismatch=0
    if [[ "$enabled" == "true" ]]; then
      route_info="$(detect_target_route "$target_host" 2>/dev/null || true)"
      IFS=$'\034' read -r target_ip actual_dev actual_table actual_src actual_via route_line <<<"$route_info"
      if [[ -n "$actual_dev" ]]; then
        [[ -n "$out_iface" && "$out_iface" == "$actual_dev" ]] || mismatch=1
        if [[ -n "$route_table" && "$route_table" != "-" && -z "$actual_table" ]]; then
          info "转发目标 ${name} route_table 保留为 $(route_table_display "$route_table")；实际路由暂时未返回表名，可能是 PBR 未正确应用或域名解析分歧导致。"
        else
          route_table_same "$route_table" "$actual_table" || mismatch=1
        fi
        if (( mismatch == 1 )); then
          if [[ -n "$out_iface" && "$out_iface" != "$actual_dev" ]]; then
            warn "$(forward_route_mismatch_text "$name" "$target_host" "$out_iface" "$route_table" "$actual_dev" "$actual_table")"
          else
            info "$(forward_route_mismatch_text "$name" "$target_host" "$out_iface" "$route_table" "$actual_dev" "$actual_table")"
          fi
          if (( auto_fix == 1 )) || { is_interactive && prompt_yes_no "是否自动修正为 out_iface=${actual_dev} route_table=$(route_table_display "$actual_table")？" "Y"; }; then
            out_iface="$actual_dev"
            if [[ -n "$route_table" && "$route_table" != "-" && -z "$actual_table" ]]; then
              info "保留 ${name} 的 route_table=$(route_table_display "$route_table")，不自动改为空。"
            else
              route_table="$actual_table"
            fi
            fixed=1
          else
            warn "未自动修正 ${name}。可执行：lq forward edit ${name}，或 lq forward apply-relay --auto-fix-route"
          fi
        else
          ok "转发目标 ${name} 出口一致：${actual_dev} / $(route_table_display "$actual_table")"
        fi
      else
        warn "无法识别转发目标 ${name} 的实际出口：${target_host}"
      fi
    fi
    row="${name}"$'\t'"${entry_port}"$'\t'"${target_host}"$'\t'"${target_port}"$'\t'"${out_iface}"$'\t'"${route_table}"$'\t'"${enabled}"$'\t'"${comment}"
    content="${content}"$'\n'"${row}"
  done < <(forwards_rows_usv)
  if (( fixed == 1 )); then
    tmp="$(make_state_tmp "$FORWARDS_DIR" "forwards")" || return 1
    printf '%s\n' "$content" >"$tmp"
    write_file "$FORWARDS_TSV" "$(cat "$tmp")" 600
    rm -f "$tmp"
    ok "已自动修正 forwards.tsv 中的出口配置。"
  fi
}

forward_code_path() {
  local name="$1"
  printf '%s/forward-%s.env' "$OUTPUT_DIR" "$name"
}

write_forward_code_file() {
  local file="$1" name="$2" entry_port="$3" target_host="$4" target_port="$5" enabled="$6" comment="$7"
  write_file "$file" "FORWARD_VERSION=0.4
NAME=${name}
ENTRY_PORT=${entry_port}
TARGET_HOST=${target_host}
TARGET_PORT=${target_port}
ENABLED=${enabled}
COMMENT=${comment}" 600
}

print_forward_code() {
  local file="$1"
  echo
  echo "=================================================="
  echo "【复制下面整段到 A 公网入口机】"
  echo "-----BEGIN LEIKWAN FORWARD-----"
  cat "$file"
  echo "-----END LEIKWAN FORWARD-----"
  echo "=================================================="
  echo
  echo "【一行转发码，复制这一行也可以】"
  printf 'LEIKWAN_FORWARD_BASE64=%s\n' "$(pairing_base64 "$file")"
}

parse_forward_raw() {
  local raw="$1" dest="$2" line payload
  : >"$dest"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(normalize_menu_choice "$line")"
    [[ -n "$line" ]] || continue
    case "$line" in
      "-----BEGIN LEIKWAN FORWARD-----"|"-----END LEIKWAN FORWARD-----") continue ;;
    esac
    if [[ "$line" == LEIKWAN_FORWARD_BASE64=* ]]; then
      payload="${line#*=}"
      decode_env_base64 "$payload" "$dest" "FORWARD_VERSION" || { fail "一行转发码解码失败，请重新复制完整内容。"; return 1; }
      return 0
    fi
    if [[ "$line" =~ ^[A-Za-z0-9+/]+={0,2}$ ]] && ((${#line} >= 30)); then
      if decode_env_base64 "$line" "$dest" "FORWARD_VERSION"; then
        return 0
      fi
    fi
    if [[ "$line" == *=* ]]; then
      printf '%s\n' "$line" >>"$dest"
    fi
  done <"$raw"
  [[ -s "$dest" ]] || { fail "没有读到有效 FORWARD 转发码。"; return 1; }
}

read_forward_code() {
  local dest="$1" source="${2:-}" raw line has_content=0
  raw="$(mktemp)"
  if [[ -n "$source" ]]; then
    if [[ "$source" == "-" ]]; then
      cat >"$raw"
    elif [[ -f "$source" ]]; then
      cp -a "$source" "$raw"
    else
      printf '%s\n' "$source" >"$raw"
    fi
  else
    echo "请粘贴从 B 利群主机复制的整段 FORWARD 转发码。"
    echo "看到 END 行会自动继续；如果只粘贴 KEY=VALUE 内容，请用空行结束。"
    while IFS= read -r line; do
      line="$(normalize_menu_choice "$line")"
      if [[ -z "$line" ]]; then
        (( has_content == 1 )) && break
        continue
      fi
      has_content=1
      printf '%s\n' "$line" >>"$raw"
      [[ "$line" == "-----END LEIKWAN FORWARD-----" || "$line" == LEIKWAN_FORWARD_BASE64=* ]] && break
      [[ "$line" =~ ^[A-Za-z0-9+/]+={0,2}$ ]] && ((${#line} >= 30)) && break
    done
  fi
  parse_forward_raw "$raw" "$dest"
  rm -f "$raw"
}

export_forward_code_by_name() {
  local name="${1:-}" row entry_port target_host target_port out_iface route_table enabled comment file
  ensure_tsv_files
  if [[ -z "$name" ]]; then
    name="$(forwards_rows | awk -F'\t' 'NR==1{print $1}')"
  fi
  [[ -n "$name" ]] || { warn "当前没有转发目标。"; return 0; }
  row="$(forwards_rows | awk -F'\t' -v n="$name" '$1==n {print; found=1} END{exit !found}')"
  [[ -n "$row" ]] || { warn "转发不存在：${name}"; return 0; }
  IFS=$'\034' read -r name entry_port target_host target_port out_iface route_table enabled comment <<<"$(awk -F'\t' 'BEGIN{OFS=sprintf("%c", 28)} {print $1,$2,$3,$4,$5,$6,$7,$8}' <<<"$row")"
  file="$(forward_code_path "$name")"
  write_forward_code_file "$file" "$name" "$entry_port" "$target_host" "$target_port" "$enabled" "$comment"
  print_forward_code "$file"
}

forward_bundle_code_path() {
  printf '%s/forward-bundle.env' "$OUTPUT_DIR"
}

build_forward_bundle_rules_tsv() {
  local filter="${1:-}"
  forwards_rows | awk -F'\t' -v f="$filter" '
    BEGIN { n=split(f, a, " "); for (i=1;i<=n;i++) if (a[i]!="") sel[a[i]]=1 }
    $7=="true" {
      if (f!="" && !($1 in sel)) next
      printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4, $7, $8
    }'
}

export_forward_bundle_code() {
  need_root_unless_dry_run
  ensure_tsv_files
  local relay_ip rules count file b64 names
  relay_ip="$(current_relay_et_ip)"
  is_ipv4 "$relay_ip" || { fail "无法确定 Relay EasyTier IP：${relay_ip}"; return 1; }
  if ! forwards_rows | awk -F'\t' '$7=="true"{f=1} END{exit !f}'; then
    warn "当前没有启用的转发目标，无法生成接入码。请先在「转发目标管理」添加。"
    return 0
  fi
  display_forwards
  if prompt_yes_no "是否只选择部分转发生成接入码？（默认导出全部已启用）" "N"; then
    names="$(prompt_value "输入要包含的转发名称（空格分隔）")"
    rules="$(build_forward_bundle_rules_tsv "$names")"
  else
    rules="$(build_forward_bundle_rules_tsv "")"
  fi
  count="$(printf '%s\n' "$rules" | grep -c . || true)"
  (( count > 0 )) || { warn "没有匹配的启用转发，未生成接入码。"; return 0; }
  b64="$(printf '%s\n' "$rules" | base64 | tr -d '\n')"
  file="$(forward_bundle_code_path)"
  write_file "$file" "FORWARD_BUNDLE_VERSION=0.5
RELAY_ET_IP=${relay_ip}
RULE_COUNT=${count}
RULES_B64=${b64}" 600
  show_pairing_code_and_confirm "公网入口转发接入码（聚合 ${count} 条）" "-----BEGIN LEIKWAN FORWARD BUNDLE-----" "-----END LEIKWAN FORWARD BUNDLE-----" "$file" "LEIKWAN_FORWARD_BUNDLE_BASE64" "在 A 公网入口机选择「粘贴转发接入码并应用」。"
}

parse_forward_bundle_raw() {
  local raw="$1" dest="$2" line payload
  : >"$dest"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(normalize_menu_choice "$line")"
    [[ -n "$line" ]] || continue
    case "$line" in
      "-----BEGIN LEIKWAN FORWARD BUNDLE-----"|"-----END LEIKWAN FORWARD BUNDLE-----") continue ;;
    esac
    if [[ "$line" == LEIKWAN_FORWARD_BUNDLE_BASE64=* ]]; then
      payload="${line#*=}"
      decode_env_base64 "$payload" "$dest" "FORWARD_BUNDLE_VERSION" || { fail "一行接入码解码失败，请重新复制完整内容。"; return 1; }
      return 0
    fi
    if [[ "$line" =~ ^[A-Za-z0-9+/]+={0,2}$ ]] && ((${#line} >= 30)); then
      if decode_env_base64 "$line" "$dest" "FORWARD_BUNDLE_VERSION"; then
        return 0
      fi
    fi
    if [[ "$line" == *=* ]]; then
      printf '%s\n' "$line" >>"$dest"
    fi
  done <"$raw"
  [[ -s "$dest" ]] || { fail "没有读到有效 BUNDLE 接入码。"; return 1; }
}

import_forward_bundle_apply() {
  need_root_unless_dry_run
  local raw="$1" tmp relay_ip rules_b64 rules public_host
  local body name entry_port target_host target_port enabled comment n=0 summary=""
  tmp="$(mktemp)"
  parse_forward_bundle_raw "$raw" "$tmp" || { rm -f "$tmp"; return 1; }
  require_env_fields "$tmp" FORWARD_BUNDLE_VERSION RELAY_ET_IP RULES_B64 || { rm -f "$tmp"; return 1; }
  [[ "$(env_file_get "$tmp" FORWARD_BUNDLE_VERSION)" == "0.5" ]] || { fail "FORWARD_BUNDLE_VERSION 不支持。"; rm -f "$tmp"; return 1; }
  relay_ip="$(env_file_get "$tmp" RELAY_ET_IP)"
  rules_b64="$(env_file_get "$tmp" RULES_B64)"
  rm -f "$tmp"
  is_ipv4 "$relay_ip" || { fail "接入码 RELAY_ET_IP 非法：${relay_ip}"; return 1; }
  rules="$(printf '%s' "$rules_b64" | base64 -d 2>/dev/null)" || { fail "RULES_B64 解码失败，请重新复制接入码。"; return 1; }
  [[ -n "$rules" ]] || { fail "接入码不含转发规则。"; return 1; }
  body="$(printf '# name\tentry_port\ttarget_host\ttarget_port\tout_iface\troute_table\tenabled\tcomment')"
  while IFS=$'\t' read -r name entry_port target_host target_port enabled comment || [[ -n "$name" ]]; do
    [[ -n "$name" ]] || continue
    name="$(safe_name "$name")"
    is_port "$entry_port" || { fail "接入码含非法 entry_port：${entry_port}"; return 1; }
    is_port "$target_port" || { fail "接入码含非法 target_port：${target_port}"; return 1; }
    [[ "$enabled" == "true" || "$enabled" == "false" ]] || enabled="true"
    body="${body}"$'\n'"${name}"$'\t'"${entry_port}"$'\t'"${target_host}"$'\t'"${target_port}"$'\t\t\t'"${enabled}"$'\t'"${comment}"
    n=$((n + 1))
    [[ "$enabled" == "true" ]] && summary="${summary}  ${name}: 端口 ${entry_port} → relay ${relay_ip}:${entry_port}（后端 ${target_host}:${target_port}）"$'\n'
  done <<<"$rules"
  (( n > 0 )) || { fail "接入码不含有效转发规则。"; return 1; }
  confirm_summary "导入公网入口转发接入码" "Relay EasyTier IP=${relay_ip}\n规则数=${n}\n${summary}动作：用接入码规则【替换】本机转发表，并按端口逐条 DNAT 到 Relay（无需再配端口池）。" || return 0
  ensure_tsv_files
  write_file "$FORWARDS_TSV" "$body" 600
  write_file "$ENTRY_EXPOSE_ENV" "ENTRY_MODE=bundle
RELAY_ET_IP=${relay_ip}
ENABLED=true" 600
  apply_nft_rules "cloud-entry" || return 1
  public_host="$(current_entry_public_host)"
  echo
  echo "公网入口已应用 ${n} 条转发："
  while IFS=$'\t' read -r name entry_port target_host target_port _oi _rt enabled comment || [[ -n "$name" ]]; do
    [[ -n "$name" && "$name" != \#* ]] || continue
    [[ "$enabled" == "true" ]] || continue
    echo "  ${public_host}:${entry_port} → relay ${relay_ip}:${entry_port} → ${target_host}:${target_port}"
  done <<<"$body"
}

add_forward() {
  need_root_unless_dry_run
  install_packages iproute2 netcat-openbsd
  ensure_tsv_files
  local name entry_port target_host target_port out_iface route_table enabled comment row target_ip route_defaults existing_name existing_port tcp_rc
  name="$(safe_name "$(prompt_value "转发名称" "service-a")")"
  entry_port="$(prompt_forward_entry_port "$name")" || return 0
  if reserved_entry_port "$entry_port"; then
    warn "该端口属于保留/常用端口：${entry_port}"
    prompt_yes_no "确定强制使用？" "N" || return 0
  fi
  warn_if_forward_port_outside_expose "$entry_port"
  target_host="$(prompt_host "后端目标地址")"
  target_port="$(prompt_required_port "后端目标端口")"
  route_defaults="$(prompt_forward_route_choice "$target_host")"
  IFS=$'\t' read -r out_iface route_table <<<"$route_defaults"
  enabled="$(prompt_enabled_value "是否启用转发目标？" "true")"
  comment="$(prompt_value "备注" "${name}-target")"
  if resolve_domain_ipv4_for_forward "$target_host"; then
    target_ip="$RESOLVE_SELECTED_IP"
  else
    target_ip=""
  fi
  if [[ -n "$target_ip" ]]; then
    if ! is_ipv4 "$target_host"; then
      info "检测到后端目标是域名，当前解析为：${target_ip}"
      info "每次 apply-relay 会重新解析域名并刷新 nftables 规则。"
      info '如果该域名需要固定走 CN2 / 9929，请到 PBR 菜单选择“从现有转发目标添加 PBR”。'
    fi
    ensure_nc_for_test || true
    tcp_rc="$(tcp_reachable_status "$target_ip" "$target_port")"
    case "$tcp_rc" in
      0) ok "后端 TCP 可达：${target_ip}:${target_port}" ;;
      2) warn "未找到 nc，已跳过后端 TCP 测试。你仍可继续写入规则。" ;;
      *) warn "后端 TCP 暂不可达：${target_ip}:${target_port}。你仍可继续写入规则。" ;;
    esac
  else
    warn "后端地址暂未解析：${target_host}。你仍可继续写入规则。"
  fi
  existing_name="$(forwards_rows | awk -F'\t' -v n="$name" '$1==n {print $1; exit}')"
  existing_port="$(forwards_rows | awk -F'\t' -v p="$entry_port" '$2==p {print $1; exit}')"
  if [[ -n "$existing_name" || -n "$existing_port" ]]; then
    warn "检测到同名或同入口端口的转发目标，将覆盖更新：${existing_name:-$existing_port}"
    prompt_yes_no "确认覆盖 / 更新？" "N" || return 0
  fi
  row="${name}"$'\t'"${entry_port}"$'\t'"${target_host}"$'\t'"${target_port}"$'\t'"${out_iface}"$'\t'"${route_table}"$'\t'"${enabled}"$'\t'"${comment}"
  confirm_summary "添加转发目标摘要" "name=${name}\nentry_port=${entry_port}\ntarget=${target_host}:${target_port}\nprotocols=tcp,udp\nout_iface=${out_iface:-auto}\nroute_table=$(route_table_display "$route_table")\nenabled=${enabled}" || return 0
  replace_forward_row "$row"
  apply_nft_rules "leikwan-relay" || warn "relay nftables 未应用成功；请返回“利群主机 B”菜单，选择“重新应用转发规则”。"
  info '下一步：A/B 两边执行"一键诊断"，并从外部机器测试公网入口端口。'
}

list_forwards() {
  display_forwards
}

delete_forward() {
  need_root_unless_dry_run
  local name="${1:-}" tmp
  [[ -n "$name" ]] || name="$(select_forward_name)" || return 0
  name="$(safe_name "$name")"
  forward_exists "$name" || { warn "转发不存在。"; return 0; }
  prompt_yes_no "确认删除转发 ${name}？" "N" || return 0
  auto_snapshot_or_confirm "delete-forward" || return 0
  tmp="$(mktemp)"
  awk -F'\t' -v n="$name" '$1==n {next} {print}' "$FORWARDS_TSV" >"$tmp"
  write_file "$FORWARDS_TSV" "$(cat "$tmp")" 600
  rm -f "$tmp"
  ok "已删除转发目标：${name}"
  if apply_nft_rules "leikwan-relay"; then
    ok "已重新应用转发规则"
  else
    warn "重新应用转发规则失败；请返回“利群主机 B”菜单，选择“重新应用转发规则”。"
  fi
}

set_forward_enabled() {
  need_root_unless_dry_run
  local name enabled row old_enabled
  name="$(select_forward_name)" || return 0
  old_enabled="$(forwards_rows | awk -F'\t' -v n="$name" '$1==n {print $7; exit}')"
  enabled="$(prompt_enabled_value "是否启用转发目标 ${name}？" "${old_enabled:-true}")"
  row="$(forwards_rows | awk -F'\t' -v n="$name" -v e="$enabled" 'BEGIN{OFS="\t"} $1==n {$7=e; print; found=1} END{exit !found}')"
  [[ -n "$row" ]] || { warn "转发不存在。"; return 0; }
  replace_forward_row "$row"
  ok "已更新转发目标：${name} enabled=${enabled}"
  if apply_nft_rules "leikwan-relay"; then
    ok "已重新应用转发规则"
  else
    warn "重新应用转发规则失败；请返回“利群主机 B”菜单，选择“重新应用转发规则”。"
  fi
}

edit_forward() {
  need_root_unless_dry_run
  local name row old_name old_port old_host old_tport old_iface old_route old_enabled old_comment
  local entry_port target_host target_port out_iface route_table enabled comment new_row route_defaults
  name="${1:-}"
  [[ -n "$name" ]] || name="$(select_forward_name)" || return 0
  name="$(safe_name "$name")"
  row="$(forwards_rows | awk -F'\t' -v n="$name" '$1==n {print; found=1} END{exit !found}')"
  [[ -n "$row" ]] || { warn "转发不存在。"; return 0; }
  IFS=$'\034' read -r old_name old_port old_host old_tport old_iface old_route old_enabled old_comment <<<"$(awk -F'\t' 'BEGIN{OFS=sprintf("%c", 28)} {print $1,$2,$3,$4,$5,$6,$7,$8}' <<<"$row")"
  entry_port="$(prompt_forward_entry_port "$old_name" "$old_port")" || return 0
  warn_if_forward_port_outside_expose "$entry_port"
  if [[ "$entry_port" != "$old_port" ]] && forwards_rows | awk -F'\t' -v p="$entry_port" '$2==p {found=1} END{exit !found}'; then
    fail "entry_port 已存在：${entry_port}"
    return 1
  fi
  target_host="$(prompt_host "后端 TARGET_HOST" "$old_host")"
  target_port="$(prompt_required_port "后端 TARGET_PORT（当前 ${old_tport}）")"
  route_defaults="$(prompt_forward_route_choice "$target_host" "$old_iface" "$old_route")"
  IFS=$'\t' read -r out_iface route_table <<<"$route_defaults"
  enabled="$(prompt_enabled_value "是否启用转发目标 ${old_name}？" "$old_enabled")"
  comment="$(prompt_value "备注" "$old_comment")"
  new_row="${old_name}"$'\t'"${entry_port}"$'\t'"${target_host}"$'\t'"${target_port}"$'\t'"${out_iface}"$'\t'"${route_table}"$'\t'"${enabled}"$'\t'"${comment}"
  confirm_summary "修改转发目标摘要" "name=${old_name}\nentry_port=${entry_port}\ntarget=${target_host}:${target_port}\nprotocols=tcp,udp\nout_iface=${out_iface:-auto}\nroute_table=$(route_table_display "$route_table")\nenabled=${enabled}" || return 0
  replace_forward_row "$new_row"
  ok "已修改转发目标：${old_name}"
  if apply_nft_rules "leikwan-relay"; then
    ok "已重新应用转发规则"
  else
    warn "重新应用转发规则失败；请返回“利群主机 B”菜单，选择“重新应用转发规则”。"
  fi
}

test_forward() {
  local name="${1:-}" row _entry_port target_host target_ip target_port _out_iface _route_table enabled _last_resolved_at _comment
  [[ -n "$name" ]] || name="$(select_forward_name)" || return 0
  name="$(safe_name "$name")"
  forward_exists "$name" || { warn "转发不存在：${name}"; return 0; }
  resolve_forwards || return 1
  row="$(resolved_rows | awk -F'\t' -v n="$name" '$1==n {print; found=1} END{exit !found}')"
  [[ -n "$row" ]] || { warn "转发不存在。"; return 0; }
  IFS=$'\034' read -r name _entry_port target_host target_ip target_port _out_iface _route_table enabled _last_resolved_at _comment <<<"$(awk -F'\t' 'BEGIN{OFS=sprintf("%c", 28)} {print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10}' <<<"$row")"
  [[ "$enabled" == "true" ]] || warn "该转发当前 disabled，仅执行后端可达性测试。"
  [[ -n "$target_ip" ]] || { warn "目标未解析：${target_host}"; return 0; }
  ensure_nc_for_test || true
  case "$(tcp_reachable_status "$target_ip" "$target_port")" in
    0) ok "${name} target TCP 可达" ;;
    2) warn "未找到 nc，无法测试 ${name} target TCP；请安装 netcat-openbsd" ;;
    *) warn "${name} target TCP 不可达" ;;
  esac
  case "$(udp_probe_status "$target_ip" "$target_port")" in
    0) ok "${name} target UDP 探测完成：${target_ip}:${target_port}" ;;
    2) warn "未找到 nc，无法测试 ${name} target UDP；请安装 netcat-openbsd" ;;
    *) warn "${name} target UDP 探测未确认。UDP 无连接探测可能不可靠，请结合业务实际测试。" ;;
  esac
}

import_forwards_tsv() {
  need_root_unless_dry_run
  local path
  path="$(prompt_value "请输入 forwards.tsv 路径")"
  [[ -f "$path" ]] || { warn "文件不存在：${path}"; return 0; }
  validate_forwards_tsv "$path" || return 1
  confirm_summary "导入 forwards.tsv" "来源：${path}\n目标：${FORWARDS_TSV}" || return 0
  write_file "$FORWARDS_TSV" "$(cat "$path")" 600
  resolve_forwards || return 1
}

import_forward_single_apply() {
  need_root_unless_dry_run
  local source="${1:-}" tmp name entry_port target_host target_port enabled comment row public_host relay_ip
  tmp="$(mktemp)"
  read_forward_code "$tmp" "$source" || { rm -f "$tmp"; return 1; }
  require_env_fields "$tmp" FORWARD_VERSION NAME ENTRY_PORT TARGET_HOST TARGET_PORT ENABLED || { rm -f "$tmp"; return 1; }
  [[ "$(env_file_get "$tmp" FORWARD_VERSION)" == "0.4" ]] || { fail "FORWARD_VERSION 不支持。"; rm -f "$tmp"; return 1; }
  name="$(safe_name "$(env_file_get "$tmp" NAME)")"
  entry_port="$(env_file_get "$tmp" ENTRY_PORT)"
  target_host="$(env_file_get "$tmp" TARGET_HOST)"
  target_port="$(env_file_get "$tmp" TARGET_PORT)"
  enabled="$(env_file_get "$tmp" ENABLED)"
  comment="$(env_file_get "$tmp" COMMENT)"
  is_port "$entry_port" || { fail "ENTRY_PORT 非法：${entry_port}"; rm -f "$tmp"; return 1; }
  is_port "$target_port" || { fail "TARGET_PORT 非法：${target_port}"; rm -f "$tmp"; return 1; }
  [[ "$enabled" == "true" || "$enabled" == "false" ]] || { fail "ENABLED 必须是 true 或 false。"; rm -f "$tmp"; return 1; }
  row="${name}"$'\t'"${entry_port}"$'\t'"${target_host}"$'\t'"${target_port}"$'\t\t\t'"${enabled}"$'\t'"${comment}"
  confirm_summary "导入公网入口转发摘要" "name=${name}\nentry_port=${entry_port}\ntarget=${target_host}:${target_port}\nenabled=${enabled}\n动作：写入本机 forwards.tsv，并按端口 DNAT 到 Relay。" || { rm -f "$tmp"; return 0; }
  replace_forward_row "$row"
  relay_ip="$(current_relay_et_ip)"
  write_file "$ENTRY_EXPOSE_ENV" "ENTRY_MODE=bundle
RELAY_ET_IP=${relay_ip}
ENABLED=true" 600
  apply_nft_rules "cloud-entry" || { rm -f "$tmp"; return 1; }
  generate_forward_outputs || true
  public_host="$(current_entry_public_host)"
  echo
  echo "公网入口："
  echo "${public_host}:${entry_port} -> EasyTier relay ${relay_ip}:${entry_port} -> ${target_host}:${target_port}"
  rm -f "$tmp"
}

import_forward_code() {
  need_root_unless_dry_run
  local source="${1:-}" raw line has_content=0 rc
  raw="$(mktemp)"
  if [[ -n "$source" ]]; then
    if [[ "$source" == "-" ]]; then
      cat >"$raw"
    elif [[ -f "$source" ]]; then
      cp -a "$source" "$raw"
    else
      printf '%s\n' "$source" >"$raw"
    fi
  else
    echo "请粘贴从 B 利群主机复制的整段转发接入码（单条或聚合 BUNDLE 均可）。"
    echo "看到 END 行会自动继续；如果只粘贴 KEY=VALUE 内容，请用空行结束。"
    while IFS= read -r line; do
      line="$(normalize_menu_choice "$line")"
      if [[ -z "$line" ]]; then
        (( has_content == 1 )) && break
        continue
      fi
      has_content=1
      printf '%s\n' "$line" >>"$raw"
      [[ "$line" == "-----END LEIKWAN FORWARD-----" || "$line" == "-----END LEIKWAN FORWARD BUNDLE-----" ]] && break
      [[ "$line" == LEIKWAN_FORWARD_BASE64=* || "$line" == LEIKWAN_FORWARD_BUNDLE_BASE64=* ]] && break
      [[ "$line" =~ ^[A-Za-z0-9+/]+={0,2}$ ]] && ((${#line} >= 30)) && break
    done
  fi
  if grep -q 'LEIKWAN FORWARD BUNDLE\|LEIKWAN_FORWARD_BUNDLE_BASE64\|FORWARD_BUNDLE_VERSION' "$raw"; then
    import_forward_bundle_apply "$raw"; rc=$?
  else
    import_forward_single_apply "$raw"; rc=$?
  fi
  rm -f "$raw"
  return $rc
}

export_forwards_tsv() {
  ensure_tsv_files
  echo "forwards.tsv：${FORWARDS_TSV}"
  sed -n '1,200p' "$FORWARDS_TSV"
}

resolve_forward_targets_action() {
  display_forward_selection_list all "当前转发目标："
  resolve_forwards
}

resolve_forwards() {
  ensure_tsv_files
  validate_forwards_tsv || return 1
  local content target_ip old_ip name entry_port target_host target_port out_iface route_table enabled comment resolved_at
  resolved_at="$(date '+%F %T')"
  content=$'# name\tentry_port\ttarget_host\tresolved_ip\ttarget_port\tout_iface\troute_table\tenabled\tlast_resolved_at\tcomment'
  while IFS=$'\034' read -r name entry_port target_host target_port out_iface route_table enabled comment; do
    old_ip="$(last_resolved_ip_for_forward "$name")"
    if resolve_domain_ipv4_for_forward "$target_host"; then
      target_ip="$RESOLVE_SELECTED_IP"
    else
      target_ip=""
    fi
    if [[ -z "$target_ip" ]]; then
      if [[ -n "$old_ip" ]]; then
        warn "${name} 域名解析失败，继续使用上次解析 IP：${old_ip}"
        target_ip="$old_ip"
      else
        warn "${name} 域名解析失败且没有上次解析 IP，已跳过该转发目标：${target_host}"
        continue
      fi
    elif [[ -n "$old_ip" && "$old_ip" != "$target_ip" ]]; then
      info "转发目标 ${name} 解析变化：${old_ip} -> ${target_ip}"
    fi
    content="${content}"$'\n'"${name}"$'\t'"${entry_port}"$'\t'"${target_host}"$'\t'"${target_ip}"$'\t'"${target_port}"$'\t'"${out_iface}"$'\t'"${route_table}"$'\t'"${enabled}"$'\t'"${resolved_at}"$'\t'"${comment}"
  done < <(forwards_rows_usv)
  write_file "$RESOLVED_TSV" "$content" 600
}

resolved_rows() {
  [[ -f "$RESOLVED_TSV" ]] || return 0
  awk -F'\t' '{gsub(/\r/, "")} NF && $1 !~ /^#/ {print}' "$RESOLVED_TSV"
}

resolved_rows_usv() {
  resolved_rows | awk -F'\t' 'BEGIN{OFS=sprintf("%c", 28)} NF>=9 {print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10}'
}

env_value_one_line() {
  printf '%s' "$1" | tr '\r\n' '  '
}

redact_sensitive_inline() {
  printf '%s' "$1" | sed -E \
    -e 's#(https?://[^?[:space:]]+)\?[^[:space:]]+#\1?<redacted>#g' \
    -e 's/(([Tt]oken|[Kk]ey|[Pp]assword|[Ss]ecret)[[:space:]_=-]+)[^[:space:]&]+/\1<redacted>/g'
}

entry_ddns_config_value() {
  local key="$1" default="$2" value
  value="$(env_file_get "$ENTRY_DDNS_CONFIG" "$key")"
  printf '%s' "${value:-$default}"
}

entry_ddns_config_bool() {
  local key="$1" default="$2" value
  value="$(entry_ddns_config_value "$key" "$default")"
  case "${value,,}" in
    true|yes|1|on) return 0 ;;
    *) return 1 ;;
  esac
}

entry_ddns_write_config() {
  local enabled="${1:-$(entry_ddns_config_value ENTRY_DDNS_ENABLED "$ENTRY_DDNS_ENABLED_DEFAULT")}"
  local host="${2:-$(entry_ddns_config_value ENTRY_DDNS_HOST "")}"
  local provider="${3:-$(entry_ddns_config_value ENTRY_DDNS_PROVIDER "$ENTRY_DDNS_PROVIDER_DEFAULT")}"
  local update_url="${4:-$(entry_ddns_config_value ENTRY_DDNS_UPDATE_URL "")}"
  local update_cmd="${5:-$(entry_ddns_config_value ENTRY_DDNS_UPDATE_CMD "")}"
  local token="${6:-$(entry_ddns_config_value ENTRY_DDNS_TOKEN "")}"
  local last_ip="${7:-$(entry_ddns_config_value ENTRY_DDNS_LAST_IP "")}"
  local interval="${8:-$(entry_ddns_config_value ENTRY_DDNS_INTERVAL "$ENTRY_DDNS_INTERVAL_DEFAULT")}"
  local ip_source="${9:-$(entry_ddns_config_value ENTRY_DDNS_IP_SOURCE "$ENTRY_DDNS_IP_SOURCE_DEFAULT")}"
  local content
  content="ENTRY_DDNS_ENABLED=$(env_value_one_line "$enabled")
ENTRY_DDNS_HOST=$(env_value_one_line "$host")
ENTRY_DDNS_PROVIDER=$(env_value_one_line "$provider")
ENTRY_DDNS_UPDATE_URL=$(env_value_one_line "$update_url")
ENTRY_DDNS_UPDATE_CMD=$(env_value_one_line "$update_cmd")
ENTRY_DDNS_TOKEN=$(env_value_one_line "$token")
ENTRY_DDNS_LAST_IP=$(env_value_one_line "$last_ip")
ENTRY_DDNS_INTERVAL=$(env_value_one_line "$interval")
ENTRY_DDNS_IP_SOURCE=$(env_value_one_line "$ip_source")"
  if (( DRY_RUN == 1 )); then
    echo
    echo "${BOLD}[DRY-RUN] ${ENTRY_DDNS_CONFIG}${RESET}"
    printf '%s\n' "$content" | sed -E \
      -e 's#(ENTRY_DDNS_UPDATE_URL=).*#\1REDACTED#g' \
      -e 's#(ENTRY_DDNS_UPDATE_CMD=).*#\1REDACTED#g' \
      -e 's#(ENTRY_DDNS_TOKEN=).*#\1REDACTED#g'
    return 0
  fi
  write_file "$ENTRY_DDNS_CONFIG" "$content" 600
}

entry_ddns_ensure_config() {
  [[ -f "$ENTRY_DDNS_CONFIG" ]] || entry_ddns_write_config "$ENTRY_DDNS_ENABLED_DEFAULT" "" "$ENTRY_DDNS_PROVIDER_DEFAULT" "" "" "" "" "$ENTRY_DDNS_INTERVAL_DEFAULT" "$ENTRY_DDNS_IP_SOURCE_DEFAULT"
}

entry_ddns_emit() {
  local level="$1" msg="$2" line
  case "$level" in
    OK) line="[OK] ${msg}" ;;
    WARN) line="[WARN] ${msg}" ;;
    FAIL) line="[FAIL] ${msg}" ;;
    *) line="[INFO] ${msg}" ;;
  esac
  echo "$line"
  if (( DRY_RUN == 0 )) && (( LOG_DISABLED == 0 )) && [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    mkdir -p "$(dirname "$ENTRY_DDNS_LOG_FILE")" 2>/dev/null || true
    printf '[%s] %s\n' "$(status_now)" "$(redact_sensitive_inline "$line")" >>"$ENTRY_DDNS_LOG_FILE" 2>/dev/null || true
  fi
}

entry_ddns_timer_state() {
  local timer_state
  timer_state="$(systemd_active_state "${ENTRY_DDNS_SERVICE_NAME}.timer" 2>/dev/null || true)"
  [[ -n "$timer_state" ]] || timer_state="disabled"
  [[ "$timer_state" == "inactive" ]] && timer_state="disabled"
  printf '%s' "$timer_state"
}

entry_ddns_status_value() {
  env_file_get "$ENTRY_DDNS_STATUS_FILE" "$1"
}

entry_ddns_write_last_status() {
  local result="$1" host="$2" public_ip="$3" resolved_ip="$4" changed="$5" provider="${6:-}" last_ip="${7:-}"
  (( DRY_RUN == 1 )) && return 0
  [[ ${EUID:-$(id -u)} -eq 0 ]] || return 0
  mkdir -p "$STATUS_DIR" 2>/dev/null || return 0
  {
    printf 'LAST_ENTRY_DDNS_TIME=%s\n' "$(status_now)"
    printf 'LAST_ENTRY_DDNS_RESULT=%s\n' "$result"
    printf 'LAST_ENTRY_DDNS_HOST=%s\n' "$host"
    printf 'LAST_ENTRY_DDNS_PUBLIC_IP=%s\n' "$public_ip"
    printf 'LAST_ENTRY_DDNS_RESOLVED_IP=%s\n' "$resolved_ip"
    printf 'LAST_ENTRY_DDNS_CHANGED=%s\n' "$changed"
    printf 'LAST_ENTRY_DDNS_PROVIDER=%s\n' "$provider"
    printf 'LAST_ENTRY_DDNS_LAST_IP=%s\n' "$last_ip"
    printf 'LAST_ENTRY_DDNS_VERSION=%s\n' "$TOOL_VERSION"
  } >"$ENTRY_DDNS_STATUS_FILE"
  chmod 600 "$ENTRY_DDNS_STATUS_FILE" 2>/dev/null || true
}

entry_ddns_apply_template() {
  local template="$1" host="$2" ip="$3" value
  value="${template//\{host\}/$host}"
  value="${value//\{ip\}/$ip}"
  printf '%s' "$value"
}

entry_ddns_current_public_ip() {
  local source
  source="$(entry_ddns_config_value ENTRY_DDNS_IP_SOURCE "$ENTRY_DDNS_IP_SOURCE_DEFAULT")"
  case "$source" in
    auto|"") detect_public_ipv4 2>/dev/null || true ;;
    last|cached) entry_ddns_status_value LAST_ENTRY_DDNS_PUBLIC_IP ;;
    *) detect_public_ipv4 2>/dev/null || true ;;
  esac
}

entry_ddns_run_update() {
  local provider="$1" host="$2" public_ip="$3" template url cmd
  case "$provider" in
    custom-url|custom)
      template="$(entry_ddns_config_value ENTRY_DDNS_UPDATE_URL "")"
      [[ -n "$template" ]] || { entry_ddns_emit FAIL "ENTRY_DDNS_UPDATE_URL 为空。"; return 1; }
      command -v curl >/dev/null 2>&1 || { entry_ddns_emit FAIL "缺少 curl，无法执行 custom-url 更新。"; return 1; }
      url="$(entry_ddns_apply_template "$template" "$host" "$public_ip")"
      entry_ddns_emit INFO "正在请求 DDNS custom-url：$(redact_sensitive_inline "$url")"
      curl -fsSL --connect-timeout 15 --max-time 60 "$url" >/dev/null
      ;;
    custom-cmd)
      template="$(entry_ddns_config_value ENTRY_DDNS_UPDATE_CMD "")"
      [[ -n "$template" ]] || { entry_ddns_emit FAIL "ENTRY_DDNS_UPDATE_CMD 为空。"; return 1; }
      cmd="$(entry_ddns_apply_template "$template" "$host" "$public_ip")"
      entry_ddns_emit INFO "正在执行 DDNS custom-cmd：$(redact_sensitive_inline "$cmd")"
      bash -c "$cmd" >/dev/null
      ;;
    cloudflare)
      entry_ddns_emit WARN "cloudflare provider 已预留，当前版本请使用 custom-url 或 custom-cmd 对接。"
      return 1
      ;;
    *)
      entry_ddns_emit FAIL "不支持的 ENTRY_DDNS_PROVIDER：${provider}"
      return 1
      ;;
  esac
}

entry_ddns_wait_resolved() {
  local host="$1" public_ip="$2" retries="${ENTRY_DDNS_VERIFY_RETRIES:-10}" sleep_seconds="${ENTRY_DDNS_VERIFY_SLEEP:-3}" i resolved
  ENTRY_DDNS_WAIT_LAST_RESOLVED=""
  for ((i = 1; i <= retries; i++)); do
    entry_ddns_emit INFO "等待 DNS 生效：${i}/${retries}"
    if resolve_domain_ipv4_multi "$host"; then
      resolved="$RESOLVE_SELECTED_IP"
    else
      resolved=""
    fi
    ENTRY_DDNS_WAIT_LAST_RESOLVED="$resolved"
    if [[ "$resolved" == "$public_ip" ]]; then
      return 0
    fi
    (( i < retries )) && sleep "$sleep_seconds"
  done
  [[ "$ENTRY_DDNS_WAIT_LAST_RESOLVED" == "$public_ip" ]]
}

entry_ddns_run() {
  need_root_unless_dry_run
  local non_interactive=0 arg enabled host provider public_ip resolved_ip final_resolved changed="false"
  while (($# > 0)); do
    arg="$1"
    case "$arg" in
      --non-interactive) non_interactive=1; shift ;;
      *) fail "未知 entry ddns run 参数：${arg}"; return 1 ;;
    esac
  done
  entry_ddns_ensure_config
  enabled="$(entry_ddns_config_value ENTRY_DDNS_ENABLED "$ENTRY_DDNS_ENABLED_DEFAULT")"
  host="$(entry_ddns_config_value ENTRY_DDNS_HOST "")"
  provider="$(entry_ddns_config_value ENTRY_DDNS_PROVIDER "$ENTRY_DDNS_PROVIDER_DEFAULT")"
  entry_ddns_emit WARN "该命令为兼容入口，普通用户建议使用 lq ddns run。"
  if ! entry_ddns_config_bool ENTRY_DDNS_ENABLED "$ENTRY_DDNS_ENABLED_DEFAULT"; then
    if (( non_interactive == 1 )); then
      entry_ddns_emit INFO "兼容 DNS 更新入口未启用，跳过。"
      entry_ddns_write_last_status "skipped" "$host" "" "" "false" "$provider" ""
      return 0
    fi
    entry_ddns_emit WARN "兼容 DNS 更新入口未启用，本次仅按当前配置手动执行。"
  fi
  [[ -n "$host" ]] || { entry_ddns_emit FAIL "ENTRY_DDNS_HOST 为空，请先执行：lq entry ddns setup"; entry_ddns_write_last_status "fail" "" "" "" "false" "$provider" ""; return 1; }
  is_domain_name "$host" || { entry_ddns_emit FAIL "ENTRY_DDNS_HOST 必须是域名，不能是纯 IPv4：${host}"; entry_ddns_write_last_status "fail" "$host" "" "" "false" "$provider" ""; return 1; }
  entry_ddns_emit INFO "正在检测当前公网 IPv4..."
  public_ip="$(entry_ddns_current_public_ip)"
  if [[ -z "$public_ip" ]]; then
    entry_ddns_emit FAIL "无法获取当前公网 IPv4。"
    entry_ddns_emit INFO "请检查服务器是否能访问 IPv4 公网。"
    entry_ddns_write_last_status "fail" "$host" "" "" "false" "$provider" ""
    return 1
  fi
  entry_ddns_emit INFO "正在解析域名：${host}"
    if resolve_domain_ipv4_multi "$host"; then
      resolved_ip="$RESOLVE_SELECTED_IP"
    else
      resolved_ip=""
    fi
  if [[ "$resolved_ip" == "$public_ip" ]]; then
    entry_ddns_emit OK "DDNS 已一致，无需更新。"
    entry_ddns_write_config "$enabled" "$host" "$provider" "$(entry_ddns_config_value ENTRY_DDNS_UPDATE_URL "")" "$(entry_ddns_config_value ENTRY_DDNS_UPDATE_CMD "")" "$(entry_ddns_config_value ENTRY_DDNS_TOKEN "")" "$public_ip" "$(entry_ddns_config_value ENTRY_DDNS_INTERVAL "$ENTRY_DDNS_INTERVAL_DEFAULT")" "$(entry_ddns_config_value ENTRY_DDNS_IP_SOURCE "$ENTRY_DDNS_IP_SOURCE_DEFAULT")"
    entry_ddns_write_last_status "ok" "$host" "$public_ip" "$resolved_ip" "false" "$provider" "$public_ip"
    return 0
  fi
  if ! ddns_config_bool DDNS_UPDATE_DNS_RECORD "$DDNS_UPDATE_DNS_RECORD_DEFAULT"; then
    entry_ddns_emit INFO "DDNS_UPDATE_DNS_RECORD=false，默认不修改 DNS 服务商记录。"
    entry_ddns_write_last_status "warn" "$host" "$public_ip" "$resolved_ip" "true" "$provider" "$(entry_ddns_config_value ENTRY_DDNS_LAST_IP "")"
    return 1
  fi
  if [[ -z "$resolved_ip" ]]; then
    entry_ddns_emit WARN "域名当前解析失败，将尝试更新 DDNS。"
  else
    entry_ddns_emit WARN "本机公网入口 DDNS 不一致：${host} ${resolved_ip} -> ${public_ip}"
  fi
  changed="true"
  if ! entry_ddns_run_update "$provider" "$host" "$public_ip"; then
    entry_ddns_write_last_status "fail" "$host" "$public_ip" "$resolved_ip" "$changed" "$provider" "$(entry_ddns_config_value ENTRY_DDNS_LAST_IP "")"
    return 1
  fi
  if entry_ddns_wait_resolved "$host" "$public_ip"; then
    final_resolved="$ENTRY_DDNS_WAIT_LAST_RESOLVED"
  else
    final_resolved="$ENTRY_DDNS_WAIT_LAST_RESOLVED"
  fi
  if [[ "$final_resolved" == "$public_ip" ]]; then
    entry_ddns_emit OK "DDNS 更新成功：${host} -> ${public_ip}"
    entry_ddns_write_config "$enabled" "$host" "$provider" "$(entry_ddns_config_value ENTRY_DDNS_UPDATE_URL "")" "$(entry_ddns_config_value ENTRY_DDNS_UPDATE_CMD "")" "$(entry_ddns_config_value ENTRY_DDNS_TOKEN "")" "$public_ip" "$(entry_ddns_config_value ENTRY_DDNS_INTERVAL "$ENTRY_DDNS_INTERVAL_DEFAULT")" "$(entry_ddns_config_value ENTRY_DDNS_IP_SOURCE "$ENTRY_DDNS_IP_SOURCE_DEFAULT")"
    entry_ddns_write_last_status "ok" "$host" "$public_ip" "$final_resolved" "$changed" "$provider" "$public_ip"
    return 0
  fi
  entry_ddns_emit WARN "DDNS 更新命令已执行，但解析尚未生效。"
  entry_ddns_emit INFO "当前公网 IP: ${public_ip}"
  entry_ddns_emit INFO "域名解析 IP: ${final_resolved:-"-"}"
  entry_ddns_emit INFO "可稍后执行：lq entry ddns status"
  entry_ddns_write_last_status "warn" "$host" "$public_ip" "$final_resolved" "$changed" "$provider" "$(entry_ddns_config_value ENTRY_DDNS_LAST_IP "")"
  return 1
}

entry_ddns_status() {
  local configured="yes" enabled host provider timer_state last_time last_result last_public last_resolved last_changed public_ip resolved_ip ip_source
  [[ -f "$ENTRY_DDNS_CONFIG" ]] || configured="no"
  enabled="$(entry_ddns_config_value ENTRY_DDNS_ENABLED "$ENTRY_DDNS_ENABLED_DEFAULT")"
  host="$(entry_ddns_config_value ENTRY_DDNS_HOST "")"
  provider="$(entry_ddns_config_value ENTRY_DDNS_PROVIDER "$ENTRY_DDNS_PROVIDER_DEFAULT")"
  ip_source="$(entry_ddns_config_value ENTRY_DDNS_IP_SOURCE "$ENTRY_DDNS_IP_SOURCE_DEFAULT")"
  timer_state="$(entry_ddns_timer_state)"
  last_time="$(entry_ddns_status_value LAST_ENTRY_DDNS_TIME)"
  last_result="$(entry_ddns_status_value LAST_ENTRY_DDNS_RESULT)"
  last_public="$(entry_ddns_status_value LAST_ENTRY_DDNS_PUBLIC_IP)"
  last_resolved="$(entry_ddns_status_value LAST_ENTRY_DDNS_RESOLVED_IP)"
  last_changed="$(entry_ddns_status_value LAST_ENTRY_DDNS_CHANGED)"
  echo "兼容 DNS 更新状态"
  echo "----------------------------------------"
  if [[ "$configured" == "no" ]]; then
    echo "[INFO] 未配置兼容 DNS 更新入口。"
    echo "[INFO] 如果公网入口域名由外部 DDNS 客户端维护，可忽略。"
  fi
  echo "enabled: $(bool_enabled_disabled "$enabled")"
  echo "host: ${host:-"-"}"
  echo "provider: ${provider:-"-"}"
  echo "timer: ${timer_state}"
  if [[ -n "$host" && "$host" != "-" ]] && is_domain_name "$host"; then
    if [[ "$ip_source" == "last" || "$ip_source" == "cached" ]]; then
      public_ip="$last_public"
      resolved_ip="$last_resolved"
    else
      public_ip="$(entry_ddns_current_public_ip)"
      if resolve_domain_ipv4_multi "$host"; then
        resolved_ip="$RESOLVE_SELECTED_IP"
      else
        resolved_ip=""
      fi
    fi
    echo "当前公网 IP: ${public_ip:-"-"}"
    echo "域名解析 IP: ${resolved_ip:-"-"}"
    if [[ -n "$public_ip" && -n "$resolved_ip" && "$public_ip" == "$resolved_ip" ]]; then
      echo "一致性: OK"
    elif [[ -n "$public_ip" || -n "$resolved_ip" ]]; then
      echo "一致性: WARN"
    else
      echo "一致性: unknown"
    fi
  else
    echo "当前公网 IP: ${last_public:-"-"}"
    echo "域名解析 IP: ${last_resolved:-"-"}"
    echo "一致性: skipped"
  fi
  echo "最近运行: ${last_time:-"-"}"
  echo "最近结果: ${last_result:-"-"}"
  echo "最近变化: ${last_changed:-"-"}"
}

entry_ddns_setup() {
  need_root_unless_dry_run
  local default_host host provider_choice provider update_url="" update_cmd="" interval enabled
  entry_ddns_current_config_summary
  echo
  warn "该命令为兼容入口，普通用户建议使用 lq ddns run。"
  warn "默认 DDNS_UPDATE_DNS_RECORD=false，不需要 DNS provider token。"
  echo "兼容 DNS 更新的作用："
  echo "把本机当前公网 IP 写入指定 DNS 记录。"
  echo "域名解析变化检测只负责检测公网入口、转发目标和 PBR 域名，并刷新本地配置。"
  echo "这是高级兼容能力，不是默认路径。"
  echo
  entry_ddns_ensure_config
  warn "兼容 DNS 更新配置可能包含 DNS 服务商 token，会保存在 ${ENTRY_DDNS_CONFIG}。"
  default_host="$(entry_ddns_config_value ENTRY_DDNS_HOST "$(current_entry_configured_public_host)")"
  host="$(prompt_value "公网入口域名" "$default_host")"
  [[ -n "$host" ]] || { warn "未填写域名，已取消。"; return 0; }
  if ! is_domain_name "$host"; then
    warn "公网入口 DDNS 域名不能是纯 IPv4：${host}"
    return 1
  fi
  echo "请选择 DDNS 更新方式："
  echo "1. custom-url：通过 URL 请求更新 DNS"
  echo "2. custom-cmd：调用本机命令更新 DNS"
  echo "0. 返回"
  provider_choice="$(prompt_menu_choice "请选择：")"
  case "$provider_choice" in
    1|"") provider="custom-url" ;;
    2) provider="custom-cmd" ;;
    0) return 0 ;;
    *) warn "无效 provider。"; return 1 ;;
  esac
  case "$provider" in
    custom-url)
      echo "支持变量："
      echo "{host} = 域名"
      echo "{ip}   = 当前公网 IPv4"
      echo "示例：https://example.com/update?token=TOKEN&domain={host}&ip={ip}"
      update_url="$(prompt_value "custom URL" "$(entry_ddns_config_value ENTRY_DDNS_UPDATE_URL "")")"
      ;;
    custom-cmd)
      echo "支持变量："
      echo "{host}"
      echo "{ip}"
      echo "示例：/usr/local/bin/update-ddns {host} {ip}"
      update_cmd="$(prompt_value "custom command" "$(entry_ddns_config_value ENTRY_DDNS_UPDATE_CMD "")")"
      ;;
  esac
  interval="$(prompt_value "刷新间隔" "$(entry_ddns_config_value ENTRY_DDNS_INTERVAL "$ENTRY_DDNS_INTERVAL_DEFAULT")")"
  [[ -n "$interval" ]] || interval="$ENTRY_DDNS_INTERVAL_DEFAULT"
  if prompt_yes_no "是否启用兼容 DNS 更新入口？" "N"; then enabled="true"; else enabled="false"; fi
  entry_ddns_write_config "$enabled" "$host" "$provider" "$update_url" "$update_cmd" "$(entry_ddns_config_value ENTRY_DDNS_TOKEN "")" "$(entry_ddns_config_value ENTRY_DDNS_LAST_IP "")" "$interval" "$(entry_ddns_config_value ENTRY_DDNS_IP_SOURCE "$ENTRY_DDNS_IP_SOURCE_DEFAULT")"
  ok "兼容 DNS 更新配置已保存：${ENTRY_DDNS_CONFIG}"
  if prompt_yes_no "是否立即启用兼容 DNS 更新定时器？" "N"; then
    entry_ddns_enable_timer
  fi
  echo "下一步："
  echo "1. 执行 lq entry ddns run 测试更新"
  echo "2. 执行 lq entry ddns enable 启用定时刷新"
  echo "3. 执行 lq entry ddns status 查看一致性"
}

render_entry_ddns_service() {
  cat <<EOF
# Managed by leikwan-toolkit ${TOOL_VERSION}
[Unit]
Description=Leikwan entry DDNS updater
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash -lc '/root/leikwan-toolkit.sh entry ddns run --non-interactive >>${ENTRY_DDNS_LOG_FILE} 2>&1'
EOF
}

render_entry_ddns_timer() {
  local interval
  interval="$(entry_ddns_config_value ENTRY_DDNS_INTERVAL "$ENTRY_DDNS_INTERVAL_DEFAULT")"
  cat <<EOF
# Managed by leikwan-toolkit ${TOOL_VERSION}
[Unit]
Description=Leikwan entry DDNS updater timer

[Timer]
OnBootSec=2min
OnUnitActiveSec=${interval}
Unit=${ENTRY_DDNS_SERVICE_NAME}.service

[Install]
WantedBy=timers.target
EOF
}

entry_ddns_install_units() {
  need_root_unless_dry_run
  entry_ddns_ensure_config
  write_file "$ENTRY_DDNS_SERVICE" "$(render_entry_ddns_service)" 644
  write_file "$ENTRY_DDNS_TIMER" "$(render_entry_ddns_timer)" 644
  if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || warn "systemd daemon-reload 失败。"
  fi
}

entry_ddns_enable_timer() {
  need_root_unless_dry_run
  local host
  entry_ddns_ensure_config
  host="$(entry_ddns_config_value ENTRY_DDNS_HOST "")"
  [[ -n "$host" ]] || { warn "尚未配置 ENTRY_DDNS_HOST，请先执行：lq entry ddns setup"; return 1; }
  entry_ddns_write_config true "$host" "$(entry_ddns_config_value ENTRY_DDNS_PROVIDER "$ENTRY_DDNS_PROVIDER_DEFAULT")" "$(entry_ddns_config_value ENTRY_DDNS_UPDATE_URL "")" "$(entry_ddns_config_value ENTRY_DDNS_UPDATE_CMD "")" "$(entry_ddns_config_value ENTRY_DDNS_TOKEN "")" "$(entry_ddns_config_value ENTRY_DDNS_LAST_IP "")" "$(entry_ddns_config_value ENTRY_DDNS_INTERVAL "$ENTRY_DDNS_INTERVAL_DEFAULT")" "$(entry_ddns_config_value ENTRY_DDNS_IP_SOURCE "$ENTRY_DDNS_IP_SOURCE_DEFAULT")"
  entry_ddns_install_units
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now "${ENTRY_DDNS_SERVICE_NAME}.timer"
    ok "兼容 DNS 更新 timer 已启用。"
  else
    warn "未找到 systemctl，无法启用兼容 DNS 更新 timer。"
    return 1
  fi
}

entry_ddns_disable_timer() {
  need_root_unless_dry_run
  if [[ -f "$ENTRY_DDNS_CONFIG" ]]; then
    entry_ddns_write_config false "$(entry_ddns_config_value ENTRY_DDNS_HOST "")" "$(entry_ddns_config_value ENTRY_DDNS_PROVIDER "$ENTRY_DDNS_PROVIDER_DEFAULT")" "$(entry_ddns_config_value ENTRY_DDNS_UPDATE_URL "")" "$(entry_ddns_config_value ENTRY_DDNS_UPDATE_CMD "")" "$(entry_ddns_config_value ENTRY_DDNS_TOKEN "")" "$(entry_ddns_config_value ENTRY_DDNS_LAST_IP "")" "$(entry_ddns_config_value ENTRY_DDNS_INTERVAL "$ENTRY_DDNS_INTERVAL_DEFAULT")" "$(entry_ddns_config_value ENTRY_DDNS_IP_SOURCE "$ENTRY_DDNS_IP_SOURCE_DEFAULT")"
  fi
  if command -v systemctl >/dev/null 2>&1; then
    systemctl disable --now "${ENTRY_DDNS_SERVICE_NAME}.timer" 2>/dev/null || true
    ok "兼容 DNS 更新 timer 已禁用。"
  else
    warn "未找到 systemctl，无法禁用兼容 DNS 更新 timer。"
  fi
}

entry_ddns_logs() {
  if [[ -f "$ENTRY_DDNS_LOG_FILE" ]]; then
    tail -n 100 "$ENTRY_DDNS_LOG_FILE"
  else
    info "暂无兼容 DNS 更新日志：${ENTRY_DDNS_LOG_FILE}"
  fi
}

entry_ddns_current_config_summary() {
  local configured enabled host provider timer_state
  configured="yes"
  [[ -f "$ENTRY_DDNS_CONFIG" ]] || configured="no"
  enabled="$(entry_ddns_config_value ENTRY_DDNS_ENABLED "$ENTRY_DDNS_ENABLED_DEFAULT")"
  host="$(entry_ddns_config_value ENTRY_DDNS_HOST "")"
  provider="$(entry_ddns_config_value ENTRY_DDNS_PROVIDER "")"
  timer_state="$(entry_ddns_timer_state)"
  [[ "$timer_state" == "unknown" ]] && timer_state="inactive"
  echo "兼容 DNS 更新当前配置"
  echo "----------------------------------------"
  if [[ "$configured" == "no" ]]; then
    echo "状态: disabled"
    echo "域名: 未配置"
    echo "provider: 未配置"
    echo "timer: ${timer_state}"
  else
    echo "状态: $(bool_enabled_disabled "$enabled")"
    echo "域名: ${host:-未配置}"
    echo "provider: ${provider:-未配置}"
    echo "timer: ${timer_state}"
  fi
}

ddns_config_value() {
  local key="$1" default="$2" value
  value="$(env_file_get "$DDNS_CONFIG" "$key")"
  [[ -n "$value" ]] || value="$(env_file_get "$DDNS_LEGACY_CONFIG" "$key")"
  printf '%s' "${value:-$default}"
}

ddns_config_bool() {
  local key="$1" default="$2" value
  value="$(ddns_config_value "$key" "$default")"
  case "${value,,}" in
    true|yes|1|on) return 0 ;;
    *) return 1 ;;
  esac
}

bool_yes_no() {
  case "${1,,}" in
    true|yes|1|on) printf 'yes' ;;
    *) printf 'no' ;;
  esac
}

bool_to_default() {
  case "${1,,}" in
    true|yes|1|on) printf 'Y' ;;
    *) printf 'N' ;;
  esac
}

bool_enabled_disabled() {
  case "${1,,}" in
    true|yes|1|on) printf 'enabled' ;;
    *) printf 'disabled' ;;
  esac
}

csv_count() {
  local value="$1"
  [[ -n "$value" ]] || { printf '0'; return 0; }
  awk -v s="$value" 'BEGIN{n=split(s,a,","); c=0; for(i=1;i<=n;i++) if(a[i]!="") c++; print c+0}'
}

ddns_write_config() {
  local interval="${1:-$(ddns_config_value DDNS_REFRESH_INTERVAL "$DDNS_REFRESH_INTERVAL_DEFAULT")}"
  local refresh_forwards="${2:-$(ddns_config_value DDNS_REFRESH_FORWARDS "$DDNS_REFRESH_FORWARDS_DEFAULT")}"
  local refresh_entries="${3:-$(ddns_config_value DDNS_REFRESH_ENTRIES "$DDNS_REFRESH_ENTRIES_DEFAULT")}"
  local refresh_pbr="${4:-$(ddns_config_value DDNS_REFRESH_PBR "$DDNS_REFRESH_PBR_DEFAULT")}"
  local auto_apply="${5:-$(ddns_config_value DDNS_AUTO_APPLY "$DDNS_AUTO_APPLY_DEFAULT")}"
  local auto_fix="${6:-$(ddns_config_value DDNS_AUTO_FIX_ROUTE "$DDNS_AUTO_FIX_ROUTE_DEFAULT")}"
  local auto_sync_forward_pbr="${7:-$(ddns_config_value DDNS_AUTO_SYNC_FORWARD_PBR "$(ddns_config_value DDNS_AUTO_SYNC_PBR "$DDNS_AUTO_SYNC_FORWARD_PBR_DEFAULT")")}"
  local auto_sync_domain_pbr="${8:-$(ddns_config_value DDNS_AUTO_SYNC_DOMAIN_PBR "$DDNS_AUTO_SYNC_DOMAIN_PBR_DEFAULT")}"
  local entry_auto_restart="${9:-$(ddns_config_value DDNS_AUTO_RESTART_RELAY "$(ddns_config_value DDNS_ENTRY_AUTO_RESTART_RELAY "$DDNS_ENTRY_AUTO_RESTART_RELAY_DEFAULT")")}"
  local keep_old="${10:-$(ddns_config_value DDNS_KEEP_OLD_ON_FAIL "$DDNS_KEEP_OLD_ON_FAIL_DEFAULT")}"
  local public_ip_urls update_dns domains enabled auto_sync_pbr dns_servers dns_strategy dns_warn_on_split restart_cooldown change_confirm_count
  enabled="$(ddns_config_value DDNS_GLOBAL_ENABLED "$DDNS_GLOBAL_ENABLED_DEFAULT")"
  domains="$(ddns_config_value DDNS_GLOBAL_DOMAINS "")"
  public_ip_urls="$(ddns_config_value PUBLIC_IP_CHECK_URLS "$PUBLIC_IP_CHECK_URLS_DEFAULT")"
  dns_servers="$(ddns_config_value DNS_RESOLVE_SERVERS "$DNS_RESOLVE_SERVERS_DEFAULT")"
  dns_strategy="$(normalize_dns_resolve_strategy "$(ddns_config_value DNS_RESOLVE_STRATEGY "$DNS_RESOLVE_STRATEGY_DEFAULT")")"
  dns_warn_on_split="$(ddns_config_value DNS_RESOLVE_WARN_ON_SPLIT "$DNS_RESOLVE_WARN_ON_SPLIT_DEFAULT")"
  auto_sync_pbr="$(ddns_config_value DDNS_AUTO_SYNC_PBR "$DDNS_AUTO_SYNC_PBR_DEFAULT")"
  update_dns="$(ddns_config_value DDNS_UPDATE_DNS_RECORD "$DDNS_UPDATE_DNS_RECORD_DEFAULT")"
  restart_cooldown="$(ddns_config_value DDNS_RESTART_RELAY_COOLDOWN "$DDNS_RESTART_RELAY_COOLDOWN_DEFAULT")"
  change_confirm_count="$(ddns_config_value DDNS_CHANGE_CONFIRM_COUNT "$DDNS_CHANGE_CONFIRM_COUNT_DEFAULT")"
  write_file "$DDNS_CONFIG" "DDNS_GLOBAL_ENABLED=${enabled}
DDNS_GLOBAL_INTERVAL=${interval}
DDNS_GLOBAL_DOMAINS=${domains}
PUBLIC_IP_CHECK_URLS=${public_ip_urls}
DNS_RESOLVE_SERVERS=${dns_servers}
DNS_RESOLVE_STRATEGY=${dns_strategy}
DNS_RESOLVE_WARN_ON_SPLIT=${dns_warn_on_split}
DDNS_AUTO_APPLY=${auto_apply}
DDNS_AUTO_SYNC_PBR=${auto_sync_pbr}
DDNS_AUTO_RESTART_RELAY=${entry_auto_restart}
DDNS_RESTART_RELAY_COOLDOWN=${restart_cooldown}
DDNS_CHANGE_CONFIRM_COUNT=${change_confirm_count}
DDNS_KEEP_OLD_ON_FAIL=${keep_old}
DDNS_UPDATE_DNS_RECORD=${update_dns}
DDNS_REFRESH_INTERVAL=${interval}
DDNS_REFRESH_FORWARDS=${refresh_forwards}
DDNS_REFRESH_ENTRIES=${refresh_entries}
DDNS_REFRESH_PBR=${refresh_pbr}
DDNS_AUTO_FIX_ROUTE=${auto_fix}
DDNS_AUTO_SYNC_FORWARD_PBR=${auto_sync_forward_pbr}
DDNS_AUTO_SYNC_DOMAIN_PBR=${auto_sync_domain_pbr}
DDNS_ENTRY_AUTO_RESTART_RELAY=${entry_auto_restart}
DDNS_KEEP_OLD_ON_FAIL=${keep_old}" 600
}

ddns_ensure_config() {
  if [[ ! -f "$DDNS_CONFIG" ]]; then
    ddns_write_config "$DDNS_REFRESH_INTERVAL_DEFAULT" "$DDNS_REFRESH_FORWARDS_DEFAULT" "$DDNS_REFRESH_ENTRIES_DEFAULT" "$DDNS_REFRESH_PBR_DEFAULT" "$DDNS_AUTO_APPLY_DEFAULT" "$DDNS_AUTO_FIX_ROUTE_DEFAULT" "$DDNS_AUTO_SYNC_FORWARD_PBR_DEFAULT" "$DDNS_AUTO_SYNC_DOMAIN_PBR_DEFAULT" "$DDNS_ENTRY_AUTO_RESTART_RELAY_DEFAULT" "$DDNS_KEEP_OLD_ON_FAIL_DEFAULT"
    return 0
  fi
  if ! grep -q '^DDNS_GLOBAL_ENABLED=' "$DDNS_CONFIG" 2>/dev/null ||
    ! grep -q '^DDNS_GLOBAL_INTERVAL=' "$DDNS_CONFIG" 2>/dev/null ||
    ! grep -q '^PUBLIC_IP_CHECK_URLS=' "$DDNS_CONFIG" 2>/dev/null ||
    ! grep -q '^DNS_RESOLVE_SERVERS=' "$DDNS_CONFIG" 2>/dev/null ||
    ! grep -q '^DNS_RESOLVE_STRATEGY=' "$DDNS_CONFIG" 2>/dev/null ||
    ! grep -q '^DNS_RESOLVE_WARN_ON_SPLIT=' "$DDNS_CONFIG" 2>/dev/null ||
    ! grep -q '^DDNS_AUTO_SYNC_PBR=' "$DDNS_CONFIG" 2>/dev/null ||
    ! grep -q '^DDNS_AUTO_RESTART_RELAY=' "$DDNS_CONFIG" 2>/dev/null ||
    ! grep -q '^DDNS_RESTART_RELAY_COOLDOWN=' "$DDNS_CONFIG" 2>/dev/null ||
    ! grep -q '^DDNS_CHANGE_CONFIRM_COUNT=' "$DDNS_CONFIG" 2>/dev/null ||
    ! grep -q '^DDNS_UPDATE_DNS_RECORD=' "$DDNS_CONFIG" 2>/dev/null ||
    ! grep -q '^DDNS_REFRESH_FORWARDS=' "$DDNS_CONFIG" 2>/dev/null ||
    ! grep -q '^DDNS_REFRESH_ENTRIES=' "$DDNS_CONFIG" 2>/dev/null ||
    ! grep -q '^DDNS_REFRESH_PBR=' "$DDNS_CONFIG" 2>/dev/null ||
    ! grep -q '^DDNS_AUTO_SYNC_FORWARD_PBR=' "$DDNS_CONFIG" 2>/dev/null ||
    ! grep -q '^DDNS_AUTO_SYNC_DOMAIN_PBR=' "$DDNS_CONFIG" 2>/dev/null ||
    ! grep -q '^DDNS_ENTRY_AUTO_RESTART_RELAY=' "$DDNS_CONFIG" 2>/dev/null; then
    ddns_write_config
  fi
}

ddns_emit() {
  local level="$1" msg="$2" line
  case "$level" in
    OK) line="[OK] ${msg}" ;;
    WARN) line="[WARN] ${msg}" ;;
    FAIL) line="[FAIL] ${msg}" ;;
    *) line="[INFO] ${msg}" ;;
  esac
  echo "$line"
  if (( DRY_RUN == 0 )) && (( LOG_DISABLED == 0 )) && [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    mkdir -p "$(dirname "$DDNS_LOG_FILE")" 2>/dev/null || true
    printf '[%s] %s\n' "$(status_now)" "$line" >>"$DDNS_LOG_FILE" 2>/dev/null || true
  fi
}

ddns_log_quiet() {
  local level="$1" msg="$2" line
  case "$level" in
    OK) line="[OK] ${msg}" ;;
    WARN) line="[WARN] ${msg}" ;;
    FAIL) line="[FAIL] ${msg}" ;;
    *) line="[INFO] ${msg}" ;;
  esac
  if (( DRY_RUN == 0 )) && (( LOG_DISABLED == 0 )) && [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    mkdir -p "$(dirname "$DDNS_LOG_FILE")" 2>/dev/null || true
    printf '[%s] %s\n' "$(status_now)" "$line" >>"$DDNS_LOG_FILE" 2>/dev/null || true
  fi
}

ddns_output_line() {
  local line="$1"
  echo "$line"
  if (( DRY_RUN == 0 )) && (( LOG_DISABLED == 0 )) && [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    mkdir -p "$(dirname "$DDNS_LOG_FILE")" 2>/dev/null || true
    printf '[%s] %s\n' "$(status_now)" "$line" >>"$DDNS_LOG_FILE" 2>/dev/null || true
  fi
}

ddns_action_text() {
  local value="$1" done_text="$2" pending_text="$3" idle_text="$4"
  case "${value,,}" in
    true|yes|1|on) printf '%s' "$done_text" ;;
    needed|need|pending) printf '%s' "$pending_text" ;;
    *) printf '%s' "$idle_text" ;;
  esac
}

ddns_print_summary() {
  local result="$1"
  ddns_output_line ""
  ddns_output_line "域名解析变化检测摘要"
  ddns_output_line "----------------------------------------"
  ddns_output_line "辅助公网 IP: ${DDNS_PUBLIC_IP:-未检测}"
  ddns_output_line "辅助公网 IP 检测源: ${DDNS_PUBLIC_IP_SOURCE:-"-"}"
  ddns_output_line ""
  ddns_output_line "后端转发："
  ddns_output_line "- 检查 ${DDNS_FORWARD_CHECKED}"
  ddns_output_line "- 域名 ${DDNS_FORWARD_DOMAIN_COUNT}"
  ddns_output_line "- 变化 ${DDNS_FORWARD_CHANGED_COUNT}"
  ddns_output_line "- 失败 ${DDNS_FORWARD_FAILED_COUNT}"
  ddns_output_line ""
  ddns_output_line "公网入口："
  if (( DDNS_ENTRY_DOMAIN_COUNT == 0 )); then
    ddns_output_line "- 域名入口 0"
    ddns_output_line "- 无需刷新"
  else
    ddns_output_line "- 检查 ${DDNS_ENTRY_CHECKED}"
    ddns_output_line "- 域名入口 ${DDNS_ENTRY_DOMAIN_COUNT}"
    ddns_output_line "- 变化 ${DDNS_ENTRY_CHANGED_COUNT}"
    ddns_output_line "- 失败 ${DDNS_ENTRY_FAILED_COUNT}"
  fi
  ddns_output_line ""
  ddns_output_line "域名 PBR："
  if (( DDNS_PBR_DOMAIN_COUNT == 0 )); then
    ddns_output_line "- 未配置"
  else
    ddns_output_line "- 检查 ${DDNS_PBR_DOMAIN_COUNT}"
    ddns_output_line "- 变化 ${DDNS_PBR_CHANGED_COUNT}"
    ddns_output_line "- 失败 ${DDNS_PBR_FAILED_COUNT}"
  fi
  ddns_output_line ""
  ddns_output_line "系统动作："
  ddns_output_line "- nftables：$(ddns_action_text "$DDNS_NFT_APPLIED" "已重应用" "待重应用" "无需重应用")"
  ddns_output_line "- PBR：$(ddns_action_text "$DDNS_PBR_APPLIED" "已应用" "待应用" "无需应用")"
  if [[ "$DDNS_RELAY_RESTARTED" == "true" ]]; then
    ddns_output_line "- relay：已重启"
  elif [[ "$DDNS_RELAY_RESTART_NEEDED" == "true" ]]; then
    ddns_output_line "- relay：pending"
  else
    ddns_output_line "- relay：无需重启"
  fi
  ddns_output_line ""
  ddns_output_line "结果："
  ddns_output_line "- DDNS 状态：$(status_result_display "$result")"
}

ddns_entry_report_append() {
  local name="$1" host="$2" old_ip="$3" new_ip="$4" state="$5" restart_needed="$6" block
  printf -v block '%s:\n- 域名: %s\n- 上次解析: %s\n- 当前解析: %s\n- 状态: %s\n- relay restart needed: %s' \
    "$name" "$host" "${old_ip:-none}" "${new_ip:-none}" "$state" "$restart_needed"
  DDNS_ENTRY_REPORT_BLOCKS="${DDNS_ENTRY_REPORT_BLOCKS}${DDNS_ENTRY_REPORT_BLOCKS:+$'\n'}${block}"
}

ddns_entry_recent_event_append() {
  local name="$1" old_ip="$2" new_ip="$3" kind="$4" line
  case "$kind" in
    initial) line="${name}: 初次记录 ${new_ip}" ;;
    *) line="${name}: ${old_ip:-none} -> ${new_ip}" ;;
  esac
  DDNS_ENTRY_RECENT_EVENTS="${DDNS_ENTRY_RECENT_EVENTS}${DDNS_ENTRY_RECENT_EVENTS:+;}${line}"
}

ddns_forward_recent_event_append() {
  local name="$1" old_ip="$2" new_ip="$3" kind="$4" line
  case "$kind" in
    initial) line="${name}: 初次记录 ${new_ip}" ;;
    *) line="${name}: ${old_ip:-none} -> ${new_ip}" ;;
  esac
  DDNS_FORWARD_RECENT_EVENTS="${DDNS_FORWARD_RECENT_EVENTS}${DDNS_FORWARD_RECENT_EVENTS:+;}${line}"
}

ddns_pbr_recent_event_append() {
  local name="$1" old_ip="$2" new_ip="$3" kind="$4" line
  case "$kind" in
    initial) line="${name}: 初次记录 ${new_ip}" ;;
    *) line="${name}: ${old_ip:-none} -> ${new_ip}" ;;
  esac
  DDNS_PBR_RECENT_EVENTS="${DDNS_PBR_RECENT_EVENTS}${DDNS_PBR_RECENT_EVENTS:+;}${line}"
}

ddns_print_entry_detection_section() {
  local line
  ddns_output_line ""
  ddns_output_line "公网入口 DDNS 检测"
  ddns_output_line "----------------------------------------"
  if [[ -n "${DDNS_ENTRY_REPORT_BLOCKS:-}" ]]; then
    while IFS= read -r line; do
      ddns_output_line "$line"
    done <<<"$DDNS_ENTRY_REPORT_BLOCKS"
  else
    ddns_output_line "域名入口: ${DDNS_ENTRY_DOMAIN_COUNT}"
    ddns_output_line "变化: ${DDNS_ENTRY_CHANGED_COUNT}"
    ddns_output_line "失败: ${DDNS_ENTRY_FAILED_COUNT}"
    ddns_output_line "relay restart needed: $(bool_yes_no "$DDNS_RELAY_RESTART_NEEDED")"
  fi
}

ddns_write_last_status() {
  local result="$1" scope="$2"
  local forward_changed="$3" forward_failed="$4" entry_changed="$5" entry_failed="$6" pbr_changed="$7" pbr_failed="$8"
  local relay_restart_needed="$9" nft_applied="${10}" pbr_applied="${11}" relay_restarted="${12}"
  local public_ip="${13:-${DDNS_PUBLIC_IP:-}}" public_ip_source="${14:-${DDNS_PUBLIC_IP_SOURCE:-}}"
  local dns_strategy dns_servers dns_split dns_incomplete dns_split_domain dns_split_results dns_selected_ip dns_selected_source
  local entry_recent entry_action forward_recent forward_action pbr_recent pbr_action relay_restarted_at
  dns_strategy="$(normalize_dns_resolve_strategy "$(ddns_config_value DNS_RESOLVE_STRATEGY "$DNS_RESOLVE_STRATEGY_DEFAULT")")"
  dns_servers="$(ddns_config_value DNS_RESOLVE_SERVERS "$DNS_RESOLVE_SERVERS_DEFAULT")"
  dns_split="${DDNS_DNS_SPLIT_DETECTED:-false}"
  dns_incomplete="${DDNS_DNS_INCOMPLETE_DETECTED:-false}"
  dns_split_domain="${DDNS_DNS_SPLIT_DOMAIN:-}"
  dns_split_results="${DDNS_DNS_SPLIT_RESULTS:-}"
  dns_selected_ip="${DDNS_DNS_SPLIT_SELECTED_IP:-}"
  dns_selected_source="${DDNS_DNS_SPLIT_SELECTED_SOURCE:-}"
  entry_recent="${DDNS_ENTRY_RECENT_EVENTS:-}"
  entry_action="${DDNS_ENTRY_RECENT_ACTION:-}"
  forward_recent="${DDNS_FORWARD_RECENT_EVENTS:-}"
  forward_action="${DDNS_FORWARD_RECENT_ACTION:-}"
  pbr_recent="${DDNS_PBR_RECENT_EVENTS:-}"
  pbr_action="${DDNS_PBR_RECENT_ACTION:-}"
  relay_restarted_at="${DDNS_RELAY_RESTARTED_AT:-$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RELAY_RESTARTED_AT)}"
  (( DRY_RUN == 1 )) && return 0
  [[ ${EUID:-$(id -u)} -eq 0 ]] || return 0
  mkdir -p "$STATUS_DIR" 2>/dev/null || return 0
  {
    printf 'LAST_DDNS_TIME=%s\n' "$(status_now)"
    printf 'LAST_DDNS_RESULT=%s\n' "$result"
    printf 'LAST_DDNS_SCOPE=%s\n' "$scope"
    printf 'LAST_DDNS_PUBLIC_IP=%s\n' "$public_ip"
    printf 'LAST_DDNS_PUBLIC_IP_SOURCE=%s\n' "$public_ip_source"
    printf 'LAST_DDNS_FORWARD_CHANGED=%s\n' "$forward_changed"
    printf 'LAST_DDNS_FORWARD_FAILED=%s\n' "$forward_failed"
    printf 'LAST_DDNS_FORWARD_CHECKED=%s\n' "$DDNS_FORWARD_DOMAIN_COUNT"
    printf 'LAST_DDNS_FORWARD_FAILED_COUNT=%s\n' "$DDNS_FORWARD_FAILED_COUNT"
    printf 'LAST_DDNS_ENTRY_CHANGED=%s\n' "$entry_changed"
    printf 'LAST_DDNS_ENTRY_FAILED=%s\n' "$entry_failed"
    printf 'LAST_DDNS_ENTRY_CHECKED=%s\n' "$DDNS_ENTRY_DOMAIN_COUNT"
    printf 'LAST_DDNS_ENTRY_FAILED_COUNT=%s\n' "$DDNS_ENTRY_FAILED_COUNT"
    printf 'LAST_DDNS_PBR_CHANGED=%s\n' "$pbr_changed"
    printf 'LAST_DDNS_PBR_FAILED=%s\n' "$pbr_failed"
    printf 'LAST_DDNS_PBR_CHECKED=%s\n' "$DDNS_PBR_DOMAIN_COUNT"
    printf 'LAST_DDNS_PBR_FAILED_COUNT=%s\n' "$DDNS_PBR_FAILED_COUNT"
    printf 'LAST_DDNS_GLOBAL_DOMAIN_CHECKED=%s\n' "$DDNS_GLOBAL_DOMAIN_COUNT"
    printf 'LAST_DDNS_GLOBAL_DOMAIN_CHANGED_COUNT=%s\n' "$DDNS_GLOBAL_CHANGED_COUNT"
    printf 'LAST_DDNS_GLOBAL_DOMAIN_FAILED_COUNT=%s\n' "$DDNS_GLOBAL_FAILED_COUNT"
    printf 'LAST_DDNS_RELAY_RESTART_NEEDED=%s\n' "$relay_restart_needed"
    printf 'LAST_DDNS_NFT_APPLIED=%s\n' "$nft_applied"
    printf 'LAST_DDNS_PBR_APPLIED=%s\n' "$pbr_applied"
    printf 'LAST_DDNS_RELAY_RESTARTED=%s\n' "$relay_restarted"
    printf 'LAST_DDNS_DNS_STRATEGY=%s\n' "$dns_strategy"
    printf 'LAST_DDNS_DNS_SERVERS=%s\n' "$dns_servers"
    printf 'LAST_DDNS_DNS_SPLIT_DETECTED=%s\n' "$dns_split"
    printf 'LAST_DDNS_DNS_INCOMPLETE_DETECTED=%s\n' "$dns_incomplete"
    printf 'LAST_DDNS_DNS_SPLIT_DOMAIN=%s\n' "$dns_split_domain"
    printf 'LAST_DDNS_DNS_SPLIT_RESULTS=%s\n' "$dns_split_results"
    printf 'LAST_DDNS_DNS_SELECTED_IP=%s\n' "$dns_selected_ip"
    printf 'LAST_DDNS_DNS_SELECTED_SOURCE=%s\n' "$dns_selected_source"
    printf 'LAST_DDNS_ENTRY_RECENT_EVENTS=%s\n' "$entry_recent"
    printf 'LAST_DDNS_ENTRY_RECENT_ACTION=%s\n' "$entry_action"
    printf 'LAST_DDNS_FORWARD_RECENT_EVENTS=%s\n' "$forward_recent"
    printf 'LAST_DDNS_FORWARD_RECENT_ACTION=%s\n' "$forward_action"
    printf 'LAST_DDNS_PBR_RECENT_EVENTS=%s\n' "$pbr_recent"
    printf 'LAST_DDNS_PBR_RECENT_ACTION=%s\n' "$pbr_action"
    printf 'LAST_DDNS_RELAY_RESTARTED_AT=%s\n' "$relay_restarted_at"
    printf 'LAST_DDNS_RELAY_RESTART_SKIPPED_COOLDOWN=%s\n' "${DDNS_RELAY_RESTART_SKIPPED_COOLDOWN:-false}"
    printf 'LAST_DDNS_VERSION=%s\n' "$TOOL_VERSION"
  } >"$DDNS_STATUS_FILE"
  chmod 600 "$DDNS_STATUS_FILE" 2>/dev/null || true
}

ddns_domain_forward_count() {
  forwards_rows | awk -F'\t' '
    $7=="true" && $3 !~ /^([0-9]{1,3}\.){3}[0-9]{1,3}$/ && $3 ~ /[A-Za-z]/ { c++ }
    END { print c+0 }
  '
}

ddns_domain_entry_count() {
  entries_rows | awk -F'\t' '
    $7=="true" && $2 !~ /^([0-9]{1,3}\.){3}[0-9]{1,3}$/ && $2 ~ /[A-Za-z]/ { c++ }
    END { print c+0 }
  '
}

ddns_domain_pbr_count() {
  pbr_domain_rows | awk -F'\t' '$4=="true"{c++} END{print c+0}'
}

last_resolved_ip_for_entry() {
  local name="$1"
  resolved_entries_rows | awk -F'\t' -v n="$name" '$1==n && $3!="" {print $3; exit}'
}

last_resolved_changed_for_entry() {
  local name="$1"
  resolved_entries_rows | awk -F'\t' -v n="$name" '$1==n && $5!="" {print $5; exit}'
}

last_resolved_ip_for_global_domain() {
  local host="$1"
  [[ -f "$DDNS_GLOBAL_RESOLVED_TSV" ]] || return 0
  awk -F'\t' -v h="$host" '$1==h && $2!="" {print $2; exit}' "$DDNS_GLOBAL_RESOLVED_TSV"
}

last_resolved_changed_for_global_domain() {
  local host="$1"
  [[ -f "$DDNS_GLOBAL_RESOLVED_TSV" ]] || return 0
  awk -F'\t' -v h="$host" '$1==h && $4!="" {print $4; exit}' "$DDNS_GLOBAL_RESOLVED_TSV"
}

ddns_global_domain_list() {
  local value host
  local -a _ddns_global_domain_items
  value="$(ddns_config_value DDNS_GLOBAL_DOMAINS "")"
  value="${value//$'\n'/,}"
  value="${value//$'\r'/,}"
  IFS=',' read -ra _ddns_global_domain_items <<<"$value"
  for host in "${_ddns_global_domain_items[@]}"; do
    host="$(trim_spaces "$host")"
    [[ -n "$host" ]] && printf '%s\n' "$host"
  done
}

ddns_scope_requested() {
  local scope="$1" wanted="$2"
  [[ "$scope" == "all" || "$scope" == "$wanted" ]]
}

ddns_scope_enabled() {
  local key="$1" default="$2"
  ddns_config_bool "$key" "$default"
}

ddns_timer_state() {
  local timer_state
  timer_state="$(systemd_active_state "${DDNS_SERVICE_NAME}.timer" 2>/dev/null || true)"
  [[ -n "$timer_state" ]] || timer_state="disabled"
  [[ "$timer_state" == "inactive" ]] && timer_state="disabled"
  printf '%s' "$timer_state"
}

ddns_timer_next_run() {
  local unit="${DDNS_SERVICE_NAME}.timer" value
  command -v systemctl >/dev/null 2>&1 || { printf 'unknown'; return 0; }
  value="$(systemctl show "$unit" -p NextElapseUSecRealtime --value 2>/dev/null || true)"
  if [[ -n "$value" && "$value" != "n/a" && "$value" != "0" ]]; then
    printf '%s' "$value"
    return 0
  fi
  value="$(systemctl list-timers "$unit" --no-legend --no-pager 2>/dev/null | awk 'NF {print $1" "$2" "$3" "$4; exit}' || true)"
  [[ -n "$value" ]] && { printf '%s' "$value"; return 0; }
  printf 'unknown'
}

ddns_auto_snapshot() {
  local dest
  need_root_unless_dry_run
  dest="${AUTO_SNAPSHOT_DIR}/auto-before-ddns-apply-$(snapshot_timestamp).tar.gz"
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] create auto snapshot ${dest}"
    return 0
  fi
  ensure_base_dirs
  if create_snapshot_archive "$dest"; then
    ddns_emit OK "已创建 DDNS 自动快照：${dest}"
    prune_auto_snapshots
    return 0
  fi
  ddns_emit WARN "DDNS 自动快照创建失败，跳过自动应用。"
  return 1
}

ddns_refresh_forwards_scope() {
  validate_forwards_tsv >/dev/null || { DDNS_FORWARD_FAILED="forwards.tsv"; return 1; }
  local content resolved_at name entry_port target_host target_port out_iface route_table enabled comment
  local old_ip target_ip forward_count=0 domain_count=0 changed_count=0 failed_count=0
  resolved_at="$(status_now)"
  content=$'# name\tentry_port\ttarget_host\tresolved_ip\ttarget_port\tout_iface\troute_table\tenabled\tlast_resolved_at\tcomment'
  while IFS=$'\034' read -r name entry_port target_host target_port out_iface route_table enabled comment; do
    forward_count=$((forward_count + 1))
    old_ip="$(last_resolved_ip_for_forward "$name")"
    target_ip=""
    if is_ipv4 "$target_host"; then
      target_ip="$target_host"
    elif [[ "$enabled" == "true" ]] && is_domain_name "$target_host"; then
      domain_count=$((domain_count + 1))
      if resolve_domain_ipv4_multi "$target_host"; then
        target_ip="$RESOLVE_SELECTED_IP"
      else
        target_ip=""
      fi
      if [[ -z "$target_ip" ]]; then
        failed_count=$((failed_count + 1))
        DDNS_FORWARD_FAILED="${DDNS_FORWARD_FAILED:+${DDNS_FORWARD_FAILED},}${name}"
        if [[ -n "$old_ip" ]]; then
          ddns_emit WARN "转发目标 ${name} 解析失败，保留旧 IP：${old_ip}"
          target_ip="$old_ip"
        else
          ddns_emit WARN "转发目标 ${name} 解析失败，且没有旧 IP：${target_host}"
          continue
        fi
      elif [[ -n "$old_ip" && "$old_ip" == "$target_ip" ]]; then
        ddns_emit OK "转发目标 ${name} 解析未变化：${target_ip}"
      else
        changed_count=$((changed_count + 1))
        DDNS_FORWARD_CHANGED="${DDNS_FORWARD_CHANGED:+${DDNS_FORWARD_CHANGED},}${name}"
        DDNS_FORWARD_NEED_APPLY=1
        ddns_emit WARN "转发目标 ${name} 解析变化：${old_ip:-none} -> ${target_ip}"
        if [[ -z "$old_ip" ]]; then
          ddns_forward_recent_event_append "$name" "" "$target_ip" "initial"
        else
          ddns_forward_recent_event_append "$name" "$old_ip" "$target_ip" "changed"
        fi
        if [[ -n "$route_table" && "$route_table" != "-" ]]; then
          DDNS_FORWARD_PBR_NEED_SYNC=1
          if ! ddns_config_bool DDNS_AUTO_SYNC_FORWARD_PBR "$(ddns_config_value DDNS_AUTO_SYNC_PBR "$DDNS_AUTO_SYNC_FORWARD_PBR_DEFAULT")"; then
            ddns_emit INFO "转发目标 ${name} 的 IP 已变化，PBR 可能需要同步。"
            ddns_emit INFO "可执行：lq pbr sync-from-forwards"
          fi
        fi
      fi
    else
      target_ip="$old_ip"
      if [[ -z "$target_ip" ]] && is_domain_name "$target_host"; then
        if resolve_domain_ipv4_multi "$target_host" >/dev/null; then
          target_ip="$RESOLVE_SELECTED_IP"
        else
          target_ip=""
        fi
      fi
    fi
    [[ -n "$target_ip" ]] || continue
    content="${content}"$'\n'"${name}"$'\t'"${entry_port}"$'\t'"${target_host}"$'\t'"${target_ip}"$'\t'"${target_port}"$'\t'"${out_iface}"$'\t'"${route_table}"$'\t'"${enabled}"$'\t'"${resolved_at}"$'\t'"${comment}"
  done < <(forwards_rows_usv)
  write_file "$RESOLVED_TSV" "$content" 600
  DDNS_FORWARD_CHECKED="$forward_count"
  DDNS_FORWARD_DOMAIN_COUNT="$domain_count"
  DDNS_FORWARD_CHANGED_COUNT="$changed_count"
  DDNS_FORWARD_FAILED_COUNT="$failed_count"
  return 0
}

ddns_refresh_entries_scope() {
  local content checked_at name public_host et_ip proto port weight enabled old_ip new_ip old_changed last_changed
  local entry_count=0 domain_count=0 changed_count=0 failed_count=0
  checked_at="$(status_now)"
  content=$'# name\tpublic_host\tresolved_ip\tlast_checked\tlast_changed'
  while IFS=$'\t' read -r name public_host et_ip proto port weight enabled; do
    if is_domain_name "$public_host"; then
      old_ip="$(last_resolved_ip_for_entry "$name")"
      old_changed="$(last_resolved_changed_for_entry "$name")"
      if [[ "$enabled" == "true" ]]; then
        entry_count=$((entry_count + 1))
        domain_count=$((domain_count + 1))
        if resolve_domain_ipv4_multi "$public_host"; then
          new_ip="$RESOLVE_SELECTED_IP"
        else
          new_ip=""
        fi
        if [[ -z "$new_ip" ]]; then
          failed_count=$((failed_count + 1))
          DDNS_ENTRY_FAILED="${DDNS_ENTRY_FAILED:+${DDNS_ENTRY_FAILED},}${name}"
          ddns_entry_report_append "$name" "$public_host" "$old_ip" "" "failed" "no"
          if [[ -n "$old_ip" ]]; then
            ddns_emit WARN "公网入口 ${name} 解析失败，保留旧 IP：${old_ip}"
            new_ip="$old_ip"
            last_changed="${old_changed:-$checked_at}"
          else
            ddns_emit WARN "公网入口 ${name} 解析失败，且没有旧 IP：${public_host}"
            continue
          fi
        elif [[ -z "$old_ip" ]]; then
          ddns_emit OK "公网入口 ${name} 解析已记录：${new_ip}"
          ddns_entry_recent_event_append "$name" "" "$new_ip" "initial"
          last_changed="$checked_at"
        elif [[ "$old_ip" == "$new_ip" ]]; then
          ddns_emit OK "公网入口 ${name} 解析未变化：${new_ip}"
          last_changed="${old_changed:-$checked_at}"
        else
          changed_count=$((changed_count + 1))
          DDNS_ENTRY_CHANGED="${DDNS_ENTRY_CHANGED:+${DDNS_ENTRY_CHANGED},}${name}"
          DDNS_RELAY_RESTART_NEEDED=true
          last_changed="$checked_at"
          ddns_emit WARN "公网入口 ${name} 解析变化：${old_ip:-none} -> ${new_ip}"
          ddns_entry_recent_event_append "$name" "$old_ip" "$new_ip" "changed"
          ddns_entry_report_append "$name" "$public_host" "$old_ip" "$new_ip" "changed" "yes"
        fi
      else
        new_ip="${old_ip:-}"
        last_changed="${old_changed:-}"
      fi
      [[ -n "$new_ip" ]] || continue
      content="${content}"$'\n'"${name}"$'\t'"${public_host}"$'\t'"${new_ip}"$'\t'"${checked_at}"$'\t'"${last_changed}"
    fi
  done < <(entries_rows)
  write_file "$RESOLVED_ENTRIES_TSV" "$content" 600
  DDNS_ENTRY_CHECKED="$entry_count"
  DDNS_ENTRY_DOMAIN_COUNT="$domain_count"
  DDNS_ENTRY_CHANGED_COUNT="$changed_count"
  DDNS_ENTRY_FAILED_COUNT="$failed_count"
}

ddns_refresh_global_domains_scope() {
  local checked_at host old_ip new_ip old_changed last_changed content domain_count=0 changed_count=0 failed_count=0
  checked_at="$(status_now)"
  content=$'# host\tresolved_ip\tlast_checked\tlast_changed'
  while IFS= read -r host; do
    [[ -n "$host" ]] || continue
    is_domain_name "$host" || { ddns_emit WARN "DDNS_GLOBAL_DOMAINS 中的值不是域名：${host}"; continue; }
    domain_count=$((domain_count + 1))
    old_ip="$(last_resolved_ip_for_global_domain "$host")"
    old_changed="$(last_resolved_changed_for_global_domain "$host")"
    if resolve_domain_ipv4_multi "$host"; then
      new_ip="$RESOLVE_SELECTED_IP"
    else
      new_ip=""
    fi
    if [[ -z "$new_ip" ]]; then
      failed_count=$((failed_count + 1))
      if [[ -n "$old_ip" ]]; then
        ddns_emit WARN "全局域名 ${host} 解析失败，保留旧 IP：${old_ip}"
        new_ip="$old_ip"
        last_changed="${old_changed:-$checked_at}"
      else
        ddns_emit WARN "全局域名 ${host} 解析失败，且没有旧 IP。"
        continue
      fi
    elif [[ -z "$old_ip" ]]; then
      ddns_emit OK "全局域名 ${host} 解析已记录：${new_ip}"
      last_changed="$checked_at"
    elif [[ "$old_ip" == "$new_ip" ]]; then
      ddns_emit OK "全局域名 ${host} 解析未变化：${new_ip}"
      last_changed="${old_changed:-$checked_at}"
    else
      changed_count=$((changed_count + 1))
      ddns_emit WARN "全局域名 ${host} 解析变化：${old_ip:-none} -> ${new_ip}"
      last_changed="$checked_at"
    fi
    content="${content}"$'\n'"${host}"$'\t'"${new_ip}"$'\t'"${checked_at}"$'\t'"${last_changed}"
  done < <(ddns_global_domain_list)
  write_file "$DDNS_GLOBAL_RESOLVED_TSV" "$content" 600
  DDNS_GLOBAL_DOMAIN_COUNT="$domain_count"
  DDNS_GLOBAL_CHANGED_COUNT="$changed_count"
  DDNS_GLOBAL_FAILED_COUNT="$failed_count"
}

ddns_now_epoch() {
  if [[ "${LQ_TEST_NOW_EPOCH:-}" =~ ^[0-9]+$ ]]; then
    printf '%s' "$LQ_TEST_NOW_EPOCH"
  else
    date +%s
  fi
}

ddns_format_epoch() {
  local epoch="$1"
  [[ "$epoch" =~ ^[0-9]+$ ]] || { printf '%s' "$epoch"; return 0; }
  date -d "@${epoch}" '+%F %T' 2>/dev/null ||
    date -r "$epoch" '+%F %T' 2>/dev/null ||
    printf '%s' "$epoch"
}

ddns_relay_restart_cooldown_remaining() {
  local cooldown last now elapsed
  cooldown="$(ddns_config_value DDNS_RESTART_RELAY_COOLDOWN "$DDNS_RESTART_RELAY_COOLDOWN_DEFAULT")"
  [[ "$cooldown" =~ ^[0-9]+$ ]] || cooldown="$DDNS_RESTART_RELAY_COOLDOWN_DEFAULT"
  (( cooldown > 0 )) || { printf '0'; return 0; }
  last="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RELAY_RESTARTED_AT)"
  [[ "$last" =~ ^[0-9]+$ ]] || { printf '0'; return 0; }
  now="$(ddns_now_epoch)"
  elapsed=$((now - last))
  (( elapsed < 0 )) && elapsed=0
  if (( elapsed < cooldown )); then
    printf '%s' "$((cooldown - elapsed))"
  else
    printf '0'
  fi
}

ddns_note_relay_restarted() {
  DDNS_RELAY_RESTARTED=true
  DDNS_RELAY_RESTART_NEEDED=false
  DDNS_RELAY_RESTARTED_AT="$(ddns_now_epoch)"
}

ddns_maybe_restart_relay() {
  local non_interactive="$1" auto_restart default_answer cooldown_remaining
  [[ "$DDNS_RELAY_RESTART_NEEDED" == "true" ]] || return 0
  auto_restart="$(ddns_config_value DDNS_AUTO_RESTART_RELAY "$(ddns_config_value DDNS_ENTRY_AUTO_RESTART_RELAY "$DDNS_ENTRY_AUTO_RESTART_RELAY_DEFAULT")")"
  ddns_emit WARN "公网入口 ${DDNS_ENTRY_CHANGED} 的 DDNS 解析已变化。"
  ddns_emit WARN "EasyTier relay 可能需要重启才能重新解析 peer。"
  if (( non_interactive == 0 )) && is_interactive; then
    if [[ "${auto_restart,,}" == "true" || "${auto_restart,,}" == "yes" || "$auto_restart" == "1" || "${auto_restart,,}" == "on" ]]; then
      default_answer="Y"
      ddns_emit INFO "DDNS_AUTO_RESTART_RELAY=true"
      if prompt_yes_no "当前已允许自动重启 relay；是否现在重启 relay？" "$default_answer"; then
        ddns_auto_snapshot || warn "relay 重启前自动快照失败，将继续按用户确认操作。"
        if apply_easytier_relay_service confirmed-no-snapshot; then
          ddns_note_relay_restarted
          ddns_emit OK "已重启 relay。"
        else
          ddns_emit WARN "relay 重启失败，请稍后手动检查。"
          return 1
        fi
      else
        ddns_emit INFO "已记录公网入口 DDNS 变化，但未重启 relay。"
      fi
    elif prompt_yes_no "DDNS_AUTO_RESTART_RELAY=false；是否现在重启 relay？" "N"; then
      ddns_auto_snapshot || warn "relay 重启前自动快照失败，将继续按用户确认操作。"
      if apply_easytier_relay_service confirmed-no-snapshot; then
        ddns_note_relay_restarted
        ddns_emit OK "已重启 relay。"
      else
        ddns_emit WARN "relay 重启失败，请稍后手动检查。"
        return 1
      fi
    else
      ddns_emit INFO "已记录公网入口 DDNS 变化，但未重启 relay。"
      ddns_emit INFO "可在维护窗口执行：利群主机 -> EasyTier 组网管理 -> 启动 / 重启 relay 服务"
    fi
  elif ddns_config_bool DDNS_AUTO_RESTART_RELAY "$(ddns_config_value DDNS_ENTRY_AUTO_RESTART_RELAY "$DDNS_ENTRY_AUTO_RESTART_RELAY_DEFAULT")"; then
    ddns_emit INFO "非交互模式，DDNS_AUTO_RESTART_RELAY=true，正在自动重启 relay。"
    cooldown_remaining="$(ddns_relay_restart_cooldown_remaining)"
    if [[ "$cooldown_remaining" =~ ^[0-9]+$ ]] && (( cooldown_remaining > 0 )); then
      DDNS_RELAY_RESTART_SKIPPED_COOLDOWN=true
      ddns_emit WARN "relay 最近已自动重启，处于 cooldown，跳过本次自动重启。"
      return 0
    fi
    if ddns_auto_snapshot && apply_easytier_relay_service confirmed-no-snapshot; then
      ddns_note_relay_restarted
      ddns_emit OK "已自动重启 relay。"
    else
      ddns_emit WARN "relay 自动重启失败。"
      return 1
    fi
  else
    ddns_emit INFO "非交互模式，DDNS_AUTO_RESTART_RELAY=false，仅标记 relay restart needed。"
  fi
}

ddns_refresh_once() {
  need_root_unless_dry_run
  ensure_base_dirs
  ddns_ensure_config
  local scope="all" non_interactive=0 no_restart=0 arg ddns_lock="" result="ok" auto_apply auto_fix public_ip
  while (($# > 0)); do
    arg="$1"
    case "$arg" in
      --scope) scope="${2:-all}"; shift 2 ;;
      --global) scope="all"; shift ;;
      --non-interactive) non_interactive=1; shift ;;
      --no-restart) no_restart=1; shift ;;
      *) fail "未知 ddns run 参数：${arg}"; return 1 ;;
    esac
  done
  case "$scope" in
    all|forwards|entries|pbr) ;;
    *) fail "DDNS scope 无效：${scope}"; return 1 ;;
  esac
  DDNS_FORWARD_CHANGED=""; DDNS_FORWARD_FAILED=""; DDNS_ENTRY_CHANGED=""; DDNS_ENTRY_FAILED=""
  DDNS_PBR_CHANGED=""; DDNS_PBR_FAILED=""; DDNS_RELAY_RESTART_NEEDED=false
  DDNS_NFT_APPLIED=false; DDNS_PBR_APPLIED=false; DDNS_RELAY_RESTARTED=false
  DDNS_FORWARD_NEED_APPLY=0; DDNS_FORWARD_PBR_NEED_SYNC=0
  DDNS_ENTRY_REPORT_BLOCKS=""
  DDNS_ENTRY_RECENT_EVENTS=""
  DDNS_ENTRY_RECENT_ACTION=""
  DDNS_FORWARD_RECENT_EVENTS=""
  DDNS_FORWARD_RECENT_ACTION=""
  DDNS_PBR_RECENT_EVENTS=""
  DDNS_PBR_RECENT_ACTION=""
  DDNS_RELAY_RESTARTED_AT=""
  DDNS_RELAY_RESTART_SKIPPED_COOLDOWN=false
  DDNS_FORWARD_CHECKED=0; DDNS_FORWARD_DOMAIN_COUNT=0; DDNS_FORWARD_CHANGED_COUNT=0; DDNS_FORWARD_FAILED_COUNT=0
  DDNS_ENTRY_CHECKED=0; DDNS_ENTRY_DOMAIN_COUNT=0; DDNS_ENTRY_CHANGED_COUNT=0; DDNS_ENTRY_FAILED_COUNT=0
  DDNS_PBR_DOMAIN_COUNT=0; DDNS_PBR_CHANGED_COUNT=0; DDNS_PBR_FAILED_COUNT=0
  DDNS_GLOBAL_DOMAIN_COUNT=0; DDNS_GLOBAL_CHANGED_COUNT=0; DDNS_GLOBAL_FAILED_COUNT=0
  if ! lock_acquire "$DDNS_LOCK_PATH" "DDNS 刷新" ddns_lock; then
    ddns_emit INFO "DDNS 本轮跳过：已有任务运行。"
    ddns_emit INFO "持有任务：$(lock_owner_inline "$DDNS_LOCK_PATH" "DDNS 刷新")"
    ddns_emit INFO "下个 timer 周期会自动重试。"
    ddns_write_last_status "skipped" "$scope" "" "" "" "" "" "" false false false false
    return 0
  fi
  if ! global_lock_acquire; then
    ddns_emit INFO "DDNS 本轮跳过：已有任务运行。"
    ddns_emit INFO "持有任务：$(lock_owner_inline "$LEIKWAN_LOCK_PATH" "任务")"
    ddns_emit INFO "下个 timer 周期会自动重试。"
    lock_release "$ddns_lock"
    ddns_write_last_status "skipped" "$scope" "" "" "" "" "" "" false false false false
    return 0
  fi
  DDNS_DNS_SPLIT_DETECTED=false
  DDNS_DNS_INCOMPLETE_DETECTED=false
  DDNS_DNS_DIG_WARNED=false
  DDNS_DNS_SPLIT_DOMAIN=""
  DDNS_DNS_SPLIT_RESULTS=""
  DDNS_DNS_SPLIT_SELECTED_IP=""
  DDNS_DNS_SPLIT_SELECTED_SOURCE=""
  dnsutils_auto_install "ddns-run" "false" "ddns" || true
  ddns_emit INFO "域名解析变化检测开始，scope=${scope}。"
  if detect_public_ipv4 >/dev/null; then
    public_ip="$DDNS_PUBLIC_IP"
    ddns_emit OK "辅助公网 IP：${DDNS_PUBLIC_IP}（source=${DDNS_PUBLIC_IP_SOURCE:-unknown}）"
  else
    DDNS_PUBLIC_IP_FAILED=true
    ddns_emit WARN "本机公网 IP 检测失败，仅影响辅助状态；继续检测域名解析变化并保留现有配置。"
  fi
  auto_apply="$(ddns_config_value DDNS_AUTO_APPLY "$DDNS_AUTO_APPLY_DEFAULT")"
  auto_fix="$(ddns_config_value DDNS_AUTO_FIX_ROUTE "$DDNS_AUTO_FIX_ROUTE_DEFAULT")"
  if ddns_scope_requested "$scope" forwards; then
    if ddns_scope_enabled DDNS_REFRESH_FORWARDS "$DDNS_REFRESH_FORWARDS_DEFAULT"; then
      ddns_refresh_forwards_scope || result="fail"
    else
      ddns_emit INFO "forwards scope 已禁用。"
    fi
  fi
  if ddns_scope_requested "$scope" entries; then
    if ddns_scope_enabled DDNS_REFRESH_ENTRIES "$DDNS_REFRESH_ENTRIES_DEFAULT"; then
      ddns_refresh_entries_scope || result="warn"
    else
      ddns_emit INFO "entries scope 已禁用。"
    fi
  fi
  if ddns_scope_requested "$scope" pbr; then
    if ddns_scope_enabled DDNS_REFRESH_PBR "$DDNS_REFRESH_PBR_DEFAULT"; then
      DDNS_PBR_DOMAIN_COUNT="$(ddns_domain_pbr_count 2>/dev/null || printf '0')"
      if ddns_config_bool DDNS_AUTO_SYNC_PBR "$DDNS_AUTO_SYNC_PBR_DEFAULT" &&
        ddns_config_bool DDNS_AUTO_SYNC_DOMAIN_PBR "$DDNS_AUTO_SYNC_DOMAIN_PBR_DEFAULT"; then
        pbr_domain_sync --from-ddns || result="warn"
        [[ -n "$PBR_DOMAIN_SYNC_CHANGED_NAMES" ]] && DDNS_PBR_CHANGED="$PBR_DOMAIN_SYNC_CHANGED_NAMES"
        [[ -n "$PBR_DOMAIN_SYNC_FAILED_NAMES" ]] && DDNS_PBR_FAILED="$PBR_DOMAIN_SYNC_FAILED_NAMES"
        [[ -n "${PBR_DOMAIN_SYNC_RECENT_EVENTS:-}" ]] && DDNS_PBR_RECENT_EVENTS="$PBR_DOMAIN_SYNC_RECENT_EVENTS"
        DDNS_PBR_CHANGED_COUNT="$(csv_count "$DDNS_PBR_CHANGED")"
        DDNS_PBR_FAILED_COUNT="$(csv_count "$DDNS_PBR_FAILED")"
      else
        ddns_emit INFO "DDNS_AUTO_SYNC_PBR=false 或 DDNS_AUTO_SYNC_DOMAIN_PBR=false，刷新域名 PBR 缓存但不自动同步规则。"
        pbr_domain_refresh_cache_only || result="warn"
      fi
    else
      ddns_emit INFO "pbr scope 已禁用。"
    fi
  fi
  if [[ "$scope" == "all" ]]; then
    ddns_refresh_global_domains_scope || result="warn"
  fi
  if (( DDNS_FORWARD_NEED_APPLY == 1 )); then
    if [[ "${auto_apply,,}" == "true" ]]; then
      if ddns_auto_snapshot; then
        ddns_emit INFO "检测到域名后端变化，正在安全重应用 nftables 转发规则。"
        if apply_nft_rules "leikwan-relay" "$([[ "${auto_fix,,}" == "true" ]] && printf '1' || printf '0')"; then
          DDNS_NFT_APPLIED=true
          ddns_emit OK "已重应用 nftables 转发规则。"
        else
          result="fail"
          ddns_emit WARN "nftables 转发规则重应用失败。"
        fi
      else
        result="warn"
      fi
    else
      result="warn"
      ddns_emit WARN "检测到域名后端变化，但 DDNS_AUTO_APPLY=${auto_apply}，未自动应用。"
    fi
  fi
  if (( DDNS_FORWARD_PBR_NEED_SYNC == 1 )); then
    if ddns_config_bool DDNS_AUTO_SYNC_FORWARD_PBR "$(ddns_config_value DDNS_AUTO_SYNC_PBR "$DDNS_AUTO_SYNC_FORWARD_PBR_DEFAULT")"; then
      ddns_emit INFO "DDNS_AUTO_SYNC_FORWARD_PBR=true，正在同步 forward 来源 PBR。"
      pbr_sync_from_forwards --no-apply || result="warn"
    fi
  fi
  if [[ -n "$DDNS_PBR_CHANGED" ]] || { [[ -n "$DDNS_FORWARD_CHANGED" ]] && (( DDNS_FORWARD_PBR_NEED_SYNC == 1 )); }; then
    if [[ "${auto_apply,,}" == "true" ]]; then
      if pbr_apply; then
        DDNS_PBR_APPLIED=true
        ddns_emit OK "已应用 PBR。"
      else
        result="warn"
        ddns_emit WARN "PBR 应用失败。"
      fi
    else
      result="warn"
      ddns_emit INFO "DDNS_AUTO_APPLY=${auto_apply}，已更新 PBR 配置但未应用。"
    fi
  fi
  if (( no_restart == 1 )) && [[ "$DDNS_RELAY_RESTART_NEEDED" == "true" ]]; then
    ddns_emit INFO "已检测到公网入口 DDNS 变化，relay 重启留给 lq ddns apply-entries 处理。"
  elif ! ddns_maybe_restart_relay "$non_interactive"; then
    result="warn"
  fi
  if [[ -n "$DDNS_ENTRY_RECENT_EVENTS" ]]; then
    DDNS_ENTRY_RECENT_ACTION="已写入缓存"
    if [[ "$DDNS_NFT_APPLIED" == "true" ]]; then
      DDNS_ENTRY_RECENT_ACTION="${DDNS_ENTRY_RECENT_ACTION} / 已重应用 nftables"
    fi
    if [[ "$DDNS_RELAY_RESTARTED" == "true" ]]; then
      DDNS_ENTRY_RECENT_ACTION="${DDNS_ENTRY_RECENT_ACTION} / relay 已重启"
    elif [[ "$DDNS_RELAY_RESTART_NEEDED" == "true" ]]; then
      DDNS_ENTRY_RECENT_ACTION="${DDNS_ENTRY_RECENT_ACTION} / relay restart needed"
    fi
  fi
  if [[ -n "$DDNS_FORWARD_RECENT_EVENTS" ]]; then
    DDNS_FORWARD_RECENT_ACTION="已写入缓存"
    if [[ "$DDNS_NFT_APPLIED" == "true" ]]; then
      DDNS_FORWARD_RECENT_ACTION="${DDNS_FORWARD_RECENT_ACTION} / 已重应用 nftables"
    elif (( DDNS_FORWARD_NEED_APPLY == 1 )); then
      DDNS_FORWARD_RECENT_ACTION="${DDNS_FORWARD_RECENT_ACTION} / 待重应用 nftables"
    fi
  fi
  if [[ -n "$DDNS_PBR_RECENT_EVENTS" ]]; then
    DDNS_PBR_RECENT_ACTION="已写入缓存"
    if [[ "$DDNS_PBR_APPLIED" == "true" ]]; then
      DDNS_PBR_RECENT_ACTION="${DDNS_PBR_RECENT_ACTION} / 已同步 PBR"
    elif [[ -n "$DDNS_PBR_CHANGED" ]] &&
      ddns_config_bool DDNS_AUTO_SYNC_PBR "$DDNS_AUTO_SYNC_PBR_DEFAULT" &&
      ddns_config_bool DDNS_AUTO_SYNC_DOMAIN_PBR "$DDNS_AUTO_SYNC_DOMAIN_PBR_DEFAULT"; then
      DDNS_PBR_RECENT_ACTION="${DDNS_PBR_RECENT_ACTION} / 已同步 PBR"
    elif [[ -n "$DDNS_PBR_CHANGED" ]]; then
      DDNS_PBR_RECENT_ACTION="${DDNS_PBR_RECENT_ACTION} / 待同步 PBR"
    fi
  fi
  if [[ -n "$DDNS_FORWARD_FAILED$DDNS_ENTRY_FAILED$DDNS_PBR_FAILED" && "$result" == "ok" ]]; then
    result="warn"
  fi
  if (( DDNS_FORWARD_CHANGED_COUNT == 0 )); then DDNS_FORWARD_CHANGED_COUNT="$(csv_count "$DDNS_FORWARD_CHANGED")"; fi
  if (( DDNS_FORWARD_FAILED_COUNT == 0 )); then DDNS_FORWARD_FAILED_COUNT="$(csv_count "$DDNS_FORWARD_FAILED")"; fi
  if (( DDNS_ENTRY_CHANGED_COUNT == 0 )); then DDNS_ENTRY_CHANGED_COUNT="$(csv_count "$DDNS_ENTRY_CHANGED")"; fi
  if (( DDNS_ENTRY_FAILED_COUNT == 0 )); then DDNS_ENTRY_FAILED_COUNT="$(csv_count "$DDNS_ENTRY_FAILED")"; fi
  if (( DDNS_PBR_DOMAIN_COUNT == 0 )) && ddns_scope_requested "$scope" pbr; then
    DDNS_PBR_DOMAIN_COUNT="$(ddns_domain_pbr_count 2>/dev/null || printf '0')"
  fi
  ddns_print_summary "$result"
  if [[ "$scope" == "entries" ]]; then
    ddns_print_entry_detection_section
  fi
  ddns_write_last_status "$result" "$scope" "$DDNS_FORWARD_CHANGED" "$DDNS_FORWARD_FAILED" "$DDNS_ENTRY_CHANGED" "$DDNS_ENTRY_FAILED" "$DDNS_PBR_CHANGED" "$DDNS_PBR_FAILED" "$DDNS_RELAY_RESTART_NEEDED" "$DDNS_NFT_APPLIED" "$DDNS_PBR_APPLIED" "$DDNS_RELAY_RESTARTED"
  ddns_emit INFO "域名解析变化检测结束：$(status_result_display "$result")。"
  global_lock_release
  lock_release "$ddns_lock"
}

render_ddns_service() {
  local exec_path="$SHORTCUT_LQ"
  if [[ ! -x "$exec_path" ]]; then
    exec_path="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
  fi
  cat <<EOF
# Managed by leikwan-toolkit ${TOOL_VERSION}
[Unit]
Description=Leikwan DDNS domain resolution refresh
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${exec_path} ddns run --global --non-interactive
EOF
}

render_ddns_timer() {
  local interval
  interval="$(ddns_config_value DDNS_GLOBAL_INTERVAL "$(ddns_config_value DDNS_REFRESH_INTERVAL "$DDNS_GLOBAL_INTERVAL_DEFAULT")")"
  cat <<EOF
# Managed by leikwan-toolkit ${TOOL_VERSION}
[Unit]
Description=Leikwan DDNS domain resolution timer

[Timer]
OnBootSec=2min
OnUnitActiveSec=${interval}
Unit=${DDNS_SERVICE_NAME}.service

[Install]
WantedBy=timers.target
EOF
}

ddns_install_units() {
  need_root_unless_dry_run
  ddns_ensure_config
  write_file "$DDNS_SERVICE" "$(render_ddns_service)" 644
  write_file "$DDNS_TIMER" "$(render_ddns_timer)" 644
  if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || warn "systemd daemon-reload 失败。"
  fi
}

ddns_enable_timer() {
  need_root_unless_dry_run
  ddns_ensure_config
  dnsutils_auto_install "ddns-enable" "false" "plain" || true
  ddns_write_config "$(ddns_config_value DDNS_GLOBAL_INTERVAL "$(ddns_config_value DDNS_REFRESH_INTERVAL "$DDNS_GLOBAL_INTERVAL_DEFAULT")")" \
    "$(ddns_config_value DDNS_REFRESH_FORWARDS "$DDNS_REFRESH_FORWARDS_DEFAULT")" \
    "$(ddns_config_value DDNS_REFRESH_ENTRIES "$DDNS_REFRESH_ENTRIES_DEFAULT")" \
    "$(ddns_config_value DDNS_REFRESH_PBR "$DDNS_REFRESH_PBR_DEFAULT")" \
    "$(ddns_config_value DDNS_AUTO_APPLY "$DDNS_AUTO_APPLY_DEFAULT")" \
    "$(ddns_config_value DDNS_AUTO_FIX_ROUTE "$DDNS_AUTO_FIX_ROUTE_DEFAULT")" \
    "$(ddns_config_value DDNS_AUTO_SYNC_FORWARD_PBR "$(ddns_config_value DDNS_AUTO_SYNC_PBR "$DDNS_AUTO_SYNC_FORWARD_PBR_DEFAULT")")" \
    "$(ddns_config_value DDNS_AUTO_SYNC_DOMAIN_PBR "$DDNS_AUTO_SYNC_DOMAIN_PBR_DEFAULT")" \
    "$(ddns_config_value DDNS_AUTO_RESTART_RELAY "$(ddns_config_value DDNS_ENTRY_AUTO_RESTART_RELAY "$DDNS_ENTRY_AUTO_RESTART_RELAY_DEFAULT")")" \
    "$(ddns_config_value DDNS_KEEP_OLD_ON_FAIL "$DDNS_KEEP_OLD_ON_FAIL_DEFAULT")"
  if (( DRY_RUN == 0 )); then
    if grep -q '^DDNS_GLOBAL_ENABLED=' "$DDNS_CONFIG" 2>/dev/null; then
      sed -i 's/^DDNS_GLOBAL_ENABLED=.*/DDNS_GLOBAL_ENABLED=true/' "$DDNS_CONFIG" 2>/dev/null || true
    fi
  fi
  ddns_install_units
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now "${DDNS_SERVICE_NAME}.timer"
    ok "域名解析变化检测 timer 已启用。"
    info "将每 $(ddns_config_value DDNS_GLOBAL_INTERVAL "$(ddns_config_value DDNS_REFRESH_INTERVAL "$DDNS_REFRESH_INTERVAL_DEFAULT")") 执行一次域名解析变化检测与本地刷新。"
    info "默认不修改 DNS 服务商记录，也不会自动重启 relay。"
  else
    warn "未找到 systemctl，无法启用 DDNS timer。"
    return 1
  fi
}

ddns_disable_timer() {
  need_root_unless_dry_run
  if [[ -f "$DDNS_CONFIG" ]] && (( DRY_RUN == 0 )); then
    sed -i 's/^DDNS_GLOBAL_ENABLED=.*/DDNS_GLOBAL_ENABLED=false/' "$DDNS_CONFIG" 2>/dev/null || true
  fi
  if command -v systemctl >/dev/null 2>&1; then
    systemctl disable --now "${DDNS_SERVICE_NAME}.timer" 2>/dev/null || true
    ok "域名解析变化检测 timer 已关闭。"
  else
    warn "未找到 systemctl，无法禁用 DDNS timer。"
  fi
}

ddns_status() {
  local timer_state interval auto_enabled update_dns
  local timer_display next_run
  local last_time last_result last_scope forward_changed forward_failed entry_changed entry_failed pbr_changed pbr_failed
  local relay_restart_needed nft_applied pbr_applied relay_restarted public_ip public_ip_source
  local dns_strategy dns_servers dns_split dns_incomplete dns_split_domain dns_split_results dns_selected_ip dns_selected_source dns_line
  local entry_recent_events entry_recent_action entry_line forward_recent_events forward_recent_action forward_line pbr_recent_events pbr_recent_action pbr_line
  local recent_auto_action relay_restarted_at restart_cooldown change_confirm_count
  local -a _ddns_status_dns_lines _ddns_status_entry_lines _ddns_status_forward_lines _ddns_status_pbr_lines
  local forward_count entry_count pbr_count forward_checked entry_checked pbr_checked
  local forward_changed_count forward_failed_count entry_changed_count entry_failed_count pbr_changed_count pbr_failed_count
  local nft_text pbr_text
  dnsutils_auto_install "ddns-status" "false" "plain" || true
  timer_state="$(ddns_timer_state)"
  if [[ "$timer_state" == "active" ]]; then
    timer_display="enabled"
    next_run="$(ddns_timer_next_run)"
  else
    timer_display="disabled"
    next_run="未启用"
  fi
  interval="$(ddns_config_value DDNS_GLOBAL_INTERVAL "$(ddns_config_value DDNS_REFRESH_INTERVAL "$DDNS_REFRESH_INTERVAL_DEFAULT")")"
  auto_enabled="$(ddns_config_value DDNS_GLOBAL_ENABLED "$DDNS_GLOBAL_ENABLED_DEFAULT")"
  [[ "$timer_state" == "active" ]] && auto_enabled="true"
  update_dns="$(ddns_config_value DDNS_UPDATE_DNS_RECORD "$DDNS_UPDATE_DNS_RECORD_DEFAULT")"
  last_time="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_TIME)"
  last_result="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RESULT)"
  last_scope="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_SCOPE)"
  public_ip="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_PUBLIC_IP)"
  public_ip_source="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_PUBLIC_IP_SOURCE)"
  forward_changed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_FORWARD_CHANGED)"
  forward_failed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_FORWARD_FAILED)"
  entry_changed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_ENTRY_CHANGED)"
  entry_failed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_ENTRY_FAILED)"
  pbr_changed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_PBR_CHANGED)"
  pbr_failed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_PBR_FAILED)"
  relay_restart_needed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RELAY_RESTART_NEEDED)"
  nft_applied="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_NFT_APPLIED)"
  pbr_applied="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_PBR_APPLIED)"
  relay_restarted="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RELAY_RESTARTED)"
  relay_restarted_at="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RELAY_RESTARTED_AT)"
  dns_strategy="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_STRATEGY)"
  [[ -n "$dns_strategy" ]] || dns_strategy="$(normalize_dns_resolve_strategy "$(ddns_config_value DNS_RESOLVE_STRATEGY "$DNS_RESOLVE_STRATEGY_DEFAULT")")"
  dns_servers="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_SERVERS)"
  [[ -n "$dns_servers" ]] || dns_servers="$(ddns_config_value DNS_RESOLVE_SERVERS "$DNS_RESOLVE_SERVERS_DEFAULT")"
  dns_split="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_SPLIT_DETECTED)"
  dns_incomplete="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_INCOMPLETE_DETECTED)"
  dns_split_domain="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_SPLIT_DOMAIN)"
  dns_split_results="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_SPLIT_RESULTS)"
  dns_selected_ip="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_SELECTED_IP)"
  dns_selected_source="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_SELECTED_SOURCE)"
  forward_count="$(ddns_domain_forward_count 2>/dev/null || printf '0')"
  entry_count="$(ddns_domain_entry_count 2>/dev/null || printf '0')"
  pbr_count="$(ddns_domain_pbr_count 2>/dev/null || printf '0')"
  forward_checked="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_FORWARD_CHECKED)"
  entry_checked="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_ENTRY_CHECKED)"
  pbr_checked="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_PBR_CHECKED)"
  [[ -n "$forward_checked" ]] || forward_checked="$forward_count"
  [[ -n "$entry_checked" ]] || entry_checked="$entry_count"
  [[ -n "$pbr_checked" ]] || pbr_checked="$pbr_count"
  forward_changed_count="$(csv_count "$forward_changed")"
  forward_failed_count="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_FORWARD_FAILED_COUNT)"
  [[ -n "$forward_failed_count" ]] || forward_failed_count="$(csv_count "$forward_failed")"
  entry_changed_count="$(csv_count "$entry_changed")"
  entry_failed_count="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_ENTRY_FAILED_COUNT)"
  [[ -n "$entry_failed_count" ]] || entry_failed_count="$(csv_count "$entry_failed")"
  pbr_changed_count="$(csv_count "$pbr_changed")"
  pbr_failed_count="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_PBR_FAILED_COUNT)"
  [[ -n "$pbr_failed_count" ]] || pbr_failed_count="$(csv_count "$pbr_failed")"
  nft_text="$(ddns_action_text "${nft_applied:-false}" "已重应用" "待重应用" "无需重应用")"
  pbr_text="$(ddns_action_text "${pbr_applied:-false}" "已同步" "待同步" "无需同步")"
  restart_cooldown="$(ddns_config_value DDNS_RESTART_RELAY_COOLDOWN "$DDNS_RESTART_RELAY_COOLDOWN_DEFAULT")"
  change_confirm_count="$(ddns_config_value DDNS_CHANGE_CONFIRM_COUNT "$DDNS_CHANGE_CONFIRM_COUNT_DEFAULT")"
  if [[ "${last_result,,}" == "fail" && "${nft_applied:-false}" != "true" && -n "$forward_changed" ]]; then
    nft_text="失败"
  fi
  if [[ "${last_result,,}" == "fail" && "${pbr_applied:-false}" != "true" && -n "$pbr_changed" ]]; then
    pbr_text="失败"
  fi
  echo "DDNS / 域名解析状态"
  echo "----------------------------------------"
  echo "自动检测: $(bool_enabled_disabled "$auto_enabled")"
  echo "timer: ${timer_display}"
  echo "下次检测: ${next_run}"
  echo "检测间隔: ${interval}"
  echo "辅助公网 IP: ${public_ip:-未检测}"
  echo "辅助公网 IP 检测源: ${public_ip_source:-"-"}"
  echo "DNS 解析策略: ${dns_strategy}"
  echo "DNS 解析器: ${dns_servers}"
  if [[ "${dns_split,,}" == "true" ]]; then
    echo "DNS 传播状态: 不一致"
  elif [[ "${dns_incomplete,,}" == "true" ]]; then
    echo "DNS 传播状态: 未完整检测"
  else
    echo "DNS 传播状态: 一致"
  fi
  echo "后端域名: checked ${forward_checked}, changed ${forward_changed_count}, failed ${forward_failed_count}"
  echo "公网入口域名: checked ${entry_checked}, changed ${entry_changed_count}, failed ${entry_failed_count}"
  echo "PBR 域名: checked ${pbr_checked}, changed ${pbr_changed_count}, failed ${pbr_failed_count}"
  echo "nftables: ${nft_text}"
  echo "PBR: ${pbr_text}"
  echo "relay restart needed: $(bool_yes_no "${relay_restart_needed:-false}")"
  [[ "${relay_restarted:-false}" == "true" ]] && echo "relay restarted: yes"
  [[ -n "$relay_restarted_at" ]] && echo "relay 最近自动重启: $(ddns_format_epoch "$relay_restarted_at")"
  echo "relay restart cooldown: ${restart_cooldown}s"
  echo "DDNS 变化确认次数: ${change_confirm_count}"
  echo "最近检测: ${last_time:-"-"}"
  echo "最近自动执行: ${last_time:-"-"}"
  recent_auto_action=""
  if [[ -n "$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_ENTRY_RECENT_EVENTS)$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_FORWARD_RECENT_EVENTS)$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_PBR_RECENT_EVENTS)" ]]; then
    recent_auto_action="已写入缓存"
  fi
  [[ "${nft_applied:-false}" == "true" ]] && recent_auto_action="${recent_auto_action}${recent_auto_action:+ / }已重应用 nftables"
  [[ "${pbr_applied:-false}" == "true" ]] && recent_auto_action="${recent_auto_action}${recent_auto_action:+ / }已同步 PBR"
  [[ "${relay_restarted:-false}" == "true" ]] && recent_auto_action="${recent_auto_action}${recent_auto_action:+ / }relay 已重启"
  [[ "${relay_restart_needed:-false}" == "true" ]] && recent_auto_action="${recent_auto_action}${recent_auto_action:+ / }relay restart needed"
  if [[ -z "$recent_auto_action" && -n "$last_time" ]]; then
    recent_auto_action="已写入缓存"
  fi
  [[ -n "$recent_auto_action" ]] || recent_auto_action="无"
  echo "最近自动动作: ${recent_auto_action}"
  echo "结果: $(status_result_display "${last_result:-unknown}")"
  if [[ "${update_dns,,}" == "true" ]]; then
    echo "[WARN] DDNS_UPDATE_DNS_RECORD=true，高级兼容 DNS 更新能力已显式启用。"
  fi
  if [[ "${dns_split,,}" == "true" ]]; then
    echo
    echo "最近 DNS 分歧:"
    echo "${dns_split_domain:-未知域名}"
    IFS=';' read -ra _ddns_status_dns_lines <<<"$dns_split_results"
    for dns_line in "${_ddns_status_dns_lines[@]}"; do
      [[ -n "$dns_line" ]] && echo "$dns_line"
    done
    echo "当前采用: ${dns_selected_ip:-"-"}${dns_selected_source:+（source=${dns_selected_source}）}"
  fi
  entry_recent_events="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_ENTRY_RECENT_EVENTS)"
  entry_recent_action="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_ENTRY_RECENT_ACTION)"
  if [[ -n "$entry_recent_events" ]]; then
    echo
    echo "最近公网入口变化:"
    IFS=';' read -ra _ddns_status_entry_lines <<<"$entry_recent_events"
    for entry_line in "${_ddns_status_entry_lines[@]}"; do
      [[ -n "$entry_line" ]] && echo "$entry_line"
    done
    echo "动作: ${entry_recent_action:-已写入缓存}"
  fi
  forward_recent_events="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_FORWARD_RECENT_EVENTS)"
  forward_recent_action="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_FORWARD_RECENT_ACTION)"
  if [[ -n "$forward_recent_events" ]]; then
    echo
    echo "最近转发目标变化:"
    IFS=';' read -ra _ddns_status_forward_lines <<<"$forward_recent_events"
    for forward_line in "${_ddns_status_forward_lines[@]}"; do
      [[ -n "$forward_line" ]] && echo "$forward_line"
    done
    echo "动作: ${forward_recent_action:-已写入缓存}"
  fi
  pbr_recent_events="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_PBR_RECENT_EVENTS)"
  pbr_recent_action="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_PBR_RECENT_ACTION)"
  if [[ -n "$pbr_recent_events" ]]; then
    echo
    echo "最近 PBR 域名变化:"
    IFS=';' read -ra _ddns_status_pbr_lines <<<"$pbr_recent_events"
    for pbr_line in "${_ddns_status_pbr_lines[@]}"; do
      [[ -n "$pbr_line" ]] && echo "$pbr_line"
    done
    echo "动作: ${pbr_recent_action:-已写入缓存}"
  fi
  [[ -n "$last_scope" ]] && echo "详细分类: ${last_scope}"
  return 0
}

ddns_apply_entries() {
  need_root_unless_dry_run
  local restart_needed changed non_interactive=0 arg
  while (($# > 0)); do
    arg="$1"
    case "$arg" in
      --non-interactive) non_interactive=1; shift ;;
      *) fail "未知 ddns apply-entries 参数：${arg}"; return 1 ;;
    esac
  done
  ddns_refresh_once --scope entries --non-interactive --no-restart || true
  restart_needed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RELAY_RESTART_NEEDED)"
  changed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_ENTRY_CHANGED)"
  if [[ "${restart_needed:-false}" != "true" ]]; then
    ok "没有公网入口 DDNS 变化需要应用。"
    return 0
  fi
  warn "公网入口 DDNS 已变化，EasyTier relay 可能仍使用旧解析。"
  info "重启 relay 会短暂影响所有入口。"
  if (( non_interactive == 1 )) || ! is_interactive; then
    if ddns_config_bool DDNS_AUTO_RESTART_RELAY "$(ddns_config_value DDNS_ENTRY_AUTO_RESTART_RELAY "$DDNS_ENTRY_AUTO_RESTART_RELAY_DEFAULT")"; then
      info "非交互模式，DDNS_AUTO_RESTART_RELAY=true，正在自动重启 relay。"
    else
      info "非交互模式，DDNS_AUTO_RESTART_RELAY=false，仅标记 relay restart needed。"
      info "可在维护窗口执行：lq ddns apply-entries"
      return 0
    fi
  elif ! prompt_yes_no "是否现在重启 relay？" "N"; then
    info "已保留当前 relay 状态。"
    info "可在维护窗口执行：lq ddns apply-entries"
    return 0
  fi
  ddns_auto_snapshot || warn "relay 重启前自动快照失败，将继续按用户确认操作。"
  if apply_easytier_relay_service confirmed-no-snapshot; then
    ddns_note_relay_restarted
    ok "已重启 relay。"
    test_all_enabled_entries || warn "公网入口连通性测试存在 WARN，请执行 lq --doctor 查看。"
    ddns_write_last_status "ok" "entries" "" "" "$changed" "" "" "" false false false true
  else
    warn "relay 重启失败，请执行 lq --doctor 查看。"
    ddns_write_last_status "warn" "entries" "" "" "$changed" "" "" "" true false false false
    return 1
  fi
}

ddns_overview() {
  ddns_status
}

ddns_check_consistency() {
  local result="OK" printed_b=0 name public_host _et_ip _proto _port _weight enabled resolved cached
  local host public_ip resolved_ip match
  echo "DDNS / 域名解析一致性检查"
  echo "----------------------------------------"
  echo "公网入口缓存:"
  while IFS=$'\t' read -r name public_host _et_ip _proto _port _weight enabled; do
    [[ "$enabled" == "true" ]] || continue
    is_domain_name "$public_host" || continue
    printed_b=1
    if resolve_domain_ipv4_multi "$public_host"; then
      resolved="$RESOLVE_SELECTED_IP"
    else
      resolved=""
    fi
    cached="$(last_resolved_ip_for_entry "$name")"
    if [[ -n "$resolved" && -n "$cached" && "$resolved" == "$cached" ]]; then
      echo "- ${name} ${public_host} resolved=${resolved} cache=${cached} OK"
    else
      result="WARN"
      echo "- ${name} ${public_host} resolved=${resolved:-"-"} cache=${cached:-"-"} WARN"
    fi
  done < <(entries_rows)
  if (( printed_b == 0 )); then
    echo "未配置"
  fi
  echo
  echo "兼容 DNS 更新配置:"
  host="$(entry_ddns_config_value ENTRY_DDNS_HOST "")"
  if [[ -z "$host" ]]; then
    echo "未配置"
  else
    public_ip="$(entry_ddns_current_public_ip)"
    if resolve_domain_ipv4_multi "$host"; then
      resolved_ip="$RESOLVE_SELECTED_IP"
    else
      resolved_ip=""
    fi
    match="WARN"
    if [[ -n "$public_ip" && -n "$resolved_ip" && "$public_ip" == "$resolved_ip" ]]; then
      match="OK"
    else
      result="WARN"
    fi
    echo "- host=${host}"
    echo "- public_ip=${public_ip:-"-"}"
    echo "- resolved_ip=${resolved_ip:-"-"}"
    echo "- match=${match}"
  fi
  echo
  echo "结果: ${result}"
}

ddns_logs() {
  if [[ -f "$DDNS_LOG_FILE" ]]; then
    tail -n 100 "$DDNS_LOG_FILE"
  else
    info "暂无 DDNS 刷新日志：${DDNS_LOG_FILE}"
  fi
}

logs_index() {
  echo "日志查看 / 清理"
  echo "----------------------------------------"
  echo "DDNS 日志: ${DDNS_LOG_FILE}"
  echo "兼容 DNS 更新日志: ${ENTRY_DDNS_LOG_FILE}"
  echo "apply-relay 日志: ${APPLY_RELAY_LOG}"
  echo "update 状态: ${UPDATE_STATUS_FILE}"
  echo "doctor 最近状态: ${STATUS_DIR}/last-doctor.env"
  echo
  echo "用法:"
  echo "  lq logs ddns"
  echo "  lq logs entry-ddns"
  echo "  lq logs apply"
  echo "  lq logs update"
  echo "  lq logs doctor"
  echo "  lq logs clean"
}

logs_tail_file() {
  local label="$1" file="$2"
  if [[ -f "$file" ]]; then
    echo "${label}"
    echo "----------------------------------------"
    tail -n 100 "$file"
  else
    info "暂无${label}：${file}"
  fi
}

logs_show_update() {
  update_status
}

logs_show_doctor() {
  logs_tail_file "doctor 最近状态" "${STATUS_DIR}/last-doctor.env"
}

logs_clean() {
  need_root_unless_dry_run
  warn "将清理运行日志，但不会删除配置、快照、备份。"
  prompt_yes_no "确认继续？" "N" || return 0
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] rm -f ${DDNS_LOG_FILE} ${ENTRY_DDNS_LOG_FILE} ${APPLY_RELAY_LOG} ${LOG_FILE}"
    return 0
  fi
  rm -f "$DDNS_LOG_FILE" "$ENTRY_DDNS_LOG_FILE" "$APPLY_RELAY_LOG" "$LOG_FILE" 2>/dev/null || true
  ok "运行日志已清理。"
}

logs_menu() {
  local choice
  while true; do
    print_menu_header "日志查看 / 清理"
    echo "1. 查看 DDNS 日志"
    echo "2. 查看兼容 DNS 更新日志"
    echo "3. 查看 apply-relay 日志"
    echo "4. 查看 update 状态"
    echo "5. 查看 doctor 最近状态"
    echo "6. 清理运行日志"
    echo "0. 返回"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) run_menu_action_pause ddns_logs ;;
      2) run_menu_action_pause entry_ddns_logs ;;
      3) run_menu_action_pause logs_tail_file "apply-relay 日志" "$APPLY_RELAY_LOG" ;;
      4) run_menu_action_pause logs_show_update ;;
      5) run_menu_action_pause logs_show_doctor ;;
      6) run_menu_action_pause logs_clean ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

logs_cli() {
  case "${1:-}" in
    "") logs_index ;;
    ddns) ddns_logs ;;
    entry-ddns|entry-ddns-log) entry_ddns_logs ;;
    apply) logs_tail_file "apply-relay 日志" "$APPLY_RELAY_LOG" ;;
    update) logs_show_update ;;
    doctor) logs_show_doctor ;;
    clean) logs_clean ;;
    *) fail "未知 logs 子命令：$1"; echo "用法：lq logs [ddns|entry-ddns|apply|update|doctor|clean]" >&2; return 1 ;;
  esac
}

ddns_set_interval() {
  need_root_unless_dry_run
  ddns_ensure_config
  local choice interval refresh_forwards refresh_entries refresh_pbr auto_apply auto_fix auto_sync_forward_pbr auto_sync_domain_pbr entry_auto_restart keep_old
  echo
  echo "设置域名解析变化检测间隔："
  echo "1. 5min"
  echo "2. 10min"
  echo "3. 30min"
  echo "4. 1h"
  echo "0. 返回"
  choice="$(prompt_menu_choice "请选择：")"
  case "$choice" in
    1) interval="5min" ;;
    2) interval="10min" ;;
    3) interval="30min" ;;
    4) interval="1h" ;;
    0|"") return 0 ;;
    *) warn "无效选择。"; return 0 ;;
  esac
  refresh_forwards="$(ddns_config_value DDNS_REFRESH_FORWARDS "$DDNS_REFRESH_FORWARDS_DEFAULT")"
  refresh_entries="$(ddns_config_value DDNS_REFRESH_ENTRIES "$DDNS_REFRESH_ENTRIES_DEFAULT")"
  refresh_pbr="$(ddns_config_value DDNS_REFRESH_PBR "$DDNS_REFRESH_PBR_DEFAULT")"
  auto_apply="$(ddns_config_value DDNS_AUTO_APPLY "$DDNS_AUTO_APPLY_DEFAULT")"
  auto_fix="$(ddns_config_value DDNS_AUTO_FIX_ROUTE "$DDNS_AUTO_FIX_ROUTE_DEFAULT")"
  auto_sync_forward_pbr="$(ddns_config_value DDNS_AUTO_SYNC_FORWARD_PBR "$(ddns_config_value DDNS_AUTO_SYNC_PBR "$DDNS_AUTO_SYNC_FORWARD_PBR_DEFAULT")")"
  auto_sync_domain_pbr="$(ddns_config_value DDNS_AUTO_SYNC_DOMAIN_PBR "$DDNS_AUTO_SYNC_DOMAIN_PBR_DEFAULT")"
  entry_auto_restart="$(ddns_config_value DDNS_ENTRY_AUTO_RESTART_RELAY "$DDNS_ENTRY_AUTO_RESTART_RELAY_DEFAULT")"
  keep_old="$(ddns_config_value DDNS_KEEP_OLD_ON_FAIL "$DDNS_KEEP_OLD_ON_FAIL_DEFAULT")"
  ddns_write_config "$interval" "$refresh_forwards" "$refresh_entries" "$refresh_pbr" "$auto_apply" "$auto_fix" "$auto_sync_forward_pbr" "$auto_sync_domain_pbr" "$entry_auto_restart" "$keep_old"
  ddns_install_units
  ok "域名解析变化检测间隔已设置为：${interval}"
  if command -v systemctl >/dev/null 2>&1 && systemctl is-enabled --quiet "${DDNS_SERVICE_NAME}.timer" 2>/dev/null; then
    systemctl restart "${DDNS_SERVICE_NAME}.timer" || warn "DDNS timer 重启失败，请稍后手动检查。"
  fi
}

ddns_toggle_menu() {
  local choice
  while true; do
    print_menu_header "域名解析变化检测"
    echo "1. 开启域名解析变化检测"
    echo "2. 关闭域名解析变化检测"
    echo "0. 返回"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) run_menu_action_pause ddns_enable_timer ;;
      2) run_menu_action_pause ddns_disable_timer ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

entry_ddns_toggle_menu() {
  local choice
  print_menu_header "兼容 DNS 更新自动刷新"
  echo "1. 启用兼容 DNS 更新 timer"
  echo "2. 禁用兼容 DNS 更新 timer"
  echo "0. 返回"
  choice="$(prompt_menu_choice "请选择：")"
  case "$choice" in
    1) entry_ddns_enable_timer ;;
    2) entry_ddns_disable_timer ;;
    0|"") return 0 ;;
    *) menu_invalid_choice ;;
  esac
}

ddns_status_logs_menu() {
  local choice
  print_menu_header "DDNS / 域名解析状态 / 日志"
  echo "1. 查看状态"
  echo "2. 查看日志"
  echo "3. 查看总览"
  echo "0. 返回"
  choice="$(prompt_menu_choice "请选择：")"
  case "$choice" in
    1) ddns_status ;;
    2) ddns_logs ;;
    3) ddns_overview ;;
    0|"") return 0 ;;
    *) menu_invalid_choice ;;
  esac
}

entry_ddns_status_logs_menu() {
  local choice
  print_menu_header "兼容 DNS 更新状态 / 日志"
  echo "1. 查看状态"
  echo "2. 查看日志"
  echo "0. 返回"
  choice="$(prompt_menu_choice "请选择：")"
  case "$choice" in
    1) entry_ddns_status ;;
    2) entry_ddns_logs ;;
    0|"") return 0 ;;
    *) menu_invalid_choice ;;
  esac
}

ddns_set_public_ip_urls() {
  need_root_unless_dry_run
  ddns_ensure_config
  local urls
  echo "当前辅助公网地址检测 URL 池："
  echo "$(ddns_config_value PUBLIC_IP_CHECK_URLS "$PUBLIC_IP_CHECK_URLS_DEFAULT")"
  urls="$(prompt_value "新的辅助公网地址检测 URL 池（逗号分隔）" "$(ddns_config_value PUBLIC_IP_CHECK_URLS "$PUBLIC_IP_CHECK_URLS_DEFAULT")")"
  [[ -n "$urls" ]] || urls="$PUBLIC_IP_CHECK_URLS_DEFAULT"
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] PUBLIC_IP_CHECK_URLS=${urls}"
    return 0
  fi
  touch "$DDNS_CONFIG"
  if grep -q '^PUBLIC_IP_CHECK_URLS=' "$DDNS_CONFIG" 2>/dev/null; then
    sed -i "s#^PUBLIC_IP_CHECK_URLS=.*#PUBLIC_IP_CHECK_URLS=$(env_value_one_line "$urls")#" "$DDNS_CONFIG"
  else
    printf 'PUBLIC_IP_CHECK_URLS=%s\n' "$(env_value_one_line "$urls")" >>"$DDNS_CONFIG"
  fi
  ok "辅助公网地址检测 URL 池已更新。"
}

ddns_set_dns_resolvers() {
  need_root_unless_dry_run
  ddns_ensure_config
  local servers
  echo "当前 DNS 解析器列表："
  echo "$(ddns_config_value DNS_RESOLVE_SERVERS "$DNS_RESOLVE_SERVERS_DEFAULT")"
  servers="$(prompt_value "新的 DNS 解析器列表（逗号分隔）" "$(ddns_config_value DNS_RESOLVE_SERVERS "$DNS_RESOLVE_SERVERS_DEFAULT")")"
  [[ -n "$servers" ]] || servers="$DNS_RESOLVE_SERVERS_DEFAULT"
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] DNS_RESOLVE_SERVERS=${servers}"
    return 0
  fi
  touch "$DDNS_CONFIG"
  if grep -q '^DNS_RESOLVE_SERVERS=' "$DDNS_CONFIG" 2>/dev/null; then
    sed -i "s#^DNS_RESOLVE_SERVERS=.*#DNS_RESOLVE_SERVERS=$(env_value_one_line "$servers")#" "$DDNS_CONFIG"
  else
    printf 'DNS_RESOLVE_SERVERS=%s\n' "$(env_value_one_line "$servers")" >>"$DDNS_CONFIG"
  fi
  ok "DNS 解析器列表已更新。"
}

ddns_set_dns_strategy() {
  need_root_unless_dry_run
  ddns_ensure_config
  local strategy
  echo "当前 DNS 解析策略：$(ddns_config_value DNS_RESOLVE_STRATEGY "$DNS_RESOLVE_STRATEGY_DEFAULT")"
  echo "可选：first-success / system-first / majority"
  strategy="$(prompt_value "新的 DNS 解析策略" "$(ddns_config_value DNS_RESOLVE_STRATEGY "$DNS_RESOLVE_STRATEGY_DEFAULT")")"
  strategy="$(normalize_dns_resolve_strategy "$strategy")"
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] DNS_RESOLVE_STRATEGY=${strategy}"
    return 0
  fi
  touch "$DDNS_CONFIG"
  if grep -q '^DNS_RESOLVE_STRATEGY=' "$DDNS_CONFIG" 2>/dev/null; then
    sed -i "s#^DNS_RESOLVE_STRATEGY=.*#DNS_RESOLVE_STRATEGY=$(env_value_one_line "$strategy")#" "$DDNS_CONFIG"
  else
    printf 'DNS_RESOLVE_STRATEGY=%s\n' "$(env_value_one_line "$strategy")" >>"$DDNS_CONFIG"
  fi
  ok "DNS 解析策略已更新：${strategy}"
}

ddns_show_recent_dns_split() {
  local split domain results selected_ip selected_source line
  local -a lines
  split="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_SPLIT_DETECTED)"
  if [[ "${split,,}" != "true" ]]; then
    info "最近一次检测没有发现 DNS 传播分歧。"
    return 0
  fi
  domain="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_SPLIT_DOMAIN)"
  results="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_SPLIT_RESULTS)"
  selected_ip="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_SELECTED_IP)"
  selected_source="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_SELECTED_SOURCE)"
  echo "最近 DNS 分歧:"
  echo "${domain:-未知域名}"
  IFS=';' read -ra lines <<<"$results"
  for line in "${lines[@]}"; do
    [[ -n "$line" ]] && echo "$line"
  done
  echo "当前采用: ${selected_ip:-"-"}${selected_source:+（source=${selected_source}）}"
}

ddns_toggle_auto_apply() {
  need_root_unless_dry_run
  ddns_ensure_config
  local value
  if prompt_yes_no "域名解析变化后自动重应用 nftables？" "$(bool_to_default "$(ddns_config_value DDNS_AUTO_APPLY "$DDNS_AUTO_APPLY_DEFAULT")")"; then value="true"; else value="false"; fi
  ddns_write_config "$(ddns_config_value DDNS_GLOBAL_INTERVAL "$(ddns_config_value DDNS_REFRESH_INTERVAL "$DDNS_GLOBAL_INTERVAL_DEFAULT")")" \
    "$(ddns_config_value DDNS_REFRESH_FORWARDS "$DDNS_REFRESH_FORWARDS_DEFAULT")" \
    "$(ddns_config_value DDNS_REFRESH_ENTRIES "$DDNS_REFRESH_ENTRIES_DEFAULT")" \
    "$(ddns_config_value DDNS_REFRESH_PBR "$DDNS_REFRESH_PBR_DEFAULT")" \
    "$value" \
    "$(ddns_config_value DDNS_AUTO_FIX_ROUTE "$DDNS_AUTO_FIX_ROUTE_DEFAULT")" \
    "$(ddns_config_value DDNS_AUTO_SYNC_FORWARD_PBR "$(ddns_config_value DDNS_AUTO_SYNC_PBR "$DDNS_AUTO_SYNC_FORWARD_PBR_DEFAULT")")" \
    "$(ddns_config_value DDNS_AUTO_SYNC_DOMAIN_PBR "$DDNS_AUTO_SYNC_DOMAIN_PBR_DEFAULT")" \
    "$(ddns_config_value DDNS_AUTO_RESTART_RELAY "$(ddns_config_value DDNS_ENTRY_AUTO_RESTART_RELAY "$DDNS_ENTRY_AUTO_RESTART_RELAY_DEFAULT")")" \
    "$(ddns_config_value DDNS_KEEP_OLD_ON_FAIL "$DDNS_KEEP_OLD_ON_FAIL_DEFAULT")"
  ok "DDNS_AUTO_APPLY=${value}"
}

ddns_toggle_auto_sync_pbr() {
  need_root_unless_dry_run
  ddns_ensure_config
  local value
  if prompt_yes_no "域名解析变化后自动同步 PBR？" "$(bool_to_default "$(ddns_config_value DDNS_AUTO_SYNC_PBR "$DDNS_AUTO_SYNC_PBR_DEFAULT")")"; then value="true"; else value="false"; fi
  ddns_write_config "$(ddns_config_value DDNS_GLOBAL_INTERVAL "$(ddns_config_value DDNS_REFRESH_INTERVAL "$DDNS_GLOBAL_INTERVAL_DEFAULT")")" \
    "$(ddns_config_value DDNS_REFRESH_FORWARDS "$DDNS_REFRESH_FORWARDS_DEFAULT")" \
    "$(ddns_config_value DDNS_REFRESH_ENTRIES "$DDNS_REFRESH_ENTRIES_DEFAULT")" \
    "$(ddns_config_value DDNS_REFRESH_PBR "$DDNS_REFRESH_PBR_DEFAULT")" \
    "$(ddns_config_value DDNS_AUTO_APPLY "$DDNS_AUTO_APPLY_DEFAULT")" \
    "$(ddns_config_value DDNS_AUTO_FIX_ROUTE "$DDNS_AUTO_FIX_ROUTE_DEFAULT")" \
    "$value" "$value" \
    "$(ddns_config_value DDNS_AUTO_RESTART_RELAY "$(ddns_config_value DDNS_ENTRY_AUTO_RESTART_RELAY "$DDNS_ENTRY_AUTO_RESTART_RELAY_DEFAULT")")" \
    "$(ddns_config_value DDNS_KEEP_OLD_ON_FAIL "$DDNS_KEEP_OLD_ON_FAIL_DEFAULT")"
  if (( DRY_RUN == 0 )); then
    sed -i "s/^DDNS_AUTO_SYNC_PBR=.*/DDNS_AUTO_SYNC_PBR=${value}/" "$DDNS_CONFIG" 2>/dev/null || true
  fi
  ok "DDNS_AUTO_SYNC_PBR=${value}"
}

ddns_toggle_auto_restart_relay() {
  need_root_unless_dry_run
  ddns_ensure_config
  local value
  if prompt_yes_no "允许公网入口域名解析变化后自动重启 relay？" "$(bool_to_default "$(ddns_config_value DDNS_AUTO_RESTART_RELAY "$DDNS_AUTO_RESTART_RELAY_DEFAULT")")"; then value="true"; else value="false"; fi
  ddns_write_config "$(ddns_config_value DDNS_GLOBAL_INTERVAL "$(ddns_config_value DDNS_REFRESH_INTERVAL "$DDNS_GLOBAL_INTERVAL_DEFAULT")")" \
    "$(ddns_config_value DDNS_REFRESH_FORWARDS "$DDNS_REFRESH_FORWARDS_DEFAULT")" \
    "$(ddns_config_value DDNS_REFRESH_ENTRIES "$DDNS_REFRESH_ENTRIES_DEFAULT")" \
    "$(ddns_config_value DDNS_REFRESH_PBR "$DDNS_REFRESH_PBR_DEFAULT")" \
    "$(ddns_config_value DDNS_AUTO_APPLY "$DDNS_AUTO_APPLY_DEFAULT")" \
    "$(ddns_config_value DDNS_AUTO_FIX_ROUTE "$DDNS_AUTO_FIX_ROUTE_DEFAULT")" \
    "$(ddns_config_value DDNS_AUTO_SYNC_FORWARD_PBR "$(ddns_config_value DDNS_AUTO_SYNC_PBR "$DDNS_AUTO_SYNC_FORWARD_PBR_DEFAULT")")" \
    "$(ddns_config_value DDNS_AUTO_SYNC_DOMAIN_PBR "$DDNS_AUTO_SYNC_DOMAIN_PBR_DEFAULT")" \
    "$value" \
    "$(ddns_config_value DDNS_KEEP_OLD_ON_FAIL "$DDNS_KEEP_OLD_ON_FAIL_DEFAULT")"
  ok "DDNS_AUTO_RESTART_RELAY=${value}"
}

ddns_set_relay_restart_cooldown() {
  need_root_unless_dry_run
  ddns_ensure_config
  local value
  echo "当前 relay 自动重启 cooldown：$(ddns_config_value DDNS_RESTART_RELAY_COOLDOWN "$DDNS_RESTART_RELAY_COOLDOWN_DEFAULT") 秒"
  value="$(prompt_value "新的 cooldown 秒数" "$(ddns_config_value DDNS_RESTART_RELAY_COOLDOWN "$DDNS_RESTART_RELAY_COOLDOWN_DEFAULT")")"
  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    warn "cooldown 必须是非负整数秒。"
    return 0
  fi
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] DDNS_RESTART_RELAY_COOLDOWN=${value}"
    return 0
  fi
  touch "$DDNS_CONFIG"
  if grep -q '^DDNS_RESTART_RELAY_COOLDOWN=' "$DDNS_CONFIG" 2>/dev/null; then
    sed -i "s/^DDNS_RESTART_RELAY_COOLDOWN=.*/DDNS_RESTART_RELAY_COOLDOWN=${value}/" "$DDNS_CONFIG"
  else
    printf 'DDNS_RESTART_RELAY_COOLDOWN=%s\n' "$value" >>"$DDNS_CONFIG"
  fi
  ok "DDNS_RESTART_RELAY_COOLDOWN=${value}"
}

ddns_legacy_dns_update_menu() {
  print_menu_header "兼容旧版 DNS 更新配置"
  echo "该入口仅为旧脚本兼容。普通用户不需要配置 DNS provider token。"
  echo "默认 DDNS_UPDATE_DNS_RECORD=false，Leikwan Toolkit 只检测解析变化并刷新本地配置。"
  echo
  local choice
  echo "1. 查看旧版配置摘要"
  echo "2. 打开旧版配置向导"
  echo "0. 返回"
  choice="$(prompt_menu_choice "请选择：")"
  case "$choice" in
    1|"") entry_ddns_current_config_summary ;;
    2) entry_ddns_setup ;;
    0) return 0 ;;
    *) menu_invalid_choice ;;
  esac
}

ddns_advanced_menu() {
  local choice
  while true; do
    print_menu_header "DDNS 高级设置"
    echo "1. 设置检测间隔"
    echo "2. 设置辅助公网地址检测 URL 池"
    echo "3. 设置 DNS 解析器列表"
    echo "4. 设置 DNS 解析策略"
    echo "5. 查看最近 DNS 分歧"
    echo "6. 设置是否自动重应用 nftables"
    echo "7. 设置是否自动同步 PBR"
    echo "8. 设置 relay 是否允许自动重启"
    echo "9. 设置 relay 自动重启 cooldown"
    echo "10. 兼容旧版 DNS 更新配置"
    echo "0. 返回"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) run_menu_action_pause ddns_set_interval ;;
      2) run_menu_action_pause ddns_set_public_ip_urls ;;
      3) run_menu_action_pause ddns_set_dns_resolvers ;;
      4) run_menu_action_pause ddns_set_dns_strategy ;;
      5) run_menu_action_pause ddns_show_recent_dns_split ;;
      6) run_menu_action_pause ddns_toggle_auto_apply ;;
      7) run_menu_action_pause ddns_toggle_auto_sync_pbr ;;
      8) run_menu_action_pause ddns_toggle_auto_restart_relay ;;
      9) run_menu_action_pause ddns_set_relay_restart_cooldown ;;
      10) run_menu_action_pause ddns_legacy_dns_update_menu ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

ddns_menu() {
  local choice
  while true; do
    print_ddns_menu_options
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) ddns_toggle_menu ;;
      2) run_menu_action_pause ddns_refresh_once --global ;;
      3) run_menu_action_pause ddns_status ;;
      4) run_menu_action_pause ddns_logs ;;
      5) ddns_advanced_menu ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

print_ddns_menu_options() {
  print_menu_header "DDNS"
  echo "1. 开启 / 关闭域名解析变化检测"
  echo "2. 立即检测并刷新"
  echo "3. 查看 DDNS / 域名解析状态"
  echo "4. 查看 DDNS 日志"
  echo "5. 高级设置"
  echo "0. 返回"
}

configure_forward_sysctl() {
  write_file "$FORWARD_SYSCTL" "net.ipv4.ip_forward=1" 644
  (( DRY_RUN == 1 )) || sysctl --system >/dev/null || true
}

render_nft_cloud() {
  local relay_ip start end mss mode name entry_port target_host target_port _oi _rt enabled comment
  if [[ ! -f "$ENTRY_EXPOSE_ENV" ]]; then
    fail "公网入口未配置，请粘贴转发接入码（推荐），或执行 lq entry expose-range。"
    return 1
  fi
  mss="$(tcp_mss_clamp_value)"
  relay_ip="$(entry_expose_relay_ip)"
  is_ipv4 "$relay_ip" || { fail "Relay EasyTier IP 非法：${relay_ip}"; return 1; }
  mode="$(env_file_get "$ENTRY_EXPOSE_ENV" ENTRY_MODE)"
  if [[ "$mode" == "bundle" ]]; then
    if ! forwards_rows | awk -F'\t' '$7=="true"{f=1} END{exit !f}'; then
      fail "接入码模式下没有启用的转发规则，请在 B 重新生成接入码并在 A 重新导入。"
      return 1
    fi
    cat <<EOF
table inet leikwan_forward {
  chain prerouting {
    type nat hook prerouting priority dstnat; policy accept;
EOF
    while IFS=$'\t' read -r name entry_port target_host target_port _oi _rt enabled comment; do
      [[ "$enabled" == "true" ]] || continue
      printf '    tcp dport %s dnat ip to %s\n' "$entry_port" "$relay_ip"
      printf '    udp dport %s dnat ip to %s\n' "$entry_port" "$relay_ip"
    done < <(forwards_rows)
    cat <<EOF
  }
  chain forward {
    type filter hook forward priority mangle; policy accept;
    ct state established,related accept
EOF
    if mss_clamp_enabled; then
      printf '    tcp flags syn tcp option maxseg size set %s\n' "$mss"
    fi
    while IFS=$'\t' read -r name entry_port target_host target_port _oi _rt enabled comment; do
      [[ "$enabled" == "true" ]] || continue
      printf '    ip daddr %s tcp dport %s accept\n' "$relay_ip" "$entry_port"
      printf '    ip daddr %s udp dport %s accept\n' "$relay_ip" "$entry_port"
    done < <(forwards_rows)
    cat <<EOF
  }
  chain postrouting {
    type nat hook postrouting priority srcnat; policy accept;
EOF
    while IFS=$'\t' read -r name entry_port target_host target_port _oi _rt enabled comment; do
      [[ "$enabled" == "true" ]] || continue
      printf '    ip daddr %s tcp dport %s masquerade\n' "$relay_ip" "$entry_port"
      printf '    ip daddr %s udp dport %s masquerade\n' "$relay_ip" "$entry_port"
    done < <(forwards_rows)
    cat <<EOF
  }
}
EOF
    return 0
  fi
  start="$(entry_expose_start)"
  end="$(entry_expose_end)"
  if ! is_port "$start" || ! is_port "$end" || (( start > end )); then
    fail "入口端口池配置非法：${start}-${end}"
    return 1
  fi
  cat <<EOF
table inet leikwan_forward {
  chain prerouting {
    type nat hook prerouting priority dstnat; policy accept;
    tcp dport ${start}-${end} dnat ip to ${relay_ip}
    udp dport ${start}-${end} dnat ip to ${relay_ip}
EOF
  cat <<EOF
  }
  chain forward {
    type filter hook forward priority mangle; policy accept;
    ct state established,related accept
EOF
  if mss_clamp_enabled; then
    printf '    tcp flags syn tcp option maxseg size set %s\n' "$mss"
  fi
  cat <<EOF
    ip daddr ${relay_ip} tcp dport ${start}-${end} accept
    ip daddr ${relay_ip} udp dport ${start}-${end} accept
EOF
  cat <<EOF
  }
  chain postrouting {
    type nat hook postrouting priority srcnat; policy accept;
    ip daddr ${relay_ip} tcp dport ${start}-${end} masquerade
    ip daddr ${relay_ip} udp dport ${start}-${end} masquerade
EOF
  cat <<EOF
  }
}
EOF
}

render_nft_relay() {
  local et_iface name entry_port target_host target_ip target_port out_iface route_table enabled _last_resolved_at comment mss
  mss="$(tcp_mss_clamp_value)"
  et_iface="$(et_iface_by_ip "$RELAY_ET_IP")"
  [[ -n "$et_iface" ]] || et_iface="easytier0"
  cat <<EOF
table inet leikwan_forward {
  chain prerouting {
    type nat hook prerouting priority dstnat; policy accept;
EOF
  while IFS=$'\034' read -r name entry_port target_host target_ip target_port out_iface route_table enabled _last_resolved_at comment; do
    [[ "$enabled" == "true" && -n "$target_ip" ]] || continue
    printf '    iifname "%s" tcp dport %s dnat ip to %s:%s\n' "$et_iface" "$entry_port" "$target_ip" "$target_port"
    printf '    iifname "%s" udp dport %s dnat ip to %s:%s\n' "$et_iface" "$entry_port" "$target_ip" "$target_port"
  done < <(resolved_rows_usv)
  cat <<EOF
  }
  chain forward {
    type filter hook forward priority mangle; policy accept;
    ct state established,related accept
EOF
  if mss_clamp_enabled; then
    printf '    tcp flags syn tcp option maxseg size set %s\n' "$mss"
  fi
  while IFS=$'\034' read -r name entry_port target_host target_ip target_port out_iface route_table enabled _last_resolved_at comment; do
    [[ "$enabled" == "true" && -n "$target_ip" ]] || continue
    if [[ -n "$out_iface" ]]; then
      printf '    iifname "%s" oifname "%s" ip daddr %s tcp dport %s accept\n' "$et_iface" "$out_iface" "$target_ip" "$target_port"
      printf '    iifname "%s" oifname "%s" ip daddr %s udp dport %s accept\n' "$et_iface" "$out_iface" "$target_ip" "$target_port"
    else
      printf '    iifname "%s" ip daddr %s tcp dport %s accept\n' "$et_iface" "$target_ip" "$target_port"
      printf '    iifname "%s" ip daddr %s udp dport %s accept\n' "$et_iface" "$target_ip" "$target_port"
    fi
  done < <(resolved_rows_usv)
  cat <<EOF
  }
  chain postrouting {
    type nat hook postrouting priority srcnat; policy accept;
EOF
  while IFS=$'\034' read -r name entry_port target_host target_ip target_port out_iface route_table enabled _last_resolved_at comment; do
    [[ "$enabled" == "true" && -n "$target_ip" ]] || continue
    if [[ -n "$out_iface" ]]; then
      printf '    oifname "%s" ip daddr %s tcp dport %s masquerade\n' "$out_iface" "$target_ip" "$target_port"
      printf '    oifname "%s" ip daddr %s udp dport %s masquerade\n' "$out_iface" "$target_ip" "$target_port"
    else
      printf '    ip daddr %s tcp dport %s masquerade\n' "$target_ip" "$target_port"
      printf '    ip daddr %s udp dport %s masquerade\n' "$target_ip" "$target_port"
    fi
  done < <(resolved_rows_usv)
  cat <<EOF
  }
}
EOF
}

render_nft_service() {
  local nft_bin
  nft_bin="$(command -v nft || printf '%s' /usr/sbin/nft)"
  cat <<EOF
# Managed by leikwan-toolkit ${TOOL_VERSION}
[Unit]
Description=Leikwan nftables L4 forwarding
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=${nft_bin} -f ${NFT_RULE_FILE}
ExecStop=-${nft_bin} delete table inet leikwan_forward

[Install]
WantedBy=multi-user.target
EOF
}

detect_role() {
  detect_leikwan_role
}

role_has_service() {
  local pattern="$1"
  command -v systemctl >/dev/null 2>&1 || return 1
  systemctl list-unit-files --type=service --no-legend "$pattern" 2>/dev/null | grep -q .
}

detect_leikwan_role() {
  local env_role relay=0 entry=0
  env_role="$(env_file_get "$NETWORK_ENV" ROLE)"
  [[ "$env_role" == "leikwan-relay" ]] && relay=1
  [[ "$env_role" == "cloud-entry" ]] && entry=1
  role_has_service "${EASYTIER_RELAY_SERVICE_NAME}.service" && relay=1
  role_has_service 'easytier-entry-*.service' && entry=1
  [[ -f "$ENTRY_PAIRING_FILE" || -f "$ENTRY_EXPOSE_ENV" ]] && entry=1
  if (( relay == 1 )); then
    printf 'leikwan-relay'
  elif (( entry == 1 )); then
    printf 'cloud-entry'
  else
    printf 'unknown'
  fi
}

role_summary() {
  local env_role sources=() aux_sources=() relay=0 entry=0 role pbr_count=0
  env_role="$(env_file_get "$NETWORK_ENV" ROLE)"
  if [[ "$env_role" == "leikwan-relay" ]]; then sources+=("network.env"); relay=1; fi
  if [[ "$env_role" == "cloud-entry" ]]; then sources+=("network.env"); entry=1; fi
  if role_has_service "${EASYTIER_RELAY_SERVICE_NAME}.service"; then sources+=("easytier-relay.service"); relay=1; fi
  if role_has_service 'easytier-entry-*.service'; then sources+=("entry service"); entry=1; fi
  if [[ -f "$ENTRY_PAIRING_FILE" || -f "$ENTRY_EXPOSE_ENV" ]]; then sources+=("entry env"); entry=1; fi
  if (( relay == 1 )) && entries_rows | awk 'NR==1 {found=1} END{exit !found}'; then aux_sources+=("entries.tsv"); fi
  if (( relay == 1 )) && forwards_rows | awk 'NR==1 {found=1} END{exit !found}'; then aux_sources+=("forwards.tsv"); fi
  pbr_count="$(pbr_rules_count 2>/dev/null || printf '0')"
  if (( relay == 1 && pbr_count > 0 )); then aux_sources+=("pbr"); fi
  role="$(detect_leikwan_role)"
  local joined="无" mixed="false" src
  if (( ${#aux_sources[@]} > 0 )); then
    sources+=("${aux_sources[@]}")
  fi
  if (( ${#sources[@]} > 0 )); then
    joined=""
    for src in "${sources[@]}"; do
      joined="${joined:+${joined} + }${src}"
    done
  fi
  (( relay == 1 && entry == 1 )) && mixed="true"
  printf '%s\t%s\t%s\n' "$role" "$joined" "$mixed"
}

ensure_role_or_warn() {
  local expected="$1" summary role source mixed expected_text actual_text
  summary="$(role_summary)"
  IFS=$'\t' read -r role source mixed <<<"$summary"
  [[ "$expected" == "$role" || "$role" == "unknown" ]] && return 0
  case "$expected" in
    leikwan-relay) expected_text="B 利群主机" ;;
    cloud-entry) expected_text="A 公网入口" ;;
    *) expected_text="$expected" ;;
  esac
  case "$role" in
    leikwan-relay) actual_text="B 利群主机" ;;
    cloud-entry) actual_text="A 公网入口" ;;
    *) actual_text="$role" ;;
  esac
  warn "当前机器检测为 ${actual_text}，你正在进入 ${expected_text} 操作。"
  warn "角色来源：${source}"
  [[ "$mixed" == "true" ]] && warn "检测到高级混合部署：relay + entry。"
  if is_interactive; then
    prompt_yes_no "是否仍然继续？" "N"
  else
    return 1
  fi
}

current_entry_et_ip() {
  local ip
  ip="$(env_file_get "$ENTRY_PAIRING_FILE" ENTRY_ET_IP)"
  [[ -n "$ip" ]] || ip="$(entries_rows | awk -F'\t' '$7=="true"{print $3; exit}')"
  printf '%s' "${ip:-$ENTRY_ET_IP_DEFAULT}"
}

current_relay_et_ip() {
  local ip
  ip="$(env_file_get "$NETWORK_ENV" RELAY_ET_IP)"
  [[ -n "$ip" ]] || ip="$(env_file_get "$NETWORK_ENV" EASYTIER_RELAY_ET_IP)"
  printf '%s' "${ip:-$RELAY_ET_IP}"
}

current_entry_configured_public_host() {
  local host
  host="$(env_file_get "$ENTRY_PAIRING_FILE" ENTRY_PUBLIC_HOST)"
  [[ -n "$host" ]] || host="$(env_file_get "$NETWORK_ENV" ENTRY_PUBLIC_HOST)"
  [[ -n "$host" ]] || host="$(entries_rows | awk -F'\t' '$7=="true"{print $2; exit}')"
  printf '%s' "$host"
}

current_entry_public_host() {
  local host
  host="$(current_entry_configured_public_host)"
  [[ -n "$host" ]] || host="$(detect_public_ipv4 2>/dev/null || true)"
  printf '%s' "${host:-<A_PUBLIC_HOST>}"
}

entry_expose_start() {
  local value
  value="$(env_file_get "$ENTRY_EXPOSE_ENV" ENTRY_EXPOSE_START)"
  printf '%s' "${value:-$ENTRY_EXPOSE_START_DEFAULT}"
}

entry_expose_end() {
  local value
  value="$(env_file_get "$ENTRY_EXPOSE_ENV" ENTRY_EXPOSE_END)"
  printf '%s' "${value:-$ENTRY_EXPOSE_END_DEFAULT}"
}

entry_expose_relay_ip() {
  local value
  value="$(env_file_get "$ENTRY_EXPOSE_ENV" RELAY_ET_IP)"
  [[ -n "$value" ]] || value="$(current_relay_et_ip)"
  printf '%s' "${value:-$RELAY_ET_IP}"
}

parse_port_range() {
  local range="$1" start end
  range="$(normalize_menu_choice "$range")"
  start="${range%-*}"
  end="${range#*-}"
  if is_port "$start" && is_port "$end" && (( start <= end )); then
    printf '%s\t%s\n' "$start" "$end"
    return 0
  fi
  fail "端口范围非法：${range}，格式示例 10000-19999"
  return 1
}

port_in_range() {
  local port="$1" start="$2" end="$3"
  is_port "$port" && is_port "$start" && is_port "$end" && (( port >= start && port <= end ))
}

warn_if_forward_port_outside_expose() {
  local port="$1" start end
  if [[ -f "$ENTRY_EXPOSE_ENV" ]]; then
    start="$(entry_expose_start)"
    end="$(entry_expose_end)"
    if port_in_range "$port" "$start" "$end"; then
      info "entry_port ${port} 位于入口端口池 ${start}-${end}。"
    else
      warn "entry_port ${port} 不在入口端口池 ${start}-${end} 内，公网入口可能无法访问。"
    fi
  else
    info "未读取到 A 入口端口池范围；将仅校验常见端口池 ${FORWARD_ENTRY_PORT_FALLBACK_START}-${FORWARD_ENTRY_PORT_FALLBACK_END}。"
    if port_in_range "$port" "$FORWARD_ENTRY_PORT_FALLBACK_START" "$FORWARD_ENTRY_PORT_FALLBACK_END"; then
      ok "entry_port ${port} 位于常见入口端口池 ${FORWARD_ENTRY_PORT_FALLBACK_START}-${FORWARD_ENTRY_PORT_FALLBACK_END}。"
    else
      warn "entry_port ${port} 不在默认推荐范围 ${FORWARD_ENTRY_PORT_FALLBACK_START}-${FORWARD_ENTRY_PORT_FALLBACK_END} 内。"
    fi
  fi
}

entry_expose_conflict_range_hint() {
  local start="$1" end="$2" conflict_ports="$3" first suggestions=()
  first="${conflict_ports%%,*}"
  [[ "$first" =~ ^[0-9]+$ ]] || return 0
  if (( first > start )); then
    suggestions+=("${start}-$((first - 1))")
  fi
  if (( first < end )); then
    suggestions+=("$((first + 1))-${end}")
  fi
  if (( ${#suggestions[@]} >= 2 )); then
    info "可改用不包含这些端口的端口池，例如 ${suggestions[0]} 或 ${suggestions[1]}。"
  elif (( ${#suggestions[@]} == 1 )); then
    info "可改用不包含这些端口的端口池，例如 ${suggestions[0]}。"
  else
    info "可改用不包含这些端口的端口池。"
  fi
}

entry_expose_range() {
  need_root_unless_dry_run
  ensure_base_dirs
  local start="$ENTRY_EXPOSE_START_DEFAULT" end="$ENTRY_EXPOSE_END_DEFAULT" relay_ip="" apply="ask" arg range parsed
  local conflict_ports
  while (($# > 0)); do
    arg="$1"
    case "$arg" in
      --start)
        start="${2:-}"; shift 2 ;;
      --end)
        end="${2:-}"; shift 2 ;;
      --range)
        range="${2:-}"; parsed="$(parse_port_range "$range")" || return 1
        IFS=$'\t' read -r start end <<<"$parsed"
        shift 2 ;;
      --relay-ip)
        relay_ip="${2:-}"; shift 2 ;;
      --no-apply)
        apply="no"; shift ;;
      *)
        fail "未知 entry expose-range 参数：${arg}"; return 1 ;;
    esac
  done
  if [[ "${start}" == "$ENTRY_EXPOSE_START_DEFAULT" && "${end}" == "$ENTRY_EXPOSE_END_DEFAULT" && -z "${relay_ip}" && "$apply" == "ask" ]]; then
    range="$(prompt_value "入口端口范围" "${ENTRY_EXPOSE_START_DEFAULT}-${ENTRY_EXPOSE_END_DEFAULT}")"
    parsed="$(parse_port_range "$range")" || return 1
    IFS=$'\t' read -r start end <<<"$parsed"
    relay_ip="$(prompt_value "Relay EasyTier IP" "$(current_relay_et_ip)")"
    prompt_yes_no "是否应用 nftables？" "Y" && apply="yes" || apply="no"
  fi
  if ! is_port "$start" || ! is_port "$end" || (( start > end )); then
    fail "入口端口范围非法：${start}-${end}"
    return 1
  fi
  conflict_ports=""
  if command -v ss >/dev/null 2>&1; then
    conflict_ports="$({
      ss -lntH 2>/dev/null
      ss -lunH 2>/dev/null
    } | awk -v s="$start" -v e="$end" '
      {
        p=$4
        sub(/^.*:/, "", p)
        if (p ~ /^[0-9]+$/ && p >= s && p <= e) seen[p]=1
      }
      END {
        for (p in seen) print p
      }
    ' | sort -n | awk '
      NR <= 12 { if (out=="") out=$1; else out=out "," $1 }
      NR == 13 { more=1 }
      END { if (more) out=out ",..."; print out }
    ')"
  fi
  if [[ -n "$conflict_ports" ]]; then
    warn "入口端口池 ${start}-${end} 中发现本机监听端口：${conflict_ports}"
    warn "如果继续，外部访问这些端口可能会被入口端口池 DNAT 接管，本机原服务可能无法从公网访问。"
    entry_expose_conflict_range_hint "$start" "$end" "$conflict_ports"
    prompt_yes_no "是否继续配置端口池？" "N" || return 0
  fi
  is_ipv4 "${relay_ip:-$RELAY_ET_IP}" || { fail "Relay EasyTier IP 非法：${relay_ip:-$RELAY_ET_IP}"; return 1; }
  relay_ip="${relay_ip:-$RELAY_ET_IP}"
  confirm_summary "配置公网入口端口池摘要" "ENTRY_EXPOSE_START=${start}\nENTRY_EXPOSE_END=${end}\nRELAY_ET_IP=${relay_ip}\n动作：A 侧把该端口池 TCP+UDP DNAT 到 Relay EasyTier IP，保持原端口不变。" || return 0
  write_file "$ENTRY_EXPOSE_ENV" "ENTRY_EXPOSE_START=${start}
ENTRY_EXPOSE_END=${end}
RELAY_ET_IP=${relay_ip}
ENABLED=true" 600
  if [[ "$apply" != "no" ]]; then
    apply_nft_rules "cloud-entry" || warn "公网入口 nftables 未应用成功，请检查后重试。"
  fi
  info "下一步：回到 B 利群主机，进入“利群主机 B”菜单。"
  info "如需指定 CN2 / 9929 出口，请先进入“IPv4 PBR 出口策略（PBR / 出口策略）”配置出口策略。"
  info "然后进入“转发目标管理（后端转发目标 / 转发管理）”添加后端目标。"
}

warn_forward_apply_ssh_risk() {
  APPLY_NFT_LAST_STATUS=""
  [[ -n "${SSH_CONNECTION:-}" ]] || return 0
  if ! is_interactive; then
    info "正在后台/非交互应用 nftables 转发规则。"
    return 0
  fi
  warn "正在重新应用 nftables 转发规则。"
  warn "如果当前 SSH 连接经过公网入口 / EasyTier / 转发链路，连接可能短暂中断。"
  info "如担心 SSH 断开，可使用："
  echo "nohup lq forward apply-relay --auto-fix-route >${APPLY_RELAY_LOG} 2>&1 &"
  if ! prompt_yes_no "是否继续前台执行？" "Y"; then
    APPLY_NFT_LAST_STATUS="skipped"
    info "已取消前台执行。"
    return 130
  fi
  return 0
}

nft_prepare_project_table_apply_file() {
  local content="$1" output="$2" chain
  : >"$output"
  if nft_project_table_exists; then
    printf '%s\n' 'flush table inet leikwan_forward' >>"$output"
    while IFS= read -r chain; do
      [[ -n "$chain" ]] || continue
      printf 'delete chain inet leikwan_forward %s\n' "$chain" >>"$output"
    done < <(nft_existing_project_chains)
  else
    printf '%s\n' 'add table inet leikwan_forward' >>"$output"
  fi
  awk '
    /^[[:space:]]*chain[[:space:]]+/ {
      chain = $2
      next
    }
    chain != "" && /^[[:space:]]*type[[:space:]]+/ {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      print "add chain inet leikwan_forward " chain " { " line " }"
      next
    }
    chain != "" && /^[[:space:]]*}/ {
      chain = ""
      next
    }
    chain != "" {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line != "" && line !~ /^[{}]/) {
        print "add rule inet leikwan_forward " chain " " line
      }
    }
  ' <<<"$content" >>"$output"
}

apply_relay_rules_background() {
  need_root_unless_dry_run
  local cmd=()
  if command -v lq >/dev/null 2>&1; then
    cmd=(lq forward apply-relay --auto-fix-route)
  else
    cmd=(bash "$(readlink -f "$0" 2>/dev/null || printf '%s' "$0")" forward apply-relay --auto-fix-route)
  fi
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] nohup ${cmd[*]} >${APPLY_RELAY_LOG} 2>&1 &"
    return 0
  fi
  nohup "${cmd[@]}" >"$APPLY_RELAY_LOG" 2>&1 &
  info "已后台执行，请稍后查看："
  echo "tail -f ${APPLY_RELAY_LOG}"
  info "后台执行完成后，可运行：lq --doctor"
}

apply_relay_rules_menu() {
  local choice
  while true; do
    print_menu_header "重新应用转发规则"
    echo "1. 前台执行"
    echo "2. 后台执行并写入 ${APPLY_RELAY_LOG}"
    echo "0. 返回"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) run_menu_action_pause apply_nft_rules "leikwan-relay" 1; return 0 ;;
      2) run_menu_action_pause apply_relay_rules_background; return 0 ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

apply_nft_rules() {
  local rc release_global_lock=0
  need_root_unless_dry_run
  if [[ -z "$LEIKWAN_GLOBAL_LOCK_TOKEN" ]]; then
    global_lock_acquire || return 1
    release_global_lock=1
  fi
  set +e
  apply_nft_rules_impl "$@"
  rc=$?
  set -e
  (( release_global_lock == 1 )) && global_lock_release
  return "$rc"
}

apply_nft_rules_impl() {
  local role="$1" auto_fix_route="${2:-0}" content tmp old enabled_count=-1 relay_ip start end proto
  local rollback
  APPLY_NFT_LAST_STATUS=""
  need_root_unless_dry_run
  install_packages nftables iproute2 || return 1
  configure_forward_sysctl || warn "IPv4 转发 sysctl 写入失败，请稍后手动检查。"
  case "$role" in
    cloud-entry)
      [[ -f "$ENTRY_EXPOSE_ENV" ]] || { warn "公网入口未配置：请粘贴转发接入码（推荐），或执行 lq entry expose-range"; return 1; }
      relay_ip="$(entry_expose_relay_ip)"
      if ! content="$(render_nft_cloud)"; then
        fail "公网入口 nftables 规则生成失败。"
        return 1
      fi
      if [[ "$(env_file_get "$ENTRY_EXPOSE_ENV" ENTRY_MODE)" == "bundle" ]]; then
        if ! grep -q "dnat ip to ${relay_ip}" <<<"$content"; then
          fail "公网入口接入码模式未生成 DNAT 规则，请在 B 重新生成接入码并重新导入。"
          return 1
        fi
      else
        start="$(entry_expose_start)"
        end="$(entry_expose_end)"
        for proto in tcp udp; do
          if ! grep -q "${proto} dport ${start}-${end} dnat ip to ${relay_ip}" <<<"$content"; then
            fail "入口端口池 ${start}-${end} 未生成 ${proto^^} DNAT 规则。"
            return 1
          fi
        done
      fi
      ;;
	    leikwan-relay)
	      enabled_count="$(enabled_forwards_count)" || return 1
	      sync_forward_routes_if_needed "$auto_fix_route" || warn "转发出口一致性检查未完成，将继续尝试应用规则。"
	      resolve_forwards || return 1
      if (( enabled_count == 0 )); then
        warn "当前没有任何启用的转发目标。"
        prompt_yes_no "当前没有任何启用的转发目标，是否仍然应用空规则？" "N" || return 0
      fi
      if (( enabled_count > 0 )) && ! resolved_rows | awk -F'\t' '$8=="true" && $4!="" {found=1} END{exit !found}'; then
        fail "没有可用的 resolved 转发规则，已停止应用 nftables。"
        return 1
      fi
      if ! content="$(render_nft_relay)"; then
        fail "利群转发 nftables 规则生成失败。"
        return 1
      fi
      if (( enabled_count > 0 )) && ! grep -q 'dnat ip to ' <<<"$content"; then
        fail "enabled forwards=${enabled_count}，但 relay nftables 未生成 DNAT 规则。"
        return 1
      fi
      warn_forward_apply_ssh_risk || return $?
      ;;
    *) fail "无法识别角色：${role}"; return 1 ;;
  esac
  case "$role" in
    leikwan-relay) auto_snapshot_or_confirm "apply-relay-nft" || return 1 ;;
    cloud-entry) auto_snapshot_or_confirm "apply-entry-nft" || return 1 ;;
  esac
  write_file "$NFT_RULE_FILE" "$content" 644
  write_file "$NFT_SERVICE" "$(render_nft_service)" 644
  (( DRY_RUN == 1 )) && return 0
  tmp="$(mktemp)"; old="$(mktemp)"; rollback="$(mktemp)"
  nft_prepare_project_table_apply_file "$content" "$tmp"
  if ! nft -c -f "$tmp"; then
    fail "nftables 规则校验失败。"
    rm -f "$tmp" "$old" "$rollback"
    return 1
  fi
  nft list table inet leikwan_forward >"$old" 2>/dev/null || true
  if nft -f "$tmp"; then
    if command -v systemctl >/dev/null 2>&1; then
      systemctl daemon-reload || warn "systemd daemon-reload 失败，请稍后手动检查。"
      systemctl enable "${NFT_SERVICE_NAME}.service" || warn "nftables 持久化服务启用失败，请稍后手动检查。"
    else
      warn "未找到 systemctl，nftables 已临时应用但无法创建持久化服务。"
    fi
    if (( enabled_count == 0 )); then
      warn "已应用空 nftables 项目表；当前没有转发 DNAT 规则。"
    elif [[ "$role" == "cloud-entry" ]]; then
      if [[ "$(env_file_get "$ENTRY_EXPOSE_ENV" ENTRY_MODE)" == "bundle" ]]; then
        ok "公网入口转发接入码 nftables 规则已应用。"
      else
        ok "公网入口端口池 nftables 规则已应用。"
      fi
    else
      ok "nftables 转发规则已应用。"
    fi
    if mss_clamp_enabled && nft_has_mss_clamp; then
      ok "已自动启用 TCP MSS clamp: $(tcp_mss_clamp_value)"
    fi
  else
    fail "nftables 应用失败，尝试回滚。"
    if [[ -s "$old" ]]; then
      nft_prepare_project_table_apply_file "$(cat "$old")" "$rollback"
      nft -f "$rollback" || true
    else
      nft delete table inet leikwan_forward 2>/dev/null || true
    fi
    rm -f "$tmp" "$old" "$rollback"
    return 1
  fi
  rm -f "$tmp" "$old" "$rollback"
  if [[ "$role" == "leikwan-relay" ]]; then
    write_status_cache apply ok "forward apply-relay"
  fi
}

nft_project_table_exists() {
  command -v nft >/dev/null 2>&1 || return 1
  nft list table inet leikwan_forward >/dev/null 2>&1
}

nft_show_rules() {
  if [[ -f "$NFT_RULE_FILE" ]]; then
    echo
    echo "${BOLD}脚本生成的 nftables 规则文件：${NFT_RULE_FILE}${RESET}"
    sed -n '1,200p' "$NFT_RULE_FILE"
  else
    warn "未找到 nftables 规则文件，请先配置公网入口端口池或利群转发目标。"
  fi
  if ! command -v nft >/dev/null 2>&1; then
    warn "系统未安装 nft 命令，无法读取当前内核规则。"
    return 0
  fi
  echo
  echo "${BOLD}当前内核中的项目 nftables 表：${RESET}"
  if nft_project_table_exists; then
    nft list table inet leikwan_forward || warn "读取 nftables 项目表失败。"
  else
    warn "当前未发现脚本生成的 nftables 表。"
  fi
}

cleanup_nftables_rules() {
  need_root_unless_dry_run
  echo
  echo "${BOLD}将清理以下脚本生成的 nftables 项：${RESET}"
  echo "- nft table inet leikwan_forward"
  echo "- ${NFT_RULE_FILE}"
  echo "- ${NFT_SERVICE}"
  prompt_yes_no "二次确认清理脚本生成的 nftables 规则？" "N" || return 0
  (( DRY_RUN == 1 )) && return 0
  if command -v systemctl >/dev/null 2>&1; then
    systemctl disable --now "${NFT_SERVICE_NAME}.service" 2>/dev/null || warn "nftables 持久化服务不存在或停止失败，继续清理文件。"
  else
    warn "未找到 systemctl，跳过服务停止。"
  fi
  if command -v nft >/dev/null 2>&1; then
    if nft_project_table_exists; then
      nft delete table inet leikwan_forward 2>/dev/null || warn "删除 nftables 项目表失败，请手动检查。"
    else
      warn "当前未发现脚本生成的 nftables 表。"
    fi
  else
    warn "系统未安装 nft 命令，跳过内核规则清理。"
  fi
  rm -f "$NFT_RULE_FILE" "$NFT_SERVICE"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload 2>/dev/null || warn "systemd daemon-reload 失败，请稍后手动检查。"
  fi
  ok "nftables 清理完成。"
}

nftables_menu() {
  local choice
  while true; do
    print_menu_header "nftables 规则管理"
    echo "1. 查看当前 nftables 规则"
    echo "2. 重新应用公网入口规则"
    echo "3. 重新应用转发规则"
    echo "4. 清理脚本生成的 nftables 规则"
    echo "0. 返回"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) run_menu_action_pause nft_show_rules ;;
      2) run_menu_action_pause apply_nft_rules "cloud-entry" || warn_and_pause "公网入口 nftables 规则未应用成功。" ;;
      3) run_menu_action_pause apply_nft_rules "leikwan-relay" || warn_and_pause "利群转发 nftables 规则未应用成功。" ;;
      4) run_menu_action_pause cleanup_nftables_rules ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

pbr_init_rt_tables() {
  if [[ ! -f "$PBR_RT_TABLES" ]]; then
    write_file "$PBR_RT_TABLES" $'255 local\n254 main\n253 default\n0 unspec' 644
  fi
}

pbr_domain_rows() {
  [[ -f "$PBR_DOMAIN_TSV" ]] || return 0
  awk -F'\t' '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    { gsub(/\r/, "") }
    NF == 0 { next }
    $1 ~ /^#/ { next }
    {
      name=trim($1)
      host=trim($2)
      route_table=trim($3)
      enabled=trim($4)
      comment=trim($5)
      if (name=="" || host=="" || route_table=="" || enabled=="") next
      printf "%s\t%s\t%s\t%s\t%s\n", name, host, route_table, enabled, comment
    }
  ' "$PBR_DOMAIN_TSV"
}

pbr_resolved_domain_rows() {
  [[ -f "$PBR_RESOLVED_DOMAIN_TSV" ]] || return 0
  awk -F'\t' '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    { gsub(/\r/, "") }
    NF == 0 { next }
    $1 ~ /^#/ { next }
    {
      name=trim($1)
      host=trim($2)
      resolved_ip=trim($3)
      route_table=trim($4)
      last_checked=trim($5)
      last_changed=trim($6)
      if (name=="" || host=="") next
      printf "%s\t%s\t%s\t%s\t%s\t%s\n", name, host, resolved_ip, route_table, last_checked, last_changed
    }
  ' "$PBR_RESOLVED_DOMAIN_TSV"
}

last_resolved_ip_for_pbr_domain() {
  local name="$1"
  pbr_resolved_domain_rows | awk -F'\t' -v n="$name" '$1==n && $3!="" {print $3; exit}'
}

last_resolved_changed_for_pbr_domain() {
  local name="$1"
  pbr_resolved_domain_rows | awk -F'\t' -v n="$name" '$1==n && $6!="" {print $6; exit}'
}

pbr_group_gateway() {
  case "$1" in
    T_9929|9929) printf '%s' "10.7.0.1" ;;
    T_CN2|CN2) printf '%s' "10.8.0.1" ;;
    T_JPSDWAN|JPSDWAN) printf '%s' "10.3.0.1" ;;
    T_DESDWAN|DESDWAN) printf '%s' "10.3.10.1" ;;
    T_KRSDWAN|KRSDWAN) printf '%s' "10.4.0.1" ;;
    T_HKSDWAN|HKSDWAN) printf '%s' "10.3.50.1" ;;
    T_TWSDWAN|TWSDWAN) printf '%s' "10.3.100.1" ;;
    *) return 1 ;;
  esac
}

pbr_table_id() {
  local group="$1"
  group="${group#T_}"
  case "$group" in
    9929) echo 101 ;; CN2) echo 102 ;; JPSDWAN) echo 103 ;; DESDWAN) echo 104 ;;
    KRSDWAN) echo 105 ;; HKSDWAN) echo 106 ;; TWSDWAN) echo 107 ;; *) return 1 ;;
  esac
}

pbr_refresh_dynamic_rules() {
  [[ -f "$PBR_STATIC_CONF" ]] || return 0
  local tmp line cidr group source_type source_name source_host _rest current_ip new_cidr changed=0
  tmp="$(make_state_tmp "$PBR_DIR" "pbr-static")" || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -z "$line" || "$line" == \#* ]]; then
      printf '%s\n' "$line" >>"$tmp"
      continue
    fi
    read -r cidr group source_type source_name source_host _rest <<<"$line"
    if [[ "$source_type" == "forward" && -n "$source_host" ]]; then
      if is_ipv4 "$source_host"; then
        new_cidr="${source_host}/32"
      else
        if resolve_domain_ipv4_for_forward_pbr "$source_host"; then
          current_ip="$RESOLVE_SELECTED_IP"
        else
          current_ip=""
        fi
        if [[ -z "$current_ip" ]]; then
          warn "PBR 来源转发 ${source_name} 的域名解析失败，继续使用当前规则：${cidr}"
          printf '%s\n' "$line" >>"$tmp"
          continue
        fi
        new_cidr="${current_ip}/32"
      fi
      if [[ "$new_cidr" != "$cidr" ]]; then
        info "PBR 来源转发 ${source_name} 解析变化：${cidr} -> ${new_cidr}"
        cidr="$new_cidr"
        changed=1
      fi
      printf '%s %s forward %s %s\n' "$cidr" "$group" "$source_name" "$source_host" >>"$tmp"
    else
      printf '%s\n' "$line" >>"$tmp"
    fi
  done <"$PBR_STATIC_CONF"
  if (( changed == 1 )); then
    write_file "$PBR_STATIC_CONF" "$(cat "$tmp")" 600
  fi
  rm -f "$tmp"
}

pbr_apply() {
  need_root_unless_dry_run
  local release_global_lock=0
  if [[ -z "$LEIKWAN_GLOBAL_LOCK_TOKEN" ]]; then
    global_lock_acquire || return 1
    release_global_lock=1
  fi
  pbr_init_rt_tables
  pbr_refresh_dynamic_rules
  if [[ ! -f "$PBR_STATIC_CONF" ]]; then
    warn "暂无 PBR 静态规则。"
    (( release_global_lock == 1 )) && global_lock_release
    return 0
  fi
  local line cidr group table_id gw table_name normalized apply_failed=0
  while ip rule del priority "$PBR_PRIORITY" 2>/dev/null; do :; done
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"
    line="$(normalize_menu_choice "$line")"
    [[ -n "$line" && "$line" != \#* ]] || continue
    if ! pbr_parse_rule_line "$line"; then
      warn "跳过无效 PBR 规则：${line}"
      continue
    fi
    if [[ "$PBR_RULE_ENABLED" == "false" ]]; then
      info "跳过 disabled PBR：${PBR_RULE_CIDR} -> ${PBR_RULE_TABLE}"
      continue
    fi
    cidr="$PBR_RULE_CIDR"
    group="$PBR_RULE_GROUP"
    normalized="$(normalize_ipv4_cidr "$cidr" 2>/dev/null || true)"
    if [[ -z "$normalized" ]]; then
      warn "跳过无效 PBR 目标：${cidr}"
      continue
    fi
    cidr="$normalized"
    group="${group#T_}"
    table_name="T_${group}"
    table_id="$(pbr_table_id "$group" 2>/dev/null || true)"
    if [[ -z "$table_id" ]]; then
      table_id="$(awk -v t="$table_name" '$2==t {print $1; exit}' "$PBR_RT_TABLES" 2>/dev/null || true)"
      [[ -n "$table_id" ]] || table_id="$table_name"
    fi
    gw="$(pbr_group_gateway "$group" 2>/dev/null || true)"
    if [[ "$table_id" =~ ^[0-9]+$ ]]; then
      grep -qE "^[[:space:]]*${table_id}[[:space:]]+${table_name}$" "$PBR_RT_TABLES" 2>/dev/null || echo "${table_id} ${table_name}" >>"$PBR_RT_TABLES"
    fi
    if [[ -n "$gw" ]]; then
      if ! ip route replace default via "$gw" table "$table_id" 2>/dev/null; then
        fail "PBR 路由表 ${table_name} 默认路由写入失败：via ${gw}"
        apply_failed=1
        continue
      fi
    fi
    if ! ip rule add to "$cidr" table "$table_id" priority "$PBR_PRIORITY" 2>/dev/null; then
      fail "PBR 应用失败：${cidr} -> ${table_name}"
      apply_failed=1
      continue
    fi
    ok "PBR：${cidr} -> ${table_name}"
  done <"$PBR_STATIC_CONF"
  (( release_global_lock == 1 )) && global_lock_release
  return "$apply_failed"
}

pbr_select_group() {
  local choice custom
  while true; do
    echo >&2
    echo "请选择线路组：" >&2
    echo "1. CN2 -> T_CN2" >&2
    echo "2. 9929 -> T_9929" >&2
    echo "3. 自定义路由表" >&2
    echo "0. 返回" >&2
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) printf '%s' "CN2"; return 0 ;;
      2) printf '%s' "9929"; return 0 ;;
      3)
        custom="$(prompt_value "请输入自定义 route_table，例如 T_HKSDWAN")"
        custom="${custom#T_}"
        [[ -n "$custom" ]] || { warn "route_table 不能为空。"; continue; }
        printf '%s' "$custom"
        return 0
        ;;
      0|"") return 1 ;;
      *) echo "无效选择，请重新输入。" >&2 ;;
    esac
  done
}

pbr_metadata_value() {
  local meta="$1" key="$2" token
  if [[ "$key" == "remark" ]]; then
    case "$meta" in
      *"remark="*) printf '%s' "${meta#*remark=}" ;;
    esac
    return 0
  fi
  for token in $meta; do
    case "$token" in
      "${key}="*) printf '%s' "${token#*=}"; return 0 ;;
    esac
  done
}

pbr_parse_rule_line() {
  local line="$1" cidr group source_type source_name source_host rest meta
  PBR_RULE_RAW="$(normalize_menu_choice "${line//$'\r'/}")"
  PBR_RULE_CIDR=""
  PBR_RULE_GROUP=""
  PBR_RULE_TABLE=""
  PBR_RULE_SOURCE_TYPE="static"
  PBR_RULE_SOURCE_NAME=""
  PBR_RULE_SOURCE_HOST=""
  PBR_RULE_SOURCE_DISPLAY="static"
  PBR_RULE_IFACE=""
  PBR_RULE_ENABLED="true"
  PBR_RULE_REMARK=""
  read -r cidr group source_type source_name source_host rest <<<"$PBR_RULE_RAW"
  [[ -n "$cidr" && -n "$group" ]] || return 1
  PBR_RULE_CIDR="$(normalize_ipv4_cidr "$cidr" 2>/dev/null || printf '%s' "$cidr")"
  PBR_RULE_GROUP="${group#T_}"
  PBR_RULE_TABLE="T_${PBR_RULE_GROUP}"
  case "${source_type:-}" in
    "")
      meta=""
      ;;
    static)
      meta="$(normalize_menu_choice "${source_name:-} ${source_host:-} ${rest:-}")"
      ;;
    forward)
      PBR_RULE_SOURCE_TYPE="forward"
      PBR_RULE_SOURCE_NAME="${source_name:-}"
      PBR_RULE_SOURCE_HOST="${source_host:-}"
      PBR_RULE_SOURCE_DISPLAY="forward:${PBR_RULE_SOURCE_NAME}"
      [[ -n "$PBR_RULE_SOURCE_HOST" ]] && PBR_RULE_SOURCE_DISPLAY="${PBR_RULE_SOURCE_DISPLAY} ${PBR_RULE_SOURCE_HOST}"
      meta="${rest:-}"
      ;;
    pbr-domain:*)
      PBR_RULE_SOURCE_TYPE="pbr-domain"
      PBR_RULE_SOURCE_NAME="${source_type#pbr-domain:}"
      PBR_RULE_SOURCE_HOST="${source_name:-}"
      PBR_RULE_SOURCE_DISPLAY="pbr-domain:${PBR_RULE_SOURCE_NAME}"
      [[ -n "$PBR_RULE_SOURCE_HOST" ]] && PBR_RULE_SOURCE_DISPLAY="${PBR_RULE_SOURCE_DISPLAY} ${PBR_RULE_SOURCE_HOST}"
      meta="$(normalize_menu_choice "${source_host:-} ${rest:-}")"
      ;;
    *)
      PBR_RULE_SOURCE_TYPE="$source_type"
      PBR_RULE_SOURCE_NAME="${source_name:-}"
      PBR_RULE_SOURCE_HOST="${source_host:-}"
      PBR_RULE_SOURCE_DISPLAY="$source_type"
      [[ -n "$source_name" ]] && PBR_RULE_SOURCE_DISPLAY="${PBR_RULE_SOURCE_DISPLAY} ${source_name}"
      [[ -n "$source_host" ]] && PBR_RULE_SOURCE_DISPLAY="${PBR_RULE_SOURCE_DISPLAY} ${source_host}"
      meta="${rest:-}"
      ;;
  esac
  PBR_RULE_IFACE="$(pbr_metadata_value "$meta" iface)"
  PBR_RULE_ENABLED="$(pbr_metadata_value "$meta" enabled)"
  case "${PBR_RULE_ENABLED,,}" in
    false|0|no|n) PBR_RULE_ENABLED="false" ;;
    *) PBR_RULE_ENABLED="true" ;;
  esac
  PBR_RULE_REMARK="$(pbr_metadata_value "$meta" remark)"
}

pbr_render_rule_line() {
  local cidr="$1" group="$2" source_type="${3:-static}" source_name="${4:-}" source_host="${5:-}" iface="${6:-}" enabled="${7:-true}" remark="${8:-}"
  local line
  group="${group#T_}"
  line="${cidr} ${group}"
  case "$source_type" in
    forward) line="${line} forward ${source_name} ${source_host}" ;;
    pbr-domain) line="${line} pbr-domain:${source_name} ${source_host}" ;;
    *) line="${line} static" ;;
  esac
  iface="$(normalize_menu_choice "$iface")"
  enabled="$(normalize_menu_choice "$enabled")"
  remark="${remark//$'\r'/ }"
  remark="${remark//$'\n'/ }"
  remark="$(normalize_menu_choice "$remark")"
  [[ -n "$iface" ]] && line="${line} iface=${iface}"
  case "${enabled,,}" in
    false|0|no|n) line="${line} enabled=false" ;;
    *) line="${line} enabled=true" ;;
  esac
  [[ -n "$remark" ]] && line="${line} remark=${remark}"
  printf '%s\n' "$line"
}

pbr_write_rule_line() {
  local line_no="$1" new_line="$2" tmp
  tmp="$(mktemp)"
  awk -v target="$line_no" -v replacement="$new_line" 'NR == target { print replacement; next } { print }' "$PBR_STATIC_CONF" >"$tmp"
  write_file "$PBR_STATIC_CONF" "$(cat "$tmp")" 600
  rm -f "$tmp"
}

pbr_add_static() {
  need_root_unless_dry_run
  local cidr group input
  while true; do
    input="$(prompt_value "目标 IP/CIDR")"
    cidr="$(normalize_ipv4_cidr "$input" 2>/dev/null || true)"
    [[ -n "$cidr" ]] && break
    if [[ "$input" =~ [A-Za-z] ]]; then
      warn '静态 PBR 只接受 IPv4 或 CIDR。如果要给域名 / DDNS 添加 PBR，请选择“从现有转发目标添加 PBR”。'
    else
      warn "目标 IP/CIDR 无效，请重新输入。"
    fi
  done
  group="$(pbr_select_group)" || return 0
  mkdir -p "$PBR_DIR"
  grep -qxF "${cidr} ${group#T_}" "$PBR_STATIC_CONF" 2>/dev/null || echo "${cidr} ${group#T_}" >>"$PBR_STATIC_CONF"
  pbr_apply
  info "如果这个目标已经存在转发规则，请执行：lq forward apply-relay --auto-fix-route"
}

pbr_add_from_forward() {
  need_root_unless_dry_run
  ensure_tsv_files >/dev/null
  local name row target_host target_ip group cidr
  name="$(select_forward_name enabled "可用于 PBR 的转发目标：")" || return 0
  row="$(forwards_rows | awk -F'\t' -v n="$name" '$1==n {print; exit}')"
  [[ -n "$row" ]] || { warn "转发目标不存在：${name}"; return 0; }
  target_host="$(awk -F'\t' '{print $3}' <<<"$row")"
  if resolve_domain_ipv4_for_pbr "$target_host"; then
    target_ip="$RESOLVE_SELECTED_IP"
  else
    target_ip=""
  fi
  if [[ -z "$target_ip" ]]; then
    warn "无法解析转发目标 ${name}：${target_host}"
    return 0
  fi
  group="$(pbr_select_group)" || return 0
  cidr="${target_ip}/32"
  mkdir -p "$PBR_DIR"
  if grep -qE "^[[:space:]]*${cidr//./\\.}[[:space:]]+${group#T_}([[:space:]]|$)" "$PBR_STATIC_CONF" 2>/dev/null; then
    warn "PBR 已存在：${cidr} -> T_${group#T_}"
  else
    printf '%s %s forward %s %s\n' "$cidr" "${group#T_}" "$name" "$target_host" >>"$PBR_STATIC_CONF"
    ok "已从转发目标添加 PBR：${name} ${target_host}(${target_ip}) -> T_${group#T_}"
  fi
  if pbr_apply; then
    if prompt_yes_no "是否立即重新应用转发规则并同步 route_table？" "Y"; then
      if apply_nft_rules "leikwan-relay" 1; then
        ok "已重新应用转发规则并同步 route_table 元数据。"
      else
        warn "PBR 已添加，但转发规则重新应用失败；请稍后执行：lq forward apply-relay --auto-fix-route"
      fi
    else
      info "PBR 已添加。请稍后执行：lq forward apply-relay --auto-fix-route 以同步转发目标元数据。"
    fi
  else
    warn "PBR 已写入，但应用失败；请稍后执行：lq pbr apply"
  fi
}

pbr_rows() {
  [[ -f "$PBR_STATIC_CONF" ]] || return 0
  local line line_no=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))
    line="${line//$'\r'/}"
    line="$(normalize_menu_choice "$line")"
    [[ -n "$line" && "$line" != \#* ]] || continue
    pbr_parse_rule_line "$line" || continue
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$line_no" "$PBR_RULE_CIDR" "$PBR_RULE_TABLE" "$PBR_RULE_SOURCE_DISPLAY" \
      "${PBR_RULE_IFACE:-"-"}" "$PBR_RULE_ENABLED" "${PBR_RULE_REMARK:-"-"}"
  done <"$PBR_STATIC_CONF"
}

pbr_rules_count() {
  pbr_rows | awk 'END{print NR+0}'
}

display_pbr_rules() {
  local numbered="${1:-no}" title="${2:-}" labels
  [[ -n "$title" ]] && { echo; echo "$title"; }
  labels=$'编号\t目标网段\t路由表\t来源\t出口接口\t启用\t备注'
  if [[ "$numbered" == "numbered" ]]; then
    pbr_rows | awk -F'\t' '{printf "%d.\t%s\t%s\t%s\t%s\t%s\t%s\n", ++i, $2, $3, $4, $5, $6, $7}' | render_tsv_table 120 "$labels"
  else
    pbr_rows | awk -F'\t' '{printf "%d.\t%s\t%s\t%s\t%s\t%s\t%s\n", ++i, $2, $3, $4, $5, $6, $7}' | render_tsv_table 120 "$labels"
  fi
}

pbr_show() {
  local count
  echo
  count="$(pbr_rules_count)"
  if (( count == 0 )); then
    info "当前没有 PBR 规则。"
    return 0
  fi
  display_pbr_rules
}

resolve_pbr_rule_selection() {
  local choice="$1" selected target count
  choice="$(normalize_menu_choice "$choice")"
  [[ -n "$choice" ]] || return 1
  if [[ "$choice" =~ ^[0-9]+$ ]]; then
    selected="$(pbr_rows | awk -F'\t' -v idx="$choice" 'NR==idx {print; exit}')"
    [[ -n "$selected" ]] || return 2
  else
    target="$(normalize_ipv4_cidr "$choice" 2>/dev/null || true)"
    [[ -n "$target" ]] || target="$choice"
    selected="$(pbr_rows | awk -F'\t' -v cidr="$target" '$2==cidr {print}')"
    count="$(printf '%s\n' "$selected" | awk 'NF {c++} END{print c+0}')"
    (( count > 0 )) || return 4
    (( count == 1 )) || return 3
  fi
  printf '%s\n' "$selected"
}

warn_pbr_selection_error() {
  local rc="$1" choice="$2"
  case "$rc" in
    2) warn "编号无效，请重新选择。" ;;
    3) warn "同一目标网段存在多条 PBR 规则，请输入编号精确选择。" ;;
    *) warn "PBR 规则不存在：${choice}" ;;
  esac
}

select_pbr_rule() {
  local action="${1:-删除}" choice selected rc count
  count="$(pbr_rules_count)"
  if (( count == 0 )); then
    warn "当前没有 PBR 规则可${action}。" >&2
    return 1
  fi
  display_pbr_rules numbered "当前 PBR 规则：" >&2
  echo >&2
  while true; do
    choice="$(prompt_value "请输入编号或目标网段，直接回车返回")"
    [[ -z "$choice" ]] && return 1
    if selected="$(resolve_pbr_rule_selection "$choice")"; then
      printf '%s\n' "$selected"
      return 0
    else
      rc=$?
      warn_pbr_selection_error "$rc" "$choice" >&2
    fi
  done
}

delete_pbr_rule() {
  need_root_unless_dry_run
  local selection="${1:-}" selected rc line_no cidr table _source tmp count
  count="$(pbr_rules_count)"
  if (( count == 0 )); then
    warn "当前没有 PBR 规则可删除。"
    return 0
  fi
  if [[ -n "$selection" ]]; then
    if selected="$(resolve_pbr_rule_selection "$selection")"; then
      :
    else
      rc=$?
      warn_pbr_selection_error "$rc" "$selection"
      return 0
    fi
  else
    selected="$(select_pbr_rule "删除")" || return 0
  fi
  IFS=$'\t' read -r line_no cidr table _source <<<"$selected"
  prompt_yes_no "确认删除 PBR 规则 ${cidr} -> ${table}？" "N" || return 0
  auto_snapshot_or_confirm "delete-pbr-rule" || return 0
  tmp="$(mktemp)"
  awk -v del="$line_no" 'NR != del {print}' "$PBR_STATIC_CONF" >"$tmp"
  write_file "$PBR_STATIC_CONF" "$(cat "$tmp")" 600
  rm -f "$tmp"
  ok "已删除 PBR 规则：${cidr} -> ${table}"
  if pbr_apply; then
    ok "PBR 已重新应用"
  else
    warn "PBR 规则已删除，但重新应用失败。请稍后执行 PBR -> 应用 PBR。"
  fi
}

pbr_edit_rule() {
  need_root_unless_dry_run
  local selection="${1:-}" selected rc line_no cidr table source iface enabled remark raw_line
  local old_cidr old_group old_table old_source_type old_source_name old_source_host old_iface old_enabled old_remark
  local new_cidr new_table new_group new_iface new_enabled new_remark new_line release_global_lock=0
  local convert_to_static=0 forward_source=0 count
  count="$(pbr_rules_count)"
  if (( count == 0 )); then
    warn "当前没有 PBR 规则可修改。"
    return 0
  fi
  if [[ -n "$selection" ]]; then
    if selected="$(resolve_pbr_rule_selection "$selection")"; then
      :
    else
      rc=$?
      warn_pbr_selection_error "$rc" "$selection"
      return 0
    fi
  else
    selected="$(select_pbr_rule "修改")" || return 0
  fi
  IFS=$'\t' read -r line_no cidr table source iface enabled remark <<<"$selected"
  raw_line="$(sed -n "${line_no}p" "$PBR_STATIC_CONF" 2>/dev/null || true)"
  if ! pbr_parse_rule_line "$raw_line"; then
    warn "PBR 规则解析失败，已取消修改：${raw_line}"
    return 1
  fi
  old_cidr="$PBR_RULE_CIDR"
  old_group="$PBR_RULE_GROUP"
  old_table="$PBR_RULE_TABLE"
  old_source_type="$PBR_RULE_SOURCE_TYPE"
  old_source_name="$PBR_RULE_SOURCE_NAME"
  old_source_host="$PBR_RULE_SOURCE_HOST"
  old_iface="$PBR_RULE_IFACE"
  old_enabled="$PBR_RULE_ENABLED"
  old_remark="$PBR_RULE_REMARK"

  echo
  echo "当前 PBR 规则："
  echo "目标网段: ${old_cidr}"
  echo "出口接口: ${old_iface:-"-"}"
  echo "路由表: ${old_table}"
  echo "来源: ${PBR_RULE_SOURCE_DISPLAY}"
  echo "启用: ${old_enabled}"
  echo "备注: ${old_remark:-"-"}"

  if [[ "$old_source_type" == "forward" ]]; then
    forward_source=1
    warn "这是从转发目标生成的 PBR。"
    info "目标 IP 会跟随转发目标解析自动同步。"
    info "如需修改后端域名、端口、出口接口或路由表，建议进入“转发目标管理 -> 修改转发目标”。"
    if prompt_yes_no "是否转为静态 PBR？" "N"; then
      prompt_yes_no "确认转为静态 PBR，并停止跟随转发目标同步？" "N" || return 0
      convert_to_static=1
    else
      warn "forward 来源 PBR 默认不允许直接修改目标 CIDR。"
      info "可修改备注，但可能在后续同步时被覆盖。"
      new_remark="$(prompt_value "备注" "$old_remark")"
      new_line="$(pbr_render_rule_line "$old_cidr" "$old_group" "forward" "$old_source_name" "$old_source_host" "$old_iface" "$old_enabled" "$new_remark")"
      confirm_summary "修改 forward 来源 PBR 备注" "目标：${old_cidr}\n路由表：${old_table}\n来源：forward:${old_source_name} ${old_source_host}\n备注：${new_remark:-"-"}" || return 0
      if [[ -z "$LEIKWAN_GLOBAL_LOCK_TOKEN" ]]; then
        global_lock_acquire || return 1
        release_global_lock=1
      fi
      auto_snapshot_or_confirm "edit-pbr-rule" || { (( release_global_lock == 1 )) && global_lock_release; return 0; }
      pbr_write_rule_line "$line_no" "$new_line"
      (( release_global_lock == 1 )) && global_lock_release
      ok "PBR 规则已修改。"
      info "修改已保存。请执行“应用 PBR”使规则生效。"
      return 0
    fi
  fi

  if (( forward_source == 0 )) && [[ "$old_source_type" != "static" ]]; then
    warn "这是由 ${PBR_RULE_SOURCE_DISPLAY} 生成的 PBR。"
    info "请使用对应管理入口修改，或删除后新增静态 PBR。"
    return 0
  fi

  if (( forward_source == 1 && convert_to_static == 1 )); then
    new_cidr="$old_cidr"
    new_table="$old_table"
    new_iface="$old_iface"
  else
    while true; do
      new_cidr="$(prompt_value "目标 CIDR/IP" "$old_cidr")"
      new_cidr="$(normalize_ipv4_cidr "$new_cidr" 2>/dev/null || true)"
      [[ -n "$new_cidr" ]] && break
      warn "目标 IP/CIDR 无效，请重新输入。"
    done
    new_table="$(prompt_value "路由表 route_table" "$old_table")"
    new_table="$(normalize_menu_choice "$new_table")"
    [[ -n "$new_table" ]] || new_table="$old_table"
    new_iface="$(prompt_value "出口接口 out_iface" "$old_iface")"
  fi
  new_group="${new_table#T_}"
  [[ -n "$new_group" ]] || new_group="$old_group"
  new_iface="$(normalize_menu_choice "$new_iface")"
  new_remark="$(prompt_value "备注" "$old_remark")"
  new_enabled="$(prompt_enabled_value "是否启用 PBR 规则？" "$old_enabled")"
  new_line="$(pbr_render_rule_line "$new_cidr" "$new_group" "static" "" "" "$new_iface" "$new_enabled" "$new_remark")"

  confirm_summary "修改 PBR 规则摘要" "目标：${old_cidr} -> ${new_cidr}\n出口接口：${old_iface:-"-"} -> ${new_iface:-"-"}\n路由表：${old_table} -> T_${new_group}\n来源：${source} -> static\n启用：${old_enabled} -> ${new_enabled}\n备注：${old_remark:-"-"} -> ${new_remark:-"-"}" || return 0
  if [[ -z "$LEIKWAN_GLOBAL_LOCK_TOKEN" ]]; then
    global_lock_acquire || return 1
    release_global_lock=1
  fi
  auto_snapshot_or_confirm "edit-pbr-rule" || { (( release_global_lock == 1 )) && global_lock_release; return 0; }
  pbr_write_rule_line "$line_no" "$new_line"
  (( release_global_lock == 1 )) && global_lock_release
  ok "PBR 规则已修改。"
  info "修改已保存。请执行“应用 PBR”使规则生效。"
  info "可返回“IPv4 PBR 出口策略”选择“应用 PBR”。"
}

pbr_edit_rule_menu() {
  pbr_edit_rule "${1:-}"
}

pbr_rule_key_exists() {
  local file="$1" cidr="$2" group="$3"
  [[ -f "$file" ]] || return 1
  awk -v cidr="$cidr" -v group="${group#T_}" '
    /^[[:space:]]*($|#)/ { next }
    {
      g=$2
      sub(/^T_/, "", g)
      if ($1 == cidr && g == group) found=1
    }
    END { exit found ? 0 : 1 }
  ' "$file"
}

pbr_domain_source_exists() {
  local file="$1" name="$2"
  [[ -f "$file" ]] || return 1
  awk -v src="pbr-domain:${name}" '
    /^[[:space:]]*($|#)/ { next }
    $3 == src { found=1 }
    END { exit found ? 0 : 1 }
  ' "$file"
}

replace_pbr_domain_row() {
  local row="$1" name tmp
  IFS=$'\t' read -r name _ <<<"$row"
  ensure_tsv_files
  tmp="$(mktemp)"
  awk -F'\t' -v n="$name" '$1==n {next} {print}' "$PBR_DOMAIN_TSV" >"$tmp"
  printf '%s\n' "$row" >>"$tmp"
  write_file "$PBR_DOMAIN_TSV" "$(cat "$tmp")" 600
  rm -f "$tmp"
}

display_pbr_domains() {
  local labels
  labels=$'编号\t名称\t域名\t路由表\t启用\t备注'
  pbr_domain_rows | awk -F'\t' '{printf "%d.\t%s\t%s\t%s\t%s\t%s\n", ++i, $1, $2, $3, $4, ($5!="" ? $5 : "-")}' | render_tsv_table 100 "$labels"
}

pbr_domain_list() {
  if ! pbr_domain_rows | awk 'NR==1 {found=1} END{exit !found}'; then
    info "当前没有域名 PBR。"
    info "从转发目标添加的 PBR 会显示在“查看 PBR”中，来源形如 forward:name domain。"
    return 0
  fi
  display_pbr_domains
}

select_pbr_domain_name() {
  local choice name
  if ! pbr_domain_rows | awk 'NR==1 {found=1} END{exit !found}'; then
    warn "当前没有域名 PBR。" >&2
    return 1
  fi
  display_pbr_domains >&2
  while true; do
    choice="$(prompt_value "请输入编号或名称，直接回车返回")"
    [[ -z "$choice" ]] && return 1
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
      name="$(pbr_domain_rows | awk -F'\t' -v idx="$choice" 'NR==idx {print $1; exit}')"
    else
      name="$(pbr_domain_rows | awk -F'\t' -v n="$choice" '$1==n {print $1; exit}')"
    fi
    [[ -n "$name" ]] && { printf '%s' "$name"; return 0; }
    warn "域名 PBR 不存在：${choice}" >&2
  done
}

pbr_domain_refresh_cache_only() {
  need_root_unless_dry_run
  ensure_tsv_files >/dev/null
  local tmp_resolved checked_at name host route_table enabled comment old_ip new_ip old_changed last_changed
  local candidates=0 failed=0 changed=0
  PBR_DOMAIN_SYNC_CHANGED_NAMES=""
  PBR_DOMAIN_SYNC_FAILED_NAMES=""
  PBR_DOMAIN_SYNC_RECENT_EVENTS=""
  tmp_resolved="$(make_state_tmp "$PBR_DIR" "resolved-pbr-domains")" || return 1
  checked_at="$(status_now)"
  printf '# name\thost\tresolved_ip\troute_table\tlast_checked\tlast_changed\n' >"$tmp_resolved"
  while IFS=$'\t' read -r name host route_table enabled comment; do
    old_ip="$(last_resolved_ip_for_pbr_domain "$name")"
    old_changed="$(last_resolved_changed_for_pbr_domain "$name")"
    if [[ "$enabled" != "true" ]]; then
      [[ -n "$old_ip" ]] && printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$host" "$old_ip" "$route_table" "$checked_at" "${old_changed:-$checked_at}" >>"$tmp_resolved"
      continue
    fi
    candidates=$((candidates + 1))
    if ! is_domain_name "$host"; then
      ddns_emit WARN "域名 PBR ${name} 的 host 不是域名：${host}"
      failed=$((failed + 1))
      PBR_DOMAIN_SYNC_FAILED_NAMES="${PBR_DOMAIN_SYNC_FAILED_NAMES:+${PBR_DOMAIN_SYNC_FAILED_NAMES},}${name}"
      continue
    fi
    if resolve_domain_ipv4_multi "$host"; then
      new_ip="$RESOLVE_SELECTED_IP"
    else
      new_ip=""
    fi
    if [[ -z "$new_ip" ]]; then
      failed=$((failed + 1))
      PBR_DOMAIN_SYNC_FAILED_NAMES="${PBR_DOMAIN_SYNC_FAILED_NAMES:+${PBR_DOMAIN_SYNC_FAILED_NAMES},}${name}"
      if [[ -n "$old_ip" ]]; then
        ddns_emit WARN "域名 PBR ${name} 解析失败，保留旧 IP：${old_ip}"
        new_ip="$old_ip"
        last_changed="${old_changed:-$checked_at}"
      else
        ddns_emit WARN "域名 PBR ${name} 解析失败，且没有旧 IP：${host}"
        continue
      fi
    elif [[ -n "$old_ip" && "$old_ip" == "$new_ip" ]]; then
      ddns_emit OK "域名 PBR ${name} 解析未变化：${new_ip}"
      last_changed="${old_changed:-$checked_at}"
    else
      changed=$((changed + 1))
      PBR_DOMAIN_SYNC_CHANGED_NAMES="${PBR_DOMAIN_SYNC_CHANGED_NAMES:+${PBR_DOMAIN_SYNC_CHANGED_NAMES},}${name}"
      ddns_emit WARN "域名 PBR ${name} 解析变化：${old_ip:-none} -> ${new_ip}"
      if [[ -z "$old_ip" ]]; then
        PBR_DOMAIN_SYNC_RECENT_EVENTS="${PBR_DOMAIN_SYNC_RECENT_EVENTS}${PBR_DOMAIN_SYNC_RECENT_EVENTS:+;}${name}: 初次记录 ${new_ip}"
      else
        PBR_DOMAIN_SYNC_RECENT_EVENTS="${PBR_DOMAIN_SYNC_RECENT_EVENTS}${PBR_DOMAIN_SYNC_RECENT_EVENTS:+;}${name}: ${old_ip:-none} -> ${new_ip}"
      fi
      last_changed="$checked_at"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$host" "$new_ip" "$route_table" "$checked_at" "$last_changed" >>"$tmp_resolved"
  done < <(pbr_domain_rows)
  write_file_from_path "$PBR_RESOLVED_DOMAIN_TSV" "$tmp_resolved" 600
  rm -f "$tmp_resolved"
  DDNS_PBR_CHANGED="$PBR_DOMAIN_SYNC_CHANGED_NAMES"
  DDNS_PBR_FAILED="$PBR_DOMAIN_SYNC_FAILED_NAMES"
  DDNS_PBR_CHANGED_COUNT="$changed"
  DDNS_PBR_FAILED_COUNT="$failed"
  DDNS_PBR_RECENT_EVENTS="$PBR_DOMAIN_SYNC_RECENT_EVENTS"
  if (( candidates == 0 )); then
    ddns_emit INFO "没有 enabled 域名 PBR 需要刷新缓存。"
  else
    ddns_emit INFO "域名 PBR 缓存刷新完成：enabled=${candidates}，changed=${changed}，failed=${failed}。"
  fi
  (( failed == 0 ))
}

pbr_domain_sync() {
  need_root_unless_dry_run
  ensure_tsv_files >/dev/null
  local no_apply=1 from_ddns=0 arg acquired_lock=0
  while (($# > 0)); do
    arg="$1"
    case "$arg" in
      --apply) no_apply=0; shift ;;
      --no-apply) no_apply=1; shift ;;
      --from-ddns) from_ddns=1; no_apply=1; shift ;;
      *) fail "未知 pbr domain sync 参数：${arg}"; return 1 ;;
    esac
  done
  if [[ -z "$LEIKWAN_GLOBAL_LOCK_TOKEN" ]]; then
    global_lock_acquire || return 0
    acquired_lock=1
  fi
  local tmp_static tmp_resolved checked_at name host route_table enabled comment old_ip new_ip old_changed last_changed
  local cidr group candidates=0 synced=0 skipped=0 failed=0 changed=0 rc=0
  PBR_DOMAIN_SYNC_CHANGED_NAMES=""
  PBR_DOMAIN_SYNC_FAILED_NAMES=""
  PBR_DOMAIN_SYNC_RECENT_EVENTS=""
  mkdir -p "$PBR_DIR"
  [[ -f "$PBR_STATIC_CONF" ]] || : >"$PBR_STATIC_CONF"
  tmp_static="$(make_state_tmp "$PBR_DIR" "static-routes")" || {
    (( acquired_lock == 1 )) && global_lock_release
    return 1
  }
  tmp_resolved="$(make_state_tmp "$PBR_DIR" "resolved-pbr-domains")" || {
    rm -f "$tmp_static"
    (( acquired_lock == 1 )) && global_lock_release
    return 1
  }
  checked_at="$(status_now)"
  awk '
    /^[[:space:]]*($|#)/ { print; next }
    $3 ~ /^pbr-domain:/ { next }
    { print }
  ' "$PBR_STATIC_CONF" >"$tmp_static"
  printf '# name\thost\tresolved_ip\troute_table\tlast_checked\tlast_changed\n' >"$tmp_resolved"
  while IFS=$'\t' read -r name host route_table enabled comment; do
    old_ip="$(last_resolved_ip_for_pbr_domain "$name")"
    old_changed="$(last_resolved_changed_for_pbr_domain "$name")"
    if [[ "$enabled" != "true" ]]; then
      [[ -n "$old_ip" ]] && printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$host" "$old_ip" "$route_table" "$checked_at" "${old_changed:-$checked_at}" >>"$tmp_resolved"
      continue
    fi
    candidates=$((candidates + 1))
    if ! is_domain_name "$host"; then
      warn "域名 PBR ${name} 的 host 不是域名：${host}"
      failed=$((failed + 1))
      PBR_DOMAIN_SYNC_FAILED_NAMES="${PBR_DOMAIN_SYNC_FAILED_NAMES:+${PBR_DOMAIN_SYNC_FAILED_NAMES},}${name}"
      continue
    fi
    if resolve_domain_ipv4_multi "$host"; then
      new_ip="$RESOLVE_SELECTED_IP"
    else
      new_ip=""
    fi
    if [[ -z "$new_ip" ]]; then
      failed=$((failed + 1))
      PBR_DOMAIN_SYNC_FAILED_NAMES="${PBR_DOMAIN_SYNC_FAILED_NAMES:+${PBR_DOMAIN_SYNC_FAILED_NAMES},}${name}"
      if [[ -n "$old_ip" ]]; then
        warn "域名 PBR ${name} 解析失败，保留旧 IP：${old_ip}"
        new_ip="$old_ip"
        last_changed="${old_changed:-$checked_at}"
      else
        warn "域名 PBR ${name} 解析失败，且没有旧 IP：${host}"
        continue
      fi
    elif [[ -n "$old_ip" && "$old_ip" == "$new_ip" ]]; then
      ok "域名 PBR ${name} 解析未变化：${new_ip}"
      last_changed="${old_changed:-$checked_at}"
    else
      changed=$((changed + 1))
      PBR_DOMAIN_SYNC_CHANGED_NAMES="${PBR_DOMAIN_SYNC_CHANGED_NAMES:+${PBR_DOMAIN_SYNC_CHANGED_NAMES},}${name}"
      warn "域名 PBR ${name} 解析变化：${old_ip:-none} -> ${new_ip}"
      if [[ -z "$old_ip" ]]; then
        PBR_DOMAIN_SYNC_RECENT_EVENTS="${PBR_DOMAIN_SYNC_RECENT_EVENTS}${PBR_DOMAIN_SYNC_RECENT_EVENTS:+;}${name}: 初次记录 ${new_ip}"
      else
        PBR_DOMAIN_SYNC_RECENT_EVENTS="${PBR_DOMAIN_SYNC_RECENT_EVENTS}${PBR_DOMAIN_SYNC_RECENT_EVENTS:+;}${name}: ${old_ip:-none} -> ${new_ip}"
      fi
      last_changed="$checked_at"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$host" "$new_ip" "$route_table" "$checked_at" "$last_changed" >>"$tmp_resolved"
    cidr="${new_ip}/32"
    group="${route_table#T_}"
    if pbr_rule_key_exists "$tmp_static" "$cidr" "$group"; then
      skipped=$((skipped + 1))
      info "已存在同 CIDR/table 的非域名 PBR，跳过 pbr-domain:${name} ${cidr} -> T_${group}"
      continue
    fi
    printf '%s %s pbr-domain:%s %s\n' "$cidr" "$group" "$name" "$host" >>"$tmp_static"
    synced=$((synced + 1))
  done < <(pbr_domain_rows)
  write_file_from_path "$PBR_RESOLVED_DOMAIN_TSV" "$tmp_resolved" 600
  write_file_from_path "$PBR_STATIC_CONF" "$tmp_static" 600
  rm -f "$tmp_static" "$tmp_resolved"
  if (( candidates == 0 )); then
    info "没有 enabled 域名 PBR 需要同步。"
  else
    info "域名 PBR 同步完成：enabled=${candidates}，写入=${synced}，已有=${skipped}，changed=${changed}，failed=${failed}。"
  fi
  if (( no_apply == 0 )); then
    pbr_apply || rc=1
  elif (( from_ddns == 0 )); then
    info "如需立即生效，请执行：lq --pbr-apply"
  fi
  (( acquired_lock == 1 )) && global_lock_release
  (( rc == 0 )) || return "$rc"
  (( failed == 0 ))
}

pbr_domain_add() {
  need_root_unless_dry_run
  ensure_tsv_files >/dev/null
  local name host group route_table enabled comment row resolved
  name="$(safe_name "$(prompt_value "域名 PBR 名称" "tw")")"
  [[ -n "$name" ]] || { warn "域名 PBR 名称不能为空。"; return 0; }
  while true; do
    host="$(prompt_host "域名 host")"
    is_domain_name "$host" && break
    warn "域名 PBR 的 host 必须是域名，不能是纯 IPv4。"
  done
  group="$(pbr_select_group)" || return 0
  route_table="T_${group#T_}"
  enabled="$(prompt_enabled_value "是否启用域名 PBR？" "true")"
  comment="$(prompt_value "备注" "${name}-ddns-pbr")"
    if resolve_domain_ipv4_multi "$host"; then
      resolved="$RESOLVE_SELECTED_IP"
    else
      resolved=""
    fi
  [[ -n "$resolved" ]] || { warn "域名暂未解析成功，未写入域名 PBR：${host}"; return 0; }
  row="${name}"$'\t'"${host}"$'\t'"${route_table}"$'\t'"${enabled}"$'\t'"${comment}"
  confirm_summary "添加域名 PBR 摘要" "name=${name}\nhost=${host}\nresolved=${resolved}\nroute_table=${route_table}\nenabled=${enabled}\nsource=pbr-domain:${name} ${host}" || return 0
  replace_pbr_domain_row "$row"
  pbr_domain_sync --apply
}

pbr_domain_delete() {
  need_root_unless_dry_run
  ensure_tsv_files >/dev/null
  local name tmp
  name="$(select_pbr_domain_name)" || return 0
  prompt_yes_no "确认删除域名 PBR ${name}？" "N" || return 0
  auto_snapshot_or_confirm "delete-pbr-domain" || return 0
  tmp="$(mktemp)"
  awk -F'\t' -v n="$name" '$1==n {next} {print}' "$PBR_DOMAIN_TSV" >"$tmp"
  write_file "$PBR_DOMAIN_TSV" "$(cat "$tmp")" 600
  awk -F'\t' -v n="$name" '$1==n {next} {print}' "$PBR_RESOLVED_DOMAIN_TSV" >"$tmp"
  write_file "$PBR_RESOLVED_DOMAIN_TSV" "$(cat "$tmp")" 600
  [[ -f "$PBR_STATIC_CONF" ]] || : >"$PBR_STATIC_CONF"
  awk -v src="pbr-domain:${name}" '
    /^[[:space:]]*($|#)/ { print; next }
    $3 == src { next }
    { print }
  ' "$PBR_STATIC_CONF" >"$tmp"
  write_file "$PBR_STATIC_CONF" "$(cat "$tmp")" 600
  rm -f "$tmp"
  ok "已删除域名 PBR：${name}"
  pbr_apply
}

pbr_domain_menu() {
  local choice
  while true; do
    print_menu_header "域名 PBR 管理"
    echo "1. 添加域名 PBR"
    echo "2. 查看域名 PBR"
    echo "3. 删除域名 PBR"
    echo "4. 立即同步域名 PBR"
    echo "0. 返回"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) run_menu_action_pause pbr_domain_add ;;
      2) run_menu_action_pause pbr_domain_list ;;
      3) run_menu_action_pause pbr_domain_delete ;;
      4) run_menu_action_pause pbr_domain_sync ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

pbr_sync_from_forwards() {
  need_root_unless_dry_run
  ensure_tsv_files >/dev/null
  resolve_forwards >/dev/null 2>&1 || true
  mkdir -p "$PBR_DIR"
  [[ -f "$PBR_STATIC_CONF" ]] || : >"$PBR_STATIC_CONF"
  local no_apply=0 arg acquired_lock=0
  while (($# > 0)); do
    arg="$1"
    case "$arg" in
      --apply) no_apply=0; shift ;;
      --no-apply) no_apply=1; shift ;;
      *) fail "未知 pbr sync-from-forwards 参数：${arg}"; return 1 ;;
    esac
  done
  if [[ -z "$LEIKWAN_GLOBAL_LOCK_TOKEN" ]]; then
    global_lock_acquire || return 0
    acquired_lock=1
  fi
  local tmp name _entry_port target_host target_ip _target_port _out_iface route_table enabled _resolved_at _comment
  local cidr group synced=0 skipped=0 candidates=0 rc=0
  tmp="$(mktemp)"
  awk '
    /^[[:space:]]*($|#)/ { print; next }
    $3 == "forward" { next }
    { print }
  ' "$PBR_STATIC_CONF" >"$tmp"

  while IFS=$'\034' read -r name _entry_port target_host target_ip _target_port _out_iface route_table enabled _resolved_at _comment; do
    [[ "$enabled" == "true" ]] || continue
    [[ -n "$target_ip" ]] || continue
    [[ -n "$route_table" && "$route_table" != "-" ]] || continue
    candidates=$((candidates + 1))
    cidr="${target_ip}/32"
    group="${route_table#T_}"
    if pbr_rule_key_exists "$tmp" "$cidr" "$group"; then
      skipped=$((skipped + 1))
      info "PBR 已存在，跳过 forward:${name} ${cidr} -> T_${group}"
      continue
    fi
    printf '%s %s forward %s %s\n' "$cidr" "$group" "$name" "$target_host" >>"$tmp"
    synced=$((synced + 1))
    ok "已同步 forward PBR：${name} ${cidr} -> T_${group}"
  done < <(resolved_rows_usv)

  write_file "$PBR_STATIC_CONF" "$(cat "$tmp")" 600
  rm -f "$tmp"
  if (( candidates == 0 )); then
    info "没有需要同步 PBR 的 enabled 转发目标。"
  else
    info "PBR 同步完成：新增 ${synced}，已存在 ${skipped}。"
  fi
  if (( no_apply == 0 )); then
    pbr_apply || rc=1
  else
    info "已更新 forward 来源 PBR 配置，稍后由统一流程应用。"
  fi
  (( acquired_lock == 1 )) && global_lock_release
  return "$rc"
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

html_escape() {
  local value="$1"
  printf '%s' "$value" | sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g' \
    -e "s/'/\&#39;/g"
}

output_generated_at() {
  date '+%Y-%m-%dT%H:%M:%S%z'
}

write_output_status() {
  write_named_status "${STATUS_DIR}/last-output.env" "LAST_OUTPUT" "ok" "forward-endpoints" "$FORWARD_TXT"
}

generate_forward_outputs() {
  local quiet="${1:-0}"
  ensure_tsv_files
  validate_forwards_tsv || return 1
  mkdir -p "$OUTPUT_DIR"
  local generated_at txt tsv json html name entry_port target_host target_port out_iface route_table enabled comment
  local e_name e_label public_host et_ip proto port weight e_enabled tcp_health udp_health role rank enabled_entries enabled_forwards
  local first_entry=1 first_forward=1 first_endpoint=1 tcp_endpoint udp_endpoint protocols_json
  generated_at="$(output_generated_at)"
  enabled_entries="$(enabled_entries_sorted | awk 'END{print NR+0}')"
  enabled_forwards="$(forwards_rows | awk -F'\t' '$7=="true"{c++} END{print c+0}')"
  txt="【转发入口清单】"$'\n'
  txt="${txt}生成时间：${generated_at}"$'\n'
  txt="${txt}脚本版本：${TOOL_VERSION}"$'\n'
  txt="${txt}公网入口：${enabled_entries} enabled"$'\n'
  txt="${txt}转发目标：${enabled_forwards} enabled"$'\n'
  tsv=$'generated_at\tversion\ttarget_name\tentry_name\tentry_label\trole\tpublic_host\tentry_port\tprotocols\ttcp_endpoint\tudp_endpoint\ttarget_host\ttarget_port\troute_table\tcomment\ttcp_health\tudp_health\tweight\tenabled'
  json="{"
  json="${json}"$'\n'"  \"version\": \"$(json_escape "$TOOL_VERSION")\","
  json="${json}"$'\n'"  \"generated_at\": \"$(json_escape "$generated_at")\","
  json="${json}"$'\n'"  \"entries\": ["
  rank=0
  while IFS=$'\t' read -r e_name public_host et_ip proto port weight e_enabled; do
    rank=$((rank + 1))
    if (( rank == 1 )); then role="PRIMARY"; else role="BACKUP"; fi
    e_label="$(entry_label "$e_name")"
    protocols_json="[\"tcp\", \"udp\"]"
    tcp_endpoint="tcp://${public_host}:${port}"
    udp_endpoint="udp://${public_host}:${port}"
    (( first_entry == 0 )) && json="${json},"
    first_entry=0
    json="${json}"$'\n'"    {\"name\":\"$(json_escape "$e_name")\",\"label\":\"$(json_escape "$e_label")\",\"role\":\"${role}\",\"public_host\":\"$(json_escape "$public_host")\",\"protocols\":${protocols_json},\"port\":${port},\"easytier_port\":${port},\"tcp_endpoint\":\"$(json_escape "$tcp_endpoint")\",\"udp_endpoint\":\"$(json_escape "$udp_endpoint")\",\"enabled\":$([[ "$e_enabled" == "true" ]] && printf 'true' || printf 'false')}"
  done < <(enabled_entries_sorted)
  json="${json}"$'\n'"  ],"
  json="${json}"$'\n'"  \"forwards\": ["
  while IFS=$'\034' read -r name entry_port target_host target_port out_iface route_table enabled comment; do
    [[ "$enabled" == "true" ]] || continue
    (( first_forward == 0 )) && json="${json},"
    first_forward=0
    json="${json}"$'\n'"    {\"name\":\"$(json_escape "$name")\",\"entry_port\":${entry_port},\"protocols\":[\"tcp\", \"udp\"],\"target_host\":\"$(json_escape "$target_host")\",\"target_port\":${target_port},\"route_table\":\"$(json_escape "${route_table:-}")\",\"comment\":\"$(json_escape "$comment")\",\"enabled\":true}"
  done < <(forwards_rows_usv)
  json="${json}"$'\n'"  ],"
  json="${json}"$'\n'"  \"endpoints\": ["

  html='<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
  html="${html}<title>Leikwan 转发端点</title><style>body{font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;margin:0;background:#f6f7f9;color:#172033}main{max-width:1100px;margin:auto;padding:24px}h1{font-size:24px}h2{font-size:18px;margin-top:28px}.note{background:#fff7d6;border:1px solid #ead27a;padding:12px;border-radius:6px}.target{background:white;border:1px solid #d8dde6;border-radius:8px;margin:16px 0;padding:16px}.endpoint{display:grid;grid-template-columns:92px 1fr;gap:8px;border-top:1px solid #edf0f5;padding:10px 0}.badge{font-weight:700}.primary{color:#126c3a}.backup{color:#6b5870}code{word-break:break-all}@media(max-width:640px){main{padding:14px}.endpoint{grid-template-columns:1fr}}</style></head><body><main>"
  html="${html}<h1>Leikwan 转发端点</h1><p>生成时间：$(html_escape "$generated_at")<br>脚本版本：$(html_escape "$TOOL_VERSION")</p>"
  html="${html}<div class=\"note\">端点输出仅用于分享 TCP/UDP 访问入口，不是代理链接，不包含 EasyTier network secret 或配对码。</div>"
  html="${html}<h2>公网入口</h2>"
  rank=0
  while IFS=$'\t' read -r e_name public_host et_ip proto port weight e_enabled; do
    [[ "$e_enabled" == "true" ]] || continue
    rank=$((rank + 1))
    if (( rank == 1 )); then role="PRIMARY"; else role="BACKUP"; fi
    e_label="$(entry_label "$e_name")"
    tcp_endpoint="tcp://${public_host}:${port}"
    udp_endpoint="udp://${public_host}:${port}"
    html="${html}<div class=\"endpoint\"><div><span class=\"badge $([[ "$role" == "PRIMARY" ]] && printf 'primary' || printf 'backup')\">${role}</span><br>$(html_escape "$e_label")</div><div><strong>TCP</strong> <code>$(html_escape "$tcp_endpoint")</code><br><strong>UDP</strong> <code>$(html_escape "$udp_endpoint")</code><br>enabled=true</div></div>"
  done < <(enabled_entries_sorted)
  html="${html}<h2>转发目标</h2>"

  while IFS=$'\034' read -r name entry_port target_host target_port out_iface route_table enabled comment; do
    [[ "$enabled" == "true" ]] || continue
    txt="${txt}"$'\n'"目标：${name}"$'\n'"后端：${target_host}:${target_port}"$'\n'"入口端口：${entry_port} TCP+UDP"$'\n'"route_table：${route_table:-"-"}"$'\n'"备注：${comment:-"-"}"$'\n'"入口："$'\n'
    html="${html}<section class=\"target\"><h2>$(html_escape "$name")</h2><p>后端：<code>$(html_escape "$target_host"):${target_port}</code><br>入口端口：${entry_port} TCP / UDP<br>route_table：$(html_escape "${route_table:-"-"}")<br>备注：$(html_escape "${comment:-"-"}")</p>"
    rank=0
    while IFS=$'\t' read -r e_name public_host et_ip proto port weight e_enabled; do
      [[ "$e_enabled" == "true" ]] || continue
      rank=$((rank + 1))
      if (( rank == 1 )); then role="PRIMARY"; else role="BACKUP"; fi
      tcp_health="UNKNOWN"
      udp_health="UNKNOWN"
      if command -v nc >/dev/null 2>&1; then
        if nc -vz -w 2 "$public_host" "$entry_port" >/dev/null 2>&1; then tcp_health="UP"; else tcp_health="DOWN"; fi
        if nc -uvz -w 2 "$public_host" "$entry_port" >/dev/null 2>&1; then udp_health="PROBED"; fi
      fi
      e_label="$(entry_label "$e_name")"
      tcp_endpoint="tcp://${public_host}:${entry_port}"
      udp_endpoint="udp://${public_host}:${entry_port}"
      txt="${txt}* ${role} ${e_label}  TCP ${tcp_endpoint}  UDP ${udp_endpoint}  状态：TCP=${tcp_health} UDP=${udp_health}  权重：${weight}"$'\n'
      tsv="${tsv}"$'\n'"${generated_at}"$'\t'"${TOOL_VERSION}"$'\t'"${name}"$'\t'"${e_name}"$'\t'"${e_label}"$'\t'"${role}"$'\t'"${public_host}"$'\t'"${entry_port}"$'\t'"tcp,udp"$'\t'"${tcp_endpoint}"$'\t'"${udp_endpoint}"$'\t'"${target_host}"$'\t'"${target_port}"$'\t'"${route_table}"$'\t'"${comment}"$'\t'"${tcp_health}"$'\t'"${udp_health}"$'\t'"${weight}"$'\t'"${e_enabled}"
      (( first_endpoint == 0 )) && json="${json},"
      first_endpoint=0
      json="${json}"$'\n'"    {\"target\":\"$(json_escape "$name")\",\"entry\":\"$(json_escape "$e_name")\",\"label\":\"$(json_escape "$e_label")\",\"role\":\"${role}\",\"entry_port\":${entry_port},\"protocols\":[\"tcp\", \"udp\"],\"tcp_endpoint\":\"$(json_escape "$tcp_endpoint")\",\"udp_endpoint\":\"$(json_escape "$udp_endpoint")\"}"
      html="${html}<div class=\"endpoint\"><div><span class=\"badge $([[ "$role" == "PRIMARY" ]] && printf 'primary' || printf 'backup')\">${role}</span><br>$(html_escape "$e_label")</div><div><strong>TCP</strong> <code>$(html_escape "$tcp_endpoint")</code><br><strong>UDP</strong> <code>$(html_escape "$udp_endpoint")</code><br>状态：TCP=$(html_escape "$tcp_health") UDP=$(html_escape "$udp_health")</div></div>"
    done < <(enabled_entries_sorted)
    html="${html}</section>"
  done < <(forwards_rows_usv)
  json="${json}"$'\n'"  ]"$'\n'"}"
  html="${html}</main></body></html>"
  txt="${txt}"$'\n'"[INFO] 本工具不会自动把外部客户端流量按权重分流；权重用于排序和推荐。"$'\n'
  txt="${txt}[INFO] 真正负载均衡需要客户端、DNS 或外部 LB 配合。"$'\n'
  txt="${txt}[INFO] 如需手动切换入口，请使用：公网入口列表管理 -> 切换主公网入口。"$'\n'
  txt="${txt}[INFO] 端点输出不包含 EasyTier secret，不等于代理链接。"
  write_file "$FORWARD_TXT" "$txt" 644
  write_file "$FORWARD_TSV" "$tsv" 644
  write_file "$FORWARD_JSON" "$json" 644
  write_file "$FORWARD_HTML" "$html" 644
  write_output_status
  if (( quiet == 0 )); then
    cat "$FORWARD_TXT"
    echo
    ok "已生成：${FORWARD_TXT}"
    ok "已生成：${FORWARD_TSV}"
    ok "已生成：${FORWARD_JSON}"
    ok "已生成：${FORWARD_HTML}"
  fi
}

output_show() {
  if [[ ! -f "$FORWARD_TXT" ]]; then
    info "尚未生成端点输出，请先执行：lq output generate"
    return 0
  fi
  cat "$FORWARD_TXT"
}

output_json() {
  if [[ ! -f "$FORWARD_JSON" ]]; then
    info "尚未生成 JSON 端点输出，请先执行：lq output generate"
    return 0
  fi
  cat "$FORWARD_JSON"
}

output_html() {
  if [[ ! -f "$FORWARD_HTML" ]]; then
    info "尚未生成 HTML 端点输出，请先执行：lq output generate"
    return 0
  fi
  ok "HTML 输出：${FORWARD_HTML}"
}

output_qr() {
  ensure_tsv_files
  validate_forwards_tsv || return 1
  if ! command -v qrencode >/dev/null 2>&1; then
    info "未安装 qrencode，跳过二维码输出。"
    return 0
  fi
  mkdir -p "$FORWARD_QR_DIR"
  local name entry_port target_host target_port out_iface route_table enabled comment
  local e_name public_host et_ip proto port weight e_enabled tcp_endpoint udp_endpoint tcp_png udp_png count=0
  while IFS=$'\034' read -r name entry_port target_host target_port out_iface route_table enabled comment; do
    [[ "$enabled" == "true" ]] || continue
    while IFS=$'\t' read -r e_name public_host et_ip proto port weight e_enabled; do
      [[ "$e_enabled" == "true" ]] || continue
      tcp_endpoint="tcp://${public_host}:${entry_port}"
      udp_endpoint="udp://${public_host}:${entry_port}"
      tcp_png="${FORWARD_QR_DIR}/$(safe_name "${name}-${e_name}-tcp").png"
      udp_png="${FORWARD_QR_DIR}/$(safe_name "${name}-${e_name}-udp").png"
      qrencode -o "$tcp_png" "$tcp_endpoint"
      qrencode -o "$udp_png" "$udp_endpoint"
      count=$((count + 2))
    done < <(enabled_entries_sorted)
  done < <(forwards_rows_usv)
  ok "已生成二维码 ${count} 个：${FORWARD_QR_DIR}"
}

config_export_time() {
  date '+%Y-%m-%dT%H:%M:%S%z'
}

config_sensitive_redact_tree() {
  local root="$1" file size
  [[ -d "$root" ]] || return 0
  while IFS= read -r -d '' file; do
    [[ -f "$file" ]] || continue
    size="$(wc -c <"$file" 2>/dev/null || printf '0')"
    [[ "$size" =~ ^[0-9]+$ ]] || size=0
    (( size <= 5 * 1024 * 1024 )) || continue
    LC_ALL=C grep -Iq . "$file" 2>/dev/null || continue
    sed -E -i \
      -e 's/(EASYTIER_NETWORK_SECRET=).*/\1REDACTED/g' \
      -e 's/(([A-Za-z0-9_]*PAIRING[A-Za-z0-9_]*BASE64=)).*/\1REDACTED/g' \
      -e 's/(LEIKWAN_[A-Z0-9_]*_BASE64=).*/\1REDACTED/g' \
      -e 's/(([A-Za-z0-9_]*)(SECRET|Secret|secret|TOKEN|Token|token|PASSWORD|Password|password)([A-Za-z0-9_]*)([[:space:]_=-]+))[^[:space:]]+/\1REDACTED/g' \
      -e 's#(https?://[^?[:space:]]+)\?[^[:space:]]+#\1?REDACTED#g' \
      -e 's/(ENTRY_DDNS_UPDATE_URL=).*/\1REDACTED/g' \
      -e 's/(ENTRY_DDNS_UPDATE_CMD=).*/\1REDACTED/g' \
      -e 's/(ENTRY_DDNS_TOKEN=).*/\1REDACTED/g' \
      -e 's/(PrivateKey[[:space:]]*=[[:space:]]*)[^[:space:]]+/\1REDACTED/g' \
      "$file" 2>/dev/null || true
  done < <(find "$root" -type f -print0 2>/dev/null)
}

config_package_mode_label() {
  case "${1:-full}" in
    redacted) printf 'redacted' ;;
    *) printf 'full' ;;
  esac
}

write_config_export_status() {
  write_named_status "${STATUS_DIR}/last-config-export.env" "LAST_CONFIG_EXPORT" "$1" "$2" "$3"
}

write_config_import_status() {
  write_named_status "${STATUS_DIR}/last-config-import.env" "LAST_CONFIG_IMPORT" "$1" "$2" "$3"
}

config_export_copy_path() {
  local src="$1" dest_dir="$2"
  [[ -e "$src" ]] || return 0
  mkdir -p "$dest_dir"
  cp -a "$src" "$dest_dir/"
}

config_manifest_env() {
  local mode="$1" contains_secret="$2" export_time="$3" role="$4" entries_count="$5" forwards_count="$6" pbr_count="$7" ddns_enabled="$8" hostname
  hostname="$(hostname 2>/dev/null || printf 'unknown')"
  cat <<EOF
LEIKWAN_CONFIG_FORMAT=1
EXPORT_TIME=${export_time}
EXPORT_VERSION=${TOOL_VERSION}
EXPORT_HOSTNAME=${hostname}
EXPORT_ROLE=${role}
EXPORT_MODE=${mode}
CONTAINS_SECRET=${contains_secret}
ENTRIES_COUNT=${entries_count}
FORWARDS_COUNT=${forwards_count}
PBR_COUNT=${pbr_count}
DDNS_ENABLED=${ddns_enabled}
EOF
}

config_manifest_json() {
  local mode="$1" contains_secret="$2" export_time="$3" role="$4" entries_count="$5" forwards_count="$6" pbr_count="$7" ddns_enabled="$8" hostname
  hostname="$(hostname 2>/dev/null || printf 'unknown')"
  cat <<EOF
{
  "format": 1,
  "export_time": "$(json_escape "$export_time")",
  "export_version": "$(json_escape "$TOOL_VERSION")",
  "export_hostname": "$(json_escape "$hostname")",
  "export_role": "$(json_escape "$role")",
  "export_mode": "$(json_escape "$mode")",
  "contains_secret": ${contains_secret},
  "entries_count": ${entries_count},
  "forwards_count": ${forwards_count},
  "pbr_count": ${pbr_count},
  "ddns_enabled": ${ddns_enabled}
}
EOF
}

config_export() {
  need_root_unless_dry_run
  ensure_tsv_files
  local mode="full" explicit_full=0 arg config_lock="" ts package_name dest tmp stage state_work checksums_tmp
  local export_time role entries_count forwards_count pbr_count ddns_enabled contains_secret base_name sha_file
  while (($# > 0)); do
    arg="$1"
    case "$arg" in
      --redacted) mode="redacted"; shift ;;
      --full) mode="full"; explicit_full=1; shift ;;
      *) fail "未知 config export 参数：${arg}"; return 1 ;;
    esac
  done
  if ! lock_acquire "$CONFIG_LOCK_PATH" "配置导入/导出" config_lock; then
    return 1
  fi
  if [[ "$mode" == "full" ]]; then
    warn "完整配置包包含 EasyTier network secret。"
    warn "泄露后可能导致别人加入你的 EasyTier 网络。"
    if (( explicit_full == 1 )) && is_interactive; then
      prompt_yes_no "确认继续导出完整配置包？" "N" || { lock_release "$config_lock"; return 0; }
    fi
    contains_secret=true
    base_name="leikwan-config"
  else
    contains_secret=false
    base_name="leikwan-config-redacted"
  fi
  ts="$(snapshot_timestamp)"
  package_name="${base_name}-${ts}"
  dest="/root/${package_name}.tar.gz"
  sha_file="${dest}.sha256"
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] export ${mode} config package ${dest}"
    lock_release "$config_lock"
    return 0
  fi
  tmp="$(mktemp -d /tmp/leikwan-config-export.XXXXXX)"
  stage="${tmp}/${package_name}"
  state_work="${tmp}/state-work"
  mkdir -p "$stage/state" "$stage/systemd" "$stage/nft" "$stage/iproute" "$stage/sysctl" "$stage/status" "$stage/outputs" "$stage/logs" "$state_work"
  export_time="$(config_export_time)"
  role="$(detect_role)"
  entries_count="$(entries_rows | awk 'END{print NR+0}')"
  forwards_count="$(forwards_rows | awk 'END{print NR+0}')"
  pbr_count="$(pbr_rules_count 2>/dev/null || printf '0')"
  if [[ "$(ddns_timer_state 2>/dev/null || true)" == "active" ]]; then ddns_enabled=true; else ddns_enabled=false; fi
  config_manifest_env "$mode" "$contains_secret" "$export_time" "$role" "$entries_count" "$forwards_count" "$pbr_count" "$ddns_enabled" >"${stage}/manifest.env"
  config_manifest_json "$mode" "$contains_secret" "$export_time" "$role" "$entries_count" "$forwards_count" "$pbr_count" "$ddns_enabled" >"${stage}/manifest.json"
  if [[ -d "$STATE_DIR" ]]; then
    tar --exclude='etc/leikwan-toolkit/snapshots' -C / -cf - etc/leikwan-toolkit 2>/dev/null | tar -C "$state_work" -xf - 2>/dev/null || true
  else
    mkdir -p "${state_work}${STATE_DIR}"
  fi
  if [[ "$mode" == "redacted" ]]; then
    config_sensitive_redact_tree "$state_work"
  fi
  tar -czf "${stage}/state/etc-leikwan-toolkit.tar.gz" -C "$state_work" etc/leikwan-toolkit 2>/dev/null || tar -czf "${stage}/state/etc-leikwan-toolkit.tar.gz" -C "$state_work" . 2>/dev/null
  config_export_copy_path "$EASYTIER_RELAY_SERVICE" "${stage}/systemd"
  while IFS= read -r svc; do config_export_copy_path "$svc" "${stage}/systemd"; done < <(find /etc/systemd/system -maxdepth 1 -type f -name 'easytier-entry-*.service' 2>/dev/null || true)
  config_export_copy_path "$NFT_SERVICE" "${stage}/systemd"
  config_export_copy_path "$DDNS_SERVICE" "${stage}/systemd"
  config_export_copy_path "$DDNS_TIMER" "${stage}/systemd"
  config_export_copy_path "$ENTRY_DDNS_SERVICE" "${stage}/systemd"
  config_export_copy_path "$ENTRY_DDNS_TIMER" "${stage}/systemd"
  command -v nft >/dev/null 2>&1 && nft list ruleset >"${stage}/nft/ruleset.nft" 2>&1 || echo "nft command not found" >"${stage}/nft/ruleset.nft"
  config_export_copy_path "$NFT_RULE_FILE" "${stage}/nft"
  config_export_copy_path "$PBR_RT_TABLES" "${stage}/iproute"
  command -v ip >/dev/null 2>&1 && ip rule show >"${stage}/iproute/ip_rule_show.txt" 2>&1 || echo "ip command not found" >"${stage}/iproute/ip_rule_show.txt"
  command -v ip >/dev/null 2>&1 && ip route show table all >"${stage}/iproute/ip_route_show_table_all.txt" 2>&1 || echo "ip command not found" >"${stage}/iproute/ip_route_show_table_all.txt"
  config_export_copy_path "$FORWARD_SYSCTL" "${stage}/sysctl"
  config_export_copy_path "$BBR_SYSCTL_CONF" "${stage}/sysctl"
  (LOG_DISABLED=1 status_overview >"${stage}/status/lq-status.txt" 2>&1) || true
  (LOG_DISABLED=1 doctor >"${stage}/status/lq-doctor.txt" 2>&1) || true
  generate_forward_outputs 1 >/dev/null 2>&1 || true
  for file in "$FORWARD_TXT" "$FORWARD_TSV" "$FORWARD_JSON" "$FORWARD_HTML"; do
    config_export_copy_path "$file" "${stage}/outputs"
  done
  [[ -f "$LOG_FILE" ]] && tail -n 200 "$LOG_FILE" >"${stage}/logs/leikwan-toolkit.tail.log" 2>/dev/null || true
  [[ -f "$DDNS_LOG_FILE" ]] && tail -n 200 "$DDNS_LOG_FILE" >"${stage}/logs/leikwan-ddns-refresh.tail.log" 2>/dev/null || true
  [[ -f "$ENTRY_DDNS_LOG_FILE" ]] && tail -n 200 "$ENTRY_DDNS_LOG_FILE" >"${stage}/logs/leikwan-entry-ddns.tail.log" 2>/dev/null || true
  if [[ "$mode" == "redacted" ]]; then
    config_sensitive_redact_tree "$stage"
  fi
  checksums_tmp="${tmp}/checksums.sha256"
  (cd "$stage" && find . -type f ! -name checksums.sha256 -print | sort | while IFS= read -r file; do sha256sum "$file"; done >"$checksums_tmp")
  mv "$checksums_tmp" "${stage}/checksums.sha256"
  tar -czf "$dest" -C "$tmp" "$package_name"
  (cd "$(dirname "$dest")" && sha256sum "$(basename "$dest")" >"$(basename "$sha_file")")
  rm -rf "$tmp"
  ok "已导出配置包：${dest}"
  ok "sha256：${sha_file}"
  if [[ "$mode" == "full" ]]; then
    warn "完整配置包包含 EasyTier network secret，请妥善保存。"
  else
    info "脱敏配置包适合排错和 issue 附件，不适合完整恢复运行。"
  fi
  write_config_export_status "ok" "$mode" "$dest"
  lock_release "$config_lock"
}

config_verify_external_sha() {
  local pkg="$1" required="${2:-0}" sha
  sha="${pkg}.sha256"
  if [[ ! -f "$sha" ]]; then
    if (( required == 1 )); then
      fail "未找到外部 sha256 文件：${sha}"
      return 1
    fi
    warn "未找到外部 sha256 文件：${sha}"
    return 0
  fi
  (cd "$(dirname "$pkg")" && sha256sum -c "$(basename "$sha")" >/dev/null)
}

config_validate_archive_members() {
  local archive="$1" label="${2:-配置包}" member line mode type
  [[ -f "$archive" ]] || { fail "${label}不存在：${archive}"; return 1; }
  if ! tar -tzf "$archive" >/dev/null 2>&1; then
    fail "${label}不是有效 tar.gz：${archive}"
    return 1
  fi
  while IFS= read -r member; do
    member="${member//$'\r'/}"
    [[ -n "$member" ]] || continue
    if [[ "$member" == /* || "$member" == *"/../"* || "$member" == ../* || "$member" == *"/.." || "$member" == "." || "$member" == ".." || "$member" == *\\* ]]; then
      fail "${label}包含不安全路径：${member}"
      return 1
    fi
  done < <(tar -tzf "$archive")
  while IFS= read -r line; do
    mode="${line%% *}"
    type="${mode:0:1}"
    case "$type" in
      l|h)
        fail "${label}包含 symlink/hardlink，拒绝导入：${line}"
        return 1
        ;;
    esac
  done < <(tar -tvzf "$archive" 2>/dev/null || true)
}

config_extract_package() {
  local pkg="$1" out_tmp="$2" out_root="$3" tmp root
  config_validate_archive_members "$pkg" "配置包" || return 1
  tmp="$(mktemp -d /tmp/leikwan-config-inspect.XXXXXX)"
  tar -xzf "$pkg" -C "$tmp"
  root="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  [[ -n "$root" && -f "${root}/manifest.env" ]] || { rm -rf "$tmp"; fail "配置包 manifest.env 缺失。"; return 1; }
  printf -v "$out_tmp" '%s' "$tmp"
  printf -v "$out_root" '%s' "$root"
}

config_verify_internal_checksums() {
  local root="$1"
  [[ -f "${root}/checksums.sha256" ]] || { warn "配置包缺少 checksums.sha256。"; return 1; }
  (cd "$root" && sha256sum -c checksums.sha256 >/dev/null)
}

config_inspect_root() {
  local root="$1" manifest
  local export_time export_version export_role export_mode contains_secret entries_count forwards_count pbr_count ddns_enabled
  manifest="${root}/manifest.env"
  export_time="$(env_file_get "$manifest" EXPORT_TIME)"
  export_version="$(env_file_get "$manifest" EXPORT_VERSION)"
  export_role="$(env_file_get "$manifest" EXPORT_ROLE)"
  export_mode="$(env_file_get "$manifest" EXPORT_MODE)"
  contains_secret="$(env_file_get "$manifest" CONTAINS_SECRET)"
  entries_count="$(env_file_get "$manifest" ENTRIES_COUNT)"
  forwards_count="$(env_file_get "$manifest" FORWARDS_COUNT)"
  pbr_count="$(env_file_get "$manifest" PBR_COUNT)"
  ddns_enabled="$(env_file_get "$manifest" DDNS_ENABLED)"
  echo "配置包信息"
  echo "----------------------------------------"
  echo "导出时间: ${export_time:-unknown}"
  echo "导出版本: ${export_version:-unknown}"
  echo "角色: ${export_role:-unknown}"
  echo "模式: ${export_mode:-unknown}"
  echo "包含 secret: ${contains_secret:-unknown}"
  echo "entries 数量: ${entries_count:-0}"
  echo "forwards 数量: ${forwards_count:-0}"
  echo "PBR 数量: ${pbr_count:-0}"
  echo "DDNS 启用: ${ddns_enabled:-unknown}"
  echo "包含 systemd: $([[ -d "${root}/systemd" ]] && find "${root}/systemd" -type f | grep -q . && echo yes || echo no)"
  echo "包含 nft: $([[ -s "${root}/nft/ruleset.nft" || -s "${root}/nft/leikwan-forward.nft" ]] && echo yes || echo no)"
  echo "包含 ip rule 快照: $([[ -s "${root}/iproute/ip_rule_show.txt" ]] && echo yes || echo no)"
}

config_inspect() {
  local pkg="$1" tmp="" root=""
  [[ -n "$pkg" ]] || { fail "缺少配置包路径。"; echo "用法：lq config inspect /path/to/pkg.tar.gz" >&2; return 1; }
  [[ -f "$pkg" ]] || { fail "配置包不存在：${pkg}"; return 1; }
  if config_verify_external_sha "$pkg"; then
    ok "外部 sha256 校验通过。"
  else
    fail "外部 sha256 校验失败：${pkg}.sha256"
    return 1
  fi
  config_extract_package "$pkg" tmp root || return 1
  if config_verify_internal_checksums "$root"; then
    ok "内部 checksums.sha256 校验通过。"
  else
    fail "内部 checksums.sha256 校验失败。"
    rm -rf "$tmp"
    return 1
  fi
  config_inspect_root "$root"
  rm -rf "$tmp"
}

config_import_auto_snapshot_or_confirm() {
  local dest
  dest="${AUTO_SNAPSHOT_DIR}/auto-before-config-import-$(snapshot_timestamp).tar.gz"
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] create auto snapshot ${dest}"
    return 0
  fi
  ensure_base_dirs
  if create_snapshot_archive "$dest"; then
    ok "已创建自动快照：${dest}"
    prune_auto_snapshots
    return 0
  fi
  warn "自动快照失败，导入风险较高。"
  prompt_yes_no "是否继续？" "N"
}

config_restore_full_assets() {
  local root="$1" svc
  mkdir -p /etc/systemd/system "$(dirname "$NFT_RULE_FILE")" "$(dirname "$FORWARD_SYSCTL")" "$(dirname "$BBR_SYSCTL_CONF")" "$(dirname "$PBR_RT_TABLES")"
  for svc in easytier-relay.service leikwan-nft-forward.service leikwan-ddns-refresh.service leikwan-ddns-refresh.timer leikwan-entry-ddns.service leikwan-entry-ddns.timer; do
    [[ -f "${root}/systemd/${svc}" ]] && cp -a "${root}/systemd/${svc}" "/etc/systemd/system/${svc}"
  done
  while IFS= read -r svc; do
    cp -a "$svc" "/etc/systemd/system/$(basename "$svc")"
  done < <(find "${root}/systemd" -maxdepth 1 -type f -name 'easytier-entry-*.service' 2>/dev/null || true)
  [[ -f "${root}/nft/leikwan-forward.nft" ]] && cp -a "${root}/nft/leikwan-forward.nft" "$NFT_RULE_FILE"
  [[ -f "${root}/sysctl/99-leikwan-forward.conf" ]] && cp -a "${root}/sysctl/99-leikwan-forward.conf" "$FORWARD_SYSCTL"
  [[ -f "${root}/sysctl/99-leikwan-bbr.conf" ]] && cp -a "${root}/sysctl/99-leikwan-bbr.conf" "$BBR_SYSCTL_CONF"
  [[ -f "${root}/iproute/rt_tables" ]] && cp -a "${root}/iproute/rt_tables" "$PBR_RT_TABLES"
  command -v systemctl >/dev/null 2>&1 && systemctl daemon-reload || true
  command -v sysctl >/dev/null 2>&1 && sysctl --system >/dev/null 2>&1 || true
}

config_apply_after_import() {
  local mode="$1" assume_yes="$2" role
  [[ "$mode" == "apply" || "$mode" == "full" ]] || return 0
  warn "应用导入配置可能重新渲染 systemd、nftables、PBR，并重启 EasyTier 服务。"
  if is_interactive && (( assume_yes == 0 )); then
    prompt_yes_no "是否继续应用导入配置？" "N" || return 0
  fi
  role="$(detect_role)"
  case "$role" in
    leikwan-relay)
      apply_easytier_relay_service confirmed || warn "relay service 重渲染/重启未完成。"
      apply_nft_rules "leikwan-relay" 1 || warn "relay nftables 应用未完成。"
      ;;
    cloud-entry)
      apply_easytier_entry_services || warn "entry service 重渲染/重启未完成。"
      apply_nft_rules "cloud-entry" || warn "entry nftables 应用未完成。"
      ;;
    *)
      warn "无法识别角色，跳过 EasyTier/nftables 自动应用。"
      ;;
  esac
  pbr_apply || warn "PBR 应用未完成。"
}

config_import() {
  local pkg="${1:-}" mode="" assume_yes=0 arg config_lock="" tmp="" root="" manifest contains_secret import_mode
  [[ -n "$pkg" ]] || { fail "缺少配置包路径。"; echo "用法：lq config import /path/to/pkg.tar.gz" >&2; return 1; }
  shift || true
  while (($# > 0)); do
    arg="$1"
    case "$arg" in
      --mode) mode="${2:-}"; shift 2 ;;
      --yes|-y) assume_yes=1; shift ;;
      *) fail "未知 config import 参数：${arg}"; return 1 ;;
    esac
  done
  [[ -f "$pkg" ]] || { fail "配置包不存在：${pkg}"; return 1; }
  case "$mode" in
    ""|config-only|apply|full) ;;
    *) fail "导入模式无效：${mode}"; return 1 ;;
  esac
  if [[ "$mode" == "full" && "$assume_yes" != "1" ]] && ! is_interactive; then
    fail "非交互 full import 必须显式添加 --yes。"
    return 1
  fi
  config_validate_archive_members "$pkg" "配置包" || return 1
  need_root_unless_dry_run
  if ! lock_acquire "$CONFIG_LOCK_PATH" "配置导入/导出" config_lock; then
    return 1
  fi
  if ! global_lock_acquire; then
    lock_release "$config_lock"
    return 1
  fi
  config_verify_external_sha "$pkg" 1 || { global_lock_release; lock_release "$config_lock"; return 1; }
  config_extract_package "$pkg" tmp root || { global_lock_release; lock_release "$config_lock"; return 1; }
  config_verify_internal_checksums "$root" || { rm -rf "$tmp"; global_lock_release; lock_release "$config_lock"; return 1; }
  manifest="${root}/manifest.env"
  [[ "$(env_file_get "$manifest" LEIKWAN_CONFIG_FORMAT)" == "1" ]] || { fail "配置包格式不支持。"; rm -rf "$tmp"; global_lock_release; lock_release "$config_lock"; return 1; }
  config_inspect_root "$root"
  contains_secret="$(env_file_get "$manifest" CONTAINS_SECRET)"
  if [[ "$contains_secret" != "true" ]]; then
    warn "这是脱敏配置包，不能恢复 EasyTier network secret。"
    info "仅适合排错查看，不适合直接恢复运行。"
    if [[ "$mode" == "full" ]]; then
      fail "脱敏配置包不能使用 full 模式导入。"
      rm -rf "$tmp"; global_lock_release; lock_release "$config_lock"; return 1
    fi
  fi
  if [[ -z "$mode" ]]; then
    if is_interactive; then
      echo
      echo "选择导入模式："
      echo "1. 仅导入 /etc/leikwan-toolkit 配置"
      echo "2. 导入配置并重新渲染 systemd / nftables / PBR"
      echo "3. 完整迁移恢复，包括 systemd service、nftables、PBR、sysctl"
      echo "0. 返回"
      case "$(prompt_menu_choice "请选择：")" in
        1) mode="config-only" ;;
        2) mode="apply" ;;
        3) mode="full" ;;
        0|"") rm -rf "$tmp"; global_lock_release; lock_release "$config_lock"; return 0 ;;
        *) warn "无效选择。"; rm -rf "$tmp"; global_lock_release; lock_release "$config_lock"; return 0 ;;
      esac
    else
      mode="config-only"
    fi
  fi
  echo "[WARN] 即将导入配置包，可能覆盖当前 /etc/leikwan-toolkit。"
  echo "[WARN] 当前服务不会立即重启，除非你选择应用配置。"
  if is_interactive && (( assume_yes == 0 )); then
    prompt_yes_no "确认继续？" "N" || { rm -rf "$tmp"; global_lock_release; lock_release "$config_lock"; return 0; }
  fi
  config_import_auto_snapshot_or_confirm || { rm -rf "$tmp"; global_lock_release; lock_release "$config_lock"; return 1; }
  import_mode="$mode"
  if [[ -f "${root}/state/etc-leikwan-toolkit.tar.gz" ]]; then
    config_validate_archive_members "${root}/state/etc-leikwan-toolkit.tar.gz" "配置包 state/etc-leikwan-toolkit.tar.gz" || { rm -rf "$tmp"; global_lock_release; lock_release "$config_lock"; return 1; }
    tar -xzf "${root}/state/etc-leikwan-toolkit.tar.gz" -C /
  else
    fail "配置包缺少 state/etc-leikwan-toolkit.tar.gz。"
    rm -rf "$tmp"; global_lock_release; lock_release "$config_lock"; return 1
  fi
  if [[ "$mode" == "full" ]]; then
    config_restore_full_assets "$root"
  fi
  config_apply_after_import "$mode" "$assume_yes"
  ok "配置导入完成：${pkg}"
  print_post_restore_next_steps
  write_config_import_status "ok" "$import_mode" "$pkg"
  rm -rf "$tmp"
  global_lock_release
  lock_release "$config_lock"
}

config_list() {
  local files=() file size i=0
  if [[ -d /root ]]; then
    mapfile -t files < <(find /root -maxdepth 1 -type f \( -name 'leikwan-config-*.tar.gz' -o -name 'leikwan-config-redacted-*.tar.gz' \) -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk '{sub(/^[^ ]+ /, ""); print}' || true)
  fi
  if (( ${#files[@]} == 0 )); then
    warn "未找到已导出的配置包。"
    return 0
  fi
  echo "已导出的配置包"
  echo "----------------------------------------"
  for file in "${files[@]}"; do
    i=$((i + 1))
    size="$(du -h "$file" 2>/dev/null | awk '{print $1}')"
    printf '%d. %s (%s)\n' "$i" "$file" "${size:-unknown}"
  done
}

config_menu() {
  local choice pkg
  while true; do
    print_menu_header "配置导入 / 导出"
    echo "1. 导出完整配置包"
    echo "2. 导出脱敏配置包"
    echo "3. 查看配置包信息"
    echo "4. 导入配置包"
    echo "5. 查看已导出的配置包"
    echo "0. 返回"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) run_menu_action_pause config_export --full ;;
      2) run_menu_action_pause config_export --redacted ;;
      3) pkg="$(prompt_value "配置包路径")"; [[ -n "$pkg" ]] && run_menu_action_pause config_inspect "$pkg" ;;
      4) pkg="$(prompt_value "配置包路径")"; [[ -n "$pkg" ]] && run_menu_action_pause config_import "$pkg" ;;
      5) run_menu_action_pause config_list ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

report() {
  local status="$1" msg="$2"
  case "$status" in
    WARN) REPORT_WARN_COUNT=$((REPORT_WARN_COUNT + 1)) ;;
    FAIL) REPORT_FAIL_COUNT=$((REPORT_FAIL_COUNT + 1)) ;;
  esac
  if is_brief_mode; then
    case "$status" in
      WARN|FAIL) ;;
      *) return 0 ;;
    esac
  fi
  case "$status" in
    OK) echo "${GREEN}[OK]${RESET} ${msg}" ;;
    WARN) echo "${YELLOW}[WARN]${RESET} ${msg}" ;;
    FAIL) echo "${RED}[FAIL]${RESET} ${msg}" ;;
    HINT) echo "[HINT] ${msg}" ;;
    INFO|DEBUG) echo "[${status}] ${msg}" ;;
  esac
}

ping_avg_ms() {
  awk -F= '/rtt|round-trip/ {
    split($2, a, "/")
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", a[2])
    print a[2]
    exit
  }'
}

ping_loss_text() {
  awk -F, '/packet loss/ {
    for (i=1; i<=NF; i++) {
      if ($i ~ /packet loss/) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
        print $i
        exit
      }
    }
  }'
}

ping_loss_percent() {
  awk -F, '/packet loss/ {
    for (i=1; i<=NF; i++) {
      if ($i ~ /packet loss/) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
        sub(/[[:space:]]*packet loss.*/, "", $i)
        print $i
        exit
      }
    }
  }'
}

emit_status() {
  local mode="$1" status="$2" msg="$3"
  if [[ "$mode" == "report" ]]; then
    report "$status" "$msg"
  else
    case "$status" in
      OK) ok "$msg" ;;
      WARN) warn "$msg" ;;
      INFO) info "$msg" ;;
      FAIL) fail "$msg" ;;
      *) echo "[${status}] ${msg}" ;;
    esac
  fi
}

ping_entry_et_ip() {
  local name="$1" et_ip="$2" mode="${3:-plain}" output rc avg loss msg
  rc=0
  output="$(ping -c 2 -W 2 "$et_ip" 2>&1)" || rc=$?
  log "PING ${name} ${et_ip}: $(printf '%s' "$output" | tr '\n' ' ')"
  avg="$(printf '%s\n' "$output" | ping_avg_ms)"
  loss="$(printf '%s\n' "$output" | ping_loss_percent)"
  if (( rc == 0 )); then
    msg="ping ${name} ${et_ip} 成功${avg:+，RTT avg=${avg}ms}"
    emit_status "$mode" OK "$msg"
    return 0
  fi
  msg="ping ${name} ${et_ip} 失败，packet loss=${loss:-unknown}"
  emit_status "$mode" WARN "$msg"
  return 1
}

report_ping_quality() {
  local host="$1" label="$2" output rc avg loss
  rc=0
  output="$(ping -c 4 "$host" 2>&1)" || rc=$?
  avg="$(printf '%s\n' "$output" | ping_avg_ms)"
  loss="$(printf '%s\n' "$output" | ping_loss_text)"
  if (( rc != 0 )); then
    report WARN "${label} 失败：${loss:-无 RTT}。请检查 EasyTier peer、路由和端口白名单。"
    return 1
  fi
  if [[ -n "$avg" ]] && awk -v a="$avg" 'BEGIN{exit !(a > 1000)}'; then
    report FAIL "${label} RTT avg=${avg}ms，严重异常；优先确认 EasyTier 端口是否走 ${FAST_PORT_RANGE_START}-${FAST_PORT_RANGE_END} 白名单。"
  elif [[ -n "$avg" ]] && awk -v a="$avg" 'BEGIN{exit !(a > 200)}'; then
    report WARN "${label} RTT avg=${avg}ms 偏高；建议检查 EasyTier 端口是否走 ${FAST_PORT_RANGE_START}-${FAST_PORT_RANGE_END} 白名单。"
  else
    report OK "${label} 成功${avg:+，RTT avg=${avg}ms}"
  fi
}

report_mss_clamp_status() {
  local mss
  mss="$(tcp_mss_clamp_value)"
  if nft_has_mss_clamp; then
    report OK "TCP MSS clamp enabled: ${mss}"
  else
    report WARN "TCP MSS clamp 未启用，EasyTier/tun TCP 转发可能出现有延迟但连接异常"
  fi
}

report_entry_policy_summary() {
  local count rank label name public_host et_ip proto port weight enabled
  count="$(enabled_entries_count)"
  report INFO "公网入口策略："
  report INFO "enabled entries: ${count}"
  if (( count == 0 )); then
    report WARN "当前没有 enabled 公网入口，relay peer 列表为空。"
    return 0
  fi
  rank=0
  while IFS=$'\t' read -r name public_host et_ip proto port weight enabled; do
    rank=$((rank + 1))
    if (( rank == 1 )); then label="PRIMARY"; else label="BACKUP"; fi
    report INFO "${label}: ${name} weight=${weight} $(easytier_protocols_display "$proto")/${port}"
  done < <(enabled_entries_sorted)
  if (( count == 1 )); then
    name="$(enabled_entries_sorted | awk -F'\t' 'NR==1 {print $1}')"
    report OK "当前为单入口模式：${name}"
  else
    report INFO "当前为多入口模式，权重只影响输出排序，不代表自动流量负载均衡。"
  fi
}

doctor_recheck_relay_dnat_rules() {
  local name entry_port target_host target_ip target_port out_iface route_table enabled _last_resolved_at comment
  local dnat_missing=0 forwards
  forwards="$(enabled_forwards_count 2>/dev/null || printf '0')"
  if (( forwards == 0 )); then
    report INFO "当前没有 enabled 转发目标，跳过 DNAT 复查。"
    return 0
  fi
  if ! nft_has_dnat_rules; then
    report WARN "nftables DNAT 规则复查：仍未发现 DNAT"
    return 1
  fi
  resolve_forwards >/dev/null 2>&1 || { report WARN "resolved.tsv 复查失败，无法逐条确认 DNAT。"; return 1; }
  while IFS=$'\034' read -r name entry_port target_host target_ip target_port out_iface route_table enabled _last_resolved_at comment; do
    [[ "$enabled" == "true" && -n "$target_ip" ]] || continue
    if ! nft_has_relay_dnat tcp "$entry_port" "$target_ip" "$target_port"; then
      report WARN "${name} relay TCP DNAT 复查仍缺失"
      dnat_missing=1
    fi
    if ! nft_has_relay_dnat udp "$entry_port" "$target_ip" "$target_port"; then
      report WARN "${name} relay UDP DNAT 复查仍缺失"
      dnat_missing=1
    fi
  done < <(resolved_rows_usv)
  return "$dnat_missing"
}

doctor_offer_forward_rule_fix() {
  local fix_needed="$1"
  local reason="${2:-legacy}"
  (( fix_needed == 1 )) || return 0
  case "$reason" in
    empty)
      report WARN "nftables 表存在，但没有任何转发 DNAT 规则。"
      report INFO "检测到转发规则可能尚未应用，请执行：lq forward apply-relay --auto-fix-route"
      ;;
    partial)
      report WARN "检测到部分转发 DNAT 规则缺失，当前 nftables 规则可能不是最新模板。"
      report INFO "请执行：lq forward apply-relay --auto-fix-route"
      ;;
    mss)
      report INFO "检测到 TCP MSS clamp 未启用，可能是旧版本 nftables 模板或规则未重新应用。"
      report INFO "请执行：lq forward apply-relay --auto-fix-route"
      ;;
    *)
      report INFO "检测到转发规则可能是旧版本模板，请执行：lq forward apply-relay --auto-fix-route"
      ;;
  esac
  is_interactive || return 0
  (( DOCTOR_INTERACTIVE_FIX == 1 )) || return 0
  if prompt_yes_no "是否立即重新应用转发规则并同步 route_table？" "Y"; then
    report INFO "正在重新应用转发规则并同步 route_table..."
    if apply_nft_rules "leikwan-relay" 1; then
      report OK "已重新应用转发规则并同步 route_table。"
      if mss_clamp_enabled; then
        report_mss_clamp_status
      fi
      if doctor_recheck_relay_dnat_rules && { ! mss_clamp_enabled || nft_has_mss_clamp; }; then
        report OK "转发规则复查通过。"
      else
        report WARN "转发规则已重新应用，但仍存在缺失，请查看上方明细。"
      fi
    elif [[ "$APPLY_NFT_LAST_STATUS" == "skipped" ]]; then
      report INFO "已取消前台执行。可使用 nohup 后台方式安全应用。"
    else
      report WARN "转发规则重新应用失败，请稍后执行：lq forward apply-relay --auto-fix-route"
    fi
  else
    report INFO "已跳过自动修复。可稍后执行：lq forward apply-relay --auto-fix-route"
  fi
}

doctor_cloud() {
  report OK "角色：cloud-entry"
  local entry_ip proto port iface service_name relay_ip start end
  local _public_host _et_ip _proto _port _weight
  entry_ip="$(current_entry_et_ip)"
  if [[ -x "$EASYTIER_CORE_BIN" && -x "$EASYTIER_CLI_BIN" ]]; then
    report OK "EasyTier binary 存在"
    report INFO "easytier-core: ${EASYTIER_CORE_BIN}"
    report INFO "easytier-cli: ${EASYTIER_CLI_BIN}"
  else
    report WARN "EasyTier binary 不存在，请先安装 EasyTier"
  fi
  while IFS=$'\t' read -r name _public_host _et_ip _proto _port _weight enabled; do
    [[ "$enabled" == "true" ]] || continue
    service_name="$(entry_service_name "$name")"
    if systemctl is-active --quiet "${service_name}.service"; then report OK "${service_name} active"; else report WARN "${service_name} 未运行"; fi
  done < <(entries_rows)
  iface="$(et_iface_by_ip "$entry_ip")"
  if [[ -n "$iface" ]]; then report OK "EasyTier IP ${entry_ip} 在接口 ${iface}"; else report WARN "未检测到 EasyTier IP：${entry_ip}"; fi
  if [[ -f "$ENTRY_PAIRING_FILE" ]]; then
    proto="$(easytier_protocols_from_env "$ENTRY_PAIRING_FILE" EASYTIER_PROTOCOLS EASYTIER_PROTOCOL "$EASYTIER_PROTOCOLS_DEFAULT" 2>/dev/null || printf '%s' "$EASYTIER_PROTOCOLS_DEFAULT")"
    port="$(easytier_port_from_env "$ENTRY_PAIRING_FILE" "$proto" EASYTIER_TCP_PORT EASYTIER_UDP_PORT EASYTIER_PORT 2>/dev/null || true)"
  else
    proto="$(easytier_protocols_from_env "$NETWORK_ENV" EASYTIER_PROTOCOLS EASYTIER_PROTOCOL "$EASYTIER_PROTOCOLS_DEFAULT" 2>/dev/null || printf '%s' "$EASYTIER_PROTOCOLS_DEFAULT")"
    port=""
  fi
  [[ -n "$port" ]] || port="$(easytier_port_from_env "$NETWORK_ENV" "$proto" EASYTIER_TCP_PORT EASYTIER_UDP_PORT EASYTIER_LISTEN_PORT 2>/dev/null || printf '%s' "$EASYTIER_PORT_DEFAULT")"
  if is_fast_port "$port"; then report OK "EasyTier 监听端口：$(easytier_protocols_display "$proto")/${port}，位于白名单 ${FAST_PORT_RANGE_START}-${FAST_PORT_RANGE_END}"; else report WARN "EasyTier 监听端口：$(easytier_protocols_display "$proto")/${port}，不在白名单 ${FAST_PORT_RANGE_START}-${FAST_PORT_RANGE_END}"; fi
  if easytier_protocols_has "$proto" tcp; then
    if ss -lntH 2>/dev/null | awk -v p=":${port}" '$4 ~ p"$" {found=1} END{exit !found}'; then report OK "EasyTier TCP ${port} 已监听"; else report WARN "EasyTier TCP ${port} 未监听"; fi
  fi
  if easytier_protocols_has "$proto" udp; then
    if ss -lunH 2>/dev/null | awk -v p=":${port}" '$4 ~ p"$" {found=1} END{exit !found}'; then report OK "EasyTier UDP ${port} 已监听"; else report WARN "EasyTier UDP ${port} 未监听"; fi
  fi
  ping_entry_et_ip "relay" "$RELAY_ET_IP" report || true
  if nft list table inet leikwan_forward >/dev/null 2>&1; then
    report OK "nftables table inet leikwan_forward 存在"
    if nft_has_dnat_rules; then report OK "nftables DNAT 规则存在"; else report WARN "nftables 表存在，但没有任何 DNAT 规则。"; fi
    report_mss_clamp_status
  else
    report WARN "nftables 项目表不存在"
  fi
  report_local_entry_ddns_status
  report_entry_ddns_updater_status
  if [[ -f "$ENTRY_EXPOSE_ENV" ]]; then
    relay_ip="$(entry_expose_relay_ip)"
    if [[ "$(env_file_get "$ENTRY_EXPOSE_ENV" ENTRY_MODE)" == "bundle" ]]; then
      local bundle_count=0 name entry_port enabled
      while IFS=$'\t' read -r name entry_port _target_host _target_port _out_iface _route_table enabled _comment; do
        [[ "$enabled" == "true" ]] || continue
        bundle_count=$((bundle_count + 1))
        report OK "转发接入码：${name} ${entry_port} -> ${relay_ip}:${entry_port}"
        if nft_has_cloud_dnat tcp "$relay_ip" "$entry_port"; then
          report OK "${name} TCP DNAT 正常"
        else
          report FAIL "${name} TCP DNAT 缺失：应为 tcp dport ${entry_port} dnat ip to ${relay_ip}"
        fi
        if nft_has_cloud_dnat udp "$relay_ip" "$entry_port"; then
          report OK "${name} UDP DNAT 正常"
        else
          report FAIL "${name} UDP DNAT 缺失：应为 udp dport ${entry_port} dnat ip to ${relay_ip}"
        fi
      done < <(forwards_rows)
      (( bundle_count > 0 )) || report WARN "接入码模式已配置，但无启用的转发规则"
    else
      start="$(entry_expose_start)"
      end="$(entry_expose_end)"
      report OK "入口端口池：${start}-${end} -> ${relay_ip}"
      if nft_has_cloud_dnat tcp "$relay_ip" "${start}-${end}"; then
        report OK "入口端口池 TCP DNAT 正常"
      else
        report FAIL "入口端口池 TCP DNAT 缺失：应为 tcp dport ${start}-${end} dnat ip to ${relay_ip}"
      fi
      if nft_has_cloud_dnat udp "$relay_ip" "${start}-${end}"; then
        report OK "入口端口池 UDP DNAT 正常"
      else
        report FAIL "入口端口池 UDP DNAT 缺失：应为 udp dport ${start}-${end} dnat ip to ${relay_ip}"
      fi
    fi
  else
    report WARN "公网入口未配置：请粘贴转发接入码（推荐），或执行 lq entry expose-range"
  fi
  [[ -f "$ENTRY_PAIRING_FILE" ]] && report OK "入口配对码：已生成"
}

doctor_relay() {
  report OK "角色：leikwan-relay"
  local iface entries forwards name public_host et_ip proto port _weight enabled target_ip target_port
  local entry_port target_host out_iface route_table comment
  local forward_rule_fix_needed=0
  local forward_rule_fix_reason=""
  local nft_table_exists=0 table_has_any_dnat=0 relay_tcp_missing=0 relay_udp_missing=0
  forwards=0
  if [[ -x "$EASYTIER_CORE_BIN" && -x "$EASYTIER_CLI_BIN" ]]; then
    report OK "EasyTier binary 存在"
    report INFO "easytier-core: ${EASYTIER_CORE_BIN}"
    report INFO "easytier-cli: ${EASYTIER_CLI_BIN}"
  else
    report WARN "EasyTier binary 不存在，请先安装 EasyTier"
  fi
  if systemctl is-active --quiet "${EASYTIER_RELAY_SERVICE_NAME}.service"; then report OK "easytier-relay.service active"; else report WARN "easytier-relay.service 未运行"; fi
  iface="$(et_iface_by_ip "$RELAY_ET_IP")"
  if [[ -n "$iface" ]]; then report OK "Relay EasyTier IP ${RELAY_ET_IP} 在接口 ${iface}"; else report WARN "未检测到 Relay EasyTier IP：${RELAY_ET_IP}"; fi
  entries="$(entries_rows | awk -F'\t' '$7=="true"{c++} END{print c+0}')"; report INFO "enabled entries：${entries}"
  report_entry_policy_summary
  while IFS=$'\t' read -r name public_host et_ip proto port _weight enabled; do
    [[ "$enabled" == "true" ]] || continue
    emit_entry_peer_targets "$name" "$public_host" "$proto" "$port" report
    check_entry_peer_connectivity "$name" "$public_host" "$et_ip" "$proto" "$port" report || true
    if is_fast_port "$port"; then report OK "入口 ${name} EasyTier 端口 ${port} 位于白名单"; else report WARN "入口 ${name} EasyTier 端口 ${port} 不在白名单 ${FAST_PORT_RANGE_START}-${FAST_PORT_RANGE_END}"; fi
    if easytier_protocols_has "$proto" tcp; then
      case "$(tcp_reachable_status "$public_host" "$port")" in
        0) report OK "入口 ${name} TCP 可达：${public_host}:${port}" ;;
        2) report WARN "未找到 nc，无法测试入口 ${name} TCP；请安装 netcat-openbsd" ;;
        *) report WARN "入口 ${name} TCP 不可达：${public_host}:${port}" ;;
      esac
    fi
    if easytier_protocols_has "$proto" udp; then
      case "$(udp_probe_status "$public_host" "$port")" in
        0) report OK "入口 ${name} UDP 探测完成：${public_host}:${port}" ;;
        2) report WARN "未找到 nc，无法测试入口 ${name} UDP；请安装 netcat-openbsd" ;;
        *) report WARN "入口 ${name} UDP 探测未确认。UDP 无连接探测可能不可靠，请结合 EasyTier peer / ping 判断。" ;;
      esac
    fi
  done < <(entries_rows)
  if sysctl -n net.ipv4.ip_forward 2>/dev/null | grep -qx 1; then report OK "net.ipv4.ip_forward=1"; else report WARN "net.ipv4.ip_forward 未启用"; fi
  if nft list table inet leikwan_forward >/dev/null 2>&1; then
    nft_table_exists=1
    report OK "nftables table inet leikwan_forward 存在"
    if nft_has_dnat_rules; then table_has_any_dnat=1; report OK "nftables DNAT 规则存在"; fi
    report_mss_clamp_status
    if mss_clamp_enabled && ! nft_has_mss_clamp; then
      forward_rule_fix_needed=1
      forward_rule_fix_reason="mss"
    fi
  else
    report WARN "nftables 项目表不存在"
  fi
  if forwards="$(enabled_forwards_count 2>/dev/null)"; then
    report INFO "enabled forwards：${forwards}"
    if (( forwards == 0 )); then
      report INFO "当前没有 enabled 转发目标。"
    fi
  else
    report FAIL "forwards.tsv 校验失败，请检查 TAB 分隔和字段数。"
  fi
  if resolve_forwards >/dev/null 2>&1; then
    while IFS=$'\034' read -r name entry_port target_host target_ip target_port out_iface route_table enabled _last_resolved_at comment; do
      [[ "$enabled" == "true" ]] || continue
      if port_in_range "$entry_port" "$FORWARD_ENTRY_PORT_FALLBACK_START" "$FORWARD_ENTRY_PORT_FALLBACK_END"; then
        report OK "${name} entry_port ${entry_port} 位于常见入口端口池 ${FORWARD_ENTRY_PORT_FALLBACK_START}-${FORWARD_ENTRY_PORT_FALLBACK_END}"
      else
        report WARN "${name} entry_port ${entry_port} 不在常见入口端口池 ${FORWARD_ENTRY_PORT_FALLBACK_START}-${FORWARD_ENTRY_PORT_FALLBACK_END}"
      fi
      if [[ -n "$target_ip" ]]; then
        report OK "${name} resolved -> ${target_ip}"
      else
        report WARN "${name} target 未解析"
      fi
      if [[ -n "$target_ip" ]]; then
        report_forward_route_consistency "$name" "$target_host" "$out_iface" "$route_table"
        case "$(tcp_reachable_status "$target_ip" "$target_port")" in
          0) report OK "${name} target TCP 可达" ;;
          2) report WARN "未找到 nc，无法测试 ${name} target TCP；请安装 netcat-openbsd" ;;
          *) report WARN "${name} target TCP 不可达" ;;
        esac
        case "$(udp_probe_status "$target_ip" "$target_port")" in
          0) report OK "${name} target UDP 探测完成" ;;
          2) report WARN "未找到 nc，无法测试 ${name} target UDP；请安装 netcat-openbsd" ;;
          *) report WARN "${name} target UDP 探测未确认。UDP 无连接探测可能不可靠，请结合业务实际测试。" ;;
        esac
      fi
      if [[ -n "$target_ip" ]]; then
        if nft_has_relay_dnat tcp "$entry_port" "$target_ip" "$target_port"; then
          report OK "${name} relay TCP DNAT 正常"
        else
          report FAIL "${name} relay TCP DNAT 缺失：应为 tcp dport ${entry_port} dnat ip to ${target_ip}:${target_port}"
          forward_rule_fix_needed=1
          relay_tcp_missing=1
        fi
        if nft_has_relay_dnat udp "$entry_port" "$target_ip" "$target_port"; then
          report OK "${name} relay UDP DNAT 正常"
        else
          report WARN "${name} relay UDP DNAT 缺失：应为 udp dport ${entry_port} dnat ip to ${target_ip}:${target_port}"
          forward_rule_fix_needed=1
          relay_udp_missing=1
        fi
      fi
    done < <(resolved_rows_usv)
  else
    report FAIL "resolved.tsv 更新失败，请检查 target_host 解析。"
  fi
  if (( nft_table_exists == 1 && forwards > 0 )); then
    if (( table_has_any_dnat == 0 )); then
      forward_rule_fix_needed=1
      forward_rule_fix_reason="empty"
    elif (( relay_tcp_missing == 1 || relay_udp_missing == 1 )); then
      forward_rule_fix_needed=1
      forward_rule_fix_reason="partial"
    fi
  fi
  [[ -n "$forward_rule_fix_reason" ]] || forward_rule_fix_reason="legacy"
  doctor_offer_forward_rule_fix "$forward_rule_fix_needed" "$forward_rule_fix_reason"
  report_b_ddns_entry_monitor_status
  report_entry_ddns_cache_status
  report_pbr_domain_ddns_status
  [[ -f "$NETWORK_PAIRING_FILE" ]] && report OK "relay 网络码：已生成"
}

is_fake_dns_ip() {
  local ip="$1"
  [[ "$ip" == 198.18.* || "$ip" == 198.19.* ]]
}

doctor_dependency_tools() {
  local cmd
  for cmd in curl jq tar unzip; do
    if command -v "$cmd" >/dev/null 2>&1; then
      report OK "依赖命令存在：${cmd}"
    elif [[ "$cmd" == "jq" && -x "$EASYTIER_CORE_BIN" && -x "$EASYTIER_CLI_BIN" ]]; then
      report INFO "jq 缺失只影响 GitHub release metadata 获取，不影响当前已安装 EasyTier 运行。"
    else
      report WARN "依赖命令缺失：${cmd}"
    fi
  done
}

doctor_fake_ip_dns() {
  local host ip found any_fake=0
  command -v getent >/dev/null 2>&1 || { report INFO "未找到 getent，跳过 fake-ip DNS 检查。"; return 0; }
  for host in raw.githubusercontent.com api.github.com cn.archive.ubuntu.com; do
    found=0
    while IFS= read -r ip; do
      [[ -n "$ip" ]] || continue
      found=1
      if is_fake_dns_ip "$ip"; then
        any_fake=1
        report WARN "${host} -> ${ip}，DNS 解析到了 198.18.x.x fake-ip。"
      else
        report OK "${host} -> ${ip}"
      fi
    done < <(getent ahostsv4 "$host" 2>/dev/null | awk '{print $1}' | sort -u)
    (( found == 1 )) || report WARN "${host} 未解析到 IPv4。"
  done
  if (( any_fake == 1 )); then
    report WARN "DNS 解析到了 198.18.x.x fake-ip，可能是 OpenClash / Mihomo / sing-box fake-ip DNS。"
    report WARN "如果本机流量没有被透明代理接管，会导致 GitHub / apt 连接超时。"
    report HINT "请改用真实 DNS，例如 223.5.5.5 / 119.29.29.29，或在路由器中让该主机直连 / 正确透明代理。"
  fi
}

doctor_apt_sources() {
  local tmp
  command -v apt-get >/dev/null 2>&1 || { report INFO "未找到 apt-get，跳过 apt 源检查。"; return 0; }
  if (( EUID != 0 )); then
    report INFO "非 root 运行，跳过 apt 源下载检查。"
    return 0
  fi
  tmp="$(mktemp)"
  if apt-get update -o Acquire::Retries=0 >"$tmp" 2>&1; then
    report OK "apt 源更新检查通过。"
  else
    report WARN "apt 源更新检查失败，依赖包可能无法自动安装。"
  fi
  if grep -qi 'mirror sync in progress\|sync in progress\|正在同步' "$tmp"; then
    report WARN "apt 镜像可能正在同步，请稍后重试或换源。"
  fi
  if grep -qi '403[[:space:]]\+Forbidden\|403 Forbidden' "$tmp"; then
    report WARN "apt 源返回 403 Forbidden，请换源或手动安装 deb 包。"
  fi
  rm -f "$tmp"
}

doctor_component_summary() {
  local role="$1" component="$2" entries_enabled forwards_enabled ddns_result value
  entries_enabled="$(entries_rows | awk -F'\t' '$7=="true"{c++} END{print c+0}')"
  forwards_enabled="$(forwards_rows | awk -F'\t' '$7=="true"{c++} END{print c+0}')"
  case "$component" in
    easytier)
      case "$role" in
        leikwan-relay)
          value="$(systemd_active_state "${EASYTIER_RELAY_SERVICE_NAME}.service" || true)"
          [[ "$value" == "active" ]] && printf 'OK' || printf 'WARN'
          ;;
        cloud-entry)
          value="$(systemd_active_state "$(entry_service_name "$(env_file_get "$NETWORK_ENV" ENTRY_NAME)").service" || true)"
          [[ "$value" == "active" ]] && printf 'OK' || printf 'WARN'
          ;;
        *) printf 'WARN' ;;
      esac
      ;;
    entries)
      if [[ "$role" == "cloud-entry" ]]; then
        printf 'OK'
      elif (( entries_enabled > 0 )); then
        printf 'OK'
      else
        printf 'WARN'
      fi
      ;;
    forwards)
      if [[ "$role" == "cloud-entry" ]]; then
        printf 'OK'
      elif (( forwards_enabled > 0 )); then
        printf 'OK'
      else
        printf 'WARN'
      fi
      ;;
    pbr)
      printf 'OK'
      ;;
    nftables)
      STATUS_OVERVIEW_RESULT="ok"
      case "$role" in
        leikwan-relay) value="$(status_nft_summary leikwan-relay "" "" "" "$forwards_enabled")" ;;
        cloud-entry) value="$(status_nft_summary cloud-entry "$(entry_expose_relay_ip)" "$(entry_expose_start)" "$(entry_expose_end)" 0)" ;;
        *) value="$(status_nft_summary unknown)" ;;
      esac
      [[ "$value" == OK* ]] && printf 'OK' || printf 'WARN'
      ;;
    mss)
      STATUS_OVERVIEW_RESULT="ok"
      value="$(status_mss_summary)"
      [[ "$value" == OK* || "$value" == "disabled" ]] && printf 'OK' || printf 'WARN'
      ;;
    ddns)
      ddns_result="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RESULT)"
      case "${ddns_result,,}" in
        fail|failed) printf 'FAIL' ;;
        warn|warning) printf 'WARN' ;;
        *) printf 'OK' ;;
      esac
      ;;
  esac
}

doctor_reset_state() {
  REPORT_WARN_COUNT=0
  REPORT_FAIL_COUNT=0
  DOCTOR_SUMMARY_OVERALL=""
  DOCTOR_SUMMARY_WARNINGS=0
  DOCTOR_SUMMARY_FAILURES=0
  APPLY_NFT_LAST_STATUS=""
  STATUS_OVERVIEW_RESULT="ok"
}

doctor_print_summary() {
  local role="$1" easytier entries forwards pbr nft mss ddns overall health nft_for_health forwards_enabled suggestions=()
  role="${role:-$(detect_role)}"
  easytier="$(doctor_component_summary "$role" easytier)"
  entries="$(doctor_component_summary "$role" entries)"
  forwards="$(doctor_component_summary "$role" forwards)"
  pbr="$(doctor_component_summary "$role" pbr)"
  nft="$(doctor_component_summary "$role" nftables)"
  mss="$(doctor_component_summary "$role" mss)"
  ddns="$(doctor_component_summary "$role" ddns)"
  if (( REPORT_FAIL_COUNT > 0 )) || [[ "$ddns" == "FAIL" ]]; then
    overall="FAIL"
  elif (( REPORT_WARN_COUNT > 0 )) || [[ "$easytier$entries$forwards$nft$mss$ddns" == *WARN* ]]; then
    overall="WARN"
  else
    overall="OK"
  fi
  [[ "$nft" != "OK" || "$mss" != "OK" ]] && suggestions+=("执行 lq forward apply-relay --auto-fix-route")
  [[ "$overall" != "OK" ]] && suggestions+=("执行 lq doctor --auto-fix")
  [[ "$ddns" != "OK" ]] && suggestions+=("执行 lq ddns run")
  if [[ "$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RELAY_RESTART_NEEDED)" == "true" ]]; then
    suggestions+=("执行 lq ddns apply-entries")
  fi
  forwards_enabled="$(forwards_rows | awk -F'\t' '$7=="true"{c++} END{print c+0}')"
  case "$role" in
    leikwan-relay)
      nft_for_health="$(status_nft_summary leikwan-relay "" "" "" "$forwards_enabled" 2>/dev/null || printf 'WARN')"
      ;;
    cloud-entry)
      nft_for_health="$(status_nft_summary cloud-entry "$(entry_expose_relay_ip)" "$(entry_expose_start)" "$(entry_expose_end)" 0 2>/dev/null || printf 'WARN')"
      ;;
    *)
      nft_for_health="$(status_nft_summary unknown 2>/dev/null || printf 'WARN')"
      ;;
  esac
  health="$(health_score_value "$role" "$nft_for_health" "$(status_mss_summary)" "$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RESULT)")"
  echo
  echo "诊断结果摘要"
  echo "----------------------------------------"
  echo "角色: ${role}"
  echo "EasyTier: ${easytier}"
  echo "公网入口: ${entries}"
  echo "转发目标: ${forwards}"
  echo "PBR: ${pbr}"
  echo "nftables: ${nft}"
  echo "MSS clamp: ${mss}"
  echo "DDNS: ${ddns}"
  echo "健康度: ${health}/100 $(health_level "$health")"
  echo "整体状态: ${overall}"
  DOCTOR_SUMMARY_OVERALL="$overall"
  DOCTOR_SUMMARY_WARNINGS="$REPORT_WARN_COUNT"
  DOCTOR_SUMMARY_FAILURES="$REPORT_FAIL_COUNT"
  if (( ${#suggestions[@]} > 0 )); then
    echo "建议修复:"
    printf -- '- %s\n' "${suggestions[@]}"
  fi
}

doctor_json() {
  local role_info role role_source role_mixed entries_total entries_enabled forwards_total forwards_enabled pbr_count
  local nft_status mss_status ddns_result overall health warnings=() failures=()
  local entry_ddns_enabled entry_ddns_host entry_ddns_public_ip entry_ddns_resolved_ip entry_ddns_match relay_restart_needed
  STATUS_OVERVIEW_RESULT="ok"
  role_info="$(role_summary)"
  IFS=$'\t' read -r role role_source role_mixed <<<"$role_info"
  entries_total="$(entries_rows | awk 'END{print NR+0}')"
  entries_enabled="$(entries_rows | awk -F'\t' '$7=="true"{c++} END{print c+0}')"
  forwards_total="$(forwards_rows | awk 'END{print NR+0}')"
  forwards_enabled="$(forwards_rows | awk -F'\t' '$7=="true"{c++} END{print c+0}')"
  pbr_count="$(pbr_rules_count 2>/dev/null || printf '0')"
  case "$role" in
    leikwan-relay) nft_status="$(status_nft_summary leikwan-relay "" "" "" "$forwards_enabled")" ;;
    cloud-entry) nft_status="$(status_nft_summary cloud-entry "$(entry_expose_relay_ip)" "$(entry_expose_start)" "$(entry_expose_end)" 0)" ;;
    *) nft_status="$(status_nft_summary unknown)"; status_mark_result warn ;;
  esac
  mss_status="$(status_mss_summary)"
  ddns_result="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RESULT)"
  [[ -n "$ddns_result" ]] || ddns_result="unknown"
  entry_ddns_enabled="$(entry_ddns_config_value ENTRY_DDNS_ENABLED "$ENTRY_DDNS_ENABLED_DEFAULT")"
  entry_ddns_host="$(entry_ddns_config_value ENTRY_DDNS_HOST "")"
  entry_ddns_public_ip="$(entry_ddns_status_value LAST_ENTRY_DDNS_PUBLIC_IP)"
  entry_ddns_resolved_ip="$(entry_ddns_status_value LAST_ENTRY_DDNS_RESOLVED_IP)"
  relay_restart_needed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RELAY_RESTART_NEEDED)"
  entry_ddns_match="unknown"
  if [[ -n "$entry_ddns_public_ip" && -n "$entry_ddns_resolved_ip" ]]; then
    [[ "$entry_ddns_public_ip" == "$entry_ddns_resolved_ip" ]] && entry_ddns_match="ok" || entry_ddns_match="warn"
  elif [[ -z "$entry_ddns_host" ]]; then
    entry_ddns_match="not_configured"
  fi
  [[ "$role_mixed" == "true" ]] && warnings+=("mixed role")
  [[ ! -d "$STATE_DIR" ]] && warnings+=("state dir missing")
  [[ "${relay_restart_needed:-false}" == "true" ]] && warnings+=("relay restart needed after public entry domain change")
  [[ "$nft_status" == WARN* ]] && warnings+=("nftables: ${nft_status}")
  [[ "$mss_status" == WARN* ]] && warnings+=("mss_clamp: ${mss_status}")
  case "${ddns_result,,}" in
    fail|failed) failures+=("ddns failed") ;;
    warn|warning) warnings+=("ddns warn") ;;
  esac
  overall="$STATUS_OVERVIEW_RESULT"
  (( ${#failures[@]} > 0 )) && overall="fail"
  health="$(health_score_value "$role" "$nft_status" "$mss_status" "$ddns_result")"
  cat <<EOF
{
  "version": "$(json_escape "$TOOL_VERSION")",
  "role": "$(json_escape "$role")",
  "role_source": "$(json_escape "${role_source:-无}")",
  "overall": "$(json_escape "$overall")",
  "health_score": ${health},
  "health_level": "$(json_escape "$(health_level "$health")")",
  "entries_total": ${entries_total},
  "entries_enabled": ${entries_enabled},
  "forwards_total": ${forwards_total},
  "forwards_enabled": ${forwards_enabled},
  "pbr_count": ${pbr_count},
  "nftables": "$(json_escape "$nft_status")",
  "mss_clamp": "$(json_escape "$mss_status")",
  "ddns": "$(json_escape "$ddns_result")",
  "entry_ddns_enabled": "$(json_escape "$(bool_yes_no "$entry_ddns_enabled")")",
  "entry_ddns_host": "$(json_escape "$entry_ddns_host")",
  "entry_ddns_public_ip": "$(json_escape "$entry_ddns_public_ip")",
  "entry_ddns_resolved_ip": "$(json_escape "$entry_ddns_resolved_ip")",
  "entry_ddns_match": "$(json_escape "$entry_ddns_match")",
  "relay_restart_needed": "$(json_escape "$(bool_yes_no "${relay_restart_needed:-false}")")",
  "warnings": $(json_array "${warnings[@]}"),
  "failures": $(json_array "${failures[@]}")
}
EOF
}

doctor() {
  local role bbr_cc bbr_qdisc
  doctor_reset_state
  role="$(detect_role)"
  bbr_cc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || true)"
  bbr_qdisc="$(sysctl -n net.core.default_qdisc 2>/dev/null || true)"
  if [[ "$bbr_cc" == "bbr" && "$bbr_qdisc" == "fq" ]]; then report OK "BBR/fq enabled"; else report INFO "BBR=${bbr_cc:-unknown}, qdisc=${bbr_qdisc:-unknown}"; fi
  if system_ipv4_prefer_enabled; then
    report OK "IPv4 优先已启用"
  else
    report WARN "IPv4 优先未启用，建议执行：lq system network prepare"
  fi
  case "$(system_dns_doctor_state)" in
    ok) report OK "系统 DNS 已使用 Leikwan 推荐国外 DNS" ;;
    legacy) report WARN "检测到旧版 Leikwan DNS 配置，建议执行：lq system network prepare" ;;
    *) report INFO "当前系统 DNS 非 Leikwan 推荐国外 DNS，建议执行：lq system network prepare" ;;
  esac
  dnsutils_auto_install "doctor" "false" "plain" || true
  doctor_dependency_tools
  doctor_fake_ip_dns
  doctor_apt_sources
  case "$role" in
    cloud-entry) doctor_cloud ;;
    leikwan-relay) doctor_relay ;;
    *) report WARN "角色未知，请先执行 EasyTier 快速配对" ;;
  esac
  report_ddns_global_state
  if (( VERBOSE_DOCTOR == 1 )); then
    report DEBUG "entries.tsv=${ENTRIES_TSV}"
    report DEBUG "forwards.tsv=${FORWARDS_TSV}"
    report DEBUG "network.env=${NETWORK_ENV}"
    report DEBUG "nft=${NFT_RULE_FILE}"
  fi
  doctor_print_summary "$role"
  write_status_cache doctor "$(status_result_from_counts)"
}

doctor_auto_fix() {
  need_root_unless_dry_run
  local before_warn before_fail after_warn after_fail before_overall after_overall role release_global_lock=0 old_brief old_compact
  old_brief="${LEIKWAN_BRIEF:-}"
  old_compact="${LEIKWAN_COMPACT:-}"
  echo "doctor 自动修复"
  echo "----------------------------------------"
  echo "修复前检查："
  LEIKWAN_BRIEF=1 doctor
  before_warn="${DOCTOR_SUMMARY_WARNINGS:-$REPORT_WARN_COUNT}"
  before_fail="${DOCTOR_SUMMARY_FAILURES:-$REPORT_FAIL_COUNT}"
  before_overall="${DOCTOR_SUMMARY_OVERALL:-unknown}"
  echo
  echo "修复前："
  echo "- FAIL: ${before_fail}"
  echo "- WARN: ${before_warn}"
  echo "- 整体状态: ${before_overall}"
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] 将检查并修复 系统网络预处理/nft/MSS/route_table/relay service/DDNS timer/lq symlink/权限/stale locks"
    LEIKWAN_BRIEF="$old_brief"
    LEIKWAN_COMPACT="$old_compact"
    return 0
  fi
  if [[ -z "$LEIKWAN_GLOBAL_LOCK_TOKEN" ]]; then
    global_lock_acquire || {
      LEIKWAN_BRIEF="$old_brief"
      LEIKWAN_COMPACT="$old_compact"
      return 1
    }
    release_global_lock=1
  fi
  echo
  echo "执行修复："
  info "doctor --auto-fix 正在执行系统网络预处理：IPv4 优先 + 国外 DNS。"
  system_network_prepare || warn "doctor --auto-fix 的系统网络预处理未完全成功，请稍后到高级维护 -> 系统网络优化中检查。"
  lock_cleanup_stale_if_possible "$LEIKWAN_LOCK_PATH"
  lock_cleanup_stale_if_possible "$DDNS_LOCK_PATH"
  lock_cleanup_stale_if_possible "$UPDATE_LOCK_PATH"
  lock_cleanup_stale_if_possible "$CONFIG_LOCK_PATH"
  install_shortcuts && echo "- lq/LQ symlink 已确认"
  if [[ -d "$STATE_DIR" ]]; then
    chmod 700 "$STATE_DIR" "$ENTRY_DIR" "$ENTRIES_DIR" "$FORWARDS_DIR" "$OUTPUT_DIR" "$NFT_DIR" "$PBR_DIR" "$EASYTIER_DIR" "$STATUS_DIR" "$SNAPSHOT_DIR" "$AUTO_SNAPSHOT_DIR" 2>/dev/null || true
    find "$STATE_DIR" -type f \( -name '*.env' -o -name '*.tsv' -o -name '*.conf' \) -exec chmod 600 {} + 2>/dev/null || true
    echo "- 配置目录权限已检查"
  fi
  role="$(detect_role)"
  case "$role" in
    leikwan-relay)
      if ! role_has_service "${EASYTIER_RELAY_SERVICE_NAME}.service" && relay_network_env_ready; then
        apply_easytier_relay_service confirmed && echo "- relay service 已重建"
      fi
      pbr_sync_from_forwards --no-apply >/dev/null 2>&1 || true
      if ! nft_project_table_exists || { mss_clamp_enabled && ! nft_has_mss_clamp; }; then
        apply_nft_rules "leikwan-relay" 1 && echo "- nftables / MSS clamp 已重应用"
      fi
      ;;
    cloud-entry)
      apply_easytier_entry_services >/dev/null 2>&1 || true
      if ! nft_project_table_exists || { mss_clamp_enabled && ! nft_has_mss_clamp; }; then
        apply_nft_rules "cloud-entry" && echo "- entry nftables / MSS clamp 已重应用"
      fi
      ;;
  esac
  if [[ "$(ddns_timer_state)" != "active" ]] && (( $(ddns_domain_forward_count 2>/dev/null || printf '0') + $(ddns_domain_entry_count 2>/dev/null || printf '0') + $(ddns_domain_pbr_count 2>/dev/null || printf '0') > 0 )); then
    ddns_enable_timer && echo "- DDNS timer 已启用"
  fi
  if doctor_should_offer_dnsutils; then
    doctor_auto_fix_dnsutils
  fi
  (( release_global_lock == 1 )) && global_lock_release
  echo
  echo "修复后复查："
  LEIKWAN_BRIEF=1 doctor
  after_warn="${DOCTOR_SUMMARY_WARNINGS:-$REPORT_WARN_COUNT}"
  after_fail="${DOCTOR_SUMMARY_FAILURES:-$REPORT_FAIL_COUNT}"
  after_overall="${DOCTOR_SUMMARY_OVERALL:-unknown}"
  echo
  echo "自动修复结果"
  echo "----------------------------------------"
  echo "修复前：FAIL=${before_fail} WARN=${before_warn}"
  echo "修复后：FAIL=${after_fail} WARN=${after_warn}"
  echo "整体状态：${before_overall} -> ${after_overall}"
  if (( after_fail == 0 && after_warn < before_warn )); then
    echo "已恢复项: $((before_warn - after_warn))"
  else
    echo "已恢复项: 0"
  fi
  echo "剩余问题: FAIL=${after_fail} WARN=${after_warn}"
  LEIKWAN_BRIEF="$old_brief"
  LEIKWAN_COMPACT="$old_compact"
}

status_mark_result() {
  case "$1" in
    fail) STATUS_OVERVIEW_RESULT="fail" ;;
    warn) [[ "$STATUS_OVERVIEW_RESULT" == "fail" ]] || STATUS_OVERVIEW_RESULT="warn" ;;
  esac
}

status_cache_summary() {
  local kind="$1" file prefix time result
  case "$kind" in
    apply) file="${STATUS_DIR}/last-apply.env"; prefix="LAST_APPLY" ;;
    doctor) file="${STATUS_DIR}/last-doctor.env"; prefix="LAST_DOCTOR" ;;
    status) file="${STATUS_DIR}/last-status.env"; prefix="LAST_STATUS" ;;
    *) return 0 ;;
  esac
  time="$(env_file_get "$file" "${prefix}_TIME")"
  result="$(env_file_get "$file" "${prefix}_RESULT")"
  if [[ -n "$time" && -n "$result" ]]; then
    printf '%s / %s' "$time" "$(status_result_display "$result")"
  elif [[ -n "$time" ]]; then
    printf '%s' "$time"
  else
    printf '-'
  fi
}

named_status_summary() {
  local file="$1" prefix="$2" default_text="${3:-无记录}" time result mode
  time="$(env_file_get "$file" "${prefix}_TIME")"
  result="$(env_file_get "$file" "${prefix}_RESULT")"
  mode="$(env_file_get "$file" "${prefix}_MODE")"
  if [[ -n "$time" ]]; then
    if [[ -n "$mode" ]]; then
      printf '%s / %s' "$time" "$mode"
    elif [[ -n "$result" ]]; then
      printf '%s / %s' "$time" "$(status_result_display "$result")"
    else
      printf '%s' "$time"
    fi
  else
    printf '%s' "$default_text"
  fi
}

recent_status_error_line() {
  local label="$1" file="$2" prefix="$3" time result
  time="$(env_file_get "$file" "${prefix}_TIME")"
  result="$(env_file_get "$file" "${prefix}_RESULT")"
  case "${result,,}" in
    fail|failed)
      printf -- '- %s: failed at %s\n' "$label" "${time:-unknown}"
      ;;
    warn|warning)
      printf -- '- %s: warn at %s\n' "$label" "${time:-unknown}"
      ;;
  esac
}

status_recent_errors() {
  local errors
  errors="$(status_recent_errors_text)"
  if [[ -n "$errors" ]]; then
    echo "最近错误:"
    printf '%s\n' "$errors"
    status_mark_result warn
  else
    echo "最近错误: 无"
  fi
}

status_ddns_entry_summary() {
  local changed failed relay_needed
  changed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_ENTRY_CHANGED)"
  failed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_ENTRY_FAILED)"
  relay_needed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RELAY_RESTART_NEEDED)"
  if [[ -n "$failed" ]]; then
    status_mark_result warn
    printf 'WARN failed=%s' "$failed"
  elif [[ "${relay_needed,,}" == "true" && -n "$changed" ]]; then
    status_mark_result warn
    printf '%s changed，relay restart needed' "$changed"
  elif [[ -n "$changed" ]]; then
    printf '%s changed' "$changed"
  else
    printf 'OK'
  fi
}

status_ddns_pbr_summary() {
  local changed failed
  changed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_PBR_CHANGED)"
  failed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_PBR_FAILED)"
  if [[ -n "$failed" ]]; then
    status_mark_result warn
    printf 'WARN failed=%s' "$failed"
  elif [[ -n "$changed" ]]; then
    printf '%s changed' "$changed"
  else
    printf 'OK'
  fi
}

status_ddns_forward_summary() {
  local changed failed
  changed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_FORWARD_CHANGED)"
  failed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_FORWARD_FAILED)"
  if [[ -n "$failed" ]]; then
    status_mark_result warn
    printf 'WARN failed=%s' "$failed"
  elif [[ -n "$changed" ]]; then
    printf '%s changed' "$changed"
  else
    printf 'OK'
  fi
}

ddns_lts_line() {
  local timer_state result changed relay_needed
  timer_state="$(ddns_timer_state)"
  result="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RESULT)"
  [[ -n "$result" ]] || result="unknown"
  changed=$(( $(csv_count "$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_FORWARD_CHANGED)") + $(csv_count "$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_ENTRY_CHANGED)") + $(csv_count "$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_PBR_CHANGED)") ))
  relay_needed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RELAY_RESTART_NEEDED)"
  printf '%s, last %s, changed %s, relay restart needed: %s' "$(bool_enabled_disabled "$([[ "$timer_state" == "active" ]] && printf true || printf false)")" "$(status_result_display "$result")" "$changed" "$(bool_yes_no "${relay_needed:-false}")"
}

ddns_b_monitor_state_label() {
  local domain_count timer_state
  domain_count=$(( $(ddns_domain_forward_count 2>/dev/null || printf '0') + $(ddns_domain_entry_count 2>/dev/null || printf '0') + $(ddns_domain_pbr_count 2>/dev/null || printf '0') ))
  if [[ ! -f "$DDNS_CONFIG" && $domain_count -eq 0 ]]; then
    printf 'not configured'
    return 0
  fi
  timer_state="$(ddns_timer_state)"
  [[ "$timer_state" == "active" ]] && printf 'active' || printf 'disabled'
}

ddns_global_state_label() {
  ddns_b_monitor_state_label
}

ddns_entry_update_state_label() {
  local host timer_state
  host="$(entry_ddns_config_value ENTRY_DDNS_HOST "")"
  if [[ ! -f "$ENTRY_DDNS_CONFIG" || -z "$host" ]]; then
    printf 'not configured'
    return 0
  fi
  timer_state="$(entry_ddns_timer_state)"
  [[ "$timer_state" == "active" ]] && printf 'active' || printf 'disabled'
}

ddns_public_entry_change_label() {
  if [[ "$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RELAY_RESTART_NEEDED)" == "true" ]]; then
    status_mark_result warn
    printf 'relay restart needed'
  else
    printf 'none'
  fi
}

status_ddns_compact_block() {
  local split incomplete strategy
  split="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_SPLIT_DETECTED)"
  incomplete="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_INCOMPLETE_DETECTED)"
  strategy="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_STRATEGY)"
  [[ -n "$strategy" ]] || strategy="$(ddns_config_value DNS_RESOLVE_STRATEGY "$DNS_RESOLVE_STRATEGY_DEFAULT")"
  echo "DDNS:"
  echo "- 域名解析变化检测: $(ddns_global_state_label)"
  echo "- DNS 解析策略: ${strategy}"
  if [[ "${split,,}" == "true" ]]; then
    echo "- DNS 传播状态: 不一致"
  elif [[ "${incomplete,,}" == "true" ]]; then
    echo "- DNS 传播状态: 未完整检测"
  else
    echo "- DNS 传播状态: 一致"
  fi
  echo "- relay restart needed: $(bool_yes_no "$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RELAY_RESTART_NEEDED)")"
}

report_local_entry_ddns_status() {
  local host resolved public_ip
  host="$(current_entry_configured_public_host)"
  if [[ -z "$host" ]]; then
    report INFO "未配置本机公网入口域名，跳过 DDNS 一致性检查。"
    return 0
  fi
  if ! is_domain_name "$host"; then
    report INFO "本机公网入口地址不是域名，跳过 DDNS 一致性检查：${host}"
    return 0
  fi
  if resolve_domain_ipv4_multi "$host"; then
    resolved="$RESOLVE_SELECTED_IP"
  else
    resolved=""
  fi
  public_ip="$(detect_public_ipv4 2>/dev/null || true)"
  if [[ -z "$resolved" ]]; then
    report WARN "本机公网入口域名解析失败：${host}"
    return 0
  fi
  if [[ -z "$public_ip" ]]; then
    report WARN "无法获取当前公网 IPv4，跳过本机公网入口 DDNS 对比。"
    report INFO "域名解析：${resolved}"
    return 0
  fi
  if [[ "$resolved" == "$public_ip" ]]; then
    report OK "本机公网入口域名解析正常：${resolved}"
  else
    report WARN "本机公网入口域名解析与当前公网 IP 不一致。"
    report INFO "域名解析：${resolved}"
    report INFO "当前公网：${public_ip}"
    report INFO "请检查外部 DDNS 客户端或 DNS 解析。"
  fi
}

status_local_entry_ddns_line() {
  local host resolved public_ip
  host="$(current_entry_configured_public_host)"
  if [[ -z "$host" ]]; then
    printf 'skipped'
    return 0
  fi
  if ! is_domain_name "$host"; then
    printf 'skipped'
    return 0
  fi
  if resolve_domain_ipv4_multi "$host"; then
    resolved="$RESOLVE_SELECTED_IP"
  else
    resolved=""
  fi
  public_ip="$(detect_public_ipv4 2>/dev/null || true)"
  if [[ -z "$resolved" || -z "$public_ip" ]]; then
    status_mark_result warn
    printf 'WARN，建议执行 lq --doctor'
  elif [[ "$resolved" == "$public_ip" ]]; then
    printf 'OK %s' "$resolved"
  else
    status_mark_result warn
    printf 'WARN %s != %s' "$resolved" "$public_ip"
  fi
}

status_entry_ddns_updater_summary() {
  local host enabled last_result public_ip resolved_ip
  host="$(entry_ddns_config_value ENTRY_DDNS_HOST "$(current_entry_configured_public_host)")"
  enabled="$(entry_ddns_config_value ENTRY_DDNS_ENABLED "$ENTRY_DDNS_ENABLED_DEFAULT")"
  last_result="$(entry_ddns_status_value LAST_ENTRY_DDNS_RESULT)"
  public_ip="$(entry_ddns_status_value LAST_ENTRY_DDNS_PUBLIC_IP)"
  resolved_ip="$(entry_ddns_status_value LAST_ENTRY_DDNS_RESOLVED_IP)"
  if [[ -z "$host" ]]; then
    printf '未配置'
  elif [[ "$enabled" != "true" ]]; then
    printf 'WARN disabled'
  elif [[ -n "$public_ip" && -n "$resolved_ip" && "$public_ip" == "$resolved_ip" ]]; then
    printf 'OK %s' "$host"
  elif [[ -n "$last_result" ]]; then
    [[ "${last_result,,}" == "ok" ]] || status_mark_result warn
    printf '%s %s' "$(status_result_display "$last_result")" "$host"
  else
    printf 'enabled %s' "$host"
  fi
}

report_entry_ddns_updater_status() {
  local host enabled
  host="$(current_entry_configured_public_host)"
  [[ -n "$host" ]] || return 0
  is_domain_name "$host" || return 0
  enabled="$(entry_ddns_config_value ENTRY_DDNS_ENABLED "$ENTRY_DDNS_ENABLED_DEFAULT")"
  if ddns_config_bool DDNS_UPDATE_DNS_RECORD "$DDNS_UPDATE_DNS_RECORD_DEFAULT"; then
  if [[ "${enabled,,}" == "true" ]]; then
    report OK "兼容 DNS 记录更新已启用：${host}"
  else
      report WARN "DDNS_UPDATE_DNS_RECORD=true，但兼容 DNS 更新入口未启用。"
      report INFO "只有确实希望 Toolkit 修改 DNS 服务商记录时才需要配置 provider/token。"
    fi
  else
    report INFO "DNS 服务商记录更新未启用；默认仅检测解析变化并刷新本地配置。"
  fi
}

report_b_ddns_entry_monitor_status() {
  local entry_count timer_state restart_needed
  entry_count="$(ddns_domain_entry_count 2>/dev/null || printf '0')"
  timer_state="$(ddns_timer_state)"
  restart_needed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RELAY_RESTART_NEEDED)"
  if (( entry_count > 0 )) && [[ "$timer_state" != "active" ]]; then
    report INFO "检测到公网入口域名，建议启用域名解析变化检测：lq ddns enable"
  fi
  if [[ "${restart_needed:-false}" == "true" ]]; then
    report WARN "公网入口域名解析已变化，relay 可能需要重启。"
    report INFO "可执行：lq ddns apply-entries"
  fi
}

domain_used_by_forward_pbr() {
  local domain="$1"
  [[ -n "$domain" ]] || return 1
  if forwards_rows | awk -F'\t' -v host="$domain" '$3==host {found=1} END{exit found ? 0 : 1}'; then
    return 0
  fi
  [[ -f "$PBR_STATIC_CONF" ]] || return 1
  awk -v host="$domain" '
    /^[[:space:]]*($|#)/ { next }
    $3 == "forward" && $5 == host { found=1 }
    END { exit found ? 0 : 1 }
  ' "$PBR_STATIC_CONF"
}

report_forward_pbr_dns_split_context() {
  local domain="$1" selected=""
  domain_used_by_forward_pbr "$domain" || return 1
  if resolve_domain_ipv4_for_forward_pbr "$domain"; then
    selected="$RESOLVE_SELECTED_IP"
  else
    return 1
  fi
  [[ "$RESOLVE_SPLIT_DETECTED" == "true" ]] || return 1
  report WARN "检测到 DNS 传播不一致：${domain}"
  report INFO "转发/PBR 场景当前采用多数结果：${selected}"
  return 0
}

report_ddns_global_state() {
  local public_ip public_source result last_time forward_failed entry_failed pbr_failed restart_needed update_dns dns_split dns_domain dns_selected ddns_enabled timer_state
  public_ip="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_PUBLIC_IP)"
  public_source="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_PUBLIC_IP_SOURCE)"
  result="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RESULT)"
  last_time="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_TIME)"
  forward_failed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_FORWARD_FAILED)"
  entry_failed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_ENTRY_FAILED)"
  pbr_failed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_PBR_FAILED)"
  restart_needed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RELAY_RESTART_NEEDED)"
  update_dns="$(ddns_config_value DDNS_UPDATE_DNS_RECORD "$DDNS_UPDATE_DNS_RECORD_DEFAULT")"
  dns_split="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_SPLIT_DETECTED)"
  dns_domain="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_SPLIT_DOMAIN)"
  dns_selected="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_SELECTED_IP)"
  ddns_enabled="$(ddns_config_value DDNS_GLOBAL_ENABLED "$DDNS_GLOBAL_ENABLED_DEFAULT")"
  timer_state="$(ddns_timer_state)"
  if [[ -n "$last_time" && -n "$public_ip" && -n "$public_source" && "${result,,}" != "fail" ]]; then
    report OK "辅助公网 IP 检测最近成功：${public_ip} (${public_source:-unknown})"
  elif [[ "${result,,}" == "fail" ]]; then
    report WARN "辅助公网 IP 检测失败，请检查网络或自定义 PUBLIC_IP_CHECK_URLS。"
  elif [[ -n "$last_time" && -z "$public_ip" ]]; then
    report WARN "辅助公网 IP 检测最近没有可用结果，请检查网络或自定义 PUBLIC_IP_CHECK_URLS。"
  else
    report INFO "尚无辅助公网 IP 检测缓存；域名解析变化检测仍可执行：lq ddns run"
  fi
  if [[ -n "$forward_failed$entry_failed$pbr_failed" ]]; then
    report WARN "存在域名解析失败，请检查 DNS。"
    [[ -n "$forward_failed" ]] && report INFO "后端域名失败：${forward_failed}"
    [[ -n "$entry_failed" ]] && report INFO "公网入口域名失败：${entry_failed}"
    [[ -n "$pbr_failed" ]] && report INFO "PBR 域名失败：${pbr_failed}"
  fi
  if [[ "${dns_split,,}" == "true" ]]; then
    if report_forward_pbr_dns_split_context "$dns_domain"; then
      [[ -n "$dns_selected" ]] && report INFO "DDNS 策略最近采用（不用于转发/PBR 写入）：${dns_selected}"
    else
      report WARN "检测到 DNS 传播不一致：${dns_domain:-未知域名}，DDNS 策略最近采用 ${dns_selected:-未知 IP}。"
      report INFO "可调整 DNS_RESOLVE_SERVERS 或 DNS_RESOLVE_STRATEGY。"
    fi
  fi
  if { [[ "${ddns_enabled,,}" == "true" ]] || [[ "$timer_state" == "active" ]]; } && ! command -v dig >/dev/null 2>&1; then
    report WARN "dig 不存在，已尝试自动安装 dnsutils；当前将使用 nslookup / host / getent fallback。"
  fi
  if [[ "${restart_needed:-false}" == "true" ]]; then
    report WARN "relay restart needed: yes，请在维护窗口重启 relay。"
  fi
  if [[ "${update_dns,,}" == "true" ]]; then
    report WARN "DDNS_UPDATE_DNS_RECORD=true，只有显式需要 Toolkit 修改 DNS 记录时才应配置 provider/token。"
  else
    report INFO "DDNS_UPDATE_DNS_RECORD=false，默认不需要 DNS provider token。"
  fi
}

report_entry_ddns_cache_status() {
  local name public_host _et_ip _proto _port _weight enabled cached_ip checked=0
  while IFS=$'\t' read -r name public_host _et_ip _proto _port _weight enabled; do
    [[ "$enabled" == "true" ]] || continue
    is_domain_name "$public_host" || continue
    checked=$((checked + 1))
    cached_ip="$(last_resolved_ip_for_entry "$name")"
    if [[ -n "$cached_ip" ]]; then
      report OK "公网入口 ${name} 解析缓存：${public_host} -> ${cached_ip}"
    else
      report WARN "公网入口 ${name} 缺少解析缓存，请执行：lq ddns run"
    fi
  done < <(entries_rows)
  if (( checked == 0 )); then
    report INFO "未发现 enabled 域名公网入口。"
  fi
  if [[ "$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RELAY_RESTART_NEEDED)" == "true" ]]; then
    report WARN "公网入口域名解析已变化，relay 可能需要重启。"
    report INFO "可执行：lq ddns apply-entries"
  fi
}

pbr_domain_rule_matches() {
  local name="$1" cidr="$2" route_table="$3"
  [[ -f "$PBR_STATIC_CONF" ]] || return 1
  awk -v src="pbr-domain:${name}" -v cidr="$cidr" -v table="${route_table#T_}" '
    /^[[:space:]]*($|#)/ { next }
    {
      g=$2
      sub(/^T_/, "", g)
      if ($1 == cidr && g == table && $3 == src) found=1
    }
    END { exit found ? 0 : 1 }
  ' "$PBR_STATIC_CONF"
}

report_pbr_domain_ddns_status() {
  local name host route_table enabled _comment cached_ip current_ip cidr checked=0
  while IFS=$'\t' read -r name host route_table enabled _comment; do
    [[ "$enabled" == "true" ]] || continue
    checked=$((checked + 1))
    if ! is_domain_name "$host"; then
      report WARN "域名 PBR ${name} host 不是域名：${host}"
      continue
    fi
    if resolve_domain_ipv4_multi "$host"; then
      current_ip="$RESOLVE_SELECTED_IP"
    else
      current_ip=""
    fi
    cached_ip="$(last_resolved_ip_for_pbr_domain "$name")"
    if [[ -z "$current_ip" ]]; then
      report WARN "域名 PBR ${name} 解析失败：${host}"
      continue
    fi
    if [[ -n "$cached_ip" && "$cached_ip" != "$current_ip" ]]; then
      report WARN "域名 PBR ${name} 已变化，请执行：lq pbr domain sync"
    else
      report OK "域名 PBR ${name} 解析：${host} -> ${current_ip}"
    fi
    cidr="${current_ip}/32"
    if pbr_domain_rule_matches "$name" "$cidr" "$route_table"; then
      report OK "域名 PBR ${name} 生成规则存在：${cidr} -> ${route_table}"
    elif pbr_rule_key_exists "$PBR_STATIC_CONF" "$cidr" "$route_table"; then
      report INFO "域名 PBR ${name} 对应 CIDR/table 已由其它 PBR 规则覆盖：${cidr} -> ${route_table}"
    else
      report WARN "域名 PBR ${name} 生成规则缺失，请执行：lq pbr domain sync"
    fi
  done < <(pbr_domain_rows)
  if (( checked == 0 )); then
    report INFO "未配置 enabled 域名 PBR。"
  fi
}

systemd_active_state() {
  local service="$1" state
  if ! command -v systemctl >/dev/null 2>&1; then
    printf 'unknown'
    return 1
  fi
  state="$(systemctl is-active "$service" 2>/dev/null || true)"
  printf '%s' "${state:-inactive}"
  [[ "$state" == "active" ]]
}

status_nft_summary() {
  local mode="$1" relay_ip="${2:-}" start="${3:-}" end="${4:-}" forwards_enabled="${5:-0}"
  if ! command -v nft >/dev/null 2>&1; then
    printf 'WARN，建议执行 lq --doctor'
    status_mark_result warn
    return 0
  fi
  if ! nft_project_table_exists; then
    printf 'WARN，建议执行 lq --doctor'
    status_mark_result warn
    return 0
  fi
  case "$mode" in
    cloud-entry)
      if [[ -n "$relay_ip" && -n "$start" && -n "$end" ]] &&
        nft_has_cloud_dnat tcp "$relay_ip" "${start}-${end}" &&
        nft_has_cloud_dnat udp "$relay_ip" "${start}-${end}"; then
        printf 'OK'
      else
        printf 'WARN，建议执行 lq --doctor'
        status_mark_result warn
      fi
      ;;
    leikwan-relay)
      if (( forwards_enabled == 0 )) || nft_has_dnat_rules; then
        printf 'OK'
      else
        printf 'WARN，建议执行 lq --doctor'
        status_mark_result warn
      fi
      ;;
    *)
      printf 'OK'
      ;;
  esac
}

status_mss_summary() {
  if ! mss_clamp_enabled; then
    printf 'disabled'
    return 0
  fi
  if nft_has_mss_clamp; then
    printf 'OK'
  else
    printf 'WARN，建议执行 lq forward apply-relay --auto-fix-route'
    status_mark_result warn
  fi
}

status_overview_relay() {
  local service_state relay_ip entries_total entries_enabled forwards_total forwards_enabled
  local primary_row primary_name primary_proto primary_port pbr_count last_apply last_doctor
  local ddns_timer ddns_last_time ddns_last_result ddns_forward_count ddns_entry_count ddns_pbr_count
  local ddns_refresh_forwards ddns_refresh_entries ddns_refresh_pbr
  service_state="$(systemd_active_state "${EASYTIER_RELAY_SERVICE_NAME}.service" || true)"
  [[ "$service_state" == "active" ]] || status_mark_result warn
  relay_ip="$(current_relay_et_ip)"
  entries_total="$(entries_rows | awk 'END{print NR+0}')"
  entries_enabled="$(entries_rows | awk -F'\t' '$7=="true"{c++} END{print c+0}')"
  forwards_total="$(forwards_rows | awk 'END{print NR+0}')"
  forwards_enabled="$(forwards_rows | awk -F'\t' '$7=="true"{c++} END{print c+0}')"
  primary_row="$(enabled_entries_sorted | awk -F'\t' 'BEGIN{OFS=sprintf("%c", 28)} NR==1 {print $1,$4,$5; exit}')"
  if [[ -n "$primary_row" ]]; then
    IFS=$'\034' read -r primary_name primary_proto primary_port <<<"$primary_row"
  else
    primary_name="无"
    primary_proto="-"
    primary_port="-"
    status_mark_result warn
  fi
  pbr_count="$(pbr_rules_count 2>/dev/null || printf '0')"
  last_apply="$(status_cache_summary apply)"
  last_doctor="$(status_cache_summary doctor)"
  ddns_timer="$(ddns_timer_state)"
  ddns_last_time="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_TIME)"
  ddns_last_result="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RESULT)"
  ddns_refresh_forwards="$(ddns_config_value DDNS_REFRESH_FORWARDS "$DDNS_REFRESH_FORWARDS_DEFAULT")"
  ddns_refresh_entries="$(ddns_config_value DDNS_REFRESH_ENTRIES "$DDNS_REFRESH_ENTRIES_DEFAULT")"
  ddns_refresh_pbr="$(ddns_config_value DDNS_REFRESH_PBR "$DDNS_REFRESH_PBR_DEFAULT")"
  ddns_forward_count="$(ddns_domain_forward_count 2>/dev/null || printf '0')"
  ddns_entry_count="$(ddns_domain_entry_count 2>/dev/null || printf '0')"
  ddns_pbr_count="$(ddns_domain_pbr_count 2>/dev/null || printf '0')"
  echo "角色: leikwan-relay"
  echo "EasyTier: relay ${service_state}"
  echo "Relay IP: ${relay_ip}"
  echo "公网入口: ${entries_enabled} enabled / ${entries_total} total"
  if [[ "$primary_name" == "无" ]]; then
    echo "主入口: 无"
  else
    echo "主入口: $(entry_label "$primary_name") $(easytier_protocols_display "$primary_proto")/${primary_port}"
  fi
  echo "转发目标: ${forwards_enabled} enabled / ${forwards_total} total"
  echo "PBR 规则: ${pbr_count}"
  echo "nftables: $(status_nft_summary leikwan-relay "" "" "" "$forwards_enabled")"
  echo "MSS clamp: $(status_mss_summary)"
  echo "DDNS: $(ddns_lts_line)"
  if [[ -n "$ddns_last_time" ]]; then
    echo "最近检测: ${ddns_last_time} / $(status_result_display "$ddns_last_result")"
    echo "辅助公网 IP 检测源: $(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_PUBLIC_IP_SOURCE)"
    echo "DNS 解析策略: $(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_STRATEGY)"
    echo "DNS 解析器: $(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_SERVERS)"
    if [[ "$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_SPLIT_DETECTED)" == "true" ]]; then
      echo "DNS 传播状态: 不一致"
    elif [[ "$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_DNS_INCOMPLETE_DETECTED)" == "true" ]]; then
      echo "DNS 传播状态: 未完整检测"
    else
      echo "DNS 传播状态: 一致"
    fi
    echo "后端域名检测: $(status_ddns_forward_summary)"
    echo "公网入口域名检测: $(status_ddns_entry_summary)"
    echo "PBR 域名检测: $(status_ddns_pbr_summary)"
    echo "nftables 应用状态: $(ddns_action_text "$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_NFT_APPLIED)" "已重应用" "待重应用" "无需重应用")"
    echo "PBR 同步状态: $(ddns_action_text "$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_PBR_APPLIED)" "已同步" "待同步" "无需同步")"
  else
    echo "最近检测: -"
    echo "后端域名检测: -"
    echo "公网入口域名检测: -"
    echo "PBR 域名检测: -"
  fi
  status_ddns_compact_block
  if (( ddns_entry_count > 0 )) && [[ "$ddns_timer" != "active" ]]; then
    echo "[INFO] 检测到公网入口域名，建议启用域名解析变化检测：lq ddns enable"
  elif (( (ddns_forward_count + ddns_entry_count + ddns_pbr_count) > 0 )) && [[ "$ddns_timer" != "active" ]]; then
    echo "[INFO] 检测到域名对象，可在 DDNS 菜单中启用域名解析变化检测。"
  fi
  if [[ "$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RELAY_RESTART_NEEDED)" == "true" ]]; then
    echo "[WARN] 公网入口域名解析已变化，relay 可能需要重启。"
    echo "[INFO] 可执行：lq ddns apply-entries"
    status_mark_result warn
  fi
  echo "最近应用: ${last_apply}"
  echo "最近诊断: ${last_doctor}"
}

status_overview_entry() {
  local entry_name display_name et_ip proto port service_name service_state start end relay_ip last_doctor public_host
  entry_name="$(env_file_get "$NETWORK_ENV" ENTRY_NAME)"
  [[ -n "$entry_name" ]] || entry_name="$(env_file_get "$ENTRY_PAIRING_FILE" ENTRY_NAME)"
  display_name="$(env_file_get "$NETWORK_ENV" ENTRY_DISPLAY_NAME)"
  [[ -n "$display_name" ]] || display_name="$(env_file_get "$ENTRY_PAIRING_FILE" ENTRY_DISPLAY_NAME)"
  [[ -n "$entry_name" ]] || entry_name="entry"
  [[ -n "$display_name" ]] || display_name="$(entry_label "$entry_name")"
  et_ip="$(current_entry_et_ip)"
  proto="$(easytier_protocols_from_env "$NETWORK_ENV" EASYTIER_PROTOCOLS EASYTIER_PROTOCOL "$EASYTIER_PROTOCOLS_DEFAULT" 2>/dev/null || printf '%s' "$EASYTIER_PROTOCOLS_DEFAULT")"
  port="$(easytier_port_from_env "$NETWORK_ENV" "$proto" EASYTIER_TCP_PORT EASYTIER_UDP_PORT EASYTIER_LISTEN_PORT 2>/dev/null || true)"
  [[ -n "$port" ]] || port="$(easytier_port_from_env "$ENTRY_PAIRING_FILE" "$proto" EASYTIER_TCP_PORT EASYTIER_UDP_PORT EASYTIER_PORT 2>/dev/null || printf '%s' "$EASYTIER_PORT_DEFAULT")"
  service_name="$(entry_service_name "$entry_name").service"
  service_state="$(systemd_active_state "$service_name" || true)"
  [[ "$service_state" == "active" ]] || status_mark_result warn
  start="$(entry_expose_start)"
  end="$(entry_expose_end)"
  relay_ip="$(entry_expose_relay_ip)"
  last_doctor="$(status_cache_summary doctor)"
  public_host="$(current_entry_configured_public_host)"
  echo "角色: cloud-entry"
  echo "入口名称: ${display_name}"
  echo "EasyTier IP: ${et_ip}"
  echo "EasyTier service: ${service_state}"
  echo "监听: $(easytier_protocols_display "$proto")/${port}"
  echo "公网入口端口池: ${start}-${end}"
  echo "本机公网入口 DDNS: $(status_local_entry_ddns_line)"
  echo "兼容 DNS 更新: $(status_entry_ddns_updater_summary)"
  status_ddns_compact_block
  if [[ -n "$public_host" ]] && is_domain_name "$public_host" && ! entry_ddns_config_bool ENTRY_DDNS_ENABLED "$ENTRY_DDNS_ENABLED_DEFAULT"; then
    echo "[INFO] 当前公网入口使用域名；如果由路由器、服务商客户端或外部 DDNS 维护，可忽略兼容 DNS 更新。"
    echo "[INFO] 建议使用：lq ddns run"
  fi
  echo "nftables: $(status_nft_summary cloud-entry "$relay_ip" "$start" "$end" 0)"
  echo "MSS clamp: $(status_mss_summary)"
  echo "最近诊断: ${last_doctor}"
}

status_next_steps() {
  local role="$1" entries_enabled forwards_enabled
  echo "下一步建议:"
  case "$role" in
    leikwan-relay)
      entries_enabled="$(entries_rows | awk -F'\t' '$7=="true"{c++} END{print c+0}')"
      forwards_enabled="$(forwards_rows | awk -F'\t' '$7=="true"{c++} END{print c+0}')"
      if (( entries_enabled == 0 )); then
        echo "- 尚未添加公网入口：执行 lq init 或 利群主机 -> 公网入口列表管理"
      fi
      if (( forwards_enabled == 0 )); then
        echo "- 尚未添加转发目标：执行 利群主机 -> 转发目标管理"
      fi
      if (( entries_enabled > 0 && forwards_enabled > 0 )); then
        echo "- 当前状态正常。"
        echo "- 可执行 lq output generate 生成端点输出。"
      fi
      ;;
    cloud-entry)
      if [[ ! -f "$ENTRY_PAIRING_FILE" && ! -f "$NETWORK_ENV" ]]; then
        echo "- 请粘贴 B 生成的公网入口接入码。"
        echo "- 部署完成后将 ENTRY 返回码复制回 B。"
      else
        echo "- 当前公网入口已配置。"
        echo "- 可执行 lq status 或 lq --doctor 检查入口状态。"
      fi
      ;;
    *)
      echo "- 首次部署建议执行 lq init。"
      echo "- 如已有迁移包，可执行 lq config inspect 后导入。"
      ;;
  esac
}

status_health_line() {
  local role="$1" forwards_enabled nft_status mss_status ddns_result health
  forwards_enabled="$(forwards_rows | awk -F'\t' '$7=="true"{c++} END{print c+0}')"
  case "$role" in
    leikwan-relay) nft_status="$(status_nft_summary leikwan-relay "" "" "" "$forwards_enabled")" ;;
    cloud-entry) nft_status="$(status_nft_summary cloud-entry "$(entry_expose_relay_ip)" "$(entry_expose_start)" "$(entry_expose_end)" 0)" ;;
    *) nft_status="$(status_nft_summary unknown)" ;;
  esac
  mss_status="$(status_mss_summary)"
  ddns_result="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RESULT)"
  [[ -n "$ddns_result" ]] || ddns_result="unknown"
  health="$(health_score_value "$role" "$nft_status" "$mss_status" "$ddns_result")"
  echo "系统健康度: ${health}/100 ($(health_level "$health"))"
}

status_lts() {
  local role_info role _role_source role_mixed role_text entries_enabled forwards_enabled pbr_count
  local nft_status mss_status ddns_result health overall
  STATUS_OVERVIEW_RESULT="ok"
  if [[ ! -d "$STATE_DIR" ]]; then
    echo "Leikwan 状态"
    echo "----------------------------------------"
    echo "版本: $(tool_version_label)"
    echo "角色: unknown"
    echo "健康度: 50/100 warning"
    echo "整体状态: WARN"
    echo "[INFO] 未检测到 Leikwan 配置目录。"
    echo "[INFO] 当前机器可能尚未初始化，建议执行：lq init"
    return 0
  fi
  role_info="$(role_summary)"
  IFS=$'\t' read -r role _role_source role_mixed <<<"$role_info"
  entries_enabled="$(entries_rows | awk -F'\t' '$7=="true"{c++} END{print c+0}')"
  forwards_enabled="$(forwards_rows | awk -F'\t' '$7=="true"{c++} END{print c+0}')"
  pbr_count="$(pbr_rules_count 2>/dev/null || printf '0')"
  case "$role" in
    leikwan-relay)
      role_text="relay"
      nft_status="$(status_nft_summary leikwan-relay "" "" "" "$forwards_enabled")"
      ;;
    cloud-entry)
      role_text="entry"
      nft_status="$(status_nft_summary cloud-entry "$(entry_expose_relay_ip)" "$(entry_expose_start)" "$(entry_expose_end)" 0)"
      ;;
    *)
      role_text="unknown"
      nft_status="$(status_nft_summary unknown)"
      status_mark_result warn
      ;;
  esac
  [[ "$role_mixed" == "true" ]] && status_mark_result warn
  mss_status="$(status_mss_summary)"
  ddns_result="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RESULT)"
  [[ -n "$ddns_result" ]] || ddns_result="ok"
  case "${ddns_result,,}" in
    fail|failed|warn|warning) status_mark_result warn ;;
  esac
  health="$(health_score_value "$role" "$nft_status" "$mss_status" "$ddns_result")"
  overall="$STATUS_OVERVIEW_RESULT"
  echo "Leikwan 状态"
  echo "----------------------------------------"
  echo "版本: $(tool_version_label)"
  echo "角色: ${role_text}"
  echo "健康度: ${health}/100 $(health_level "$health")"
  echo "公网入口: ${entries_enabled} enabled"
  echo "转发目标: ${forwards_enabled} enabled"
  echo "DDNS: $(ddns_lts_line)"
  echo "nftables: $([[ "$nft_status" == OK* ]] && printf 'OK' || printf 'WARN')"
  echo "PBR: $([[ "$pbr_count" =~ ^[0-9]+$ ]] && printf 'OK' || printf 'WARN')"
  echo "整体状态: $(status_result_display "$overall")"
  write_status_cache status "$overall"
}

status_brief() {
  local role_info role role_text entries_enabled forwards_enabled pbr_count service_state nft_status mss_status ddns_result overall health
  STATUS_OVERVIEW_RESULT="ok"
  role_info="$(role_summary)"
  IFS=$'\t' read -r role _role_source _role_mixed <<<"$role_info"
  entries_enabled="$(entries_rows | awk -F'\t' '$7=="true"{c++} END{print c+0}')"
  forwards_enabled="$(forwards_rows | awk -F'\t' '$7=="true"{c++} END{print c+0}')"
  pbr_count="$(pbr_rules_count 2>/dev/null || printf '0')"
  case "$role" in
    leikwan-relay)
      role_text="relay"
      service_state="$(systemd_active_state "${EASYTIER_RELAY_SERVICE_NAME}.service" || true)"
      nft_status="$(status_nft_summary leikwan-relay "" "" "" "$forwards_enabled")"
      ;;
    cloud-entry)
      role_text="entry"
      service_state="$(systemd_active_state "$(entry_service_name "$(env_file_get "$NETWORK_ENV" ENTRY_NAME)").service" || true)"
      nft_status="$(status_nft_summary cloud-entry "$(entry_expose_relay_ip)" "$(entry_expose_start)" "$(entry_expose_end)" 0)"
      ;;
    *)
      role_text="unknown"
      service_state="unknown"
      nft_status="$(status_nft_summary unknown)"
      status_mark_result warn
      ;;
  esac
  mss_status="$(status_mss_summary)"
  ddns_result="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RESULT)"
  [[ -n "$ddns_result" ]] || ddns_result="unknown"
  health="$(health_score_value "$role" "$nft_status" "$mss_status" "$ddns_result")"
  overall="$STATUS_OVERVIEW_RESULT"
  echo "Leikwan Status"
  echo "----------------------------------------"
  echo "Role: ${role_text}"
  echo "EasyTier: $([[ "$service_state" == "active" ]] && printf 'OK' || printf 'WARN')"
  echo "Entries: ${entries_enabled} enabled"
  echo "Forwards: ${forwards_enabled} enabled"
  echo "PBR: ${pbr_count}"
  echo "DDNS: $(ddns_lts_line)"
  echo "nftables: $([[ "$nft_status" == OK* ]] && printf 'OK' || printf 'WARN')"
  echo "Health: ${health}/100 ($(health_level "$health"))"
  echo "Overall: $(status_result_display "$overall")"
}

status_overview() {
  local role role_info role_source role_mixed
  STATUS_OVERVIEW_RESULT="ok"
  role_info="$(role_summary)"
  IFS=$'\t' read -r role role_source role_mixed <<<"$role_info"
  echo "Leikwan 状态总览"
  echo "----------------------------------------"
  echo "脚本版本: $(tool_version_label)"
  if [[ ! -d "$STATE_DIR" ]]; then
    echo "[INFO] 未检测到 Leikwan 配置目录。"
    echo "[INFO] 当前机器可能尚未初始化，建议执行：lq init"
    status_mark_result warn
  fi
  echo "角色来源: ${role_source:-无}"
  if [[ "$role_mixed" == "true" ]]; then
    echo "[WARN] 检测到高级混合部署：relay + entry"
    echo "[INFO] 请确认这是否为高级部署，否则建议执行 lq --doctor。"
    status_mark_result warn
  fi
  echo "最近更新: $(update_status_line)"
  status_lock_lines
  status_recent_errors
  case "$role" in
    leikwan-relay) status_overview_relay ;;
    cloud-entry) status_overview_entry ;;
    *)
      echo "角色: unknown"
      echo "nftables: $(status_nft_summary unknown)"
      echo "MSS clamp: $(status_mss_summary)"
      status_mark_result warn
      ;;
  esac
  echo "最近配置导出: $(named_status_summary "${STATUS_DIR}/last-config-export.env" LAST_CONFIG_EXPORT)"
  echo "最近配置导入: $(named_status_summary "${STATUS_DIR}/last-config-import.env" LAST_CONFIG_IMPORT)"
  echo "最近端点输出: $(named_status_summary "${STATUS_DIR}/last-output.env" LAST_OUTPUT)"
  status_health_line "$role"
  status_next_steps "$role"
  echo "整体状态: $(status_result_display "$STATUS_OVERVIEW_RESULT")"
  write_status_cache status "$STATUS_OVERVIEW_RESULT"
  if [[ "$STATUS_OVERVIEW_RESULT" == "ok" ]]; then
    echo "[OK] 当前状态正常。"
  else
    echo "[INFO] 建议执行：lq --doctor"
  fi
}

json_array() {
  local first=1 item
  printf '['
  for item in "$@"; do
    (( first == 0 )) && printf ','
    printf '"%s"' "$(json_escape "$item")"
    first=0
  done
  printf ']'
}

health_level() {
  local score="$1"
  if (( score >= 90 )); then
    printf 'excellent'
  elif (( score >= 75 )); then
    printf 'good'
  elif (( score >= 50 )); then
    printf 'warning'
  else
    printf 'critical'
  fi
}

health_score_value() {
  local role="$1" nft_status="$2" mss_status="$3" ddns_result="$4"
  local score=100 entries_enabled forwards_enabled pbr_count service_state
  entries_enabled="$(entries_rows | awk -F'\t' '$7=="true"{c++} END{print c+0}')"
  forwards_enabled="$(forwards_rows | awk -F'\t' '$7=="true"{c++} END{print c+0}')"
  pbr_count="$(pbr_rules_count 2>/dev/null || printf '0')"
  case "$role" in
    leikwan-relay)
      service_state="$(systemd_active_state "${EASYTIER_RELAY_SERVICE_NAME}.service" || true)"
      [[ "$service_state" == "active" ]] || score=$((score - 20))
      et_ip_present "$RELAY_ET_IP" || score=$((score - 15))
      (( entries_enabled > 0 )) || score=$((score - 15))
      (( forwards_enabled > 0 )) || score=$((score - 15))
      ;;
    cloud-entry)
      service_state="$(systemd_active_state "$(entry_service_name "$(env_file_get "$NETWORK_ENV" ENTRY_NAME)").service" || true)"
      [[ "$service_state" == "active" ]] || score=$((score - 20))
      et_ip_present "$(current_entry_et_ip)" || score=$((score - 15))
      ;;
    *)
      score=$((score - 35))
      ;;
  esac
  if [[ "$role" == "leikwan-relay" ]]; then
    (( pbr_count > 0 )) || score=$((score - 10))
  fi
  [[ "$nft_status" == OK* ]] || score=$((score - 10))
  [[ "$mss_status" == OK* || "$mss_status" == "disabled" ]] || score=$((score - 5))
  case "${ddns_result,,}" in
    fail|failed) score=$((score - 5)) ;;
    warn|warning) score=$((score - 3)) ;;
  esac
  if [[ "$(status_recent_errors_text)" != "" ]]; then
    score=$((score - 5))
  fi
  (( score < 0 )) && score=0
  (( score > 100 )) && score=100
  printf '%s' "$score"
}

status_recent_errors_text() {
  {
    recent_status_error_line "DDNS" "$DDNS_STATUS_FILE" LAST_DDNS
    recent_status_error_line "Update" "$UPDATE_STATUS_FILE" LAST_UPDATE
    recent_status_error_line "Doctor" "${STATUS_DIR}/last-doctor.env" LAST_DOCTOR
    recent_status_error_line "Config import" "${STATUS_DIR}/last-config-import.env" LAST_CONFIG_IMPORT
  } | sed '/^[[:space:]]*$/d'
}

status_json() {
  local role_info role role_source role_mixed entries_total entries_enabled forwards_total forwards_enabled pbr_count
  local nft_status mss_status ddns_result overall health warnings=() failures=()
  local entry_ddns_enabled entry_ddns_host entry_ddns_public_ip entry_ddns_resolved_ip entry_ddns_match relay_restart_needed
  STATUS_OVERVIEW_RESULT="ok"
  role_info="$(role_summary)"
  IFS=$'\t' read -r role role_source role_mixed <<<"$role_info"
  entries_total="$(entries_rows | awk 'END{print NR+0}')"
  entries_enabled="$(entries_rows | awk -F'\t' '$7=="true"{c++} END{print c+0}')"
  forwards_total="$(forwards_rows | awk 'END{print NR+0}')"
  forwards_enabled="$(forwards_rows | awk -F'\t' '$7=="true"{c++} END{print c+0}')"
  pbr_count="$(pbr_rules_count 2>/dev/null || printf '0')"
  case "$role" in
    leikwan-relay) nft_status="$(status_nft_summary leikwan-relay "" "" "" "$forwards_enabled")" ;;
    cloud-entry) nft_status="$(status_nft_summary cloud-entry "$(entry_expose_relay_ip)" "$(entry_expose_start)" "$(entry_expose_end)" 0)" ;;
    *) nft_status="$(status_nft_summary unknown)"; status_mark_result warn ;;
  esac
  mss_status="$(status_mss_summary)"
  ddns_result="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RESULT)"
  [[ -n "$ddns_result" ]] || ddns_result="unknown"
  entry_ddns_enabled="$(entry_ddns_config_value ENTRY_DDNS_ENABLED "$ENTRY_DDNS_ENABLED_DEFAULT")"
  entry_ddns_host="$(entry_ddns_config_value ENTRY_DDNS_HOST "")"
  entry_ddns_public_ip="$(entry_ddns_status_value LAST_ENTRY_DDNS_PUBLIC_IP)"
  entry_ddns_resolved_ip="$(entry_ddns_status_value LAST_ENTRY_DDNS_RESOLVED_IP)"
  relay_restart_needed="$(env_file_get "$DDNS_STATUS_FILE" LAST_DDNS_RELAY_RESTART_NEEDED)"
  entry_ddns_match="unknown"
  if [[ -n "$entry_ddns_public_ip" && -n "$entry_ddns_resolved_ip" ]]; then
    [[ "$entry_ddns_public_ip" == "$entry_ddns_resolved_ip" ]] && entry_ddns_match="ok" || entry_ddns_match="warn"
  elif [[ -z "$entry_ddns_host" ]]; then
    entry_ddns_match="not_configured"
  fi
  [[ "$role_mixed" == "true" ]] && warnings+=("mixed role")
  [[ ! -d "$STATE_DIR" ]] && warnings+=("state dir missing")
  [[ "${relay_restart_needed:-false}" == "true" ]] && warnings+=("relay restart needed after public entry domain change")
  [[ "$nft_status" == WARN* ]] && warnings+=("nftables: ${nft_status}")
  [[ "$mss_status" == WARN* ]] && warnings+=("mss_clamp: ${mss_status}")
  case "${ddns_result,,}" in
    fail|failed) failures+=("ddns failed") ;;
    warn|warning) warnings+=("ddns warn") ;;
  esac
  overall="$STATUS_OVERVIEW_RESULT"
  (( ${#failures[@]} > 0 )) && overall="fail"
  health="$(health_score_value "$role" "$nft_status" "$mss_status" "$ddns_result")"
  cat <<EOF
{
  "version": "$(json_escape "$TOOL_VERSION")",
  "role": "$(json_escape "$role")",
  "role_source": "$(json_escape "${role_source:-无}")",
  "overall": "$(json_escape "$overall")",
  "health_score": ${health},
  "health_level": "$(json_escape "$(health_level "$health")")",
  "entries_total": ${entries_total},
  "entries_enabled": ${entries_enabled},
  "forwards_total": ${forwards_total},
  "forwards_enabled": ${forwards_enabled},
  "pbr_count": ${pbr_count},
  "nftables": "$(json_escape "$nft_status")",
  "mss_clamp": "$(json_escape "$mss_status")",
  "ddns": "$(json_escape "$ddns_result")",
  "entry_ddns_enabled": "$(json_escape "$(bool_yes_no "$entry_ddns_enabled")")",
  "entry_ddns_host": "$(json_escape "$entry_ddns_host")",
  "entry_ddns_public_ip": "$(json_escape "$entry_ddns_public_ip")",
  "entry_ddns_resolved_ip": "$(json_escape "$entry_ddns_resolved_ip")",
  "entry_ddns_match": "$(json_escape "$entry_ddns_match")",
  "relay_restart_needed": "$(json_escape "$(bool_yes_no "${relay_restart_needed:-false}")")",
  "warnings": $(json_array "${warnings[@]}"),
  "failures": $(json_array "${failures[@]}")
}
EOF
}

port_check_mark() {
  case "$1" in
    fail) PORT_CHECK_RESULT="fail" ;;
    warn) [[ "$PORT_CHECK_RESULT" == "fail" ]] || PORT_CHECK_RESULT="warn" ;;
  esac
}

port_check_line() {
  local level="$1" msg="$2"
  case "$level" in
    OK) printf '[OK] %s\n' "$msg" ;;
    WARN) printf '[WARN] %s\n' "$msg"; port_check_mark warn ;;
    FAIL) printf '[FAIL] %s\n' "$msg"; port_check_mark fail ;;
    INFO) printf '[INFO] %s\n' "$msg" ;;
  esac
}

check_easytier_ports() {
  local any=0 name _public_host _et_ip proto port _weight enabled count conflict
  local pending_name _pending_ip _pending_proto pending_port _pending_created_at
  echo "EasyTier 端口:"
  while IFS=$'\t' read -r name _public_host _et_ip proto port _weight enabled; do
    any=1
    count="$(entries_rows | awk -F'\t' -v p="$port" '$5==p{c++} END{print c+0}')"
    if [[ "$enabled" != "true" ]]; then
      port_check_line INFO "${port} ${name} 已 disabled，保留历史配置。"
    elif (( count > 1 )); then
      port_check_line WARN "${port} ${name} 与其它公网入口重复"
    elif ! is_fast_port "$port"; then
      port_check_line WARN "${port} ${name} $(easytier_protocols_display "$proto")，不在 ${FAST_PORT_RANGE_START}-${FAST_PORT_RANGE_END} 白名单"
    else
      conflict="$(easytier_port_conflict_message "$port" "$name" || true)"
      if [[ -n "$conflict" ]]; then
        port_check_line WARN "${port} ${name} ${conflict}"
      else
        port_check_line OK "${port} ${name} $(easytier_protocols_display "$proto")，位于 ${FAST_PORT_RANGE_START}-${FAST_PORT_RANGE_END} 白名单"
      fi
    fi
  done < <(entries_rows)
  while IFS=$'\t' read -r pending_name _pending_ip _pending_proto pending_port _pending_created_at; do
    any=1
    if is_fast_port "$pending_port"; then
      port_check_line WARN "${pending_port} ${pending_name} pending 预占，尚未完成接入"
    else
      port_check_line WARN "${pending_port} ${pending_name} pending 预占且不在白名单"
    fi
  done < <(pending_entries_rows)
  (( any == 1 )) || port_check_line INFO "未发现公网入口或 pending 接入码。"
  echo
}

check_forward_ports() {
  local any=0 name entry_port _target_host _target_port _out_iface _route_table enabled _comment count
  local _kind start end
  IFS=$'\t' read -r _kind start end <<<"$(entry_pool_for_prompt)"
  echo "业务入口端口:"
  while IFS=$'\t' read -r name entry_port _target_host _target_port _out_iface _route_table enabled _comment; do
    any=1
    count="$(forwards_rows | awk -F'\t' -v p="$entry_port" '$2==p{c++} END{print c+0}')"
    if (( count > 1 )); then
      port_check_line WARN "${entry_port} ${name} 与其它转发目标重复"
    elif [[ "$enabled" != "true" ]]; then
      port_check_line INFO "${entry_port} ${name} 已 disabled，保留历史配置。"
    elif ! port_in_range "$entry_port" "$start" "$end"; then
      port_check_line WARN "${entry_port} ${name} 不在入口端口池 ${start}-${end}"
    else
      port_check_line OK "${entry_port} ${name}"
    fi
  done < <(forwards_rows)
  (( any == 1 )) || port_check_line INFO "未发现转发目标。"
  echo
}

check_listening_conflicts() {
  local name entry_port _target_host _target_port _out_iface _route_table enabled _comment conflict=0
  echo "本机监听:"
  if ! command -v ss >/dev/null 2>&1; then
    port_check_line INFO "未找到 ss，跳过本机监听检查。"
    echo
    return 0
  fi
  while IFS=$'\t' read -r name entry_port _target_host _target_port _out_iface _route_table enabled _comment; do
    [[ "$enabled" == "true" ]] || continue
    if port_listening_any "$entry_port"; then
      conflict=1
      port_check_line WARN "${entry_port} ${name} 已被本机监听进程占用"
    fi
  done < <(forwards_rows)
  (( conflict == 1 )) || port_check_line OK "未发现业务入口端口被其它进程监听"
  if ss_port_listening tcp 22; then
    port_check_line INFO "22/tcp ssh 正常，未纳入 leikwan 管理"
  fi
  echo
}

check_nft_port_conflicts() {
  local name entry_port _target_host _target_port _out_iface _route_table enabled _comment
  local any=0 tcp_ok udp_ok
  echo "nftables:"
  if ! command -v nft >/dev/null 2>&1; then
    port_check_line WARN "未找到 nft，跳过 nftables dport 检查。"
    echo
    return 0
  fi
  if ! nft_project_table_exists; then
    port_check_line WARN "未发现项目 nftables 表 inet leikwan_forward"
    echo
    return 0
  fi
  while IFS=$'\t' read -r name entry_port _target_host _target_port _out_iface _route_table enabled _comment; do
    [[ "$enabled" == "true" ]] || continue
    any=1
    tcp_ok=0
    udp_ok=0
    nft_project_has_dport "$entry_port" tcp && tcp_ok=1
    nft_project_has_dport "$entry_port" udp && udp_ok=1
    if (( tcp_ok == 1 && udp_ok == 1 )); then
      port_check_line OK "${entry_port} tcp/udp DNAT 存在"
    elif (( tcp_ok == 1 )); then
      port_check_line WARN "${entry_port} tcp DNAT 存在，udp DNAT 缺失"
    elif (( udp_ok == 1 )); then
      port_check_line WARN "${entry_port} udp DNAT 存在，tcp DNAT 缺失"
    else
      port_check_line WARN "${entry_port} ${name} tcp/udp DNAT 未发现"
    fi
  done < <(forwards_rows)
  (( any == 1 )) || port_check_line INFO "没有 enabled 转发目标需要检查 DNAT。"
  echo
}

port_check() {
  PORT_CHECK_RESULT="ok"
  echo "端口冲突预检"
  echo "----------------------------------------"
  check_easytier_ports
  check_forward_ports
  check_listening_conflicts
  check_nft_port_conflicts
  echo "整体状态: $(status_result_display "$PORT_CHECK_RESULT")"
}

run_doctor_interactive() {
  local old_doctor_interactive_fix="$DOCTOR_INTERACTIVE_FIX"
  DOCTOR_INTERACTIVE_FIX=1
  doctor
  DOCTOR_INTERACTIVE_FIX="$old_doctor_interactive_fix"
}

ipv4_prefer_block() {
  cat <<'EOF'
# BEGIN LEIKWAN IPV4 PREFER
precedence ::ffff:0:0/96  100
# END LEIKWAN IPV4 PREFER
EOF
}

strip_ipv4_prefer_block() {
  [[ -f "$SYSTEM_GAI_CONF" ]] || return 0
  awk '
    /^# BEGIN LEIKWAN IPV4 PREFER$/ {skip=1; next}
    /^# END LEIKWAN IPV4 PREFER$/ {skip=0; next}
    !skip {print}
  ' "$SYSTEM_GAI_CONF"
}

system_ipv4_prefer_managed() {
  [[ -f "$SYSTEM_GAI_CONF" ]] || return 1
  grep -q '^# BEGIN LEIKWAN IPV4 PREFER$' "$SYSTEM_GAI_CONF" 2>/dev/null &&
    grep -q '^# END LEIKWAN IPV4 PREFER$' "$SYSTEM_GAI_CONF" 2>/dev/null
}

system_ipv4_prefer_enabled() {
  [[ -f "$SYSTEM_GAI_CONF" ]] || return 1
  grep -Eq '^[[:space:]]*precedence[[:space:]]+::ffff:0:0/96[[:space:]]+100([[:space:]]*)?$' "$SYSTEM_GAI_CONF" 2>/dev/null
}

system_ipv4_prefer_status() {
  local enabled="disabled" managed="unmanaged"
  system_ipv4_prefer_enabled && enabled="enabled"
  system_ipv4_prefer_managed && managed="managed"
  echo "IPv4 优先: ${enabled}"
  echo "gai.conf: ${managed}"
}

system_ipv4_prefer_enable() {
  need_root_unless_dry_run
  local content block
  if system_ipv4_prefer_managed && system_ipv4_prefer_enabled; then
    ok "IPv4 优先已启用。"
    return 0
  fi
  content="$(strip_ipv4_prefer_block || true)"
  block="$(ipv4_prefer_block)"
  if [[ -n "$content" ]]; then
    content="${content%$'\n'}"$'\n\n'"${block}"
  else
    content="$block"
  fi
  write_file "$SYSTEM_GAI_CONF" "$content" 644 || return 1
  ok "已开启 IPv4 优先。"
}

system_ipv4_prefer_disable() {
  need_root_unless_dry_run
  local content
  if ! system_ipv4_prefer_managed; then
    ok "IPv4 优先已关闭。"
    return 0
  fi
  content="$(strip_ipv4_prefer_block || true)"
  write_file "$SYSTEM_GAI_CONF" "$content" 644 || return 1
  ok "已关闭 IPv4 优先。"
}

system_dns_validate_csv() {
  local csv="$1" ip
  local -a dns_items
  csv="${csv//[[:space:]]/}"
  [[ -n "$csv" ]] || return 1
  IFS=',' read -r -a dns_items <<<"$csv"
  (( ${#dns_items[@]} > 0 )) || return 1
  for ip in "${dns_items[@]}"; do
    is_ipv4 "$ip" || return 1
  done
}

system_dns_csv_to_space() {
  local csv="$1"
  csv="${csv//,/ }"
  awk '{$1=$1; print}' <<<"$csv"
}

system_dns_space_to_csv() {
  local value="$1"
  value="$(system_dns_csv_to_space "$value")"
  value="${value// /,}"
  printf '%s' "$value"
}

system_dns_resolved_content() {
  local dns_csv="${1:-$SYSTEM_DNS_TARGET_CSV}" dns_space
  dns_space="$(system_dns_csv_to_space "$dns_csv")"
  cat <<EOF
[Resolve]
DNS=${dns_space}
FallbackDNS=${LEIKWAN_SYSTEM_DNS_FALLBACK}
LLMNR=no
MulticastDNS=no
EOF
}

systemd_resolved_state() {
  if ! command -v systemctl >/dev/null 2>&1; then
    printf 'missing'
    return 0
  fi
  if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    printf 'active'
  elif systemctl list-unit-files --no-legend systemd-resolved.service 2>/dev/null | grep -q .; then
    printf 'inactive'
  else
    printf 'missing'
  fi
}

resolv_conf_type() {
  if [[ -L "$SYSTEM_RESOLV_CONF" ]]; then
    printf 'symlink'
  elif [[ -f "$SYSTEM_RESOLV_CONF" ]]; then
    printf 'file'
  else
    printf 'unknown'
  fi
}

csv_has_item() {
  local csv="$1" needle="$2" item
  local -a dns_items
  IFS=',' read -r -a dns_items <<<"$csv"
  for item in "${dns_items[@]}"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

system_dns_conf_value_csv() {
  local key="$1" file="${2:-$DNS_RESOLVED_CONF}"
  [[ -f "$file" ]] || return 1
  awk -F= -v key="$key" '
    {
      k=$1
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
      if (k == key) {
        v=$2
        for (i=3; i<=NF; i++) v=v "=" $i
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
        gsub(/[[:space:]]+/, ",", v)
        print v
        exit
      }
    }
  ' "$file" 2>/dev/null
}

system_dns_resolv_conf_csv() {
  [[ -f "$SYSTEM_RESOLV_CONF" && ! -L "$SYSTEM_RESOLV_CONF" ]] || return 1
  awk '$1=="nameserver" && $2 ~ /^[0-9.]+$/ {if (out=="") out=$2; else out=out "," $2} END{print out}' "$SYSTEM_RESOLV_CONF" 2>/dev/null
}

system_dns_resolvectl_csv() {
  command -v resolvectl >/dev/null 2>&1 || return 1
  resolvectl dns 2>/dev/null | awk '
    {
      for (i=2; i<=NF; i++) {
        if ($i ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {
          if (out=="") out=$i; else out=out "," $i
        }
      }
    }
    END{print out}
  '
}

system_dns_current_csv() {
  local line state
  state="$(systemd_resolved_state)"
  if [[ -f "$DNS_RESOLVED_CONF" ]]; then
    line="$(system_dns_conf_value_csv DNS "$DNS_RESOLVED_CONF" || true)"
    [[ -n "$line" ]] && { printf '%s' "$line"; return 0; }
  fi
  if [[ "$state" == "active" ]]; then
    line="$(system_dns_resolvectl_csv || true)"
    [[ -n "$line" ]] && { printf '%s' "$line"; return 0; }
  fi
  line="$(system_dns_resolv_conf_csv || true)"
  [[ -n "$line" ]] && { printf '%s' "$line"; return 0; }
  printf '-'
}

system_dns_fallback_csv() {
  local line
  if [[ -f "$DNS_RESOLVED_CONF" ]]; then
    line="$(system_dns_conf_value_csv FallbackDNS "$DNS_RESOLVED_CONF" || true)"
    [[ -n "$line" ]] && { printf '%s' "$line"; return 0; }
  fi
  printf '-'
}

system_dns_config_state() {
  system_dns_managed_state
}

system_dns_managed_state() {
  local current fallback
  if [[ -f "$DNS_RESOLVED_CONF" ]]; then
    current="$(system_dns_conf_value_csv DNS "$DNS_RESOLVED_CONF" || true)"
    fallback="$(system_dns_conf_value_csv FallbackDNS "$DNS_RESOLVED_CONF" || true)"
    if [[ "$current" == "$SYSTEM_DNS_TARGET_CSV" && "$fallback" == "$SYSTEM_DNS_FALLBACK_CSV" ]]; then
      printf 'managed-current'
    else
      printf 'managed-legacy'
    fi
  elif [[ -f "$SYSTEM_RESOLV_CONF" && ! -L "$SYSTEM_RESOLV_CONF" ]] && grep -q '^# Managed by leikwan-toolkit system DNS$' "$SYSTEM_RESOLV_CONF" 2>/dev/null; then
    current="$(system_dns_resolv_conf_csv || true)"
    if [[ "$current" == "$SYSTEM_DNS_TARGET_CSV" ]]; then
      printf 'managed-current'
    else
      printf 'managed-legacy'
    fi
  else
    printf 'unmanaged'
  fi
}

system_dns_is_target() {
  [[ "$(system_dns_managed_state)" == "managed-current" ]]
}

system_dns_is_recommended() {
  local current managed_state
  managed_state="$(system_dns_managed_state)"
  [[ "$managed_state" == "managed-legacy" ]] && return 1
  current="$(system_dns_current_csv)"
  csv_has_item "$current" "8.8.8.8" && csv_has_item "$current" "1.1.1.1"
}

system_dns_doctor_state() {
  local managed_state
  managed_state="$(system_dns_managed_state)"
  case "$managed_state" in
    managed-current) printf 'ok' ;;
    managed-legacy) printf 'legacy' ;;
    *)
      if system_dns_is_recommended; then
        printf 'ok'
      else
        printf 'missing'
      fi
      ;;
  esac
}

system_dns_status() {
  local managed_state
  managed_state="$(system_dns_managed_state)"
  echo "系统 DNS: $(system_dns_current_csv)"
  echo "Fallback DNS: $(system_dns_fallback_csv)"
  echo "systemd-resolved: $(systemd_resolved_state)"
  echo "resolv.conf: $(resolv_conf_type)"
  echo "DNS 配置: ${managed_state}"
  if [[ "$managed_state" == "managed-legacy" ]]; then
    warn "检测到旧版 Leikwan DNS 配置，建议执行：lq system network prepare"
  fi
}

system_dns_set() {
  need_root_unless_dry_run
  local dns_csv="${1:-$SYSTEM_DNS_TARGET_CSV}" state content managed_state
  dns_csv="${dns_csv//[[:space:]]/}"
  system_dns_validate_csv "$dns_csv" || { fail "系统 DNS 格式无效：${dns_csv}"; return 1; }
  managed_state="$(system_dns_managed_state)"
  if [[ "$dns_csv" == "$SYSTEM_DNS_TARGET_CSV" && "$managed_state" == "managed-current" ]]; then
    ok "系统 DNS 已是目标配置。"
    return 0
  fi
  if [[ "$managed_state" == "managed-legacy" ]]; then
    warn "检测到旧版 Leikwan DNS 配置，正在迁移到当前目标配置。"
  fi
  state="$(systemd_resolved_state)"
  case "$state" in
    active)
      write_file "$DNS_RESOLVED_CONF" "$(system_dns_resolved_content "$dns_csv")" 644 || return 1
      if (( DRY_RUN == 1 )); then
        echo "[DRY-RUN] systemctl restart systemd-resolved"
      else
        systemctl restart systemd-resolved 2>/dev/null || warn "systemd-resolved 重启失败，请稍后手动检查系统 DNS。"
      fi
      if [[ "$managed_state" == "managed-legacy" ]]; then
        ok "系统 DNS 已更新为目标配置。"
      else
        ok "系统 DNS 配置已写入。"
      fi
      ;;
    inactive|missing)
      if [[ -L "$SYSTEM_RESOLV_CONF" ]]; then
        warn "resolv.conf 是符号链接且 systemd-resolved 未处于 active，未硬改系统 DNS。"
        return 1
      fi
      content="# Managed by leikwan-toolkit system DNS"
      while IFS= read -r ip; do
        [[ -n "$ip" ]] && content="${content}"$'\n'"nameserver ${ip}"
      done < <(tr ',' '\n' <<<"$dns_csv")
      write_file "$SYSTEM_RESOLV_CONF" "$content" 644 || return 1
      if [[ "$managed_state" == "managed-legacy" ]]; then
        ok "系统 DNS 已更新为目标配置。"
      else
        ok "系统 DNS 配置已写入。"
      fi
      ;;
  esac
}

system_dns_set_default_foreign() {
  system_dns_set "$SYSTEM_DNS_TARGET_CSV"
}

system_dns_restore() {
  need_root_unless_dry_run
  local latest state restored=0
  if [[ -f "$DNS_RESOLVED_CONF" ]]; then
    backup_file "$DNS_RESOLVED_CONF"
    if (( DRY_RUN == 1 )); then
      echo "[DRY-RUN] 删除 ${DNS_RESOLVED_CONF}"
    else
      rm -f "$DNS_RESOLVED_CONF"
    fi
    restored=1
  fi
  state="$(systemd_resolved_state)"
  if [[ "$state" == "active" ]]; then
    if (( DRY_RUN == 1 )); then
      echo "[DRY-RUN] systemctl restart systemd-resolved"
    else
      systemctl restart systemd-resolved 2>/dev/null || warn "systemd-resolved 重启失败，请稍后手动检查系统 DNS。"
    fi
  fi
  if [[ -f "$SYSTEM_RESOLV_CONF" && ! -L "$SYSTEM_RESOLV_CONF" ]] && grep -q '^# Managed by leikwan-toolkit system DNS$' "$SYSTEM_RESOLV_CONF" 2>/dev/null; then
    latest="$(latest_backup_for_file "$SYSTEM_RESOLV_CONF" || true)"
    if [[ -n "$latest" && -f "$latest" ]]; then
      backup_file "$SYSTEM_RESOLV_CONF"
      if (( DRY_RUN == 1 )); then
        echo "[DRY-RUN] 恢复 ${SYSTEM_RESOLV_CONF} <- ${latest}"
      else
        cp -a "$latest" "$SYSTEM_RESOLV_CONF"
      fi
      restored=1
    else
      warn "未找到 ${SYSTEM_RESOLV_CONF} 的备份，保留当前文件，请按需手动恢复。"
    fi
  fi
  (( restored == 1 )) && ok "系统 DNS 已恢复。" || ok "未发现脚本托管的系统 DNS 配置。"
}

system_ipv6_value() {
  local scope="$1" file
  file="${IPV6_PROC_CONF_DIR}/${scope}/disable_ipv6"
  [[ -r "$file" ]] && tr -d '[:space:]' <"$file" || printf 'unknown'
}

system_ipv6_summary() {
  local all default lo
  all="$(system_ipv6_value all)"
  default="$(system_ipv6_value default)"
  lo="$(system_ipv6_value lo)"
  if [[ "$all" == "1" && "$default" == "1" && "$lo" == "1" ]]; then
    printf 'disabled'
  elif [[ "$all" == "0" && "$default" == "0" && "$lo" == "0" ]]; then
    printf 'enabled'
  else
    printf 'partial'
  fi
}

system_ipv6_config_state() {
  [[ -f "$IPV6_DISABLE_SYSCTL_CONF" ]] && printf 'managed' || printf 'unmanaged'
}

system_ipv6_conflicts() {
  local paths=() p
  if [[ -n "${LEIKWAN_SYSCTL_DIRS:-}" ]]; then
    IFS=',' read -r -a paths <<<"$LEIKWAN_SYSCTL_DIRS"
  else
    paths=(/etc/sysctl.conf /etc/sysctl.d)
  fi
  for p in "${paths[@]}"; do
    [[ -e "$p" ]] || continue
    grep -RHE '^[[:space:]]*net\.ipv6\.conf\..*\.disable_ipv6[[:space:]]*=[[:space:]]*0([[:space:]]*)?$' "$p" 2>/dev/null | grep -vF "$IPV6_DISABLE_SYSCTL_CONF" || true
  done
}

system_ipv6_status() {
  echo "IPv6: $(system_ipv6_summary)"
  echo "IPv6 sysctl: all=$(system_ipv6_value all) default=$(system_ipv6_value default) lo=$(system_ipv6_value lo)"
  echo "IPv6 配置: $(system_ipv6_config_state)"
}

system_ipv6_disable() {
  need_root_unless_dry_run
  local conflicts summary
  conflicts="$(system_ipv6_conflicts || true)"
  if [[ -n "$conflicts" ]]; then
    warn "检测到其他 sysctl 配置含 disable_ipv6=0，未修改用户文件；如需处理请在高级维护中确认。"
    printf '%s\n' "$conflicts" | sed -n '1,5p'
  fi
  write_file "$IPV6_DISABLE_SYSCTL_CONF" $'# Managed by leikwan-toolkit\nnet.ipv6.conf.all.disable_ipv6=1\nnet.ipv6.conf.default.disable_ipv6=1\nnet.ipv6.conf.lo.disable_ipv6=1' 644 || return 1
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] sysctl -p ${IPV6_DISABLE_SYSCTL_CONF}"
    ok "IPv6 已禁用。"
    return 0
  fi
  if command -v sysctl >/dev/null 2>&1; then
    sysctl -p "$IPV6_DISABLE_SYSCTL_CONF" >/dev/null 2>&1 || sysctl --system >/dev/null 2>&1 || true
  fi
  summary="$(system_ipv6_summary)"
  if [[ "$summary" == "disabled" ]]; then
    ok "IPv6 已禁用。"
  else
    warn "IPv6 禁用可能需要重启后完全生效。"
  fi
}

system_ipv6_restore() {
  need_root_unless_dry_run
  if [[ -f "$IPV6_DISABLE_SYSCTL_CONF" ]]; then
    backup_file "$IPV6_DISABLE_SYSCTL_CONF"
    if (( DRY_RUN == 1 )); then
      echo "[DRY-RUN] 删除 ${IPV6_DISABLE_SYSCTL_CONF}"
    else
      rm -f "$IPV6_DISABLE_SYSCTL_CONF"
    fi
  fi
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] sysctl --system"
    echo "[DRY-RUN] sysctl -w net.ipv6.conf.all.disable_ipv6=0 net.ipv6.conf.default.disable_ipv6=0 net.ipv6.conf.lo.disable_ipv6=0"
    ok "IPv6 已恢复。"
    return 0
  fi
  if command -v sysctl >/dev/null 2>&1; then
    sysctl --system >/dev/null 2>&1 || true
    sysctl -w net.ipv6.conf.all.disable_ipv6=0 net.ipv6.conf.default.disable_ipv6=0 net.ipv6.conf.lo.disable_ipv6=0 >/dev/null 2>&1 || true
  fi
  if [[ "$(system_ipv6_summary)" == "enabled" ]]; then
    ok "IPv6 已恢复。"
  else
    warn "IPv6 可能被其他 sysctl 配置禁用，请检查冲突项或重启系统。"
  fi
}

ipv6_nft_lockdown_content() {
  cat <<'EOF'
table inet leikwan_ipv6_lockdown {
  chain input {
    type filter hook input priority filter; policy accept;

    ip6 nexthdr ipv6-icmp accept
    iif lo accept
    ct state established,related accept
    tcp dport 22 accept

    meta nfproto ipv6 drop
  }
}
EOF
}

ipv6_nft_lockdown_service_content() {
  local nft_bin
  nft_bin="$(command -v nft 2>/dev/null || printf '/usr/sbin/nft')"
  cat <<EOF
[Unit]
Description=Leikwan IPv6 inbound lockdown nftables
After=network-online.target nftables.service

[Service]
Type=oneshot
ExecStart=${nft_bin} -f ${IPV6_NFT_LOCK_FILE}
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
}

ipv6_nft_lockdown_status() {
  if command -v nft >/dev/null 2>&1 && nft list table inet leikwan_ipv6_lockdown >/dev/null 2>&1; then
    printf 'enabled'
  elif [[ -f "$IPV6_NFT_LOCK_FILE" ]]; then
    printf 'enabled'
  else
    printf 'disabled'
  fi
}

ipv6_nft_lockdown() {
  need_root_unless_dry_run
  install_packages nftables
  write_file "$IPV6_NFT_LOCK_FILE" "$(ipv6_nft_lockdown_content)" 644 || return 1
  write_file "$IPV6_NFT_SERVICE" "$(ipv6_nft_lockdown_service_content)" 644 || return 1
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] nft -f ${IPV6_NFT_LOCK_FILE}"
    ok "IPv6 入站收口 nftables 已应用。"
    info "这不是禁用 IPv6，只是限制 IPv6 入站访问。"
    return 0
  fi
  if ! command -v nft >/dev/null 2>&1; then
    fail "未找到 nft 命令，无法应用 IPv6 入站收口。"
    return 1
  fi
  if ! nft -f "$IPV6_NFT_LOCK_FILE"; then
    nft delete table inet leikwan_ipv6_lockdown >/dev/null 2>&1 || true
    warn "IPv6 入站收口 nftables 应用失败，已尝试回滚。"
    return 1
  fi
  if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable "$IPV6_NFT_SERVICE_NAME" >/dev/null 2>&1 || true
  fi
  ok "IPv6 入站收口 nftables 已应用。"
  info "这不是禁用 IPv6，只是限制 IPv6 入站访问。"
}

ipv6_lockdown() {
  ipv6_nft_lockdown
}

system_bbr_status() {
  echo "BBR: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || printf 'unknown')"
  echo "qdisc: $(sysctl -n net.core.default_qdisc 2>/dev/null || printf 'unknown')"
}

system_bbr_enable() {
  need_root_unless_dry_run
  write_file "$BBR_SYSCTL_CONF" $'net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr' 644 || return 1
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] modprobe tcp_bbr"
    echo "[DRY-RUN] sysctl --system"
    ok "已启用 BBR + fq。"
    return 0
  fi
  modprobe tcp_bbr 2>/dev/null || true
  sysctl --system >/dev/null 2>&1 || true
  ok "已启用 BBR + fq。"
}

system_bbr_restore() {
  need_root_unless_dry_run
  backup_file "$BBR_SYSCTL_CONF"
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] 删除 ${BBR_SYSCTL_CONF}"
    echo "[DRY-RUN] sysctl --system"
    ok "已恢复 BBR / qdisc 默认配置。"
    return 0
  fi
  rm -f "$BBR_SYSCTL_CONF"
  sysctl --system >/dev/null 2>&1 || true
  ok "已恢复 BBR / qdisc 默认配置。"
}

system_network_status() {
  echo "系统网络优化状态"
  echo "----------------------------------------"
  system_ipv4_prefer_status
  system_dns_status
  system_ipv6_status
  echo "IPv6 入站收口: nftables $(ipv6_nft_lockdown_status)"
  system_bbr_status
  echo "最近备份: $(latest_backup_any || printf '-')"
}

system_network_prepare() {
  local rc=0
  info "正在执行系统网络预处理：IPv4 优先 + 国外 DNS。"
  system_ipv4_prefer_enable || rc=1
  system_dns_set_default_foreign || rc=1
  if (( rc != 0 )); then
    warn "系统网络预处理失败，GitHub / EasyTier / DNS 解析可能受影响。"
    return "$rc"
  fi
  return 0
}

fix_dns_ipv4_first() {
  system_network_prepare
}

system_ipv4_prefer_menu() {
  local choice
  system_ipv4_prefer_status
  echo "1. 开启 IPv4 优先"
  echo "2. 关闭 IPv4 优先"
  echo "0. 返回"
  choice="$(prompt_menu_choice "请选择：")"
  case "$choice" in
    1) system_ipv4_prefer_enable ;;
    2) system_ipv4_prefer_disable ;;
    0|"") return 0 ;;
    *) menu_invalid_choice ;;
  esac
}

system_dns_menu() {
  local choice dns
  system_dns_status
  echo "1. 设置系统 DNS：${SYSTEM_DNS_TARGET_CSV}"
  echo "2. 自定义系统 DNS"
  echo "3. 恢复系统 DNS"
  echo "0. 返回"
  choice="$(prompt_menu_choice "请选择：")"
  case "$choice" in
    1) system_dns_set_default_foreign ;;
    2) dns="$(prompt_value "系统 DNS，逗号分隔" "$SYSTEM_DNS_TARGET_CSV")"; system_dns_set "$dns" ;;
    3) system_dns_restore ;;
    0|"") return 0 ;;
    *) menu_invalid_choice ;;
  esac
}

system_ipv6_menu() {
  local choice
  system_ipv6_status
  echo "1. 禁用 IPv6（sysctl）"
  echo "2. 恢复 IPv6（sysctl）"
  echo "0. 返回"
  choice="$(prompt_menu_choice "请选择：")"
  case "$choice" in
    1) system_ipv6_disable ;;
    2) system_ipv6_restore ;;
    0|"") return 0 ;;
    *) menu_invalid_choice ;;
  esac
}

print_system_network_menu_options() {
  print_menu_header "系统网络优化"
  echo "1. 查看系统网络优化状态"
  echo "2. IPv4 优先：开启 / 关闭"
  echo "3. DNS 服务器：设置 / 恢复"
  echo "4. IPv6：禁用 / 恢复"
  echo "5. BBR / fq：开启 / 恢复"
  echo "6. IPv6 入站收口 nftables"
  echo "0. 返回"
}

system_network_menu() {
  local choice
  while true; do
    print_system_network_menu_options
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) run_menu_action_pause system_network_status ;;
      2) run_menu_action_pause system_ipv4_prefer_menu ;;
      3) run_menu_action_pause system_dns_menu ;;
      4) run_menu_action_pause system_ipv6_menu ;;
      5) bbr_menu ;;
      6) run_menu_action_pause ipv6_nft_lockdown ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

bbr_menu() {
  local choice
  while true; do
    print_menu_header "BBR / 系统优化"
    echo "1. 查看状态"; echo "2. 启用 BBR + fq"; echo "3. 恢复默认"; echo "0. 返回"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) system_bbr_status; pause_after_action ;;
      2) system_bbr_enable; pause_after_action ;;
      3) system_bbr_restore; pause_after_action ;;
      0) return 0 ;;
    esac
  done
}

link_test_menu() {
  local choice
  while true; do
    print_menu_header "链路测试"
    echo "1. ping relay EasyTier IP"; echo "2. ping 所有入口 EasyTier IP"; echo "3. 测入口 EasyTier TCP/UDP"; echo "4. 测后端 target"; echo "0. 返回"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) ping_entry_et_ip "relay" "$RELAY_ET_IP" plain || true; pause_after_action ;;
      2) entries_rows | while IFS=$'\t' read -r n _h ip _proto _port _w e; do [[ "$e" == "true" ]] && ping_entry_et_ip "$n" "$ip" plain || true; done; pause_after_action ;;
      3)
        ensure_nc_for_test || { pause_after_action; continue; }
        entries_rows | while IFS=$'\t' read -r n h ip proto port _w e; do [[ "$e" == "true" ]] && test_entry_row "$n" "$h" "$ip" "$proto" "$port" "$e" || true; done
        pause_after_action
        ;;
      4)
        ensure_nc_for_test || { pause_after_action; continue; }
        resolved_rows | while IFS=$'\t' read -r n _ep _th ti tp _oi _rt en _ts _comment; do
          [[ "$en" == "true" && -n "$ti" ]] || continue
          nc -vz -w 3 "$ti" "$tp" || true
          case "$(udp_probe_status "$ti" "$tp")" in
            0) ok "${n} target UDP 探测完成：${ti}:${tp}" ;;
            *) warn "${n} target UDP 探测未确认。UDP 无连接探测可能不可靠，请结合业务实际测试。" ;;
          esac
        done
        pause_after_action
        ;;
      0) return 0 ;;
    esac
  done
}

generate_debug_report() {
  need_root_unless_dry_run
  local tmp
  tmp="$(mktemp)"
  {
    echo "leikwan-toolkit debug report ${TOOL_VERSION}"
    bash "$UPDATE_TARGET_SCRIPT" --version 2>&1 || true
    if command -v lq >/dev/null 2>&1; then
      lq --version 2>&1 || true
      readlink -f "$SHORTCUT_LQ" 2>&1 || true
    fi
    ls -lh "$UPDATE_TARGET_SCRIPT" 2>&1 || true
    cat /etc/os-release 2>/dev/null || true
    ip -br addr || true
    ip route || true
    ip rule || true
    systemctl --no-pager --full status "$EASYTIER_RELAY_SERVICE_NAME" 'easytier-entry-*' "$NFT_SERVICE_NAME" "${DDNS_SERVICE_NAME}.service" "${DDNS_SERVICE_NAME}.timer" "${ENTRY_DDNS_SERVICE_NAME}.service" "${ENTRY_DDNS_SERVICE_NAME}.timer" 2>&1 || true
    ss -lntup || true
    nft list table inet leikwan_forward 2>&1 || true
    "$EASYTIER_CLI_BIN" peer 2>&1 || true
    doctor || true
    echo "ddns.env:"
    [[ -f "$DDNS_CONFIG" ]] && sed -n '1,120p' "$DDNS_CONFIG"
    echo "entry/ddns.env:"
    [[ -f "$ENTRY_DDNS_CONFIG" ]] && sed -n '1,120p' "$ENTRY_DDNS_CONFIG"
    echo "last-ddns.env:"
    [[ -f "$DDNS_STATUS_FILE" ]] && sed -n '1,120p' "$DDNS_STATUS_FILE"
    echo "last-entry-ddns.env:"
    [[ -f "$ENTRY_DDNS_STATUS_FILE" ]] && sed -n '1,120p' "$ENTRY_DDNS_STATUS_FILE"
    echo "last-update.env:"
    [[ -f "$UPDATE_STATUS_FILE" ]] && sed -n '1,120p' "$UPDATE_STATUS_FILE"
    echo "last-config-export.env:"
    [[ -f "${STATUS_DIR}/last-config-export.env" ]] && sed -n '1,120p' "${STATUS_DIR}/last-config-export.env"
    echo "last-config-import.env:"
    [[ -f "${STATUS_DIR}/last-config-import.env" ]] && sed -n '1,120p' "${STATUS_DIR}/last-config-import.env"
    echo "last-output.env:"
    [[ -f "${STATUS_DIR}/last-output.env" ]] && sed -n '1,120p' "${STATUS_DIR}/last-output.env"
    echo "ddns log tail:"
    [[ -f "$DDNS_LOG_FILE" ]] && tail -n 100 "$DDNS_LOG_FILE"
    echo "entry ddns log tail:"
    [[ -f "$ENTRY_DDNS_LOG_FILE" ]] && tail -n 100 "$ENTRY_DDNS_LOG_FILE"
    echo "resolved-entries.tsv:"
    [[ -f "$RESOLVED_ENTRIES_TSV" ]] && sed -n '1,160p' "$RESOLVED_ENTRIES_TSV"
    echo "pbr/domain-routes.tsv:"
    [[ -f "$PBR_DOMAIN_TSV" ]] && sed -n '1,160p' "$PBR_DOMAIN_TSV"
    echo "pbr/resolved-pbr-domains.tsv:"
    [[ -f "$PBR_RESOLVED_DOMAIN_TSV" ]] && sed -n '1,160p' "$PBR_RESOLVED_DOMAIN_TSV"
    echo "outputs:"
    find "$OUTPUT_DIR" -maxdepth 2 -type f -printf '%p\t%s bytes\n' 2>/dev/null || true
    [[ -f "$FORWARD_TSV" ]] && sed -n '1,120p' "$FORWARD_TSV"
    echo "forward-endpoints.json summary:"
    [[ -f "$FORWARD_JSON" ]] && sed -n '1,220p' "$FORWARD_JSON"
  } >"$tmp" 2>&1
  sed -E \
    -e 's/(EASYTIER_NETWORK_SECRET=).*/\1<redacted>/g' \
    -e 's/(PAIRING_CODE_BASE64=).*/\1<redacted>/g' \
    -e 's/(LEIKWAN_[A-Z0-9_]*_BASE64=).*/\1<redacted>/g' \
    -e 's/(([Ss]ecret|[Tt]oken|[Pp]assword)[[:space:]_=-]+)[^[:space:]]+/\1<redacted>/g' \
    -e 's#(https?://[^?[:space:]]+)\?[^[:space:]]+#\1?<redacted>#g' \
    -e 's/(ENTRY_DDNS_UPDATE_URL=).*/\1<redacted>/g' \
    -e 's/(ENTRY_DDNS_UPDATE_CMD=).*/\1<redacted>/g' \
    -e 's/(ENTRY_DDNS_TOKEN=).*/\1<redacted>/g' \
    -e 's#(LAST_UPDATE_SOURCE=https?://[^?[:space:]]+)\?[^[:space:]]+#\1?<redacted>#g' \
    -e 's/(PrivateKey[[:space:]]*=[[:space:]]*)[^[:space:]]+/\1<redacted>/g' \
    -e 's#(vless|vmess|trojan|ss|hysteria)://[^[:space:]]+#<proxy-link-redacted>#g' \
    "$tmp" >"$REPORT_FILE"
  rm -f "$tmp"
  chmod 600 "$REPORT_FILE"
  ok "已生成脱敏故障报告：${REPORT_FILE}"
  wait_file_output_confirm "脱敏故障报告" "$REPORT_FILE"
}

legacy_cleanup_menu() {
  need_root
  local choice
  while true; do
    print_menu_header "legacy 清理（默认不执行）"
    echo "1. 清理旧内核隧道残留"
    echo "2. 清理旧 UDP 加速残留"
    echo "3. 清理旧端口代理残留"
    echo "4. 清理旧四层转发残留"
    echo "5. 清理旧测试服务残留"
    echo "6. 清理脚本生成的 nftables 规则"
    echo "7. 清理 EasyTier 服务和配置"
    echo "0. 返回"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1)
        if prompt_yes_no "二次确认清理旧内核隧道残留？" "N"; then
          systemctl disable --now wg-quick@wg0 wg-quick@wg1 2>/dev/null || true
          rm -f /etc/wireguard/wg0.conf /etc/wireguard/wg1.conf /etc/wireguard/wg0_privatekey /etc/wireguard/wg1_privatekey /etc/wireguard/wg0_publickey /etc/wireguard/wg1_publickey
        fi
        ;;
      2)
        if prompt_yes_no "二次确认清理旧 UDP 加速残留？" "N"; then
          systemctl disable --now phantun-server-leikwan 'phantun-client-entry-*' 2>/dev/null || true
          rm -f /etc/systemd/system/phantun-server-leikwan.service /etc/systemd/system/phantun-client-entry-*.service /usr/local/bin/phantun_server /usr/local/bin/phantun_client
        fi
        ;;
      3)
        if prompt_yes_no "二次确认清理旧端口代理残留？" "N"; then
          systemctl disable --now frps-leikwan frpc-leikwan 2>/dev/null || true
          rm -f /etc/systemd/system/frps-leikwan.service /etc/systemd/system/frpc-leikwan.service /etc/frp/frps-leikwan.toml /etc/frp/frpc-leikwan.toml
        fi
        ;;
      4)
        if prompt_yes_no "二次确认清理旧四层转发残留？" "N"; then
          systemctl disable --now realm-leikwan 2>/dev/null || true
          rm -f /etc/systemd/system/realm-leikwan.service
          rm -rf "${STATE_DIR}/realm"
        fi
        ;;
      5)
        if prompt_yes_no "二次确认清理旧测试服务残留？" "N"; then
          systemctl disable --now xray-leikwan 2>/dev/null || true
          rm -f /etc/systemd/system/xray-leikwan.service
          rm -rf /usr/local/etc/xray/leikwan
        fi
        ;;
      6) cleanup_nftables_rules ;;
      7)
        echo "将清理本脚本生成的 EasyTier 服务与配置："
        echo "- ${EASYTIER_RELAY_SERVICE}"
        echo "- /etc/systemd/system/easytier-entry-*.service"
        echo "- ${EASYTIER_DIR}"
        if prompt_yes_no "二次确认清理 EasyTier 服务和配置？" "N"; then
          if command -v systemctl >/dev/null 2>&1; then
            systemctl disable --now "$EASYTIER_RELAY_SERVICE_NAME" 2>/dev/null || true
            systemctl list-unit-files --type=service --no-legend 'easytier-entry-*.service' 2>/dev/null | awk '{print $1}' | while read -r svc; do
              systemctl disable --now "$svc" 2>/dev/null || true
              rm -f "/etc/systemd/system/${svc}"
            done
          else
            warn "未找到 systemctl，跳过 systemd 服务停止。"
          fi
          rm -f "$EASYTIER_RELAY_SERVICE"
          rm -rf "$EASYTIER_DIR"
        fi
        ;;
      0) return 0 ;;
    esac
    command -v systemctl >/dev/null 2>&1 && systemctl daemon-reload || true
    [[ "$choice" =~ ^[1-7]$ ]] && pause_after_action
  done
}

safe_stop_disable_service() {
  local svc="$1"
  command -v systemctl >/dev/null 2>&1 || return 0
  systemctl disable --now "$svc" 2>/dev/null || true
}

safe_rm_file() {
  local path
  for path in "$@"; do
    rm -f "$path" 2>/dev/null || true
  done
}

safe_rm_dir() {
  local path
  for path in "$@"; do
    rm -rf "$path" 2>/dev/null || true
  done
}

cleanup_easytier_entry_units() {
  local svc unit
  if command -v systemctl >/dev/null 2>&1; then
    while IFS= read -r svc; do
      [[ -n "$svc" ]] || continue
      safe_stop_disable_service "$svc"
      safe_rm_file "/etc/systemd/system/${svc}"
    done < <(systemctl list-unit-files --type=service --no-legend 'easytier-entry-*.service' 2>/dev/null | awk '{print $1}' || true)
  fi
  for unit in /etc/systemd/system/easytier-entry-*.service; do
    [[ -e "$unit" ]] || continue
    svc="$(basename "$unit")"
    safe_stop_disable_service "$svc"
    safe_rm_file "$unit"
  done
}

cleanup_leikwan_policy_routes() {
  local table table_id pref tmp
  if command -v ip >/dev/null 2>&1; then
    while IFS= read -r pref; do
      [[ -n "$pref" ]] || continue
      ip rule del pref "$pref" 2>/dev/null || true
    done < <(ip rule show 2>/dev/null | awk -v p="$PBR_PRIORITY" '$1 ~ "^"p":" {gsub(":","",$1); print $1}' || true)
  fi
  for table in T_CN2 T_9929; do
    if command -v ip >/dev/null 2>&1; then
      ip route flush table "$table" 2>/dev/null || true
      table_id=""
      if [[ -f "$PBR_RT_TABLES" ]]; then
        table_id="$(awk -v t="$table" '$2==t {print $1; exit}' "$PBR_RT_TABLES" 2>/dev/null || true)"
      fi
      [[ -n "$table_id" ]] && ip route flush table "$table_id" 2>/dev/null || true
      while IFS= read -r pref; do
        [[ -n "$pref" ]] || continue
        ip rule del pref "$pref" table "$table" 2>/dev/null || true
        [[ -n "$table_id" ]] && ip rule del pref "$pref" table "$table_id" 2>/dev/null || true
      done < <(ip rule show 2>/dev/null | awk -v t="$table" '$0 ~ ("lookup " t) {gsub(":","",$1); print $1}' || true)
      if [[ -n "$table_id" ]]; then
        while IFS= read -r pref; do
          [[ -n "$pref" ]] || continue
          ip rule del pref "$pref" table "$table_id" 2>/dev/null || true
        done < <(ip rule show 2>/dev/null | awk -v t="$table_id" '$0 ~ ("lookup " t "($| )") {gsub(":","",$1); print $1}' || true)
      fi
    fi
  done
  if [[ -f "$PBR_RT_TABLES" ]]; then
    tmp="$(mktemp)"
    awk '$2!="T_CN2" && $2!="T_9929" {print}' "$PBR_RT_TABLES" >"$tmp" 2>/dev/null || true
    if [[ -s "$tmp" ]]; then
      cat "$tmp" >"$PBR_RT_TABLES" 2>/dev/null || true
    fi
    rm -f "$tmp" 2>/dev/null || true
  fi
}

systemd_reload_reset_failed() {
  command -v systemctl >/dev/null 2>&1 || return 0
  systemctl daemon-reload 2>/dev/null || true
  systemctl reset-failed 2>/dev/null || true
}

uninstall_check_command_absent() {
  local label="$1" command_name="$2"
  if command -v "$command_name" >/dev/null 2>&1; then
    warn "${label}：仍可执行 $(command -v "$command_name" 2>/dev/null)"
  else
    ok "${label}：已清理"
  fi
}

uninstall_check_line() {
  local label="$1" kind="$2" value="$3"
  case "$kind" in
    file)
      if [[ ! -e "$value" ]]; then
        ok "${label}：已清理"
      else
        warn "${label}：仍存在 ${value}"
      fi
      ;;
    dir)
      if [[ ! -e "$value" ]]; then
        ok "${label}：已清理"
      else
        warn "${label}：仍存在 ${value}"
      fi
      ;;
    service)
      if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files --type=service --no-legend "$value" 2>/dev/null | grep -q .; then
        warn "${label}：服务文件仍存在 ${value}"
      else
        ok "${label}：已清理"
      fi
      ;;
    nft)
      if command -v nft >/dev/null 2>&1 && nft list table inet "$value" >/dev/null 2>&1; then
        warn "${label}：nft table 仍存在 inet ${value}"
      else
        ok "${label}：已清理"
      fi
      ;;
  esac
}

uninstall_stop_services_and_rules() {
  if command -v systemctl >/dev/null 2>&1; then
    safe_stop_disable_service "$EASYTIER_RELAY_SERVICE_NAME"
    safe_stop_disable_service "$NFT_SERVICE_NAME"
    safe_stop_disable_service "${DDNS_SERVICE_NAME}.timer"
    safe_stop_disable_service "${DDNS_SERVICE_NAME}.service"
    safe_stop_disable_service "${ENTRY_DDNS_SERVICE_NAME}.timer"
    safe_stop_disable_service "${ENTRY_DDNS_SERVICE_NAME}.service"
    safe_stop_disable_service "leikwan-mss-clamp.service"
    cleanup_easytier_entry_units
  else
    warn "未找到 systemctl，跳过 systemd 服务停止。"
  fi
  safe_rm_file "$EASYTIER_RELAY_SERVICE" "$NFT_SERVICE" "$DDNS_SERVICE" "$DDNS_TIMER" "$ENTRY_DDNS_SERVICE" "$ENTRY_DDNS_TIMER" "/etc/systemd/system/leikwan-mss-clamp.service"
  if command -v nft >/dev/null 2>&1; then
    nft delete table inet leikwan_forward 2>/dev/null || true
    nft delete table inet lq_mss 2>/dev/null || true
  fi
  cleanup_leikwan_policy_routes
  safe_rm_file "$SHORTCUT_LQ" "$SHORTCUT_LQ_UPPER" "$FORWARD_SYSCTL" "$BBR_SYSCTL_CONF" "$DNS_RESOLVED_CONF"
  rm -rf /tmp/leikwan-update.* 2>/dev/null || true
  systemd_reload_reset_failed
}

uninstall_print_check_result() {
  echo
  echo "${BOLD}卸载检查结果${RESET}"
  uninstall_check_line "nftables 转发表" nft leikwan_forward
  uninstall_check_line "旧 MSS 临时表" nft lq_mss
  uninstall_check_line "EasyTier relay 服务" service "${EASYTIER_RELAY_SERVICE_NAME}.service"
  uninstall_check_line "nft 持久化服务" service "${NFT_SERVICE_NAME}.service"
  uninstall_check_line "DDNS refresh 服务" service "${DDNS_SERVICE_NAME}.service"
  uninstall_check_line "DDNS refresh timer" file "$DDNS_TIMER"
  uninstall_check_line "Entry DDNS 服务" service "${ENTRY_DDNS_SERVICE_NAME}.service"
  uninstall_check_line "Entry DDNS timer" file "$ENTRY_DDNS_TIMER"
  uninstall_check_line "MSS clamp 旧服务" service "leikwan-mss-clamp.service"
  uninstall_check_line "快捷命令 lq" file "$SHORTCUT_LQ"
  uninstall_check_line "快捷命令 LQ" file "$SHORTCUT_LQ_UPPER"
  uninstall_check_command_absent "command -v lq" lq
  uninstall_check_command_absent "command -v LQ" LQ
  uninstall_check_line "IPv4 转发 sysctl" file "$FORWARD_SYSCTL"
  uninstall_check_line "BBR sysctl" file "$BBR_SYSCTL_CONF"
  uninstall_check_line "DNS resolved 配置" file "$DNS_RESOLVED_CONF"
}

uninstall_normal() {
  local assume_yes="${1:-0}" release_global_lock=0
  need_root_unless_dry_run
  warn "将停止并删除 Leikwan 相关服务和 nftables/PBR 规则。"
  info "将保留 ${STATE_DIR} 和 ${BACKUP_DIR}。"
  if is_interactive && (( assume_yes == 0 )); then
    prompt_yes_no "确认继续？" "N" || return 0
  elif (( assume_yes == 0 && DRY_RUN == 0 )); then
    fail "非交互普通卸载必须显式传入 --yes。"
    return 1
  fi
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] stop/disable Leikwan services, delete nftables/PBR rules, remove lq shortcuts"
    return 0
  fi
  if [[ -z "$LEIKWAN_GLOBAL_LOCK_TOKEN" ]]; then
    global_lock_acquire || return 1
    release_global_lock=1
  fi
  LOG_DISABLED=1
  set +e
  uninstall_stop_services_and_rules
  set -e
  (( release_global_lock == 1 )) && global_lock_release
  uninstall_print_check_result
  ok "普通卸载完成；配置、快照和备份已保留。"
}

uninstall_final_snapshot() {
  local dest
  dest="/root/final-before-uninstall-$(snapshot_timestamp).tar.gz"
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] create final snapshot ${dest}"
    return 0
  fi
  if create_snapshot_archive "$dest"; then
    ok "已创建卸载前 final snapshot：${dest}"
    return 0
  fi
  warn "卸载前快照失败。"
  prompt_yes_no "是否仍继续深度卸载？" "N"
}

uninstall_deep() {
  local assume_yes="${1:-0}" confirm release_global_lock=0
  need_root_unless_dry_run
  warn "深度卸载会删除 ${STATE_DIR} 配置、状态、DDNS、PBR、entries、forwards。"
  warn "删除后若没有配置包或快照，将无法直接恢复。"
  if is_interactive && (( assume_yes == 0 )); then
    confirm="$(prompt_value "请输入 DELETE 确认")"
    [[ "$confirm" == "DELETE" ]] || { info "已取消深度卸载。"; return 0; }
  elif (( assume_yes == 0 )); then
    fail "非交互深度卸载必须显式传入 --yes。"
    return 1
  fi
  if (( DRY_RUN == 0 )) && [[ -z "$LEIKWAN_GLOBAL_LOCK_TOKEN" ]]; then
    global_lock_acquire || return 1
    release_global_lock=1
  fi
  if ! uninstall_final_snapshot; then
    (( release_global_lock == 1 )) && global_lock_release
    return 0
  fi
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] deep uninstall removes services/rules/config/logs/status/locks"
    return 0
  fi
  LOG_DISABLED=1
  set +e
  uninstall_stop_services_and_rules
  safe_rm_dir "$STATE_DIR" "$OLD_STATE_DIR"
  safe_rm_file "$DDNS_LOG_FILE" "$ENTRY_DDNS_LOG_FILE" "$APPLY_RELAY_LOG" "$LOG_FILE" "$OLD_LOG_FILE" "$OLD_ROOT_SCRIPT"
  rm -f "${LEIKWAN_RUN_DIR}"/leikwan-*.lock "${LEIKWAN_RUN_DIR}"/leikwan-*.lock.pid 2>/dev/null || true
  rm -rf "${LEIKWAN_RUN_DIR}"/leikwan-*.lock.d 2>/dev/null || true
  if is_interactive; then
    prompt_yes_no "是否同时删除 ${BACKUP_DIR}？" "N" && safe_rm_dir "$BACKUP_DIR" "$OLD_BACKUP_DIR"
  fi
  set -e
  (( release_global_lock == 1 )) && global_lock_release
  uninstall_print_check_result
  uninstall_check_line "配置目录" dir "$STATE_DIR"
  uninstall_check_line "DDNS 日志文件" file "$DDNS_LOG_FILE"
  uninstall_check_line "兼容 DNS 更新日志文件" file "$ENTRY_DDNS_LOG_FILE"
  uninstall_check_line "apply-relay 日志" file "$APPLY_RELAY_LOG"
  ok "深度卸载完成。"
}

print_uninstall_menu() {
  print_menu_header "卸载"
  echo "1. 普通卸载：移除服务和规则，保留配置 / 快照 / 备份"
  echo "2. 深度卸载：移除服务、规则、配置、日志、状态"
  echo "0. 返回"
}

uninstall_new_mode() {
  local choice
  while true; do
    print_uninstall_menu
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) run_menu_action_pause uninstall_normal; return 0 ;;
      2) run_menu_action_pause uninstall_deep; return 0 ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

uninstall_cli() {
  local mode="${1:-}" assume_yes=0
  shift || true
  while (($# > 0)); do
    case "$1" in
      --yes|-y) assume_yes=1; shift ;;
      *) fail "未知 uninstall 参数：$1"; return 1 ;;
    esac
  done
  case "$mode" in
    normal|"") uninstall_normal "$assume_yes" ;;
    deep|--deep) uninstall_deep "$assume_yes" ;;
    menu) uninstall_new_mode ;;
    *) fail "未知 uninstall 模式：${mode}"; echo "用法：lq uninstall [normal|deep] [--yes]" >&2; return 1 ;;
  esac
}

snapshot_timestamp() {
  date '+%Y%m%d-%H%M%S'
}

snapshot_copy_path() {
  local stage="$1" path="$2" dest
  [[ -e "$path" ]] || return 0
  dest="${stage}${path}"
  mkdir -p "$(dirname "$dest")"
  cp -a "$path" "$dest"
}

snapshot_collect_runtime_info() {
  local stage="$1"
  local info_dir="${stage}${STATE_DIR}/snapshot-info"
  mkdir -p "$info_dir"
  {
    echo "leikwan-toolkit ${TOOL_VERSION}"
    echo "created_at=$(status_now)"
  } >"${info_dir}/manifest.txt"
  if command -v nft >/dev/null 2>&1; then
    nft list ruleset >"${info_dir}/nft-ruleset.txt" 2>&1 || true
  else
    echo "nft command not found" >"${info_dir}/nft-ruleset.txt"
  fi
  if command -v ip >/dev/null 2>&1; then
    ip rule show >"${info_dir}/ip-rule-show.txt" 2>&1 || true
    ip route show table all >"${info_dir}/ip-route-show-table-all.txt" 2>&1 || true
  else
    echo "ip command not found" >"${info_dir}/ip-rule-show.txt"
    echo "ip command not found" >"${info_dir}/ip-route-show-table-all.txt"
  fi
}

create_snapshot_archive() {
  local dest="$1" tmp stage svc
  tmp="$(mktemp -d)"
  stage="${tmp}/root"
  mkdir -p "$stage"
  if [[ -d "$STATE_DIR" ]]; then
    tar --exclude='etc/leikwan-toolkit/snapshots' -C / -cf - etc/leikwan-toolkit 2>/dev/null | tar -C "$stage" -xf - 2>/dev/null || true
  else
    mkdir -p "${stage}${STATE_DIR}"
  fi
  snapshot_copy_path "$stage" "$EASYTIER_RELAY_SERVICE"
  while IFS= read -r svc; do
    snapshot_copy_path "$stage" "$svc"
  done < <(find /etc/systemd/system -maxdepth 1 -type f -name 'easytier-entry-*.service' 2>/dev/null || true)
  snapshot_copy_path "$stage" "$NFT_SERVICE"
  snapshot_copy_path "$stage" "$FORWARD_SYSCTL"
  snapshot_copy_path "$stage" "$BBR_SYSCTL_CONF"
  snapshot_copy_path "$stage" "$PBR_RT_TABLES"
  snapshot_collect_runtime_info "$stage"
  mkdir -p "$(dirname "$dest")"
  tar -czf "$dest" -C "$stage" .
  rm -rf "$tmp"
}

create_snapshot() {
  need_root_unless_dry_run
  local dest
  echo "[WARN] 快照可能包含 EasyTier network secret，请妥善保存。"
  dest="${SNAPSHOT_DIR}/snapshot-$(snapshot_timestamp).tar.gz"
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] create snapshot ${dest}"
    return 0
  fi
  ensure_base_dirs
  create_snapshot_archive "$dest"
  ok "已创建配置快照：${dest}"
}

snapshot_files() {
  {
    find "$SNAPSHOT_DIR" -maxdepth 1 -type f -name 'snapshot-*.tar.gz' 2>/dev/null || true
    find "$AUTO_SNAPSHOT_DIR" -maxdepth 1 -type f -name 'auto-before-*.tar.gz' 2>/dev/null || true
  } | sort
}

latest_snapshot_file() {
  {
    find "$SNAPSHOT_DIR" -maxdepth 1 -type f -name 'snapshot-*.tar.gz' -printf '%T@ %p\n' 2>/dev/null || true
    find "$AUTO_SNAPSHOT_DIR" -maxdepth 1 -type f -name 'auto-before-*.tar.gz' -printf '%T@ %p\n' 2>/dev/null || true
  } | sort -nr | awk 'NR==1 {sub(/^[^ ]+ /, ""); print}'
}

list_snapshots() {
  local files=() i file size
  mapfile -t files < <(snapshot_files)
  if (( ${#files[@]} == 0 )); then
    warn "当前没有快照。"
    return 0
  fi
  echo "配置快照列表"
  echo "----------------------------------------"
  i=0
  for file in "${files[@]}"; do
    i=$((i + 1))
    size="$(du -h "$file" 2>/dev/null | awk '{print $1}')"
    printf '%d. %s (%s)\n' "$i" "$file" "${size:-unknown}"
  done
}

select_snapshot_by_number() {
  local prompt="${1:-请输入快照编号，直接回车返回}" files=() choice
  mapfile -t files < <(snapshot_files)
  if (( ${#files[@]} == 0 )); then
    warn "当前没有快照。"
    return 1
  fi
  list_snapshots
  choice="$(prompt_value "$prompt")"
  [[ -n "$choice" ]] || return 1
  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#files[@]} )); then
    printf '%s' "${files[$((choice - 1))]}"
    return 0
  fi
  warn "快照编号无效：${choice}"
  return 1
}

restart_restored_services() {
  local svc
  if ! command -v systemctl >/dev/null 2>&1; then
    warn "未找到 systemctl，跳过服务重启。"
    return 0
  fi
  echo "将重启以下 Leikwan 相关服务（若存在）："
  [[ -f "$EASYTIER_RELAY_SERVICE" ]] && echo "- ${EASYTIER_RELAY_SERVICE_NAME}.service"
  while IFS= read -r svc; do
    [[ -n "$svc" ]] && echo "- $(basename "$svc")"
  done < <(find /etc/systemd/system -maxdepth 1 -type f -name 'easytier-entry-*.service' 2>/dev/null || true)
  [[ -f "$NFT_SERVICE" ]] && echo "- ${NFT_SERVICE_NAME}.service"
  systemctl daemon-reload || warn "systemd daemon-reload 失败。"
  [[ -f "$EASYTIER_RELAY_SERVICE" ]] && systemctl restart "${EASYTIER_RELAY_SERVICE_NAME}.service" || true
  while IFS= read -r svc; do
    systemctl restart "$(basename "$svc")" || warn "重启 $(basename "$svc") 失败。"
  done < <(find /etc/systemd/system -maxdepth 1 -type f -name 'easytier-entry-*.service' 2>/dev/null || true)
  [[ -f "$NFT_SERVICE" ]] && systemctl restart "${NFT_SERVICE_NAME}.service" || true
}

print_post_restore_next_steps() {
  echo "下一步建议:"
  echo "1. lq status"
  echo "2. lq --doctor"
  echo "3. 如需应用转发规则：lq forward apply-relay --auto-fix-route"
}

restore_snapshot() {
  need_root_unless_dry_run
  local path="${1:-}" release_global_lock=0
  [[ -n "$path" ]] || path="$(select_snapshot_by_number "请输入要恢复的快照编号")" || return 0
  if [[ ! -f "$path" ]]; then
    [[ "$path" == *.tar.gz ]] || { warn "快照不存在：${path}"; return 0; }
  fi
  [[ -f "$path" ]] || { warn "文件不存在：${path}"; return 0; }
  echo "[WARN] 恢复快照会覆盖当前 leikwan 配置和相关 systemd/nftables 状态。"
  prompt_yes_no "确认恢复？" "N" || return 0
  auto_snapshot_or_confirm "restore-snapshot" || return 0
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] tar -xzf ${path} -C /"
    return 0
  fi
  if [[ -z "$LEIKWAN_GLOBAL_LOCK_TOKEN" ]]; then
    global_lock_acquire || return 1
    release_global_lock=1
  fi
  if ! tar -xzf "$path" -C /; then
    (( release_global_lock == 1 )) && global_lock_release
    fail "快照恢复失败：${path}"
    return 1
  fi
  ok "快照已恢复：${path}"
  if prompt_yes_no "是否立即重新加载 systemd 并重启相关服务？" "N"; then
    restart_restored_services
  else
    info "已跳过服务重启。请按需手动执行 systemctl daemon-reload / restart。"
  fi
  print_post_restore_next_steps
  (( release_global_lock == 1 )) && global_lock_release
}

delete_snapshot() {
  need_root_unless_dry_run
  local path
  path="$(select_snapshot_by_number "请输入要删除的快照编号")" || return 0
  prompt_yes_no "确认删除快照 ${path}？" "N" || return 0
  (( DRY_RUN == 1 )) && { echo "[DRY-RUN] rm -f ${path}"; return 0; }
  rm -f "$path"
  ok "已删除快照：${path}"
}

export_latest_snapshot() {
  need_root_unless_dry_run
  local latest dest ts
  latest="$(latest_snapshot_file)"
  [[ -n "$latest" && -f "$latest" ]] || { warn "当前没有可导出的快照。"; return 0; }
  ts="$(snapshot_timestamp)"
  dest="/root/leikwan-snapshot-${ts}.tar.gz"
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] cp -a ${latest} ${dest}"
    return 0
  fi
  cp -a "$latest" "$dest"
  ok "已导出最新快照：${dest}"
}

prune_auto_snapshots() {
  local old=() file
  mapfile -t old < <(find "$AUTO_SNAPSHOT_DIR" -maxdepth 1 -type f -name 'auto-before-*.tar.gz' -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR>10 {sub(/^[^ ]+ /, ""); print}')
  for file in "${old[@]}"; do
    rm -f "$file" 2>/dev/null || true
  done
}

auto_snapshot_or_confirm() {
  local action="$1" safe_action dest
  need_root_unless_dry_run
  safe_action="$(safe_name "$action")"
  dest="${AUTO_SNAPSHOT_DIR}/auto-before-${safe_action}-$(snapshot_timestamp).tar.gz"
  if (( DRY_RUN == 1 )); then
    echo "[DRY-RUN] create auto snapshot ${dest}"
    return 0
  fi
  ensure_base_dirs
  if create_snapshot_archive "$dest"; then
    ok "已创建自动快照：${dest}"
    prune_auto_snapshots
    return 0
  fi
  warn "自动快照失败，建议先手动创建快照。"
  if ! is_interactive; then
    warn "非交互模式不进行确认 prompt，已跳过本次操作。"
    return 1
  fi
  prompt_yes_no "是否继续？" "N"
}

snapshot_menu() {
  local choice
  while true; do
    print_menu_header "配置快照 / 回滚"
    echo "1. 创建当前完整快照"
    echo "2. 查看快照列表"
    echo "3. 恢复指定快照"
    echo "4. 删除旧快照"
    echo "5. 导出最新快照到 /root"
    echo "0. 返回"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) run_menu_action_pause create_snapshot ;;
      2) run_menu_action_pause list_snapshots ;;
      3) run_menu_action_pause restore_snapshot ;;
      4) run_menu_action_pause delete_snapshot ;;
      5) run_menu_action_pause export_latest_snapshot ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

backup_snapshot() {
  create_snapshot "$@"
}

snapshot_restore_legacy() {
  restore_snapshot "$@"
}

backup_restore_menu() {
  snapshot_menu "$@"
}

easytier_menu() {
  local choice
  while true; do
    print_menu_header "EasyTier 组网管理"
    echo "1. 安装 / 修复 EasyTier"; echo "2. B 生成网络码"; echo "3. A 粘贴网络码并部署入口"; echo "4. B 粘贴入口码并完成接入"; echo "5. 启动 / 重启 entry 服务"; echo "6. 启动 / 重启 relay 服务"; echo "0. 返回"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) run_menu_action install_easytier_binary repair ;;
      2) run_menu_action quick_generate_network_pairing ;;
      3) run_menu_action quick_deploy_entry_from_network_pairing ;;
      4) run_menu_action quick_deploy_relay_from_entry_pairing ;;
      5) run_menu_action apply_easytier_entry_services ;;
      6) run_menu_action apply_easytier_relay_service ;;
      0) return 0 ;;
    esac
  done
}

entries_menu() {
  local choice
  while true; do
    print_menu_header "公网入口列表管理（B 侧）"
    echo "1. 生成新公网入口接入码"
    echo "2. 粘贴公网入口返回码并接入"
    echo "3. 手动添加公网入口（高级）"
    echo "4. 修改公网入口详情"
    echo "5. 删除公网入口"
    echo "6. 启用 / 禁用公网入口"
    echo "7. 修改公网入口权重"
    echo "8. 查看所有公网入口"
    echo "9. 测试公网入口"
    echo "10. 切换主公网入口"
    echo "11. 批量启用 / 禁用公网入口"
    echo "12. 查看 / 清理未完成接入码"
    echo "0. 返回"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) run_menu_action quick_generate_network_pairing ;;
      2) run_menu_action quick_deploy_relay_from_entry_pairing ;;
      3) run_menu_action_pause add_entry ;;
      4) run_menu_action_pause edit_entry ;;
      5) run_menu_action_pause delete_entry ;;
      6) run_menu_action_pause set_entry_enabled ;;
      7) run_menu_action_pause set_entry_weight ;;
      8) run_menu_action_pause list_entries ;;
      9) run_menu_action_pause test_entries ;;
      10) run_menu_action_pause switch_primary_entry ;;
      11) bulk_entry_enable_menu ;;
      12) pending_entries_menu ;;
      13|0) return 0 ;;
    esac
  done
}

print_forwards_menu_options() {
  print_menu_header "转发目标管理"
  echo "1. 添加转发目标"
  echo "2. 修改转发目标"
  echo "3. 删除转发目标"
  echo "4. 查看转发目标"
  echo "5. 启用 / 禁用转发目标"
  echo "6. 解析 target_host"
  echo "7. 测试单个转发目标"
  echo "8. 导入 forwards.tsv（高级）"
  echo "9. 导出 forwards.tsv"
  echo "10. 生成转发入口输出"
  echo "11. 生成公网入口转发接入码（A 侧导入用）"
  echo "0. 返回"
  info "DDNS / 域名解析变化检测已移动到主菜单“DDNS”。"
}

forwards_menu() {
  local choice
  while true; do
    print_forwards_menu_options
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) run_menu_action_pause add_forward ;;
      2) run_menu_action_pause edit_forward ;;
      3) run_menu_action_pause delete_forward ;;
      4) run_menu_action_pause list_forwards ;;
      5) run_menu_action_pause set_forward_enabled ;;
      6) run_menu_action_pause resolve_forward_targets_action ;;
      7) run_menu_action_pause test_forward ;;
      8) run_menu_action_pause import_forwards_tsv ;;
      9) run_menu_action_pause export_forwards_tsv ;;
      10) run_menu_action generate_forward_outputs ;;
      11) run_menu_action export_forward_bundle_code ;;
      0) return 0 ;;
    esac
  done
}

print_pbr_menu_options() {
  print_menu_header "IPv4 多出口策略路由 / PBR"
  echo "1. 添加静态 PBR"
  echo "2. 从现有转发目标添加 PBR"
  echo "3. 修改 PBR 规则"
  echo "4. 删除 PBR 规则"
  echo "5. 应用 PBR"
  echo "6. 查看 PBR"
  echo "7. 域名 PBR 管理"
  echo "0. 返回"
}

pbr_menu() {
  local choice
  while true; do
    print_pbr_menu_options
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) run_menu_action_pause pbr_add_static ;;
      2) run_menu_action_pause pbr_add_from_forward ;;
      3) run_menu_action_pause pbr_edit_rule_menu ;;
      4) run_menu_action_pause delete_pbr_rule ;;
      5) run_menu_action_pause pbr_apply ;;
      6) run_menu_action_pause pbr_show ;;
      7) pbr_domain_menu ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

install_shortcuts() {
  need_root_unless_dry_run
  local script_path content
  if [[ -f /root/leikwan-toolkit.sh ]]; then
    script_path="$(readlink -f /root/leikwan-toolkit.sh 2>/dev/null || printf '%s' /root/leikwan-toolkit.sh)"
  else
    script_path="$(readlink -f "$0" 2>/dev/null || printf '%s' "$0")"
  fi
  content="#!/usr/bin/env bash
# Managed by leikwan-toolkit
exec bash ${script_path@Q} \"\$@\""
  install_shortcut_if_needed "$SHORTCUT_LQ" "$script_path" "$content"
  install_shortcut_if_needed "$SHORTCUT_LQ_UPPER" "$script_path" "$content"
}

shortcut_is_current() {
  local shortcut="$1" script_path="$2" content="$3" tmp rc
  if [[ -L "$shortcut" ]]; then
    [[ "$(readlink -f "$shortcut" 2>/dev/null || true)" == "$script_path" ]]
    return
  fi
  [[ -f "$shortcut" ]] || return 1
  tmp="$(mktemp)"
  printf '%s\n' "$content" >"$tmp"
  cmp -s "$tmp" "$shortcut"
  rc=$?
  rm -f "$tmp"
  return "$rc"
}

install_shortcut_if_needed() {
  local shortcut="$1" script_path="$2" content="$3"
  if shortcut_is_current "$shortcut" "$script_path" "$content"; then
    return 0
  fi
  if [[ -L "$shortcut" ]]; then
    backup_file "$shortcut"
    (( DRY_RUN == 1 )) || rm -f "$shortcut"
  fi
  write_file "$shortcut" "$content" 755
}

print_quick_networking_steps() {
  cat <<'EOF'
快速组网详细说明
----------------------------------------
快速组网会自动执行系统网络预处理：
- 开启 IPv4 优先
- 设置系统 DNS 为 8.8.8.8 / 1.1.1.1

如果不希望系统 DNS 被脚本管理，可在完成组网后到：
高级维护 -> 系统网络优化 -> DNS 服务器：设置 / 恢复
中恢复。

步骤 1：利群主机生成网络码
在 B 利群主机执行：
主菜单 -> 快速组网 -> 2
脚本会读取 entries.tsv，自动推荐下一个不冲突的公网入口名称、EasyTier IP 和 8000-9000 内监听端口。
复制输出的 NETWORK 网络码。

步骤 2：公网入口加入网络
在 A 公网入口机执行：
主菜单 -> 快速组网 -> 3
粘贴 B 生成的 NETWORK 网络码。
完成后复制 A 输出的 ENTRY 入口码。

步骤 3：利群主机完成接入
在 B 利群主机执行：
主菜单 -> 快速组网 -> 4
粘贴 A 生成的 ENTRY 入口码。

步骤 4：如需指定 CN2 / 9929 出口，利群主机先配置 PBR（可选）
在 B 利群主机执行：
主菜单 -> 利群主机 B -> 3
如果不需要 PBR，本步骤可以跳过。

步骤 5：利群主机添加后端转发目标
在 B 利群主机执行：
主菜单 -> 快速组网 -> 5
例如：
10001 -> 后端IP:后端端口

如果先添加了转发目标，后添加 PBR，需要重新执行：
lq forward apply-relay --auto-fix-route

步骤 6：利群主机生成公网入口转发接入码
在 B 利群主机执行：
主菜单 -> 快速组网 -> 6
复制 LEIKWAN_FORWARD_BUNDLE 接入码。

步骤 7：公网入口粘贴转发接入码（推荐）
在 A 公网入口机执行：
主菜单 -> 快速组网 -> 7
或 公网入口 A -> 2
粘贴 B 生成的转发接入码，按端口逐条 DNAT，无需手填端口池。

（兼容）旧版端口池：快速组网 -> 8 或 公网入口 A -> 3

步骤 8：A/B 两边执行一键诊断
A 和 B 都执行：
主菜单 -> 状态 / 诊断 -> 3

步骤 9：外部机器测试公网入口端口
nc -vz -w 5 A_PUBLIC_IP 10001

新增第二台公网入口：
- B 进入“快速组网”，生成公网入口接入码，脚本会自动推荐新的 EasyTier IP 和监听端口。
- 新 A 进入“快速组网”，粘贴接入码并部署入口。
- 新 A 执行“粘贴转发接入码”（或兼容：配置入口端口池）。
- B 回到“快速组网”，粘贴 A 返回码完成接入。
- B 执行 利群主机 -> 公网入口列表管理 查看 / 测试。

确认：
- EasyTier active
- ping 对端成功
- nftables DNAT 存在
- TCP MSS clamp enabled: 1320
----------------------------------------
EOF
}

quick_networking_menu() {
  local choice
  while true; do
    clear_screen_if_interactive
    print_compact_header "快速组网"
    echo "B：利群主机，负责中转和转发"
    echo "A：公网入口，负责接入公网流量"
    echo "C：后端目标，最终访问的服务"
    echo
    info "快速组网会自动执行系统网络预处理："
    echo "- 开启 IPv4 优先"
    echo "- 设置系统 DNS 为 8.8.8.8 / 1.1.1.1"
    echo "如不希望系统 DNS 被脚本管理，可在高级维护 -> 系统网络优化中恢复。"
    echo
    echo "1. B：初始化利群主机"
    echo "2. B：生成公网入口接入码"
    echo "3. A：粘贴接入码并部署入口"
    echo "4. B：粘贴入口返回码完成接入"
    echo "5. B：添加后端转发目标"
    echo "6. B：生成公网入口转发接入码"
    echo "7. A：粘贴转发接入码并应用（推荐）"
    echo "8. A：配置入口端口池（兼容）"
    echo "9. B：生成转发端点输出"
    echo "0. 返回"
    info "B 配好转发后第 6 项生成接入码，A 第 7 项粘贴即生效，无需手填端口池。"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) init_relay_wizard ;;
      2) run_menu_action quick_generate_network_pairing || warn_and_pause "生成 EasyTier 网络码未完成，请查看上方提示后重试。" ;;
      3) run_menu_action quick_deploy_entry_from_network_pairing || warn_and_pause "公网入口部署未完成，请查看上方提示后重试。" ;;
      4) run_menu_action quick_deploy_relay_from_entry_pairing || warn_and_pause "利群主机接入未完成，请查看上方提示后重试。" ;;
      5) run_menu_action add_forward || warn_and_pause "后端转发目标添加未完成，请查看上方提示后重试。" ;;
      6) run_menu_action export_forward_bundle_code || warn_and_pause "生成公网入口转发接入码未完成，请查看上方提示后重试。" ;;
      7) run_menu_action import_forward_code || warn_and_pause "粘贴转发接入码未完成，请查看上方提示后重试。" ;;
      8) run_menu_action entry_expose_range || warn_and_pause "公网入口端口池配置未完成，请查看上方提示后重试。" ;;
      9) run_menu_action_pause generate_forward_outputs ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

init_plan() {
  local role_info role role_source entries_count forwards_count pbr_count
  role_info="$(role_summary)"
  IFS=$'\t' read -r role role_source _mixed <<<"$role_info"
  entries_count="$(entries_rows | awk 'END{print NR+0}')"
  forwards_count="$(forwards_rows | awk 'END{print NR+0}')"
  pbr_count="$(pbr_rules_count 2>/dev/null || printf '0')"
  echo "Leikwan 初始化计划"
  echo "----------------------------------------"
  case "$role" in
    leikwan-relay) echo "角色: B 利群主机 / 中转主机" ;;
    cloud-entry) echo "角色: A 公网入口" ;;
    *) echo "角色: 待选择（B 利群主机 / A 公网入口 / 配置包恢复）" ;;
  esac
  echo "角色来源: ${role_source:-无}"
  echo "已有配置: entries=${entries_count} forwards=${forwards_count} pbr=${pbr_count}"
  echo "将执行:"
  echo "[1] 环境预检"
  echo "[2] 自动执行系统网络预处理（IPv4 优先 + 8.8.8.8 / 1.1.1.1）"
  echo "[3] 安装依赖 curl jq tar unzip nftables"
  echo "[4] 安装 / 修复 EasyTier"
  echo "[5] 生成或粘贴公网入口接入码"
  echo "[6] 可选添加后端转发目标 / PBR / DDNS"
  echo
  echo "不会执行:"
  echo "- 不会覆盖已有 network.env"
  echo "- 不会重启 relay，除非用户确认"
  echo "- 不会清空 entries / forwards / pbr"
  echo "- --dry-run / --plan 不写文件、不启动服务、不应用 nftables / PBR"
  if (( entries_count + forwards_count + pbr_count > 0 )); then
    echo "[INFO] 检测到已有配置，初始化会进入维护模式并保留现有配置。"
  fi
}

init_step_action() {
  local title="$1"
  shift
  echo
  echo "[INFO] ${title}"
  if (( DRY_RUN == 1 )) || [[ "${1:-}" == "status_overview" || "${1:-}" == "init_plan" ]]; then
    run_menu_action_pause "$@"
    return $?
  fi
  local release_global_lock=0 rc
  if [[ -z "$LEIKWAN_GLOBAL_LOCK_TOKEN" ]]; then
    global_lock_acquire || return 1
    release_global_lock=1
  fi
  run_menu_action_pause "$@"
  rc=$?
  (( release_global_lock == 1 )) && global_lock_release
  return "$rc"
}

init_relay_wizard() {
  local choice entries_count forwards_count pbr_count
  ensure_role_or_warn leikwan-relay || return 0
  system_network_prepare || true
  while true; do
    entries_count="$(entries_rows | awk 'END{print NR+0}')"
    forwards_count="$(forwards_rows | awk 'END{print NR+0}')"
    pbr_count="$(pbr_rules_count 2>/dev/null || printf '0')"
    print_menu_header "B 利群主机初始化"
    if (( entries_count + forwards_count + pbr_count > 0 )) || relay_network_env_ready; then
      info "检测到已有利群主机配置。"
      info "将进入维护模式，不会重新初始化 network.env。"
    fi
    echo "1. 环境预检"
    echo "2. 系统网络预处理（IPv4 优先 + 国外 DNS）"
    echo "3. 安装 / 修复 EasyTier"
    echo "4. 生成第一个公网入口接入码"
    echo "5. 添加后端转发目标"
    echo "6. 可选：配置 PBR"
    echo "7. 可选：启用 DDNS 自动刷新"
    echo "8. 查看状态总览"
    echo "9. 查看初始化计划"
    echo "0. 返回"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) init_step_action "将读取当前配置、端口和状态，不修改系统。" status_overview ;;
      2) init_step_action "将执行系统网络预处理：IPv4 优先 + 国外 DNS。" system_network_prepare ;;
      3) init_step_action "将安装或修复 EasyTier 二进制，执行前会确认下载来源。" install_easytier_binary repair ;;
      4) init_step_action "将复用现有 network name / secret 生成公网入口接入码，不覆盖 network.env。" quick_generate_network_pairing ;;
      5) init_step_action "将添加后端转发目标，端口冲突会被预检拦截。" add_forward ;;
      6) pbr_menu ;;
      7) ddns_menu ;;
      8) init_step_action "将显示 B 利群主机状态总览。" status_overview ;;
      9) init_step_action "仅展示计划，不修改系统。" init_plan ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

init_entry_wizard() {
  local choice
  ensure_role_or_warn cloud-entry || return 0
  while true; do
    print_menu_header "A 公网入口初始化"
    if [[ "$(detect_leikwan_role)" == "cloud-entry" ]]; then
      info "检测到已有公网入口配置。"
      info "将进入维护模式，不会重复覆盖 entry service。"
    fi
    echo "1. 环境预检"
    echo "2. 粘贴 B 生成的公网入口接入码"
    echo "3. 安装 / 修复 EasyTier"
    echo "4. 部署 entry service"
    echo "5. 配置公网入口端口池"
    echo "6. 生成入口返回码"
    echo "7. 查看本机公网入口状态"
    echo "8. 查看初始化计划"
    echo "0. 返回"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) init_step_action "将读取当前入口配置和状态，不修改系统。" status_overview ;;
      2|4|6) init_step_action "将粘贴 B 生成的网络码并部署入口；EasyTier IP 必须是 10.x 虚拟 IP，DDNS 域名应填写为公网地址 / 域名。" init_entry_deploy_guarded ;;
      3) init_step_action "将安装或修复 EasyTier 二进制，执行前会确认下载来源。" install_easytier_binary repair ;;
      5) init_step_action "将配置 A 侧公网入口端口池 TCP+UDP DNAT。" entry_expose_range ;;
      7) init_step_action "将显示 A 公网入口状态总览，并提示 DDNS 是否一致。" status_overview ;;
      8) init_step_action "仅展示计划，不修改系统。" init_plan ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

init_import_wizard() {
  local pkg
  print_menu_header "配置包恢复"
  pkg="$(prompt_value "请输入配置包路径")"
  [[ -n "$pkg" ]] || return 0
  init_step_action "将 inspect 配置包，不导入、不修改系统。" config_inspect "$pkg" || return 0
  init_step_action "将复用 config import，导入前自动快照并保留安全边界检查。" config_import "$pkg"
  if prompt_yes_no "是否立即执行 doctor？" "N"; then
    run_menu_action_pause run_doctor_interactive
  else
    run_menu_action_pause status_overview
  fi
}

init_status_only() {
  init_step_action "仅查看当前状态，不修改系统。" status_overview
}

init_entry_deploy_guarded() {
  if [[ "$(detect_leikwan_role)" == "cloud-entry" ]] && { [[ -f "$NETWORK_ENV" || -f "$ENTRY_PAIRING_FILE" || -f "$ENTRY_EXPOSE_ENV" ]] || role_has_service 'easytier-entry-*.service'; }; then
    warn "检测到已有公网入口配置。"
    warn "为避免覆盖 entry service / entry env / ENTRY 返回码状态，默认不重新部署。"
    prompt_yes_no "是否仍然重新粘贴接入码并部署？" "N" || return 0
  fi
  quick_deploy_entry_from_network_pairing
}

print_init_wizard_menu() {
  print_menu_header "Leikwan 初始化向导"
  echo "这台机器准备用作："
  echo
  echo "1. B：利群主机 / 中转主机"
  echo "2. A：公网入口"
  echo "3. 从配置包恢复"
  echo "4. 仅检查当前状态"
  echo "0. 返回"
}

# shellcheck disable=SC2120
init_wizard() {
  local choice plan_only=0 arg
  while (($# > 0)); do
    arg="$1"
    case "$arg" in
      --dry-run|--plan) DRY_RUN=1; plan_only=1; shift ;;
      *) fail "未知 init 参数：${arg}"; return 1 ;;
    esac
  done
  if (( plan_only == 1 )) || ! is_interactive; then
    init_plan
    return 0
  fi
  while true; do
    print_init_wizard_menu
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) init_relay_wizard ;;
      2) init_entry_wizard ;;
      3) init_import_wizard ;;
      4) init_status_only ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

print_operations_center_menu() {
  print_menu_header "运维命令中心"
  echo "1. 查看状态总览"
  echo "2. 一键诊断"
  echo "3. 自动修复常见问题"
  echo "4. 重新应用转发规则"
  echo "5. 检查端口冲突"
  echo "6. 生成端点输出"
  echo "7. 配置导出 / 导入"
  echo "8. DDNS 自动刷新"
  echo "9. 自更新"
  echo "10. 日志查看 / 清理"
  echo "0. 返回"
}

operations_center_menu() {
  local choice
  while true; do
    print_operations_center_menu
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) run_menu_action_pause status_overview ;;
      2) run_menu_action run_doctor_interactive ;;
      3) run_menu_action_pause doctor_auto_fix ;;
      4) apply_relay_rules_menu ;;
      5) run_menu_action_pause port_check ;;
      6) run_menu_action_pause generate_forward_outputs ;;
      7) config_menu ;;
      8) ddns_menu ;;
      9) update_menu ;;
      10) logs_menu ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

endpoint_output_menu() {
  local choice
  while true; do
    print_menu_header "端点输出"
    echo "1. 生成端点输出"
    echo "2. 查看文本输出"
    echo "3. 查看 JSON 输出"
    echo "4. 查看 HTML 路径"
    echo "5. 生成 QR（可选）"
    echo "0. 返回"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) run_menu_action_pause generate_forward_outputs ;;
      2) run_menu_action_pause output_show ;;
      3) run_menu_action_pause output_json ;;
      4) run_menu_action_pause output_html ;;
      5) run_menu_action_pause output_qr ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

entry_ddns_menu() {
  local choice
  while true; do
    print_menu_header "兼容 DNS 更新"
    echo "1. 配置兼容 DNS 更新"
    echo "2. 立即执行兼容 DNS 更新"
    echo "3. 启用 / 禁用兼容 DNS 更新"
    echo "4. 查看兼容 DNS 更新状态"
    echo "5. 查看兼容 DNS 更新日志"
    echo "0. 返回"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) run_menu_action_pause entry_ddns_setup ;;
      2) run_menu_action_pause entry_ddns_run ;;
      3) entry_ddns_toggle_menu ;;
      4) run_menu_action_pause entry_ddns_status ;;
      5) run_menu_action_pause entry_ddns_logs ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

print_status_diagnostics_menu_options() {
    print_menu_header "状态 / 诊断"
    echo "1. 状态总览"
    echo "2. 简洁状态"
    echo "3. 一键诊断"
    echo "4. 自动修复常见问题"
    echo "5. 端口冲突检查"
    echo "6. 查看日志"
    echo "0. 返回"
}

status_diagnostics_menu() {
  local choice
  while true; do
    print_status_diagnostics_menu_options
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) run_menu_action_pause status_lts ;;
      2) run_menu_action_pause status_brief ;;
      3) run_menu_action run_doctor_interactive ;;
      4) run_menu_action_pause doctor_auto_fix ;;
      5) run_menu_action_pause port_check ;;
      6) logs_menu ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

print_relay_host_menu_options() {
  print_menu_header "利群主机 B"
  echo "1. 公网入口管理"
  echo "2. 转发目标管理"
  echo "3. IPv4 PBR 出口策略"
  echo "4. 重新应用转发规则"
  echo "5. 查看 B 端状态"
  echo "0. 返回"
}

relay_host_menu() {
  local choice
  ensure_role_or_warn leikwan-relay || return 0
  while true; do
    print_relay_host_menu_options
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) entries_menu ;;
      2) forwards_menu ;;
      3) pbr_menu ;;
      4) apply_relay_rules_menu ;;
      5) run_menu_action_pause status_lts ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

entry_host_menu() {
  local choice
  ensure_role_or_warn cloud-entry || return 0
  while true; do
    print_menu_header "公网入口 A"
    echo "1. 粘贴组网接入码并部署入口"
    echo "2. 粘贴转发接入码并应用（推荐）"
    echo "3. 配置入口端口池（兼容）"
    echo "4. 查看 A 端状态"
    echo "5. DDNS / 域名解析变化"
    echo "0. 返回"
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) run_menu_action quick_deploy_entry_from_network_pairing ;;
      2) run_menu_action_pause import_forward_code ;;
      3) run_menu_action_pause entry_expose_range ;;
      4) run_menu_action_pause status_lts ;;
      5) ddns_menu ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

print_advanced_menu_options() {
    print_menu_header "高级维护"
    echo "1. EasyTier 服务管理"
    echo "2. 配置备份 / 快照 / 回滚"
    echo "3. 配置导入 / 导出"
    echo "4. 自更新"
    echo "5. 端点输出"
    echo "6. 调试报告"
    echo "7. 系统网络优化"
    echo "8. 卸载"
    echo "0. 返回"
}

advanced_menu() {
  local choice
  while true; do
    print_advanced_menu_options
    choice="$(prompt_menu_choice "请选择：")"
    case "$choice" in
      1) easytier_menu ;;
      2) snapshot_menu ;;
      3) config_menu ;;
      4) update_menu ;;
      5) endpoint_output_menu ;;
      6) run_menu_action_pause generate_debug_report ;;
      7) system_network_menu ;;
      8) uninstall_new_mode ;;
      0) return 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

print_main_menu_options() {
  print_banner
    echo "1. 快速组网"
    echo "2. 利群主机 B"
    echo "3. 公网入口 A"
    echo "4. DDNS"
    echo "5. 状态 / 诊断"
    echo "6. 高级维护"
    echo "0. 退出"
}

main_menu() {
  need_root_unless_dry_run
  install_shortcuts || true
  ensure_tsv_files
  local choice
  while true; do
    clear_screen_if_interactive
    print_main_menu_options
    choice="$(prompt_menu_choice "请选择：")"
    # shellcheck disable=SC2119
    case "$choice" in
      1) quick_networking_menu ;;
      2) relay_host_menu ;;
      3) entry_host_menu ;;
      4) ddns_menu ;;
      5) status_diagnostics_menu ;;
      6) advanced_menu ;;
      0) exit 0 ;;
      "") menu_input_required ;;
      *) menu_invalid_choice ;;
    esac
  done
}

main() {
  while true; do
    case "${1:-}" in
      --dry-run) DRY_RUN=1; shift ;;
      --compact|--brief) LEIKWAN_BRIEF=1; LEIKWAN_COMPACT=1; shift ;;
      *) break ;;
    esac
  done
  if [[ -z "${1:-}" && "${LEIKWAN_BRIEF:-0}" == "1" ]]; then
    run_cli_action status_brief
  fi
  case "${1:-}" in
    init|wizard|quickstart)
      shift
      run_cli_action init_wizard "$@"
      ;;
    plan)
      run_cli_action init_plan
      ;;
    status)
      if [[ "${2:-}" == "--json" ]]; then
        run_cli_action status_json
      elif [[ "${2:-}" == "--verbose" ]]; then
        run_cli_action status_overview
      elif [[ "${2:-}" == "--brief" || "${2:-}" == "--compact" || "${LEIKWAN_BRIEF:-0}" == "1" ]]; then
        LEIKWAN_BRIEF=1
        run_cli_action status_brief
      else
        run_cli_action status_lts
      fi
      ;;
    doctor)
      case "${2:-}" in
        --json) run_cli_action doctor_json ;;
        --auto-fix) doctor_auto_fix ;;
        --brief|--compact) LEIKWAN_BRIEF=1; doctor ;;
        --verbose) VERBOSE_DOCTOR=1; doctor ;;
        "") doctor ;;
        *) fail "未知 doctor 参数：${2:-}"; print_help; exit 1 ;;
      esac
      ;;
    config)
      case "${2:-}" in
        export) shift 2; run_cli_action config_export "$@" ;;
        import) shift 2; run_cli_action config_import "$@" ;;
        inspect) run_cli_action config_inspect "${3:-}" ;;
        list) run_cli_action config_list ;;
        *) fail "未知 config 子命令：${2:-}"; print_help; exit 1 ;;
      esac
      ;;
    export-config)
      shift
      run_cli_action config_export "$@"
      ;;
    import-config)
      shift
      run_cli_action config_import "$@"
      ;;
    output)
      case "${2:-}" in
        generate) run_cli_action generate_forward_outputs ;;
        show) run_cli_action output_show ;;
        json) run_cli_action output_json ;;
        html) run_cli_action output_html ;;
        qr) run_cli_action output_qr ;;
        *) fail "未知 output 子命令：${2:-}"; print_help; exit 1 ;;
      esac
      ;;
    pair)
      case "${2:-}" in
        relay-init) quick_generate_network_pairing ;;
        entry-join) quick_deploy_entry_from_network_pairing "${3:-}" ;;
        relay-join) quick_deploy_relay_from_entry_pairing "${3:-}" ;;
        status) pairing_status ;;
        *) fail "未知 pair 子命令：${2:-}"; print_help; exit 1 ;;
      esac
      ;;
    system)
      case "${2:-}" in
        network)
          case "${3:-}" in
            status) run_cli_action system_network_status ;;
            prepare) run_cli_action system_network_prepare ;;
            *) fail "未知 system network 子命令：${3:-}"; print_help; exit 1 ;;
          esac
          ;;
        ipv4-prefer)
          case "${3:-}" in
            status) run_cli_action system_ipv4_prefer_status ;;
            enable) run_cli_action system_ipv4_prefer_enable ;;
            disable) run_cli_action system_ipv4_prefer_disable ;;
            *) fail "未知 system ipv4-prefer 子命令：${3:-}"; print_help; exit 1 ;;
          esac
          ;;
        dns)
          case "${3:-}" in
            status) run_cli_action system_dns_status ;;
            set) run_cli_action system_dns_set "${4:-$SYSTEM_DNS_TARGET_CSV}" ;;
            restore) run_cli_action system_dns_restore ;;
            *) fail "未知 system dns 子命令：${3:-}"; print_help; exit 1 ;;
          esac
          ;;
        ipv6)
          case "${3:-}" in
            status) run_cli_action system_ipv6_status ;;
            disable) run_cli_action system_ipv6_disable ;;
            restore) run_cli_action system_ipv6_restore ;;
            lockdown) run_cli_action ipv6_nft_lockdown ;;
            *) fail "未知 system ipv6 子命令：${3:-}"; print_help; exit 1 ;;
          esac
          ;;
        bbr)
          case "${3:-}" in
            status) run_cli_action system_bbr_status ;;
            enable) run_cli_action system_bbr_enable ;;
            restore) run_cli_action system_bbr_restore ;;
            *) fail "未知 system bbr 子命令：${3:-}"; print_help; exit 1 ;;
          esac
          ;;
        *) fail "未知 system 子命令：${2:-}"; print_help; exit 1 ;;
      esac
      ;;
    forward)
      case "${2:-}" in
        add) add_forward ;;
        edit) edit_forward "${3:-}" ;;
        delete) delete_forward "${3:-}" ;;
        export) export_forward_code_by_name "${3:-}" ;;
        bundle-export|bundle) export_forward_bundle_code ;;
        import) import_forward_code "${3:-}" ;;
        list) list_forwards ;;
        apply-relay)
          if [[ "${3:-}" == "--auto-fix-route" ]]; then
            apply_nft_rules "leikwan-relay" 1
          else
            apply_nft_rules "leikwan-relay"
          fi
          ;;
        *) fail "未知 forward 子命令：${2:-}"; print_help; exit 1 ;;
      esac
      ;;
    entry)
      case "${2:-}" in
        expose-range) shift 2; entry_expose_range "$@" ;;
        import) import_forward_code "${3:-}" ;;
        ddns)
          case "${3:-}" in
            status) run_cli_action entry_ddns_status ;;
            setup) warn "该命令为兼容入口，普通用户建议使用 lq ddns run。"; run_cli_action entry_ddns_setup ;;
            run) warn "该命令为兼容入口，普通用户建议使用 lq ddns run。"; shift 3; entry_ddns_run "$@" ;;
            enable) warn "该命令为兼容入口，普通用户建议使用 lq ddns enable。"; entry_ddns_enable_timer ;;
            disable) warn "该命令为兼容入口，普通用户建议使用 lq ddns disable。"; entry_ddns_disable_timer ;;
            logs) entry_ddns_logs ;;
            *) fail "未知 entry ddns 子命令：${3:-}"; print_help; exit 1 ;;
          esac
          ;;
        *) fail "未知 entry 子命令：${2:-}"; print_help; exit 1 ;;
      esac
      ;;
    port)
      case "${2:-}" in
        check) run_cli_action port_check ;;
        *) fail "未知 port 子命令：${2:-}"; print_help; exit 1 ;;
      esac
      ;;
    pbr)
      case "${2:-}" in
        edit) pbr_edit_rule "${3:-}" || exit $? ;;
        delete) delete_pbr_rule "${3:-}" || exit $? ;;
        apply) pbr_apply || exit $? ;;
        show|list) pbr_show || exit $? ;;
        sync-from-forwards) shift 2; pbr_sync_from_forwards "$@" || exit $? ;;
        domain)
          case "${3:-}" in
            add) pbr_domain_add || exit $? ;;
            list|show) pbr_domain_list || exit $? ;;
            delete) pbr_domain_delete || exit $? ;;
            sync) shift 3; pbr_domain_sync "$@" || exit $? ;;
            *) fail "未知 pbr domain 子命令：${3:-}"; print_help; exit 1 ;;
          esac
          ;;
        *) fail "未知 pbr 子命令：${2:-}"; print_help; exit 1 ;;
      esac
      ;;
    ddns)
      case "${2:-}" in
        run) shift 2; ddns_refresh_once "$@" ;;
        overview) run_cli_action ddns_overview ;;
        apply-entries) run_cli_action ddns_apply_entries ;;
        check-consistency) run_cli_action ddns_check_consistency ;;
        entry)
          case "${3:-}" in
            status) run_cli_action entry_ddns_status ;;
            run) warn "该命令为兼容入口，普通用户建议使用 lq ddns run。"; shift 3; entry_ddns_run "$@" ;;
            setup) warn "该命令为兼容入口，普通用户建议使用 lq ddns run。"; run_cli_action entry_ddns_setup ;;
            enable) warn "该命令为兼容入口，普通用户建议使用 lq ddns enable。"; entry_ddns_enable_timer ;;
            disable) warn "该命令为兼容入口，普通用户建议使用 lq ddns disable。"; entry_ddns_disable_timer ;;
            logs) entry_ddns_logs ;;
            *) fail "未知 ddns entry 子命令：${3:-}"; print_help; exit 1 ;;
          esac
          ;;
        status) run_cli_action ddns_status ;;
        enable) ddns_enable_timer ;;
        disable) ddns_disable_timer ;;
        logs) ddns_logs ;;
        *) fail "未知 ddns 子命令：${2:-}"; print_help; exit 1 ;;
      esac
      ;;
    logs)
      shift
      run_cli_action logs_cli "$@"
      ;;
    task)
      case "${2:-}" in
        status) run_cli_action task_status ;;
        unlock-stale) run_cli_action task_unlock_stale ;;
        *) fail "未知 task 子命令：${2:-}"; print_help; exit 1 ;;
      esac
      ;;
    update)
      case "${2:-}" in
        check) update_check || exit $? ;;
        ""|run) update_run || exit $? ;;
        status) update_status || exit $? ;;
        rollback) update_rollback || exit $? ;;
        *) fail "未知 update 子命令：${2:-}"; print_help; exit 1 ;;
      esac
      ;;
    --help|-h) print_help ;;
    --version|-v) echo "${PROJECT_NAME} $(tool_version_label)" ;;
    --status)
      case "${2:-}" in
        --verbose) run_cli_action status_overview ;;
        --brief|--compact) LEIKWAN_BRIEF=1; run_cli_action status_brief ;;
        *) if [[ "${LEIKWAN_BRIEF:-0}" == "1" ]]; then run_cli_action status_brief; else run_cli_action status_lts; fi ;;
      esac
      ;;
    --status-json) run_cli_action status_json ;;
    --compact|--brief) LEIKWAN_BRIEF=1; LEIKWAN_COMPACT=1; run_cli_action status_brief ;;
    --port-check) run_cli_action port_check ;;
    --doctor|--validate)
      case "${2:-}" in
        --auto-fix) doctor_auto_fix ;;
        --brief|--compact) LEIKWAN_BRIEF=1; doctor ;;
        --verbose) VERBOSE_DOCTOR=1; doctor ;;
        "") doctor ;;
        *) fail "未知 doctor 参数：${2:-}"; print_help; exit 1 ;;
      esac
      ;;
    --doctor-auto-fix) doctor_auto_fix ;;
    --doctor-json) run_cli_action doctor_json ;;
    --self-update) update_run 1 || exit $? ;;
    --update-check) update_check || exit $? ;;
    --ddns-run) shift; ddns_refresh_once "$@" ;;
    --pbr-apply) pbr_apply ;;
    --pbr-delete) delete_pbr_rule "${2:-}" ;;
    uninstall) shift; uninstall_cli "$@" ;;
    --uninstall) uninstall_new_mode ;;
    "") main_menu ;;
    *) fail "未知参数：$1"; print_help; exit 1 ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
