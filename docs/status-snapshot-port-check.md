# 状态、快照与端口预检

本文记录状态总览、快照 / 回滚、端口预检，以及 1.4.1 的 DDNS / IP 变化检测状态集成。

## 状态总览

```bash
lq status
lq --status
lq status --json
lq --status-json
```

`status` 用于日常快速查看，只读取 `/etc/leikwan-toolkit/` 下的配置文件、systemd 状态和 nftables 项目表。它不会执行 ping、nc、apt update，也不会自动修改系统。

`doctor` 用于详细排障，会检查更多链路细节，并在交互菜单中提供部分修复入口。

1.4.0 起，状态总览会显示角色来源、运行中任务、锁状态、最近错误、系统健康度和下一步建议。例如 `network.env + easytier-relay.service`、`entry service`，或真实 relay + entry 混合部署 WARN。`entries.tsv` 不再作为 entry 判据，因为 relay 本来就管理公网入口列表。下一步建议只基于本地配置判断，不联网、不修改系统。

状态缓存文件：

```text
/etc/leikwan-toolkit/status/last-apply.env
/etc/leikwan-toolkit/status/last-doctor.env
/etc/leikwan-toolkit/status/last-status.env
/etc/leikwan-toolkit/status/last-update.env
```

缓存只记录时间、动作、结果和版本，不写 EasyTier secret。

1.4.1 起，状态总览显示全局 IP 变化检测状态：

```text
DDNS: enabled, last OK, changed 0, relay restart needed: no
最近检测: 2026-05-10 04:12:00 / OK
公网 IP 检测源: https://api.ipify.org
后端域名检测: OK
公网入口域名检测: OK
PBR 域名检测: OK
DDNS:
- 全局 IP 变化检测: active
- relay restart needed: no
最近配置导出: 2026-05-10 06:00:00 / full
最近配置导入: 无记录
最近端点输出: 2026-05-10 06:01:00 / forward-endpoints
```

DDNS 最近状态缓存：

```text
/etc/leikwan-toolkit/status/last-ddns.env
/etc/leikwan-toolkit/status/last-config-export.env
/etc/leikwan-toolkit/status/last-config-import.env
/etc/leikwan-toolkit/status/last-output.env
```

脚本自更新最近状态也会显示在 `lq status` 中：

```text
脚本版本: 1.4.0
最近更新: 2026-05-10 05:30:00 / 1.1.2 -> 1.4.0 / OK
```

`status` 不联网检查 latest release；联网检查只由 `lq update check` 执行。

简洁模式：

```bash
lq --brief
lq --compact
lq status --brief
LEIKWAN_BRIEF=1 lq status
```

会输出短英文状态块，并包含类似 `Health: 96/100 (excellent)` 的健康度。

## 配置快照 / 回滚

菜单路径：

```text
高级维护 -> 配置备份 / 快照 / 回滚
```

快照保存在：

```text
/etc/leikwan-toolkit/snapshots/
/etc/leikwan-toolkit/snapshots/auto/
```

快照内容包含 leikwan 配置、相关 systemd unit、sysctl、rt_tables，以及 nft/ip rule/ip route 的只读导出。快照可能包含 EasyTier network secret，请妥善保存。

## 配置导入 / 导出状态

`lq config export` 和 `lq config import` 会分别写入：

```text
/etc/leikwan-toolkit/status/last-config-export.env
/etc/leikwan-toolkit/status/last-config-import.env
```

`lq output generate` 会写入：

```text
/etc/leikwan-toolkit/status/last-output.env
```

状态总览会读取这些文件，不会打开完整配置包，也不会把完整配置包放入 debug report。

高危操作前会自动创建轻量快照，失败时会 WARN 并询问是否继续。自动快照只保留最近 10 个。

## 端口冲突预检

```bash
lq port check
lq --port-check
```

端口预检会检查：

- EasyTier 端口是否在 `8000-9000` 白名单，是否被 entries/pending/本机监听/nftables 占用。
- 业务入口端口是否被 forwards、本机监听或 nftables DNAT 占用。
- enabled 转发目标是否能在项目 nftables 表中找到 TCP/UDP dport。

预检只读，不修改系统。新增入口和新增转发目标时也会使用同一套冲突判断，避免普通菜单路径写入重复端口。

disabled 的历史入口或历史转发目标只显示 INFO，不进入 WARN / FAIL 聚合。只有 enabled 项发生冲突、nft 缺失或监听异常时才 WARN。
