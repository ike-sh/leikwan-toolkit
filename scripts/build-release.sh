#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${VERSION:-${1:-}}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(awk -F= '$1=="TOOL_VERSION" {gsub(/"/, "", $2); print $2; exit}' leikwan-toolkit.sh)"
fi
if [[ -z "$VERSION" ]]; then
  echo "[FAIL] 无法读取 TOOL_VERSION，也未提供 VERSION。" >&2
  exit 1
fi

PACKAGE_NAME="leikwan-toolkit-${VERSION}"
DIST_DIR="${ROOT_DIR}/dist"
WORK_PARENT="${ROOT_DIR}/.tmp"
STAGE_DIR="${WORK_PARENT}/${PACKAGE_NAME}"
PACKAGE_PATH="${DIST_DIR}/${PACKAGE_NAME}.tar.gz"
SHA_PATH="${PACKAGE_PATH}.sha256"

mkdir -p "$WORK_PARENT" "$DIST_DIR"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

cp README.md leikwan-toolkit.sh "$STAGE_DIR/"
[[ -f LICENSE ]] && cp LICENSE "$STAGE_DIR/"
[[ -d scripts ]] && cp -R scripts "$STAGE_DIR/scripts"
[[ -d docs ]] && cp -R docs "$STAGE_DIR/docs"
[[ -d tests ]] && cp -R tests "$STAGE_DIR/tests"

find "$STAGE_DIR" \( \
  -path '*/panel' -o -path '*/panel/*' -o \
  -path '*/controller' -o -path '*/controller/*' -o \
  -path '*/agent' -o -path '*/agent/*' -o \
  -path '*/web' -o -path '*/web/*' -o \
  -path '*/edge-tunnel-panel' -o -path '*/edge-tunnel-panel/*' \
\) -exec rm -rf {} + 2>/dev/null || true

rm -f "$PACKAGE_PATH" "$SHA_PATH"
tar -czf "$PACKAGE_PATH" -C "$WORK_PARENT" "$PACKAGE_NAME"

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$PACKAGE_PATH" >"$SHA_PATH"
elif command -v shasum >/dev/null 2>&1; then
  shasum -a 256 "$PACKAGE_PATH" >"$SHA_PATH"
else
  echo "[FAIL] sha256sum 或 shasum 不存在，无法生成校验文件。" >&2
  exit 1
fi

echo "[OK] Release package: ${PACKAGE_PATH}"
echo "[OK] SHA256:"
cat "$SHA_PATH"
