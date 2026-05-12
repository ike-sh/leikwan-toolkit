package agent

import (
	"context"
	"encoding/json"
	"errors"
	"net"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"
)

type Collector struct {
	LQPath          string
	PublicIPFunc    func(context.Context) (string, error)
	CommandFunc     func(context.Context, string, ...string) (string, error)
	TaskCommandFunc func(context.Context, string, ...string) (string, string, int, error)
	CommandTimeout  time.Duration
}

func DefaultCollector() Collector {
	return Collector{PublicIPFunc: fetchPublicIP, CommandTimeout: 5 * time.Second}
}

func (c Collector) Collect(ctx context.Context, cfg Config) ReportRequest {
	if c.CommandTimeout <= 0 {
		c.CommandTimeout = 5 * time.Second
	}
	if c.PublicIPFunc == nil {
		c.PublicIPFunc = fetchPublicIP
	}
	hostname, _ := os.Hostname()
	report := ReportRequest{
		NodeID: cfg.NodeID, NodeName: cfg.NodeName, Role: normalizeRole(cfg.Role), Hostname: hostname,
		AgentVersion: Version, CoreVersion: "missing", Status: "online", HealthScore: 100, IntervalSeconds: cfg.IntervalSeconds,
		Services: map[string]string{},
		Capabilities: Capabilities{
			CoreVersion:                        "missing",
			EnableTasks:                        cfg.EnableTasks,
			SupportsSnapshotManualRecord:       true,
			SupportsRollbackManualRecord:       true,
			WriteActionsSupported:              cfg.EnableWriteActions,
			SupportedWriteActions:              SupportedWriteActions(cfg),
			ControllerMetadataActionsSupported: false,
			AllowedTaskActions:                 AllowedTaskActions(),
		},
	}
	if report.IntervalSeconds <= 0 {
		report.IntervalSeconds = 60
	}
	if ip, err := c.PublicIPFunc(ctx); err == nil {
		report.PublicIP = ip
	} else {
		report.PublicIP = "unknown"
		report.Errors = append(report.Errors, "public_ip: "+err.Error())
	}
	if lan := primaryLANIP(); lan != "" {
		report.PrimaryLANIP = lan
	}

	lqPath, err := c.findLQ()
	if err != nil {
		report.Status = "degraded"
		report.HealthScore = 50
		report.Errors = append(report.Errors, "lq missing")
		report.Capabilities.LQAvailable = false
	} else {
		report.Capabilities.LQAvailable = true
		if out, err := c.runCommand(ctx, lqPath, "--version"); err == nil {
			report.CoreVersion = parseCoreVersion(out)
			report.Capabilities.CoreVersion = report.CoreVersion
		} else {
			report.Status = "degraded"
			report.Errors = append(report.Errors, "lq --version: "+err.Error())
		}
		if out, err := c.runCommand(ctx, lqPath, "status", "--json"); err == nil {
			report.LQStatus = json.RawMessage(RedactJSONBytes([]byte(out)))
			if err := applyStatusJSON(&report, []byte(out)); err != nil {
				report.Status = "degraded"
				report.RecentErrors = append(report.RecentErrors, "lq status json: "+err.Error())
			} else {
				report.Capabilities.SupportsStatusJSON = true
			}
		} else {
			report.Status = "degraded"
			report.Errors = append(report.Errors, "lq status --json: "+err.Error())
		}
		if out, err := c.runCommand(ctx, lqPath, "doctor", "--json"); err == nil {
			report.LQDoctor = json.RawMessage(RedactJSONBytes([]byte(out)))
			if err := applyDoctorJSON(&report, []byte(out)); err != nil {
				report.Status = "degraded"
				report.RecentErrors = append(report.RecentErrors, "lq doctor json: "+err.Error())
			} else {
				report.Capabilities.SupportsDoctorJSON = true
			}
		} else {
			report.Status = "degraded"
			report.Errors = append(report.Errors, "lq doctor --json: "+err.Error())
		}
		report.Capabilities.SupportsForwardList = c.readonlyCommandWorks(ctx, lqPath, "forward", "list")
		report.Capabilities.SupportsDDNSOverview = c.readonlyCommandWorks(ctx, lqPath, "ddns", "overview")
	}

	report.Services["nftables"] = c.systemctlActive(ctx, "nftables")
	report.Services["easytier"] = c.systemctlActive(ctx, "leikwan-easytier")
	if report.Services["easytier"] == "unknown" || strings.Contains(report.Services["easytier"], "failed") {
		report.Services["easytier_relay"] = c.systemctlActive(ctx, "easytier-relay.service")
	}
	report.Services["leikwan-agent"] = "active"
	report.Services["ddns_timer"] = c.systemctlActive(ctx, "leikwan-ddns-refresh.timer")
	if report.Services["easytier"] == "unknown" || strings.Contains(report.Services["easytier"], "failed") {
		report.Services["easytier_entry"] = c.systemctlActive(ctx, "easytier-entry.service")
	}
	if report.Status == "degraded" && report.HealthScore > 80 {
		report.HealthScore = 80
	}
	return report
}

