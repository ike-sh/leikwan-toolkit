# DDNS

DDNS profiles can be attached to a node.

Providers:

- `manual`
- `generic_webhook`
- `cloudflare`

The Agent writes `/etc/leikwan-agent/ddns/config.json`. Tokens are redacted from API responses, events and task results. `ddns_sync_now` uses HTTP clients directly; it does not execute shell commands.

