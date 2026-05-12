# Leikwan Panel 2.2.0-alpha.3

`2.2.0-alpha.3` is a demo apply release. It is not a production automation promise. The goal is to make the first Controller install, Agent join, Network creation, Entry creation, Forward creation and Apply task flow usable from the Web Panel.

## Difference From 2.1.0 Stable

`2.1.0` is the stable safety-control release: readonly tasks, manual plans, dry-run, snapshot / rollback metadata, Safety Gate, Action Catalog, Write Action Review and Operator Auth.

`2.2.0-alpha.3` adds a narrow demo apply path:

- Web Bootstrap can generate Agent install commands.
- Controller can store Network / Entry / Forward records.
- Apply can create allowlisted Agent tasks.
- Write-enabled Agents can stage Panel-managed JSON config files.
- Landing/backend machines are configured as `target_host:target_port` and do not need Agents.

## Alpha Write Actions

These are enabled in the Action Catalog, but only work on Agents reporting `enable_write_actions=true`:

- `configure_node_role`
- `apply_network_profile`
- `apply_entry_config`
- `apply_forward_config`
- `reload_leikwan_core`
- `verify_applied_config`

The Agent maps each action to fixed Go logic or fixed readonly argv. It does not accept a Controller-provided command string.

## Still Disabled

These real node mutation actions remain disabled / future:

- `create_entry`
- `create_forward`
- `switch_entry`
- `update_ddns_config`
- `rollback_config`
- `restart_relay`

Blocked actions remain permanently blocked:

- arbitrary command
- `shell -c`
- `bash -c`
- `eval`
- raw nft
- raw iptables
- raw ip route
- `rm`
- arbitrary write into `/etc`
- `curl | bash`

## Safety Boundary

`2.2.0-alpha.3` can write only Panel-managed staging files on write-enabled Agent nodes:

- `/etc/leikwan-toolkit/panel-network.json`
- `/etc/leikwan-toolkit/panel-entry.json`
- `/etc/leikwan-toolkit/panel-forward.json`

The Agent creates simple backups under `/var/backups/leikwan-panel-agent/` before overwriting those files. It does not modify Shell Core TSV files, nftables, systemd, EasyTier, DDNS or PBR.

## Known Limits

- This is a demo alpha.
- It does not configure backend/landing machines.
- It does not implement smooth public entry switching.
- It does not restart relay.
- It does not run rollback.
- It does not bridge all staged JSON into stable Core CLI changes yet.

Future 2.2.x versions can decide whether a tiny subset of write actions should graduate from staged demo config into guarded Core integration.
