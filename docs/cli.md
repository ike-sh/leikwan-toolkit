# CLI 参考

1.4.0 LTS 保留旧 CLI 兼容，但 README 首页只展示最常用命令。

## 常用

```bash
lq init
lq status
lq status --verbose
lq --brief
lq --doctor
lq doctor --auto-fix
lq ddns overview
lq forward apply-relay --auto-fix-route
lq update check
```

## 状态与诊断

```bash
lq status
lq status --verbose
lq status --json
lq --status
lq --status-json
lq --brief
lq --compact
lq --doctor
lq doctor --json
lq doctor --auto-fix
lq port check
lq logs
```

## DDNS

```bash
lq ddns overview
lq ddns run --scope all
lq ddns run --scope forwards
lq ddns run --scope entries
lq ddns run --scope pbr
lq ddns apply-entries
lq ddns check-consistency
lq ddns status
lq entry ddns status
lq entry ddns setup
lq entry ddns run
lq entry ddns enable
lq entry ddns disable
lq entry ddns logs
```

## 转发与 PBR

```bash
lq forward add
lq forward list
lq forward apply-relay --auto-fix-route
lq pbr show
lq pbr sync-from-forwards
lq pbr domain add
lq pbr domain list
lq pbr domain sync
```

## 配置、输出、自更新

```bash
lq config export --full
lq config export --redacted
lq config inspect /path/to/pkg.tar.gz
lq config import /path/to/pkg.tar.gz
lq config list
lq output generate
lq output show
lq output json
lq output html
lq output qr
lq update
lq update check
lq update run
lq update status
lq update rollback
lq task status
lq task unlock-stale
```

`lq update` 等价于 `lq update run`，用于直接进入更新到最新版本流程。

`lq task status` 用于查看当前 Leikwan 任务锁持有者；`lq task unlock-stale` 只清理遗留锁，不会删除活进程持有的锁。

## 卸载

```bash
lq uninstall normal
lq uninstall deep
```

普通卸载保留配置和快照；深度卸载删除配置和状态，执行前会二次确认。
