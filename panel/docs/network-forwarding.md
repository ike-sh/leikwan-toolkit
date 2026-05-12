# Network / Entry / Forward

`3.0.0-alpha.1` keeps the model intentionally small:

- Network: EasyTier network metadata and relay node.
- Entry: public entry node, relay node and TCP/UDP port range.
- Forward: listen port to `target_host:target_port`.

Apply Entry creates fixed tasks for the entry and relay nodes. Apply Forward creates fixed tasks for the entry and relay nodes only. No backend node task is created.

The first alpha writes Panel-managed nftables config and asks the Agent to load it with fixed argv. It does not accept raw nft rules from users.

