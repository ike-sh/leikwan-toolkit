package agent

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"time"
)

func executeBuiltinReadonlyTask(ctx context.Context, collector Collector, cfg Config, task Task) TaskResultRequest {
	timeout := time.Duration(cfg.TaskTimeoutSeconds) * time.Second
	if timeout <= 0 {
		timeout = 20 * time.Second
	}
	runCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	action := strings.TrimSpace(task.Action)
	var stdout string
	var err error
	switch action {
	case "node_status":
		stdout, err = nodeStatusJSON(cfg)
	case "easytier_status":
		stdout, err = runFixedCommand(runCtx, collector, "systemctl", "is-active", "leikwan-easytier")
	case "nftables_status":
		stdout, err = nftablesStatus(runCtx, collector)
	case "pbr_status":
		stdout, err = runFixedCommand(runCtx, collector, "ip", "rule", "show")
	case "ddns_status":
		stdout, err = readOptionalJSONFile(ddnsConfigPath())
	case "list_entries":
		stdout, err = readOptionalJSONFile(panelEntryConfigPath())
	case "verify_config":
		stdout, err = verifyRealConfigFiles()
	default:
		err = fmt.Errorf("unsupported readonly action")
	}
	if errors.Is(runCtx.Err(), context.DeadlineExceeded) {
		err = fmt.Errorf("task timeout")
	}
	result := TaskResultRequest{Status: "succeeded", ResultStdout: truncateTaskOutput(stdout, cfg.TaskResultLimitKB), ExitCode: 0}
	if err != nil {
		result.Status = "failed"
		result.Error = truncateTaskOutput(err.Error(), cfg.TaskResultLimitKB)
		result.ExitCode = 1
	}
	return result
}

func runFixedCommand(ctx context.Context, collector Collector, name string, args ...string) (string, error) {
	stdout, stderr, exitCode, err := collector.runTaskCommand(ctx, name, args...)
	text := strings.TrimSpace(stdout)
	if strings.TrimSpace(stderr) != "" {
		if text != "" {
			text += "\n"
		}
		text += "stderr=" + strings.TrimSpace(stderr)
	}
	if err != nil {
		return RedactString(text), fmt.Errorf("%s %s failed exit=%d: %w", name, strings.Join(args, " "), exitCode, err)
	}
	if text == "" {
		text = fmt.Sprintf("%s %s ok", name, strings.Join(args, " "))
	}
	return RedactString(text), nil
}

func nodeStatusJSON(cfg Config) (string, error) {
	host, _ := os.Hostname()
	raw, _ := json.Marshal(map[string]any{
		"hostname":              host,
		"agent_version":         Version,
		"node_id":               cfg.NodeID,
		"node_name":             cfg.NodeName,
		"role":                  normalizeRole(cfg.Role),
		"enable_tasks":          cfg.EnableTasks,
		"enable_write_actions":  cfg.EnableWriteActions,
		"write_actions":         SupportedWriteActions(cfg),
		"shell_core_is_managed": false,
	})
	return string(raw), nil
}

