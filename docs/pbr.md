# IPv4 多出口策略路由 / PBR

PBR 用来把指定后端 IPv4 固定到某个出口线路，例如 `T_CN2` 或 `T_9929`。它只处理 IPv4，不接管整机默认路由。

菜单：

```text
IPv4 多出口策略路由 / PBR
1. 添加静态 PBR
2. 从现有转发目标添加 PBR
3. 删除 PBR 规则
4. 应用 PBR
5. 查看 PBR
6. 域名 PBR 管理
0. 返回
```

## 静态 PBR

静态 PBR 只接受 IPv4 或 CIDR：

```text
203.0.113.10
203.0.113.0/24
```

静态规则写入：

```text
/etc/leikwan-toolkit/pbr/static-routes.conf
```

格式：

```text
203.0.113.10/32 CN2 static
```

`static` 规则由用户显式管理，DDNS 同步不会自动删除。

## 从转发目标添加 PBR

当 forward 有 `route_table` 时，可以用当前 resolved IP 生成 `forward:<name>` 来源 PBR。
在转发 / PBR 场景中，如果多个 DNS 解析器返回不同 IPv4，脚本会优先选择出现次数最多且至少出现两次的多数结果；没有多数结果时才回退到 `DNS_RESOLVE_STRATEGY`。这不会改变 DDNS 全局检测策略。

同步命令：

```bash
sudo lq pbr sync-from-forwards
```

它会删除旧的 `forward <name> <host>` 来源规则，再按当前 `resolved.tsv` 和 `route_table` 生成新的 `/32` 规则。用户手写 `static` PBR 和 `pbr-domain:<name>` 规则不会被删除。

DDNS 后端刷新时，如果 `DDNS_AUTO_SYNC_FORWARD_PBR=true`，forward 域名 IP 变化会自动执行同等同步，并在统一流程中只应用一次 PBR。

## 域名 PBR

域名 PBR 用于这类需求：

```text
tw.example.com -> T_CN2
```

CLI：

```bash
lq pbr domain add
lq pbr domain list
lq pbr domain delete
lq pbr domain sync
```

菜单：

```text
域名 PBR 管理
1. 添加域名 PBR
2. 查看域名 PBR
3. 删除域名 PBR
4. 立即同步域名 PBR
0. 返回
```

定义文件：

```text
/etc/leikwan-toolkit/pbr/domain-routes.tsv
```

格式：

```text
# name host route_table enabled comment
tw tw.example.com T_CN2 true tw-ddns-pbr
```

解析缓存：

```text
/etc/leikwan-toolkit/pbr/resolved-pbr-domains.tsv
```

同步后会在 `static-routes.conf` 中生成来源明确的规则：

```text
203.0.113.45/32 CN2 pbr-domain:tw tw.example.com
```

规则说明：

- 添加域名 PBR 时，host 必须是域名，不能是纯 IPv4。
- 添加后会立即解析域名，解析失败不写入。
- `lq pbr domain sync` 只同步 `pbr-domain:<name>` 来源规则。
- 域名 IP 变化时，旧 `pbr-domain:<name>` 规则会被替换为新的 `/32`。
- 如果相同 CIDR / table 已有 static 规则，脚本不会重复添加，会保留用户规则。

## 自动管理边界

DDNS 和同步命令只自动管理两类来源：

- `forward:<name>`：由 `lq pbr sync-from-forwards` 管理。
- `pbr-domain:<name>`：由 `lq pbr domain sync` 管理。

不会自动删除：

- `static`
- 旧版本手写且无来源标记的 PBR
- 其它手动维护规则

## 删除 PBR 规则

普通删除请进入 PBR 规则删除入口。脚本会先展示当前 PBR 规则列表：

```text
编号  目标网段              路由表      来源
1. 203.0.113.10/32      T_CN2      static
2. 198.51.100.20/32     T_CN2      forward:tw tw.example.com
3. 203.0.113.45/32      T_CN2      pbr-domain:tw tw.example.com
```

可以输入编号、完整 CIDR，或裸 IP。裸 IP 会按 `/32` 匹配。删除前会确认，确认后从 `static-routes.conf` 删除对应行并重新应用 PBR。

删除域名 PBR 请使用 `lq pbr domain delete` 或域名 PBR 菜单；它会同时清理 `domain-routes.tsv`、`resolved-pbr-domains.tsv` 和 `pbr-domain:<name>` 来源规则，不会删除 static 规则。

## 应用

```bash
sudo lq --pbr-apply
sudo lq pbr apply
sudo lq forward apply-relay --auto-fix-route
```

从现有转发目标添加 PBR 后，脚本会默认询问是否立即重新应用利群转发规则并同步 `route_table`，等价于执行 `lq forward apply-relay --auto-fix-route`。选择稍后应用时，PBR 会保留，但转发目标元数据需要在维护窗口手动同步。
