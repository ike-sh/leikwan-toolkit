package agent

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func TestRedactCleansSecrets(t *testing.T) {
	raw := []byte(`{"token":"abc","secret":"s","password":"p","privateKey":"k","custom_url":"https://example.com?token=abc","custom_cmd":"cmd --token abc"}`)
	redacted := string(RedactJSONBytes(raw))
	for _, leak := range []string{"abc", "--token abc", "https://example.com?token=abc"} {
		if strings.Contains(redacted, leak) {
			t.Fatalf("redaction leaked %q in %s", leak, redacted)
		}
	}
}

func TestCollectorDoesNotCrashWhenLQMissing(t *testing.T) {
	c := Collector{
		LQPath: filepath.Join(t.TempDir(), "missing-lq"),
		PublicIPFunc: func(context.Context) (string, error) {
			return "", errors.New("no network")
		},
	}
	report := c.Collect(context.Background(), Config{NodeID: "node-a", NodeName: "A", Role: "entry"})
	if report.CoreVersion != "missing" {
		t.Fatalf("expected missing core version, got %q", report.CoreVersion)
	}
	if report.Status != "degraded" {
		t.Fatalf("expected degraded, got %q", report.Status)
	}
	if report.Capabilities.LQAvailable {
		t.Fatalf("expected lq unavailable capabilities: %+v", report.Capabilities)
	}
	if report.Capabilities.WriteActionsSupported || len(report.Capabilities.SupportedWriteActions) != 0 {
		t.Fatalf("agent must not advertise write actions by default: %+v", report.Capabilities)
	}
	if report.Capabilities.ControllerMetadataActionsSupported {
		t.Fatalf("agent must not participate in Controller metadata actions: %+v", report.Capabilities)
	}
	if report.NodeID != "node-a" {
		t.Fatalf("node id not preserved: %q", report.NodeID)
	}
}

func TestConfigParser(t *testing.T) {
	path := filepath.Join(t.TempDir(), "agent.yml")
	content := "controller_url: http://127.0.0.1:18080\nnode_id: n1\nnode_name: test\nrole: relay\ninterval_seconds: 5\ntoken: secret\nenable_tasks: true\ntask_interval_seconds: 3\ntask_timeout_seconds: 4\nmax_concurrent_tasks: 3\ntask_result_limit_kb: 12\n"
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	cfg, err := LoadConfig(path)
	if err != nil {
		t.Fatal(err)
	}
	if cfg.ControllerURL != "http://127.0.0.1:18080" || cfg.Role != "relay" || cfg.IntervalSeconds != 5 || !cfg.EnableTasks || cfg.TaskIntervalSeconds != 3 || cfg.TaskTimeoutSeconds != 4 || cfg.MaxConcurrentTasks != 1 || cfg.TaskResultLimitKB != 12 {
		t.Fatalf("unexpected config: %+v", cfg)
	}
}

func TestLoadConfigWritesStableNodeIDState(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "agent.yml")
	nodeIDPath := filepath.Join(dir, "node_id")
	t.Setenv("LEIKWAN_AGENT_NODE_ID_FILE", nodeIDPath)
	content := "controller_url: http://127.0.0.1:18080\nnode_name: Demo Node\nrole: relay\ntoken: secret\nenable_tasks: true\n"
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	cfg, err := LoadConfig(path)
	if err != nil {
		t.Fatal(err)
	}
	if cfg.NodeID == "" {
		t.Fatalf("expected generated stable node_id")
	}
	raw, err := os.ReadFile(nodeIDPath)
	if err != nil {
		t.Fatalf("expected node_id state file: %v", err)
	}
	if strings.TrimSpace(string(raw)) != cfg.NodeID {
		t.Fatalf("state node_id mismatch: %q vs %q", string(raw), cfg.NodeID)
	}
	cfg2, err := LoadConfig(path)
	if err != nil {
		t.Fatal(err)
	}
	if cfg2.NodeID != cfg.NodeID {
		t.Fatalf("node_id should be stable: %q vs %q", cfg.NodeID, cfg2.NodeID)
	}
}

