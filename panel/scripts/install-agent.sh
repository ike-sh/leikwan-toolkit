#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="3.0.0-alpha.2"
CONTROLLER_URL=""
TOKEN=""
NODE_NAME=""
ROLE="unknown"
ENABLE_TASKS="true"
ENABLE_WRITE_ACTIONS="false"
RELEASE_URL=""
CONFIG_DIR="/etc/leikwan-agent"
CONFIG_FILE="${CONFIG_DIR}/config.yml"
STATE_DIR="/var/lib/leikwan-agent"
BIN_DST="/usr/local/bin/leikwan-agent"
SERVICE_DST="/etc/systemd/system/leikwan-agent.service"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --controller|--controller-url) CONTROLLER_URL="${2:-}"; shift 2 ;;
    --token) TOKEN="${2:-}"; shift 2 ;;
    --name|--node-name) NODE_NAME="${2:-}"; shift 2 ;;
    --role) ROLE="${2:-}"; shift 2 ;;
    --enable-tasks) ENABLE_TASKS="true"; shift ;;
    --disable-tasks) ENABLE_TASKS="false"; shift ;;
    --enable-write-actions) ENABLE_WRITE_ACTIONS="true"; shift ;;
    --version) VERSION="${2:-}"; shift 2 ;;
    --release-url|--install-url) RELEASE_URL="${2:-}"; shift 2 ;;
    *) echo "[FAIL] Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "[FAIL] Please run as root or via sudo." >&2
  exit 1
fi
if [[ -z "${CONTROLLER_URL}" || -z "${TOKEN}" || -z "${NODE_NAME}" ]]; then
  echo "[FAIL] Missing required arguments: --controller-url, --token, --node-name" >&2
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

detect_os_arch() {
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"
  case "${ARCH}" in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
  esac
}

install_deps_for_source_build() {
  command -v go >/dev/null 2>&1 && return 0
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "[FAIL] Source build requires go. Please install it manually." >&2
    return 1
  fi
  echo "[INFO] Installing build dependencies for Agent source build."
  apt-get update
  apt-get install -y ca-certificates curl wget tar gzip golang
}

install_from_dist_dir() {
  local dist="$1"
  if [[ ! -x "${dist}/leikwan-agent" ]]; then
    return 1
  fi
  echo "[INFO] Installing Agent from ${dist}"
  install -m 0755 "${dist}/leikwan-agent" "${BIN_DST}"
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
  if [[ ! -x "${dist}/leikwan-agent" ]]; then
    dist="$(find "${tmp}/extract" -maxdepth 3 -type f -name leikwan-agent -perm -111 -print -quit | xargs -r dirname)"
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
  echo "[INFO] Falling back to Agent source build from GitHub main branch."
  download_file "https://github.com/ike-sh/leikwan-toolkit/archive/refs/heads/main.tar.gz" "${tmp}/source.tar.gz"
  rm -rf "${tmp}/source"
  mkdir -p "${tmp}/source"
  tar -xzf "${tmp}/source.tar.gz" -C "${tmp}/source" --strip-components=1
  if [[ ! -d "${tmp}/source/panel/agent" ]]; then
    echo "[FAIL] Source tarball missing panel/agent" >&2
    return 1
  fi
  (
    cd "${tmp}/source/panel/agent"
    go build -o "${tmp}/leikwan-agent" ./cmd/leikwan-agent
  )
  install -m 0755 "${tmp}/leikwan-agent" "${BIN_DST}"
}

if ! try_local_dist; then
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "${TMP_DIR}"' EXIT
  if ! try_release_download "${TMP_DIR}"; then
    source_build_fallback "${TMP_DIR}"
  fi
fi

mkdir -p "${CONFIG_DIR}" "${STATE_DIR}"
chmod 0750 "${CONFIG_DIR}" "${STATE_DIR}"

INIT_ARGS=(--init-config --config "${CONFIG_FILE}" --controller-url "${CONTROLLER_URL}" --token "${TOKEN}" --node-name "${NODE_NAME}" --role "${ROLE}")
if [[ "${ENABLE_TASKS}" == "true" ]]; then
  INIT_ARGS+=(--enable-tasks)
else
  INIT_ARGS+=(--enable-tasks=false)
fi
if [[ "${ENABLE_WRITE_ACTIONS}" == "true" ]]; then
  INIT_ARGS+=(--enable-write-actions)
fi
"${BIN_DST}" "${INIT_ARGS[@]}"
chmod 0600 "${CONFIG_FILE}"

cat >"${SERVICE_DST}" <<EOF
[Unit]
Description=Leikwan Panel Agent
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=${BIN_DST} --config ${CONFIG_FILE}
Restart=on-failure
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now leikwan-agent.service

if ! "${BIN_DST}" --config "${CONFIG_FILE}" --once; then
  echo "[WARN] initial Agent report failed; service remains installed and will retry." >&2
fi

cat <<EOF

Leikwan Panel Agent installed.

Controller URL: ${CONTROLLER_URL}
Node name: ${NODE_NAME}
Role: ${ROLE}
enable_tasks=${ENABLE_TASKS}
enable_write_actions=${ENABLE_WRITE_ACTIONS}

Status:
systemctl status leikwan-agent --no-pager

Logs:
journalctl -u leikwan-agent -n 100 --no-pager

EOF
