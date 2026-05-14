# 工作流

本文说明 Leikwan Toolkit 1.4.1 的推荐操作顺序。

## 角色

- A：公网入口，可部署多台，用于接入公网流量。
- B：利群主机 / 中转主机，负责 EasyTier relay、PBR 和后端转发。
- C：后端目标，支持 TCP/UDP 转发。

链路：

```text
外部客户端 -> A 公网入口端口（TCP/UDP） -> EasyTier -> B 利群主机 -> 后端目标
```

## 快速组网

首次部署建议先运行初始化向导：

```bash
lq init
```

向导会先选择角色：B 利群主机、A 公网入口、从配置包恢复或仅检查状态。只想预览计划时使用：

```bash
lq init --dry-run
lq plan
```

推荐顺序：

1. B：初始化利群主机。
2. B：生成公网入口接入码。
3. A：粘贴接入码部署入口。
4. B：粘贴 A 返回码完成接入。
5. B：添加后端转发目标。
6. B：生成转发端点输出。

如果后端需要指定出口，先配置 PBR，再添加或重应用转发目标。

## 多公网入口

新入口默认命名：

```text
public1 -> 公网1
public2 -> 公网2
public3 -> 公网3
```

连续生成多个入口码时，脚本会写入 pending reservation，后续推荐会同时排除已保存入口和 pending 入口，因此会依次推荐 `public1 10.198.1.2 tcp+udp/8301`、`public2 10.198.1.3 tcp+udp/8302`、`public3 10.198.1.4 tcp+udp/8303`。

连接码输出后需要输入 `y` 确认返回菜单；输入 `r` 可重新显示单行码，输入 `p` 可显示保存路径，直接回车不会返回菜单。

A 的 ENTRY 返回码接回 B 后，会按 `ENTRY_ET_IP + EASYTIER_PORT` 清理对应 pending。ENTRY 名称和 pending 名称不同也允许保存。

## 终端显示

窄 SSH 终端会自动切换为紧凑列表，避免中英文混排表格错位。可用 `LEIKWAN_COMPACT=1 lq` 强制紧凑列表，用 `LEIKWAN_NO_CLEAR=1 lq` 禁用清屏；调试宽表时可尝试 `LEIKWAN_TABLE=1 lq`。只想看最短巡检结果时使用 `lq --brief` 或 `LEIKWAN_BRIEF=1 lq status`。

## 公网入口管理

菜单路径：

```text
利群主机 B -> 公网入口管理
```

可执行：

- 生成新公网入口接入码
- 粘贴公网入口返回码并接入
- 手动添加公网入口
- 修改公网入口详情
- 删除公网入口
- 启用 / 禁用公网入口
- 修改权重
- 切换主公网入口
- 批量启用 / 禁用公网入口
- 查看 / 清理未完成接入码

入口变更后默认不会静默重启 relay。脚本会提示是否现在重启，选择 `N` 时运行中的 relay peer 不会改变。

## 端口

- EasyTier 组网端口：默认 `8301`、`8302`、`8303`，TCP+UDP，同端口，建议位于 `8000-9000`。
- 业务入口端口：常用 `10001-19999`，默认 TCP+UDP 转发。
- 后端目标端口：由用户填写。

新增公网入口前会检查 EasyTier 端口是否已被 `entries.tsv`、`pending-entries.tsv`、本机监听进程或 nftables dport 占用。新增转发目标前会检查业务入口端口是否已被 `forwards.tsv`、本机监听进程或 nftables DNAT 占用。推荐端口会自动跳过这些冲突。

可随时执行轻量端口预检：

```bash
lq port check
lq --port-check
```

端口预检只读，不修改系统。

## 状态总览

日常查看建议使用：

```bash
lq status
lq --status
```

`status` 输出角色、版本、入口数量、转发数量、nftables、MSS clamp、最近应用和最近诊断，适合快速确认状态。它只做轻量检查，不执行 ping、nc 或 apt update，也不会自动修改系统。

`status` 会显示系统健康度 `0-100`。角色识别不会把 B relay 的 `entries.tsv` 误判为 entry；只有真实 relay + entry 信号同时存在才会 WARN。

`doctor` 适合排障，会做更完整的链路、DNAT、MSS、依赖和 DNS 检查；交互菜单中可按提示执行修复。`lq doctor --auto-fix` 可自动修复常见安全问题，修复后会重新运行 doctor。

常用维护操作已经收敛到主菜单的“状态 / 诊断”和“高级维护”。日常巡检走“状态 / 诊断”，低频或高危操作走“高级维护”。

## 脚本更新

检查 GitHub Release 最新版本：

```bash
lq update check
```

更新到最新正式 release：

```bash
lq update run
```

更新只替换 `/root/leikwan-toolkit.sh`，不会删除 `/etc/leikwan-toolkit` 配置。更新失败会保留旧脚本，替换后版本校验失败会自动恢复备份。

