#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TARGETS=(leikwan-toolkit.sh scripts/bootstrap.sh scripts/package-release.sh scripts/build-release.sh README.md docs)
[[ -f scripts/verify-release.sh ]] && TARGETS+=(scripts/verify-release.sh)
[[ -d tests ]] && TARGETS+=(tests)
TOOL_VERSION="$(awk -F= '$1=="TOOL_VERSION" {gsub(/"/, "", $2); print $2; exit}' leikwan-toolkit.sh 2>/dev/null || true)"
if [[ -n "$TOOL_VERSION" && -d "dist/leikwan-toolkit-${TOOL_VERSION}" ]]; then
  TARGETS+=(
    "dist/leikwan-toolkit-${TOOL_VERSION}/leikwan-toolkit.sh"
    "dist/leikwan-toolkit-${TOOL_VERSION}/scripts/bootstrap.sh"
    "dist/leikwan-toolkit-${TOOL_VERSION}/scripts/package-release.sh"
    "dist/leikwan-toolkit-${TOOL_VERSION}/scripts/build-release.sh"
    "dist/leikwan-toolkit-${TOOL_VERSION}/README.md"
    "dist/leikwan-toolkit-${TOOL_VERSION}/docs"
  )
  [[ -f "dist/leikwan-toolkit-${TOOL_VERSION}/scripts/verify-release.sh" ]] && TARGETS+=("dist/leikwan-toolkit-${TOOL_VERSION}/scripts/verify-release.sh")
  [[ -d "dist/leikwan-toolkit-${TOOL_VERSION}/tests" ]] && TARGETS+=("dist/leikwan-toolkit-${TOOL_VERSION}/tests")
fi

FAILED=0

deny_patterns=(
  '8\.163\.46\.205'
  '216\.45\.59\.72'
  '223\.167\.121\.166'
  '33nZX4gm'
  'U3KiUq6I'
  'T4Nwx0To'
  'b6f1ca1c'
  'a58f5425'
  '(vless|vmess|trojan|ss|hysteria)://'
  'PrivateKey[[:space:]]*=[[:space:]]*[A-Za-z0-9+/]{40,}={0,2}'
  'EASYTIER_NETWORK_SECRET=[A-Za-z0-9][A-Za-z0-9._-]{8,}'
  'REALITY_PRIVATE_KEY[[:space:]]*='
  'X25519.*private[[:space:]_-]*key'
  '(^|[^A-Za-z0-9_])([Pp]assword|[Tt]oken|[Ss]ecret)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9][A-Za-z0-9._/-]{8,}'
  'LEIKWAN_[A-Z0-9_]*_BASE64=[A-Za-z0-9+/]{24,}={0,2}'
)

for pattern in "${deny_patterns[@]}"; do
  if grep -RInE -- "$pattern" "${TARGETS[@]}"; then
    echo "FAIL: redaction pattern matched: ${pattern}" >&2
    FAILED=1
  fi
done

is_allowed_ip() {
  local ip="$1"
  local o1 o2 o3 o4
  case "$ip" in
    1.1.1.1|8.8.8.8|8.8.4.4|9.9.9.9|223.5.5.5|119.29.29.29) return 0 ;;
  esac
  IFS=. read -r o1 o2 o3 o4 <<<"$ip"

  (( o1 == 0 )) && return 0
  (( o1 == 10 )) && return 0
  (( o1 == 127 )) && return 0
  (( o1 == 169 && o2 == 254 )) && return 0
  (( o1 == 172 && o2 >= 16 && o2 <= 31 )) && return 0
  (( o1 == 192 && o2 == 168 )) && return 0
  (( o1 == 192 && o2 == 0 && o3 == 2 )) && return 0
  (( o1 == 198 && o2 == 51 && o3 == 100 )) && return 0
  (( o1 == 203 && o2 == 0 && o3 == 113 )) && return 0
  (( o1 == 100 && o2 >= 64 && o2 <= 127 )) && return 0
  (( o1 >= 224 )) && return 0
  (( o1 == 255 && o2 == 255 && o3 == 255 && o4 == 255 )) && return 0

  return 1
}

while IFS=: read -r file line ip; do
  [[ -n "$ip" ]] || continue
  if ! is_allowed_ip "$ip"; then
    echo "FAIL: possible real public IPv4 in ${file}:${line}: ${ip}" >&2
    FAILED=1
  fi
done < <(grep -RInEo -- '([0-9]{1,3}\.){3}[0-9]{1,3}' "${TARGETS[@]}" || true)

if (( FAILED != 0 )); then
  exit 1
fi

echo "redaction check passed"