func TestWriteConfig(t *testing.T) {
	path := filepath.Join(t.TempDir(), "agent.yml")
	err := WriteConfig(path, Config{ControllerURL: "http://127.0.0.1:18080", Token: "secret-token", NodeName: "node-a", Role: "entry", IntervalSeconds: 7, EnableTasks: true, TaskIntervalSeconds: 8, TaskTimeoutSeconds: 9, TaskResultLimitKB: 16})
	if err != nil {
		t.Fatal(err)
	}
	cfg, err := LoadConfig(path)
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Token != "secret-token" || cfg.Role != "entry" || cfg.NodeName != "node-a" || cfg.IntervalSeconds != 7 || !cfg.EnableTasks || cfg.TaskIntervalSeconds != 8 || cfg.TaskTimeoutSeconds != 9 || cfg.MaxConcurrentTasks != 1 || cfg.TaskResultLimitKB != 16 {
		t.Fatalf("unexpected config: %+v", cfg)
	}
	if runtime.GOOS != "windows" {
		info, err := os.Stat(path)
		if err != nil {
			t.Fatal(err)
		}
		if info.Mode().Perm() != 0o600 {
			t.Fatalf("expected 0600 config mode, got %o", info.Mode().Perm())
		}
	}
}

func TestCollectorBadJSONDegrades(t *testing.T) {
	lqPath := filepath.Join(t.TempDir(), "lq")
	if err := os.WriteFile(lqPath, []byte("placeholder"), 0o700); err != nil {
		t.Fatal(err)
	}
	c := Collector{
		LQPath: lqPath,
		PublicIPFunc: func(context.Context) (string, error) {
			return "203.0.113.10", nil
		},
		CommandFunc: func(_ context.Context, _ string, args ...string) (string, error) {
			if len(args) == 1 && args[0] == "--version" {
				return "leikwan-toolkit 1.4.0 LTS", nil
			}
			return "{bad-json", nil
		},
	}
	report := c.Collect(context.Background(), Config{NodeID: "node-a", NodeName: "A", Role: "relay", IntervalSeconds: 9})
	if report.Status != "degraded" {
		t.Fatalf("expected degraded, got %q", report.Status)
	}
	if len(report.RecentErrors) == 0 {
		t.Fatalf("expected recent JSON parse errors")
	}
	if report.IntervalSeconds != 9 {
		t.Fatalf("interval not reported: %d", report.IntervalSeconds)
	}
	if !report.Capabilities.LQAvailable || report.Capabilities.SupportsStatusJSON || report.Capabilities.SupportsDoctorJSON {
		t.Fatalf("bad json capabilities should be degraded but available without json support: %+v", report.Capabilities)
	}
}