func installEasyTier(ctx context.Context, collector Collector) (string, error) {
	for _, path := range []string{"/usr/local/bin/easytier-core", "/usr/bin/easytier-core", "easytier-core"} {
		if strings.Contains(path, "/") {
			if st, err := os.Stat(path); err == nil && !st.IsDir() {
				return "easytier-core already installed at " + path, nil
			}
			continue
		}
		if found, err := exec.LookPath(path); err == nil {
			return "easytier-core already installed at " + found, nil
		}
	}
	url := strings.TrimSpace(os.Getenv("LEIKWAN_AGENT_EASYTIER_URL"))
	if url == "" {
		url = defaultEasyTierURL()
	}
	if url == "" {
		return "", fmt.Errorf("easytier-core not found and no download URL is known for arch %s", runtime.GOARCH)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return "", err
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("download easytier-core: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		return "", fmt.Errorf("download easytier-core returned %s", resp.Status)
	}
	buf, err := io.ReadAll(io.LimitReader(resp.Body, 100<<20))
	if err != nil {
		return "", err
	}
	if len(buf) == 0 {
		return "", fmt.Errorf("downloaded easytier-core is empty")
	}
	if err := writeAllowedFile("/usr/local/bin/easytier-core", buf, 0o755); err != nil {
		return "", err
	}
	installState := map[string]any{"status": "installed", "arch": runtime.GOARCH, "source": RedactString(url), "installed_at": time.Now().UTC().Format(time.RFC3339)}
	_ = writeAllowedJSON(easytierInstallStatePath(), installState, 0o600)
	_ = collector
	return "downloaded easytier-core to /usr/local/bin/easytier-core", nil
}

func defaultEasyTierURL() string {
	switch runtime.GOARCH {
	case "amd64":
		return "https://github.com/EasyTier/EasyTier/releases/latest/download/easytier-linux-x86_64"
	case "arm64":
		return "https://github.com/EasyTier/EasyTier/releases/latest/download/easytier-linux-aarch64"
	default:
		return ""
	}
}

func configureEasyTierNetwork(raw json.RawMessage) (string, error) {
	payload, err := objectPayload(raw)
	if err != nil {
		return "", err
	}
	payload["managed_by"] = "leikwan-panel"
	payload["version"] = Version
	if err := writeAllowedJSON(easytierConfigPath(), payload, 0o600); err != nil {
		return "", err
	}
	service := `[Unit]
Description=Leikwan Panel EasyTier
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/easytier-core --config /etc/leikwan-agent/easytier/config.json
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
`
	if err := writeAllowedFile(filepath.Join(agentSystemdDir(), "leikwan-easytier.service"), []byte(service), 0o644); err != nil {
		return "", err
	}
	return "wrote EasyTier config and leikwan-easytier.service", nil
}

func applyEntryPorts(raw json.RawMessage) (string, error) {
	payload, err := objectPayload(raw)
	if err != nil {
		return "", err
	}
	entry := nestedObject(payload, "entry")
	start := intFromAny(firstValue(entry, payload, "listen_port_start", "port_start"))
	end := intFromAny(firstValue(entry, payload, "listen_port_end", "port_end"))
	if end == 0 {
		end = start
	}
	if err := validatePortRange(start, end); err != nil {
		return "", err
	}
	protocols, err := normalizeProtocols(stringFromAny(firstValue(entry, payload, "protocols", "protocol")))
	if err != nil {
		return "", err
	}
	listenHost := stringFromAny(firstValue(entry, payload, "listen_host"))
	if listenHost == "" {
		listenHost = "0.0.0.0"
	}
	if err := validateHostOrWildcard(listenHost); err != nil {
		return "", err
	}
	payload["validated"] = map[string]any{"listen_port_start": start, "listen_port_end": end, "protocols": protocols, "listen_host": listenHost}
	if err := writeAllowedJSON(panelEntryConfigPath(), payload, 0o600); err != nil {
		return "", err
	}
	config := buildNFTConfig("entry", protocols, start, end, "", 0)
	if err := writeAllowedFile(nftConfigPath(), []byte(config), 0o600); err != nil {
		return "", err
	}
	return fmt.Sprintf("wrote entry ports %d-%d for %s", start, end, strings.Join(protocols, ",")), nil
}

func applyForwardRules(raw json.RawMessage) (string, error) {
	payload, err := objectPayload(raw)
	if err != nil {
		return "", err
	}
	forward := nestedObject(payload, "forward")
	listenPort := intFromAny(firstValue(forward, payload, "listen_port"))
	targetPort := intFromAny(firstValue(forward, payload, "target_port"))
	if err := validatePortRange(listenPort, listenPort); err != nil {
		return "", fmt.Errorf("listen_port: %w", err)
	}
	if err := validatePortRange(targetPort, targetPort); err != nil {
		return "", fmt.Errorf("target_port: %w", err)
	}
	targetHost := stringFromAny(firstValue(forward, payload, "target_host"))
	if err := validateHostOrWildcard(targetHost); err != nil || targetHost == "0.0.0.0" {
		if err == nil {
			err = fmt.Errorf("target_host is required")
		}
		return "", err
	}
	protocols, err := normalizeProtocols(stringFromAny(firstValue(forward, payload, "protocol", "protocols")))
	if err != nil {
		return "", err
	}
	payload["validated"] = map[string]any{"listen_port": listenPort, "target_host": targetHost, "target_port": targetPort, "protocols": protocols}
	if err := writeAllowedJSON(panelForwardConfigPath(), payload, 0o600); err != nil {
		return "", err
	}
	config := buildNFTConfig("forward", protocols, listenPort, listenPort, targetHost, targetPort)
	if err := writeAllowedFile(nftConfigPath(), []byte(config), 0o600); err != nil {
		return "", err
	}
	return fmt.Sprintf("wrote forward %d -> %s:%d for %s", listenPort, RedactString(targetHost), targetPort, strings.Join(protocols, ",")), nil
}

func reloadFirewallRules(ctx context.Context, collector Collector) (string, error) {
	if _, err := os.Stat(nftConfigPath()); err != nil {
		return "", fmt.Errorf("nftables config not found: %w", err)
	}
	if _, err := exec.LookPath("nft"); err != nil {
		if _, installErr := runFixedCommand(ctx, collector, "apt-get", "install", "-y", "nftables"); installErr != nil {
			return "", fmt.Errorf("nft missing and apt-get install failed: %w", installErr)
		}
	}
	return runFixedCommand(ctx, collector, "nft", "-f", nftConfigPath())
}

func nftablesStatus(ctx context.Context, collector Collector) (string, error) {
	if _, err := os.Stat(nftConfigPath()); err == nil {
		return runFixedCommand(ctx, collector, "nft", "-c", "-f", nftConfigPath())
	}
	return runFixedCommand(ctx, collector, "nft", "list", "ruleset")
}

func applyPBRRules(ctx context.Context, collector Collector, raw json.RawMessage) (string, error) {
	payload, err := objectPayload(raw)
	if err != nil {
		return "", err
	}
	sourceCIDR := stringFromAny(payload["source_cidr"])
	targetCIDR := stringFromAny(payload["target_cidr"])
	if sourceCIDR != "" {
		if _, _, err := net.ParseCIDR(sourceCIDR); err != nil {
			return "", fmt.Errorf("invalid source_cidr")
		}
	}
	if targetCIDR != "" {
		if _, _, err := net.ParseCIDR(targetCIDR); err != nil {
			return "", fmt.Errorf("invalid target_cidr")
		}
	}
	iface := stringFromAny(payload["output_interface"])
	if iface != "" && !interfaceNameRe.MatchString(iface) {
		return "", fmt.Errorf("invalid output_interface")
	}
	tableID := intFromAny(payload["table_id"])
	priority := intFromAny(payload["priority"])
	if tableID <= 0 || tableID > 999999 {
		return "", fmt.Errorf("invalid table_id")
	}
	if priority <= 0 || priority > 999999 {
		return "", fmt.Errorf("invalid priority")
	}
	if err := writeAllowedJSON(pbrConfigPath(), payload, 0o600); err != nil {
		return "", err
	}
	output := []string{"wrote pbr config"}
	if sourceCIDR != "" {
		out, err := runFixedCommand(ctx, collector, "ip", "rule", "add", "from", sourceCIDR, "priority", strconv.Itoa(priority), "table", strconv.Itoa(tableID))
		output = append(output, out)
		if err != nil {
			return strings.Join(output, "\n"), err
		}
	}
	args := []string{"route", "replace"}
	if targetCIDR != "" {
		args = append(args, targetCIDR)
	} else {
		args = append(args, "default")
	}
	if gw := stringFromAny(payload["gateway"]); gw != "" {
		if net.ParseIP(gw) == nil {
			return strings.Join(output, "\n"), fmt.Errorf("invalid gateway")
		}
		args = append(args, "via", gw)
	}
	if iface != "" {
		args = append(args, "dev", iface)
	}
	args = append(args, "table", strconv.Itoa(tableID))
	out, err := runFixedCommand(ctx, collector, "ip", args...)
	output = append(output, out)
	return strings.Join(output, "\n"), err
}

func applyDDNSConfig(raw json.RawMessage) (string, error) {
	payload, err := objectPayload(raw)
	if err != nil {
		return "", err
	}
	provider := strings.ToLower(stringFromAny(payload["provider"]))
	switch provider {
	case "cloudflare", "generic_webhook", "manual":
	default:
		return "", fmt.Errorf("unsupported ddns provider")
	}
	if strings.TrimSpace(stringFromAny(payload["domain"])) == "" {
		return "", fmt.Errorf("domain is required")
	}
	if err := writeAllowedJSON(ddnsConfigPath(), payload, 0o600); err != nil {
		return "", err
	}
	return "wrote ddns config for " + RedactString(stringFromAny(payload["domain"])), nil
}

func syncDDNSNow(ctx context.Context, raw json.RawMessage) (string, error) {
	payload, err := objectPayload(raw)
	if err != nil {
		return "", err
	}
	if len(payload) == 0 {
		if text, err := os.ReadFile(ddnsConfigPath()); err == nil {
			payload, err = objectPayload(text)
			if err != nil {
				return "", err
			}
		}
	}
	provider := strings.ToLower(stringFromAny(payload["provider"]))
	domain := stringFromAny(payload["domain"])
	if domain == "" {
		return "", fmt.Errorf("domain is required")
	}
	publicIP, err := fetchPublicIP(ctx)
	if err != nil {
		return "", fmt.Errorf("public ip: %w", err)
	}
	switch provider {
	case "manual", "":
		return fmt.Sprintf("manual ddns check: %s -> %s", RedactString(domain), publicIP), nil
	case "generic_webhook":
		target := strings.ReplaceAll(stringFromAny(payload["target"]), "{domain}", domain)
		target = strings.ReplaceAll(target, "{host}", domain)
		target = strings.ReplaceAll(target, "{ip}", publicIP)
		if target == "" {
			return "", fmt.Errorf("generic_webhook target is required")
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, target, nil)
		if err != nil {
			return "", err
		}
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			return "", err
		}
		defer resp.Body.Close()
		_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
		if resp.StatusCode >= 300 {
			return "", fmt.Errorf("generic webhook returned %s", resp.Status)
		}
		return "generic webhook ddns sync ok for " + RedactString(domain), nil
	case "cloudflare":
		token := stringFromAny(payload["api_token"])
		zoneID := stringFromAny(payload["zone_id"])
		recordID := stringFromAny(payload["record_id"])
		recordType := strings.ToUpper(stringFromAny(payload["record_type"]))
		if recordType == "" {
			recordType = "A"
		}
		if token == "" || zoneID == "" || recordID == "" {
			return "", fmt.Errorf("cloudflare api_token, zone_id and record_id are required")
		}
		body, _ := json.Marshal(map[string]any{"type": recordType, "name": domain, "content": publicIP, "ttl": 120, "proxied": false})
		url := "https://api.cloudflare.com/client/v4/zones/" + zoneID + "/dns_records/" + recordID
		req, err := http.NewRequestWithContext(ctx, http.MethodPatch, url, bytes.NewReader(body))
		if err != nil {
			return "", err
		}
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Content-Type", "application/json")
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			return "", err
		}
		defer resp.Body.Close()
		if resp.StatusCode >= 300 {
			return "", fmt.Errorf("cloudflare returned %s", resp.Status)
		}
		return "cloudflare ddns sync ok for " + RedactString(domain), nil
	default:
		return "", fmt.Errorf("unsupported ddns provider")
	}
}

