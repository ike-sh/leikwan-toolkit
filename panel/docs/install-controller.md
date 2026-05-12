# Install Controller

Leikwan Controller `3.0.0-alpha.2` is the Web/API server for the Panel demo.

## One-click Install

```bash
curl -fsSL https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/panel/scripts/install-controller.sh | sudo bash
```

Options:

```bash
--version 3.0.0-alpha.2
--listen 0.0.0.0:18080
--data-dir /var/lib/leikwan-panel
--agent-token <token>
--operator-token <token>
--release-url <url>
--public-url http://1.2.3.4:18080
--strict-auth
```

If tokens are omitted, the installer generates strong random tokens and writes `/etc/leikwan-panel/controller.env`. The generated admin password is printed once and is also used as the initial Operator token.

Download order:

1. Local `panel/dist` when the script is run from a checkout.
2. GitHub Release assets under `v3.0.0-alpha.2` and `panel-3.0.0-alpha.2`.
3. Source build fallback from the GitHub `main` tarball.

Installed files:

```text
/usr/local/bin/leikwan-controller
/etc/systemd/system/leikwan-controller.service
/var/lib/leikwan-panel/controller.db
/var/lib/leikwan-panel/web
```

The script starts `leikwan-controller.service` and prints the Web URL, Operator token, Agent token and next step.

It does not install Agent and does not modify Leikwan Shell Core.