func TestCollectorParsesStatusAndDoctorJSON(t *testing.T) {
	lqPath := filepath.Join(t.TempDir(), "lq")
	if err := os.WriteFile(lqPath, []byte("placeholder"), 0o700); err != nil {
		t.Fatal(err)
	}
	statusJSON := `{"role":"relay","easytier_ip":"10.198.1.1","health_score":96,"overall":"OK","entries_total":1,"forwards_total":1,"entries":[{"name":"public1","listen_port":8301,"protocols":["tcp","udp"],"public_host":"home.example.com","status":"ok"}],"forwards":[{"name":"hk","entry_name":"public1","target_host":"10.0.0.8","target_port":443,"protocols":["tcp","udp"],"status":"ok"}]}`
	doctorJSON := `{"overall":"OK","warnings":["none"],"suggestions":["none"]}`
	c := Collector{
		LQPath: lqPath,
		PublicIPFunc: func(context.Context) (string, error) {
			return "203.0.113.10", nil
		},
		CommandFunc: func(_ context.Context, _ string, args ...string) (string, error) {
			if len(args) == 1 && args[0] == "--version" {
				return "leikwan-toolkit 1.4.0 LTS", nil
			}
			if len(args) == 2 && args[0] == "status" {
				return statusJSON, nil
			}
			if len(args) == 2 && args[0] == "doctor" {
				return doctorJSON, nil
			}
			return "", nil
		},
	}
	report := c.Collect(context.Background(), Config{NodeID: "node-a", Role: "unknown", IntervalSeconds: 15})
	if report.Role != "relay" || report.EasyTierIP != "10.198.1.1" || report.HealthScore != 96 {
		t.Fatalf("status fields not parsed: %+v", report)
	}
	if len(report.Entries) != 1 || report.Entries[0].Name != "public1" {
		t.Fatalf("entries not parsed: %+v", report.Entries)
	}
	if len(report.Forwards) != 1 || report.Forwards[0].Name != "hk" {
		t.Fatalf("forwards not parsed: %+v", report.Forwards)
	}
	if !report.Capabilities.LQAvailable || !report.Capabilities.SupportsStatusJSON || !report.Capabilities.SupportsDoctorJSON || !report.Capabilities.SupportsForwardList || !report.Capabilities.SupportsDDNSOverview {
		t.Fatalf("capabilities not detected: %+v", report.Capabilities)
	}
	if !report.Capabilities.SupportsSnapshotManualRecord || !report.Capabilities.SupportsRollbackManualRecord {
		t.Fatalf("manual snapshot/rollback record capabilities should be advertised: %+v", report.Capabilities)
	}
	if report.Capabilities.WriteActionsSupported || len(report.Capabilities.SupportedWriteActions) != 0 {
		t.Fatalf("write actions must remain unsupported unless enable_write_actions=true: %+v", report.Capabilities)
	}
	if report.Capabilities.ControllerMetadataActionsSupported {
		t.Fatalf("Controller metadata actions are Controller-only and must not be agent capabilities: %+v", report.Capabilities)
	}
	var doc map[string]any
	if err := json.Unmarshal(report.Doctor, &doc); err != nil || doc["overall"] != "OK" {
		t.Fatalf("doctor not parsed: %s err=%v", report.Doctor, err)
	}
}

func TestAlphaWriteActionsAreExplicitAndStageFilesOnly(t *testing.T) {
	cfg := Config{EnableWriteActions: true, TaskTimeoutSeconds: 5, TaskResultLimitKB: 64}
	supported := SupportedWriteActions(cfg)
	for _, want := range []string{"configure_node_role", "apply_network_profile", "apply_entry_config", "apply_forward_config", "reload_leikwan_core", "verify_applied_config"} {
		found := false
		for _, got := range supported {
			if got == want {
				found = true
			}
			for _, forbidden := range []string{"shell -c", "bash -c", "eval", "nft", "iptables", "rm"} {
				if strings.Contains(got, forbidden) {
					t.Fatalf("supported action leaked forbidden token %q: %s", forbidden, got)
				}
			}
		}
		if !found {
			t.Fatalf("missing supported write action %s in %+v", want, supported)
		}
	}
	if len(SupportedWriteActions(Config{})) != 0 {
		t.Fatalf("write actions must be hidden when disabled")
	}
	etcDir := t.TempDir()
	stateDir := t.TempDir()
	backupDir := t.TempDir()
	t.Setenv("LEIKWAN_AGENT_ETC_DIR", etcDir)
	t.Setenv("LEIKWAN_AGENT_STATE_DIR", stateDir)
	t.Setenv("LEIKWAN_AGENT_BACKUP_DIR", backupDir)
	payload := json.RawMessage(`{"network_name":"demo","network_secret":"secret-token","custom_cmd":"cmd --token abc"}`)
	disabled := ExecuteTask(context.Background(), Collector{}, Config{EnableWriteActions: false}, Task{Action: "apply_network_profile", PayloadJSON: payload})
	if disabled.Status != "rejected" {
		t.Fatalf("disabled write action should reject: %+v", disabled)
	}
	commandPayload := ExecuteTask(context.Background(), Collector{}, cfg, Task{Action: "apply_network_profile", PayloadJSON: json.RawMessage(`{"command":"rm -rf /"}`)})
	if commandPayload.Status != "rejected" || !strings.Contains(commandPayload.Error, "command") {
		t.Fatalf("command payload should reject: %+v", commandPayload)
	}
	result := ExecuteTask(context.Background(), Collector{}, cfg, Task{Action: "apply_network_profile", PayloadJSON: payload})
	if result.Status != "succeeded" || strings.Contains(result.ResultStdout, "secret-token") || strings.Contains(result.ResultStdout, "--token abc") {
		t.Fatalf("apply network should succeed and redact result: %+v", result)
	}
	written, err := os.ReadFile(filepath.Join(etcDir, "panel-network.json"))
	if err != nil {
		t.Fatalf("expected panel-network.json: %v", err)
	}
	if strings.Contains(string(written), "secret-token") || strings.Contains(string(written), "--token abc") {
		t.Fatalf("staged file leaked secret: %s", string(written))
	}
	forward := ExecuteTask(context.Background(), Collector{}, cfg, Task{Action: "apply_forward_config", PayloadJSON: json.RawMessage(`{"target_host":"10.0.0.8","target_port":443}`)})
	if forward.Status != "succeeded" {
		t.Fatalf("apply forward failed: %+v", forward)
	}
	if _, err := os.Stat(filepath.Join(etcDir, "panel-forward.json")); err != nil {
		t.Fatalf("expected panel-forward.json: %v", err)
	}
	verify := ExecuteTask(context.Background(), Collector{}, cfg, Task{Action: "verify_applied_config"})
	if verify.Status != "succeeded" || !strings.Contains(verify.ResultStdout, "panel-forward.json") {
		t.Fatalf("verify should find staged files: %+v", verify)
	}
	if _, err := safePath(etcDir, "../evil"); err == nil {
		t.Fatalf("safePath should reject traversal")
	}
}

