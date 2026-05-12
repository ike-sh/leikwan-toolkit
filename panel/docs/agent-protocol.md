# Leikwan Agent Protocol

Current protocol version: `3.0.0-alpha.1`.

Agent reports local state to Controller. In `3.0.0-alpha.1`, Agent can optionally pull built-in readonly tasks and fixed alpha write tasks when `enable_write_actions=true`. It still cannot receive arbitrary command strings.

## Authorization

Agent APIs require:

```text
Authorization: Bearer <token>
```

Tokens must never appear in logs, events, raw JSON, frontend pages, task results or Plan output.

## Role Enum

```text
entry
relay
backend
mixed
unknown
```

## Status Enum

```text
online
offline
degraded
```

Use `degraded` when collection partially fails but the Agent can still report.

## Register

```http
POST /api/v1/agent/register
Authorization: Bearer <token>
Content-Type: application/json
```

```json
{
  "node_id": "relay-1",
  "node_name": "relay-1",
  "role": "relay",
  "hostname": "relay-1"
}
```

## Report

```http
POST /api/v1/agent/report
Authorization: Bearer <token>
Content-Type: application/json
```

```json
{
  "node_id": "relay-1",
  "node_name": "relay-1",
  "role": "relay",
  "hostname": "relay-1",
  "public_ip": "203.0.113.10",
  "primary_lan_ip": "10.0.0.10",
  "easytier_ip": "10.198.1.1",
  "agent_version": "3.0.0-alpha.1",
  "core_version": "1.4.0 LTS",
  "status": "online",
  "health_score": 96,
  "interval_seconds": 30,
  "services": {
    "nftables": "active",
    "easytier": "active",
    "leikwan-agent": "active",
    "ddns_timer": "active"
  },
  "capabilities": {
    "lq_available": true,
    "core_version": "1.4.0 LTS",
    "supports_status_json": true,
    "supports_doctor_json": true,
    "supports_forward_list": true,
  "supports_ddns_overview": true,
  "enable_tasks": false,
  "supports_snapshot_manual_record": true,
  "supports_rollback_manual_record": true,
  "write_actions_supported": false,
  "supported_write_actions": [],
  "allowed_task_actions": [
      "ddns_overview",
      "list_forwards",
      "probe_core_version",
      "run_doctor",
      "run_doctor_json",
      "run_status",
      "run_status_json"
    ]
  },
  "entries": [],
  "forwards": [],
  "recent_errors": [],
  "errors": []
}
```

## Readonly Task Poll

`enable_tasks` defaults to `false`. When explicitly enabled, Agent polls:

```http
GET /api/v1/agent/tasks?node_id=relay-1
Authorization: Bearer <token>
```

Controller returns only queued tasks for that exact `node_id`. Expired, canceled, rejected, and non-allowlisted tasks are not returned.

```json
[
  {
    "id": 1,
    "node_id": "relay-1",
    "action": "run_status_json",
    "status": "picked",
    "approval_status": "not_required",
    "attempt": 1,
    "max_attempts": 3
  }
]
```

## Readonly Task Result

```http
POST /api/v1/agent/tasks/1/result
Authorization: Bearer <token>
Content-Type: application/json
```

```json
{
  "status": "succeeded",
  "result_stdout": "{...redacted...}",
  "result_stderr": "",
  "exit_code": 0,
  "error": ""
}
```

Controller redacts and truncates stdout/stderr to 64KB before storing.

## Task Lifecycle API

```http
POST /api/v1/tasks/:id/cancel
POST /api/v1/tasks/:id/retry
POST /api/v1/tasks/:id/approve
POST /api/v1/tasks/:id/reject
GET  /api/v1/tasks/:id/timeline
```

These endpoints update Controller task state and audit timeline only. They do not cause Agents to perform writes.

## Allowed Task Actions

Actions are names, not commands:

```text
probe_core_version -> lq --version
run_status         -> lq status
run_status_json    -> lq status --json
run_doctor         -> lq doctor
run_doctor_json    -> lq doctor --json
list_forwards      -> lq forward list
ddns_overview      -> lq ddns overview
```

Agent maps action to fixed argv locally. Controller never sends command text.

## Capabilities

Capabilities are discovered only through read-only checks:

- `lq --version`
- `lq status --json`
- `lq doctor --json`
- `lq forward list`
- `lq ddns overview`

Probe failures are reported as `false` or `missing`; they do not crash the Agent.

## Redaction

Controller and Agent redact:

```text
token
secret
password
private_key
privateKey
network_secret
custom_url
custom_cmd
Authorization
```

URL query fields such as `token=`, `key=`, `password=` and `secret=` are also redacted. Bearer tokens become `Bearer REDACTED`.

## Forbidden

The protocol does not include:

- arbitrary command execution
- shell command strings
- configuration writes
- service restarts
- nftables changes
- EasyTier network modification
- DDNS configuration updates
- entries / forwards / PBR modification

## 3.0.0-alpha.1 Snapshot / Rollback Safety Framework

Leikwan Panel 3.0.0-alpha.1 adds Plan fields for manual snapshot and rollback metadata plus Safety Gate and verification APIs. The Controller only records operator-provided references and notes. It does not create snapshots, roll back nodes, restart services, or modify Core configuration.

New Plan APIs:

```text
POST /api/v1/plans/:id/snapshot
POST /api/v1/plans/:id/rollback-info
GET  /api/v1/plans/:id/safety-gate
POST /api/v1/plans/:id/verify
```

See `snapshot-rollback-beta.md` and `safety-gate.md`.

## 3.0.0-alpha.1 Write Action Review

The Agent protocol still does not accept Controller-provided command strings. By default, Agents report `write_actions_supported=false` and an empty `supported_write_actions` list. If an operator explicitly installs an Agent with `enable_write_actions=true`, it may report fixed alpha actions for EasyTier, nftables, PBR, DDNS and node lifecycle operations.

Controller Action Review is separate from Agent tasks. It does not send action-review results to Agents and does not create write tasks.
## Agent Token and Operator Token

Agent APIs use the Agent token from `LEIKWAN_CONTROLLER_TOKEN`. They do not accept `LEIKWAN_OPERATOR_TOKEN`. Operator APIs use the Operator token and do not accept the Agent token. See `operator-auth.md`.

## Controller-only Metadata Actions

3.0.0-alpha.1 adds metadata-only Plan actions. They are not Agent protocol messages: the Agent does not pull them, execute them, or report results for them. Agent capabilities should continue to report `controller_metadata_actions_supported=false`; metadata actions stay Controller-only even when demo alpha write actions are enabled.
