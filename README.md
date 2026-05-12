# Leikwan Toolkit

Leikwan Toolkit 是一个基于 Shell 的快速组网、入口管理、转发管理与诊断工具。

当前仓库只维护 **Shell 脚本版 LTS**：

- `leikwan-toolkit.sh`
- `scripts/bootstrap.sh`
- Shell 版状态查看、诊断、DDNS、PBR、转发管理、快照与维护能力

Web 面板、Controller、Agent、前端页面等代码已经迁移到独立仓库。

## 当前稳定版本

```text
Leikwan Toolkit 1.4.0 LTS
```

`1.4.0 LTS` 是 Shell 版功能冻结稳定线。后续本仓库只建议做严重 Bug 修复、兼容性修复和文档维护，不再继续承载 Panel 主线功能。

## Panel 已迁移

Web 面板 / Controller / Agent / EasyTier 面板化管理已经迁移到新仓库：

```text
https://github.com/ike-sh/edge-tunnel-panel
```

如果你需要以下功能，请使用新仓库：

- Web 主控面板
- Agent 节点接入
- 一键添加节点
- EasyTier 组网
- TCP / UDP 转发
- PBR 出口策略
- DDNS
- Web 可视化管理

本仓库不再维护 Panel 代码。

## 一键安装 Shell 版

```bash
curl -fsSL -o /tmp/lq-bootstrap.sh https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/scripts/bootstrap.sh
bash /tmp/lq-bootstrap.sh
lq
```

如果 GitHub 网络不稳定，可以使用镜像环境变量：

```bash
export LEIKWAN_GITHUB_MIRRORS="https://gh.llkk.cc/,https://gh.ddlc.top/,https://gh-proxy.com/,https://ghproxy.net/"
curl -fsSL -o /tmp/lq-bootstrap.sh https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/scripts/bootstrap.sh
bash /tmp/lq-bootstrap.sh
lq
```

## 常用命令

```bash
lq
lq --version
lq status
lq status --verbose
lq doctor
```

## Shell 版功能范围

Shell 版仍保留以下能力：

- 快速组网辅助
- 公网入口配置
- 利群中转配置
- 转发目标管理
- TCP / UDP 转发配置
- DDNS 检测与刷新
- PBR 出口策略
- 状态查看
- 诊断检查
- 快照与恢复辅助
- 高级维护入口

这些能力均通过 `lq` / `leikwan-toolkit.sh` 在本机交互式执行，不依赖 Web 面板。

## 项目边界

本仓库只保留 Shell LTS 线。

不包含：

- Web Panel
- Controller
- Agent
- React 前端
- Go Controller / Agent
- 面板安装脚本
- 面板发布包
- Edge Tunnel Panel 代码

这些内容已经迁移到：

```text
https://github.com/ike-sh/edge-tunnel-panel
```

## 目录说明

```text
leikwan-toolkit.sh              Shell 主脚本
scripts/bootstrap.sh            Shell 版安装脚本
scripts/check-redaction.sh      脱敏检查脚本
docs/                           Shell 版文档
tests/                          Shell 版回归测试
```

## 建议保留的文档

建议 `docs/` 目录只保留 Shell 相关文档，例如：

```text
docs/final-guide.md
docs/cli.md
docs/release-notes.md
docs/status.md
docs/doctor.md
docs/workflow.md
docs/troubleshooting.md
docs/acceptance-test.md
docs/ddns-refresh.md
docs/architecture.md
docs/uninstall.md
```

如果仓库中仍有 Panel / Controller / Agent 相关历史文档，建议删除或迁移到：

```text
https://github.com/ike-sh/edge-tunnel-panel
```

## 清理 Panel 残留

如果你要把旧仓库恢复成 Shell LTS 仓库，可以手动删除：

```powershell
cd D:\leikwan-toolkit

Remove-Item -Recurse -Force .\panel -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force .\dist\panel* -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force .\dist\leikwan-panel* -ErrorAction SilentlyContinue
```

然后检查残留：

```powershell
rg -n "Panel|Controller|Agent|edge-tunnel-panel|Edge Tunnel|3\.0\.0|2\.2\.0|2\.1\.0|LEIKWAN_OPERATOR_TOKEN|write_actions|Action Catalog|Safety Gate" README.md docs scripts tests leikwan-toolkit.sh
```

README 中保留“Panel 已迁移到 edge-tunnel-panel”的说明是可以的；其他 Panel 主线代码和文档建议删除。

## 检查 Shell 脚本

```bash
bash -n leikwan-toolkit.sh
bash -n scripts/bootstrap.sh
```

如果有测试脚本，也可以运行对应回归测试：

```bash
bash tests/final-menu-regression.sh
bash tests/final-readme-regression.sh
```

## 版本策略

`1.4.0 LTS` 是 Shell 版稳定线。

后续规划：

```text
ike-sh/leikwan-toolkit
= Shell 脚本 LTS 仓库

ike-sh/edge-tunnel-panel
= Panel / Controller / Agent / Web 主线仓库
```

## License

请根据仓库实际许可证文件为准。
