# Leikwan Toolkit

Leikwan Toolkit `1.4.14 LTS` is the Shell LTS line for local TCP/UDP forwarding, EasyTier relay / entry setup, nftables, IPv4 PBR, snapshots, status, doctor, and DDNS domain-resolution refresh.

当前仓库只维护 Shell LTS：

- `leikwan-toolkit.sh`
- `scripts/bootstrap.sh`
- `docs/`
- `tests/`

历史 `panel/` 实现已迁移到 `edge-tunnel-panel`，本仓库不恢复这些文件。

## 快速开始

国内机器优先使用这一组命令，避免 GitHub 大文件直连卡住。bootstrap 后续 GitHub 下载默认继续走 `mirror-first`：

```bash
export LEIKWAN_GITHUB_DOWNLOAD_MODE=mirror-first
export LEIKWAN_GITHUB_MIRRORS="https://gh-proxy.com/,https://gh.llkk.cc/,https://gh.ddlc.top/,https://ghproxy.net/,https://mirror.ghproxy.com/,https://cf.ghproxy.cc/,https://gh.api.99988866.xyz/,https://github.akams.cn/"
curl -fsSL -o /tmp/lq-bootstrap.sh https://gh-proxy.com/https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/scripts/bootstrap.sh
bash /tmp/lq-bootstrap.sh
```

国内机器建议使用国内推荐命令。bootstrap 内部后续 GitHub 下载默认 `mirror-first`，镜像失败时会 fallback 官方 GitHub；如果某个镜像不可用，可调整 `LEIKWAN_GITHUB_MIRRORS` 顺序。需要改回官方 GitHub 优先时设置 `LEIKWAN_GITHUB_DOWNLOAD_MODE=origin-first`。

官方安装命令：

```bash
curl -fsSL -o /tmp/lq-bootstrap.sh https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/scripts/bootstrap.sh
bash /tmp/lq-bootstrap.sh
```

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
# leikwan-toolkit 1.4.14 LTS
```

## 快速组网系统网络预处理

快速组网在 B 利群主机初始化和 A 公网入口部署前，会自动执行系统网络预处理：

- 开启 IPv4 优先，托管 `/etc/gai.conf` 中的 Leikwan managed block。
- 设置系统 DNS 为国外 DNS：`8.8.8.8`、`1.1.1.1`。

这些系统级修改会先备份，再写入可恢复配置。手动入口在：

```text
高级维护 -> 系统网络优化
```

也可以使用 CLI：

```bash
lq system network status
lq system network prepare
lq system ipv4-prefer enable
lq system dns set 8.8.8.8,1.1.1.1
lq system dns restore
lq system ipv6 disable
lq system ipv6 restore
lq system ipv6 lockdown
lq system bbr enable
```

系统 DNS 影响整机解析；DDNS 多 DNS 解析器只影响 Toolkit 对域名解析变化的检测，两者不是同一套配置。如果不希望脚本继续管理系统 DNS，可在“系统网络优化”中恢复。

IPv6 禁用是 sysctl 级别的禁用 / 恢复；“IPv6 入站收口 nftables”只是用 nftables 限制 IPv6 入站访问，不是禁用 IPv6。

## 域名解析变化自动刷新

Leikwan Toolkit 默认不修改 DNS 服务商记录，也不要求配置 DNS provider token。公网入口域名 / IP 可以由路由器、服务商客户端、Cloudflare、外部 DDNS 客户端或外部脚本维护。

Toolkit 在 B 利群主机侧定时解析这些域名，并根据解析结果相对本地缓存是否变化来刷新本地配置：

- `entries.tsv` 中 enabled 公网入口的 `public_host`。
- `forwards.tsv` 中 enabled 转发目标的 `target_host`。
- `pbr/domain-routes.tsv` 中 enabled 域名规则。
- `DDNS_GLOBAL_DOMAINS` 中额外配置的域名。

本机公网 IP 检测只作为辅助状态展示，不参与 entries / forwards / PBR 的变化判断。

1.4.5 起，DDNS 域名检测继续支持多 DNS 解析器，避免只依赖系统 DNS 时漏掉国内外 DNS 传播不一致：

```text
DNS_RESOLVE_SERVERS=1.1.1.1,8.8.8.8,223.5.5.5,119.29.29.29
DNS_RESOLVE_STRATEGY=first-success
DNS_RESOLVE_WARN_ON_SPLIT=true
```

默认优先使用 `1.1.1.1` / `8.8.8.8`，再使用国内 DNS。用户可以调整 `DNS_RESOLVE_SERVERS` 顺序，也可以把 `DNS_RESOLVE_STRATEGY` 设置为 `system-first` 或 `majority`。如果解析器返回不同 IP，会记录 WARN，并在状态中显示最近 DNS 分歧。

没有 `dig` 时，`lq ddns run`、`lq ddns status`、`lq doctor`、`lq doctor --auto-fix` 和 DDNS timer 会在 root + apt-get 环境下自动安装 `dnsutils`。安装失败不会中断检测，会继续使用 `nslookup`、`host` 和系统 resolver fallback；如果只能使用系统 resolver，状态会显示 `DNS 传播状态: 未完整检测`。

发现采用结果与本地缓存不同时，Toolkit 会更新 resolved 缓存并自动刷新本地转发 / PBR。公网入口 `public_host` 变化时会标记 `relay restart needed`；默认不会自动重启 relay。需要自动重启时再显式设置：

启用或禁用公网入口后，如果该入口使用域名，Toolkit 会自动轻量刷新 `resolved-entries.tsv` 和 DDNS 状态缓存；刷新失败只 WARN，不阻塞入口启停。

```text
DDNS_AUTO_RESTART_RELAY=true
DDNS_RESTART_RELAY_COOLDOWN=300
```

关键默认值：

```text
DDNS_UPDATE_DNS_RECORD=false
DDNS_AUTO_APPLY=true
DDNS_AUTO_SYNC_PBR=true
DDNS_AUTO_RESTART_RELAY=false
DDNS_RESTART_RELAY_COOLDOWN=300
PUBLIC_IP_CHECK_URLS=
```

## Release 打包

```bash
bash scripts/build-release.sh
# 或指定版本
VERSION=1.4.14 bash scripts/build-release.sh
```

产物写入 `dist/leikwan-toolkit-1.4.14.tar.gz` 和对应 `.sha256`，只包含 Shell LTS 需要的 VERSION、README、主脚本、scripts、docs、tests 和可选 LICENSE。`.sha256` 文件使用 `hash  leikwan-toolkit-1.4.14.tar.gz` 的 basename 格式。`VERSION` 用于 `lq update check` 轻量检查最新版本，发布时必须与 `TOOL_VERSION` 保持一致。

## 文档

- [DDNS / 域名解析变化](docs/ddns-refresh.md)
- [CLI](docs/cli.md)
- [状态输出](docs/status.md)
- [Doctor](docs/doctor.md)
- [PBR](docs/pbr.md)
- [nftables 转发](docs/nftables-forwarding.md)
- [Workflow](docs/workflow.md)
- [Testing](docs/testing.md)
