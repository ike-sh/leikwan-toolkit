# Leikwan Panel Quick Start

1. Install Controller:

```bash
curl -fsSL https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/panel/scripts/install-controller.sh | sudo bash
```

2. Open the Web URL printed by the installer.
3. Enter the Operator token.
4. Open **Bootstrap / Add Agent**.
5. Copy the generated install command to each A/B VPS.
6. Wait for nodes to become online.
7. Create Network, Entry and Forward.
8. Click Apply and watch Tasks.

Backend / landing machines do not need Agent. A Forward uses `target_host:target_port`.

