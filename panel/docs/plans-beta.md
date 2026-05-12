# Plans

Leikwan Panel Plans remain manual-only in `3.0.0-alpha.1`.

Plans are still safe by design:

- Controller stores drafts, classifies safety, and generates text only.
- Agent may optionally pull only builtin readonly tasks, but Plans are never executed by Agent.
- Agent does not execute Plan commands.
- No node system is modified by the Panel.
- Leikwan Core files, nftables, systemd, EasyTier, DDNS, entries, forwards and PBR remain untouched.

## Plan Types

```text
create_entry
create_forward
switch_entry
ddns_check
```

- `create_entry`: draft manual steps for adding an A public entry.
- `create_forward`: draft manual steps for adding a forward target.
- `switch_entry`: conservative inspection guide for a possible entry switch.
- `ddns_check`: read-only DDNS inspection guide.

## Plan Status

```text
draft
generated
copied
archived
```

## Manual Execution Status

```text
not_run
running_manually
succeeded
failed
rolled_back
```

These fields are audit notes only. Marking a plan as `succeeded`, `failed` or `rolled_back` never changes a node.

## Generated Artifacts

When a plan is generated, Controller stores:

- `generated_commands`: backward-compatible flat command list.
- `command_groups`: commands grouped by node.
- `checklist`: manual verification checklist.
- `markdown`: a redacted execution guide.
- `warnings`: risk notes.
- `safety_level`: `safe`, `caution` or `dangerous`.
- `command_classification`: `readonly`, `manual` or `blocked`.
- `preflight`: Controller-side checks that do not run node commands.
- `capability_requirements`: read-only Core commands needed for manual verification.

The Markdown guide always states:

```text
This plan is manual-only. The agent will not execute it.
```

## Write Action Review

`3.0.0-alpha.1` adds review-only APIs for future write actions:

```text
GET  /api/v1/plans/:id/action-review
POST /api/v1/plans/:id/action-review
```

The review maps the Plan type to a future action such as `create_forward` or `switch_entry`, shows its risk level, required gates and missing gates, then returns:

```text
ready_for_future_execution=false
```

The reason is always:

```text
write execution is disabled in 3.0.0-alpha.1
```

Action review does not create Agent tasks, does not modify nodes, and does not generate shell commands.

## Allowed Commands

Generated command text may include read-only checks:

```bash
lq --version
lq status
lq status --json
lq doctor
lq doctor --json
lq forward list
lq ddns overview
```

If Leikwan Core does not expose a stable non-interactive CLI for an operation, Panel writes a `# TODO` manual step instead of inventing a command.

## Preflight

`POST /api/v1/plans/:id/preflight` checks Controller-known state only:

- target node selected
- target node known to Controller
- target node online/offline
- node role matching the plan type
- no blocked command text present
- Markdown generated
- warnings present

Preflight never SSHs into a node and never asks Agent to run anything.

## Readonly Dry-run

`POST /api/v1/plans/:id/dry-run` creates linked readonly tasks for the target node. It is still a preflight, not execution.

`GET /api/v1/plans/:id/dry-run` refreshes the aggregate report from task results.

Dry-run fields:

```text
dry_run_status
dry_run_task_ids
dry_run_report
last_dry_run_at
```

Dry-run uses only the built-in allowlist tasks:

```text
run_status_json
run_doctor_json
list_forwards
ddns_overview
```

It never runs Plan generated command text and never modifies a node.

## Forbidden Commands

Plans must not generate:

```text
rm
systemctl restart
systemctl stop
nft
iptables
ip route
curl | bash
eval
bash -c
direct writes into /etc
```

## Redaction

Plan payload, generated commands, Markdown, events and raw JSON are redacted for:

```text
token
secret
password
privateKey
network_secret
custom_url
custom_cmd
Authorization
```

## Why Not Automatic Execution Yet

Automatic write execution needs a permission model, write allowlists, dry-run, snapshots, review, audit logs, rollback handling and explicit operator approval. These are still out of scope.

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
## Compatibility Note

This document remains under its original filename for link compatibility. Plans are part of Leikwan Panel 3.0.0-alpha.1 and remain manual-only.
