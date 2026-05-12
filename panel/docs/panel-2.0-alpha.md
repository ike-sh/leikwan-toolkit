# Leikwan Panel Preview History

Leikwan Panel 2.0 preview / 2.1 stable �?Leikwan Toolkit �?Web 面板预览版。当前实现版本为 `3.0.0-alpha.1`�?
1.4.x Shell 版继续作�?Leikwan Core / LTS，负责真实转发、nftables、EasyTier、DDNS、PBR 和本机维护。Panel 3.0.0-alpha.1 只做状态采集、汇总、只读任务、计划审计和安全控制，不做配置下发�?## 安全边界

3.0.0-alpha.1 仍然不自动执行配置，明确不做�?
- 不远程执行任意命�?- 不下�?nftables / systemd / EasyTier / DDNS 配置
- 不修�?`entries.tsv`、`forwards.tsv`、PBR 或任何转发规�?- 不自动做入口切换、转发新增、转发删除、relay restart
- 不把 token、secret、private key、custom-url、custom-cmd 展示到前端、日志或 events �?
Agent 只允许采集本机只读状态并上报。需要调�?`lq` 时，只调用只读命令，例如�?
```bash
lq --version
lq status --json
lq doctor --json
lq forward list
lq ddns overview
```

3.0.0-alpha.1 �?Plans 之外新增只读 Tasks：Controller 只能创建内置 action，Agent 只有�?`enable_tasks=true` 时拉取，并将 action 映射到固�?`lq` 只读 argv。它不接�?command 字符串，不执�?shell，不执行写操作�?
## 架构

```text
Agent(entry/relay/backend) -> HTTPS/HTTP POST -> Controller(SQLite) -> Web UI
```

- Controller：Go HTTP API + SQLite，保存节点、历史上报、入口、转发、事件和 Plans�?- Agent：Go 采集器，周期性采集本机状态并上报�?- Web：React + Vite，展�?Dashboard、Topology、Bootstrap、Plans、Nodes、Node Detail、Entries、Forwards、Events�?
## 启动 Controller

本地开发：

```bash
cd panel/controller
go test ./...
go run ./cmd/leikwan-controller --listen 127.0.0.1:18080 --db ./data/controller.db --token dev-token
```

生产默认数据库路径建议：

```text
/var/lib/leikwan-panel/controller.db
```

也可以通过环境变量提供 token�?
```bash
export LEIKWAN_CONTROLLER_TOKEN='change-me'
go run ./cmd/leikwan-controller --listen 0.0.0.0:18080 --db /var/lib/leikwan-panel/controller.db
```

也可以使用简单配置文件：

```yaml
token: change-me
```

本地默认读取 `./controller.yml`，生产默认读�?`/etc/leikwan-panel/controller.yml`；`--token` 会覆盖环境变量和配置文件�?
健康检查：

```bash
curl http://127.0.0.1:18080/api/v1/health
```

返回�?
```json
{
  "name": "leikwan-controller",
  "version": "3.0.0-alpha.1",
  "status": "ok"
}
```

## 启动 Agent

配置文件默认路径�?
```text
/etc/leikwan-agent/config.yml
```

本地开发可用：

```text
./agent.yml
```

示例�?
```yaml
controller_url: http://127.0.0.1:18080
token: dev-token
node_id: relay-1
node_name: relay-1
role: relay
interval_seconds: 30
```

运行一次后退出：

```bash
cd panel/agent
go test ./...
go run ./cmd/leikwan-agent --config ./agent.yml --once
```

持续运行�?
```bash
go run ./cmd/leikwan-agent --config /etc/leikwan-agent/config.yml
```

`--debug` 只会输出脱敏后的内容，不会打�?token�?
## 启动 Web

```bash
cd panel/controller
npm --prefix web install
npm --prefix web run build
npm --prefix web run dev
```

默认前端从同�?`/api/v1/...` 读取 API。本地跨端口开发可设置�?
```bash
VITE_API_BASE=http://127.0.0.1:18080 npm --prefix web run dev
```

## API 列表

```text
GET  /api/v1/health
GET  /api/v1/bootstrap/agent-command
GET  /api/v1/topology
POST /api/v1/agent/register
POST /api/v1/agent/report
GET  /api/v1/nodes
GET  /api/v1/nodes/:id
GET  /api/v1/nodes/:id/reports
GET  /api/v1/nodes/:id/events
GET  /api/v1/nodes/:id/raw
GET  /api/v1/entries
GET  /api/v1/forwards
GET  /api/v1/events
POST /api/v1/plans
GET  /api/v1/plans
GET  /api/v1/plans/:id
POST /api/v1/plans/:id/generate
POST /api/v1/plans/:id/archive
POST /api/v1/tasks
GET  /api/v1/tasks
GET  /api/v1/tasks/:id
GET  /api/v1/agent/tasks?node_id=...
POST /api/v1/agent/tasks/:id/result
```

Agent 上报接口必须带：

```text
Authorization: Bearer <token>
```

## 数据存储

SQLite 默认开发路径：

```text
./data/controller.db
```

主要表：

- `nodes`
- `node_reports`
- `entries`
- `forwards`
- `events`

`raw_json` 入库前会统一脱敏�?
`GET /api/v1/nodes` 会动态计�?offline：`last_seen` 超过 `3 * interval_seconds`，或未上�?interval 时超�?120 秒，视为 offline�?
`GET /api/v1/bootstrap/agent-command` 返回的安装命令永远只包含 `REDACTED` token。Web API 不返�?Controller 的真�?token�?
Plans API 只生成命令文本，不执行命令，也不会改变节点系统。Tasks API 只支持内置只�?action，不接受任意 command 字符串�?
## 3.0.0-alpha.1 验收

```bash
cd panel/controller
go test ./...
npm --prefix web install
npm --prefix web run build

cd ../agent
go test ./...
```

## Snapshot / Rollback Safety Framework

`3.0.0-alpha.1` records manual snapshot and rollback metadata for Plans. It remains non-executing: no snapshot creation, no rollback, no relay restart, no Core configuration writes.

Detailed docs: `snapshot-rollback-beta.md` and `safety-gate.md`.
