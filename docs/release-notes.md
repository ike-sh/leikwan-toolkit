# Release Notes

## 1.4.15 LTS

- `lq update` 不带子命令时等价于 `lq update run`，保留 `check` / `run` / `status` / `rollback` 原有行为。
- 修复确认提示默认值处理，`[Y/n]` 直接回车按 yes，`[y/N]` 直接回车按 no，`Y/y/N/n` 均可识别。

## 1.4.14 LTS

- 修复 `PBR -> 应用 PBR` 中 forward 来源规则仍使用通用 `first-success` resolver 的问题，统一改用转发 / PBR majority resolver。
- 修复 doctor 在 forward/PBR 域名 DNS 分歧时误报“当前采用 1.1.1.1”的提示，改为显示转发 / PBR 场景当前采用的多数结果。
- 调整 `forward apply-relay --auto-fix-route`：当实际路由暂时没有返回 table 时，不再自动把已有 `T_CN2` 等 route_table 元数据清空。

## 1.4.13 LTS

- 为转发目标 / PBR 场景新增多数优先的域名解析选择：多 DNS 结果分歧时，若某个 IP 至少出现两次且为唯一多数，转发和 PBR 写入统一使用该 IP。
- 修复“从现有转发目标添加 PBR”先按 `first-success` 显示错误 IP、随后同步又修正 IP 的体验问题。
- 查看转发目标时，域名后端的当前解析 IP 使用同一套 forward resolver，避免显示和 PBR 写入不一致。
- 域名 PBR 管理为空时补充说明：从转发目标添加的 PBR 在“查看 PBR”中查看，来源形如 `forward:name domain`。

## 1.4.12 LTS

- 修复 A 端“配置入口端口池”成功后的下一步提示，不再写死菜单编号，改为提示进入“利群主机 B”“IPv4 PBR 出口策略”和“转发目标管理”。
- 增强入口端口池检测到本机监听端口时的提示，明确继续配置后外部访问可能被 DNAT 接管，并给出避开冲突端口的范围建议。

## 1.4.11 LTS

- 修复 `lq system network prepare` 对旧版 Leikwan 托管 DNS 的误判：只有主 DNS 和 FallbackDNS 都精确等于当前目标配置时才算 `managed-current`。
- 新增 DNS 配置状态 `managed-current` / `managed-legacy` / `unmanaged`，旧托管配置会提示并自动迁移。
- `doctor` 使用同一套 DNS 状态判断，旧托管配置提示迁移，未托管但主 DNS 包含 `8.8.8.8` / `1.1.1.1` 时仍认可为推荐 DNS。

## 1.4.10 LTS

- 修复 systemd-resolved 托管 DNS 状态把主 DNS 和 FallbackDNS 混在一起展示的问题。
- 修复 `doctor` 对系统 DNS 的误判：托管配置中主 DNS 包含 `8.8.8.8` 和 `1.1.1.1` 时输出 OK，FallbackDNS 不再触发“非推荐国外 DNS”提示。
- 保持 `lq system network prepare` 幂等：目标 DNS 与 FallbackDNS 已写入时不重复改写。

## 1.4.9 LTS

- 快速组网在 B 利群主机初始化和 A 公网入口部署前自动执行系统网络预处理：IPv4 优先 + `8.8.8.8` / `1.1.1.1` 系统 DNS。
- 新增“高级维护 -> 系统网络优化”，集中管理 IPv4 优先、系统 DNS 设置 / 恢复、IPv6 sysctl 禁用 / 恢复、BBR / fq 和 IPv6 入站收口。
- IPv4 优先改为 `/etc/gai.conf` managed block，重复开启不会重复追加，关闭时只移除托管块。
- 系统 DNS 写入 systemd-resolved drop-in 或普通 `/etc/resolv.conf`，写入前备份；恢复时删除托管配置或回滚备份。
- IPv6 禁用 / 恢复使用 sysctl 托管文件，不再把 IPv6 入站收口冒充为禁用 IPv6。
- IPv6 入站收口迁移为 nftables `table inet leikwan_ipv6_lockdown`，保留 ICMPv6、lo、已建立连接和 SSH 22，不影响 IPv4。
- 新增 `lq system ...` CLI，doctor 会提示并在 `--auto-fix` 中执行系统网络预处理，但不会默认禁用 IPv6 或自动做 IPv6 入站收口。

## 1.4.8 LTS

- 修复 `lq update check` 风控式轮询 GitHub 镜像池的问题，latest 元数据查询默认改为轻量 `fast` 模式。
- 新增根目录 `VERSION` 文件，优先通过 raw VERSION 读取最新版本，减少 GitHub API 风控和代理兼容问题。
- API latest、latest redirect、tags API 默认只走官方短 timeout；完整探测需显式设置 `LEIKWAN_GITHUB_METADATA_MODE=full`。
- 保留 release tar.gz、sha256 和 EasyTier 大文件下载的 `mirror-first` 策略、缓存、禁止跨镜像 resume 和 sha256 校验。

## 1.4.7 LTS

- GitHub 下载默认改为 `mirror-first`，官方 GitHub 保留为最后兜底。
- 扩大默认 GitHub 镜像池，并支持 `LEIKWAN_GITHUB_DOWNLOAD_MODE=origin-first` 改回官方优先。
- 修复 latest 检测为空的问题，依次 fallback 到 API、redirect、tags API 和 HTML 解析。
- latest 为空时自更新会明确失败，不再构造空版本下载 URL。
- EasyTier release asset 先构造确定性 URL，按镜像池优先下载，API 只作为辅助兜底。
- 大文件下载缩短单源超时，启用低速失败切源，不再在慢源上多次 retry。
- 每个下载源使用独立临时文件，避免跨镜像 partial / resume。
- EasyTier 安装包下载成功后缓存到 `/var/cache/leikwan-toolkit/downloads`，同版本优先复用。
- 自更新 release 包和 `.sha256` 继续校验 sha256，并统一走 mirror-aware 下载。
- Release `.sha256` 文件改为 basename 格式，避免写入本机绝对路径。

## 1.4.0 LTS

1.4.0 LTS 是 Leikwan Toolkit 的功能冻结版。

项目定位收敛为：

```text
A 公网入口 + B 中转主机 + C 后端目标 的 TCP/UDP 转发组网工具
```

本版重点：

- 主菜单收敛为 6 个核心入口。
- 普通用户路径压缩为“快速组网、B、A、DDNS、状态 / 诊断、高级维护”。
- `lq status` 默认输出更短的最终版状态。
- 高级、低频和高危操作移动到“高级维护”。
- README 重写为最终用户视角，详细命令移到 docs。
- 保留既有 CLI 兼容，不删除旧用户脚本依赖的命令。

后续版本主要只做：

- bug fix
- 兼容性修复
- 安全修复
- 文档完善
