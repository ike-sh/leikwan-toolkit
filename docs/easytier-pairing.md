# EasyTier 配对码

配对码用于在 B 利群主机和 A 公网入口之间传递 EasyTier network name、network secret、入口建议值和 ENTRY 返回信息。配对码包含敏感信息，不应公开。

## B 生成公网入口接入码

B 生成 NETWORK 接入码时，会推荐下一个公网入口：

```text
SUGGESTED_ENTRY_NAME=public1
SUGGESTED_ENTRY_DISPLAY_NAME=公网1
SUGGESTED_ENTRY_ET_IP=10.198.1.2
SUGGESTED_EASYTIER_PROTOCOLS=tcp,udp
SUGGESTED_EASYTIER_TCP_PORT=8301
SUGGESTED_EASYTIER_UDP_PORT=8301
SUGGESTED_EASYTIER_PROTOCOL=tcp
SUGGESTED_EASYTIER_PORT=8301
```

新字段 `SUGGESTED_EASYTIER_PROTOCOLS` 优先。旧网络码如果只有 `SUGGESTED_EASYTIER_PROTOCOL=tcp` 和 `SUGGESTED_EASYTIER_PORT=8301`，A 侧会继续按 TCP 单协议部署。

生成网络码后，B 会写入 pending reservation，避免连续生成时重复推荐 EasyTier IP 或端口。

## A 粘贴网络码并部署入口

A 会读取网络码中的建议值，并允许修改：

- 本机公网入口名称
- 本机 EasyTier IP
- EasyTier 传输模式：`tcp+udp`、`tcp`、`udp`
- EasyTier 监听端口
- 本机公网 IP / 域名

默认传输模式是 TCP+UDP，同端口监听：

```text
tcp://0.0.0.0:8301
udp://0.0.0.0:8301
```

EasyTier 组网端口应位于 `8000-9000`。这不是业务入口端口。

## A 生成公网入口返回码

A 部署成功后生成 ENTRY 返回码：

```text
ENTRY_NAME=public1
ENTRY_DISPLAY_NAME=公网1
ENTRY_PUBLIC_HOST=203.0.113.10
ENTRY_ET_IP=10.198.1.2
EASYTIER_PROTOCOLS=tcp,udp
EASYTIER_TCP_PORT=8301
EASYTIER_UDP_PORT=8301
EASYTIER_PROTOCOL=tcp
EASYTIER_PORT=8301
WEIGHT=100
ENABLED=true
```

B 接入 ENTRY 时优先读取 `EASYTIER_PROTOCOLS`。旧 ENTRY 如果只有 `EASYTIER_PROTOCOL=tcp`，仍保持 TCP 单协议 peer。

## pending 与改名

如果 pending 是：

```text
public2  10.198.1.3  tcp,udp  8302
```

但 A 返回：

```text
ENTRY_NAME=shanghai
ENTRY_ET_IP=10.198.1.3
EASYTIER_PORT=8302
```

B 会保存为 `shanghai`，并清理 `public2` pending。正式入口的 `entries.tsv` 冲突仍会被拒绝。

## 输出顺序

脚本输出配对码时会按以下顺序显示：

1. 简短摘要
2. 多行码
3. 下一步提示
4. 单行码

单行码放在最后一行，方便在 SSH 终端中复制。
