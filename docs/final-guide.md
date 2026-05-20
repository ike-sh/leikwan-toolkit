# Leikwan Toolkit 1.4.17 LTS 最终版使用手册

1.4.17 LTS 是 Shell LTS 维护版。Leikwan Toolkit 的定位收敛为：

```text
A 公网入口 + B 中转主机 + C 后端目标 的 TCP/UDP 转发组网工具
```

后续版本主要只做 bug fix、兼容性修复、安全修复和文档完善。

## 最短使用路径

只想把服务跑起来，按这个顺序：

1. B 安装工具，执行 `lq init`。
2. B 生成公网入口接入码。
3. A 安装工具，粘贴接入码并部署入口。
4. B 粘贴 A 返回码完成接入。
5. B 添加后端转发目标。
6. B 生成端点输出，交给使用方连接。

快速组网会自动执行系统网络预处理：开启 IPv4 优先，并把系统 DNS 设置为 `8.8.8.8` / `1.1.1.1`。如果不希望脚本继续管理系统 DNS，可在“高级维护 -> 系统网络优化 -> DNS 服务器：设置 / 恢复”中恢复。

主菜单只保留 6 个入口：

```text
1. 快速组网
2. 利群主机 B
3. 公网入口 A
4. DDNS
5. 状态 / 诊断
6. 高级维护
0. 退出
```

## B 利群主机

B 端负责：

- 管理公网入口列表
- 管理后端转发目标
- 可选 IPv4 PBR 出口策略
- 应用 nftables 转发规则
- 查看 B 端状态

常用命令：

```bash
lq status
lq --doctor
lq forward apply-relay --auto-fix-route
```

## A 公网入口

A 端负责：

- 粘贴 B 生成的接入码
- 部署本机 entry service
- 配置入口端口池
- 可选维护本机公网入口 DDNS

常用命令：

```bash
lq entry expose-range
lq ddns status
lq status
```

## DDNS

DDNS 用户路径是“域名解析变化自动刷新”：

- Toolkit 默认不修改 DNS 服务商记录。
- 域名可以由路由器、服务商客户端、Cloudflare 或外部脚本维护。
- Toolkit 在 B 侧检测 entries / forwards / PBR 域名变化后刷新本地转发、resolved 缓存和 PBR。
- 公网入口域名变化时默认只标记 `relay restart needed`，不会自动重启 relay。

普通用户不需要配置 DNS provider token。

```bash
lq ddns run
lq ddns status
lq ddns enable
```

## 高级维护

低频和高危操作都收进“高级维护”：

- EasyTier 服务管理
- 配置备份 / 快照 / 回滚
- 配置导入 / 导出
- 自更新
- 端点输出
- 调试报告
- 系统网络优化
- 卸载

高危操作仍会保留确认、自动快照和锁保护。

系统网络优化包含 IPv4 优先开启 / 关闭、系统 DNS 设置 / 恢复、IPv6 sysctl 禁用 / 恢复、BBR / fq，以及 IPv6 入站收口 nftables。IPv6 入站收口是防火墙限制，不是禁用 IPv6。
