# 多公网入口

Leikwan Toolkit 支持在同一台 B 利群主机上接入多台 A 公网入口。多入口用于手动切换、主备推荐和输出排序，不是 B 侧自动负载均衡。

外部客户端连接哪台 A，就从哪台 A 的公网地址进入。`weight` 只影响输出清单和 doctor 中的 PRIMARY / BACKUP 排序。

## 默认命名

新入口默认使用 ASCII 内部名，并在中文 UI 中显示为正式名称：

```text
public1 -> 公网1
public2 -> 公网2
public3 -> 公网3
```

示例：

```text
1) 公网1(public1)  203.0.113.10  10.198.1.2  tcp+udp  8301  weight=100 enabled
2) 公网2(public2)  203.0.113.20  10.198.1.3  tcp+udp  8302  weight=100 enabled
```

旧入口名继续兼容，不会被自动改名。

## entries.tsv

路径：

```text
/etc/leikwan-toolkit/entries/entries.tsv
```

格式保持 7 列：

```text
entry_name  public_host     et_ip        easytier_protocol  easytier_port  weight  enabled
public1     203.0.113.10    10.198.1.2   tcp,udp            8301           100     true
public2     entry.example   10.198.1.3   tcp                8302           100     true
public3     203.0.113.30    10.198.1.4   udp                8303           50      false
```

`easytier_protocol` 允许 `tcp`、`udp`、`tcp,udp`。`tcp,udp` 会渲染为两个 peer：

```text
tcp://203.0.113.10:8301
udp://203.0.113.10:8301
```

旧 TCP 单协议入口仍只生成 TCP peer。

## pending reservation

生成网络码后，B 会把推荐值写入：

```text
/etc/leikwan-toolkit/entries/pending-entries.tsv
```

pending 字段：

```text
name  et_ip  protocols  port  created_at
```

ENTRY 返回码接回 B 后，脚本按 `ENTRY_ET_IP + EASYTIER_PORT` 清理对应 pending。若 A 侧修改了入口名称，B 会按 ENTRY 返回名称保存，并清理命中的 pending。

## 切换主入口

菜单路径：

```text
利群主机 -> 公网入口列表管理 -> 切换主公网入口
```

模式：

- 只启用选中的入口：用于手动切换，应用 relay 后只保留该入口 peer。
- 选中入口作为 PRIMARY，保留其它 enabled：用于主备推荐和输出排序。

变更后会提示是否现在重启 relay。默认 `N`，避免中断现有入口。
