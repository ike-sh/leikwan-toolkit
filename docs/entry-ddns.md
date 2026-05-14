# 兼容 DNS 更新入口

本页只记录旧版 `entry ddns` CLI 的兼容行为。普通用户建议使用：

```bash
lq ddns run
lq ddns status
lq ddns enable
```

1.4.1 LTS 的默认 DDNS 路径是“全局 IP 变化检测与自动刷新”：Toolkit 不修改 DNS 服务商记录，只检测公网 IP、域名解析变化，并刷新本地转发、resolved 缓存和 PBR。

## 何时使用兼容入口

只有你明确希望 Toolkit 直接修改 DNS 记录时，才需要启用兼容入口：

```text
DDNS_UPDATE_DNS_RECORD=true
```

然后再配置旧的 provider、token、custom URL 或 custom command。该路径会保存敏感配置到：

```text
/etc/leikwan-toolkit/entry/ddns.env
```

## 旧 CLI

这些命令继续保留，避免破坏旧脚本：

```bash
lq entry ddns status
lq entry ddns setup
lq entry ddns run
lq entry ddns enable
lq entry ddns disable
lq entry ddns logs
lq ddns entry status
lq ddns entry setup
lq ddns entry run
```

运行旧命令时会提示这是兼容入口。`DDNS_UPDATE_DNS_RECORD=false` 时，不会执行 DNS 记录更新。

## 安全边界

- 普通菜单不要求配置 DNS token。
- 普通菜单不展示 provider、custom URL 或 custom command。
- 配置导出和 debug report 会脱敏 token、secret、password、custom URL query 和 custom command。
