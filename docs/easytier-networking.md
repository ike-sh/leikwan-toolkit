# EasyTier 组网

Leikwan Toolkit 1.4.0 使用 EasyTier 作为 A 公网入口机和 B 利群主机之间的虚拟网络。脚本只管理 EasyTier 组网和 nftables 四层 TCP/UDP 转发，不部署后端代理协议。

默认地址：

```text
RELAY_ET_IP=10.198.1.1
ENTRY_ET_IP=10.198.1.2
ET_NET=10.198.1.0/24
```

默认端口：

```text
EASYTIER_PROTOCOLS=tcp,udp
EASYTIER_TCP_PORT=8301
EASYTIER_UDP_PORT=8301
EASYTIER_PROTOCOL=tcp
EASYTIER_PORT=8301
```

本项目默认 EasyTier 端口是 `8301` 的 TCP+UDP 双协议监听，位于利群推荐 `8000-9000` 白名单端口段。`11010` 只是 EasyTier 官方常见示例端口，不作为本项目默认值。旧配置只有 `EASYTIER_PROTOCOL=tcp` 时仍保持 TCP 单协议。

## 安装器

脚本会优先复用已经可用的：

```text
/usr/local/bin/easytier-core
/usr/local/bin/easytier-cli
```

缺失时按以下流程安装：

1. 默认 `LEIKWAN_GITHUB_DOWNLOAD_MODE=mirror-first`，先尝试镜像池，官方 GitHub 最后兜底。
2. 先构造确定性 Release URL，不让 GitHub API 慢请求阻塞大文件下载。
3. 每个 EasyTier asset URL 按镜像池、官方 GitHub 的顺序尝试，并做轻量预检。
4. 单个源使用短超时和低速失败切源，不在慢源上重复 retry。
5. 文件大小必须大于 10MB，且 `unzip -t` 或 `tar -tzf` 校验通过后才安装。
6. 下载成功后缓存到 `/var/cache/leikwan-toolkit/downloads`，下次同版本优先复用。
7. 如果所有确定性 URL 失败，GitHub API metadata 只作为辅助兜底。
8. 全部失败时，允许选择 `/root/easytier*.zip`、`/root/easytier*.tar.gz` 或当前目录本地包。

内置镜像只作为加速候选，不会成为唯一入口。官方 GitHub 始终保留为兜底候选。

可自定义镜像：

```bash
export LEIKWAN_GITHUB_MIRRORS="https://gh-proxy.com/,https://gh.llkk.cc/,https://gh.ddlc.top/,https://ghproxy.net/,https://mirror.ghproxy.com/,https://cf.ghproxy.cc/,https://gh.api.99988866.xyz/,https://github.akams.cn/"
```

需要改回官方 GitHub 优先时：

```bash
export LEIKWAN_GITHUB_DOWNLOAD_MODE=origin-first
```

如果下载仍失败：

1. 先执行 `lq system network prepare`，快速组网也会自动执行这一步。
2. 设置 `LEIKWAN_GITHUB_MIRRORS` 指定你可用的镜像。
3. 手动下载 EasyTier zip 后，在安装器提示时输入本地路径。

解包后脚本通过 `find` 查找 `easytier-core` 和 `easytier-cli`，不假设目录结构。

## 验证

```bash
systemctl status easytier-relay --no-pager
systemctl status 'easytier-entry-*' --no-pager
easytier-cli peer
ip -br addr
ping 10.198.1.1
ping 10.198.1.2
```

relay 重启后的检测会等待 service active、Relay EasyTier IP 就绪，并重试读取 `easytier-cli peer`。如果 peer 列表暂时没刷新但 EasyTier IP ping 成功，脚本会按已连通处理；只有 peer 未确认且 ping 失败时才 WARN。
