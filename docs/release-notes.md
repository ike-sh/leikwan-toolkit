# Release Notes

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