func TestAlphaWriteCapabilitiesWhenEnabled(t *testing.T) {
	c := Collector{
		LQPath: filepath.Join(t.TempDir(), "missing-lq"),
		PublicIPFunc: func(context.Context) (string, error) {
			return "203.0.113.10", nil
		},
	}
	report := c.Collect(context.Background(), Config{NodeID: "node-a", NodeName: "A", Role: "relay", EnableWriteActions: true})
	if !report.Capabilities.WriteActionsSupported || len(report.Capabilities.SupportedWriteActions) == 0 {
		t.Fatalf("write-enabled agent should advertise alpha write actions: %+v", report.Capabilities)
	}
}

func TestPanel3RealActionsUseAllowedPathsAndFixedArgv(t *testing.T) {
	configDir := t.TempDir()
	systemdDir := t.TempDir()
	backupDir := t.TempDir()
	t.Setenv("LEIKWAN_AGENT_CONFIG_DIR", configDir)
	t.Setenv("LEIKWAN_AGENT_SYSTEMD_DIR", systemdDir)
	t.Setenv("LEIKWAN_AGENT_BACKUP_DIR", backupDir)
	cfg := Config{EnableWriteActions: true, TaskTimeoutSeconds: 5, TaskResultLimitKB: 4}
	commands := []string{}
	c := Collector{TaskCommandFunc: func(_ context.Context, name string, args ...string) (string, string, int, error) {
		commands = append(commands, name+" "+strings.Join(args, " "))
		return "ok", "", 0, nil
	}}
	easy := ExecuteTask(context.Background(), c, cfg, Task{Action: "configure_easytier_network", PayloadJSON: json.RawMessage(`{"network_name":"demo","network_secret":"super-secret","role":"relay"}`)})
	if easy.Status != "succeeded" {
		t.Fatalf("configure easytier failed: %+v", easy)
	}
	if _, err := os.Stat(filepath.Join(configDir, "easytier", "config.json")); err != nil {
		t.Fatalf("expected easytier config: %v", err)
	}
	if _, err := os.Stat(filepath.Join(systemdDir, "leikwan-easytier.service")); err != nil {
		t.Fatalf("expected easytier service: %v", err)
	}
	entry := ExecuteTask(context.Background(), c, cfg, Task{Action: "apply_entry_ports", PayloadJSON: json.RawMessage(`{"entry":{"listen_port_start":10000,"listen_port_end":10002,"protocols":"both","listen_host":"0.0.0.0"}}`)})
	if entry.Status != "succeeded" {
		t.Fatalf("apply entry ports failed: %+v", entry)
	}
	forward := ExecuteTask(context.Background(), c, cfg, Task{Action: "apply_forward_rules", PayloadJSON: json.RawMessage(`{"forward":{"listen_port":10001,"target_host":"10.0.0.8","target_port":443,"protocol":"tcp"}}`)})
	if forward.Status != "succeeded" {
		t.Fatalf("apply forward rules failed: %+v", forward)
	}
	if _, err := os.Stat(filepath.Join(configDir, "nftables", "leikwan-panel.nft")); err != nil {
		t.Fatalf("expected nft config: %v", err)
	}
	reload := ExecuteTask(context.Background(), c, cfg, Task{Action: "reload_firewall_rules"})
	if reload.Status != "succeeded" {
		t.Fatalf("reload firewall should use fixed argv: %+v commands=%v", reload, commands)
	}
	pbr := ExecuteTask(context.Background(), c, cfg, Task{Action: "apply_pbr_rules", PayloadJSON: json.RawMessage(`{"source_cidr":"10.0.0.0/24","target_cidr":"0.0.0.0/0","output_interface":"eth0","gateway":"192.0.2.1","table_id":100,"priority":1000}`)})
	if pbr.Status != "succeeded" {
		t.Fatalf("apply pbr failed: %+v", pbr)
	}
	ddns := ExecuteTask(context.Background(), c, cfg, Task{Action: "apply_ddns_config", PayloadJSON: json.RawMessage(`{"provider":"manual","domain":"home.example.com","api_token":"secret-token"}`)})
	if ddns.Status != "succeeded" || strings.Contains(ddns.ResultStdout, "secret-token") {
		t.Fatalf("apply ddns failed or leaked token: %+v", ddns)
	}
	restartAgent := ExecuteTask(context.Background(), c, cfg, Task{Action: "restart_agent"})
	if restartAgent.Status != "succeeded" {
		t.Fatalf("restart agent fixed action failed: %+v", restartAgent)
	}
	rebootRejected := ExecuteTask(context.Background(), c, cfg, Task{Action: "reboot_node", PayloadJSON: json.RawMessage(`{"confirm":"NO"}`)})
	if rebootRejected.Status != "failed" {
		t.Fatalf("reboot must require confirm: %+v", rebootRejected)
	}
	reboot := ExecuteTask(context.Background(), c, cfg, Task{Action: "reboot_node", PayloadJSON: json.RawMessage(`{"confirm":"REBOOT"}`)})
	if reboot.Status != "succeeded" {
		t.Fatalf("reboot fixed action failed: %+v", reboot)
	}
	joined := strings.Join(commands, "\n")
	for _, forbidden := range []string{"shell -c", "bash -c", "eval"} {
		if strings.Contains(joined, forbidden) {
			t.Fatalf("forbidden execution path appeared: %s", joined)
		}
	}
	for _, expected := range []string{"systemctl restart leikwan-agent", "nft -f", "ip rule add", "ip route replace", "reboot"} {
		if !strings.Contains(joined, expected) {
			t.Fatalf("expected fixed argv %q in commands: %s", expected, joined)
		}
	}
}

