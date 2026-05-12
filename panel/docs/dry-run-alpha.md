# Plan Dry-run

Leikwan Panel `3.0.0-alpha.2` adds readonly Plan dry-runs.

Dry-run is a preflight helper. It creates only built-in readonly tasks for the target node and waits for Agent results. It does not apply a Plan, does not run generated command text, and does not change Leikwan Core configuration.

## How It Works

When an operator starts dry-run from a Plan, Controller creates allowlisted readonly tasks:

```text
create_forward -> run_status_json, run_doctor_json, list_forwards
switch_entry   -> run_status_json, run_doctor_json, list_forwards, ddns_overview
create_entry   -> run_status_json, run_doctor_json, ddns_overview
ddns_check     -> ddns_overview, run_doctor_json
```

Agent only receives action names and maps them locally to fixed argv. Controller never sends a command string.

## Status

```text
not_run
running
passed
warning
failed
```

- `running`: dry-run tasks are queued or picked.
- `passed`: all readonly tasks succeeded and no serious warning was detected.
- `warning`: tasks completed but doctor, node status, capabilities, or output checks need review.
- `failed`: at least one task failed, expired, was canceled, or was rejected.

## Dry-run Report

`dry_run_report` is redacted and includes:

- target node status
- whether reported capabilities satisfy the Plan
- linked readonly task ids, actions, status, exit code and error
- doctor warnings
- whether forward list / DDNS overview were readable
- whether blocked command text was detected in Plan artifacts
- recommendation

## Security Boundary

Dry-run is not execution. It does not:

- create, edit, or delete forwards
- switch public entries
- restart relay
- modify nftables, systemd, EasyTier, DDNS, entries, forwards, or PBR
- execute shell strings
- execute Plan generated commands

Future write automation would still require explicit approval, dry-run, snapshot, rollback, a strict write allowlist, and auditable recovery behavior.

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
## Compatibility Note

This document remains under its original filename for link compatibility. The dry-run flow described here is part of Leikwan Panel 3.0.0-alpha.2.
