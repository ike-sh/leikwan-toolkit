# Leikwan Toolkit

Leikwan Toolkit 是一套 **Shell LTS 快速组网与转发工具**，用于公网入口、利群中转主机、后端落地目标之间的 TCP / UDP 转发、EasyTier 组网、nftables 转发、IPv4 PBR 出口策略、DDNS 域名解析变化自动刷新、状态诊断与维护。

当前仓库只维护 **Shell LTS 线**：

```text
leikwan-toolkit 1.4.5 LTS
```

Web 面板、Controller、Agent、前端页面等代码已经迁移到独立仓库：

```text
https://github.com/ike-sh/edge-tunnel-panel
```

本仓库不再包含 `panel/`、Controller、Agent、Web 前端或面板发布包。

---

## 一键安装

在 Debian / Ubuntu 服务器上执行：

```bash
curl -fsSL -o /tmp/lq-bootstrap.sh https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/scripts/bootstrap.sh
bash /tmp/lq-bootstrap.sh
lq
```

如果 GitHub 直连不稳定，可以先设置镜像：

```bash
export LEIKWAN_GITHUB_MIRRORS="https://gh.llkk.cc/,https://gh.ddlc.top/,https://gh-proxy.com/,https://ghproxy.net/"
curl -fsSL -o /tmp/lq-bootstrap.sh https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/scripts/bootstrap.sh
bash /tmp/lq-bootstrap.sh
lq
```

安装完成后会写入命令入口：

```bash
lq
```

---

## 更新到最新版本

进入交互菜单：

```bash
lq
```

然后选择：

```text
6. 高级维护
4. 自更新
2. 更新到最新版本
```

也可以使用 CLI：

```bash
lq update check
lq update install
```

自更新会优先尝试 GitHub Release，直连失败后自动尝试 `LEIKWAN_GITHUB_MIRRORS` 镜像，并保留 sha256 校验。

---

## 常用命令

```bash
lq
lq --version
lq status
lq status --verbose
lq doctor
lq doctor --auto-fix
lq ddns run --global
lq ddns run --global --non-interactive
lq ddns status
lq forward apply-relay --auto-fix-route
```

---

## 适用拓扑

典型拓扑：

```text
公网入口 A
  ↓
EasyTier 组网
  ↓
利群中转主机 B
  ↓
nftables TCP/UDP 转发
  ↓
后端落地目标 target_host:target_port
```

说明：

- A 是公网入口服务器，提供公网端口和 EasyTier 入口。
- B 是利群中转主机，负责接入多个公网入口、维护转发规则、PBR 出口和 DDNS 域名解析变化自动刷新。
- 后端落地目标不需要安装本工具，只需要在转发规则中填写 `target_host:target_port`。
- 多个公网入口可以共存，通过权重区分主入口 / 备用入口。

---

## 核心功能

### 快速组网

- 引导配置 EasyTier 网络。
- 支持公网入口 A 和利群主机 B 角色。
- 支持生成和粘贴公网入口接入码。
- 支持多个公网入口共存。
- 支持公网入口启用 / 禁用、权重调整、连通性测试。

### 转发规则

- 支持 TCP、UDP、TCP+UDP 转发。
- 使用 nftables 生成 DNAT 转发规则。
- 支持常见入口端口池检查。
- 支持目标域名解析缓存。
- 支持转发规则重应用。
- 支持目标 TCP / UDP 探测。

### IPv4 PBR 出口策略

- 支持基于目标 IP / 域名的 IPv4 PBR 出口策略。
- 支持不同后端转发走不同出口。
- 支持域名型 PBR 的解析缓存与自动同步。
- 支持状态和 doctor 检查出口一致性。

### DDNS / 域名解析变化自动刷新

从 `1.4.5 LTS` 开始，DDNS 主路径已经收敛为：

```text
B 端域名解析变化检测与无人值守自动刷新
```

它不负责修改 DNS 服务商记录。你的 DNS 记录可以由路由器、云厂商、Cloudflare、外部 DDNS 客户端或其他系统维护。

Toolkit 负责：

- 检测 `entries.tsv` 中 enabled 公网入口 `public_host` 域名。
- 检测 `forwards.tsv` 中 enabled 转发目标 `target_host` 域名。
- 检测 PBR 域名规则。
- 使用多 DNS 解析器识别国内外 DNS 传播差异。
- 检测到变化后更新本地 `resolved*.tsv` 缓存。
- 按配置自动重应用 nftables。
- 按配置自动同步 PBR。
- 公网入口域名变化时按配置自动重启 relay，或仅标记 `relay restart needed`。

默认 DNS 解析器：

```text
DNS_RESOLVE_SERVERS=1.1.1.1,8.8.8.8,223.5.5.5,119.29.29.29
DNS_RESOLVE_STRATEGY=first-success
DNS_RESOLVE_WARN_ON_SPLIT=true
```

关键配置文件：

```text
/etc/leikwan-toolkit/ddns-global.env
```

常用配置：

```text
DDNS_AUTO_APPLY=true
DDNS_AUTO_SYNC_PBR=true
DDNS_AUTO_RESTART_RELAY=false
DDNS_RESTART_RELAY_COOLDOWN=300
DDNS_CHANGE_CONFIRM_COUNT=1
DDNS_UPDATE_DNS_RECORD=false
```

无人值守执行命令：

```bash
lq ddns run --global --non-interactive
```

systemd timer 会使用非交互模式执行，避免卡在确认提示：

```text
/usr/local/bin/lq ddns run --global --non-interactive
```

