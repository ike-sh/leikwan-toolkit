# 验收清单

本页用于 Leikwan Toolkit 1.4.11 LTS 正式版验收。

## 版本

```bash
grep -n '^TOOL_VERSION=' leikwan-toolkit.sh
bash leikwan-toolkit.sh --version
```

期望：

```text
TOOL_VERSION="1.4.11"
leikwan-toolkit 1.4.11 LTS
```

## 打包

```bash
bash scripts/verify-release.sh
bash -n leikwan-toolkit.sh scripts/package-release.sh scripts/check-redaction.sh scripts/bootstrap.sh
shellcheck leikwan-toolkit.sh scripts/package-release.sh scripts/check-redaction.sh scripts/bootstrap.sh
git diff --check
bash scripts/check-redaction.sh
bash scripts/package-release.sh
```

期望生成：

```text
dist/leikwan-toolkit-1.4.11.tar.gz
dist/leikwan-toolkit-1.4.11.tar.gz.sha256
```

release 包不得包含旧入口文件：

按发布验收命令检查包内容，确认不包含旧入口文件和旧卸载脚本。

## 回归测试

```bash
bash tests/smoke.sh
bash tests/cli-regression.sh
bash tests/render-regression.sh
bash tests/final-menu-regression.sh
bash tests/final-readme-regression.sh
bash tests/role-detection-regression.sh
bash tests/doctor-reset-regression.sh
bash tests/compact-output-regression.sh
bash tests/ddns-summary-regression.sh
bash tests/entry-ddns-regression.sh
bash tests/ddns-menu-regression.sh
bash tests/ddns-overview-regression.sh
bash tests/ddns-consistency-regression.sh
bash tests/health-score-regression.sh
bash tests/update-regression.sh
bash tests/package-regression.sh
bash tests/uninstall-regression.sh
bash tests/lock-regression.sh
bash tests/redaction-regression.sh
bash scripts/verify-release.sh
```

期望全部通过，`scripts/verify-release.sh` 最后输出：

```text
[OK] release verification passed
```

## 初始化向导

```bash
lq init --dry-run
lq init --plan
lq plan
```

期望：

- 输出初始化计划。
- 不修改系统。
- 不清屏、不等待回车。
- 不触发全局 trap。

交互执行 `lq` 后，主菜单只保留：

```text
1. 快速组网
2. 利群主机 B
3. 公网入口 A
4. DDNS
5. 状态 / 诊断
6. 高级维护
0. 退出
```

`lq init` 初始化向导仍可选择 B 利群主机、A 公网入口、从配置包恢复或仅检查状态。

## 状态 JSON / 日志 / 卸载 / 锁

```bash
lq --brief
lq status --brief
lq status --json
lq --status-json
lq doctor --json
lq --doctor-json
lq doctor --auto-fix
lq --doctor-auto-fix
lq logs
lq logs ddns
lq logs apply
```

期望：

- relay 节点不会因为存在 entries.tsv 被误报 relay + entry；真实混合部署才 WARN。
- 简洁模式输出 `Leikwan Status`、`Health: N/100 (level)` 和 `Overall`。
- doctor 每次重新聚合当前状态，不继承历史 last-doctor FAIL / WARN。
- doctor 自动修复只处理 nft/MSS、DDNS timer、快捷命令、权限和 stale lock，不删除业务配置。
- JSON 合法，不清屏、不等待回车、不包含 secret。
- JSON 包含 `health_score` 和 `health_level`。
- 无日志时友好提示。
- doctor 文本输出末尾包含“诊断结果摘要”。

卸载菜单应显示：

```text
1. 普通卸载：移除服务和规则，保留配置 / 快照 / 备份
2. 深度卸载：移除服务、规则、配置、日志、状态
0. 返回
```

模拟 lock 占用时，高危任务应提示已有任务运行；stale lock 应可清理。

## 自更新热修验收

```bash
lq update check
lq update status
```

期望：

