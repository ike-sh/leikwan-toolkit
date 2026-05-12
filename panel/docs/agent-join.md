# Agent Join

Agents connect outward to the Controller. The Controller does not SSH into nodes and does not need inbound access to the Agent host.

## Bootstrap Page

Open `Web Panel -> Bootstrap`.

Fill Controller URL, node name, role, readonly task toggle and alpha write action toggle. The page returns an install command. By default the token is masked. With a valid Operator token, the command can include the Agent token.

## Alpha Write Actions

`--enable-write-actions` is off by default. When enabled, the Agent reports `write_actions_supported=true` and the fixed alpha action list. These actions can write Panel-managed config and run fixed argv only; they never accept command strings.
