# Safety Model

Leikwan Panel `3.0.0-alpha.1` is a demo apply release with a narrow write boundary.

## Still Forbidden

The Panel still forbids Controller-provided command strings, user-entered shell commands, `shell -c`, `bash -c`, `eval`, raw nft, raw iptables, raw ip route, `rm`, arbitrary write into `/etc`, `curl | bash`, Agent token calling Operator APIs, Operator token calling Agent APIs, backend/landing node management, smooth public entry switching, relay restart automation and rollback automation.

## Readonly Tasks

Readonly tasks are fixed Agent actions mapped to fixed `lq` argv.

## Metadata-only Actions

Metadata actions update only Controller DB audit state.

## Demo Alpha Write Actions

`3.0.0-alpha.1` enables fixed alpha actions only when an Agent has `enable_write_actions=true`:

- `configure_node_role`
- `apply_network_profile`
- `apply_entry_config`
- `apply_forward_config`
- `reload_leikwan_core`
- `verify_applied_config`

Those actions can write Panel-managed config files and use fixed argv only:

- `/etc/leikwan-toolkit/panel-network.json`
- `/etc/leikwan-toolkit/panel-entry.json`
- `/etc/leikwan-toolkit/panel-forward.json`
- `/var/lib/leikwan-panel-agent/`

Backups go to `/var/backups/leikwan-panel-agent/`.

## Operator Auth

All mutating Controller APIs require Operator token. Agent token cannot call them. Agent APIs require Agent token and do not accept Operator token.

## Redaction

Task payloads, results, stdout, stderr, raw JSON, evidence and timeline entries are redacted for tokens, secrets, passwords, private keys, network secrets, custom URLs, custom commands and Authorization headers.