func rebootNode(ctx context.Context, collector Collector, raw json.RawMessage) (string, error) {
	payload, err := objectPayload(raw)
	if err != nil {
		return "", err
	}
	if stringFromAny(payload["confirm"]) != "REBOOT" {
		return "", fmt.Errorf("reboot requires confirm=REBOOT")
	}
	return runFixedCommand(ctx, collector, "reboot")
}

func verifyRealConfigFiles() (string, error) {
	names := []string{
		easytierConfigPath(),
		panelEntryConfigPath(),
		panelForwardConfigPath(),
		nftConfigPath(),
		pbrConfigPath(),
		ddnsConfigPath(),
	}
	found := []string{}
	for _, name := range names {
		if _, err := os.Stat(name); err == nil {
			found = append(found, name)
		}
	}
	if len(found) == 0 {
		return "", fmt.Errorf("no Panel-managed config files found")
	}
	sort.Strings(found)
	return "verified Panel-managed config files: " + RedactString(strings.Join(found, ", ")), nil
}

func readOptionalJSONFile(path string) (string, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	return string(RedactJSONBytes(raw)), nil
}

func objectPayload(raw json.RawMessage) (map[string]any, error) {
	if len(raw) == 0 || string(raw) == "null" {
		return map[string]any{}, nil
	}
	var payload map[string]any
	if err := json.Unmarshal(raw, &payload); err != nil {
		return nil, fmt.Errorf("payload must be JSON object")
	}
	return payload, nil
}

