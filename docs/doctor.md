# doctor 诊断

Leikwan Toolkit 1.4.11 继续保留详细 `doctor`，同时修复历史 FAIL / WARN 污染问题，并新增自动修复常见问题入口。

## 常用命令

```bash
lq --doctor
lq doctor --json
lq --doctor-json
lq doctor --auto-fix
lq --doctor-auto-fix
LEIKWAN_BRIEF=1 lq --doctor
```

## 状态聚合

每次 doctor 开始都会重置本次诊断状态：

- 清空 WARN / FAIL 计数。
- 清空临时状态变量。
- 清空 summary cache。
- 不继承 `/etc/leikwan-toolkit/status/last-doctor.env` 的历史结果。

因此某次故障修复后再次运行 doctor，整体状态会按当前机器实时重新聚合为 OK / WARN / FAIL，不会被旧状态污染。

## 简洁模式

`LEIKWAN_BRIEF=1 lq --doctor` 或 `lq doctor --brief` 只显示 WARN / FAIL 和最后的摘要，适合巡检脚本或窄终端。普通 `lq --doctor` 仍保留详细输出。

## 自动修复

自动修复入口：

```bash
lq doctor --auto-fix
lq --doctor-auto-fix
```

允许自动修复：

- 系统网络预处理：开启 IPv4 优先，并把系统 DNS 设置为 `8.8.8.8` / `1.1.1.1`。
- nftables 表或 MSS clamp 缺失。
- route table metadata 不一致。
- relay service 丢失但已有有效 relay network.env。
- DDNS timer 未启用。
- 缺少 `dig` 时自动尝试安装 `dnsutils`，用于完整多 DNS 解析器检测。
- `lq` / `LQ` 快捷命令错误。
- 配置文件权限错误。
- stale locks。

禁止自动修复：

- 删除 entries。
- 删除 forwards。
- 删除 PBR。
- 重置 EasyTier network secret。
- 默认禁用 IPv6。
- 自动执行 IPv6 入站收口。

自动修复会先运行一次简洁 doctor，记录修复前 FAIL / WARN 数量；修复后再运行 doctor，并输出已恢复项与剩余问题。

doctor 会在 IPv4 优先未启用时提示 `lq system network prepare`。如果系统 DNS 不是 Leikwan 推荐的国外 DNS，也会提示当前系统 DNS 与推荐值不同。这里的“系统 DNS”影响整机解析；DDNS 多 DNS 解析器只影响 Toolkit 的域名变化检测。

缺少 `dig` 时会在 root + apt-get 环境下直接尝试安装 `dnsutils`；安装失败不会中断 doctor，会继续按 fallback 能力检查。

## JSON 摘要

`doctor --json` 和 `--doctor-json` 输出轻量 summary JSON，包含：

- version
- role / role_source
- overall
- health_score / health_level
- entries / forwards / PBR 数量
- nftables / MSS clamp / DDNS 状态
- warnings / failures

JSON 输出不包含 EasyTier secret、配对码 base64、token 或 password。

## 末尾摘要

文本 doctor 末尾会保留最终版摘要：

```text
诊断结果摘要
----------------------------------------
角色: relay
EasyTier: OK
公网入口: OK
转发目标: OK
PBR: OK
nftables: OK
MSS clamp: OK
DDNS: OK
健康度: 96/100 excellent
整体状态: OK
```

存在问题时会输出“建议修复”，优先给出 `lq doctor --auto-fix`、`lq ddns apply-entries` 或 `lq forward apply-relay --auto-fix-route`。

## DDNS / 域名解析变化检查

1.4.5 起，doctor 会按“域名解析变化自动刷新”提示 DDNS 状态：

- 检测到 enabled 公网入口域名但域名解析变化检测 timer 未启用时，会提示 `lq ddns enable`。
- DDNS 最近状态中已有成功的辅助公网 IP、检测源和时间时，不会误报“最近没有可用结果”。
- 最近检测结果为 FAIL，或最近检测没有可用公网 IP 时，会提示检查网络或自定义 `PUBLIC_IP_CHECK_URLS`。
- 域名解析失败时，会提示检查 DNS。
- 启用 DDNS 域名解析变化检测但缺少 `dig` 时，会先尝试自动安装 `dnsutils`；失败后提示当前使用 fallback。
- 公网入口域名变化且 relay 尚未重启时，会提示 `relay restart needed`，建议维护窗口处理。
- 只有显式设置 `DDNS_UPDATE_DNS_RECORD=true` 时，才会提示兼容 DNS 更新 provider/token。

doctor 仍不会自动删除 entries、forwards、PBR，也不会重置 EasyTier network secret。
