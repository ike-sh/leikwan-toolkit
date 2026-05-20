# forwards.tsv

转发目标是任意 TCP 或 UDP 后端。脚本只需要知道入口端口和后端地址。

路径：

```text
/etc/leikwan-toolkit/forwards/forwards.tsv
```

格式是 **8 列 TAB 分隔**，不是空格对齐：

```text
name  entry_port  target_host     target_port  out_iface  route_table  enabled  comment
service-a  10001  203.0.113.30    37592        eth1       T_CN2        true     main-target
service-b  10002  target.example  37593                   T_9929       true     backup-target
```

默认推荐用菜单或 `lq forward` 命令，不要手写 TSV。Leikwan Toolkit 1.4.0 的转发模型是：

- A 公网入口机只配置一次入口端口池。
- B 利群主机负责所有后端目标的新增 / 修改 / 删除 / 应用。
- A 不需要知道每个 `target_host` / `target_port`。

A 公网入口机先执行一次：

```bash
sudo lq entry expose-range --range 10001-10020 --relay-ip 10.198.1.1
```

这会把该端口池全部 DNAT 到 `10.198.1.1`，保持原端口。需要更大范围时可配置 `10001-19999`。

A 侧端口池默认同时生成 TCP 和 UDP DNAT。业务入口端口例如 `10001` 不受 EasyTier `8000-9000` 白名单限制；`8000-9000` 只用于 EasyTier 组网端口。

B 利群主机添加后端：

```bash
sudo lq forward add
```

以后只在 B 上管理：

```bash
sudo lq forward edit service-a
sudo lq forward delete service-a
sudo lq forward list
sudo lq forward apply-relay
```

修改、删除、启用/禁用、测试单个目标都会先展示列表，支持编号或名称选择。

导出的 `forward-endpoints.txt` 会把业务转发标成 `TCP+UDP`，并分别展示 `TCP=UP/DOWN/UNKNOWN` 与 `UDP=PROBED/UNKNOWN`。UDP 探测只是参考，不会阻断转发目标保存。

菜单入口：

```text
利群主机 -> 转发目标管理
```

`forward import` 只保留为 legacy / 高级兼容，不再是默认流程。

手写 `forwards.tsv` 只适合高级用户，并且只应该在 B relay 上维护。如果必须命令行写入，请用 `printf` 明确输出 TAB，不要手工用空格排版：

```bash
sudo install -d -m 700 /etc/leikwan-toolkit/forwards
{
  printf '# name\tentry_port\ttarget_host\ttarget_port\tout_iface\troute_table\tenabled\tcomment\n'
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    'service-a' '10001' '203.0.113.30' '37592' 'eth1' 'T_CN2' 'true' 'main-target'
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    'service-b' '10002' 'target.example' '37593' '' 'T_9929' 'true' 'backup-target'
} | sudo tee /etc/leikwan-toolkit/forwards/forwards.tsv >/dev/null
```

写坏成 `service-a10001203.0.113.3037592truecomment` 这类“粘在一起”的内容时，脚本会停止解析并拒绝应用 nftables，避免生成空转发表。

字段说明：

- `name`：转发目标名称。
- `entry_port`：公网入口端口，必须唯一。
- `target_host`：后端 IP 或域名。
- `target_port`：后端业务端口。
- `out_iface`：可选出口接口。
- `route_table`：可选 PBR 表，例如 `T_CN2`。
- `enabled`：`true` 或 `false`。
- `comment`：备注。

默认协议语义：

- 旧 8 列格式继续兼容，不需要新增协议列。
- 每一行默认同时创建 TCP 和 UDP 转发：`tcp entry_port -> target_port` 与 `udp entry_port -> target_port`。
- 如果后端只有 TCP，UDP 规则存在也不会影响 TCP。
- 如果后端支持 UDP，外部 UDP 可以走同一个 `entry_port`。
- 以后如需单独控制协议，再增加可选协议字段。

保留端口如 `22`、`80`、`443`、`8301` 默认会要求二次确认。

域名解析结果写入：

```text
/etc/leikwan-toolkit/forwards/resolved.tsv
```

`resolved.tsv` 字段：

```text
name  entry_port  target_host  resolved_ip  target_port  out_iface  route_table  enabled  last_resolved_at  comment
```

如果 `target_host` 是域名，`apply-relay` 每次都会重新解析。解析失败时，有上次 IP 就继续使用上次 IP；没有上次 IP 则跳过该目标并 WARN。

1.4.0 起 DDNS 自动刷新可覆盖后端转发目标、公网入口域名和域名 PBR：

```bash
sudo lq ddns enable
sudo lq ddns status
```

DDNS 刷新会检查 enabled 转发目标中的域名后端。forward IP 变化时会更新 `resolved.tsv`，创建自动快照，并安全重应用 nftables；IP 未变化时不会重复 apply。带 `route_table` 的域名 forward 可通过 `DDNS_AUTO_SYNC_FORWARD_PBR=true` 自动同步 `forward:<name>` 来源 PBR。