func nestedObject(payload map[string]any, key string) map[string]any {
	if m, ok := payload[key].(map[string]any); ok {
		return m
	}
	return map[string]any{}
}

func firstValue(primary, fallback map[string]any, keys ...string) any {
	for _, key := range keys {
		if v, ok := primary[key]; ok {
			return v
		}
		if v, ok := fallback[key]; ok {
			return v
		}
	}
	return nil
}

func intFromAny(v any) int {
	switch x := v.(type) {
	case float64:
		return int(x)
	case int:
		return x
	case string:
		n, _ := strconv.Atoi(strings.TrimSpace(x))
		return n
	default:
		return 0
	}
}

func stringFromAny(v any) string {
	switch x := v.(type) {
	case string:
		return strings.TrimSpace(x)
	case float64:
		return strconv.Itoa(int(x))
	case int:
		return strconv.Itoa(x)
	default:
		return ""
	}
}

func normalizeProtocols(text string) ([]string, error) {
	text = strings.ToLower(strings.TrimSpace(text))
	if text == "" || text == "both" || text == "tcp,udp" || text == "udp,tcp" {
		return []string{"tcp", "udp"}, nil
	}
	parts := strings.FieldsFunc(text, func(r rune) bool { return r == ',' || r == ' ' || r == '/' || r == '+' })
	out := []string{}
	seen := map[string]bool{}
	for _, part := range parts {
		switch part {
		case "tcp", "udp":
			if !seen[part] {
				out = append(out, part)
				seen[part] = true
			}
		default:
			return nil, fmt.Errorf("invalid protocol")
		}
	}
	if len(out) == 0 {
		return nil, fmt.Errorf("protocol is required")
	}
	sort.Strings(out)
	return out, nil
}

