# Task Lifecycle

Leikwan Panel `3.0.0-alpha.2` supports readonly tasks only.

## Status

- `queued`: Controller accepted an allowlisted readonly action.
- `picked`: the matching Agent pulled the task.
- `succeeded`: Agent ran the fixed readonly argv and returned exit code 0.
- `failed`: the readonly command failed or timed out.
- `expired`: the task exceeded `expires_at` before pickup.
- `rejected`: Agent rejected a non-allowlisted action locally.
- `canceled`: an operator canceled a queued or picked task in Controller.

## Cancel and Retry

`POST /api/v1/tasks/:id/cancel` changes only Controller state. It does not contact the node directly.

`POST /api/v1/tasks/:id/retry` is allowed only for `failed`, `expired`, or `canceled` tasks. It creates a new queued task with `retry_of_task_id`, increments `attempt`, and keeps the same readonly action.

## TTL

Tasks have `ttl_seconds` and `expires_at`. Controller marks expired queued tasks as `expired` during normal API activity, and Agents do not receive expired tasks.

## Agent Lock

Agent uses a local task lock and runs only one task at a time. If a task is still running, the next poll is skipped.

## Plan Dry-run Groups

Plan dry-runs add a `task_group_id` so several readonly tasks can be tied back to one Plan. The Agent still receives only individual allowlisted actions and never sees Plan command text.

## Result Limit and Redaction

Agent redacts stdout, stderr, and errors before upload. Controller redacts again before storage and keeps only the first 64KB of stdout/stderr/error.

Secrets covered by redaction include token, secret, password, privateKey, network_secret, custom_url, custom_cmd, and Authorization.

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
