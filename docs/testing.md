# 测试与 release 验证

Leikwan Toolkit 1.4.0 增加正式回归测试入口，用于发布前检查 CLI、渲染、打包和脱敏边界。

## 一键验证

```bash
bash scripts/verify-release.sh
```

它会按顺序执行：

```bash
bash -n leikwan-toolkit.sh scripts/package-release.sh scripts/check-redaction.sh scripts/bootstrap.sh
shellcheck leikwan-toolkit.sh scripts/package-release.sh scripts/check-redaction.sh scripts/bootstrap.sh
git diff --check
bash scripts/check-redaction.sh
bash tests/smoke.sh
bash tests/cli-regression.sh
bash tests/render-regression.sh
bash tests/final-menu-regression.sh
bash tests/final-readme-regression.sh
bash tests/entry-port-pool-message-regression.sh
bash tests/pbr-forward-domain-resolution-regression.sh
bash tests/pbr-apply-forward-majority-regression.sh
bash tests/doctor-forward-pbr-dns-split-regression.sh
bash tests/forward-route-table-sync-regression.sh
bash tests/forward-domain-resolution-regression.sh
bash tests/domain-pbr-message-regression.sh
bash tests/system-network-menu-regression.sh
bash tests/quickstart-network-prepare-regression.sh
bash tests/ipv4-prefer-regression.sh
bash tests/dns-config-regression.sh
bash tests/ipv6-disable-restore-regression.sh
bash tests/ipv6-nft-lockdown-regression.sh
bash tests/system-network-cli-regression.sh
bash tests/role-detection-regression.sh
bash tests/doctor-reset-regression.sh
bash tests/compact-output-regression.sh
bash tests/ddns-summary-regression.sh
bash tests/entry-ddns-regression.sh
bash tests/ddns-menu-regression.sh
bash tests/ddns-overview-regression.sh
bash tests/ddns-noninteractive-autoswitch-regression.sh
bash tests/ddns-restart-cooldown-regression.sh
bash tests/ddns-consistency-regression.sh
bash tests/health-score-regression.sh
bash tests/update-regression.sh
bash tests/update-latest-version-regression.sh
bash tests/update-latest-no-risky-download-regression.sh
bash tests/update-empty-latest-guard-regression.sh
bash tests/package-regression.sh
bash tests/github-mirror-download-regression.sh
bash tests/easytier-download-mirror-regression.sh
bash tests/bootstrap-mirror-first-regression.sh
bash tests/tmpdir-fallback-regression.sh
bash tests/build-release-regression.sh
bash tests/uninstall-regression.sh
bash tests/lock-regression.sh
bash tests/redaction-regression.sh
bash scripts/package-release.sh
```

任一步失败都会退出非零。全部通过时输出：

```text
[OK] release verification passed
```

## 单项测试

```bash
bash tests/smoke.sh
bash tests/cli-regression.sh
bash tests/render-regression.sh
bash tests/final-menu-regression.sh
bash tests/final-readme-regression.sh
bash tests/entry-port-pool-message-regression.sh
bash tests/pbr-forward-domain-resolution-regression.sh
bash tests/pbr-apply-forward-majority-regression.sh
bash tests/doctor-forward-pbr-dns-split-regression.sh
bash tests/forward-route-table-sync-regression.sh
bash tests/forward-domain-resolution-regression.sh
bash tests/domain-pbr-message-regression.sh
bash tests/system-network-menu-regression.sh
bash tests/quickstart-network-prepare-regression.sh
bash tests/ipv4-prefer-regression.sh
bash tests/dns-config-regression.sh
bash tests/ipv6-disable-restore-regression.sh
bash tests/ipv6-nft-lockdown-regression.sh
bash tests/system-network-cli-regression.sh
bash tests/role-detection-regression.sh
bash tests/doctor-reset-regression.sh
bash tests/compact-output-regression.sh
bash tests/ddns-summary-regression.sh
bash tests/entry-ddns-regression.sh
bash tests/ddns-menu-regression.sh
bash tests/ddns-overview-regression.sh
bash tests/ddns-noninteractive-autoswitch-regression.sh
bash tests/ddns-restart-cooldown-regression.sh
bash tests/ddns-consistency-regression.sh
bash tests/health-score-regression.sh
bash tests/update-regression.sh
bash tests/update-latest-version-regression.sh
bash tests/update-latest-no-risky-download-regression.sh
bash tests/update-empty-latest-guard-regression.sh
bash tests/package-regression.sh
bash tests/github-mirror-download-regression.sh
bash tests/easytier-download-mirror-regression.sh
bash tests/bootstrap-mirror-first-regression.sh
bash tests/tmpdir-fallback-regression.sh
bash tests/build-release-regression.sh
bash tests/uninstall-regression.sh
bash tests/lock-regression.sh
bash tests/redaction-regression.sh
```