func TestReadonlyTaskActionMappingAndRejection(t *testing.T) {
	args, ok := TaskActionArgs("list_forwards")
	if !ok || strings.Join(args, " ") != "forward list" {
		t.Fatalf("unexpected list_forwards mapping: %v %v", args, ok)
	}
	for _, action := range AllowedTaskActions() {
		args, ok := TaskActionArgs(action)
		if !ok {
			t.Fatalf("allowed action missing argv mapping: %s", action)
		}
		joined := strings.Join(args, " ")
		for _, forbidden := range []string{"sh -c", "bash -c", "eval", "systemctl", "nft", "iptables", "snapshot", "rollback"} {
			if strings.Contains(joined, forbidden) {
				t.Fatalf("readonly action %s contains forbidden argv text %q: %v", action, forbidden, args)
			}
		}
	}
	for _, forbidden := range []string{"create_snapshot", "rollback", "restart_relay", "systemctl_restart"} {
		if _, ok := TaskActionArgs(forbidden); ok {
			t.Fatalf("forbidden action must not be allowed: %s", forbidden)
		}
	}
	lqPath := filepath.Join(t.TempDir(), "lq")
	if err := os.WriteFile(lqPath, []byte("placeholder"), 0o700); err != nil {
		t.Fatal(err)
	}
	var gotName string
	var gotArgs []string
	c := Collector{
		LQPath: lqPath,
		TaskCommandFunc: func(_ context.Context, name string, args ...string) (string, string, int, error) {
			gotName = name
			gotArgs = append([]string(nil), args...)
			return "ok token=abc", "privateKey=key", 0, nil
		},
	}
	result := ExecuteTask(context.Background(), c, Config{TaskTimeoutSeconds: 5}, Task{ID: 1, NodeID: "node-a", Action: "list_forwards"})
	if result.Status != "succeeded" || gotName != lqPath || strings.Join(gotArgs, " ") != "forward list" {
		t.Fatalf("unexpected task result=%+v name=%s args=%v", result, gotName, gotArgs)
	}
	if strings.Contains(result.ResultStdout, "token=abc") || strings.Contains(result.ResultStderr, "privateKey=key") {
		t.Fatalf("task output was not redacted: %+v", result)
	}
	rejected := ExecuteTask(context.Background(), c, Config{}, Task{Action: "rm"})
	if rejected.Status != "rejected" || rejected.ExitCode == 0 {
		t.Fatalf("invalid action should be rejected: %+v", rejected)
	}
}

