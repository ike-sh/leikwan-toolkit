# Safety Gate

Leikwan Panel `3.0.0-alpha.2` adds a Safety Gate for Plans.

Safety Gate is a Controller-side readiness report. It is not execution permission, and it does not make the Agent run anything.

## Fields

```text
dry_run_passed
approval_ready
snapshot_ready
rollback_ready
metadata_actions_ready
evidence_count
manual_execution_recorded
manual_verification_recorded
blocked_reasons
warnings
overall
```

## Meaning

- `dry_run_passed`: the latest readonly Plan dry-run passed.
- `approval_ready`: the Plan is not classified as dangerous or blocked.
- `snapshot_ready`: snapshot metadata is recorded when policy requires it.
- `rollback_ready`: rollback instructions and manual rollback metadata are present when required.
- `metadata_actions_ready`: Controller metadata-only action support is available.
- `evidence_count`: number of manual evidence records attached to the Plan.
- `manual_execution_recorded`: an operator recorded manual execution metadata.
- `manual_verification_recorded`: an operator recorded manual verification metadata.
- `blocked_reasons`: reasons the Plan should not be manually executed yet.
- `warnings`: issues that should be reviewed but may not block a recommended-only Plan.

## API

```text
GET  /api/v1/plans/:id/safety-gate
POST /api/v1/plans/:id/verify
```

`verify` reads current Controller state, dry-run status and stored metadata. It does not create Agent tasks and does not contact nodes.

## Boundary

Safety Gate does not:

- create snapshots
- roll back nodes
- approve write execution
- restart relay
- edit nftables, systemd, EasyTier, DDNS, entries, forwards or PBR
- send command strings to Agents

`3.0.0-alpha.2` adds Write Action Review as another Controller-side design check. The review can explain which gates a future write action would need, but it never releases execution.

Future `2.2` work may consider a tiny write allowlist, but only with dry-run, snapshot, rollback, approval and audit requirements in place.
## Alpha Boundary

In 3.0.0-alpha.2, Safety Gate is an audit and readiness view only. It never grants write execution permission.

## Metadata-only Readiness

3.0.0-alpha.2 Safety Gate also reports `metadata_actions_ready`, `evidence_count`, `manual_execution_recorded`, and `manual_verification_recorded`. These fields help audit manual work; they do not permit node writes.
