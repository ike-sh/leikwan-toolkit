# 自更新与安全回滚

Leikwan Toolkit 1.4.13 LTS 保持 Shell 自更新能力。自更新只使用 GitHub Release 包和对应 `.sha256`，不会直接拉取 raw main 分支脚本作为更新产物。

## 检查版本

```bash
lq update check
lq --update-check
```

`update check` 会先读取磁盘上的 `/root/leikwan-toolkit.sh --version` 作为当前安装版本，再显示当前菜单进程内的运行版本。

1.4.13 起，latest 检测默认使用轻量 `fast` 元数据策略：

1. 读取仓库根目录 `VERSION` 文件。
2. 请求官方 GitHub API `releases/latest`。
3. 解析官方 `releases/latest` redirect。
4. 请求官方 tags API，并按 semver 选择最大版本。

默认不会把 `api.github.com` 或 `releases/latest` redirect 套进整套大文件下载镜像池里轮询。

成功示例：

```text
[INFO] 当前安装版本：1.4.13
[INFO] 当前运行进程：1.4.13
[INFO] 正在获取最新版本，模式：fast
[INFO] 正在读取 VERSION：...
[INFO] 最新版本：1.4.13
[OK] 当前已是最新版本。
```

失败示例：

```text
[WARN] 无法快速获取最新版本。
[INFO] 可直接选择“更新到最新版本”，或设置 LEIKWAN_TARGET_VERSION=1.4.13 后重试。
[INFO] 如需完整探测，可设置 LEIKWAN_GITHUB_METADATA_MODE=full。
```

## 元数据策略

默认：

```bash
export LEIKWAN_GITHUB_METADATA_MODE=fast
```

支持值：

- `fast`：只做轻量 VERSION / 官方 API / 官方 redirect / 官方 tags 查询，总耗时受限。
- `full`：用于手动排查，可尝试更多 metadata fallback，但仍使用短 timeout 和总耗时保护。

如需为 metadata 查询显式指定少量镜像：

```bash
export LEIKWAN_GITHUB_METADATA_MIRRORS="https://gh-proxy.com/,https://gh.llkk.cc/"
```

这与大文件下载镜像池 `LEIKWAN_GITHUB_MIRRORS` 是两条策略线。

## 大文件下载策略

release tar.gz、`.sha256` 和 EasyTier release asset 下载仍使用 `LEIKWAN_GITHUB_DOWNLOAD_MODE=mirror-first`：

```bash
export LEIKWAN_GITHUB_DOWNLOAD_MODE=mirror-first
```

官方 GitHub 仍作为最后 fallback。sha256 校验是强制步骤，不应跳过。

## 执行更新

```bash
lq update run
lq --self-update
```

如果 latest 无法确定，更新会取消，不会构造空版本下载 URL：

```text
[ERROR] 无法确定最新版本，已取消更新。
[INFO] 可设置 LEIKWAN_TARGET_VERSION=1.4.13 后重试。
```

也可以手动指定目标版本并跳过 latest 检测：

```bash
export LEIKWAN_TARGET_VERSION=1.4.13
lq update run
```

`LEIKWAN_TARGET_VERSION` 必须是 `X.Y.Z` 或 `vX.Y.Z`。

## VERSION 文件

仓库根目录 `VERSION` 文件只包含当前最新版本号，例如：

```text
1.4.13
```

发布时 `VERSION` 必须与 `TOOL_VERSION` 一致，并随 release 包一起发布。`scripts/build-release.sh` 会校验这一点。

## sha256 兼容

Release `.sha256` 推荐格式：

```text
hash  leikwan-toolkit-1.4.13.tar.gz
```

自更新校验兼容三种格式：

- `hash  basename`
- `hash  /old/absolute/path`
- 只包含 `hash`

## 回滚

```bash
lq update rollback
```

回滚会根据 `last-update.env` 找到最近备份，恢复旧脚本，并把最近更新结果记录为 `rollback`。
