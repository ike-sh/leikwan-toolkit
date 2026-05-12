package agent

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

var readonlyTaskActions = map[string][]string{
	"probe_core_version": {"--version"},
	"run_status":         {"status"},
	"run_status_json":    {"status", "--json"},
	"run_doctor":         {"doctor"},
	"run_doctor_json":    {"doctor", "--json"},
	"list_forwards":      {"forward", "list"},
	"ddns_overview":      {"ddns", "overview"},
}

var builtinReadonlyActions = map[string]struct{}{
	"node_status":     {},
	"easytier_status": {},
	"nftables_status": {},
	"pbr_status":      {},
	"ddns_status":     {},
	"list_entries":    {},
	"verify_config":   {},
}

var alphaWriteTaskActions = map[string]string{
	"configure_node_role":        "panel-node-role.json",
	"apply_network_profile":      "panel-network.json",
	"apply_entry_config":         "panel-entry.json",
	"apply_forward_config":       "panel-forward.json",
	"reload_leikwan_core":        "",
	"verify_applied_config":      "",
	"install_easytier":           "",
	"configure_easytier_network": "",
	"start_easytier":             "",
	"restart_easytier":           "",
	"stop_easytier":              "",
	"apply_entry_ports":          "",
	"apply_forward_rules":        "",
	"apply_pbr_rules":            "",
	"apply_ddns_config":          "",
	"ddns_sync_now":              "",
	"reload_firewall_rules":      "",
	"restart_agent":              "",
	"reboot_node":                "",
}

func AllowedTaskActions() []string {
	out := make([]string, 0, len(readonlyTaskActions))
	for action := range readonlyTaskActions {
		out = append(out, action)
	}
	for action := range builtinReadonlyActions {
		out = append(out, action)
	}
	sort.Strings(out)
	return out
}

func SupportedWriteActions(cfg Config) []string {
	if !cfg.EnableWriteActions {
		return []string{}
	}
	out := make([]string, 0, len(alphaWriteTaskActions))
	for action := range alphaWriteTaskActions {
		out = append(out, action)
	}
	sort.Strings(out)
	return out
}

func TaskActionArgs(action string) ([]string, bool) {
	args, ok := readonlyTaskActions[action]
	if !ok {
		if _, builtin := builtinReadonlyActions[action]; builtin {
			return []string{"<builtin>", "readonly"}, true
		}
		return nil, false
	}
	cp := append([]string(nil), args...)
	return cp, true
}

func ExecuteTask(ctx context.Context, collector Collector, cfg Config, task Task) TaskResultRequest {
	action := strings.TrimSpace(task.Action)
	if _, ok := builtinReadonlyActions[action]; ok {
		return executeBuiltinReadonlyTask(ctx, collector, cfg, task)
	}
	args, ok := TaskActionArgs(action)
	if !ok {
		if _, writeOK := alphaWriteTaskActions[action]; writeOK {
			return executeAlphaWriteTask(ctx, collector, cfg, task)
		}
		return TaskResultRequest{
			Status:   "rejected",
			ExitCode: 1,
			Error:    RedactString("unsupported readonly task action: " + task.Action),
		}
	}
	lqPath, err := collector.findLQ()
	if err != nil {
		return TaskResultRequest{
			Status:   "failed",
			ExitCode: 127,
			Error:    "lq missing: " + RedactString(err.Error()),
		}
	}
	timeout := time.Duration(cfg.TaskTimeoutSeconds) * time.Second
	if timeout <= 0 {
		timeout = 20 * time.Second
	}
	runCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	stdout, stderr, exitCode, err := collector.runTaskCommand(runCtx, lqPath, args...)
	result := TaskResultRequest{
		Status:       "succeeded",
		ResultStdout: truncateTaskOutput(stdout, cfg.TaskResultLimitKB),
		ResultStderr: truncateTaskOutput(stderr, cfg.TaskResultLimitKB),
		ExitCode:     exitCode,
	}
	if err != nil {
		result.Status = "failed"
		result.Error = truncateTaskOutput(err.Error(), cfg.TaskResultLimitKB)
		if errors.Is(runCtx.Err(), context.DeadlineExceeded) {
			result.Error = "task timeout"
		}
		if result.ExitCode == 0 {
			result.ExitCode = 1
		}
	}
	return result
}

