# Leikwan Panel systemd 示例

��ҳ�ṩ Leikwan Panel 3.0.0-alpha.1 �� systemd �ݰ���3.0.0-alpha.1 �����Զ�ִ�����ñ���������޸�?Leikwan Core �� nftables��systemd��EasyTier��DDNS �� TSV ���á�
## Controller 配置路径

建议路径�?
```text
/usr/local/bin/leikwan-controller
/var/lib/leikwan-panel/controller.db
/etc/leikwan-panel/controller.yml
```

`controller.yml` 示例�?
```yaml
token: change-me
```

也可以使用环境变量：

```text
LEIKWAN_CONTROLLER_TOKEN=change-me
```

## leikwan-controller.service

示例文件见：

```text
panel/examples/leikwan-controller.service
```

内容�?
```ini
[Unit]
Description=Leikwan Panel Controller
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=-/etc/leikwan-panel/controller.env
ExecStart=/usr/local/bin/leikwan-controller --listen 0.0.0.0:18080 --db /var/lib/leikwan-panel/controller.db
Restart=on-failure
RestartSec=5s
User=root

[Install]
WantedBy=multi-user.target
```

## Agent 配置路径

建议路径�?
```text
/usr/local/bin/leikwan-agent
/etc/leikwan-agent/config.yml
```

`config.yml` 示例见：

```text
panel/examples/agent.yml
```

## leikwan-agent.service

示例文件见：

```text
panel/examples/leikwan-agent.service
```

内容�?
```ini
[Unit]
Description=Leikwan Panel Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/leikwan-agent --config /etc/leikwan-agent/config.yml
Restart=on-failure
RestartSec=5s
User=root

[Install]
WantedBy=multi-user.target
```

## 启用服务

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now leikwan-controller.service
sudo systemctl enable --now leikwan-agent.service
```

## 查看日志

```bash
journalctl -u leikwan-controller.service -n 100 --no-pager
journalctl -u leikwan-agent.service -n 100 --no-pager
```

日志中不应出�?token、secret、password、privateKey、custom_url、custom_cmd �?Authorization 明文�?
## 3.0.0-alpha.1 Operator Token Example

`/etc/leikwan-panel/controller.env` can contain both tokens:

```text
LEIKWAN_CONTROLLER_TOKEN=agent-token
LEIKWAN_OPERATOR_TOKEN=operator-token
```

`LEIKWAN_CONTROLLER_TOKEN` is used only by Agents. `LEIKWAN_OPERATOR_TOKEN` is used by the Web UI and operator APIs. To require the Operator token for all non-health Web APIs, add `--strict-auth` to the Controller `ExecStart`.
