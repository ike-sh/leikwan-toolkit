# 状态输出

Leikwan Toolkit 1.4.1 对 `lq status` 做了稳定化整理，目标是让日常巡检像正式运维系统一样可读、可脚本化、不会误报角色。

## 常用命令

```bash
lq status
lq status --verbose
lq --status
lq --brief
lq --compact
lq status --brief
lq status --json
lq --status-json
LEIKWAN_BRIEF=1 lq status
```

1.4.1 LTS 起，`lq status` 默认输出最终版短状态：

```text
Leikwan 状态
----------------------------------------
版本: 1.4.1 LTS
角色: relay
健康度: 96/100 excellent
公网入口: 2 enabled
转发目标: 4 enabled
DDNS: OK
nftables: OK
PBR: OK
整体状态: OK
```

详细状态使用：

```bash
lq status --verbose
```

## 角色识别

角色判断只使用真正能证明角色的信号：

- relay：`easytier-relay.service` 存在，或 `network.env` 中 `ROLE=leikwan-relay`。
- entry：`easytier-entry-*.service` 存在，或 `ROLE=cloud-entry`，或 A 侧 entry env / service 状态存在。

`entries.tsv` 不再作为 entry 判据，因为 B relay 本来就管理公网入口列表。`forwards.tsv` 只作为 relay 辅助信息，不能单独决定角色。

只有真实同时部署 relay 和 entry 时才会显示：

```text
[WARN] 检测到高级混合部署：relay + entry
```

## 简洁模式

简洁模式适合日常监控或窄终端：

```text
Leikwan Status
----------------------------------------
Role: relay
EasyTier: OK
Entries: 2 enabled
Forwards: 4 enabled
PBR: 4
DDNS: OK
nftables: OK
Health: 96/100 (excellent)
Overall: OK
```

JSON 输出不受简洁模式影响，仍输出结构化摘要。

## 健康度评分

`status` 和 JSON 都包含系统健康度：

- 90-100：excellent
- 75-89：good
- 50-74：warning
- 0-49：critical

评分会参考 EasyTier、relay / entry 服务、entries、forwards、PBR、nftables、MSS clamp、DDNS、锁和最近错误。它是巡检提示，不替代 `lq --doctor` 的详细诊断。

## DDNS / 域名解析变化状态

1.4.4 起，`lq status` 将 DDNS 显示为域名解析变化检测：

- 检测后端域名、公网入口域名和 PBR 域名。
- 发现变化后刷新 resolved 缓存、nftables 和 PBR。
- 默认不修改 DNS 服务商记录，不要求 DNS provider token。
- 本机公网 IP 检测只作为辅助状态，不参与域名变化判断。

如果检测到公网入口域名变化但 relay 尚未重启，状态会提示：

```text
[WARN] 公网入口域名解析已变化，relay 可能需要重启。
[INFO] 可执行：lq ddns apply-entries
```

状态块还会显示：

```text
DDNS:
- 域名解析变化检测: active / disabled / not configured
- relay restart needed: yes / no
```

JSON 输出包含 `entry_ddns_enabled`、`entry_ddns_host`、`entry_ddns_public_ip`、`entry_ddns_resolved_ip`、`entry_ddns_match`、`relay_restart_needed`，不包含 token、secret 或自定义更新 URL。

## disabled 项

禁用的公网入口或转发目标会保留历史配置，但不再进入 WARN / FAIL 聚合。例如端口预检会显示：

```text
[INFO] 8303 public3 已 disabled，保留历史配置。
```

只有 enabled 项发生端口冲突、nft 缺失或监听异常时才会 WARN。
