# nftables 转发

Leikwan Toolkit 1.4.0 只管理本项目自己的表：

```text
table inet leikwan_forward
```

脚本不会 `flush ruleset`，也不会清空用户已有防火墙规则。

## cloud-entry

公网入口机 A 只配置一次入口端口池：

```bash
sudo lq entry expose-range --range 10001-10020 --relay-ip 10.198.1.1
```

生成的核心规则是：

```text
tcp dport 10001-10020 dnat ip to 10.198.1.1
udp dport 10001-10020 dnat ip to 10.198.1.1
```

注意这里不指定 DNAT 目标端口，因此会保持原始端口：

```text
A_PUBLIC_HOST:10001 -> 10.198.1.1:10001
A_PUBLIC_HOST:10002 -> 10.198.1.1:10002
```

A 不需要读取 `target_host`，也不需要为每个后端重复导入转发码。A 侧入口端口池默认同时处理 TCP 和 UDP。

## leikwan-relay

B 利群主机负责所有后端目标：

```bash
sudo lq forward add
sudo lq forward edit service-a
sudo lq forward delete service-a
sudo lq forward apply-relay
```

B 侧根据 `forwards.tsv` 生成每个后端的 DNAT：

```text
tcp 10.198.1.1:ENTRY_PORT -> TARGET_HOST:TARGET_PORT
udp 10.198.1.1:ENTRY_PORT -> TARGET_HOST:TARGET_PORT
```

`forwards.tsv` 仍保持 8 列，不新增协议字段。旧 8 列行默认代表 TCP+UDP 同端口转发；如果后端只有 TCP，UDP 规则不会影响 TCP 使用。

多公网入口只影响可用 A 入口 peer 和输出清单排序，不是 B 侧自动负载均衡。外部客户端从哪个 A 的公网地址进入，就命中该 A 的端口池规则；PRIMARY / BACKUP 只是推荐提示。

如果 `TARGET_HOST` 是域名，会先解析为 IPv4 并写入：

```text
/etc/leikwan-toolkit/forwards/resolved.tsv
```

启用 DDNS 自动刷新后，timer 会监控 enabled 域名后端、公网入口域名和域名 PBR。后端解析 IP 变化时，脚本会更新 `resolved.tsv` 并使用同一套安全 apply-relay 逻辑重渲染 nftables；IP 未变化时不会重复应用规则。

## TCP MSS clamp

EasyTier/tun 叠加 A/B 两侧 NAT 时，部分后端 TCP 协议会遇到 MTU/MSS 问题，表现为：

- 后端直连成功。
- 经 A -> EasyTier -> B 转发后有延迟、有握手迹象，但应用层连接失败。

脚本默认在 A 和 B 的 `leikwan_forward` 表中加入：

```text
tcp flags syn tcp option maxseg size set 1320
```

该规则位于 `forward` hook，随 `/etc/leikwan-toolkit/nft/leikwan-forward.nft` 和 `leikwan-nft-forward.service` 持久化，不需要手工创建临时 `lq_mss` 表。

`doctor` 和“查看状态”会检测当前 nftables 规则。交互菜单发现 MSS clamp 缺失时会询问是否重新应用规则；非交互 `lq --doctor` 只提示命令，不会自行修改。执行入口端口池应用或利群转发规则应用时，脚本会重新渲染 nftables；如果默认开启 MSS clamp，会明确输出 `已自动启用 TCP MSS clamp: 1320`。

默认 MSS clamp 是 `1320`。如仍不稳定，可降到 `1280` 或故障兜底值 `1200`：

```bash
sudo install -d -m 700 /etc/leikwan-toolkit/nft
printf 'TCP_MSS_CLAMP=1280\nENABLE_MSS_CLAMP=true\n' | sudo tee /etc/leikwan-toolkit/nft/mss.env >/dev/null
```

也可以临时用环境变量覆盖：

```bash
sudo env LEIKWAN_TCP_MSS_CLAMP=1200 lq forward apply-relay
```

如果当前 SSH 连接可能经过公网入口、EasyTier 或正在修改的转发链路，建议后台应用 B 侧转发规则：

```bash
nohup lq forward apply-relay --auto-fix-route >/root/lq-apply-relay.log 2>&1 &
tail -f /root/lq-apply-relay.log
lq --doctor
```

## ip_forward

A 和 B 都需要：

```text
net.ipv4.ip_forward=1
```

脚本写入独立文件：

```text
/etc/sysctl.d/99-leikwan-forward.conf
```
