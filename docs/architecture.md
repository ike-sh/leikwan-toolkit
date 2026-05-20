# 架构说明

Leikwan Toolkit 1.4.0 使用 EasyTier + nftables 构建三段式 TCP/UDP 转发链路。

```text
外部客户端 -> A 公网入口端口（TCP/UDP） -> EasyTier -> B 利群主机 -> 后端目标
```

## 角色

- A：公网入口，可部署多台。
- B：利群主机 / 中转主机，通常只有一台。
- C：后端目标，由用户自行维护。

## 地址

默认 EasyTier 网段：

```text
10.198.1.0/24
```

默认地址：

```text
B relay: 10.198.1.1
public1: 10.198.1.2
public2: 10.198.1.3
public3: 10.198.1.4
```

## 转发

A 侧负责把业务入口端口池 TCP+UDP DNAT 到 B 的 EasyTier IP。B 侧负责把每个转发目标的入口端口 TCP+UDP DNAT 到后端目标。

如果后端目标是域名，B 侧会把当前解析 IP 写入 `resolved.tsv`。DDNS 自动刷新可以定期检查域名后端、公网入口域名和域名 PBR；后端 IP 变化时自动更新 resolved 记录并重应用 nftables，公网入口变化时提示 relay 可能需要重启，域名 PBR 变化时同步 `/32` 规则。

## 多入口

多公网入口用于手动切换和主备推荐，不是自动负载均衡。外部客户端连接哪台 A，就从哪台 A 进入。