func (c Collector) readonlyCommandWorks(ctx context.Context, lqPath string, args ...string) bool {
	_, err := c.runCommand(ctx, lqPath, args...)
	return err == nil
}

func (c Collector) findLQ() (string, error) {
	if c.LQPath != "" {
		if _, err := os.Stat(c.LQPath); err != nil {
			return "", err
		}
		return c.LQPath, nil
	}
	if p, err := exec.LookPath("lq"); err == nil {
		return p, nil
	}
	return "", errors.New("lq not found")
}

func (c Collector) runCommand(ctx context.Context, name string, args ...string) (string, error) {
	if c.CommandFunc != nil {
		return c.CommandFunc(ctx, name, args...)
	}
	cmdCtx, cancel := context.WithTimeout(ctx, c.CommandTimeout)
	defer cancel()
	cmd := exec.CommandContext(cmdCtx, name, args...)
	out, err := cmd.CombinedOutput()
	return string(out), err
}

func (c Collector) systemctlActive(ctx context.Context, service string) string {
	if _, err := exec.LookPath("systemctl"); err != nil {
		return "unknown"
	}
	out, err := c.runCommand(ctx, "systemctl", "is-active", service)
	if err != nil {
		text := strings.TrimSpace(out)
		if text == "" {
			return "unknown"
		}
		return RedactString(text)
	}
	return strings.TrimSpace(out)
}

func fetchPublicIP(ctx context.Context) (string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, "https://api.ipify.org", nil)
	if err != nil {
		return "", err
	}
	client := &http.Client{Timeout: 4 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	buf := make([]byte, 64)
	n, _ := resp.Body.Read(buf)
	ip := strings.TrimSpace(string(buf[:n]))
	if net.ParseIP(ip) == nil {
		return "", errors.New("invalid public ip response")
	}
	return ip, nil
}

func primaryLANIP() string {
	conn, err := net.Dial("udp", "8.8.8.8:80")
	if err == nil {
		defer conn.Close()
		if addr, ok := conn.LocalAddr().(*net.UDPAddr); ok {
			return addr.IP.String()
		}
	}
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return ""
	}
	for _, addr := range addrs {
		ipNet, ok := addr.(*net.IPNet)
		if !ok || ipNet.IP.IsLoopback() {
			continue
		}
		if ip := ipNet.IP.To4(); ip != nil {
			return ip.String()
		}
	}
	return ""
}

func parseCoreVersion(out string) string {
	out = strings.TrimSpace(out)
	if out == "" {
		return "unknown"
	}
	out = strings.TrimPrefix(out, "leikwan-toolkit ")
	return out
}

