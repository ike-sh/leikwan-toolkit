#!/usr/bin/env bash
# shellcheck disable=SC2034
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=/dev/null
source "$ROOT_DIR/tests/test-lib.sh"

TMP_DIR="$(test_mktemp_dir "$ROOT_DIR")"
trap 'rm -rf "$TMP_DIR"' EXIT

installed_script="${TMP_DIR}/leikwan-toolkit.sh"
shortcut_lq="${TMP_DIR}/lq"
shortcut_lq_upper="${TMP_DIR}/LQ"

cat >"$installed_script" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  --version|-v) echo "leikwan-toolkit 1.4.0 LTS" ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$installed_script"
cat >"$shortcut_lq" <<EOF
#!/usr/bin/env bash
exec bash '${installed_script}' "\$@"
EOF
chmod +x "$shortcut_lq"
ln -s "$installed_script" "$shortcut_lq_upper" 2>/dev/null || true

export LEIKWAN_STATE_DIR="${TMP_DIR}/state"
export LEIKWAN_BACKUP_DIR="${TMP_DIR}/backups"
export LEIKWAN_RUN_DIR="${TMP_DIR}/run"
export LEIKWAN_UPDATE_TARGET_SCRIPT="$installed_script"
export LEIKWAN_LOG_DISABLED=1
export LEIKWAN_NO_CLEAR=1
mkdir -p "$LEIKWAN_RUN_DIR" "${LEIKWAN_STATE_DIR}/status"

# shellcheck source=/dev/null
source "$ROOT_DIR/leikwan-toolkit.sh"

TOOL_VERSION="1.3.5"
SHORTCUT_LQ="$shortcut_lq"
SHORTCUT_LQ_UPPER="$shortcut_lq_upper"

update_latest_release() {
  printf 'v1.4.0\t1.4.0\n'
}

cat >"$UPDATE_STATUS_FILE" <<EOF
LAST_UPDATE_TIME=2026-05-11 16:30:00
LAST_UPDATE_FROM=1.3.5
LAST_UPDATE_TO=1.4.0
LAST_UPDATE_RESULT=ok
LAST_UPDATE_BACKUP=${TMP_DIR}/backup.sh
LAST_UPDATE_SOURCE=https://github.com/ike-sh/leikwan-toolkit/releases/download/v1.4.0/leikwan-toolkit-1.4.0.tar.gz
LAST_UPDATE_VERSION=1.4.0
EOF

check_out="$(update_check 2>&1)"
grep -q "当前安装版本�?.4.0" <<<"$check_out"
grep -q "当前运行进程�?.3.5" <<<"$check_out"
grep -q "最新版本：1.4.0" <<<"$check_out"
grep -q "当前已是最新版本：1.4.0" <<<"$check_out"
grep -q "当前运行进程版本与已安装脚本版本不一�? <<<"$check_out"
if grep -q "可执行：lq update run" <<<"$check_out"; then
  echo "FAIL: update check treated old running process as installed version" >&2
  echo "$check_out" >&2
  exit 1
fi

status_out="$(update_status 2>&1)"
grep -q "当前运行版本: 1.3.5" <<<"$status_out"
grep -q "当前安装版本: 1.4.0" <<<"$status_out"
grep -q "快捷命令: ${shortcut_lq} -> ${installed_script}" <<<"$status_out"
grep -q "最近更�? 1.3.5 -> 1.4.0 / OK" <<<"$status_out"
grep -q "建议重新进入菜单：lq" <<<"$status_out"

export LEIKWAN_DISABLE_UPDATE_EXEC=1
UPDATE_RELOAD_AFTER_ACTION=1
reload_out="$(update_maybe_reload_after_change 1.4.0 update 2>&1)"
grep -q "当前菜单进程仍是旧版本，正在重新载入新版�? <<<"$reload_out"
grep -q "已跳过自�?exec" <<<"$reload_out"

rollback_out="$(update_maybe_reload_after_change 1.4.0 rollback 2>&1)"
grep -q "当前菜单进程仍是回滚前版本，正在重新载入" <<<"$rollback_out"

UPDATE_RELOAD_AFTER_ACTION=0
non_menu_out="$(update_maybe_reload_after_change 1.4.0 update 2>&1)"
grep -q "请重新执�?lq 使用新版�? <<<"$non_menu_out"

echo "[OK] update regression passed"
