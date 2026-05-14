# 全局 IP 变化检测与自动刷新

Leikwan Toolkit 1.4.1 LTS 将 DDNS 用户路径定义为“全局 IP 变化检测”。它默认不修改 DNS 服务商记录，也不要求配置 DNS provider token。

你的域名解析可以由路由器、服务商客户端、Cloudflare、Cloudflare Worker、外部 DDNS 客户端或外部脚本维护。Toolkit 只检测解析结果是否变化，并在变化后刷新本机转发、缓存和 PBR。

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

一次全局检测会覆盖：

- 本机公网 IPv4。
- `entries.tsv` 中 enabled `public_host` 域名。
- `forwards.tsv` 中 enabled `target_host` 域名。
- `pbr/domain-routes.tsv` 中 enabled 域名规则。

纯 IPv4 不会被替换。域名仍保留在原始配置中，解析结果写入缓存文件。

## 公网 IP URL 池

默认 URL 池兼顾国内外网络：

```text
https://api.ipify.org
https://ifconfig.me/ip
https://ipv4.icanhazip.com
https://4.ipw.cn
https://ip.3322.net
https://myip.ipip.net
```

检测时按顺序尝试，每个 URL 使用短超时，并从响应中提取第一个 IPv4。第一个成功返回 IPv4 的源会写入状态缓存。全部失败时只记录 WARN，不破坏已有配置。

可在 `/etc/leikwan-toolkit/ddns-global.env` 覆盖：

```text
PUBLIC_IP_CHECK_URLS=https://4.ipw.cn,https://ip.3322.net,https://api.ipify.org
```

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
DDNS_AUTO_APPLY=true
DDNS_AUTO_SYNC_PBR=true
DDNS_AUTO_RESTART_RELAY=false
DDNS_KEEP_OLD_ON_FAIL=true
DDNS_UPDATE_DNS_RECORD=false
```

关键点是 `DDNS_UPDATE_DNS_RECORD=false`。默认只检测解析变化并刷新本地配置。

旧配置 `/etc/leikwan-toolkit/ddns.env` 和 `/etc/leikwan-toolkit/entry/ddns.env` 仍会兼容读取。旧 provider、token、update URL、update command 不会被删除，但只作为高级兼容能力。

## 自动刷新行为

发现解析 IP 变化后，Toolkit 会：

- 更新 `forwards/resolved.tsv`。
- 更新 `entries/resolved-entries.tsv`。
- 更新 PBR resolved 缓存。
- 在 `DDNS_AUTO_APPLY=true` 时重应用 nftables。
- 在 `DDNS_AUTO_SYNC_PBR=true` 时同步并应用 PBR。
- 写入 `/etc/leikwan-toolkit/status/last-ddns.env`。
- 写入 `/var/log/leikwan-ddns-refresh.log`。
- 公网入口域名变化时标记 `relay restart needed`。

默认不会自动重启 relay。确认能接受短暂中断后，再设置：

```text
DDNS_AUTO_RESTART_RELAY=true
```

## 状态输出

```bash
lq ddns status
```

输出示例：

```text
DDNS / IP 变化检测状态
----------------------------------------
自动检测: enabled
检测间隔: 5min
本机公网 IP: 203.0.113.10
公网 IP 检测源: https://api.ipify.org
后端域名: checked 1, changed 0, failed 0
公网入口域名: checked 1, changed 0, failed 0
PBR 域名: checked 1, changed 0, failed 0
nftables: 无需重应用
PBR: 无需同步
relay restart needed: no
最近检测: 2026-05-14 12:00:00
结果: OK
```

## systemd timer

菜单“开启 / 关闭全局 IP 变化检测”管理：

```text
leikwan-ddns-refresh.timer
```

service 执行：

```text
/usr/local/bin/lq ddns run --global --non-interactive
```

如果 `/usr/local/bin/lq` 不存在，会回退到当前脚本路径。

## 高级兼容：DNS 记录更新

如果确实希望 Toolkit 修改 DNS 记录，可以显式启用：

```text
DDNS_UPDATE_DNS_RECORD=true
```

然后使用兼容入口配置 provider、token、update URL 或 update command。这个能力只为旧脚本和高级集成保留，不是默认路径。普通用户不需要配置 DNS provider token。
