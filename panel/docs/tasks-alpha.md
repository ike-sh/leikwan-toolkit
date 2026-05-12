# Readonly Tasks

Leikwan Panel `3.0.0-alpha.2` hardens the minimal Agent task system for readonly diagnostics.

## Scope

This release only supports readonly allowlisted tasks. It does not support configuration changes, service restarts, nftables edits, EasyTier changes, DDNS edits, entries/forwards/PBR changes, or arbitrary remote commands.

## Defaults

Agent tasks are disabled by default:

```yaml
enable_tasks: false
task_interval_seconds: 10
task_timeout_seconds: 20
max_concurrent_tasks: 1
task_result_limit_kb: 64
```

Enable tasks only on nodes where you want the Controller to request readonly diagnostics:

```yaml
enable_tasks: true
```

## Supported Actions

Controller accepts only these action names:

```text
probe_core_version
run_status
run_status_json
run_doctor
run_doctor_json
list_forwards
ddns_overview
```

Agent maps them locally to fixed argv:

```text
probe_core_version -> lq --version
run_status         -> lq status
run_status_json    -> lq status --json
run_doctor         -> lq doctor
run_doctor_json    -> lq doctor --json
list_forwards      -> lq forward list
ddns_overview      -> lq ddns overview
```

## No Command Strings

The task API does not accept `command`. Controller sends only an `action`, and Agent rejects any action outside the local allowlist.

Agent does not use `shell -c`, `bash -c`, `eval`, or string concatenation. Each action becomes a fixed executable plus fixed argv.

## Timeout, Redaction and Result Limit

- Each task has a timeout, default 20 seconds.
- Agent runs one task at a time with a local task lock.
- Each queued task has `ttl_seconds` and `expires_at`; expired tasks are not handed to Agents.
- stdout, stderr and errors are redacted before upload.
- Controller redacts again before database storage.
- stdout/stderr are limited to the first 64KB.
- Task failure does not stop the Agent's normal status reports.

## Lifecycle and Audit

Task status values are `queued`, `picked`, `succeeded`, `failed`, `expired`, `rejected`, and `canceled`.

The task system includes audit-only approval fields:

```text
approval_status: not_required | pending | approved | rejected
```

Readonly tasks default to `not_required`. `approve` and `reject` only record audit state; they do not unlock write tasks.

Every create, pick, result, cancel, retry, approve, and reject action is written to the task timeline and events.

## Plan Dry-run

Plans can create linked readonly tasks as a dry-run preflight. The tasks use the same allowlist above, are grouped with `task_group_id`, and are summarized into the Plan `dry_run_report`.

Dry-run does not execute generated Plan commands and does not enable write operations.

## API

```http
POST /api/v1/tasks
GET  /api/v1/tasks
GET  /api/v1/tasks/:id
POST /api/v1/tasks/:id/cancel
POST /api/v1/tasks/:id/retry
POST /api/v1/tasks/:id/approve
POST /api/v1/tasks/:id/reject
GET  /api/v1/tasks/:id/timeline
GET  /api/v1/agent/tasks?node_id=...
POST /api/v1/agent/tasks/:id/result
```

Agent endpoints require `Authorization: Bearer <token>`.

## Future Write Automation

Future write operations would require dry-run, snapshot, rollback, approval, strict write allowlists and audit trails. They are not part of 3.0.0-alpha.2.

## 3.0.0-alpha.2 Snapshot / Rollback Safety Framework

Leikwan Panel 3.0.0-alpha.2 adds Plan fields for manual snapshot and rollback metadata plus Safety Gate and verification APIs. The Controller only records operator-provided references and notes. It does not create snapshots, roll back nodes, restart services, or modify Core configuration.

New Plan APIs:

```text
POST /api/v1/plans/:id/snapshot
POST /api/v1/plans/:id/rollback-info
GET  /api/v1/plans/:id/safety-gate
POST /api/v1/plans/:id/verify
```

See `snapshot-rollback-beta.md` and `safety-gate.md`.

## 3.0.0-alpha.2 Write Review Boundary

Tasks remain readonly. Action Catalog and Action Review do not add task actions and do not allow write execution.

Agents still support only:

```text
probe_core_version
run_status
run_status_json
run_doctor
run_doctor_json
list_forwards
ddns_overview
```

Agents with default config report:

```json
{
  "write_actions_supported": false,
  "supported_write_actions": []
}
```

Any non-readonly action is rejected by the Controller and by the Agent local allowlist unless the Agent was explicitly installed with `enable_write_actions=true`. In that demo mode, only the fixed alpha staging actions documented in `demo-apply-alpha.md` are allowed; no command string is accepted.
## Compatibility Note

This document remains under its original filename for link compatibility. The readonly task system described here is part of Leikwan Panel 3.0.0-alpha.2.