- `smoke.sh`：基础语法、版本、帮助和关键 CLI 参数识别。
- `cli-regression.sh`：只读 CLI 在空状态目录下不触发全局 trap。
- `render-regression.sh`：模拟 TSV，检查表格、紧凑渲染和核心菜单渲染。
- `final-menu-regression.sh`：检查 1.4.16 LTS 主菜单只暴露 6 个核心入口，DDNS 和高级维护菜单保持收敛。
- `final-readme-regression.sh`：检查 README 标明 LTS、域名解析变化自动刷新、默认不修改 DNS 记录和常用命令。
- `system-network-menu-regression.sh`：检查高级维护挂载“系统网络优化”及 IPv4 / DNS / IPv6 / BBR / nftables 子菜单。
- `quickstart-network-prepare-regression.sh`：检查快速组网自动执行 IPv4 优先和 `8.8.8.8` / `1.1.1.1` 系统 DNS 预处理。
- `ipv4-prefer-regression.sh`：检查 `/etc/gai.conf` managed block 幂等写入和恢复。
- `dns-config-regression.sh`：检查系统 DNS 设置 / 恢复路径、systemd-resolved 与普通 resolv.conf 场景，以及不修改 DDNS 解析器。
- `ipv6-disable-restore-regression.sh`：检查 IPv6 sysctl 禁用 / 恢复和冲突提示。
- `ipv6-nft-lockdown-regression.sh`：检查 IPv6 入站收口使用 nftables 且文案不冒充 IPv6 禁用。
- `system-network-cli-regression.sh`：检查 `lq system ...` CLI 兼容入口。
- `role-detection-regression.sh`：检查 relay 不因 entries.tsv 被误判为 entry，真实混合部署才 WARN。
- `doctor-reset-regression.sh`：检查 doctor 每次运行都重置 WARN / FAIL 聚合，不继承历史 last-doctor。
- `compact-output-regression.sh`：检查 `--brief` / `LEIKWAN_BRIEF=1` 输出专业简洁，JSON 不受影响。
- `ddns-summary-regression.sh`：检查 DDNS 检测摘要为分区人类可读格式，不再输出机器化 `summary scope=`。
- `entry-ddns-regression.sh`：检查兼容 DNS 更新 status、配置生成、custom-url / custom-cmd 脱敏和 JSON 字段。
- `ddns-menu-regression.sh`：检查主菜单和 DDNS 菜单展示域名解析变化检测入口。
- `ddns-overview-regression.sh`：检查 `lq ddns overview` 输出统一 DDNS / 域名解析变化状态。
- `ddns-noninteractive-autoswitch-regression.sh`：检查 `ddns run --global --non-interactive` 自动写缓存、重应用 nftables、同步 PBR 和按配置处理 relay 重启。
- `ddns-restart-cooldown-regression.sh`：检查 relay 自动重启 cooldown 防止短时间重复重启。
- `entry-ddns-refresh-after-enable-regression.sh`：检查启用域名公网入口后自动轻量刷新 DDNS 入口解析缓存。
- `doctor-ddns-status-regression.sh`：检查 doctor 优先读取 DDNS 最近成功状态，不误报辅助公网 IP 缺失。
- `doctor-autofix-dnsutils-regression.sh`：检查 dig 缺失时会尝试安装 dnsutils，而不是只提示建议安装。
- `ddns-status-timer-regression.sh`：检查 DDNS 状态显示 timer 和下次检测时间。
- `ddns-consistency-regression.sh`：检查 `lq ddns check-consistency` 不写状态，并能比较公网入口缓存与兼容 DNS 更新摘要。
- `public-ip-source-regression.sh`：检查内置公网 IP 检测 URL 池和 IPv4 提取函数。
- `health-score-regression.sh`：检查健康度评分和 JSON 字段。
- `update-regression.sh`：模拟运行进程版本与安装脚本版本不一致，检查 update check/status 和菜单 reload 提示。
- `update-latest-version-regression.sh`：检查 latest 可从 VERSION、API、redirect、tags API 多路径解析，且 fast 模式不轮询完整下载镜像池。
- `update-latest-no-risky-download-regression.sh`：检查 latest 检测不会触发 release asset、sha256 或 EasyTier 大文件下载，也不会在默认模式刷出 403 / TLS / SSL 细节。
- `update-empty-latest-guard-regression.sh`：检查 latest 为空时自更新不会构造空版本 URL。
- `package-regression.sh`：检查 release 包内容边界。
- `github-mirror-download-regression.sh`：检查 GitHub 下载默认 mirror-first、origin-first 可切换、release / sha256 / raw / API 都走统一镜像函数。
- `easytier-download-mirror-regression.sh`：检查 EasyTier release asset 默认镜像优先、短超时低速切源、zip/tar/tgz 候选、本地包 fallback 和缓存复用。
- `bootstrap-mirror-first-regression.sh`：检查 bootstrap 默认 mirror-first、国内推荐命令和 `LEIKWAN_GITHUB_MIRRORS` 覆盖。
- `tmpdir-fallback-regression.sh`：检查 `TMPDIR` 不可用时测试临时目录 fallback 到仓库 `.tmp`。
- `build-release-regression.sh`：检查 `scripts/build-release.sh` 生成 tar.gz/sha256 且不包含 panel/controller/agent/web。
- `uninstall-regression.sh`：检查普通 / 深度卸载菜单、dry-run 和卸载后状态友好输出。
- `lock-regression.sh`：检查 stale lock 清理和锁占用时的友好拒绝。
- `redaction-regression.sh`：检查脱敏、端点 HTML 转义、恶意 tar 拒绝。

测试脚本会使用临时 `LEIKWAN_STATE_DIR`，不会修改真实 `/etc/leikwan-toolkit`。

## 服务器验收

发布包生成后，在真实测试机继续执行：

```bash
lq status
lq --doctor
lq port check
lq ddns status
lq pbr domain list
```

有完整 B 侧配置时，继续检查：

```bash
lq output generate
lq output json
lq output html
lq config export --redacted
```

有维护窗口时再检查高危路径：

```bash
nohup lq forward apply-relay --auto-fix-route >/root/lq-apply-relay.log 2>&1 &
lq config import /root/leikwan-config-YYYYMMDD-HHMMSS.tar.gz
```

初始化向导回归：

```bash
lq init --dry-run
lq init --plan
lq plan
```

这些命令必须不清屏、不等待回车、不写文件、不触发全局 trap。

真实部署稳定化回归：

```bash
lq status --json
lq doctor --json
lq logs
lq --dry-run uninstall normal --yes
```

JSON 输出必须合法且不包含 secret；卸载 dry-run 不应删除真实文件。