func TestReadonlyTaskMissingLQAndTimeout(t *testing.T) {
	missing := Collector{LQPath: filepath.Join(t.TempDir(), "missing-lq")}
	result := ExecuteTask(context.Background(), missing, Config{}, Task{Action: "run_status"})
	if result.Status != "failed" || result.ExitCode != 127 || !strings.Contains(result.Error, "lq missing") {
		t.Fatalf("missing lq should fail clearly: %+v", result)
	}
	lqPath := filepath.Join(t.TempDir(), "lq")
	if err := os.WriteFile(lqPath, []byte("placeholder"), 0o700); err != nil {
		t.Fatal(err)
	}
	timeoutCollector := Collector{
		LQPath: lqPath,
		TaskCommandFunc: func(ctx context.Context, _ string, _ ...string) (string, string, int, error) {
			<-ctx.Done()
			return "", "", 1, ctx.Err()
		},
	}
	timedOut := ExecuteTask(context.Background(), timeoutCollector, Config{TaskTimeoutSeconds: 1}, Task{Action: "run_status"})
	if timedOut.Status != "failed" || !strings.Contains(timedOut.Error, "timeout") {
		t.Fatalf("timeout should fail cleanly: %+v", timedOut)
	}
}

func TestRunDoesNotPollTasksWhenDisabled(t *testing.T) {
	var taskPolls int
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/api/v1/agent/register", "/api/v1/agent/report":
			w.Header().Set("Content-Type", "application/json")
			_, _ = w.Write([]byte(`{"status":"ok"}`))
		case "/api/v1/agent/tasks":
			taskPolls++
			_, _ = w.Write([]byte(`[]`))
		default:
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
	}))
	defer server.Close()
	cfg := Config{ControllerURL: server.URL, Token: "test-token", NodeID: "node-a", NodeName: "node-a", Role: "relay", IntervalSeconds: 1, EnableTasks: false}
	if err := Run(context.Background(), cfg, true, false); err != nil {
		t.Fatalf("run failed: %v", err)
	}
	if taskPolls != 0 {
		t.Fatalf("expected no task polls when disabled, got %d", taskPolls)
	}
}

func TestTaskLockPreventsConcurrentExecution(t *testing.T) {
	taskExecutionLock.Lock()
	defer taskExecutionLock.Unlock()
	var polls int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/api/v1/agent/tasks":
			atomic.AddInt32(&polls, 1)
			_, _ = w.Write([]byte(`[]`))
		default:
			_, _ = w.Write([]byte(`{"status":"ok"}`))
		}
	}))
	defer server.Close()
	cfg := Config{ControllerURL: server.URL, Token: "test-token", NodeID: "node-a", EnableTasks: true}
	processTasks(context.Background(), cfg, NewClient(cfg), Collector{}, false)
	if atomic.LoadInt32(&polls) != 0 {
		t.Fatalf("task poll should be skipped while lock is held")
	}
}

