# 安全边界

本页汇总 Leikwan Toolkit 1.4.0 LTS 的敏感信息和高危操作边界。LTS 功能冻结后，后续重点是 bug fix、兼容性修复、安全修复和文档完善。

## 敏感内容

以下内容应按敏感文件保存：

- EasyTier network secret
- 配对码中的 base64 内容
- 完整配置快照
- full config export 包

不要把这些内容公开到 issue、聊天记录或仓库。

## 配置包

完整配置包：

```bash
lq config export --full
```

用于迁移和恢复运行，包含 EasyTier network secret。导出时会明确警告，并生成外部 `.sha256` 与包内 `checksums.sha256`。

脱敏配置包：

```bash
lq config export --redacted
```

用于排错和提交 issue。脚本会把 EasyTier secret、配对码 base64、token、password、secret 类字段替换为 `REDACTED`。脱敏包不能用于完整恢复运行。

导入配置包前，脚本会：

- 校验外部 `.sha256`
- 校验包内 `checksums.sha256`
- 校验 manifest
- 拒绝路径穿越、绝对路径、symlink 和 hardlink 包成员
- 自动创建 `auto-before-config-import-*` 快照
- 对 full import 非交互模式要求 `--yes`

## debug report

debug report 会包含状态文件、配置摘要、端点输出摘要和日志尾部，不会打包完整 config export 包。日志只保留尾部片段，DDNS 日志最多 tail 100 行，其它日志最多按功能导出尾部片段。

生成后仍建议人工快速检查再发送。

## 端点输出

```bash
lq output generate
```

端点输出只包含公网入口、业务端口、PRIMARY / BACKUP、TCP / UDP endpoint 和后端摘要，不包含 EasyTier secret、配对码、token 或 password。

HTML 输出会转义用户输入字段。QR 输出只包含 `tcp://host:port` 或 `udp://host:port` endpoint 字符串，不是代理链接。

## 自更新

自更新只使用 GitHub Release 包：

```bash
lq update check
lq update run
```

更新流程会下载 `.tar.gz` 和 `.sha256`，校验通过并确认新脚本语法和版本后才替换当前脚本。失败时保留旧脚本，必要时可执行：

```bash
lq update rollback
```

## 高危操作快照

删除公网入口、删除转发目标、删除 PBR、重新应用转发规则、恢复快照、配置导入、卸载等操作前会自动创建快照。自动快照保存在：

```text
/etc/leikwan-toolkit/snapshots/auto/
```

默认只保留最近 10 个。

深度卸载会额外创建 `/root/final-before-uninstall-YYYYMMDD-HHMMSS.tar.gz`。如果 final snapshot 失败，默认不继续深度卸载。

## 并发锁

高危写操作会使用锁避免并发写配置或规则：

```text
/run/leikwan-toolkit.lock
/run/leikwan-ddns-refresh.lock
/run/leikwan-update.lock
/run/leikwan-config.lock
```

如果已有任务运行，脚本会提示稍后再试。systemd timer 模式下 DDNS 遇到锁占用会跳过本次运行，不视为失败。若检测到 PID 已不存在的 stale lock，下次获取锁时会清理并提示。

## JSON 输出

```bash
lq status --json
lq doctor --json
```

JSON 只输出状态摘要、计数、健康度评分和 WARN / FAIL 概要，不包含 EasyTier network secret、配对码 base64、token 或 password。

## 角色保护

1.4.0 起，脚本会根据真正的角色信号做检测：relay service 或 `ROLE=leikwan-relay` 表示 B 角色；entry service、`ROLE=cloud-entry` 或 entry env 表示 A 角色。`entries.tsv` 不再作为 entry 判据，`forwards.tsv` 也不能单独决定角色。B 菜单在 A 机器执行高危操作、A 菜单在 B 机器执行高危操作时会先提示角色不匹配，交互模式默认不继续。

## 兼容 DNS 更新凭据

默认全局 IP 变化检测不会保存 DNS provider token。只有显式启用 `DDNS_UPDATE_DNS_RECORD=true` 并使用兼容入口时，`lq entry ddns setup` 才可能保存 DNS 服务商 token、custom URL 或 custom command 到：

```text
/etc/leikwan-toolkit/entry/ddns.env
```

普通 `status`、JSON、debug report、redacted config export 不会明文输出这些字段。debug report 和 redacted export 会脱敏：

- `token`
- `secret`
- `password`
- `key`
- custom-url query
- `ENTRY_DDNS_UPDATE_CMD`

完整配置包会包含 `/etc/leikwan-toolkit/entry/ddns.env` 和最近的 `last-entry-ddns.env`，仍可能包含这些信息，只适合自己迁移恢复，不能公开分享。

如果同时检测到真实 relay 和 entry 信号，`lq status` 会提示“高级混合部署：relay + entry”。高级部署可以继续操作，但普通部署建议先执行 `lq --doctor` 确认。

## doctor 自动修复边界

`lq doctor --auto-fix` 只自动处理 nftables / MSS clamp、route table metadata、relay service、DDNS timer、快捷命令、权限和 stale lock。它不会删除 entries / forwards / PBR，也不会重置 EasyTier network secret。
