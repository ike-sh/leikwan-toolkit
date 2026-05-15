# 域名解析变化自动刷新

Leikwan Toolkit 1.4.5 LTS 将 DDNS 用户路径收敛为 B 利群主机侧的“域名解析变化自动刷新”。它默认不修改 DNS 服务商记录，也不要求配置 DNS provider token。

公网入口 A 的域名 / IP 可以由路由器、服务商客户端、Cloudflare、外部 DDNS 客户端或外部脚本维护。Toolkit 只在 B 侧定时解析域名，发现解析结果相对本地缓存变化后刷新本机转发、缓存和 PBR。

## 常用命令

```bash
lq ddns run
lq ddns run --global
lq ddns status
lq ddns overview
lq ddns enable
lq ddns disable
lq ddns logs
```

`lq ddns run` 默认等价于 `lq ddns run --global`。

## 检测范围

一次检测会覆盖：

- `entries.tsv` 中 enabled 公网入口的 `public_host` 域名。
- `forwards.tsv` 中 enabled 转发目标的 `target_host` 域名。
- `pbr/domain-routes.tsv` 中 enabled 域名规则。
- `DDNS_GLOBAL_DOMAINS` 中额外配置的域名。

纯 IPv4 不会被替换。域名仍保留在原始配置中，解析结果写入缓存文件。本机公网 IP 检测只作为辅助状态展示，不参与 entries / forwards / PBR 的变化判断。

## 多 DNS 解析器

1.4.5 起，域名解析变化检测不再只依赖系统默认 DNS。它会按配置的解析器列表执行 A 记录查询，并检测国内外 DNS 传播不一致或缓存不一致。

默认配置：

```text
DNS_RESOLVE_SERVERS=1.1.1.1,8.8.8.8,223.5.5.5,119.29.29.29
DNS_RESOLVE_STRATEGY=first-success
DNS_RESOLVE_WARN_ON_SPLIT=true
```

默认优先使用 `1.1.1.1` / `8.8.8.8`，再使用国内 DNS。用户可以调整 `DNS_RESOLVE_SERVERS` 的顺序。

缺少 `dig` 时，`lq ddns run`、`lq ddns status`、`lq doctor`、`lq doctor --auto-fix` 和 DDNS timer 会在 root + apt-get 环境下自动安装 `dnsutils`。安装失败不会中断检测。

没有 `dig` 时，脚本会依次尝试 `nslookup DOMAIN SERVER`、`host DOMAIN SERVER`，最后 fallback 到 `getent ahostsv4 DOMAIN`。如果只能使用系统 resolver，状态会显示：

```text
DNS 传播状态: 未完整检测
```

解析策略：

- `first-success`：按 `DNS_RESOLVE_SERVERS` 顺序选择第一个成功返回 IPv4 的结果。
- `system-first`：先使用系统 resolver，失败后再使用配置的 DNS 解析器。
- `majority`：多个解析器投票，选择出现次数最多的 IP。

如果不同解析器返回不同 IP，会记录 WARN，并在状态中显示最近 DNS 分歧：

```text
DNS 传播状态: 不一致
最近 DNS 分歧:
home.example.test
1.1.1.1 -> 1.1.1.1
8.8.8.8 -> 1.1.1.1
223.5.5.5 -> 211.158.46.251
system -> 211.158.46.251
当前采用: 1.1.1.1
```

如果采用结果与本地缓存不同，Toolkit 会触发 changed 并写入缓存。例如：

```text
公网入口 public3 解析变化：211.158.46.251 -> 1.1.1.1
relay restart needed: yes
```

## 辅助公网 IP 状态

公网 IP URL 池仍保留，用于展示 B 侧当前辅助公网 IP 状态和排障信息。它不影响域名变化判断。

默认 URL 池：

```text
https://api.ipify.org
https://ifconfig.me/ip
https://ipv4.icanhazip.com
https://4.ipw.cn
https://ip.3322.net
https://myip.ipip.net
```

检测时按顺序尝试，每个 URL 使用短超时，并从响应中提取第一个 IPv4。第一个成功返回 IPv4 的源会写入状态缓存和日志：

```text
辅助公网 IP 检测源: https://4.ipw.cn
[OK] 辅助公网 IP：203.0.113.10（source=https://4.ipw.cn）
```