func validatePortRange(start, end int) error {
	if start <= 0 || start > 65535 || end <= 0 || end > 65535 || start > end {
		return fmt.Errorf("invalid port range")
	}
	return nil
}

var hostRe = regexp.MustCompile(`^[A-Za-z0-9_.:-]+$`)
var interfaceNameRe = regexp.MustCompile(`^[A-Za-z0-9_.:-]{1,64}$`)

func validateHostOrWildcard(host string) error {
	if strings.TrimSpace(host) == "" {
		return fmt.Errorf("host is required")
	}
	if host == "0.0.0.0" || host == "::" {
		return nil
	}
	if ip := net.ParseIP(host); ip != nil {
		return nil
	}
	if !hostRe.MatchString(host) || strings.Contains(host, "..") {
		return fmt.Errorf("invalid host")
	}
	return nil
}

func buildNFTConfig(kind string, protocols []string, start, end int, targetHost string, targetPort int) string {
	var b strings.Builder
	b.WriteString("table ip leikwan_panel {\n")
	b.WriteString("  chain prerouting {\n")
	b.WriteString("    type nat hook prerouting priority dstnat; policy accept;\n")
	for _, proto := range protocols {
		portExpr := strconv.Itoa(start)
		if end > start {
			portExpr = strconv.Itoa(start) + "-" + strconv.Itoa(end)
		}
		if kind == "forward" && targetHost != "" && targetPort > 0 && net.ParseIP(targetHost) != nil {
			b.WriteString(fmt.Sprintf("    %s dport %s dnat to %s:%d\n", proto, portExpr, targetHost, targetPort))
		} else {
			b.WriteString(fmt.Sprintf("    %s dport %s accept comment \"leikwan-panel-%s\"\n", proto, portExpr, kind))
		}
	}
	b.WriteString("  }\n")
	b.WriteString("}\n")
	return b.String()
}

