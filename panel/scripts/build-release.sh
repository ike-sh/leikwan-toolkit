#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
if [[ -n "${SCRIPT_SOURCE}" && -f "${SCRIPT_SOURCE}" ]]; then
  ROOT_DIR="$(cd -- "$(dirname -- "${SCRIPT_SOURCE}")/../.." && pwd)"
else
  ROOT_DIR="$(pwd)"
fi
PANEL_DIR="${ROOT_DIR}/panel"
DIST_DIR="${PANEL_DIR}/dist"
PANEL_VERSION="${PANEL_VERSION:-3.0.0-alpha.2}"
CONTROLLER_GOCACHE="${PANEL_DIR}/controller/.gocache"
AGENT_GOCACHE="${PANEL_DIR}/agent/.gocache"

GO_BIN="${GO_BIN:-}"
if [[ -z "${GO_BIN}" ]] && command -v go >/dev/null 2>&1; then
  GO_BIN="$(command -v go)"
fi
if [[ -z "${GO_BIN}" ]]; then
  for candidate in "/c/Program Files/Go/bin/go.exe" "/d/Program Files/Go/bin/go.exe" "/mnt/host/c/Program Files/Go/bin/go.exe" "/mnt/host/d/Program Files/Go/bin/go.exe"; do
    if [[ -x "${candidate}" ]]; then
      GO_BIN="${candidate}"
      break
    fi
  done
fi
if [[ -z "${GO_BIN}" ]]; then
  echo "[FAIL] go not found in PATH" >&2
  exit 1
fi

NPM_BIN="${NPM_BIN:-}"
if [[ -z "${NPM_BIN}" ]] && command -v npm >/dev/null 2>&1; then
  NPM_BIN="$(command -v npm)"
fi
if [[ -z "${NPM_BIN}" ]]; then
  for candidate in "/c/Program Files/nodejs/npm.cmd" "/d/Program Files/nodejs/npm.cmd" "/mnt/host/c/Program Files/nodejs/npm.cmd" "/mnt/host/d/Program Files/nodejs/npm.cmd"; do
    if [[ -x "${candidate}" ]]; then
      NPM_BIN="${candidate}"
      break
    fi
  done
fi
if [[ -z "${NPM_BIN}" ]]; then
  echo "[FAIL] npm not found in PATH" >&2
  exit 1
fi

mkdir -p "${DIST_DIR}" "${CONTROLLER_GOCACHE}" "${AGENT_GOCACHE}"

GOOS_VALUE="${GOOS:-linux}"
GOARCH_VALUE="${GOARCH:-amd64}"
TARBALL="leikwan-panel-${PANEL_VERSION}-${GOOS_VALUE}-${GOARCH_VALUE}.tar.gz"

echo "[INFO] Building controller for ${GOOS_VALUE}/${GOARCH_VALUE}"
(
  cd "${PANEL_DIR}/controller"
  GOCACHE="${GOCACHE:-${CONTROLLER_GOCACHE}}" GOOS="${GOOS_VALUE}" GOARCH="${GOARCH_VALUE}" "${GO_BIN}" build -o "${DIST_DIR}/leikwan-controller" ./cmd/leikwan-controller
)

echo "[INFO] Building agent for ${GOOS_VALUE}/${GOARCH_VALUE}"
(
  cd "${PANEL_DIR}/agent"
  GOCACHE="${GOCACHE:-${AGENT_GOCACHE}}" GOOS="${GOOS_VALUE}" GOARCH="${GOARCH_VALUE}" "${GO_BIN}" build -o "${DIST_DIR}/leikwan-agent" ./cmd/leikwan-agent
)

echo "[INFO] Building web assets"
(
  cd "${PANEL_DIR}/controller"
  "${NPM_BIN}" --prefix web install
  "${NPM_BIN}" --prefix web run build
)

rm -rf "${DIST_DIR}/web" "${DIST_DIR}/examples" "${DIST_DIR}/docs" "${DIST_DIR}/scripts"
mkdir -p "${DIST_DIR}/web" "${DIST_DIR}/examples" "${DIST_DIR}/docs" "${DIST_DIR}/scripts"
cp -R "${PANEL_DIR}/controller/web/dist/." "${DIST_DIR}/web/"
cp -R "${PANEL_DIR}/examples/." "${DIST_DIR}/examples/"
cp -R "${PANEL_DIR}/docs/." "${DIST_DIR}/docs/"
install -m 0755 "${PANEL_DIR}/scripts/install-controller.sh" "${DIST_DIR}/scripts/install-controller.sh"
install -m 0755 "${PANEL_DIR}/scripts/install-agent.sh" "${DIST_DIR}/scripts/install-agent.sh"
printf 'LEIKWAN_PANEL_VERSION=%s\n' "${PANEL_VERSION}" >"${DIST_DIR}/VERSION"

rm -f "${DIST_DIR}"/*.tar.gz "${DIST_DIR}/SHA256SUMS"
echo "[INFO] Creating ${TARBALL}"
(
  cd "${DIST_DIR}"
  tar -czf "${TARBALL}" leikwan-controller leikwan-agent web docs examples scripts VERSION
)

echo "[INFO] Writing SHA256SUMS"
(
  cd "${DIST_DIR}"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

echo "[OK] Panel release files written to ${DIST_DIR}"
echo "[OK] GitHub Release asset to upload: ${DIST_DIR}/${TARBALL}"
echo "[OK] Suggested release tags: v${PANEL_VERSION} or panel-${PANEL_VERSION}"