func TestTaskResultLimitKB(t *testing.T) {
	lqPath := filepath.Join(t.TempDir(), "lq")
	if err := os.WriteFile(lqPath, []byte("placeholder"), 0o700); err != nil {
		t.Fatal(err)
	}
	c := Collector{
		LQPath: lqPath,
		TaskCommandFunc: func(_ context.Context, _ string, _ ...string) (string, string, int, error) {
			return strings.Repeat("x", 3*1024), "", 0, nil
		},
	}
	result := ExecuteTask(context.Background(), c, Config{TaskTimeoutSeconds: 5, TaskResultLimitKB: 1}, Task{Action: "run_status"})
	if !strings.Contains(result.ResultStdout, "[TRUNCATED]") || len(result.ResultStdout) > 1200 {
		t.Fatalf("expected 1KB truncation, got len=%d body=%q", len(result.ResultStdout), result.ResultStdout)
	}
}

func TestProcessTasksSerializesLongTask(t *testing.T) {
	lqPath := filepath.Join(t.TempDir(), "lq")
	if err := os.WriteFile(lqPath, []byte("placeholder"), 0o700); err != nil {
		t.Fatal(err)
	}
	var maxRunning int32
	var running int32
	c := Collector{
		LQPath: lqPath,
		TaskCommandFunc: func(_ context.Context, _ string, _ ...string) (string, string, int, error) {
			cur := atomic.AddInt32(&running, 1)
			if cur > atomic.LoadInt32(&maxRunning) {
				atomic.StoreInt32(&maxRunning, cur)
			}
			time.Sleep(30 * time.Millisecond)
			atomic.AddInt32(&running, -1)
			return "ok", "", 0, nil
		},
	}
	var resultCount int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/api/v1/agent/tasks":
			_ = json.NewEncoder(w).Encode([]Task{{ID: 1, NodeID: "node-a", Action: "run_status", Status: "queued"}})
		case "/api/v1/agent/tasks/1/result":
			atomic.AddInt32(&resultCount, 1)
			_, _ = w.Write([]byte(`{"status":"ok"}`))
		default:
			_, _ = w.Write([]byte(`{"status":"ok"}`))
		}
	}))
	defer server.Close()
	cfg := Config{ControllerURL: server.URL, Token: "test-token", NodeID: "node-a", EnableTasks: true, TaskTimeoutSeconds: 2}
	done := make(chan struct{})
	go func() {
		processTasks(context.Background(), cfg, NewClient(cfg), c, false)
		close(done)
	}()
	time.Sleep(5 * time.Millisecond)
	processTasks(context.Background(), cfg, NewClient(cfg), c, false)
	<-done
	if maxRunning != 1 || resultCount != 1 {
		t.Fatalf("expected serialized task execution, maxRunning=%d results=%d", maxRunning, resultCount)
	}
}

func TestClientTaskAPIsRedactBody(t *testing.T) {
	var resultBody bytes.Buffer
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer test-token" {
			t.Fatalf("missing auth header")
		}
		switch r.URL.Path {
		case "/api/v1/agent/tasks":
			_ = json.NewEncoder(w).Encode([]Task{{ID: 7, NodeID: "node-a", Action: "run_status", Status: "queued"}})
		case "/api/v1/agent/tasks/7/result":
			_, _ = resultBody.ReadFrom(r.Body)
			_, _ = w.Write([]byte(`{"status":"ok"}`))
		default:
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
	}))
	defer server.Close()
	client := NewClient(Config{ControllerURL: server.URL, Token: "test-token"})
	tasks, err := client.GetTasks(context.Background(), "node-a")
	if err != nil || len(tasks) != 1 || tasks[0].ID != 7 {
		t.Fatalf("get tasks failed: tasks=%+v err=%v", tasks, err)
	}
	if err := client.ReportTaskResult(context.Background(), 7, TaskResultRequest{Status: "failed", ResultStdout: "token=abc", ResultStderr: "privateKey=key"}); err != nil {
		t.Fatalf("report result failed: %v", err)
	}
	if strings.Contains(resultBody.String(), "token=abc") || strings.Contains(resultBody.String(), "privateKey=key") {
		t.Fatalf("client leaked task result body: %s", resultBody.String())
	}
}
