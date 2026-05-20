# 配置导入 / 导出 / 迁移包

Leikwan Toolkit 1.4.0 增加配置包，用于备份、迁移和排错。

## 完整包和脱敏包

完整配置包：

- 默认输出到 `/root/leikwan-config-YYYYMMDD-HHMMSS.tar.gz`
- 同时生成 `.sha256`
- 包含 `/etc/leikwan-toolkit`
- 包含 EasyTier network secret，可用于恢复运行

完整包泄露后，别人可能加入你的 EasyTier 网络。请按敏感文件保存。

脱敏配置包：

- 输出到 `/root/leikwan-config-redacted-YYYYMMDD-HHMMSS.tar.gz`
- EasyTier secret、配对码 base64、token/password/secret 类字段会替换为 `REDACTED`
- 适合排错或提交 issue
- 不适合完整恢复运行

## 导出

```bash
lq config export
lq config export --full
lq config export --redacted
lq export-config --redacted
```

`--full` 会二次确认，因为完整包包含 EasyTier network secret。

配置包内含：

```text
manifest.env
manifest.json
state/etc-leikwan-toolkit.tar.gz
systemd/
nft/
iproute/
sysctl/
status/
outputs/
checksums.sha256
```

日志只导出尾部 200 行，不包含全量历史备份和 dist 构建产物。

## 查看

```bash
lq config inspect /root/leikwan-config-YYYYMMDD-HHMMSS.tar.gz
lq config list
```

inspect 只读取配置包，不导入、不修改系统。它会显示导出时间、版本、角色、是否脱敏、entries / forwards / PBR 数量、DDNS 状态，以及是否包含 systemd / nft / ip rule 快照。

## 导入

交互导入：

```bash
lq config import /root/leikwan-config-YYYYMMDD-HHMMSS.tar.gz
```

首次恢复新机器时也可以从初始化向导进入：

```bash
lq init
```

选择“从配置包恢复”后，脚本会先 inspect，再复用 `lq config import` 的导入、安全校验和自动快照逻辑。

导入前会：

- 校验外部 `.sha256`
- 校验包内 `checksums.sha256`
- 校验 manifest
- 拒绝路径穿越、绝对路径、symlink 和 hardlink 包成员
- 展示 inspect 摘要
- 自动创建 `auto-before-config-import-YYYYMMDD-HHMMSS.tar.gz` 快照
- 二次确认覆盖风险
- 持有配置锁和全局锁，避免与 DDNS、转发应用、自更新、卸载并发

导入模式：

```text
1. 仅导入 /etc/leikwan-toolkit 配置
2. 导入配置并重新渲染 systemd / nftables / PBR
3. 完整迁移恢复，包括 systemd service、nftables、PBR、sysctl
```

非交互：

```bash
lq config import /root/leikwan-config.tar.gz --mode config-only
lq config import /root/leikwan-config.tar.gz --mode apply
lq config import /root/leikwan-config.tar.gz --mode full --yes
```

非交互 full import 必须加 `--yes`。脱敏包不能用于 full 恢复。

## 导入后检查

```bash
lq status
lq --doctor
lq forward apply-relay --auto-fix-route
```

导入不会盲目重启所有服务。选择 apply / full 时会提示 EasyTier、nftables 和 PBR 应用风险。

导入完成后会提示：

```text
下一步建议:
1. lq status
2. lq --doctor
3. 如需应用转发规则：lq forward apply-relay --auto-fix-route
```