- `update check` 优先显示当前安装版本，而不是只使用旧菜单进程里的 `TOOL_VERSION`。
- 当运行版本和安装版本不一致时，输出 WARN 并建议重新进入菜单。
- `update status` 显示当前运行版本、当前安装版本、快捷命令指向和最近更新状态。
- 菜单中执行更新或回滚成功后自动重新载入新脚本；如果 reload 失败，明确提示手动执行 `lq`。

## 快速组网

1. B 生成公网入口接入码，默认推荐 `public1 / 公网1 / 10.198.1.2 / tcp+udp / 8301`。
2. 不粘贴 ENTRY，继续生成第二份，推荐 `public2 / 公网2 / 10.198.1.3 / tcp+udp / 8302`。
3. 如果已有旧入口 `aliyun -> 10.198.1.2/8301` 和 `home -> 10.198.1.3/8302`，下一台必须推荐 `public3 / 公网3 / 10.198.1.4 / 8303`。
4. A 粘贴网络码部署入口，systemd service 同时包含 TCP 和 UDP listener。
5. A 返回 ENTRY 后，B 能保存入口并清理 pending。
6. ENTRY 名称和 pending 名称不同也能保存并清理命中的 pending。

## 多公网入口

准备：

```text
public1  203.0.113.10   10.198.1.2  tcp,udp  8301  100  true
public2  203.0.113.20   10.198.1.3  tcp,udp  8302  100  true
```

验收：

- 列表显示 `公网1(public1)`、`公网2(public2)`。
- relay service peer 包含 TCP+UDP 两个协议。
- 切换主入口模式 1 后，只保留选中入口 enabled。
- 切换主入口模式 2 后，选中入口标记 PRIMARY，其它 enabled 入口标记 BACKUP。
- 批量禁用所有入口必须二次确认。

旧入口名仍兼容，可继续读取、修改、删除、启用禁用和切换主入口。

## 转发与 PBR

- A 侧端口池必须生成 TCP+UDP DNAT。
- B 侧转发目标必须生成 TCP+UDP DNAT。
- PBR 菜单显示 `0. 返回`。
- PBR 菜单包含 `域名 PBR 管理`。
- 从现有转发目标添加 PBR 后，默认询问是否立即同步转发规则和 `route_table` 元数据。
- `lq pbr sync-from-forwards` 能根据当前 resolved IP 同步 forward 来源 PBR，且不删除 static PBR。
- `lq pbr domain add/list/delete/sync` 可用，域名 PBR 同步生成 `pbr-domain:<name>` 来源规则，且不删除 static PBR。
- 删除 PBR 支持编号、CIDR 和裸 IP。

## DDNS 自动刷新

```bash
lq ddns status
lq ddns run
lq ddns run --scope forwards
lq ddns run --scope entries
lq ddns run --scope pbr
lq ddns run --scope all
lq ddns overview
lq ddns apply-entries
lq ddns check-consistency
lq entry ddns status
lq entry ddns setup
lq entry ddns run
lq entry ddns enable
lq entry ddns logs
lq logs entry-ddns
lq --ddns-run
```

期望：

- 不清屏，不等待回车。
- 能识别 enabled 转发目标中的域名后端、公网入口域名和域名 PBR。
- forward IP 未变化时不重应用 nftables。
- forward IP 变化时更新 `resolved.tsv`，创建 `auto-before-ddns-apply-*.tar.gz` 快照并安全重应用 nftables。
- entry IP 变化时更新 `resolved-entries.tsv`，默认只记录 `relay restart needed`，timer 不自动重启 relay。
- 默认不修改 DNS 服务商记录；兼容 `entry ddns` 仅在 `DDNS_UPDATE_DNS_RECORD=true` 时用于高级旧脚本集成。
- `lq ddns apply-entries` 在没有 pending 变化时输出 OK；有 pending 变化时提示 relay 重启风险，确认后创建快照、重启 relay 并测试 enabled entries。
- `lq ddns overview` 输出统一 DDNS / 域名解析变化检测状态。
- `lq ddns check-consistency` 只读检查公网入口缓存和兼容 DNS 更新摘要。
- pbr domain IP 变化时更新 `resolved-pbr-domains.tsv`，生成新的 `pbr-domain:<name>` `/32` 规则。
- 解析失败时保留旧 resolved IP。

