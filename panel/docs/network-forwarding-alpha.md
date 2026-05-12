# Network / Entry / Forwarding Alpha

Leikwan Panel `3.0.0-alpha.1` adds a minimal Controller-side model for demo forwarding setup.

## Network Profile

A Network Profile stores name, network name, network secret and relay node id. The network secret is redacted in API responses and hidden in the UI.

## Entry

An Entry stores network id, entry node id, relay node id, listen host, port pool and protocols. Applying an Entry queues fixed Agent tasks for the entry node and relay node.

## Forward

A Forward stores network id, entry id, relay node id, name, listen port, target host, target port and protocol.

The backend/landing machine does not need an Agent. It is simply `target_host:target_port`.

## Apply

Apply creates a task group:

- entry node: `apply_network_profile`, `apply_entry_config`, `verify_applied_config`
- relay node: `apply_network_profile`, `apply_forward_config`, `verify_applied_config`

Tasks are accepted only by Agents with `enable_write_actions=true`.

## Current Limit

This alpha stages Panel-managed JSON files. It does not yet fully translate the model into Shell Core forwarding rules.