func writeAllowedJSON(path string, v any, perm os.FileMode) error {
	raw, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	return writeAllowedFile(path, raw, perm)
}

func writeAllowedFile(path string, data []byte, perm os.FileMode) error {
	clean, err := allowedAbsolutePath(path)
	if err != nil {
		return err
	}
	if existing, err := os.ReadFile(clean); err == nil {
		if err := backupBytes(clean, existing); err != nil {
			return err
		}
	}
	if err := os.MkdirAll(filepath.Dir(clean), 0o755); err != nil {
		return err
	}
	return os.WriteFile(clean, data, perm)
}

func allowedAbsolutePath(path string) (string, error) {
	if strings.TrimSpace(path) == "" {
		return "", fmt.Errorf("empty path")
	}
	abs, err := filepath.Abs(path)
	if err != nil {
		return "", err
	}
	allowed := []string{
		agentConfigDir(),
		agentSystemdDir(),
		"/var/lib/leikwan-panel-agent",
		"/usr/local/bin",
	}
	for _, base := range allowed {
		baseAbs, err := filepath.Abs(base)
		if err != nil {
			continue
		}
		rel, err := filepath.Rel(baseAbs, abs)
		if err == nil && rel != "." && !strings.HasPrefix(rel, "..") && !filepath.IsAbs(rel) {
			return abs, nil
		}
	}
	return "", fmt.Errorf("path is outside allowed directories")
}

func backupBytes(path string, data []byte) error {
	base := panelBackupDir()
	rel := strings.TrimPrefix(filepath.ToSlash(path), "/")
	name := strings.ReplaceAll(rel, "/", "_")
	name = regexp.MustCompile(`[^A-Za-z0-9._-]`).ReplaceAllString(name, "_") + "." + time.Now().UTC().Format("20060102T150405Z") + ".bak"
	target, err := safePath(base, name)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(target), 0o700); err != nil {
		return err
	}
	return os.WriteFile(target, data, 0o600)
}

func agentConfigDir() string {
	if v := strings.TrimSpace(os.Getenv("LEIKWAN_AGENT_CONFIG_DIR")); v != "" {
		return v
	}
	return "/etc/leikwan-agent"
}

func agentSystemdDir() string {
	if v := strings.TrimSpace(os.Getenv("LEIKWAN_AGENT_SYSTEMD_DIR")); v != "" {
		return v
	}
	return "/etc/systemd/system"
}

func easytierConfigPath() string { return filepath.Join(agentConfigDir(), "easytier", "config.json") }
func easytierInstallStatePath() string {
	return filepath.Join(agentConfigDir(), "easytier", "install.json")
}
func nftConfigPath() string          { return filepath.Join(agentConfigDir(), "nftables", "leikwan-panel.nft") }
func pbrConfigPath() string          { return filepath.Join(agentConfigDir(), "pbr", "pbr.json") }
func ddnsConfigPath() string         { return filepath.Join(agentConfigDir(), "ddns", "config.json") }
func panelEntryConfigPath() string   { return filepath.Join(agentConfigDir(), "panel-entry.json") }
func panelForwardConfigPath() string { return filepath.Join(agentConfigDir(), "panel-forward.json") }
