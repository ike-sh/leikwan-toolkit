# Install Controller

Leikwan Controller `3.0.0-alpha.1` is the Web/API server for the Panel demo.

## One-click Install

```bash
curl -fsSL https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/panel/scripts/install-controller.sh | bash
```

Options:

```bash
--version 3.0.0-alpha.1
--listen 0.0.0.0:18080
--data-dir /var/lib/leikwan-panel
--agent-token <token>
--operator-token <token>
--strict-auth
```

If tokens are omitted, the installer generates strong random tokens and writes `/etc/leikwan-panel/controller.env`.

Installed files:

```text
/usr/local/bin/leikwan-controller
/etc/systemd/system/leikwan-controller.service
/var/lib/leikwan-panel/controller.db
```

The script starts `leikwan-controller.service` and prints the Web URL, Operator token, Agent token and next step.

It does not install Agent and does not modify Leikwan Shell Core.
