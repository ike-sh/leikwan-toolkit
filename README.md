# Leikwan Toolkit

Leikwan Toolkit `1.4.2 LTS` is the Shell LTS line for local TCP/UDP forwarding, EasyTier relay / entry setup, nftables, IPv4 PBR, snapshots, status, doctor, and DDNS domain-resolution refresh.

当前仓库只维护 Shell LTS：

- `leikwan-toolkit.sh`
- `scripts/bootstrap.sh`
- `docs/`
- `tests/`

历史 `panel/` 实现已迁移到 `edge-tunnel-panel`，本仓库不恢复这些文件。

## 快速开始

```bash
lq init
lq status
lq status --verbose
lq --doctor
lq ddns run
lq ddns status
lq forward apply-relay --auto-fix-route
```

查看版本：

```bash
lq --version
# leikwan-toolkit 1.4.2 LTS
```

## 域名解析变化自动刷新

Leikwan Toolkit 默认不修改 DNS 服务商记录，也不要求配置 DNS provider token。公网入口域名 / IP 可以由路由器、服务商客户端、Cloudflare、外部 DDNS 客户端或外部脚本维护。

Toolkit 在 B 利群主机侧定时解析这些域名，并根据解析结果相对本地缓存是否变化来刷新本地配置：

- `entries.tsv` 中 enabled 公网入口的 `public_host`。
- `forwards.tsv` 中 enabled 转发目标的 `target_host`。
- `pbr/domain-routes.tsv` 中 enabled 域名规则。
- `DDNS_GLOBAL_DOMAINS` 中额外配置的域名。

本机公网 IP 检测只作为辅助状态展示，不参与 entries / forwards / PBR 的变化判断。

1.4.2 起，DDNS 域名检测支持多 DNS 解析器，避免只依赖系统 DNS 时漏掉国内外 DNS 传播不一致：

```text
DNS_RESOLVE_SERVERS=1.1.1.1,8.8.8.8,223.5.5.5,119.29.29.29
DNS_RESOLVE_STRATEGY=first-success
DNS_RESOLVE_WARN_ON_SPLIT=true
```

默认优先使用 `1.1.1.1` / `8.8.8.8`，再使用国内 DNS。用户可以调整 `DNS_RESOLVE_SERVERS` 顺序，也可以把 `DNS_RESOLVE_STRATEGY` 设置为 `system-first` 或 `majority`。如果解析器返回不同 IP，会记录 WARN，并在状态中显示最近 DNS 分歧。

发现采用结果与本地缓存不同时，Toolkit 会更新 resolved 缓存并自动刷新本地转发 / PBR。公网入口 `public_host` 变化时会标记 `relay restart needed`；默认不会自动重启 relay。需要自动重启时再显式设置：

```text
DDNS_AUTO_RESTART_RELAY=true
```

关键默认值：

```text
DDNS_UPDATE_DNS_RECORD=false
DDNS_AUTO_APPLY=true
DDNS_AUTO_SYNC_PBR=true
DDNS_AUTO_RESTART_RELAY=false
PUBLIC_IP_CHECK_URLS=
```

## 文档

- [DDNS / 域名解析变化](docs/ddns-refresh.md)
- [CLI](docs/cli.md)
- [状态输出](docs/status.md)
- [Doctor](docs/doctor.md)
- [PBR](docs/pbr.md)
- [nftables 转发](docs/nftables-forwarding.md)
- [Workflow](docs/workflow.md)
- [Testing](docs/testing.md)
