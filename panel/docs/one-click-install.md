# One-click Install

Leikwan Panel `3.0.0-alpha.1` includes conservative install scripts for demo deployment. They install Panel binaries and systemd units only. They do not modify Leikwan Shell Core, nftables, EasyTier, DDNS, entries, forwards or PBR.

## Controller

```bash
curl -fsSL https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/panel/scripts/install-controller.sh | bash
```

Supported options:

```bash
--version 3.0.0-alpha.1
--listen 0.0.0.0:18080
--data-dir /var/lib/leikwan-panel
--agent-token <token>
--operator-token <token>
--strict-auth
```

If tokens are not provided, the script generates strong random tokens and stores them in `/etc/leikwan-panel/controller.env`.

It installs `/usr/local/bin/leikwan-controller`, `/etc/systemd/system/leikwan-controller.service` and `/var/lib/leikwan-panel/controller.db`.

## Agent

Agents should normally be installed using the command copied from `Web Panel -> Bootstrap / Add Agent`.

Add `--enable-write-actions` only for alpha/demo nodes where you accept Panel-managed staging file writes.
