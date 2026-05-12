# Capabilities

Leikwan Panel `3.0.0-alpha.2` uses capabilities to decide what can be requested from a node.

## Readonly Capabilities

Agents report whether they can run fixed readonly checks:

- `lq_available`
- `supports_status_json`
- `supports_doctor_json`
- `supports_forward_list`
- `supports_ddns_overview`
- `enable_tasks`
- `allowed_task_actions`

Readonly task actions remain fixed and do not accept command strings.

## Alpha Write Capabilities

Agents report write support only when configured with `enable_write_actions=true`:

```json
{
  "write_actions_supported": true,
  "supported_write_actions": [
    "configure_node_role",
    "apply_network_profile",
    "apply_entry_config",
    "apply_forward_config",
    "reload_leikwan_core",
    "verify_applied_config"
  ]
}
```

Otherwise Agents report:

```json
{
  "write_actions_supported": false,
  "supported_write_actions": []
}
```

## Controller Checks Before Apply

Before creating alpha write tasks, the Controller checks:

- Operator token is valid.
- node is online.
- node reports `write_actions_supported=true`.
- action is in `supported_write_actions`.
- Action Catalog says the action is enabled.
- action is not blocked.
- task payload does not contain `command`, `cmd` or `shell` fields.

Capabilities do not bypass Operator Auth and do not permit arbitrary commands.
