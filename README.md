# Leikwan Toolkit

Leikwan Toolkit Shell Core is `1.4.1 LTS`. This repository now keeps only the Shell LTS line: `leikwan-toolkit.sh`, `scripts/bootstrap.sh`, docs, and tests.

Leikwan Toolkit is a TCP/UDP forwarding toolkit for a public entry, relay host, and backend target topology. The Shell Core owns the real local behavior: EasyTier, nftables forwarding, global IP change detection, PBR, snapshots, status, doctor, and maintenance.

## Quick Start

```bash
curl -fsSL -o /tmp/lq-bootstrap.sh https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/scripts/bootstrap.sh
bash /tmp/lq-bootstrap.sh
lq
```

Common commands:

```bash
export LEIKWAN_GITHUB_MIRRORS="https://gh.llkk.cc/,https://gh.ddlc.top/,https://gh-proxy.com/,https://ghproxy.net/"
curl -fsSL -o /tmp/lq-bootstrap.sh https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/scripts/bootstrap.sh
bash /tmp/lq-bootstrap.sh
lq
```

## 常用命令

```bash
lq
lq --version
lq status
lq status --verbose
lq --doctor
lq ddns run
lq ddns status
lq forward apply-relay --auto-fix-route
lq update check
```

## Shell LTS Scope

The former `panel/` code has moved to the separate `edge-tunnel-panel` repository and is not part of this Shell LTS line. This repo does not restore panel implementation files.

## 全局 IP 变化检测与自动刷新

Leikwan Toolkit 默认不修改 DNS 服务商记录。你的 DDNS 解析记录可以由路由器、服务商客户端、Cloudflare、Cloudflare Worker、外部 DDNS 客户端或外部脚本维护。

Toolkit 只负责检测 IP 和域名解析是否变化：

- 检测本机公网 IP。
- 检测 `entries.tsv` 中 enabled `public_host` 域名。
- 检测 `forwards.tsv` 中 enabled `target_host` 域名。
- 检测 PBR 域名规则。
- 发现变化后自动刷新本地转发、`resolved.tsv` 缓存和 PBR。

内置公网 IP 检测 URL 池，国内外服务器都可以直接使用：

```text
https://api.ipify.org
https://ifconfig.me/ip
https://ipv4.icanhazip.com
https://4.ipw.cn
https://ip.3322.net
https://myip.ipip.net
```

默认不会自动重启 relay，避免中断业务。公网入口域名解析变化时只标记 `relay restart needed`；需要自动重启时再显式设置：

```text
DDNS_AUTO_RESTART_RELAY=true
```

默认配置位于：

```text
/etc/leikwan-toolkit/ddns-global.env
```

关键默认值：

```text
DDNS_UPDATE_DNS_RECORD=false
DDNS_AUTO_APPLY=true
DDNS_AUTO_SYNC_PBR=true
DDNS_AUTO_RESTART_RELAY=false
PUBLIC_IP_CHECK_URLS=
```

兼容旧版 DNS 更新能力仍保留给高级用户，但普通路径不需要 DNS provider token。

## Docs

- [DDNS / IP 变化检测](docs/ddns-refresh.md)
- [CLI](docs/cli.md)
- [状态输出](docs/status.md)
- [Doctor](docs/doctor.md)
- [PBR](docs/pbr.md)
- [nftables 转发](docs/nftables-forwarding.md)
- [Workflow](docs/workflow.md)
- [Testing](docs/testing.md)
