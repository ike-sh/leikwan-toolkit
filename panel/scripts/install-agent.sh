#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="3.0.0-alpha.1"
CONTROLLER_URL=""
TOKEN=""
NODE_NAME=""
ROLE="unknown"
ENABLE_TASKS="true"
ENABLE_WRITE_ACTIONS="false"
TEST_ONCE="0"
INSTALL_URL=""
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
    --test-once) TEST_ONCE="1"; shift ;;
    --version) VERSION="${2:-}"; shift 2 ;;
    --install-url) INSTALL_URL="${2:-}"; shift 2 ;;
    *) echo "[FAIL] Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "[FAIL] Please run as root." >&2
  exit 1
fi
if [[ -z "${CONTROLLER_URL}" || -z "${TOKEN}" || -z "${NODE_NAME}" ]]; then
  echo "[FAIL] Missing required arguments: --controller-url, --token, --node-name" >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PANEL_DIR="$(cd -- "${SCRIPT_DIR}/.." 2>/dev/null && pwd || true)"
LOCAL_BIN="${PANEL_DIR}/dist/leikwan-agent"
if [[ -x "${PANEL_DIR}/leikwan-agent" ]]; then
  LOCAL_BIN="${PANEL_DIR}/leikwan-agent"
fi

if [[ -x "${LOCAL_BIN}" ]]; then
  install -m 0755 "${LOCAL_BIN}" "${BIN_DST}"
else
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "${TMP_DIR}"' EXIT
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"
  case "${ARCH}" in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
  esac
  URL="${INSTALL_URL:-${LEIKWAN_PANEL_DIST_URL:-https://github.com/ike-sh/leikwan-toolkit/releases/download/panel-${VERSION}/leikwan-panel-${VERSION}-${OS}-${ARCH}.tar.gz}}"
  echo "[INFO] Local dist not found; downloading ${URL}"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${URL}" -o "${TMP_DIR}/panel.tar.gz"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "${TMP_DIR}/panel.tar.gz" "${URL}"
  else
    echo "[FAIL] curl or wget is required to download Panel dist." >&2
    exit 1
  fi
  tar -xzf "${TMP_DIR}/panel.tar.gz" -C "${TMP_DIR}"
  if [[ ! -x "${TMP_DIR}/leikwan-agent" ]]; then
    echo "[FAIL] downloaded dist does not contain leikwan-agent" >&2
    echo "[INFO] Please download the Panel release manually and rerun this script from panel/dist/scripts." >&2
    exit 1
  fi
  install -m 0755 "${TMP_DIR}/leikwan-agent" "${BIN_DST}"
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

if [[ "${TEST_ONCE}" == "1" ]]; then
  if ! "${BIN_DST}" --config "${CONFIG_FILE}" --once; then
    echo "[WARN] one-shot Agent report failed; service remains installed and will retry." >&2
  fi
else
  if ! "${BIN_DST}" --config "${CONFIG_FILE}" --once; then
    echo "[WARN] initial Agent report failed; service remains installed and will retry." >&2
  fi
fi

echo "[OK] Leikwan Panel Agent ${VERSION} installed."
echo "[OK] Wrote ${CONFIG_FILE}"
echo "[OK] Started leikwan-agent.service"
echo "[OK] Controller URL: ${CONTROLLER_URL}"
echo "[OK] Node name: ${NODE_NAME}"
echo "[OK] Role: ${ROLE}"
echo "[INFO] enable_tasks=${ENABLE_TASKS}"
echo "[INFO] enable_write_actions=${ENABLE_WRITE_ACTIONS} (alpha/demo; stages Panel-managed config files only)"
echo "[INFO] Service status: systemctl status leikwan-agent.service"
echo "[INFO] Logs: journalctl -u leikwan-agent.service -f"
echo "[INFO] This script does not modify Leikwan Shell Core, nftables, EasyTier, DDNS, entries.tsv, forwards.tsv, or PBR."
