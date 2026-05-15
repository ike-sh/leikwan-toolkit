#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
PACKAGE_VERSION="$(grep -E '^TOOL_VERSION=' "${ROOT_DIR}/leikwan-toolkit.sh" | head -n 1 | cut -d= -f2 | tr -d '"')"
PACKAGE_NAME="leikwan-toolkit-${PACKAGE_VERSION}"
STAGING_DIR="${DIST_DIR}/${PACKAGE_NAME}"
PACKAGE_PATH="${DIST_DIR}/${PACKAGE_NAME}.tar.gz"
SHA_PATH="${PACKAGE_PATH}.sha256"

cd "$ROOT_DIR"

SHELLCHECK_TARGETS=(
  leikwan-toolkit.sh
  scripts/package-release.sh
  scripts/build-release.sh
  scripts/check-redaction.sh
  scripts/bootstrap.sh
)
[[ -f scripts/verify-release.sh ]] && SHELLCHECK_TARGETS+=(scripts/verify-release.sh)
if compgen -G 'tests/*.sh' >/dev/null; then
  while IFS= read -r test_script; do
    SHELLCHECK_TARGETS+=("$test_script")
  done < <(find tests -maxdepth 1 -type f -name '*.sh' | sort)
fi

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "FAIL: shellcheck not found" >&2
  exit 1
fi

shellcheck "${SHELLCHECK_TARGETS[@]}"
bash scripts/check-redaction.sh

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
mkdir -p "$STAGING_DIR"

cp leikwan-toolkit.sh README.md "$STAGING_DIR/"
cp -R docs "$STAGING_DIR/docs"
mkdir -p "$STAGING_DIR/scripts"
cp scripts/package-release.sh scripts/build-release.sh scripts/check-redaction.sh scripts/bootstrap.sh "$STAGING_DIR/scripts/"
[[ -f scripts/verify-release.sh ]] && cp scripts/verify-release.sh "$STAGING_DIR/scripts/"
[[ -d tests ]] && cp -R tests "$STAGING_DIR/tests"

bash scripts/check-redaction.sh

tar -czf "$PACKAGE_PATH" -C "$DIST_DIR" "$PACKAGE_NAME"

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$PACKAGE_PATH" >"$SHA_PATH"
elif command -v shasum >/dev/null 2>&1; then
  shasum -a 256 "$PACKAGE_PATH" >"$SHA_PATH"
else
  echo "FAIL: sha256sum or shasum not found" >&2
  exit 1
fi

echo "Package: ${PACKAGE_PATH}"
echo "SHA256:  ${SHA_PATH}"
echo
echo "安全一键安装："
echo "curl -fsSL -o /tmp/lq-bootstrap.sh https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/scripts/bootstrap.sh"
echo "bash /tmp/lq-bootstrap.sh"
echo
echo "国内推荐安装："
echo "export LEIKWAN_GITHUB_DOWNLOAD_MODE=mirror-first"
echo "export LEIKWAN_GITHUB_MIRRORS=\"https://gh-proxy.com/,https://gh.llkk.cc/,https://gh.ddlc.top/,https://ghproxy.net/,https://mirror.ghproxy.com/,https://cf.ghproxy.cc/,https://gh.api.99988866.xyz/,https://github.akams.cn/\""
echo "curl -fsSL -o /tmp/lq-bootstrap.sh https://gh-proxy.com/https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/scripts/bootstrap.sh"
echo "bash /tmp/lq-bootstrap.sh"
echo
echo "下载到本地再执行："
echo "curl -fsSL -o /root/leikwan-toolkit.sh https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/leikwan-toolkit.sh && chmod +x /root/leikwan-toolkit.sh && ln -sf /root/leikwan-toolkit.sh /usr/local/bin/lq && ln -sf /root/leikwan-toolkit.sh /usr/local/bin/LQ && lq init"
echo
echo "Release 包安装："
echo "curl -fsSL -o /tmp/leikwan-toolkit.tar.gz https://github.com/ike-sh/leikwan-toolkit/releases/latest/download/leikwan-toolkit-${PACKAGE_VERSION}.tar.gz && tar -xzf /tmp/leikwan-toolkit.tar.gz -C /root && cp /root/leikwan-toolkit-${PACKAGE_VERSION}/leikwan-toolkit.sh /root/leikwan-toolkit.sh && chmod +x /root/leikwan-toolkit.sh && ln -sf /root/leikwan-toolkit.sh /usr/local/bin/lq && ln -sf /root/leikwan-toolkit.sh /usr/local/bin/LQ && lq init"
