# Install Agent

Leikwan Agent `3.0.0-alpha.1` reports local state to the Controller and can optionally run fixed allowlisted tasks.

## From Web Panel

Open `Bootstrap / Add Agent`, select node role, choose whether to enable readonly tasks and alpha write actions, then copy the install command.

## Script Options

```bash
panel/scripts/install-agent.sh \
  --controller-url http://controller:18080 \
  --token <agent-token> \
  --node-name relay-1 \
  --role relay \
  --enable-tasks
```

Optional:

```bash
--enable-write-actions
```

`--enable-write-actions` is off by default. It enables only fixed 3.0 alpha actions. It does not allow arbitrary commands.

Installed files:

```text
/etc/leikwan-agent/config.yml
/usr/local/bin/leikwan-agent
/etc/systemd/system/leikwan-agent.service
```

The installer starts `leikwan-agent.service`. It does not modify nftables, EasyTier, DDNS, entries.tsv, forwards.tsv, PBR or Shell Core.
