#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="3.0.0-alpha.1"
LISTEN="0.0.0.0:18080"
DATA_DIR="/var/lib/leikwan-panel"
CONFIG_DIR="/etc/leikwan-panel"
ENV_FILE="${CONFIG_DIR}/controller.env"
BIN_DST="/usr/local/bin/leikwan-controller"
SERVICE_DST="/etc/systemd/system/leikwan-controller.service"
AGENT_TOKEN=""
OPERATOR_TOKEN=""
STRICT_AUTH="false"
PUBLIC_URL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="${2:-}"; shift 2 ;;
    --listen) LISTEN="${2:-}"; shift 2 ;;
    --data-dir) DATA_DIR="${2:-}"; shift 2 ;;
    --agent-token) AGENT_TOKEN="${2:-}"; shift 2 ;;
    --operator-token) OPERATOR_TOKEN="${2:-}"; shift 2 ;;
    --strict-auth) STRICT_AUTH="true"; shift ;;
    --public-url) PUBLIC_URL="${2:-}"; shift 2 ;;
    *) echo "[FAIL] Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "[FAIL] Please run as root." >&2
  exit 1
fi

random_token() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'
  fi
}

if [[ -z "${AGENT_TOKEN}" ]]; then
  AGENT_TOKEN="$(random_token)"
fi
if [[ -z "${OPERATOR_TOKEN}" ]]; then
  OPERATOR_TOKEN="$(random_token)"
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PANEL_DIR="$(cd -- "${SCRIPT_DIR}/.." 2>/dev/null && pwd || true)"
LOCAL_BIN="${PANEL_DIR}/dist/leikwan-controller"
if [[ -x "${PANEL_DIR}/leikwan-controller" ]]; then
  LOCAL_BIN="${PANEL_DIR}/leikwan-controller"
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
  URL="${LEIKWAN_PANEL_DIST_URL:-https://github.com/ike-sh/leikwan-toolkit/releases/download/panel-${VERSION}/leikwan-panel-${VERSION}-${OS}-${ARCH}.tar.gz}"
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
  if [[ ! -x "${TMP_DIR}/leikwan-controller" ]]; then
    echo "[FAIL] downloaded dist does not contain leikwan-controller" >&2
    exit 1
  fi
  install -m 0755 "${TMP_DIR}/leikwan-controller" "${BIN_DST}"
fi

mkdir -p "${CONFIG_DIR}" "${DATA_DIR}"
chmod 0750 "${CONFIG_DIR}" "${DATA_DIR}"
umask 077
cat >"${ENV_FILE}" <<EOF
LEIKWAN_CONTROLLER_TOKEN=${AGENT_TOKEN}
LEIKWAN_OPERATOR_TOKEN=${OPERATOR_TOKEN}
LEIKWAN_STRICT_AUTH=${STRICT_AUTH}
LEIKWAN_PANEL_LISTEN=${LISTEN}
LEIKWAN_PANEL_DB=${DATA_DIR}/controller.db
EOF
chmod 0600 "${ENV_FILE}"

cat >"${SERVICE_DST}" <<EOF
[Unit]
Description=Leikwan Panel Controller
After=network-online.target
Wants=network-online.target

[Service]
EnvironmentFile=${ENV_FILE}
ExecStart=${BIN_DST} --listen \${LEIKWAN_PANEL_LISTEN} --db \${LEIKWAN_PANEL_DB} --strict-auth=\${LEIKWAN_STRICT_AUTH}
Restart=on-failure
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now leikwan-controller.service

HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
if [[ -z "${HOST_IP}" ]]; then
  HOST_IP="127.0.0.1"
fi
PORT="${LISTEN##*:}"
if [[ -z "${PUBLIC_URL}" ]]; then
  PUBLIC_URL="http://${HOST_IP}:${PORT}"
fi
AGENT_CMD="curl -fsSL https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/panel/scripts/install-agent.sh | sudo bash -s -- --controller-url '${PUBLIC_URL}' --token '${AGENT_TOKEN}' --node-name 'relay-1' --role relay --enable-tasks"

echo "[OK] Leikwan Panel Controller ${VERSION} installed."
echo "[OK] Web URL: ${PUBLIC_URL}"
echo "[OK] Operator token: ${OPERATOR_TOKEN}"
echo "[OK] Agent token: ${AGENT_TOKEN}"
echo "[OK] Add Agent page: ${PUBLIC_URL}/bootstrap"
echo "[INFO] Example Agent install command:"
echo "${AGENT_CMD}"
echo "[INFO] Open the Web UI, unlock with the Operator token, then use Bootstrap / Add Agent to copy a role-specific install command."
echo "[INFO] This script does not install Agent and does not modify Leikwan Shell Core."
