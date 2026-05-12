# Action Catalog

Leikwan Panel `3.0.0-alpha.1` exposes all known actions through `/api/v1/action-catalog`.

## Readonly Actions

Readonly task actions are enabled and mapped to fixed Agent argv:

- `probe_core_version`
- `run_status`
- `run_status_json`
- `run_doctor`
- `run_doctor_json`
- `list_forwards`
- `ddns_overview`

They do not accept command strings.

## Metadata-only Actions

Controller-only metadata actions remain enabled:

- `record_snapshot_ref`
- `record_rollback_ref`
- `mark_plan_executed`
- `mark_plan_verified`
- `attach_manual_evidence`

They update Controller audit metadata only and never create Agent tasks.

## Demo Alpha Write Actions

`3.0.0-alpha.1` enables a narrow `alpha_write` category:

- `configure_node_role`
- `apply_network_profile`
- `apply_entry_config`
- `apply_forward_config`
- `reload_leikwan_core`
- `verify_applied_config`

These require Operator token, Agent token for pickup, target node online, Agent `enable_write_actions=true`, fixed action allowlist and redacted payload.

In 3.0 alpha they can write Panel-managed EasyTier, nftables, PBR and DDNS config or run fixed lifecycle argv. They do not expose arbitrary command dispatch.

## Future Node Writes Still Disabled

These actions stay disabled / future:

- `create_entry`
- `create_forward`
- `switch_entry`
- `update_ddns_config`
- `rollback_config`
- `restart_relay`

The 3.0 alpha apply flow uses lower-level fixed actions instead of enabling high-level guarded actions such as `create_forward` or `switch_entry`.

## Permanently Blocked Actions

Blocked actions stay disabled:

- `arbitrary_command`
- `shell_c`
- `bash_c`
- `eval`
- `raw_nft`
- `raw_iptables`
- `raw_ip_route`
- `rm`
- `write_etc`
- `curl_pipe_bash`

The Controller does not accept command strings for any action.