## 配置快照 / 回滚

菜单路径：

```text
高级维护 -> 配置备份 / 快照 / 回滚
```

可创建完整快照、查看列表、按编号恢复、删除旧快照，以及导出最新快照到 `/root/leikwan-snapshot-YYYYMMDD-HHMMSS.tar.gz`。

快照可能包含 EasyTier network secret，请按敏感文件保存。恢复快照前会二次确认，恢复后会询问是否立即 reload systemd 并重启相关服务。

高危操作前会自动创建轻量快照，包括重启 relay、重新应用 nftables 转发规则、删除公网入口、批量禁用公网入口、删除转发目标、删除 PBR 规则、深度卸载和恢复快照前。自动快照保存在 `/etc/leikwan-toolkit/snapshots/auto/`，只保留最近 10 个。

## 配置导入 / 导出

迁移到新机器或排错前，可以导出配置包：

```bash
lq config export --full
lq config export --redacted
lq config inspect /root/leikwan-config-YYYYMMDD-HHMMSS.tar.gz
```

完整配置包包含 EasyTier network secret，可用于迁移恢复；脱敏配置包把 secret、配对码 base64、token/password 类字段替换为 `REDACTED`，适合排错但不能完整恢复运行。

导入配置包：

```bash
lq config import /root/leikwan-config-YYYYMMDD-HHMMSS.tar.gz
```

导入前会校验 sha256 和 manifest，并自动创建 `auto-before-config-import-*` 快照。交互模式可选择 config-only、apply 或 full。非交互 full import 需要显式添加 `--yes`。

## PBR

如果需要 CN2、9929 或其它指定出口：

1. 先配置 PBR。
2. 再添加转发目标。

如果先添加了转发目标，后添加 PBR，请执行：

```bash
lq forward apply-relay --auto-fix-route
```

从现有转发目标添加 PBR 后，脚本会默认询问是否立即执行上述同步。

域名型 PBR 使用独立菜单：

```bash
lq pbr domain add
lq pbr domain sync
```

域名 PBR 会生成 `pbr-domain:<name>` 来源规则。脚本只自动管理 `forward:<name>` 和 `pbr-domain:<name>`，不会自动删除用户手写 `static` 规则。

## DDNS 后端 / 公网入口 / PBR 自动刷新

如果后端目标、公网入口 `public_host` 或域名 PBR 使用动态域名，建议在配置稳定后启用域名解析变化检测：

```bash
lq ddns enable
lq ddns status
lq ddns run
lq ddns overview
lq ddns check-consistency
```

常用 scope：

```bash
lq ddns run --scope forwards
lq ddns run --scope entries
lq ddns run --scope pbr
```

脚本会定期检查 enabled 转发目标中的域名后端、公网入口域名和域名 PBR。后端变化时更新 `resolved.tsv`、创建自动快照并安全重应用 nftables；PBR 变化时同步 `/32` 规则并应用 PBR；解析失败时保留旧 IP。

公网入口域名变化默认不会自动重启 relay，只会记录 `relay restart needed`。维护窗口内执行 `lq ddns apply-entries` 可交互确认重启。原因是 relay 重启会短暂中断所有入口，而 EasyTier 运行中又不一定重新解析 peer 域名。确认可以接受维护窗口自动重启时，可设置：

```text
DDNS_AUTO_RESTART_RELAY=true
```

默认不需要 Toolkit 更新 DNS 服务商记录。你的域名可以由路由器、服务商客户端、Cloudflare 或外部脚本维护；Toolkit 只检测解析变化并刷新本地配置。确实需要 Toolkit 主动改 DNS 时，才在高级兼容路径启用 `DDNS_UPDATE_DNS_RECORD=true` 并配置旧 `entry ddns`。

```bash
lq ddns status
lq ddns logs
```

forward 来源 PBR 可手动同步：

```bash
lq pbr sync-from-forwards
```

域名 PBR 可手动同步：

```bash
lq pbr domain sync
```

## 转发端点输出

生成转发端点分享文件：

```bash
lq output generate
lq output json
lq output html
```

输出会生成 TXT、TSV、JSON 和静态 HTML，包含 PRIMARY / BACKUP、TCP / UDP endpoint、enabled entries 和 enabled forwards。端点输出不包含 EasyTier secret，不等于代理链接。

如果安装了 `qrencode`，可选生成二维码：

```bash
lq output qr
```

## 诊断

A 和 B 都可以执行：

```bash
lq --doctor
```

doctor 会检查 EasyTier、nftables、PBR、TCP/UDP DNAT、MSS clamp、入口 TCP/UDP 探测、后端目标探测、entry DDNS 缓存和域名 PBR 同步状态。UDP 探测只作为参考，最终应结合 EasyTier peer / ping 和业务实测判断。
