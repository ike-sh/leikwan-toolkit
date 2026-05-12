# Leikwan Toolkit

Leikwan Toolkit Shell Core is frozen at `1.4.0 LTS`.

Leikwan Toolkit is a TCP/UDP forwarding toolkit for an **A public entry + B relay host + C backend target** topology. The Shell Core remains responsible for real forwarding behavior: EasyTier, nftables, DDNS, PBR, snapshots and local maintenance.

## Core Quick Start

```bash
curl -fsSL -o /tmp/lq-bootstrap.sh https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/scripts/bootstrap.sh && bash /tmp/lq-bootstrap.sh
lq init
```

Common Core commands:

```bash
lq init
lq status
lq --doctor
lq ddns overview
lq forward apply-relay --auto-fix-route
lq update check
```

## Leikwan Panel 2.1.0 Stable

Leikwan Panel `2.1.0` is the stable safety-control plane. It provides Controller / Agent / Web UI for observation, readonly diagnostics, manual planning and audit metadata.

It supports Controller / Agent, node heartbeat, readonly status reports, readonly Tasks, Plan manual execution, Plan dry-run, Snapshot / Rollback metadata, Safety Gate, Action Catalog, Write Action Review, Operator Auth and strict-auth.

It does **not** execute write operations, create write tasks, accept command strings, add/delete/modify forwards, switch public entries, restart relay, create snapshots, run rollback, or modify nftables, systemd, EasyTier, DDNS, entries, forwards or PBR.

## Leikwan Panel 3.0.0-alpha.1

`3.0.0-alpha.1` is the first **real apply alpha**. It can install/configure EasyTier, write Panel nftables/PBR/DDNS config, reload Panel firewall rules and queue fixed node actions when an operator explicitly enables `enable_write_actions=true` on that Agent.

The demo flow is intentionally small:

1. Install Controller.
2. Open Web Panel.
3. Unlock with Operator token.
4. Add Agent nodes from the Bootstrap page.
5. Create a Network profile.
6. Create an Entry.
7. Create a Forward.
8. Apply.
9. Watch Tasks.

Controller one-click install:

```bash
curl -fsSL https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/panel/scripts/install-controller.sh | bash
```

Agent one-click join:

```text
Copy the command from Web Panel -> Bootstrap / Add Agent.
```

Alpha write actions are fixed allowlisted actions only:

- `configure_node_role`
- `apply_network_profile`
- `apply_entry_config`
- `apply_forward_config`
- `reload_leikwan_core`
- `verify_applied_config`
- `install_easytier`
- `configure_easytier_network`
- `start_easytier`
- `restart_easytier`
- `stop_easytier`
- `apply_entry_ports`
- `apply_forward_rules`
- `apply_pbr_rules`
- `apply_ddns_config`
- `ddns_sync_now`
- `reload_firewall_rules`
- `restart_agent`
- `reboot_node`

They do not accept command strings, do not run `shell -c`, do not run `bash -c`, do not run `eval`, and do not expose raw nft / iptables / ip route operations. Panel writes only under its own managed paths such as `/etc/leikwan-agent/`, `/etc/systemd/system/leikwan-easytier.service`, `/var/backups/leikwan-panel-agent/` and uses fixed argv for `systemctl`, `nft`, `ip` and `reboot`. The landing/backend machine does **not** need an Agent; it is configured as `target_host:target_port`.

Still disabled or blocked:

- `create_entry`
- `create_forward`
- `switch_entry`
- `rollback_config`
- `restart_relay`
- arbitrary commands
- raw shell
- raw nft / iptables / ip route

## Deployment Model

- Controller can run on a dedicated management host.
- Agents run on A public entry and B relay nodes.
- C backend/landing machines do not need Agents.
- Agents connect outward to Controller.
- Controller outage does not affect existing Core forwarding.
- `LEIKWAN_CONTROLLER_TOKEN` is for Agents.
- `LEIKWAN_OPERATOR_TOKEN` is for Web / Operator APIs.
- Agent token and Operator token are intentionally not interchangeable.

## Panel Local Development

Controller:

```bash
cd panel/controller
go test ./...
go run ./cmd/leikwan-controller --listen 127.0.0.1:18080 --db ./data/controller.db
```

Agent:

```bash
cd panel/agent
go test ./...
go run ./cmd/leikwan-agent --config ./agent.yml --once
```

Web:

```bash
cd panel/controller
npm --prefix web install
npm --prefix web run build
```

Panel release package:

```bash
bash panel/scripts/build-release.sh
```

Output:

```text
panel/dist/leikwan-controller
panel/dist/leikwan-agent
panel/dist/web/
panel/dist/docs/
panel/dist/examples/
panel/dist/scripts/
panel/dist/SHA256SUMS
```

## Docs

- [Panel 2.1.0 Release Notes](panel/docs/release-2.1.0.md)
- [Panel 3.0 Alpha Notes](panel/docs/release-3.0-alpha.md)
- [Quick Start](panel/docs/quickstart.md)
- [One-click Install](panel/docs/one-click-install.md)
- [Agent Join](panel/docs/agent-join.md)
- [Network / Forwarding](panel/docs/network-forwarding.md)
- [PBR](panel/docs/pbr.md)
- [DDNS](panel/docs/ddns.md)
- [Security](panel/docs/security.md)
- [Operator Auth](panel/docs/operator-auth.md)
- [Action Catalog](panel/docs/action-catalog.md)
- [Safety Model](panel/docs/safety-model.md)
