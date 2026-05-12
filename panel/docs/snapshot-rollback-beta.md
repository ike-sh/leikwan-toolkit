# Snapshot / Rollback Metadata

Leikwan Panel `3.0.0-alpha.1` adds a Controller-side safety framework for Plans.

Leikwan Panel 3.0.0-alpha.1 records manual snapshot and rollback information. It does not create snapshots, does not restore snapshots, does not roll back nodes, and does not change Leikwan Core configuration.

## Snapshot Policy

`snapshot_policy` describes how strongly a Plan should require an operator-recorded snapshot before manual execution:

```text
not_required
recommended
required
```

Defaults:

```text
ddns_check      -> recommended
create_entry    -> required
create_forward  -> required
switch_entry    -> required
```

## Snapshot Status

`snapshot_status` records what the operator has provided:

```text
not_required
missing
recorded
verified
```

`POST /api/v1/plans/:id/snapshot` records `snapshot_ref` and `snapshot_note`. It only updates Controller metadata. It does not call the Agent and does not create a snapshot on any node.

## Rollback Information

Plans include generated `rollback_instructions` with manual recovery guidance. The instructions intentionally avoid destructive commands and avoid inventing uncertain Core CLI syntax.

`POST /api/v1/plans/:id/rollback-info` records:

```text
rollback_available
rollback_ref
rollback_note
```

It does not execute rollback.

## Redaction

Snapshot and rollback metadata is redacted before storage and display. Tokens, secrets, passwords, private keys, network secrets, custom URLs, custom commands and Authorization headers must not appear in events, timelines, dry-run reports or raw JSON.

## Why This Exists

Future write automation must have an auditable recovery path before it can be considered safe. Leikwan Panel 3.0.0-alpha.1 establishes the fields, UI and API shape without enabling writes.

## 3.0.0-alpha.1 Action Review Integration

`3.0.0-alpha.1` adds action review metadata on top of this framework. Snapshot and rollback fields are treated as required gates for future write actions such as `create_entry`, `create_forward`, and `switch_entry`.

The review remains informational:

- it does not create snapshots
- it does not roll back nodes
- it does not queue Agent write tasks
- it always reports `ready_for_future_execution=false`
## Compatibility Note

This document remains under its original filename for link compatibility. The snapshot and rollback metadata model described here is part of Leikwan Panel 3.0.0-alpha.1.
