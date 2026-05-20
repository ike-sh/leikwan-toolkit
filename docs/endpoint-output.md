# 转发端点分享输出

Leikwan Toolkit 1.4.0 会生成更完整的端点分享文件，方便把公网入口发给使用方或交给脚本读取。

## 生成

```bash
lq output generate
```

交互模式可从“高级维护 -> 端点输出”进入。

输出路径：

```text
/etc/leikwan-toolkit/outputs/forward-endpoints.txt
/etc/leikwan-toolkit/outputs/forward-endpoints.tsv
/etc/leikwan-toolkit/outputs/forward-endpoints.json
/etc/leikwan-toolkit/outputs/forward-endpoints.html
```

也可以直接查看：

```bash
lq output show
lq output json
lq output html
```

HTML 是静态文件，不需要 Web 服务。JSON 包含版本、生成时间、enabled entries、enabled forwards 和每个 TCP / UDP endpoint。HTML 会转义 forward name、comment、target_host 和 public_host 等用户输入字段。

## 内容

端点输出包含：

- 生成时间和脚本版本
- PRIMARY / BACKUP 入口
- enabled entries
- enabled forwards
- 转发目标 name、entry_port、target_host、target_port、route_table、comment
- 公网入口 label、public_host、TCP endpoint、UDP endpoint、enabled 状态

端点输出不包含：

- EasyTier network secret
- 配对码 base64
- token / password
- 任何代理协议链接

它只是端点分享，例如：

```text
tcp://entry.example.com:10001
udp://entry.example.com:10001
```

## QR

如果系统已安装 `qrencode`：

```bash
lq output qr
```

脚本会生成：

```text
/etc/leikwan-toolkit/outputs/qr/
```

每个二维码只包含 endpoint 字符串，不是代理链接。未安装 `qrencode` 时会提示并跳过，不会强制安装。

## 配置包集成

`lq config export` 会把 txt / tsv / json / html 端点输出放入配置包的 `outputs/` 目录。脱敏包也可以包含这些文件，因为它们不含 secret。
