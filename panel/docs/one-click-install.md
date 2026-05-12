# One-click Install

Leikwan Panel `3.0.0-alpha.2` includes conservative install scripts for demo deployment. They install Panel binaries and systemd units only. They do not modify Leikwan Shell Core, nftables, EasyTier, DDNS, entries, forwards or PBR.

## Controller

```bash
curl -fsSL https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/panel/scripts/install-controller.sh | sudo bash
```

Supported options:

```bash
--version 3.0.0-alpha.2
--listen 0.0.0.0:18080
--data-dir /var/lib/leikwan-panel
--agent-token <token>
--operator-token <token>
--release-url <url>
--strict-auth
```

If tokens are not provided, the script generates strong random tokens and stores them in `/etc/leikwan-panel/controller.env`. If a release asset is not available yet, the script tries multiple release asset names and then falls back to building from the GitHub source tarball.

It installs `/usr/local/bin/leikwan-controller`, `/etc/systemd/system/leikwan-controller.service`, `/var/lib/leikwan-panel/controller.db` and Web assets under `/var/lib/leikwan-panel/web`.

## Agent

Agents should normally be installed using the command copied from `Web Panel -> Bootstrap / Add Agent`.

Example:

```bash
curl -fsSL https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/panel/scripts/install-agent.sh | sudo bash -s -- \
  --controller-url http://PANEL_HOST:18080 \
  --token AGENT_TOKEN \
  --node-name relay-1 \
  --role relay \
  --enable-tasks \
  --enable-write-actions
```

Add `--enable-write-actions` only for alpha/demo nodes where you accept Panel-managed staging file writes.