func executeAlphaWriteTask(ctx context.Context, collector Collector, cfg Config, task Task) TaskResultRequest {
	action := strings.TrimSpace(task.Action)
	if !cfg.EnableWriteActions {
		return TaskResultRequest{Status: "rejected", ExitCode: 1, Error: "alpha write actions are disabled on this Agent"}
	}
	if _, ok := alphaWriteTaskActions[action]; !ok {
		return TaskResultRequest{Status: "rejected", ExitCode: 1, Error: RedactString("unsupported alpha write action: " + action)}
	}
	if payloadContainsCommand(task.PayloadJSON) {
		return TaskResultRequest{Status: "rejected", ExitCode: 1, Error: "payload command strings are not accepted"}
	}
	timeout := time.Duration(cfg.TaskTimeoutSeconds) * time.Second
	if timeout <= 0 {
		timeout = 20 * time.Second
	}
	runCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	var stdout string
	var err error
	switch action {
	case "configure_node_role":
		stdout, err = writePanelFile("panel-node-role.json", task.PayloadJSON)
	case "apply_network_profile":
		stdout, err = writePanelFile("panel-network.json", task.PayloadJSON)
	case "apply_entry_config":
		stdout, err = writePanelFile("panel-entry.json", task.PayloadJSON)
	case "apply_forward_config":
		stdout, err = writePanelFile("panel-forward.json", task.PayloadJSON)
	case "reload_leikwan_core":
		stdout, err = runReadonlyCoreValidation(runCtx, collector, cfg)
	case "verify_applied_config":
		stdout, err = verifyPanelFiles()
	case "install_easytier":
		stdout, err = installEasyTier(runCtx, collector)
	case "configure_easytier_network":
		stdout, err = configureEasyTierNetwork(task.PayloadJSON)
	case "start_easytier":
		stdout, err = runFixedCommand(runCtx, collector, "systemctl", "start", "leikwan-easytier")
	case "restart_easytier":
		stdout, err = runFixedCommand(runCtx, collector, "systemctl", "restart", "leikwan-easytier")
	case "stop_easytier":
		stdout, err = runFixedCommand(runCtx, collector, "systemctl", "stop", "leikwan-easytier")
	case "apply_entry_ports":
		stdout, err = applyEntryPorts(task.PayloadJSON)
	case "apply_forward_rules":
		stdout, err = applyForwardRules(task.PayloadJSON)
	case "apply_pbr_rules":
		stdout, err = applyPBRRules(runCtx, collector, task.PayloadJSON)
	case "apply_ddns_config":
		stdout, err = applyDDNSConfig(task.PayloadJSON)
	case "ddns_sync_now":
		stdout, err = syncDDNSNow(runCtx, task.PayloadJSON)
	case "reload_firewall_rules":
		stdout, err = reloadFirewallRules(runCtx, collector)
	case "restart_agent":
		stdout, err = runFixedCommand(runCtx, collector, "systemctl", "restart", "leikwan-agent")
	case "reboot_node":
		stdout, err = rebootNode(runCtx, collector, task.PayloadJSON)
	default:
		err = fmt.Errorf("unsupported alpha write action")
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

func payloadContainsCommand(raw json.RawMessage) bool {
	if len(raw) == 0 {
		return false
	}
	var v any
	if err := json.Unmarshal(raw, &v); err != nil {
		return false
	}
	return containsCommandKey(v)
}

func containsCommandKey(v any) bool {
	switch x := v.(type) {
	case map[string]any:
		for k, val := range x {
			if strings.EqualFold(k, "command") || strings.EqualFold(k, "cmd") || strings.EqualFold(k, "shell") {
				return true
			}
			if containsCommandKey(val) {
				return true
			}
		}
	case []any:
		for _, item := range x {
			if containsCommandKey(item) {
				return true
			}
		}
	}
	return false
}

func panelEtcDir() string {
	if v := strings.TrimSpace(os.Getenv("LEIKWAN_AGENT_ETC_DIR")); v != "" {
		return v
	}
	return "/etc/leikwan-toolkit"
}

func panelStateDir() string {
	if v := strings.TrimSpace(os.Getenv("LEIKWAN_AGENT_STATE_DIR")); v != "" {
		return v
	}
	return "/var/lib/leikwan-panel-agent"
}

func panelBackupDir() string {
	if v := strings.TrimSpace(os.Getenv("LEIKWAN_AGENT_BACKUP_DIR")); v != "" {
		return v
	}
	return "/var/backups/leikwan-panel-agent"
}

func safePath(base, name string) (string, error) {
	if strings.Contains(name, "/") || strings.Contains(name, "\\") || strings.TrimSpace(name) == "" {
		return "", fmt.Errorf("invalid panel file name")
	}
	cleanBase, err := filepath.Abs(base)
	if err != nil {
		return "", err
	}
	target := filepath.Join(cleanBase, name)
	cleanTarget, err := filepath.Abs(target)
	if err != nil {
		return "", err
	}
	if cleanTarget != filepath.Join(cleanBase, filepath.Base(name)) {
		return "", fmt.Errorf("target path is outside allowed directory")
	}
	return cleanTarget, nil
}

func writePanelFile(name string, payload json.RawMessage) (string, error) {
	if len(payload) == 0 || string(payload) == "null" {
		payload = json.RawMessage(`{}`)
	}
	target, err := safePath(panelEtcDir(), name)
	if err != nil {
		return "", err
	}
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		return "", err
	}
	if existing, err := os.ReadFile(target); err == nil {
		backupName := filepath.Base(name) + "." + time.Now().UTC().Format("20060102T150405Z") + ".bak"
		backup, err := safePath(panelBackupDir(), backupName)
		if err != nil {
			return "", err
		}
		if err := os.MkdirAll(filepath.Dir(backup), 0o700); err != nil {
			return "", err
		}
		if err := os.WriteFile(backup, existing, 0o600); err != nil {
			return "", err
		}
	}
	var formatted bytes.Buffer
	if err := json.Indent(&formatted, RedactJSONBytes(payload), "", "  "); err != nil {
		formatted.Write(RedactJSONBytes(payload))
	}
	if err := os.WriteFile(target, formatted.Bytes(), 0o600); err != nil {
		return "", err
	}
	if err := os.MkdirAll(panelStateDir(), 0o755); err != nil {
		return "", err
	}
	return "wrote Panel-managed staging file: " + RedactString(target), nil
}

func verifyPanelFiles() (string, error) {
	names := []string{"panel-network.json", "panel-entry.json", "panel-forward.json"}
	found := []string{}
	for _, name := range names {
		target, err := safePath(panelEtcDir(), name)
		if err != nil {
			return "", err
		}
		if _, err := os.Stat(target); err == nil {
			found = append(found, name)
		}
	}
	if len(found) == 0 {
		return "", fmt.Errorf("no Panel-managed staging files found")
	}
	sort.Strings(found)
	return "verified Panel-managed staging files: " + strings.Join(found, ", "), nil
}

func runReadonlyCoreValidation(ctx context.Context, collector Collector, cfg Config) (string, error) {
	lqPath, err := collector.findLQ()
	if err != nil {
		return "", fmt.Errorf("lq missing: %w", err)
	}
	checks := [][]string{{"status"}, {"doctor"}, {"forward", "list"}}
	out := []string{}
	for _, args := range checks {
		stdout, stderr, exitCode, err := collector.runTaskCommand(ctx, lqPath, args...)
		line := fmt.Sprintf("lq %s exit=%d", strings.Join(args, " "), exitCode)
		if strings.TrimSpace(stdout) != "" {
			line += " stdout=" + truncateTaskOutput(stdout, cfg.TaskResultLimitKB)
		}
		if strings.TrimSpace(stderr) != "" {
			line += " stderr=" + truncateTaskOutput(stderr, cfg.TaskResultLimitKB)
		}
		out = append(out, line)
		if err != nil {
			return strings.Join(out, "\n"), err
		}
	}
	return strings.Join(out, "\n"), nil
}

func (c Collector) runTaskCommand(ctx context.Context, name string, args ...string) (string, string, int, error) {
	if c.TaskCommandFunc != nil {
		return c.TaskCommandFunc(ctx, name, args...)
	}
	cmd := exec.CommandContext(ctx, name, args...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	exitCode := 0
	if err != nil {
		exitCode = 1
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			exitCode = exitErr.ExitCode()
		}
		if ctx.Err() == context.DeadlineExceeded {
			err = fmt.Errorf("task timeout")
		}
	}
	return stdout.String(), stderr.String(), exitCode, err
}

func truncateTaskOutput(s string, limitKB int) string {
	s = RedactString(s)
	if limitKB <= 0 {
		limitKB = 64
	}
	if limitKB > 64 {
		limitKB = 64
	}
	maxBytes := limitKB * 1024
	if len(s) <= maxBytes {
		return s
	}
	return s[:maxBytes] + "\n[TRUNCATED]"
}
