#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="3.0.0-alpha.2"
LISTEN="0.0.0.0:18080"
DATA_DIR="/var/lib/leikwan-panel"
CONFIG_DIR="/etc/leikwan-panel"
LOG_DIR="/var/log/leikwan-panel"
WEB_DIR=""
ENV_FILE=""
BIN_DST="/usr/local/bin/leikwan-controller"
AGENT_BIN_DST="/usr/local/bin/leikwan-agent"
SERVICE_DST="/etc/systemd/system/leikwan-controller.service"
AGENT_TOKEN=""
OPERATOR_TOKEN=""
ADMIN_PASSWORD=""
STRICT_AUTH="false"
PUBLIC_URL=""
RELEASE_URL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="${2:-}"; shift 2 ;;
    --listen) LISTEN="${2:-}"; shift 2 ;;
    --data-dir) DATA_DIR="${2:-}"; shift 2 ;;
    --agent-token) AGENT_TOKEN="${2:-}"; shift 2 ;;
    --operator-token) OPERATOR_TOKEN="${2:-}"; shift 2 ;;
    --admin-password) ADMIN_PASSWORD="${2:-}"; shift 2 ;;
    --strict-auth) STRICT_AUTH="true"; shift ;;
    --public-url) PUBLIC_URL="${2:-}"; shift 2 ;;
    --release-url|--install-url) RELEASE_URL="${2:-}"; shift 2 ;;
    *) echo "[FAIL] Unknown argument: $1" >&2; exit 1 ;;
  esac
done

WEB_DIR="${DATA_DIR}/web"
ENV_FILE="${CONFIG_DIR}/controller.env"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "[FAIL] Please run as root or via sudo." >&2
  exit 1
fi

SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
if [[ -n "${SCRIPT_SOURCE}" && -f "${SCRIPT_SOURCE}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_SOURCE}")" && pwd)"
else
  SCRIPT_DIR=""
fi

download_file() {
  local url="$1"
  local out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 2 --connect-timeout 10 "${url}" -o "${out}"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "${out}" "${url}"
  else
    echo "[FAIL] curl or wget is required." >&2
    return 1
  fi
}

random_token() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'
  fi
}

password_hash() {
  local value="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "${value}" | sha256sum | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    printf '%s' "${value}" | openssl dgst -sha256 | awk '{print $NF}'
  else
    printf '%s' "${value}"
  fi
}

detect_os_arch() {
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"
  case "${ARCH}" in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
  esac
}