全部失败时只记录 WARN，不影响域名解析变化检测。

## 配置文件

全局配置文件：

```text
/etc/leikwan-toolkit/ddns-global.env
```

推荐字段：

```text
DDNS_GLOBAL_ENABLED=false
DDNS_GLOBAL_INTERVAL=5min
DDNS_GLOBAL_DOMAINS=
PUBLIC_IP_CHECK_URLS=
DNS_RESOLVE_SERVERS=1.1.1.1,8.8.8.8,223.5.5.5,119.29.29.29
DNS_RESOLVE_STRATEGY=first-success
DNS_RESOLVE_WARN_ON_SPLIT=true
DDNS_AUTO_APPLY=true
DDNS_AUTO_SYNC_PBR=true
DDNS_AUTO_RESTART_RELAY=false
DDNS_RESTART_RELAY_COOLDOWN=300
DDNS_CHANGE_CONFIRM_COUNT=1
DDNS_KEEP_OLD_ON_FAIL=true
DDNS_UPDATE_DNS_RECORD=false
```

关键点是 `DDNS_UPDATE_DNS_RECORD=false`。默认只检测解析变化并刷新本地配置。

旧配置 `/etc/leikwan-toolkit/ddns.env` 和 `/etc/leikwan-toolkit/entry/ddns.env` 仍会兼容读取。旧 provider、token、update URL、update command 不会被删除，但只作为高级兼容能力。

## 自动刷新行为

发现解析 IP 变化后，Toolkit 会：

- 更新 `entries/resolved-entries.tsv`。
- 更新 `forwards/resolved.tsv`。
- 更新 PBR resolved 缓存。
- 更新 `status/resolved-ddns-domains.tsv`。
- 在 `DDNS_AUTO_APPLY=true` 时重应用 nftables。
- 在 `DDNS_AUTO_SYNC_PBR=true` 时同步并应用 PBR。
- 写入 `/etc/leikwan-toolkit/status/last-ddns.env`。
- 写入 `/var/log/leikwan-ddns-refresh.log`。
- 公网入口域名变化时标记 `relay restart needed`。

启用或禁用公网入口后，如果该入口使用域名，Toolkit 会自动轻量刷新 `entries/resolved-entries.tsv` 和 `status/last-ddns.env`。这个刷新不会强制重启 relay；如果刷新失败，只记录 WARN。

默认不会自动重启 relay。确认能接受短暂中断后，再设置：

```text
DDNS_AUTO_RESTART_RELAY=true
DDNS_RESTART_RELAY_COOLDOWN=300
```

非交互模式不会询问确认。`DDNS_AUTO_RESTART_RELAY=true` 时会自动重启 relay；`DDNS_AUTO_RESTART_RELAY=false` 时只标记 `relay restart needed`。自动重启默认 300 秒 cooldown，短时间 DNS 抖动只会更新缓存并保留 pending restart，不会重复重启。

## 状态输出

```bash
lq ddns status
```

输出示例：

```text
DDNS / 域名解析状态
----------------------------------------
自动检测: enabled
timer: enabled
下次检测: Fri 2026-05-15 12:05:00 CST
检测间隔: 5min
辅助公网 IP: 203.0.113.10
辅助公网 IP 检测源: https://api.ipify.org
DNS 解析策略: first-success
DNS 解析器: 1.1.1.1,8.8.8.8,223.5.5.5,119.29.29.29
DNS 传播状态: 一致
后端域名: checked 1, changed 0, failed 0
公网入口域名: checked 1, changed 0, failed 0
PBR 域名: checked 1, changed 0, failed 0
nftables: 无需重应用
PBR: 无需同步
relay restart needed: no
relay restart cooldown: 300s
DDNS 变化确认次数: 1
最近检测: 2026-05-14 12:00:00
最近自动执行: 2026-05-14 12:00:00
最近自动动作: 已写入缓存
结果: OK
```

## 高级兼容 DNS 更新

如果确实需要 Toolkit 主动修改 DNS 服务商记录，可以显式设置：

```text
DDNS_UPDATE_DNS_RECORD=true
```

然后使用兼容入口配置 provider / token / custom URL / custom command。这不是默认路径，也不会出现在普通 DDNS 菜单中。