启用 timer：

```bash
lq ddns enable
systemctl status leikwan-ddns-refresh.timer
lq ddns status
```

检查：

```bash
tail -n 100 /var/log/leikwan-ddns-refresh.log
cat /etc/leikwan-toolkit/status/last-ddns.env
```

期望日志包含开始 / 结束、changed / failed 统计，不包含 EasyTier secret。

检查 last-ddns：

```bash
cat /etc/leikwan-toolkit/status/last-ddns.env
```

期望包含：

```text
LAST_DDNS_SCOPE=
LAST_DDNS_FORWARD_CHANGED=
LAST_DDNS_ENTRY_CHANGED=
LAST_DDNS_PBR_CHANGED=
LAST_DDNS_RELAY_RESTART_NEEDED=
LAST_DDNS_NFT_APPLIED=
LAST_DDNS_PBR_APPLIED=
```

## 自更新

```bash
lq update check
lq --update-check
```

期望显示当前版本和最新 GitHub Release 版本；当前已最新时显示 `[OK] 当前已是最新版本`。

在测试环境中使用旧版本脚本执行：

```bash
lq update run
```

期望：

- 下载 release tar.gz 和 sha256。
- sha256 校验通过。
- 解包得到 `leikwan-toolkit.sh`。
- `bash -n` 通过。
- 新脚本 `--version` 符合预期。
- 备份旧脚本到 `/var/backups/leikwan-toolkit/root__leikwan-toolkit.sh.*.bak`。
- 替换 `/root/leikwan-toolkit.sh`。
- `lq --version` 显示新版本。

回滚：

```bash
lq update rollback
```

期望根据 `last-update.env` 找到备份，恢复旧脚本，并把 `LAST_UPDATE_RESULT` 记为 `rollback`。

## 状态总览与缓存

```bash
lq status
lq --status
```

期望：

- 输出简洁状态总览，不清屏，不等待回车。
- 显示版本、角色、入口数量、转发数量、nftables、MSS clamp、整体状态。
- 不自动修改系统。

执行：

```bash
lq status
lq --doctor
nohup lq forward apply-relay --auto-fix-route >/root/lq-apply-relay.log 2>&1 &
```

检查：

```bash
ls -lh /etc/leikwan-toolkit/status/
cat /etc/leikwan-toolkit/status/last-status.env
cat /etc/leikwan-toolkit/status/last-doctor.env
cat /etc/leikwan-toolkit/status/last-apply.env
```

期望缓存文件存在，包含时间、结果、版本，不包含 EasyTier secret。

## 快照 / 回滚

菜单路径：

```text
高级维护 -> 配置备份 / 快照 / 回滚
```

验收：

- 创建当前完整快照会生成 `snapshot-YYYYMMDD-HHMMSS.tar.gz`。
- 查看快照列表能按编号显示。
- 导出最新快照到 `/root/leikwan-snapshot-YYYYMMDD-HHMMSS.tar.gz`。
- 创建快照时提醒可能包含 EasyTier network secret。
- 恢复快照前二次确认，恢复后询问是否 reload systemd 并重启相关服务。

高危操作前，例如删除转发目标、删除公网入口、重新应用利群转发规则，应生成 `/etc/leikwan-toolkit/snapshots/auto/auto-before-*.tar.gz`，且只保留最近 10 个自动快照。

## 配置导入 / 导出

```bash
lq config export --full
lq config export --redacted
lq config inspect /root/leikwan-config-YYYYMMDD-HHMMSS.tar.gz
lq config list
```

期望：

- 完整配置包输出到 `/root/leikwan-config-YYYYMMDD-HHMMSS.tar.gz`，同时生成 `.sha256`。
- `--full` 明确警告包含 EasyTier network secret。
- 脱敏配置包输出到 `/root/leikwan-config-redacted-YYYYMMDD-HHMMSS.tar.gz`，secret、配对码 base64、token / password 类字段被替换为 `REDACTED`。
- inspect 只展示 manifest、entries / forwards / PBR / DDNS 摘要和 systemd / nft / ip rule 快照状态，不导入、不修改系统。
- 配置包内包含 `manifest.env`、`manifest.json`、`state/etc-leikwan-toolkit.tar.gz`、`checksums.sha256` 和 outputs 文件。