func applyStatusJSON(report *ReportRequest, raw []byte) error {
	var data map[string]any
	if err := json.Unmarshal(raw, &data); err != nil {
		return err
	}
	if v, ok := data["role"].(string); ok && report.Role == "unknown" {
		report.Role = normalizeRole(v)
	}
	if v, ok := data["easytier_ip"].(string); ok {
		report.EasyTierIP = v
	}
	if v, ok := data["health_score"].(float64); ok {
		report.HealthScore = int(v)
	}
	if v, ok := data["overall"].(string); ok {
		switch strings.ToLower(v) {
		case "ok", "online":
			report.Status = "online"
		default:
			report.Status = "degraded"
		}
	}
	report.Summary = buildSummaryJSON(data)
	report.Entries = parseEntries(data["entries"])
	report.Forwards = parseForwards(data["forwards"])
	return nil
}

func applyDoctorJSON(report *ReportRequest, raw []byte) error {
	var data map[string]any
	if err := json.Unmarshal(raw, &data); err != nil {
		return err
	}
	doc := map[string]any{}
	for _, key := range []string{"overall", "warnings", "suggestions"} {
		if v, ok := data[key]; ok {
			doc[key] = v
		}
	}
	if len(doc) == 0 {
		doc = data
	}
	rawDoc, _ := json.Marshal(RedactValue(doc))
	report.Doctor = json.RawMessage(rawDoc)
	if overall, ok := data["overall"].(string); ok && strings.ToLower(overall) != "ok" {
		report.Status = "degraded"
	}
	return nil
}

func buildSummaryJSON(data map[string]any) json.RawMessage {
	summary := map[string]any{}
	if v, ok := data["summary"].(map[string]any); ok {
		summary = v
	}
	for _, key := range []string{"entries_count", "entries_total", "entries_enabled", "forwards_count", "forwards_total", "forwards_enabled", "health_score"} {
		if v, ok := data[key]; ok {
			summary[key] = v
		}
	}
	raw, _ := json.Marshal(RedactValue(summary))
	return json.RawMessage(raw)
}

func parseEntries(v any) []EntryPayload {
	items, ok := v.([]any)
	if !ok {
		return nil
	}
	out := make([]EntryPayload, 0, len(items))
	for _, item := range items {
		m, ok := item.(map[string]any)
		if !ok {
			continue
		}
		raw, _ := json.Marshal(RedactValue(m))
		out = append(out, EntryPayload{
			Name:       stringField(m, "name"),
			ListenPort: intField(m, "listen_port", "port", "easytier_port"),
			Protocol:   stringField(m, "protocol", "protocols"),
			PublicHost: stringField(m, "public_host", "host"),
			Status:     stringField(m, "status", "enabled"),
			RawJSON:    json.RawMessage(raw),
		})
	}
	return out
}

func parseForwards(v any) []ForwardPayload {
	items, ok := v.([]any)
	if !ok {
		return nil
	}
	out := make([]ForwardPayload, 0, len(items))
	for _, item := range items {
		m, ok := item.(map[string]any)
		if !ok {
			continue
		}
		raw, _ := json.Marshal(RedactValue(m))
		out = append(out, ForwardPayload{
			Name:       stringField(m, "name"),
			EntryName:  stringField(m, "entry_name", "entry"),
			TargetHost: stringField(m, "target_host"),
			TargetPort: intField(m, "target_port"),
			Protocol:   stringField(m, "protocol", "protocols"),
			Status:     stringField(m, "status", "enabled"),
			RawJSON:    json.RawMessage(raw),
		})
	}
	return out
}

func stringField(m map[string]any, keys ...string) string {
	for _, key := range keys {
		switch v := m[key].(type) {
		case string:
			return v
		case bool:
			if v {
				return "true"
			}
			return "false"
		case []any:
			parts := make([]string, 0, len(v))
			for _, item := range v {
				if s, ok := item.(string); ok {
					parts = append(parts, s)
				}
			}
			return strings.Join(parts, ",")
		}
	}
	return ""
}

func intField(m map[string]any, keys ...string) int {
	for _, key := range keys {
		switch v := m[key].(type) {
		case float64:
			return int(v)
		case int:
			return v
		}
	}
	return 0
}
