# Metadata-only Actions Alpha

Leikwan Panel `3.0.0-alpha.1` enables a very small set of Controller-only metadata actions. These actions update the Controller database for audit and operator workflow only.

They do not modify nodes, do not create Agent tasks, do not execute commands, do not create snapshots, do not run rollback, and do not change Leikwan Core configuration.

## Supported Actions

```text
record_snapshot_ref
record_rollback_ref
mark_plan_executed
mark_plan_verified
attach_manual_evidence
```

## API

```text
POST /api/v1/plans/:id/metadata-action
GET  /api/v1/plans/:id/evidence
POST /api/v1/plans/:id/evidence
```

All mutating endpoints require the Operator token. Agent tokens cannot call these APIs.

Operator identity is stored as a short fingerprint such as `operator:abcd1234`. Full tokens are never stored in Plan fields, evidence, events or timeline.

## What Each Action Does

- `record_snapshot_ref`: records an operator-provided snapshot reference and note.
- `record_rollback_ref`: records an operator-provided rollback reference and note.
- `mark_plan_executed`: records manual execution status in the Controller.
- `mark_plan_verified`: records manual verification status in the Controller.
- `attach_manual_evidence`: stores redacted evidence text for audit.

All notes and evidence content are redacted before storage. Redaction covers `token`, `operator_token`, `controller_token`, `secret`, `password`, `privateKey`, `network_secret`, `custom_url`, `custom_cmd` and `Authorization`.

## Safety Boundary

Metadata actions are intentionally separate from Agent tasks:

- no Agent pull
- no command string
- no shell execution
- no nftables/systemd/EasyTier/DDNS/PBR write
- no entries.tsv or forwards.tsv change
- no tasks table write except unrelated existing readonly task APIs

This is a safety transition toward future automation: first build audit, redaction, Operator Auth and timeline behavior before considering any node write operation.
