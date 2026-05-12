# Demo Apply Alpha

`3.0.0-alpha.2` is the first release that can ask a write-enabled Agent to do a tiny set of fixed actions. This is a demo path for validating install and basic Panel workflow.

## What It Can Do

With `enable_write_actions=true`, an Agent can run fixed actions for EasyTier config, entry ports, forward rules, PBR, DDNS, firewall reload and node lifecycle operations.

Files are restricted to `/etc/leikwan-toolkit/panel-network.json`, `/etc/leikwan-toolkit/panel-entry.json`, `/etc/leikwan-toolkit/panel-forward.json` and `/var/lib/leikwan-panel-agent/`.

Backups are written to `/var/backups/leikwan-panel-agent/`.

## What It Cannot Do

It cannot accept command strings, run `shell -c`, run `bash -c`, run `eval`, run raw nft / iptables / ip route, add real Core forwards directly, switch public entries, restart relay, create snapshots, run rollback or manage backend/landing nodes.

## Why This Exists

The alpha.3 demo proves that the Controller, Web UI, Operator Auth, Agent token, Agent capabilities and task lifecycle can carry a tiny fixed write workflow without opening arbitrary command execution.
