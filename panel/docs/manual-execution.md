# Manual Execution

Leikwan Panel `3.0.0-alpha.1` does not execute configuration changes. It creates an execution guide that an operator copies and runs manually on the target node.

## Create a Plan

1. Open `Plans`.
2. Select a type: `create_entry`, `create_forward`, `switch_entry` or `ddns_check`.
3. Select the target node.
4. Fill the intent fields.
5. Create the draft.
6. Generate the guide.
7. Run preflight.

## Review the Checklist

The generated checklist is intentionally conservative:

- Confirm the target node and role.
- Run `lq status`.
- Run `lq doctor`.
- Confirm snapshot and rollback path.
- After manual execution, run `lq status` again.
- After manual execution, run `lq doctor` again.

For `switch_entry`, the checklist also reminds you to verify the new entry first, keep the old entry available and use a low-traffic window.

## Review Safety and Preflight

Each generated plan includes:

- safety level: `safe`, `caution` or `dangerous`
- command classification: `readonly`, `manual` or `blocked`
- capability requirements
- preflight checks

Preflight is Controller-only. It does not run commands on the node.

## Copy Commands

Use `Copy commands` to copy only the command text. Commands are grouped by node and are limited to read-only checks plus manual `# TODO` notes when Core CLI details are intentionally not automated.

## Copy Markdown

Use `Copy markdown` to copy the full execution guide for change review or an operations ticket. The guide is redacted and includes:

- warnings
- checklist
- command groups
- redacted payload

## Execute Manually

SSH to the target node yourself. The Agent will not receive this plan, will not execute it, and will not change the node.

## Mark the Result

After manual work, mark the plan as:

- `running_manually`
- `succeeded`
- `failed`
- `rolled_back`

This only updates Controller audit state. It does not modify the node.

## Safety Boundary

Panel Leikwan Panel 3.0.0-alpha.1 does not:

- push tasks to Agent
- run remote commands
- restart relay
- write nftables or systemd
- edit EasyTier, DDNS, entries, forwards or PBR
- modify `leikwan-toolkit.sh`
