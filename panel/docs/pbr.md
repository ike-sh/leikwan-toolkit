# PBR

PBR policies are Controller records applied to relay nodes through fixed Agent action `apply_pbr_rules`.

Supported fields:

- source CIDR
- target CIDR
- output interface
- gateway
- table id
- priority

The Agent validates CIDR, interface name, table id and priority. It writes `/etc/leikwan-agent/pbr/pbr.json` and uses fixed `ip rule` / `ip route` argv. Raw `ip route` payload is not accepted.

