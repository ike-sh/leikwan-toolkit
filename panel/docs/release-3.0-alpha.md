# Leikwan Panel 3.0.0-alpha.1

`3.0.0-alpha.1` is the first real apply alpha for the Panel line.

It can queue fixed Agent actions for:

- EasyTier install/config/start/status.
- Entry node public port range config.
- Relay node TCP/UDP forward config.
- PBR rule config.
- DDNS config and sync.
- Agent / EasyTier restart and confirmed node reboot.

The Shell Core remains independent at `1.4.0 LTS`; `leikwan-toolkit.sh` is not modified by this release.

## Boundaries

- No arbitrary command strings.
- No Web shell input.
- No Controller `command` / `cmd` / `shell` payload.
- No `shell -c`, `bash -c` or `eval`.
- No raw nft / iptables / ip route payload.
- Backend / landing machines do not need Agent.
- Relay restart automation is still not implemented.
- Smooth public entry switching is still not implemented.

## Managed Paths

Agents write only Panel-managed files:

- `/etc/leikwan-agent/easytier/config.json`
- `/etc/systemd/system/leikwan-easytier.service`
- `/etc/leikwan-agent/nftables/leikwan-panel.nft`
- `/etc/leikwan-agent/pbr/pbr.json`
- `/etc/leikwan-agent/ddns/config.json`

Backups are written under `/var/backups/leikwan-panel-agent/`.

