# 自更新与安全回滚

Leikwan Toolkit 1.4.7 LTS 保持 Shell 自更新能力。自更新只使用 GitHub Release 包和对应 `.sha256`，不会直接拉取 raw main 分支脚本作为更新产物。

## 检查版本

```bash
lq update check
lq --update-check
```

`update check` 会先读取磁盘上的 `/root/leikwan-toolkit.sh --version` 作为当前安装版本，再显示当前菜单进程内的运行版本。1.4.7 起，最新版本检测按顺序尝试：

1. GitHub API `releases/latest`
2. `releases/latest` redirect
3. GitHub tags API，按 semver 选择最大版本
4. GitHub releases HTML fallback

任一方法成功都会输出非空版本，例如：

```text
[INFO] 当前安装版本：1.4.7
[INFO] 当前运行进程：1.4.7
[INFO] 正在获取最新版本，策略：mirror-first
[INFO] 最新版本：1.4.7
[OK] 当前已是最新版本：1.4.7
```

如果所有路径失败，脚本不会输出空 latest，也不会构造下载 URL：

```text
[WARN] 无法获取最新版本：GitHub API / latest redirect / tags 均失败。
[INFO] 可直接尝试“更新到最新版本”，或检查网络 / 镜像配置。
```

## 下载策略

1.4.7 默认使用镜像优先：

```bash
export LEIKWAN_GITHUB_DOWNLOAD_MODE=mirror-first
```

支持值：

- `mirror-first`：先尝试镜像池，再尝试官方 GitHub。
- `origin-first`：先尝试官方 GitHub，再尝试镜像池。

默认镜像池：

```bash
export LEIKWAN_GITHUB_MIRRORS="https://gh-proxy.com/,https://gh.llkk.cc/,https://gh.ddlc.top/,https://ghproxy.net/,https://mirror.ghproxy.com/,https://cf.ghproxy.cc/,https://gh.api.99988866.xyz/,https://github.akams.cn/"
```

镜像不可用时会快速切换，官方 GitHub 仍作为最后 fallback。需要改回官方优先时：

```bash
export LEIKWAN_GITHUB_DOWNLOAD_MODE=origin-first
```

## 执行更新

```bash
lq update run
lq --self-update
```

更新流程：

1. 获取 latest release 版本。
2. 下载 `leikwan-toolkit-X.Y.Z.tar.gz`。
3. 下载 `leikwan-toolkit-X.Y.Z.tar.gz.sha256`。
4. 校验 sha256。
5. 解包并取出 `leikwan-toolkit.sh`。
6. 执行 `bash -n`。
7. 执行新脚本 `--version`。
8. 备份当前 `/root/leikwan-toolkit.sh`。
9. 替换脚本并修复 `/usr/local/bin/lq` / `/usr/local/bin/LQ`。
10. 再次检查 `/root/leikwan-toolkit.sh --version` 和 `lq --version`。

如果 latest 无法确定，更新会直接取消：

```text
[ERROR] 无法确定最新版本，已取消更新。
[INFO] 可设置 LEIKWAN_TARGET_VERSION=1.4.7 后重试。
```

也可以手动指定目标版本：

```bash
export LEIKWAN_TARGET_VERSION=1.4.7
lq update run
```

## sha256 兼容

Release `.sha256` 推荐格式：

```text
hash  leikwan-toolkit-1.4.7.tar.gz
```

自更新校验兼容三种格式：

- `hash  basename`
- `hash  /old/absolute/path`
- 只包含 `hash`

sha256 校验是强制步骤，不应跳过。

## 回滚

```bash
lq update rollback
```

回滚会根据 `last-update.env` 找到最近备份，恢复旧脚本，并把最近更新结果记录为 `rollback`。