导入测试：

```bash
lq config import /root/leikwan-config-YYYYMMDD-HHMMSS.tar.gz
lq config import /root/leikwan-config-YYYYMMDD-HHMMSS.tar.gz --mode config-only
lq config import /root/leikwan-config-YYYYMMDD-HHMMSS.tar.gz --mode full --yes
```

期望：

- 导入前展示 inspect 摘要并校验外部 `.sha256` 与包内 `checksums.sha256`。
- 导入前自动创建 `auto-before-config-import-YYYYMMDD-HHMMSS.tar.gz` 快照。
- 交互导入可选择 config-only / apply / full。
- 非交互 full import 没有 `--yes` 时拒绝执行。
- 脱敏包不能用于 full 恢复运行。
- 包内含路径穿越、绝对路径、symlink 或 hardlink 时，inspect / import 必须拒绝。
- 导入后提示执行 `lq status`、`lq --doctor` 和必要时 `lq forward apply-relay --auto-fix-route`。

菜单路径：

```text
高级维护 -> 配置导入 / 导出
```

动作输出必须停留，按回车返回。

## 转发端点输出

```bash
lq output generate
lq output show
lq output json
lq output html
lq output qr
```

期望生成：

```text
/etc/leikwan-toolkit/outputs/forward-endpoints.txt
/etc/leikwan-toolkit/outputs/forward-endpoints.tsv
/etc/leikwan-toolkit/outputs/forward-endpoints.json
/etc/leikwan-toolkit/outputs/forward-endpoints.html
```

验收：

- TXT / TSV / JSON / HTML 都包含生成时间、脚本版本、enabled entries、enabled forwards、PRIMARY / BACKUP、TCP / UDP endpoint。
- JSON 可被 `jq` 或其它 JSON 解析器读取。
- HTML 是静态文件，移动端可读，不需要 Web 服务；用户输入中的 `<script>` 必须被转义。
- 输出不包含 EasyTier network secret、配对码 base64、token 或 password。
- 未安装 `qrencode` 时 `lq output qr` 输出 INFO 并跳过；已安装时只把 endpoint 字符串写入二维码。
- `lq status` 显示最近端点输出时间。

## 端口预检

```bash
lq port check
lq --port-check
```

期望：

- 输出 EasyTier 端口、业务入口端口、本机监听、nftables 状态。
- 不修改系统。
- 发现端口重复、pending 占用、本机监听或 nftables dport 冲突时输出 WARN。

新增转发目标时尝试使用已存在的 `entry_port`，应提示端口已被对应转发目标使用，不直接写入重复端口，并允许重新输入。

新增公网入口时尝试使用已存在的 EasyTier 端口，应提示端口已被对应入口使用或 pending 占用，不直接写入重复端口，并允许重新输入。

## 交互

- 主菜单显示清晰 banner。
- 子菜单不重复大 banner。
- 菜单进入前会清屏；`LEIKWAN_NO_CLEAR=1 lq` 可禁用清屏。
- 菜单动作输出必须停留，按回车后才继续。
- NETWORK / ENTRY 连接码输出后，直接回车不能返回菜单；必须输入 `y`，输入 `r` 可重显，输入 `p` 可显示保存路径。
- 快速组网说明简洁。
- 生成 NETWORK / ENTRY 配对码后，单行码停留在最后一行，并提示按回车返回。
- doctor、debug report、转发入口输出等长输出后等待回车返回菜单。

## 卸载

卸载后检查：

```bash
test ! -e /var/log/leikwan-toolkit.log && echo "OK: no log"
test ! -e /etc/leikwan-toolkit && echo "OK: no state"
test ! -e /var/backups/leikwan-toolkit && echo "OK: no backups"
command -v lq || echo "OK: no lq"
```

卸载检查结果中日志文件应显示已清理，且卸载结束后不应重新创建日志。