install_deps_for_source_build() {
  local missing=()
  command -v go >/dev/null 2>&1 || missing+=(golang)
  command -v npm >/dev/null 2>&1 || missing+=(npm nodejs)
  if [[ ${#missing[@]} -eq 0 ]]; then
    return 0
  fi
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "[FAIL] Source build requires go and npm/nodejs. Please install them manually." >&2
    return 1
  fi
  echo "[INFO] Installing build dependencies: ${missing[*]}"
  apt-get update
  apt-get install -y ca-certificates curl wget tar gzip "${missing[@]}"
}

install_from_dist_dir() {
  local dist="$1"
  if [[ ! -x "${dist}/leikwan-controller" ]]; then
    return 1
  fi
  echo "[INFO] Installing Controller from ${dist}"
  install -m 0755 "${dist}/leikwan-controller" "${BIN_DST}"
  if [[ -x "${dist}/leikwan-agent" ]]; then
    install -m 0755 "${dist}/leikwan-agent" "${AGENT_BIN_DST}"
  fi
  if [[ -d "${dist}/web" ]]; then
    rm -rf "${WEB_DIR}"
    mkdir -p "${WEB_DIR}"
    cp -R "${dist}/web/." "${WEB_DIR}/"
  else
    echo "[WARN] dist does not contain web/; Controller API will run but Web UI may be missing." >&2
  fi
}

try_local_dist() {
  if [[ -z "${SCRIPT_DIR}" ]]; then
    return 1
  fi
  local panel_dir
  panel_dir="$(cd "${SCRIPT_DIR}/.." 2>/dev/null && pwd || true)"
  [[ -n "${panel_dir}" ]] || return 1
  if [[ -d "${panel_dir}/dist" ]]; then
    install_from_dist_dir "${panel_dir}/dist"
    return $?
  fi
  install_from_dist_dir "${panel_dir}"
}

extract_and_install_tarball() {
  local tarball="$1"
  local tmp="$2"
  rm -rf "${tmp}/extract"
  mkdir -p "${tmp}/extract"
  tar -xzf "${tarball}" -C "${tmp}/extract"
  local dist="${tmp}/extract"
  if [[ ! -x "${dist}/leikwan-controller" ]]; then
    dist="$(find "${tmp}/extract" -maxdepth 3 -type f -name leikwan-controller -perm -111 -print -quit | xargs -r dirname)"
  fi
  [[ -n "${dist}" ]] || return 1
  install_from_dist_dir "${dist}"
}

try_release_download() {
  local tmp="$1"
  detect_os_arch
  local urls=()
  if [[ -n "${RELEASE_URL}" ]]; then
    urls+=("${RELEASE_URL}")
  else
    local tags=("v${VERSION}" "panel-${VERSION}")
    local assets=(
      "leikwan-panel-${VERSION}-${OS}-${ARCH}.tar.gz"
      "leikwan-panel-${OS}-${ARCH}.tar.gz"
      "panel-dist-${OS}-${ARCH}.tar.gz"
    )
    for tag in "${tags[@]}"; do
      for asset in "${assets[@]}"; do
        urls+=("https://github.com/ike-sh/leikwan-toolkit/releases/download/${tag}/${asset}")
      done
    done
  fi
  local url
  for url in "${urls[@]}"; do
    echo "[INFO] Trying Panel release: ${url}"
    if download_file "${url}" "${tmp}/panel.tar.gz"; then
      if extract_and_install_tarball "${tmp}/panel.tar.gz" "${tmp}"; then
        return 0
      fi
      echo "[WARN] Release downloaded but layout was not usable: ${url}" >&2
    else
      echo "[WARN] Release not available: ${url}" >&2
    fi
  done
  return 1
}

source_build_fallback() {
  local tmp="$1"
  install_deps_for_source_build
  echo "[INFO] Falling back to source build from GitHub main branch."
  download_file "https://github.com/ike-sh/leikwan-toolkit/archive/refs/heads/main.tar.gz" "${tmp}/source.tar.gz"
  rm -rf "${tmp}/source"
  mkdir -p "${tmp}/source"
  tar -xzf "${tmp}/source.tar.gz" -C "${tmp}/source" --strip-components=1
  for required in panel/controller panel/agent panel/controller/web; do
    if [[ ! -d "${tmp}/source/${required}" ]]; then
      echo "[FAIL] Source tarball missing ${required}" >&2
      return 1
    fi
  done
  (
    cd "${tmp}/source/panel/controller"
    go build -o "${tmp}/leikwan-controller" ./cmd/leikwan-controller
    npm --prefix web install
    npm --prefix web run build
  )
  (
    cd "${tmp}/source/panel/agent"
    go build -o "${tmp}/leikwan-agent" ./cmd/leikwan-agent
  )
  install -m 0755 "${tmp}/leikwan-controller" "${BIN_DST}"
  install -m 0755 "${tmp}/leikwan-agent" "${AGENT_BIN_DST}"
  rm -rf "${WEB_DIR}"
  mkdir -p "${WEB_DIR}"
  cp -R "${tmp}/source/panel/controller/web/dist/." "${WEB_DIR}/"
}

if [[ -z "${AGENT_TOKEN}" ]]; then
  AGENT_TOKEN="$(random_token)"
fi
if [[ -z "${ADMIN_PASSWORD}" ]]; then
  ADMIN_PASSWORD="$(random_token)"
fi
if [[ -z "${OPERATOR_TOKEN}" ]]; then
  OPERATOR_TOKEN="${ADMIN_PASSWORD}"
fi

mkdir -p "${CONFIG_DIR}" "${DATA_DIR}" "${LOG_DIR}" "${WEB_DIR}"
chmod 0750 "${CONFIG_DIR}" "${DATA_DIR}" "${LOG_DIR}" "${WEB_DIR}"

if ! try_local_dist; then
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "${TMP_DIR}"' EXIT
  if ! try_release_download "${TMP_DIR}"; then
    source_build_fallback "${TMP_DIR}"
  fi
fi

ADMIN_PASSWORD_HASH="$(password_hash "${ADMIN_PASSWORD}")"
umask 077
cat >"${ENV_FILE}" <<EOF
LEIKWAN_CONTROLLER_TOKEN=${AGENT_TOKEN}
LEIKWAN_OPERATOR_TOKEN=${OPERATOR_TOKEN}
LEIKWAN_ADMIN_USER=admin
LEIKWAN_ADMIN_PASSWORD_HASH=${ADMIN_PASSWORD_HASH}
LEIKWAN_SESSION_SECRET=$(random_token)
LEIKWAN_STRICT_AUTH=${STRICT_AUTH}
LEIKWAN_LISTEN=${LISTEN}
LEIKWAN_DATA_DIR=${DATA_DIR}
LEIKWAN_WEB_DIR=${WEB_DIR}
EOF
chmod 0600 "${ENV_FILE}"

cat >"${SERVICE_DST}" <<EOF
[Unit]
Description=Leikwan Panel Controller
After=network-online.target
Wants=network-online.target

[Service]
EnvironmentFile=${ENV_FILE}
ExecStart=${BIN_DST} --listen \${LEIKWAN_LISTEN} --db \${LEIKWAN_DATA_DIR}/controller.db --web-dir \${LEIKWAN_WEB_DIR} --strict-auth=\${LEIKWAN_STRICT_AUTH}
Restart=on-failure
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
if ! systemctl enable --now leikwan-controller.service; then
  echo "[FAIL] leikwan-controller.service failed to start." >&2
  systemctl status leikwan-controller --no-pager || true
  journalctl -u leikwan-controller -n 100 --no-pager || true
  exit 1
fi

HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
if [[ -z "${HOST_IP}" ]] && command -v curl >/dev/null 2>&1; then
  HOST_IP="$(curl -fsSL --connect-timeout 3 https://ifconfig.me 2>/dev/null || true)"
fi
if [[ -z "${HOST_IP}" ]]; then
  HOST_IP="127.0.0.1"
fi
PORT="${LISTEN##*:}"
if [[ -z "${PUBLIC_URL}" ]]; then
  PUBLIC_URL="http://${HOST_IP}:${PORT}"
fi

AGENT_CMD="curl -fsSL https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/panel/scripts/install-agent.sh | sudo bash -s -- --controller-url '${PUBLIC_URL}' --token '${AGENT_TOKEN}' --node-name 'relay-1' --role relay --enable-tasks"

cat <<EOF

Leikwan Panel installed.

Web URL:
${PUBLIC_URL}

Login:
username: admin
password: ${ADMIN_PASSWORD}

Operator token:
${OPERATOR_TOKEN}

Agent token:
${AGENT_TOKEN}

Add Agent:
Open Web Panel -> Add Agent

Example Agent install command:
${AGENT_CMD}

Service:
systemctl status leikwan-controller --no-pager
journalctl -u leikwan-controller -n 100 --no-pager

EOF
