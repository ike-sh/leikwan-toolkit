#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "${TMPDIR:-}" || ! -w "${TMPDIR:-}" ]]; then
  mkdir -p "$ROOT_DIR/.tmp"
  export TMPDIR="$ROOT_DIR/.tmp"
fi

section() {
  echo
  echo "==> $*"
}

section "bash syntax"
bash -n leikwan-toolkit.sh scripts/package-release.sh scripts/build-release.sh scripts/check-redaction.sh scripts/bootstrap.sh

section "shellcheck"
shellcheck leikwan-toolkit.sh scripts/package-release.sh scripts/build-release.sh scripts/check-redaction.sh scripts/bootstrap.sh

section "git diff --check"
git diff --check

section "redaction check"
bash scripts/check-redaction.sh

section "smoke tests"
bash tests/smoke.sh

section "cli regression"
bash tests/cli-regression.sh

section "render regression"
bash tests/render-regression.sh

section "final menu regression"
bash tests/final-menu-regression.sh

section "final README regression"
bash tests/final-readme-regression.sh

section "entry port pool message regression"
bash tests/entry-port-pool-message-regression.sh

section "PBR forward domain resolution regression"
bash tests/pbr-forward-domain-resolution-regression.sh

section "PBR apply forward majority regression"
bash tests/pbr-apply-forward-majority-regression.sh

section "doctor forward/PBR DNS split regression"
bash tests/doctor-forward-pbr-dns-split-regression.sh

section "forward route_table sync regression"
bash tests/forward-route-table-sync-regression.sh

section "forward domain resolution regression"
bash tests/forward-domain-resolution-regression.sh

section "domain PBR message regression"
bash tests/domain-pbr-message-regression.sh

section "system network menu regression"
bash tests/system-network-menu-regression.sh

section "quickstart network prepare regression"
bash tests/quickstart-network-prepare-regression.sh

section "IPv4 prefer regression"
bash tests/ipv4-prefer-regression.sh

section "DNS config regression"
bash tests/dns-config-regression.sh

section "doctor system DNS regression"
bash tests/doctor-system-dns-regression.sh

section "IPv6 disable / restore regression"
bash tests/ipv6-disable-restore-regression.sh

section "IPv6 nft lockdown regression"
bash tests/ipv6-nft-lockdown-regression.sh

section "system network CLI regression"
bash tests/system-network-cli-regression.sh

section "role detection regression"
bash tests/role-detection-regression.sh

section "doctor reset regression"
bash tests/doctor-reset-regression.sh

section "compact output regression"
bash tests/compact-output-regression.sh

section "ddns summary regression"
bash tests/ddns-summary-regression.sh

section "entry ddns regression"
bash tests/entry-ddns-regression.sh

section "ddns menu regression"
bash tests/ddns-menu-regression.sh

section "ddns overview regression"
bash tests/ddns-overview-regression.sh

section "ddns consistency regression"
bash tests/ddns-consistency-regression.sh

section "health score regression"
bash tests/health-score-regression.sh

section "update regression"
bash tests/update-regression.sh

section "latest version regression"
bash tests/update-latest-version-regression.sh

section "latest no risky download regression"
bash tests/update-latest-no-risky-download-regression.sh

section "empty latest guard regression"
bash tests/update-empty-latest-guard-regression.sh

section "package regression"
bash tests/package-regression.sh

section "GitHub mirror download regression"
bash tests/github-mirror-download-regression.sh

section "EasyTier mirror download regression"
bash tests/easytier-download-mirror-regression.sh

section "bootstrap mirror-first regression"
bash tests/bootstrap-mirror-first-regression.sh

section "tmpdir fallback regression"
bash tests/tmpdir-fallback-regression.sh

section "uninstall regression"
bash tests/uninstall-regression.sh

section "lock regression"
bash tests/lock-regression.sh

section "redaction regression"
bash tests/redaction-regression.sh

section "release package"
bash scripts/package-release.sh

echo
echo "[OK] release verification passed"