如果 `DDNS_AUTO_RESTART_RELAY=true`，非交互模式检测到公网入口域名变化后会自动重启 relay；如果为 `false`，只标记 `relay restart needed`。

### dnsutils / dig 自动处理

多 DNS 解析器检测优先使用 `dig`。如果系统缺少 `dig`，脚本会尝试自动安装 `dnsutils`：

```bash
apt-get update
apt-get install -y dnsutils
```

安装失败不会中断检测，会降级使用：

```text
nslookup → host → getent ahostsv4
```

### 状态与诊断

- `lq status`：简洁状态。
- `lq status --verbose`：详细状态。
- `lq doctor`：一键诊断。
- `lq doctor --auto-fix`：自动修复常见问题。
- `lq ddns status`：查看 DDNS / 域名解析状态。
- `lq ddns log`：查看 DDNS 日志。

doctor 会检查：

- 系统依赖。
- GitHub / apt 源可达性。
- EasyTier 服务。
- 公网入口 peer、ping、TCP / UDP。
- nftables 表和 DNAT 规则。
- MSS clamp。
- 转发目标连通性。
- PBR 出口一致性。
- DDNS 最近执行状态。
- 多 DNS 检测能力。

### 配置备份 / 快照 / 回滚

高风险操作前会自动备份关键文件。常见备份位置：

```text
/var/backups/leikwan-toolkit/
```

自动快照位置：

```text
/etc/leikwan-toolkit/snapshots/auto/
```

---

## 交互菜单

主菜单：

```text
1. 快速组网
2. 利群主机 B
3. 公网入口 A
4. DDNS
5. 状态 / 诊断
6. 高级维护
0. 退出
```

DDNS 菜单：

```text
1. 开启 / 关闭域名解析变化检测
2. 立即检测并刷新
3. 查看 DDNS / 域名解析状态
4. 查看 DDNS 日志
5. 高级设置
0. 返回
```

DDNS 高级设置：

```text
1. 设置检测间隔
2. 设置辅助公网地址检测 URL 池
3. 设置 DNS 解析器列表
4. 设置 DNS 解析策略
5. 查看最近 DNS 分歧
6. 设置是否自动重应用 nftables
7. 设置是否自动同步 PBR
8. 设置 relay 是否允许自动重启
9. 设置 relay 自动重启 cooldown
10. 兼容旧版 DNS 更新配置
0. 返回
```

---

## 重要文件路径

```text
/root/leikwan-toolkit.sh
/usr/local/bin/lq
/etc/leikwan-toolkit/
/etc/leikwan-toolkit/easytier/network.env
/etc/leikwan-toolkit/entries/entries.tsv
/etc/leikwan-toolkit/entries/resolved-entries.tsv
/etc/leikwan-toolkit/forwards/forwards.tsv
/etc/leikwan-toolkit/forwards/resolved.tsv
/etc/leikwan-toolkit/ddns-global.env
/var/log/leikwan-ddns-refresh.log
/var/backups/leikwan-toolkit/
```

---

## GitHub 镜像加速

支持环境变量：

```bash
export LEIKWAN_GITHUB_MIRRORS="https://gh.llkk.cc/,https://gh.ddlc.top/,https://gh-proxy.com/,https://ghproxy.net/"
```

适用范围：

- bootstrap 安装。
- 自更新 Release 包下载。
- sha256 下载。
- EasyTier 下载。
- GitHub raw / release / API 访问。

下载逻辑：

```text
先尝试原始 GitHub URL
失败或超时后尝试镜像
镜像格式：${mirror}${original_url}
继续保留 sha256 校验
```

---

## 发布包构建

本仓库提供 Shell LTS 发布包构建脚本：

```bash
bash scripts/build-release.sh
```

生成：

```text
dist/leikwan-toolkit-1.4.5.tar.gz
dist/leikwan-toolkit-1.4.5.tar.gz.sha256
```

发布包包含：

```text
README.md
leikwan-toolkit.sh
scripts/
docs/
tests/
LICENSE（如存在）
```

发布包不包含：

```text
panel/
controller
agent
web
edge-tunnel-panel
```

---

## 文档

主要文档：

```text
docs/ddns-refresh.md
docs/doctor.md
docs/status.md
docs/entry-ddns.md
docs/troubleshooting.md
docs/workflow.md
docs/testing.md
docs/security.md
docs/acceptance-test.md
```

---

## Shell LTS 与 Panel 的关系

本仓库只维护 Shell LTS 线。

如果你需要：

- Web 主控面板
- Agent 节点接入
- 一键添加节点
- 面板化 EasyTier 组网
- 面板化 TCP / UDP 转发
- 面板化 PBR / DDNS 管理

请使用独立仓库：

```text
https://github.com/ike-sh/edge-tunnel-panel
```

---

## 安全边界

Leikwan Toolkit Shell LTS 是本机脚本工具：

- 不提供远程任意命令执行。
- 不包含 Controller / Agent。
- 不包含 Web 面板。
- 不默认修改 DNS 服务商记录。
- 高风险操作前尽量备份配置。
- relay 自动重启默认关闭，需要显式开启。

---

## 卸载

进入菜单：

```text
6. 高级维护
7. 卸载
```

卸载前建议先备份：

```bash
lq status --verbose
```

---

## 版本策略

`1.4.5 LTS` 是 Shell 版稳定维护线。

后续本仓库只建议做：

- 严重 Bug 修复。
- 兼容性修复。
- 文档维护。
- Shell LTS 小修。

Panel / Controller / Agent / Web 方向请跟随：

```text
edge-tunnel-panel 3.x
```
