package controller

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

type Store struct {
	db *sql.DB
}

func OpenStore(path string) (*Store, error) {
	if dir := filepath.Dir(path); dir != "." && dir != "" {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return nil, err
		}
	}
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, err
	}
	s := &Store{db: db}
	if err := s.migrate(context.Background()); err != nil {
		db.Close()
		return nil, err
	}
	return s, nil
}

func (s *Store) Close() error {
	return s.db.Close()
}

func (s *Store) migrate(ctx context.Context) error {
	stmts := []string{
		`CREATE TABLE IF NOT EXISTS nodes (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			node_id TEXT NOT NULL UNIQUE,
			node_name TEXT,
			role TEXT,
			public_ip TEXT,
			lan_ip TEXT,
			easytier_ip TEXT,
			agent_version TEXT,
			core_version TEXT,
			status TEXT,
			health_score INTEGER DEFAULT 0,
			interval_seconds INTEGER DEFAULT 0,
			last_seen TEXT,
			services_json TEXT,
			capabilities_json TEXT,
			summary_json TEXT,
			doctor_json TEXT,
			recent_errors_json TEXT,
			raw_json TEXT
		)`,
		`CREATE TABLE IF NOT EXISTS node_reports (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			node_id TEXT NOT NULL,
			status TEXT,
			health_score INTEGER DEFAULT 0,
			interval_seconds INTEGER DEFAULT 0,
			services_json TEXT,
			capabilities_json TEXT,
			summary_json TEXT,
			doctor_json TEXT,
			recent_errors_json TEXT,
			raw_json TEXT,
			created_at TEXT
		)`,
		`CREATE TABLE IF NOT EXISTS entries (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			node_id TEXT NOT NULL,
			name TEXT,
			listen_port INTEGER,
			protocol TEXT,
			public_host TEXT,
			status TEXT,
			raw_json TEXT
		)`,
		`CREATE TABLE IF NOT EXISTS forwards (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			node_id TEXT NOT NULL,
			name TEXT,
			entry_name TEXT,
			target_host TEXT,
			target_port INTEGER,
			protocol TEXT,
			status TEXT,
			raw_json TEXT
		)`,
		`CREATE TABLE IF NOT EXISTS events (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			node_id TEXT,
			level TEXT,
			message TEXT,
			created_at TEXT
		)`,
		`CREATE TABLE IF NOT EXISTS plans (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			type TEXT NOT NULL,
			title TEXT,
			status TEXT,
			execution_status TEXT,
			execution_note TEXT,
			manual_result TEXT,
			dry_run_status TEXT,
			dry_run_task_ids TEXT,
			dry_run_report TEXT,
			last_dry_run_at TEXT,
			snapshot_policy TEXT,
			snapshot_required INTEGER DEFAULT 0,
			snapshot_status TEXT,
			snapshot_ref TEXT,
			snapshot_note TEXT,
			rollback_available INTEGER DEFAULT 0,
			rollback_ref TEXT,
			rollback_note TEXT,
			rollback_instructions TEXT,
			verification_status TEXT,
			verification_report TEXT,
			verification_note TEXT,
			executed_by TEXT,
			executed_at TEXT,
			verified_by TEXT,
			verified_at TEXT,
			timeline_json TEXT,
			safety_level TEXT,
			command_classification TEXT,
			target_node_id TEXT,
			payload_json TEXT,
			generated_commands TEXT,
			command_groups TEXT,
			checklist TEXT,
			preflight TEXT,
			capability_requirements TEXT,
			markdown TEXT,
			warnings TEXT,
			created_at TEXT,
			updated_at TEXT
		)`,
		`CREATE TABLE IF NOT EXISTS plan_evidence (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			plan_id INTEGER NOT NULL,
			evidence_type TEXT,
			title TEXT,
			content TEXT,
			created_by TEXT,
			created_at TEXT,
			redacted_content TEXT
		)`,
		`CREATE TABLE IF NOT EXISTS network_profiles (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL,
			network_name TEXT NOT NULL,
			network_secret TEXT,
			relay_node_id TEXT,
			created_at TEXT,
			updated_at TEXT
		)`,
		`CREATE TABLE IF NOT EXISTS panel_entries (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			network_id INTEGER NOT NULL,
			entry_node_id TEXT,
			relay_node_id TEXT,
			listen_host TEXT,
			listen_port_start INTEGER DEFAULT 0,
			listen_port_end INTEGER DEFAULT 0,
			protocols TEXT,
			status TEXT,
			created_at TEXT,
			updated_at TEXT
		)`,
		`CREATE TABLE IF NOT EXISTS panel_forwards (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			network_id INTEGER NOT NULL,
			entry_id INTEGER NOT NULL,
			relay_node_id TEXT,
			name TEXT,
			listen_port INTEGER DEFAULT 0,
			target_host TEXT,
			target_port INTEGER DEFAULT 0,
			protocol TEXT,
			pbr_policy_id INTEGER DEFAULT 0,
			status TEXT,
			created_at TEXT,
			updated_at TEXT
		)`,
		`CREATE TABLE IF NOT EXISTS pbr_policies (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT,
			relay_node_id TEXT,
			source_cidr TEXT,
			target_cidr TEXT,
			output_interface TEXT,
			gateway TEXT,
			table_id INTEGER DEFAULT 0,
			priority INTEGER DEFAULT 0,
			mark TEXT,
			status TEXT,
			created_at TEXT,
			updated_at TEXT
		)`,
		`CREATE TABLE IF NOT EXISTS ddns_profiles (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			node_id TEXT,
			provider TEXT,
			domain TEXT,
			record_type TEXT,
			api_token TEXT,
			zone_id TEXT,
			record_id TEXT,
			target TEXT,
			interval_seconds INTEGER DEFAULT 0,
			status TEXT,
			last_sync_at TEXT,
			last_error TEXT,
			created_at TEXT,
			updated_at TEXT
		)`,
		`CREATE TABLE IF NOT EXISTS tasks (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			node_id TEXT NOT NULL,
			action TEXT NOT NULL,
			status TEXT NOT NULL,
			approval_status TEXT,
			approved_by TEXT,
			approved_at TEXT,
			requested_by TEXT,
			ttl_seconds INTEGER DEFAULT 300,
			expires_at TEXT,
			retry_of_task_id INTEGER DEFAULT 0,
			attempt INTEGER DEFAULT 1,
			max_attempts INTEGER DEFAULT 3,
			task_group_id TEXT,
			payload_json TEXT,
			timeline_json TEXT,
			result_stdout TEXT,
			result_stderr TEXT,
			exit_code INTEGER DEFAULT 0,
			error TEXT,
			created_at TEXT,
			picked_at TEXT,
			finished_at TEXT
		)`,
	}
	for _, stmt := range stmts {
		if _, err := s.db.ExecContext(ctx, stmt); err != nil {
			return err
		}
	}
	columns := map[string]string{
		"interval_seconds":   "INTEGER DEFAULT 0",
		"services_json":      "TEXT",
		"capabilities_json":  "TEXT",
		"summary_json":       "TEXT",
		"doctor_json":        "TEXT",
		"recent_errors_json": "TEXT",
	}
	for name, typ := range columns {
		if err := s.addColumnIfMissing(ctx, "nodes", name, typ); err != nil {
			return err
		}
	}
	planColumns := map[string]string{
		"execution_status":        "TEXT",
		"execution_note":          "TEXT",
		"manual_result":           "TEXT",
		"dry_run_status":          "TEXT",
		"dry_run_task_ids":        "TEXT",
		"dry_run_report":          "TEXT",
		"last_dry_run_at":         "TEXT",
		"snapshot_policy":         "TEXT",
		"snapshot_required":       "INTEGER DEFAULT 0",
		"snapshot_status":         "TEXT",
		"snapshot_ref":            "TEXT",
		"snapshot_note":           "TEXT",
		"rollback_available":      "INTEGER DEFAULT 0",
		"rollback_ref":            "TEXT",
		"rollback_note":           "TEXT",
		"rollback_instructions":   "TEXT",
		"verification_status":     "TEXT",
		"verification_report":     "TEXT",
		"verification_note":       "TEXT",
		"executed_by":             "TEXT",
		"executed_at":             "TEXT",
		"verified_by":             "TEXT",
		"verified_at":             "TEXT",
		"timeline_json":           "TEXT",
		"safety_level":            "TEXT",
		"command_classification":  "TEXT",
		"command_groups":          "TEXT",
		"checklist":               "TEXT",
		"preflight":               "TEXT",
		"capability_requirements": "TEXT",
		"markdown":                "TEXT",
	}
	for name, typ := range planColumns {
		if err := s.addColumnIfMissing(ctx, "plans", name, typ); err != nil {
			return err
		}
	}
	for name, typ := range map[string]string{"capabilities_json": "TEXT"} {
		if err := s.addColumnIfMissing(ctx, "node_reports", name, typ); err != nil {
			return err
		}
	}
	taskColumns := map[string]string{
		"approval_status":  "TEXT",
		"approved_by":      "TEXT",
		"approved_at":      "TEXT",
		"requested_by":     "TEXT",
		"ttl_seconds":      "INTEGER DEFAULT 300",
		"expires_at":       "TEXT",
		"retry_of_task_id": "INTEGER DEFAULT 0",
		"attempt":          "INTEGER DEFAULT 1",
		"max_attempts":     "INTEGER DEFAULT 3",
		"task_group_id":    "TEXT",
		"payload_json":     "TEXT",
		"timeline_json":    "TEXT",
	}
	for name, typ := range taskColumns {
		if err := s.addColumnIfMissing(ctx, "tasks", name, typ); err != nil {
			return err
		}
	}
	if err := s.addColumnIfMissing(ctx, "panel_forwards", "pbr_policy_id", "INTEGER DEFAULT 0"); err != nil {
		return err
	}
	return nil
}

func (s *Store) addColumnIfMissing(ctx context.Context, table, column, typ string) error {
	rows, err := s.db.QueryContext(ctx, "PRAGMA table_info("+table+")")
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var cid int
		var name, colType string
		var notNull int
		var defaultValue any
		var pk int
		if err := rows.Scan(&cid, &name, &colType, &notNull, &defaultValue, &pk); err != nil {
			return err
		}
		if name == column {
			return nil
		}
	}
	if err := rows.Err(); err != nil {
		return err
	}
	_, err = s.db.ExecContext(ctx, fmt.Sprintf("ALTER TABLE %s ADD COLUMN %s %s", table, column, typ))
	return err
}

func nowString() string {
	return time.Now().UTC().Format(time.RFC3339)
}

func normalizeRole(role string) string {
	switch role {
	case "entry", "relay", "backend", "mixed", "unknown":
		return role
	default:
		return "unknown"
	}
}

func normalizeStatus(status string) string {
	switch status {
	case "online", "offline", "degraded", "ok":
		if status == "ok" {
			return "online"
		}
		return status
	default:
		return "degraded"
	}
}

func normalizePlanType(planType string) (string, error) {
	switch planType {
	case "create_entry", "create_forward", "switch_entry", "ddns_check":
		return planType, nil
	default:
		return "", fmt.Errorf("unsupported plan type: %s", planType)
	}
}

func normalizePlanStatus(status string) string {
	switch status {
	case "draft", "generated", "copied", "archived":
		return status
	default:
		return "draft"
	}
}

func normalizeExecutionStatus(status string) string {
	switch status {
	case "not_run", "running_manually", "succeeded", "failed", "rolled_back":
		return status
	default:
		return "not_run"
	}
}

func normalizeDryRunStatus(status string) string {
	switch status {
	case "not_run", "running", "passed", "warning", "failed":
		return status
	default:
		return "not_run"
	}
}

func normalizeSnapshotPolicy(policy string) string {
	switch policy {
	case "not_required", "recommended", "required":
		return policy
	default:
		return "recommended"
	}
}

func defaultSnapshotPolicy(planType string) string {
	switch planType {
	case "ddns_check":
		return "recommended"
	case "create_entry", "create_forward", "switch_entry":
		return "required"
	default:
		return "recommended"
	}
}

func normalizeSnapshotStatus(status string) string {
	switch status {
	case "not_required", "missing", "recorded", "verified":
		return status
	default:
		return "missing"
	}
}

func normalizeVerificationStatus(status string) string {
	switch status {
	case "not_run", "passed", "warning", "failed":
		return status
	default:
		return "not_run"
	}
}

func normalizeSafetyLevel(level string) string {
	switch level {
	case "safe", "caution", "dangerous":
		return level
	default:
		return "safe"
	}
}

func normalizeCommandClassification(class string) string {
	switch class {
	case "readonly", "manual", "blocked":
		return class
	default:
		return "manual"
	}
}

func allowedTaskAction(action string) bool {
	if allowedAlphaWriteAction(action) {
		return true
	}
	switch action {
	case "probe_core_version", "run_status", "run_status_json", "run_doctor", "run_doctor_json", "list_forwards", "ddns_overview",
		"node_status", "easytier_status", "nftables_status", "pbr_status", "ddns_status", "list_entries", "verify_config":
		return true
	default:
		return false
	}
}

func allowedTaskActions() []string {
	return []string{"probe_core_version", "run_status", "run_status_json", "run_doctor", "run_doctor_json", "list_forwards", "ddns_overview", "node_status", "easytier_status", "nftables_status", "pbr_status", "ddns_status", "list_entries", "verify_config"}
}

func allowedAlphaWriteAction(action string) bool {
	switch action {
	case "configure_node_role", "apply_network_profile", "apply_entry_config", "apply_forward_config", "reload_leikwan_core", "verify_applied_config",
		"install_easytier", "configure_easytier_network", "start_easytier", "restart_easytier", "stop_easytier",
		"apply_entry_ports", "apply_forward_rules", "apply_pbr_rules", "apply_ddns_config", "ddns_sync_now",
		"reload_firewall_rules", "restart_agent", "reboot_node":
		return true
	default:
		return false
	}
}

func alphaWriteActions() []string {
	return []string{"configure_node_role", "apply_network_profile", "apply_entry_config", "apply_forward_config", "reload_leikwan_core", "verify_applied_config", "install_easytier", "configure_easytier_network", "start_easytier", "restart_easytier", "stop_easytier", "apply_entry_ports", "apply_forward_rules", "apply_pbr_rules", "apply_ddns_config", "ddns_sync_now", "reload_firewall_rules", "restart_agent", "reboot_node"}
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
		for key, value := range x {
			if strings.EqualFold(key, "command") || strings.EqualFold(key, "cmd") || strings.EqualFold(key, "shell") {
				return true
			}
			if containsCommandKey(value) {
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

func normalizeTaskStatus(status string) string {
	switch status {
	case "queued", "picked", "succeeded", "failed", "expired", "rejected", "canceled":
		return status
	default:
		return "failed"
	}
}

func normalizeApprovalStatus(status string) string {
	switch status {
	case "not_required", "pending", "approved", "rejected":
		return status
	default:
		return "not_required"
	}
}

func normalizeTTLSeconds(ttl int) int {
	if ttl <= 0 {
		return 300
	}
	if ttl > 86400 {
		return 86400
	}
	return ttl
}

func normalizeAttempts(maxAttempts int) int {
	if maxAttempts <= 0 {
		return 3
	}
	if maxAttempts > 10 {
		return 10
	}
	return maxAttempts
}

func truncateTaskResult(s string) string {
	s = RedactString(s)
	const maxBytes = 64 * 1024
	if len(s) <= maxBytes {
		return s
	}
	return s[:maxBytes] + "\n[TRUNCATED]"
}

func newTaskTimeline(action, level, message string) string {
	items := []TaskTimelineItem{{
		Time:    nowString(),
		Action:  RedactString(action),
		Level:   RedactString(level),
		Message: RedactString(message),
	}}
	raw, _ := json.Marshal(items)
	return string(RedactJSONBytes(raw))
}

func appendTaskTimeline(timeline string, action, level, message string) string {
	items := []TaskTimelineItem{}
	if strings.TrimSpace(timeline) != "" {
		_ = json.Unmarshal([]byte(timeline), &items)
	}
	items = append(items, TaskTimelineItem{
		Time:    nowString(),
		Action:  RedactString(action),
		Level:   RedactString(level),
		Message: RedactString(message),
	})
	raw, _ := json.Marshal(items)
	return string(RedactJSONBytes(raw))
}

func (s *Store) appendTaskTimeline(ctx context.Context, id int64, action, level, message string) error {
	var timeline string
	if err := s.db.QueryRowContext(ctx, `SELECT COALESCE(timeline_json, '[]') FROM tasks WHERE id=?`, id).Scan(&timeline); err != nil {
		return err
	}
	_, err := s.db.ExecContext(ctx, `UPDATE tasks SET timeline_json=? WHERE id=?`, appendTaskTimeline(timeline, action, level, message), id)
	return err
}

func jsonText(v any) string {
	raw, err := json.Marshal(v)
	if err != nil {
		return "null"
	}
	return string(RedactJSONBytes(raw))
}

func rawJSONText(raw json.RawMessage) string {
	if len(raw) == 0 {
		return "null"
	}
	return string(RedactJSONBytes(raw))
}

func reportErrors(req ReportRequest) []string {
	out := make([]string, 0, len(req.RecentErrors)+len(req.Errors))
	out = append(out, req.RecentErrors...)
	out = append(out, req.Errors...)
	for i := range out {
		out[i] = RedactString(out[i])
	}
	return out
}

func scanJSONMap(text string) map[string]string {
	out := map[string]string{}
	if text == "" || text == "null" {
		return out
	}
	_ = json.Unmarshal([]byte(text), &out)
	return out
}

func scanCapabilities(text string) AgentCapabilities {
	var caps AgentCapabilities
	if text == "" || text == "null" {
		return caps
	}
	_ = json.Unmarshal([]byte(text), &caps)
	caps.CoreVersion = RedactString(caps.CoreVersion)
	return caps
}

func scanStringSlice(text string) []string {
	out := []string{}
	if text == "" || text == "null" {
		return out
	}
	_ = json.Unmarshal([]byte(text), &out)
	return out
}

func scanInt64Slice(text string) []int64 {
	out := []int64{}
	if text == "" || text == "null" {
		return out
	}
	_ = json.Unmarshal([]byte(text), &out)
	return out
}

func rawPlanPayload(raw json.RawMessage) string {
	if len(raw) == 0 {
		return "{}"
	}
	var v any
	if err := json.Unmarshal(raw, &v); err != nil {
		return string(RedactJSONBytes(raw))
	}
	out, err := json.Marshal(StripSensitiveValue(v))
	if err != nil {
		return string(RedactJSONBytes(raw))
	}
	return string(out)
}

func redactManualText(text string) string {
	trimmed := strings.TrimSpace(text)
	if trimmed == "" {
		return ""
	}
	var v any
	if err := json.Unmarshal([]byte(trimmed), &v); err == nil {
		raw, err := json.Marshal(StripSensitiveValue(v))
		if err == nil {
			return string(RedactJSONBytes(raw))
		}
	}
	return RedactString(text)
}

func (s *Store) Register(ctx context.Context, req RegisterRequest, raw []byte) error {
	if req.NodeID == "" {
		return fmt.Errorf("node_id is required")
	}
	name := req.NodeName
	if name == "" {
		name = req.Hostname
	}
	if name == "" {
		name = req.NodeID
	}
	now := nowString()
	redacted := string(RedactJSONBytes(raw))
	_, err := s.db.ExecContext(ctx, `INSERT INTO nodes
		(node_id, node_name, role, status, last_seen, raw_json)
		VALUES (?, ?, ?, ?, ?, ?)
		ON CONFLICT(node_id) DO UPDATE SET
			node_name=excluded.node_name,
			role=excluded.role,
			last_seen=excluded.last_seen,
			raw_json=excluded.raw_json`,
		req.NodeID, name, normalizeRole(req.Role), "unknown", now, redacted)
	if err != nil {
		return err
	}
	return s.AddEvent(ctx, req.NodeID, "info", "node registered")
}

func (s *Store) Report(ctx context.Context, req ReportRequest, raw []byte) error {
	if req.NodeID == "" {
		return fmt.Errorf("node_id is required")
	}
	name := req.NodeName
	if name == "" {
		name = req.Hostname
	}
	if name == "" {
		name = req.NodeID
	}
	status := normalizeStatus(req.Status)
	now := nowString()
	redacted := string(RedactJSONBytes(raw))
	interval := req.IntervalSeconds
	if interval <= 0 {
		interval = 60
	}
	servicesJSON := jsonText(req.Services)
	capabilitiesJSON := jsonText(req.Capabilities)
	summaryJSON := rawJSONText(req.Summary)
	doctorJSON := rawJSONText(req.Doctor)
	recentErrorsJSON := jsonText(reportErrors(req))
	oldStatus := "unknown"
	var oldLastSeen string
	var oldInterval int
	_ = s.db.QueryRowContext(ctx, `SELECT COALESCE(status, 'unknown'), COALESCE(last_seen, ''), COALESCE(interval_seconds, 0) FROM nodes WHERE node_id=?`, req.NodeID).Scan(&oldStatus, &oldLastSeen, &oldInterval)
	oldStatus = computedStatus(oldStatus, oldLastSeen, oldInterval)
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	_, err = tx.ExecContext(ctx, `INSERT INTO nodes
		(node_id, node_name, role, public_ip, lan_ip, easytier_ip, agent_version, core_version, status, health_score, interval_seconds, last_seen, services_json, capabilities_json, summary_json, doctor_json, recent_errors_json, raw_json)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(node_id) DO UPDATE SET
			node_name=excluded.node_name,
			role=excluded.role,
			public_ip=excluded.public_ip,
			lan_ip=excluded.lan_ip,
			easytier_ip=excluded.easytier_ip,
			agent_version=excluded.agent_version,
			core_version=excluded.core_version,
			status=excluded.status,
			health_score=excluded.health_score,
			interval_seconds=excluded.interval_seconds,
			last_seen=excluded.last_seen,
			services_json=excluded.services_json,
			capabilities_json=excluded.capabilities_json,
			summary_json=excluded.summary_json,
			doctor_json=excluded.doctor_json,
			recent_errors_json=excluded.recent_errors_json,
			raw_json=excluded.raw_json`,
		req.NodeID, name, normalizeRole(req.Role), req.PublicIP, req.PrimaryLANIP, req.EasyTierIP,
		req.AgentVersion, req.CoreVersion, status, req.HealthScore, interval, now, servicesJSON, capabilitiesJSON, summaryJSON, doctorJSON, recentErrorsJSON, redacted)
	if err != nil {
		return err
	}
	if _, err = tx.ExecContext(ctx, `INSERT INTO node_reports
		(node_id, status, health_score, interval_seconds, services_json, capabilities_json, summary_json, doctor_json, recent_errors_json, raw_json, created_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		req.NodeID, status, req.HealthScore, interval, servicesJSON, capabilitiesJSON, summaryJSON, doctorJSON, recentErrorsJSON, redacted, now); err != nil {
		return err
	}
	if _, err = tx.ExecContext(ctx, `DELETE FROM entries WHERE node_id=?`, req.NodeID); err != nil {
		return err
	}
	for _, e := range req.Entries {
		rawEntry, _ := json.Marshal(e)
		if len(e.RawJSON) > 0 {
			rawEntry = e.RawJSON
		}
		_, err = tx.ExecContext(ctx, `INSERT INTO entries (node_id, name, listen_port, protocol, public_host, status, raw_json)
			VALUES (?, ?, ?, ?, ?, ?, ?)`, req.NodeID, e.Name, e.ListenPort, e.Protocol, e.PublicHost, e.Status, string(RedactJSONBytes(rawEntry)))
		if err != nil {
			return err
		}
	}
	if _, err = tx.ExecContext(ctx, `DELETE FROM forwards WHERE node_id=?`, req.NodeID); err != nil {
		return err
	}
	for _, f := range req.Forwards {
		rawForward, _ := json.Marshal(f)
		if len(f.RawJSON) > 0 {
			rawForward = f.RawJSON
		}
		_, err = tx.ExecContext(ctx, `INSERT INTO forwards (node_id, name, entry_name, target_host, target_port, protocol, status, raw_json)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?)`, req.NodeID, f.Name, f.EntryName, f.TargetHost, f.TargetPort, f.Protocol, f.Status, string(RedactJSONBytes(rawForward)))
		if err != nil {
			return err
		}
	}
	if err = tx.Commit(); err != nil {
		return err
	}
	if oldStatus != status {
		_ = s.AddEvent(ctx, req.NodeID, "info", fmt.Sprintf("node status changed: %s -> %s", oldStatus, status))
	}
	level := "info"
	if status == "degraded" || len(req.Errors) > 0 || len(req.RecentErrors) > 0 {
		level = "warn"
	}
	msg := "node report received"
	if len(req.Errors) > 0 || len(req.RecentErrors) > 0 {
		msg = "node report has collector warnings"
	}
	return s.AddEvent(ctx, req.NodeID, level, msg)
}

func (s *Store) AddEvent(ctx context.Context, nodeID, level, message string) error {
	_, err := s.db.ExecContext(ctx, `INSERT INTO events (node_id, level, message, created_at) VALUES (?, ?, ?, ?)`,
		nodeID, level, RedactString(message), nowString())
	return err
}

func computedStatus(status, lastSeen string, intervalSeconds int) string {
	if status == "" {
		status = "unknown"
	}
	if status == "unknown" {
		return status
	}
	threshold := 120 * time.Second
	if intervalSeconds > 0 {
		threshold = time.Duration(intervalSeconds*3) * time.Second
	}
	seen, err := time.Parse(time.RFC3339, lastSeen)
	if err != nil {
		return status
	}
	if time.Since(seen) > threshold {
		return "offline"
	}
	return status
}

func (s *Store) updateOfflineNodes(ctx context.Context) {
	nodes, err := s.listNodesRaw(ctx)
	if err != nil {
		return
	}
	for _, n := range nodes {
		effective := computedStatus(n.Status, n.LastSeen, n.IntervalSeconds)
		if effective == "offline" && n.Status != "offline" {
			if _, err := s.db.ExecContext(ctx, `UPDATE nodes SET status='offline' WHERE node_id=?`, n.NodeID); err == nil {
				_ = s.AddEvent(ctx, n.NodeID, "warn", fmt.Sprintf("node status changed: %s -> offline", n.Status))
			}
		}
	}
}

func (s *Store) ListNodes(ctx context.Context) ([]Node, error) {
	s.updateOfflineNodes(ctx)
	return s.listNodesRaw(ctx)
}

func (s *Store) listNodesRaw(ctx context.Context) ([]Node, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT id, node_id, node_name, role, public_ip, lan_ip, easytier_ip, agent_version, core_version, COALESCE(status, 'unknown'), COALESCE(health_score, 0), COALESCE(interval_seconds, 0), COALESCE(last_seen, ''), COALESCE(services_json, '{}'), COALESCE(capabilities_json, '{}'), COALESCE(summary_json, 'null'), COALESCE(doctor_json, 'null'), COALESCE(recent_errors_json, '[]'), COALESCE(raw_json, '{}') FROM nodes ORDER BY last_seen DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Node{}
	for rows.Next() {
		var n Node
		var servicesJSON, capabilitiesJSON, summaryJSON, doctorJSON, errorsJSON string
		if err := rows.Scan(&n.ID, &n.NodeID, &n.NodeName, &n.Role, &n.PublicIP, &n.LANIP, &n.EasyTierIP, &n.AgentVersion, &n.CoreVersion, &n.Status, &n.HealthScore, &n.IntervalSeconds, &n.LastSeen, &servicesJSON, &capabilitiesJSON, &summaryJSON, &doctorJSON, &errorsJSON, &n.RawJSON); err != nil {
			return nil, err
		}
		n.Status = computedStatus(n.Status, n.LastSeen, n.IntervalSeconds)
		n.Services = scanJSONMap(servicesJSON)
		n.Capabilities = scanCapabilities(capabilitiesJSON)
		n.Summary = json.RawMessage(summaryJSON)
		n.Doctor = json.RawMessage(doctorJSON)
		n.RecentErrors = scanStringSlice(errorsJSON)
		out = append(out, n)
	}
	return out, rows.Err()
}

func (s *Store) GetNode(ctx context.Context, id string) (Node, bool, error) {
	s.updateOfflineNodes(ctx)
	var n Node
	var servicesJSON, capabilitiesJSON, summaryJSON, doctorJSON, errorsJSON string
	err := s.db.QueryRowContext(ctx, `SELECT id, node_id, node_name, role, public_ip, lan_ip, easytier_ip, agent_version, core_version, COALESCE(status, 'unknown'), COALESCE(health_score, 0), COALESCE(interval_seconds, 0), COALESCE(last_seen, ''), COALESCE(services_json, '{}'), COALESCE(capabilities_json, '{}'), COALESCE(summary_json, 'null'), COALESCE(doctor_json, 'null'), COALESCE(recent_errors_json, '[]'), COALESCE(raw_json, '{}')
		FROM nodes WHERE node_id=? OR CAST(id AS TEXT)=?`, id, id).Scan(&n.ID, &n.NodeID, &n.NodeName, &n.Role, &n.PublicIP, &n.LANIP, &n.EasyTierIP, &n.AgentVersion, &n.CoreVersion, &n.Status, &n.HealthScore, &n.IntervalSeconds, &n.LastSeen, &servicesJSON, &capabilitiesJSON, &summaryJSON, &doctorJSON, &errorsJSON, &n.RawJSON)
	if err == sql.ErrNoRows {
		return Node{}, false, nil
	}
	if err != nil {
		return Node{}, false, err
	}
	n.Status = computedStatus(n.Status, n.LastSeen, n.IntervalSeconds)
	n.Services = scanJSONMap(servicesJSON)
	n.Capabilities = scanCapabilities(capabilitiesJSON)
	n.Summary = json.RawMessage(summaryJSON)
	n.Doctor = json.RawMessage(doctorJSON)
	n.RecentErrors = scanStringSlice(errorsJSON)
	return n, true, nil
}

func (s *Store) ListEntries(ctx context.Context) ([]Entry, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT id, node_id, name, listen_port, protocol, public_host, status, raw_json FROM entries ORDER BY node_id, name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Entry{}
	for rows.Next() {
		var e Entry
		if err := rows.Scan(&e.ID, &e.NodeID, &e.Name, &e.ListenPort, &e.Protocol, &e.PublicHost, &e.Status, &e.RawJSON); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

func (s *Store) ListForwards(ctx context.Context) ([]Forward, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT id, node_id, name, entry_name, target_host, target_port, protocol, status, raw_json FROM forwards ORDER BY node_id, name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Forward{}
	for rows.Next() {
		var f Forward
		if err := rows.Scan(&f.ID, &f.NodeID, &f.Name, &f.EntryName, &f.TargetHost, &f.TargetPort, &f.Protocol, &f.Status, &f.RawJSON); err != nil {
			return nil, err
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

func randomHex(n int) string {
	if n <= 0 {
		n = 16
	}
	buf := make([]byte, n)
	if _, err := rand.Read(buf); err != nil {
		return fmt.Sprintf("%d", time.Now().UnixNano())
	}
	return hex.EncodeToString(buf)
}

func normalizePanelStatus(status string) string {
	switch strings.TrimSpace(status) {
	case "draft", "ready", "applied", "failed":
		return strings.TrimSpace(status)
	default:
		return "draft"
	}
}

func normalizePanelProtocol(protocol string) string {
	switch strings.ToLower(strings.TrimSpace(protocol)) {
	case "tcp", "udp", "both", "tcp+udp":
		if strings.ToLower(strings.TrimSpace(protocol)) == "tcp+udp" {
			return "both"
		}
		return strings.ToLower(strings.TrimSpace(protocol))
	default:
		return "both"
	}
}

func normalizeDDNSProvider(provider string) string {
	switch strings.ToLower(strings.TrimSpace(provider)) {
	case "cloudflare", "generic_webhook", "manual":
		return strings.ToLower(strings.TrimSpace(provider))
	default:
		return "manual"
	}
}

func normalizeRecordType(recordType string) string {
	switch strings.ToUpper(strings.TrimSpace(recordType)) {
	case "A", "AAAA":
		return strings.ToUpper(strings.TrimSpace(recordType))
	default:
		return "A"
	}
}

func normalizeInterval(interval int) int {
	if interval <= 0 {
		return 300
	}
	if interval < 60 {
		return 60
	}
	if interval > 86400 {
		return 86400
	}
	return interval
}

var interfaceNameStoreRe = regexp.MustCompile(`^[A-Za-z0-9_.:-]{1,64}$`)

func validatePBRRequest(req PBRPolicyRequest) error {
	if strings.TrimSpace(req.Name) == "" || strings.TrimSpace(req.RelayNodeID) == "" {
		return fmt.Errorf("name and relay_node_id are required")
	}
	if req.SourceCIDR != "" {
		if _, _, err := net.ParseCIDR(req.SourceCIDR); err != nil {
			return fmt.Errorf("invalid source_cidr")
		}
	}
	if req.TargetCIDR != "" {
		if _, _, err := net.ParseCIDR(req.TargetCIDR); err != nil {
			return fmt.Errorf("invalid target_cidr")
		}
	}
	if req.OutputInterface != "" && !interfaceNameStoreRe.MatchString(req.OutputInterface) {
		return fmt.Errorf("invalid output_interface")
	}
	if req.Gateway != "" && net.ParseIP(req.Gateway) == nil {
		return fmt.Errorf("invalid gateway")
	}
	if req.TableID <= 0 || req.TableID > 999999 || req.Priority <= 0 || req.Priority > 999999 {
		return fmt.Errorf("invalid table_id or priority")
	}
	return nil
}

func validateDDNSRequest(req DDNSProfileRequest) error {
	if strings.TrimSpace(req.NodeID) == "" || strings.TrimSpace(req.Domain) == "" {
		return fmt.Errorf("node_id and domain are required")
	}
	provider := normalizeDDNSProvider(req.Provider)
	if provider == "cloudflare" && (strings.TrimSpace(req.ZoneID) == "" || strings.TrimSpace(req.RecordID) == "") {
		return fmt.Errorf("cloudflare zone_id and record_id are required")
	}
	if provider == "generic_webhook" && strings.TrimSpace(req.Target) == "" {
		return fmt.Errorf("generic_webhook target is required")
	}
	return nil
}

func redactNetworkProfile(profile NetworkProfile) NetworkProfile {
	profile.Name = RedactString(profile.Name)
	profile.NetworkName = RedactString(profile.NetworkName)
	if strings.TrimSpace(profile.NetworkSecret) != "" {
		profile.NetworkSecret = "REDACTED"
	}
	profile.RelayNodeID = RedactString(profile.RelayNodeID)
	return profile
}

func (s *Store) CreateNetworkProfile(ctx context.Context, req NetworkProfileRequest) (NetworkProfile, error) {
	name := strings.TrimSpace(RedactString(req.Name))
	if name == "" {
		return NetworkProfile{}, fmt.Errorf("name is required")
	}
	relayNodeID := strings.TrimSpace(RedactString(req.RelayNodeID))
	if relayNodeID == "" {
		return NetworkProfile{}, fmt.Errorf("relay_node_id is required")
	}
	networkName := strings.TrimSpace(RedactString(req.NetworkName))
	if networkName == "" {
		networkName = "leikwan-" + randomHex(4)
	}
	networkSecret := strings.TrimSpace(req.NetworkSecret)
	if networkSecret == "" {
		networkSecret = randomHex(24)
	}
	now := nowString()
	result, err := s.db.ExecContext(ctx, `INSERT INTO network_profiles (name, network_name, network_secret, relay_node_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)`,
		name, networkName, networkSecret, relayNodeID, now, now)
	if err != nil {
		return NetworkProfile{}, err
	}
	id, err := result.LastInsertId()
	if err != nil {
		return NetworkProfile{}, err
	}
	_ = s.AddEvent(ctx, relayNodeID, "info", "network profile created")
	return s.GetNetworkProfile(ctx, id)
}

func (s *Store) ListNetworkProfiles(ctx context.Context) ([]NetworkProfile, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT id, name, network_name, COALESCE(network_secret, ''), relay_node_id, created_at, updated_at FROM network_profiles ORDER BY id DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []NetworkProfile{}
	for rows.Next() {
		var item NetworkProfile
		if err := rows.Scan(&item.ID, &item.Name, &item.NetworkName, &item.NetworkSecret, &item.RelayNodeID, &item.CreatedAt, &item.UpdatedAt); err != nil {
			return nil, err
		}
		out = append(out, redactNetworkProfile(item))
	}
	return out, rows.Err()
}

func (s *Store) getNetworkProfileRaw(ctx context.Context, id int64) (NetworkProfile, error) {
	var item NetworkProfile
	err := s.db.QueryRowContext(ctx, `SELECT id, name, network_name, COALESCE(network_secret, ''), relay_node_id, created_at, updated_at FROM network_profiles WHERE id=?`, id).
		Scan(&item.ID, &item.Name, &item.NetworkName, &item.NetworkSecret, &item.RelayNodeID, &item.CreatedAt, &item.UpdatedAt)
	if err != nil {
		return NetworkProfile{}, err
	}
	return item, nil
}

func (s *Store) GetNetworkProfile(ctx context.Context, id int64) (NetworkProfile, error) {
	item, err := s.getNetworkProfileRaw(ctx, id)
	if err != nil {
		return NetworkProfile{}, err
	}
	return redactNetworkProfile(item), nil
}

func (s *Store) CreatePanelEntry(ctx context.Context, req PanelEntryRequest) (PanelEntry, error) {
	if req.NetworkID <= 0 {
		return PanelEntry{}, fmt.Errorf("network_id is required")
	}
	if _, err := s.getNetworkProfileRaw(ctx, req.NetworkID); err != nil {
		return PanelEntry{}, fmt.Errorf("network profile not found")
	}
	entryNodeID := strings.TrimSpace(RedactString(req.EntryNodeID))
	relayNodeID := strings.TrimSpace(RedactString(req.RelayNodeID))
	if entryNodeID == "" || relayNodeID == "" {
		return PanelEntry{}, fmt.Errorf("entry_node_id and relay_node_id are required")
	}
	if req.ListenPortStart <= 0 || req.ListenPortEnd < req.ListenPortStart {
		return PanelEntry{}, fmt.Errorf("valid listen port range is required")
	}
	listenHost := strings.TrimSpace(RedactString(req.ListenHost))
	if listenHost == "" {
		listenHost = "0.0.0.0"
	}
	protocols := normalizePanelProtocol(req.Protocols)
	now := nowString()
	result, err := s.db.ExecContext(ctx, `INSERT INTO panel_entries (network_id, entry_node_id, relay_node_id, listen_host, listen_port_start, listen_port_end, protocols, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		req.NetworkID, entryNodeID, relayNodeID, listenHost, req.ListenPortStart, req.ListenPortEnd, protocols, normalizePanelStatus(req.Status), now, now)
	if err != nil {
		return PanelEntry{}, err
	}
	id, err := result.LastInsertId()
	if err != nil {
		return PanelEntry{}, err
	}
	_ = s.AddEvent(ctx, entryNodeID, "info", "panel entry created")
	return s.GetPanelEntry(ctx, id)
}

func (s *Store) ListPanelEntries(ctx context.Context) ([]PanelEntry, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT id, network_id, entry_node_id, relay_node_id, listen_host, listen_port_start, listen_port_end, protocols, status, created_at, updated_at FROM panel_entries ORDER BY id DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []PanelEntry{}
	for rows.Next() {
		var item PanelEntry
		if err := rows.Scan(&item.ID, &item.NetworkID, &item.EntryNodeID, &item.RelayNodeID, &item.ListenHost, &item.ListenPortStart, &item.ListenPortEnd, &item.Protocols, &item.Status, &item.CreatedAt, &item.UpdatedAt); err != nil {
			return nil, err
		}
		item.EntryNodeID = RedactString(item.EntryNodeID)
		item.RelayNodeID = RedactString(item.RelayNodeID)
		item.ListenHost = RedactString(item.ListenHost)
		out = append(out, item)
	}
	return out, rows.Err()
}

func (s *Store) GetPanelEntry(ctx context.Context, id int64) (PanelEntry, error) {
	var item PanelEntry
	err := s.db.QueryRowContext(ctx, `SELECT id, network_id, entry_node_id, relay_node_id, listen_host, listen_port_start, listen_port_end, protocols, status, created_at, updated_at FROM panel_entries WHERE id=?`, id).
		Scan(&item.ID, &item.NetworkID, &item.EntryNodeID, &item.RelayNodeID, &item.ListenHost, &item.ListenPortStart, &item.ListenPortEnd, &item.Protocols, &item.Status, &item.CreatedAt, &item.UpdatedAt)
	if err != nil {
		return PanelEntry{}, err
	}
	item.EntryNodeID = RedactString(item.EntryNodeID)
	item.RelayNodeID = RedactString(item.RelayNodeID)
	item.ListenHost = RedactString(item.ListenHost)
	return item, nil
}

func (s *Store) CreatePanelForward(ctx context.Context, req PanelForwardRequest) (PanelForward, error) {
	if req.NetworkID <= 0 || req.EntryID <= 0 {
		return PanelForward{}, fmt.Errorf("network_id and entry_id are required")
	}
	if _, err := s.getNetworkProfileRaw(ctx, req.NetworkID); err != nil {
		return PanelForward{}, fmt.Errorf("network profile not found")
	}
	if _, err := s.GetPanelEntry(ctx, req.EntryID); err != nil {
		return PanelForward{}, fmt.Errorf("entry not found")
	}
	name := strings.TrimSpace(RedactString(req.Name))
	if name == "" {
		return PanelForward{}, fmt.Errorf("name is required")
	}
	relayNodeID := strings.TrimSpace(RedactString(req.RelayNodeID))
	if relayNodeID == "" {
		return PanelForward{}, fmt.Errorf("relay_node_id is required")
	}
	if req.ListenPort <= 0 || req.TargetPort <= 0 {
		return PanelForward{}, fmt.Errorf("listen_port and target_port are required")
	}
	targetHost := strings.TrimSpace(RedactString(req.TargetHost))
	if targetHost == "" {
		return PanelForward{}, fmt.Errorf("target_host is required")
	}
	protocol := normalizePanelProtocol(req.Protocol)
	now := nowString()
	result, err := s.db.ExecContext(ctx, `INSERT INTO panel_forwards (network_id, entry_id, relay_node_id, name, listen_port, target_host, target_port, protocol, pbr_policy_id, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		req.NetworkID, req.EntryID, relayNodeID, name, req.ListenPort, targetHost, req.TargetPort, protocol, req.PBRPolicyID, normalizePanelStatus(req.Status), now, now)
	if err != nil {
		return PanelForward{}, err
	}
	id, err := result.LastInsertId()
	if err != nil {
		return PanelForward{}, err
	}
	_ = s.AddEvent(ctx, relayNodeID, "info", "panel forward created")
	return s.GetPanelForward(ctx, id)
}

func (s *Store) ListPanelForwards(ctx context.Context) ([]PanelForward, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT id, network_id, entry_id, relay_node_id, name, listen_port, target_host, target_port, protocol, COALESCE(pbr_policy_id, 0), status, created_at, updated_at FROM panel_forwards ORDER BY id DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []PanelForward{}
	for rows.Next() {
		var item PanelForward
		if err := rows.Scan(&item.ID, &item.NetworkID, &item.EntryID, &item.RelayNodeID, &item.Name, &item.ListenPort, &item.TargetHost, &item.TargetPort, &item.Protocol, &item.PBRPolicyID, &item.Status, &item.CreatedAt, &item.UpdatedAt); err != nil {
			return nil, err
		}
		item.RelayNodeID = RedactString(item.RelayNodeID)
		item.Name = RedactString(item.Name)
		item.TargetHost = RedactString(item.TargetHost)
		out = append(out, item)
	}
	return out, rows.Err()
}

func (s *Store) GetPanelForward(ctx context.Context, id int64) (PanelForward, error) {
	var item PanelForward
	err := s.db.QueryRowContext(ctx, `SELECT id, network_id, entry_id, relay_node_id, name, listen_port, target_host, target_port, protocol, COALESCE(pbr_policy_id, 0), status, created_at, updated_at FROM panel_forwards WHERE id=?`, id).
		Scan(&item.ID, &item.NetworkID, &item.EntryID, &item.RelayNodeID, &item.Name, &item.ListenPort, &item.TargetHost, &item.TargetPort, &item.Protocol, &item.PBRPolicyID, &item.Status, &item.CreatedAt, &item.UpdatedAt)
	if err != nil {
		return PanelForward{}, err
	}
	item.RelayNodeID = RedactString(item.RelayNodeID)
	item.Name = RedactString(item.Name)
	item.TargetHost = RedactString(item.TargetHost)
	return item, nil
}

func (s *Store) UpdateNetworkProfile(ctx context.Context, id int64, req NetworkProfileRequest) (NetworkProfile, error) {
	if _, err := s.getNetworkProfileRaw(ctx, id); err != nil {
		return NetworkProfile{}, err
	}
	name := strings.TrimSpace(RedactString(req.Name))
	if name == "" {
		return NetworkProfile{}, fmt.Errorf("name is required")
	}
	networkName := strings.TrimSpace(RedactString(req.NetworkName))
	if networkName == "" {
		networkName = "leikwan-" + randomHex(4)
	}
	networkSecret := strings.TrimSpace(req.NetworkSecret)
	if networkSecret == "" {
		old, _ := s.getNetworkProfileRaw(ctx, id)
		networkSecret = old.NetworkSecret
	}
	relayNodeID := strings.TrimSpace(RedactString(req.RelayNodeID))
	if relayNodeID == "" {
		return NetworkProfile{}, fmt.Errorf("relay_node_id is required")
	}
	_, err := s.db.ExecContext(ctx, `UPDATE network_profiles SET name=?, network_name=?, network_secret=?, relay_node_id=?, updated_at=? WHERE id=?`,
		name, networkName, networkSecret, relayNodeID, nowString(), id)
	if err != nil {
		return NetworkProfile{}, err
	}
	return s.GetNetworkProfile(ctx, id)
}

func (s *Store) UpdatePanelEntry(ctx context.Context, id int64, req PanelEntryRequest) (PanelEntry, error) {
	if _, err := s.GetPanelEntry(ctx, id); err != nil {
		return PanelEntry{}, err
	}
	if _, err := s.getNetworkProfileRaw(ctx, req.NetworkID); err != nil {
		return PanelEntry{}, fmt.Errorf("network profile not found")
	}
	if req.ListenPortStart <= 0 || req.ListenPortEnd <= 0 || req.ListenPortStart > req.ListenPortEnd {
		return PanelEntry{}, fmt.Errorf("invalid port range")
	}
	_, err := s.db.ExecContext(ctx, `UPDATE panel_entries SET network_id=?, entry_node_id=?, relay_node_id=?, listen_host=?, listen_port_start=?, listen_port_end=?, protocols=?, status=?, updated_at=? WHERE id=?`,
		req.NetworkID, strings.TrimSpace(RedactString(req.EntryNodeID)), strings.TrimSpace(RedactString(req.RelayNodeID)), strings.TrimSpace(RedactString(req.ListenHost)),
		req.ListenPortStart, req.ListenPortEnd, normalizePanelProtocol(req.Protocols), normalizePanelStatus(req.Status), nowString(), id)
	if err != nil {
		return PanelEntry{}, err
	}
	return s.GetPanelEntry(ctx, id)
}

func (s *Store) UpdatePanelForward(ctx context.Context, id int64, req PanelForwardRequest) (PanelForward, error) {
	if _, err := s.GetPanelForward(ctx, id); err != nil {
		return PanelForward{}, err
	}
	if _, err := s.getNetworkProfileRaw(ctx, req.NetworkID); err != nil {
		return PanelForward{}, fmt.Errorf("network profile not found")
	}
	if _, err := s.GetPanelEntry(ctx, req.EntryID); err != nil {
		return PanelForward{}, fmt.Errorf("entry not found")
	}
	if req.ListenPort <= 0 || req.TargetPort <= 0 {
		return PanelForward{}, fmt.Errorf("listen_port and target_port are required")
	}
	_, err := s.db.ExecContext(ctx, `UPDATE panel_forwards SET network_id=?, entry_id=?, relay_node_id=?, name=?, listen_port=?, target_host=?, target_port=?, protocol=?, pbr_policy_id=?, status=?, updated_at=? WHERE id=?`,
		req.NetworkID, req.EntryID, strings.TrimSpace(RedactString(req.RelayNodeID)), strings.TrimSpace(RedactString(req.Name)), req.ListenPort,
		strings.TrimSpace(RedactString(req.TargetHost)), req.TargetPort, normalizePanelProtocol(req.Protocol), req.PBRPolicyID, normalizePanelStatus(req.Status), nowString(), id)
	if err != nil {
		return PanelForward{}, err
	}
	return s.GetPanelForward(ctx, id)
}

func (s *Store) CreatePBRPolicy(ctx context.Context, req PBRPolicyRequest) (PBRPolicy, error) {
	if err := validatePBRRequest(req); err != nil {
		return PBRPolicy{}, err
	}
	now := nowString()
	result, err := s.db.ExecContext(ctx, `INSERT INTO pbr_policies (name, relay_node_id, source_cidr, target_cidr, output_interface, gateway, table_id, priority, mark, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		RedactString(req.Name), RedactString(req.RelayNodeID), RedactString(req.SourceCIDR), RedactString(req.TargetCIDR), RedactString(req.OutputInterface), RedactString(req.Gateway), req.TableID, req.Priority, RedactString(req.Mark), normalizePanelStatus(req.Status), now, now)
	if err != nil {
		return PBRPolicy{}, err
	}
	id, _ := result.LastInsertId()
	return s.GetPBRPolicy(ctx, id)
}

func (s *Store) ListPBRPolicies(ctx context.Context) ([]PBRPolicy, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT id, name, relay_node_id, source_cidr, target_cidr, output_interface, gateway, table_id, priority, mark, status, created_at, updated_at FROM pbr_policies ORDER BY id DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []PBRPolicy{}
	for rows.Next() {
		var item PBRPolicy
		if err := rows.Scan(&item.ID, &item.Name, &item.RelayNodeID, &item.SourceCIDR, &item.TargetCIDR, &item.OutputInterface, &item.Gateway, &item.TableID, &item.Priority, &item.Mark, &item.Status, &item.CreatedAt, &item.UpdatedAt); err != nil {
			return nil, err
		}
		out = append(out, item)
	}
	return out, rows.Err()
}

func (s *Store) GetPBRPolicy(ctx context.Context, id int64) (PBRPolicy, error) {
	var item PBRPolicy
	err := s.db.QueryRowContext(ctx, `SELECT id, name, relay_node_id, source_cidr, target_cidr, output_interface, gateway, table_id, priority, mark, status, created_at, updated_at FROM pbr_policies WHERE id=?`, id).
		Scan(&item.ID, &item.Name, &item.RelayNodeID, &item.SourceCIDR, &item.TargetCIDR, &item.OutputInterface, &item.Gateway, &item.TableID, &item.Priority, &item.Mark, &item.Status, &item.CreatedAt, &item.UpdatedAt)
	return item, err
}

func (s *Store) UpdatePBRPolicy(ctx context.Context, id int64, req PBRPolicyRequest) (PBRPolicy, error) {
	if _, err := s.GetPBRPolicy(ctx, id); err != nil {
		return PBRPolicy{}, err
	}
	if err := validatePBRRequest(req); err != nil {
		return PBRPolicy{}, err
	}
	_, err := s.db.ExecContext(ctx, `UPDATE pbr_policies SET name=?, relay_node_id=?, source_cidr=?, target_cidr=?, output_interface=?, gateway=?, table_id=?, priority=?, mark=?, status=?, updated_at=? WHERE id=?`,
		RedactString(req.Name), RedactString(req.RelayNodeID), RedactString(req.SourceCIDR), RedactString(req.TargetCIDR), RedactString(req.OutputInterface), RedactString(req.Gateway), req.TableID, req.Priority, RedactString(req.Mark), normalizePanelStatus(req.Status), nowString(), id)
	if err != nil {
		return PBRPolicy{}, err
	}
	return s.GetPBRPolicy(ctx, id)
}

func (s *Store) ApplyPBRPolicy(ctx context.Context, id int64, actor string) (ApplyResponse, error) {
	policy, err := s.GetPBRPolicy(ctx, id)
	if err != nil {
		return ApplyResponse{}, err
	}
	return s.createApplyTasks(ctx, []applyTaskSpec{{nodeID: policy.RelayNodeID, action: "apply_pbr_rules", payload: taskPayload(policy)}}, actor)
}

func (s *Store) CreateDDNSProfile(ctx context.Context, req DDNSProfileRequest) (DDNSProfile, error) {
	if err := validateDDNSRequest(req); err != nil {
		return DDNSProfile{}, err
	}
	now := nowString()
	result, err := s.db.ExecContext(ctx, `INSERT INTO ddns_profiles (node_id, provider, domain, record_type, api_token, zone_id, record_id, target, interval_seconds, status, last_sync_at, last_error, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '', '', ?, ?)`,
		RedactString(req.NodeID), normalizeDDNSProvider(req.Provider), RedactString(req.Domain), normalizeRecordType(req.RecordType), req.APIToken, RedactString(req.ZoneID), RedactString(req.RecordID), RedactString(req.Target), normalizeInterval(req.IntervalSeconds), normalizePanelStatus(req.Status), now, now)
	if err != nil {
		return DDNSProfile{}, err
	}
	id, _ := result.LastInsertId()
	return s.GetDDNSProfile(ctx, id)
}

func (s *Store) ListDDNSProfiles(ctx context.Context) ([]DDNSProfile, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT id, node_id, provider, domain, record_type, api_token, zone_id, record_id, target, interval_seconds, status, last_sync_at, last_error, created_at, updated_at FROM ddns_profiles ORDER BY id DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []DDNSProfile{}
	for rows.Next() {
		var item DDNSProfile
		if err := rows.Scan(&item.ID, &item.NodeID, &item.Provider, &item.Domain, &item.RecordType, &item.APIToken, &item.ZoneID, &item.RecordID, &item.Target, &item.IntervalSeconds, &item.Status, &item.LastSyncAt, &item.LastError, &item.CreatedAt, &item.UpdatedAt); err != nil {
			return nil, err
		}
		item.APIToken = "REDACTED"
		out = append(out, item)
	}
	return out, rows.Err()
}

func (s *Store) GetDDNSProfile(ctx context.Context, id int64) (DDNSProfile, error) {
	item, err := s.getDDNSProfileRaw(ctx, id)
	if err != nil {
		return DDNSProfile{}, err
	}
	item.APIToken = "REDACTED"
	return item, nil
}

func (s *Store) getDDNSProfileRaw(ctx context.Context, id int64) (DDNSProfile, error) {
	var item DDNSProfile
	err := s.db.QueryRowContext(ctx, `SELECT id, node_id, provider, domain, record_type, api_token, zone_id, record_id, target, interval_seconds, status, last_sync_at, last_error, created_at, updated_at FROM ddns_profiles WHERE id=?`, id).
		Scan(&item.ID, &item.NodeID, &item.Provider, &item.Domain, &item.RecordType, &item.APIToken, &item.ZoneID, &item.RecordID, &item.Target, &item.IntervalSeconds, &item.Status, &item.LastSyncAt, &item.LastError, &item.CreatedAt, &item.UpdatedAt)
	return item, err
}

func (s *Store) UpdateDDNSProfile(ctx context.Context, id int64, req DDNSProfileRequest) (DDNSProfile, error) {
	old, err := s.getDDNSProfileRaw(ctx, id)
	if err != nil {
		return DDNSProfile{}, err
	}
	if err := validateDDNSRequest(req); err != nil {
		return DDNSProfile{}, err
	}
	token := req.APIToken
	if strings.TrimSpace(token) == "" {
		token = old.APIToken
	}
	_, err = s.db.ExecContext(ctx, `UPDATE ddns_profiles SET node_id=?, provider=?, domain=?, record_type=?, api_token=?, zone_id=?, record_id=?, target=?, interval_seconds=?, status=?, updated_at=? WHERE id=?`,
		RedactString(req.NodeID), normalizeDDNSProvider(req.Provider), RedactString(req.Domain), normalizeRecordType(req.RecordType), token, RedactString(req.ZoneID), RedactString(req.RecordID), RedactString(req.Target), normalizeInterval(req.IntervalSeconds), normalizePanelStatus(req.Status), nowString(), id)
	if err != nil {
		return DDNSProfile{}, err
	}
	return s.GetDDNSProfile(ctx, id)
}

func (s *Store) ApplyDDNSProfile(ctx context.Context, id int64, actor string) (ApplyResponse, error) {
	profile, err := s.getDDNSProfileRaw(ctx, id)
	if err != nil {
		return ApplyResponse{}, err
	}
	return s.createApplyTasks(ctx, []applyTaskSpec{{nodeID: profile.NodeID, action: "apply_ddns_config", payload: taskPayload(profile)}}, actor)
}

func (s *Store) SyncDDNSProfile(ctx context.Context, id int64, actor string) (ApplyResponse, error) {
	profile, err := s.getDDNSProfileRaw(ctx, id)
	if err != nil {
		return ApplyResponse{}, err
	}
	return s.createApplyTasks(ctx, []applyTaskSpec{{nodeID: profile.NodeID, action: "ddns_sync_now", payload: taskPayload(profile)}}, actor)
}

func taskPayload(v any) json.RawMessage {
	raw, _ := json.Marshal(RedactValue(v))
	return json.RawMessage(raw)
}

func networkApplyPayload(profile NetworkProfile) json.RawMessage {
	return taskPayload(map[string]any{
		"type":           "network_profile",
		"id":             profile.ID,
		"name":           profile.Name,
		"network_name":   profile.NetworkName,
		"network_secret": "REDACTED",
		"relay_node_id":  profile.RelayNodeID,
		"alpha":          "3.0.0-alpha.2",
	})
}

func entryApplyPayload(entry PanelEntry, profile NetworkProfile) json.RawMessage {
	return taskPayload(map[string]any{
		"type":               "entry_config",
		"entry":              entry,
		"network_id":         profile.ID,
		"network_name":       profile.NetworkName,
		"network_secret":     "REDACTED",
		"alpha":              "3.0.0-alpha.2",
		"panel_managed_only": true,
	})
}

func forwardApplyPayload(forward PanelForward, entry PanelEntry, profile NetworkProfile) json.RawMessage {
	return taskPayload(map[string]any{
		"type":               "forward_config",
		"forward":            forward,
		"entry":              entry,
		"network_id":         profile.ID,
		"network_name":       profile.NetworkName,
		"network_secret":     "REDACTED",
		"alpha":              "3.0.0-alpha.2",
		"panel_managed_only": true,
		"target_note":        "backend/landing machine is target_host:target_port and does not need an Agent",
	})
}

type applyTaskSpec struct {
	nodeID  string
	action  string
	payload json.RawMessage
}

func (s *Store) createApplyTasks(ctx context.Context, specs []applyTaskSpec, actor string) (ApplyResponse, error) {
	for _, spec := range specs {
		if err := s.validateTaskCreate(ctx, spec.nodeID, spec.action); err != nil {
			return ApplyResponse{}, err
		}
	}
	groupID := "apply-" + randomHex(8)
	taskIDs := []int64{}
	for _, spec := range specs {
		task, err := s.CreateTask(ctx, CreateTaskRequest{
			NodeID:      spec.nodeID,
			Action:      spec.action,
			RequestedBy: actor,
			TTLSeconds:  600,
			MaxAttempts: 1,
			TaskGroupID: groupID,
			PayloadJSON: spec.payload,
		})
		if err != nil {
			return ApplyResponse{}, err
		}
		taskIDs = append(taskIDs, task.ID)
	}
	return ApplyResponse{TaskGroupID: groupID, TaskIDs: taskIDs, Message: "3.0 alpha apply tasks queued; backend target does not need an Agent"}, nil
}

func (s *Store) ApplyNetworkProfile(ctx context.Context, id int64, actor string) (ApplyResponse, error) {
	profile, err := s.getNetworkProfileRaw(ctx, id)
	if err != nil {
		return ApplyResponse{}, err
	}
	specs := []applyTaskSpec{
		{nodeID: profile.RelayNodeID, action: "install_easytier", payload: networkApplyPayload(profile)},
		{nodeID: profile.RelayNodeID, action: "configure_easytier_network", payload: networkApplyPayload(profile)},
		{nodeID: profile.RelayNodeID, action: "start_easytier", payload: networkApplyPayload(profile)},
		{nodeID: profile.RelayNodeID, action: "easytier_status", payload: taskPayload(map[string]any{"network_id": profile.ID})},
	}
	resp, err := s.createApplyTasks(ctx, specs, actor)
	if err != nil {
		return ApplyResponse{}, err
	}
	_ = s.AddEvent(ctx, profile.RelayNodeID, "info", fmt.Sprintf("network apply task group queued: %s", resp.TaskGroupID))
	return resp, nil
}

func (s *Store) ApplyPanelEntry(ctx context.Context, id int64, actor string) (ApplyResponse, error) {
	entry, err := s.GetPanelEntry(ctx, id)
	if err != nil {
		return ApplyResponse{}, err
	}
	profile, err := s.getNetworkProfileRaw(ctx, entry.NetworkID)
	if err != nil {
		return ApplyResponse{}, fmt.Errorf("network profile not found")
	}
	specs := []applyTaskSpec{
		{nodeID: entry.EntryNodeID, action: "install_easytier", payload: networkApplyPayload(profile)},
		{nodeID: entry.EntryNodeID, action: "configure_easytier_network", payload: networkApplyPayload(profile)},
		{nodeID: entry.EntryNodeID, action: "start_easytier", payload: networkApplyPayload(profile)},
		{nodeID: entry.EntryNodeID, action: "apply_entry_ports", payload: entryApplyPayload(entry, profile)},
		{nodeID: entry.EntryNodeID, action: "reload_firewall_rules", payload: entryApplyPayload(entry, profile)},
		{nodeID: entry.EntryNodeID, action: "verify_config", payload: taskPayload(map[string]any{"type": "verify_entry", "entry_id": entry.ID})},
	}
	if entry.RelayNodeID != entry.EntryNodeID {
		specs = append(specs,
			applyTaskSpec{nodeID: entry.RelayNodeID, action: "install_easytier", payload: networkApplyPayload(profile)},
			applyTaskSpec{nodeID: entry.RelayNodeID, action: "configure_easytier_network", payload: networkApplyPayload(profile)},
			applyTaskSpec{nodeID: entry.RelayNodeID, action: "start_easytier", payload: networkApplyPayload(profile)},
			applyTaskSpec{nodeID: entry.RelayNodeID, action: "verify_config", payload: taskPayload(map[string]any{"type": "verify_relay_network", "entry_id": entry.ID})},
		)
	}
	resp, err := s.createApplyTasks(ctx, specs, actor)
	if err != nil {
		return ApplyResponse{}, err
	}
	_, _ = s.db.ExecContext(ctx, `UPDATE panel_entries SET status='ready', updated_at=? WHERE id=?`, nowString(), id)
	_ = s.AddEvent(ctx, entry.EntryNodeID, "info", fmt.Sprintf("entry apply task group queued: %s", resp.TaskGroupID))
	return resp, nil
}

func (s *Store) ApplyPanelForward(ctx context.Context, id int64, actor string) (ApplyResponse, error) {
	forward, err := s.GetPanelForward(ctx, id)
	if err != nil {
		return ApplyResponse{}, err
	}
	entry, err := s.GetPanelEntry(ctx, forward.EntryID)
	if err != nil {
		return ApplyResponse{}, fmt.Errorf("entry not found")
	}
	profile, err := s.getNetworkProfileRaw(ctx, forward.NetworkID)
	if err != nil {
		return ApplyResponse{}, fmt.Errorf("network profile not found")
	}
	specs := []applyTaskSpec{
		{nodeID: entry.EntryNodeID, action: "apply_entry_ports", payload: entryApplyPayload(entry, profile)},
		{nodeID: entry.EntryNodeID, action: "reload_firewall_rules", payload: entryApplyPayload(entry, profile)},
		{nodeID: entry.EntryNodeID, action: "verify_config", payload: taskPayload(map[string]any{"type": "verify_entry", "entry_id": entry.ID})},
		{nodeID: forward.RelayNodeID, action: "apply_forward_rules", payload: forwardApplyPayload(forward, entry, profile)},
	}
	if forward.PBRPolicyID > 0 {
		policy, err := s.GetPBRPolicy(ctx, forward.PBRPolicyID)
		if err != nil {
			return ApplyResponse{}, fmt.Errorf("pbr policy not found")
		}
		specs = append(specs, applyTaskSpec{nodeID: forward.RelayNodeID, action: "apply_pbr_rules", payload: taskPayload(policy)})
	}
	specs = append(specs,
		applyTaskSpec{nodeID: forward.RelayNodeID, action: "reload_firewall_rules", payload: forwardApplyPayload(forward, entry, profile)},
		applyTaskSpec{nodeID: forward.RelayNodeID, action: "verify_config", payload: taskPayload(map[string]any{"type": "verify_forward", "forward_id": forward.ID})},
	)
	resp, err := s.createApplyTasks(ctx, specs, actor)
	if err != nil {
		return ApplyResponse{}, err
	}
	_, _ = s.db.ExecContext(ctx, `UPDATE panel_forwards SET status='ready', updated_at=? WHERE id=?`, nowString(), id)
	_ = s.AddEvent(ctx, forward.RelayNodeID, "info", fmt.Sprintf("forward apply task group queued: %s", resp.TaskGroupID))
	return resp, nil
}

func (s *Store) ListEvents(ctx context.Context, limit int) ([]Event, error) {
	if limit <= 0 || limit > 200 {
		limit = 100
	}
	rows, err := s.db.QueryContext(ctx, `SELECT id, node_id, level, message, created_at FROM events ORDER BY id DESC LIMIT ?`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Event{}
	for rows.Next() {
		var e Event
		if err := rows.Scan(&e.ID, &e.NodeID, &e.Level, &e.Message, &e.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

func (s *Store) CreateTask(ctx context.Context, req CreateTaskRequest) (Task, error) {
	nodeID := strings.TrimSpace(RedactString(req.NodeID))
	action := strings.TrimSpace(req.Action)
	if nodeID == "" {
		return Task{}, fmt.Errorf("node_id is required")
	}
	if !allowedTaskAction(action) {
		return Task{}, fmt.Errorf("unsupported task action: %s", RedactString(action))
	}
	if payloadContainsCommand(req.PayloadJSON) {
		return Task{}, fmt.Errorf("task payload must not contain command, cmd, or shell fields")
	}
	if err := s.validateTaskCreate(ctx, nodeID, action); err != nil {
		return Task{}, err
	}
	now := nowString()
	ttl := normalizeTTLSeconds(req.TTLSeconds)
	expiresAt := time.Now().UTC().Add(time.Duration(ttl) * time.Second).Format(time.RFC3339)
	maxAttempts := normalizeAttempts(req.MaxAttempts)
	requestedBy := RedactString(strings.TrimSpace(req.RequestedBy))
	taskGroupID := RedactString(strings.TrimSpace(req.TaskGroupID))
	payloadJSON := rawJSONText(req.PayloadJSON)
	taskKind := "readonly"
	if allowedAlphaWriteAction(action) {
		taskKind = "alpha write"
	}
	timeline := newTaskTimeline("created", "info", fmt.Sprintf("%s task queued: %s", taskKind, action))
	result, err := s.db.ExecContext(ctx, `INSERT INTO tasks
		(node_id, action, status, approval_status, requested_by, ttl_seconds, expires_at, retry_of_task_id, attempt, max_attempts, task_group_id, payload_json, timeline_json, result_stdout, result_stderr, exit_code, error, created_at, picked_at, finished_at)
		VALUES (?, ?, 'queued', 'not_required', ?, ?, ?, 0, 1, ?, ?, ?, ?, '', '', 0, '', ?, '', '')`, nodeID, action, requestedBy, ttl, expiresAt, maxAttempts, taskGroupID, payloadJSON, timeline, now)
	if err != nil {
		return Task{}, err
	}
	id, err := result.LastInsertId()
	if err != nil {
		return Task{}, err
	}
	_ = s.AddEvent(ctx, nodeID, "info", fmt.Sprintf("%s task queued: %s", taskKind, action))
	return s.GetTask(ctx, id)
}

func (s *Store) validateTaskCreate(ctx context.Context, nodeID, action string) error {
	if !allowedAlphaWriteAction(action) {
		return nil
	}
	def, err := s.ActionDefinition(ctx, action)
	if err != nil || !def.Enabled || def.Category != "alpha_write" {
		return fmt.Errorf("alpha write action is not enabled: %s", RedactString(action))
	}
	node, found, err := s.GetNode(ctx, nodeID)
	if err != nil {
		return err
	}
	if !found {
		return fmt.Errorf("target node has not reported yet: %s", RedactString(nodeID))
	}
	if node.Status != "online" {
		return fmt.Errorf("target node is not online: %s", RedactString(node.Status))
	}
	if !node.Capabilities.WriteActionsSupported {
		return fmt.Errorf("target node does not enable alpha write actions")
	}
	for _, supported := range node.Capabilities.SupportedWriteActions {
		if supported == action {
			return nil
		}
	}
	return fmt.Errorf("target node does not support action: %s", RedactString(action))
}

func (s *Store) ListTasks(ctx context.Context) ([]Task, error) {
	s.ExpireTasks(ctx)
	rows, err := s.db.QueryContext(ctx, taskSelectSQL+` ORDER BY id DESC LIMIT 200`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanTasks(rows)
}

func (s *Store) GetTask(ctx context.Context, id int64) (Task, error) {
	s.ExpireTasks(ctx)
	rows, err := s.db.QueryContext(ctx, taskSelectSQL+` WHERE id=?`, id)
	if err != nil {
		return Task{}, err
	}
	defer rows.Close()
	tasks, err := scanTasks(rows)
	if err != nil {
		return Task{}, err
	}
	if len(tasks) == 0 {
		return Task{}, sql.ErrNoRows
	}
	return tasks[0], nil
}

func (s *Store) GetTasksByIDs(ctx context.Context, ids []int64) ([]Task, error) {
	s.ExpireTasks(ctx)
	if len(ids) == 0 {
		return []Task{}, nil
	}
	placeholders := strings.TrimRight(strings.Repeat("?,", len(ids)), ",")
	args := make([]any, 0, len(ids))
	for _, id := range ids {
		args = append(args, id)
	}
	rows, err := s.db.QueryContext(ctx, taskSelectSQL+` WHERE id IN (`+placeholders+`) ORDER BY id ASC`, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanTasks(rows)
}

const taskSelectSQL = `SELECT id, node_id, action, status, COALESCE(approval_status, 'not_required'), COALESCE(approved_by, ''), COALESCE(approved_at, ''), COALESCE(requested_by, ''), COALESCE(ttl_seconds, 0), COALESCE(expires_at, ''), COALESCE(retry_of_task_id, 0), COALESCE(attempt, 1), COALESCE(max_attempts, 3), COALESCE(task_group_id, ''), COALESCE(payload_json, 'null'), COALESCE(timeline_json, '[]'), COALESCE(result_stdout, ''), COALESCE(result_stderr, ''), COALESCE(exit_code, 0), COALESCE(error, ''), COALESCE(created_at, ''), COALESCE(picked_at, ''), COALESCE(finished_at, '') FROM tasks`

func scanTasks(rows *sql.Rows) ([]Task, error) {
	out := []Task{}
	for rows.Next() {
		var task Task
		var timeline, payload string
		if err := rows.Scan(&task.ID, &task.NodeID, &task.Action, &task.Status, &task.ApprovalStatus, &task.ApprovedBy, &task.ApprovedAt, &task.RequestedBy, &task.TTLSeconds, &task.ExpiresAt, &task.RetryOfTaskID, &task.Attempt, &task.MaxAttempts, &task.TaskGroupID, &payload, &timeline, &task.ResultStdout, &task.ResultStderr, &task.ExitCode, &task.Error, &task.CreatedAt, &task.PickedAt, &task.FinishedAt); err != nil {
			return nil, err
		}
		task.NodeID = RedactString(task.NodeID)
		task.Action = RedactString(task.Action)
		task.Status = normalizeTaskStatus(task.Status)
		task.ApprovalStatus = normalizeApprovalStatus(task.ApprovalStatus)
		task.ApprovedBy = RedactString(task.ApprovedBy)
		task.RequestedBy = RedactString(task.RequestedBy)
		task.TaskGroupID = RedactString(task.TaskGroupID)
		task.PayloadJSON = json.RawMessage(RedactJSONBytes([]byte(payload)))
		task.ResultStdout = truncateTaskResult(task.ResultStdout)
		task.ResultStderr = truncateTaskResult(task.ResultStderr)
		task.Error = truncateTaskResult(task.Error)
		task.Timeline = json.RawMessage(RedactJSONBytes([]byte(timeline)))
		out = append(out, task)
	}
	return out, rows.Err()
}

func (s *Store) PickTasks(ctx context.Context, nodeID string, limit int) ([]Task, error) {
	nodeID = strings.TrimSpace(RedactString(nodeID))
	if nodeID == "" {
		return nil, fmt.Errorf("node_id is required")
	}
	if limit <= 0 || limit > 20 {
		limit = 5
	}
	now := nowString()
	s.ExpireTasks(ctx)
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	rows, err := tx.QueryContext(ctx, `SELECT id FROM tasks WHERE node_id=? AND status='queued' AND COALESCE(approval_status, 'not_required') IN ('not_required', 'approved') AND action IN ('probe_core_version', 'run_status', 'run_status_json', 'run_doctor', 'run_doctor_json', 'list_forwards', 'ddns_overview', 'node_status', 'easytier_status', 'nftables_status', 'pbr_status', 'ddns_status', 'list_entries', 'verify_config', 'configure_node_role', 'apply_network_profile', 'apply_entry_config', 'apply_forward_config', 'reload_leikwan_core', 'verify_applied_config', 'install_easytier', 'configure_easytier_network', 'start_easytier', 'restart_easytier', 'stop_easytier', 'apply_entry_ports', 'apply_forward_rules', 'apply_pbr_rules', 'apply_ddns_config', 'ddns_sync_now', 'reload_firewall_rules', 'restart_agent', 'reboot_node') ORDER BY id ASC LIMIT ?`, nodeID, limit)
	if err != nil {
		return nil, err
	}
	ids := []int64{}
	for rows.Next() {
		var id int64
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return nil, err
		}
		ids = append(ids, id)
	}
	if err := rows.Close(); err != nil {
		return nil, err
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	for _, id := range ids {
		if _, err := tx.ExecContext(ctx, `UPDATE tasks SET status='picked', picked_at=? WHERE id=? AND status='queued'`, now, id); err != nil {
			return nil, err
		}
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	for _, id := range ids {
		_ = s.AddEvent(ctx, nodeID, "info", fmt.Sprintf("agent picked task: %d", id))
		_ = s.appendTaskTimeline(ctx, id, "picked", "info", "agent picked task")
	}
	if len(ids) == 0 {
		return []Task{}, nil
	}
	placeholders := strings.TrimRight(strings.Repeat("?,", len(ids)), ",")
	args := make([]any, 0, len(ids))
	for _, id := range ids {
		args = append(args, id)
	}
	taskRows, err := s.db.QueryContext(ctx, taskSelectSQL+` WHERE id IN (`+placeholders+`) ORDER BY id ASC`, args...)
	if err != nil {
		return nil, err
	}
	defer taskRows.Close()
	return scanTasks(taskRows)
}

func (s *Store) FinishTask(ctx context.Context, id int64, req TaskResultRequest) (Task, error) {
	status := normalizeTaskStatus(req.Status)
	if status != "succeeded" && status != "failed" && status != "rejected" {
		status = "failed"
	}
	now := nowString()
	stdout := truncateTaskResult(req.ResultStdout)
	stderr := truncateTaskResult(req.ResultStderr)
	errText := truncateTaskResult(req.Error)
	result, err := s.db.ExecContext(ctx, `UPDATE tasks SET status=?, result_stdout=?, result_stderr=?, exit_code=?, error=?, finished_at=? WHERE id=? AND status IN ('picked', 'queued')`,
		status, stdout, stderr, req.ExitCode, errText, now, id)
	if err != nil {
		return Task{}, err
	}
	if rows, err := result.RowsAffected(); err == nil && rows == 0 {
		return Task{}, fmt.Errorf("task is not pending")
	}
	_ = s.appendTaskTimeline(ctx, id, "result", mapTaskLevel(status), fmt.Sprintf("task finished with status=%s exit_code=%d", status, req.ExitCode))
	task, err := s.GetTask(ctx, id)
	if err != nil {
		return Task{}, err
	}
	level := "info"
	if task.Status != "succeeded" {
		level = "warn"
	}
	_ = s.AddEvent(ctx, task.NodeID, level, fmt.Sprintf("task %s: %s", task.Status, task.Action))
	return task, nil
}

func mapTaskLevel(status string) string {
	if status == "succeeded" {
		return "info"
	}
	return "warn"
}

func (s *Store) ExpireTasks(ctx context.Context) {
	now := time.Now().UTC()
	rows, err := s.db.QueryContext(ctx, `SELECT id, node_id, action, COALESCE(timeline_json, '[]') FROM tasks WHERE status='queued' AND COALESCE(expires_at, '') <> '' AND expires_at <= ?`, now.Format(time.RFC3339))
	if err != nil {
		return
	}
	type expiredTask struct {
		id       int64
		nodeID   string
		action   string
		timeline string
	}
	expired := []expiredTask{}
	for rows.Next() {
		var item expiredTask
		if err := rows.Scan(&item.id, &item.nodeID, &item.action, &item.timeline); err == nil {
			expired = append(expired, item)
		}
	}
	_ = rows.Close()
	for _, item := range expired {
		timeline := appendTaskTimeline(item.timeline, "expired", "warn", "task expired before agent pickup")
		if _, err := s.db.ExecContext(ctx, `UPDATE tasks SET status='expired', finished_at=?, timeline_json=? WHERE id=? AND status='queued'`, nowString(), timeline, item.id); err == nil {
			_ = s.AddEvent(ctx, item.nodeID, "warn", fmt.Sprintf("readonly task expired: %s", item.action))
		}
	}
}

func (s *Store) CancelTask(ctx context.Context, id int64) (Task, error) {
	task, err := s.GetTask(ctx, id)
	if err != nil {
		return Task{}, err
	}
	if task.Status != "queued" && task.Status != "picked" {
		return Task{}, fmt.Errorf("task cannot be canceled from status=%s", task.Status)
	}
	now := nowString()
	if _, err := s.db.ExecContext(ctx, `UPDATE tasks SET status='canceled', finished_at=? WHERE id=? AND status IN ('queued', 'picked')`, now, id); err != nil {
		return Task{}, err
	}
	_ = s.appendTaskTimeline(ctx, id, "canceled", "warn", "task canceled by operator")
	_ = s.AddEvent(ctx, task.NodeID, "warn", fmt.Sprintf("readonly task canceled: %s", task.Action))
	return s.GetTask(ctx, id)
}

func (s *Store) RetryTask(ctx context.Context, id int64) (Task, error) {
	task, err := s.GetTask(ctx, id)
	if err != nil {
		return Task{}, err
	}
	if task.Status != "failed" && task.Status != "expired" && task.Status != "canceled" {
		return Task{}, fmt.Errorf("task cannot be retried from status=%s", task.Status)
	}
	if task.Attempt >= task.MaxAttempts {
		return Task{}, fmt.Errorf("task max attempts reached")
	}
	now := nowString()
	ttl := normalizeTTLSeconds(task.TTLSeconds)
	expiresAt := time.Now().UTC().Add(time.Duration(ttl) * time.Second).Format(time.RFC3339)
	timeline := newTaskTimeline("created", "info", fmt.Sprintf("retry of task %d", id))
	result, err := s.db.ExecContext(ctx, `INSERT INTO tasks
		(node_id, action, status, approval_status, requested_by, ttl_seconds, expires_at, retry_of_task_id, attempt, max_attempts, task_group_id, timeline_json, result_stdout, result_stderr, exit_code, error, created_at, picked_at, finished_at)
		VALUES (?, ?, 'queued', 'not_required', ?, ?, ?, ?, ?, ?, ?, ?, '', '', 0, '', ?, '', '')`,
		task.NodeID, task.Action, task.RequestedBy, ttl, expiresAt, task.ID, task.Attempt+1, task.MaxAttempts, task.TaskGroupID, timeline, now)
	if err != nil {
		return Task{}, err
	}
	newID, err := result.LastInsertId()
	if err != nil {
		return Task{}, err
	}
	_ = s.appendTaskTimeline(ctx, id, "retry", "info", fmt.Sprintf("created retry task %d", newID))
	_ = s.AddEvent(ctx, task.NodeID, "info", fmt.Sprintf("readonly task retry queued: %d -> %d", id, newID))
	return s.GetTask(ctx, newID)
}

func (s *Store) ApproveTask(ctx context.Context, id int64, req TaskApprovalRequest) (Task, error) {
	return s.setTaskApproval(ctx, id, "approved", "approve", req)
}

func (s *Store) RejectTask(ctx context.Context, id int64, req TaskApprovalRequest) (Task, error) {
	return s.setTaskApproval(ctx, id, "rejected", "reject", req)
}

func (s *Store) setTaskApproval(ctx context.Context, id int64, status, timelineAction string, req TaskApprovalRequest) (Task, error) {
	task, err := s.GetTask(ctx, id)
	if err != nil {
		return Task{}, err
	}
	actor := RedactString(strings.TrimSpace(req.Actor))
	if actor == "" {
		actor = "operator"
	}
	now := nowString()
	if _, err := s.db.ExecContext(ctx, `UPDATE tasks SET approval_status=?, approved_by=?, approved_at=? WHERE id=?`, status, actor, now, id); err != nil {
		return Task{}, err
	}
	message := fmt.Sprintf("approval %s by %s", status, actor)
	if strings.TrimSpace(req.Note) != "" {
		message += ": " + RedactString(req.Note)
	}
	_ = s.appendTaskTimeline(ctx, id, timelineAction, "info", message)
	_ = s.AddEvent(ctx, task.NodeID, "info", fmt.Sprintf("readonly task approval %s: %s", status, task.Action))
	return s.GetTask(ctx, id)
}

func (s *Store) TaskTimeline(ctx context.Context, id int64) ([]TaskTimelineItem, error) {
	task, err := s.GetTask(ctx, id)
	if err != nil {
		return nil, err
	}
	items := []TaskTimelineItem{}
	if len(task.Timeline) > 0 {
		_ = json.Unmarshal(task.Timeline, &items)
	}
	return items, nil
}

func (s *Store) ListNodeReports(ctx context.Context, nodeID string, limit int) ([]NodeReport, error) {
	if limit <= 0 || limit > 200 {
		limit = 100
	}
	rows, err := s.db.QueryContext(ctx, `SELECT id, node_id, COALESCE(status, 'unknown'), COALESCE(health_score, 0), COALESCE(interval_seconds, 0), COALESCE(services_json, '{}'), COALESCE(capabilities_json, '{}'), COALESCE(summary_json, 'null'), COALESCE(doctor_json, 'null'), COALESCE(recent_errors_json, '[]'), COALESCE(raw_json, '{}'), COALESCE(created_at, '')
		FROM node_reports WHERE node_id=? ORDER BY id DESC LIMIT ?`, nodeID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []NodeReport{}
	for rows.Next() {
		var r NodeReport
		var servicesJSON, capabilitiesJSON, summaryJSON, doctorJSON, errorsJSON string
		if err := rows.Scan(&r.ID, &r.NodeID, &r.Status, &r.HealthScore, &r.IntervalSeconds, &servicesJSON, &capabilitiesJSON, &summaryJSON, &doctorJSON, &errorsJSON, &r.RawJSON, &r.CreatedAt); err != nil {
			return nil, err
		}
		r.Services = scanJSONMap(servicesJSON)
		r.Capabilities = scanCapabilities(capabilitiesJSON)
		r.Summary = json.RawMessage(summaryJSON)
		r.Doctor = json.RawMessage(doctorJSON)
		r.RecentErrors = scanStringSlice(errorsJSON)
		out = append(out, r)
	}
	return out, rows.Err()
}

func (s *Store) ListNodeEvents(ctx context.Context, nodeID string, limit int) ([]Event, error) {
	if limit <= 0 || limit > 200 {
		limit = 100
	}
	rows, err := s.db.QueryContext(ctx, `SELECT id, node_id, level, message, created_at FROM events WHERE node_id=? ORDER BY id DESC LIMIT ?`, nodeID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Event{}
	for rows.Next() {
		var e Event
		if err := rows.Scan(&e.ID, &e.NodeID, &e.Level, &e.Message, &e.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

func (s *Store) CreatePlan(ctx context.Context, req CreatePlanRequest) (Plan, error) {
	planType, err := normalizePlanType(req.Type)
	if err != nil {
		return Plan{}, err
	}
	title := RedactString(req.Title)
	if title == "" {
		title = planType
	}
	now := nowString()
	payload := rawPlanPayload(req.Payload)
	snapshotPolicy := defaultSnapshotPolicy(planType)
	snapshotRequired := snapshotPolicy == "required"
	snapshotStatus := "missing"
	if snapshotPolicy == "not_required" {
		snapshotStatus = "not_required"
	}
	result, err := s.db.ExecContext(ctx, `INSERT INTO plans
		(type, title, status, execution_status, execution_note, manual_result, dry_run_status, dry_run_task_ids, dry_run_report, last_dry_run_at, snapshot_policy, snapshot_required, snapshot_status, snapshot_ref, snapshot_note, rollback_available, rollback_ref, rollback_note, rollback_instructions, verification_status, verification_report, verification_note, executed_by, executed_at, verified_by, verified_at, timeline_json, safety_level, command_classification, target_node_id, payload_json, generated_commands, command_groups, checklist, preflight, capability_requirements, markdown, warnings, created_at, updated_at)
		VALUES (?, ?, 'draft', 'not_run', '', '', 'not_run', '[]', '{}', '', ?, ?, ?, '', '', 0, '', '', '', 'not_run', '{}', '', '', '', '', '', '[]', 'safe', 'manual', ?, ?, '[]', '[]', '[]', '{}', '[]', '', '[]', ?, ?)`,
		planType, title, snapshotPolicy, snapshotRequired, snapshotStatus, RedactString(req.TargetNodeID), payload, now, now)
	if err != nil {
		return Plan{}, err
	}
	id, err := result.LastInsertId()
	if err != nil {
		return Plan{}, err
	}
	_ = s.AddEvent(ctx, req.TargetNodeID, "info", fmt.Sprintf("plan created: %s", planType))
	return s.GetPlan(ctx, id)
}

func (s *Store) ListPlans(ctx context.Context) ([]Plan, error) {
	rows, err := s.db.QueryContext(ctx, planSelectSQL+` ORDER BY id DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanPlans(rows)
}

func (s *Store) GetPlan(ctx context.Context, id int64) (Plan, error) {
	rows, err := s.db.QueryContext(ctx, planSelectSQL+` WHERE id=?`, id)
	if err != nil {
		return Plan{}, err
	}
	defer rows.Close()
	plans, err := scanPlans(rows)
	if err != nil {
		return Plan{}, err
	}
	if len(plans) == 0 {
		return Plan{}, sql.ErrNoRows
	}
	return plans[0], nil
}

const planSelectSQL = `SELECT id, type, title, status, COALESCE(execution_status, 'not_run'), COALESCE(execution_note, ''), COALESCE(manual_result, ''), COALESCE(dry_run_status, 'not_run'), COALESCE(dry_run_task_ids, '[]'), COALESCE(dry_run_report, '{}'), COALESCE(last_dry_run_at, ''), COALESCE(snapshot_policy, ''), COALESCE(snapshot_required, 0), COALESCE(snapshot_status, ''), COALESCE(snapshot_ref, ''), COALESCE(snapshot_note, ''), COALESCE(rollback_available, 0), COALESCE(rollback_ref, ''), COALESCE(rollback_note, ''), COALESCE(rollback_instructions, ''), COALESCE(verification_status, 'not_run'), COALESCE(verification_report, '{}'), COALESCE(verification_note, ''), COALESCE(executed_by, ''), COALESCE(executed_at, ''), COALESCE(verified_by, ''), COALESCE(verified_at, ''), COALESCE(timeline_json, '[]'), COALESCE(safety_level, 'safe'), COALESCE(command_classification, 'manual'), target_node_id, COALESCE(payload_json, '{}'), COALESCE(generated_commands, '[]'), COALESCE(command_groups, '[]'), COALESCE(checklist, '[]'), COALESCE(preflight, '{}'), COALESCE(capability_requirements, '[]'), COALESCE(markdown, ''), COALESCE(warnings, '[]'), created_at, updated_at FROM plans`

func scanPlans(rows *sql.Rows) ([]Plan, error) {
	out := []Plan{}
	for rows.Next() {
		var p Plan
		var payload, commands, commandGroups, checklist, preflight, capabilityRequirements, markdown, warnings string
		var dryRunTaskIDs, dryRunReport string
		var snapshotRequired, rollbackAvailable int
		var verificationReport, timeline string
		if err := rows.Scan(&p.ID, &p.Type, &p.Title, &p.Status, &p.ExecutionStatus, &p.ExecutionNote, &p.ManualResult, &p.DryRunStatus, &dryRunTaskIDs, &dryRunReport, &p.LastDryRunAt, &p.SnapshotPolicy, &snapshotRequired, &p.SnapshotStatus, &p.SnapshotRef, &p.SnapshotNote, &rollbackAvailable, &p.RollbackRef, &p.RollbackNote, &p.RollbackInstructions, &p.VerificationStatus, &verificationReport, &p.VerificationNote, &p.ExecutedBy, &p.ExecutedAt, &p.VerifiedBy, &p.VerifiedAt, &timeline, &p.SafetyLevel, &p.CommandClassification, &p.TargetNodeID, &payload, &commands, &commandGroups, &checklist, &preflight, &capabilityRequirements, &markdown, &warnings, &p.CreatedAt, &p.UpdatedAt); err != nil {
			return nil, err
		}
		p.PayloadJSON = json.RawMessage(RedactJSONBytes([]byte(payload)))
		p.DryRunStatus = normalizeDryRunStatus(p.DryRunStatus)
		p.DryRunTaskIDs = scanInt64Slice(dryRunTaskIDs)
		p.DryRunReport = json.RawMessage(RedactJSONBytes([]byte(dryRunReport)))
		if strings.TrimSpace(p.SnapshotPolicy) == "" {
			p.SnapshotPolicy = defaultSnapshotPolicy(p.Type)
		}
		p.SnapshotPolicy = normalizeSnapshotPolicy(p.SnapshotPolicy)
		p.SnapshotRequired = snapshotRequired != 0 || p.SnapshotPolicy == "required"
		if strings.TrimSpace(p.SnapshotStatus) == "" {
			p.SnapshotStatus = "missing"
			if p.SnapshotPolicy == "not_required" {
				p.SnapshotStatus = "not_required"
			}
		}
		p.SnapshotStatus = normalizeSnapshotStatus(p.SnapshotStatus)
		if p.SnapshotPolicy == "not_required" {
			p.SnapshotStatus = "not_required"
		}
		p.SnapshotRef = RedactString(p.SnapshotRef)
		p.SnapshotNote = RedactString(p.SnapshotNote)
		p.RollbackAvailable = rollbackAvailable != 0
		p.RollbackRef = RedactString(p.RollbackRef)
		p.RollbackNote = RedactString(p.RollbackNote)
		p.RollbackInstructions = RedactString(p.RollbackInstructions)
		p.VerificationStatus = normalizeVerificationStatus(p.VerificationStatus)
		p.VerificationReport = json.RawMessage(RedactJSONBytes([]byte(verificationReport)))
		p.VerificationNote = RedactString(p.VerificationNote)
		p.ExecutedBy = RedactString(p.ExecutedBy)
		p.VerifiedBy = RedactString(p.VerifiedBy)
		p.Timeline = json.RawMessage(RedactJSONBytes([]byte(timeline)))
		p.GeneratedCommands = scanStringSlice(commands)
		p.CommandGroups = scanCommandGroups(commandGroups)
		p.Checklist = scanStringSlice(checklist)
		p.Preflight = json.RawMessage(RedactJSONBytes([]byte(preflight)))
		p.CapabilityRequirements = scanStringSlice(capabilityRequirements)
		p.Markdown = RedactString(markdown)
		p.Warnings = scanStringSlice(warnings)
		p.ExecutionStatus = normalizeExecutionStatus(p.ExecutionStatus)
		p.SafetyLevel = normalizeSafetyLevel(p.SafetyLevel)
		p.CommandClassification = normalizeCommandClassification(p.CommandClassification)
		p.ExecutionNote = RedactString(p.ExecutionNote)
		p.ManualResult = RedactString(p.ManualResult)
		out = append(out, p)
	}
	return out, rows.Err()
}

func (s *Store) GeneratePlan(ctx context.Context, id int64) (Plan, error) {
	return s.generatePlan(ctx, id, "plan generated")
}

func (s *Store) RegeneratePlan(ctx context.Context, id int64) (Plan, error) {
	return s.generatePlan(ctx, id, "plan regenerated")
}

func (s *Store) generatePlan(ctx context.Context, id int64, event string) (Plan, error) {
	plan, err := s.GetPlan(ctx, id)
	if err != nil {
		return Plan{}, err
	}
	artifacts := s.buildPlanArtifacts(ctx, plan)
	now := nowString()
	if _, err := s.db.ExecContext(ctx, `UPDATE plans SET status='generated', generated_commands=?, command_groups=?, checklist=?, preflight=?, capability_requirements=?, markdown=?, warnings=?, rollback_instructions=?, safety_level=?, command_classification=?, updated_at=? WHERE id=?`,
		jsonText(artifacts.GeneratedCommands), jsonText(artifacts.CommandGroups), jsonText(artifacts.Checklist), rawJSONText(artifacts.Preflight), jsonText(artifacts.CapabilityRequirements), RedactString(artifacts.Markdown), jsonText(artifacts.Warnings), RedactString(artifacts.RollbackInstructions), artifacts.SafetyLevel, artifacts.CommandClassification, now, id); err != nil {
		return Plan{}, err
	}
	_ = s.AddEvent(ctx, plan.TargetNodeID, "info", fmt.Sprintf("%s: %s", event, plan.Type))
	return s.GetPlan(ctx, id)
}

func (s *Store) MarkPlan(ctx context.Context, id int64, req MarkPlanRequest) (Plan, error) {
	return s.MarkPlanBy(ctx, id, req, "operator")
}

func (s *Store) MarkPlanBy(ctx context.Context, id int64, req MarkPlanRequest, actor string) (Plan, error) {
	status := normalizeExecutionStatus(req.ExecutionStatus)
	actor = RedactString(strings.TrimSpace(actor))
	if actor == "" {
		actor = "operator"
	}
	now := nowString()
	if _, err := s.db.ExecContext(ctx, `UPDATE plans SET execution_status=?, execution_note=?, manual_result=?, updated_at=? WHERE id=?`,
		status, redactManualText(req.ExecutionNote), redactManualText(req.ManualResult), now, id); err != nil {
		return Plan{}, err
	}
	plan, err := s.GetPlan(ctx, id)
	if err != nil {
		return Plan{}, err
	}
	_ = s.AddEvent(ctx, plan.TargetNodeID, "info", fmt.Sprintf("plan marked %s by %s: %s", status, actor, plan.Type))
	return plan, nil
}

func (s *Store) PlanMarkdown(ctx context.Context, id int64) (string, error) {
	plan, err := s.GetPlan(ctx, id)
	if err != nil {
		return "", err
	}
	if strings.TrimSpace(plan.Markdown) != "" {
		return RedactString(plan.Markdown), nil
	}
	return RedactString(s.buildPlanArtifacts(ctx, plan).Markdown), nil
}

func (s *Store) PlanPreflight(ctx context.Context, id int64) (Plan, error) {
	plan, err := s.GetPlan(ctx, id)
	if err != nil {
		return Plan{}, err
	}
	artifacts := s.buildPlanArtifacts(ctx, plan)
	now := nowString()
	if _, err := s.db.ExecContext(ctx, `UPDATE plans SET preflight=?, safety_level=?, command_classification=?, capability_requirements=?, updated_at=? WHERE id=?`,
		rawJSONText(artifacts.Preflight), artifacts.SafetyLevel, artifacts.CommandClassification, jsonText(artifacts.CapabilityRequirements), now, id); err != nil {
		return Plan{}, err
	}
	_ = s.AddEvent(ctx, plan.TargetNodeID, "info", fmt.Sprintf("plan preflight generated: %s", plan.Type))
	return s.GetPlan(ctx, id)
}

func (s *Store) StartPlanDryRun(ctx context.Context, id int64) (Plan, error) {
	plan, err := s.GetPlan(ctx, id)
	if err != nil {
		return Plan{}, err
	}
	if strings.TrimSpace(plan.TargetNodeID) == "" {
		report := dryRunReport("failed", "target node is required before dry-run", map[string]any{
			"plan_id": id,
			"checks":  []string{"target node missing"},
		})
		now := nowString()
		if _, err := s.db.ExecContext(ctx, `UPDATE plans SET dry_run_status='failed', dry_run_task_ids='[]', dry_run_report=?, last_dry_run_at=?, updated_at=? WHERE id=?`, rawJSONText(report), now, now, id); err != nil {
			return Plan{}, err
		}
		_ = s.AddEvent(ctx, plan.TargetNodeID, "warn", fmt.Sprintf("plan dry-run failed: %s", plan.Type))
		return s.GetPlan(ctx, id)
	}
	actions := dryRunActionsForPlan(plan.Type)
	if len(actions) == 0 {
		return Plan{}, fmt.Errorf("unsupported dry-run plan type: %s", plan.Type)
	}
	groupID := fmt.Sprintf("plan-%d-dry-run-%d", id, time.Now().UTC().Unix())
	ids := []int64{}
	for _, action := range actions {
		if !allowedTaskAction(action) {
			return Plan{}, fmt.Errorf("unsupported dry-run action: %s", action)
		}
		task, err := s.CreateTask(ctx, CreateTaskRequest{
			NodeID:      plan.TargetNodeID,
			Action:      action,
			RequestedBy: "plan-dry-run",
			TTLSeconds:  300,
			MaxAttempts: 1,
			TaskGroupID: groupID,
		})
		if err != nil {
			return Plan{}, err
		}
		ids = append(ids, task.ID)
	}
	report := dryRunReport("running", "readonly dry-run tasks queued; waiting for Agent results", map[string]any{
		"plan_id":          id,
		"plan_type":        plan.Type,
		"target_node_id":   plan.TargetNodeID,
		"task_group_id":    groupID,
		"queued_actions":   actions,
		"dry_run_task_ids": ids,
	})
	now := nowString()
	if _, err := s.db.ExecContext(ctx, `UPDATE plans SET dry_run_status='running', dry_run_task_ids=?, dry_run_report=?, last_dry_run_at=?, updated_at=? WHERE id=?`,
		jsonText(ids), rawJSONText(report), now, now, id); err != nil {
		return Plan{}, err
	}
	_ = s.AddEvent(ctx, plan.TargetNodeID, "info", fmt.Sprintf("plan dry-run queued: %s", plan.Type))
	return s.GetPlan(ctx, id)
}

func (s *Store) PlanDryRun(ctx context.Context, id int64) (Plan, error) {
	plan, err := s.GetPlan(ctx, id)
	if err != nil {
		return Plan{}, err
	}
	if len(plan.DryRunTaskIDs) == 0 {
		return plan, nil
	}
	tasks, err := s.GetTasksByIDs(ctx, plan.DryRunTaskIDs)
	if err != nil {
		return Plan{}, err
	}
	status, report := s.buildDryRunReport(ctx, plan, tasks)
	now := nowString()
	if _, err := s.db.ExecContext(ctx, `UPDATE plans SET dry_run_status=?, dry_run_report=?, updated_at=? WHERE id=?`,
		status, rawJSONText(report), now, id); err != nil {
		return Plan{}, err
	}
	return s.GetPlan(ctx, id)
}

func (s *Store) RecordPlanSnapshot(ctx context.Context, id int64, req PlanSnapshotRequest) (Plan, error) {
	plan, err := s.GetPlan(ctx, id)
	if err != nil {
		return Plan{}, err
	}
	status := normalizeSnapshotStatus(req.SnapshotStatus)
	if req.SnapshotStatus == "" {
		status = "missing"
		if strings.TrimSpace(req.SnapshotRef) != "" {
			status = "recorded"
		}
		if plan.SnapshotPolicy == "not_required" && strings.TrimSpace(req.SnapshotRef) == "" {
			status = "not_required"
		}
	}
	now := nowString()
	if _, err := s.db.ExecContext(ctx, `UPDATE plans SET snapshot_status=?, snapshot_ref=?, snapshot_note=?, updated_at=? WHERE id=?`,
		status, redactManualText(req.SnapshotRef), redactManualText(req.SnapshotNote), now, id); err != nil {
		return Plan{}, err
	}
	_ = s.AddEvent(ctx, plan.TargetNodeID, "info", fmt.Sprintf("plan snapshot metadata recorded: %s", plan.Type))
	return s.GetPlan(ctx, id)
}

func (s *Store) RecordPlanRollbackInfo(ctx context.Context, id int64, req PlanRollbackInfoRequest) (Plan, error) {
	plan, err := s.GetPlan(ctx, id)
	if err != nil {
		return Plan{}, err
	}
	available := req.RollbackAvailable || strings.TrimSpace(req.RollbackRef) != "" || strings.TrimSpace(req.RollbackNote) != ""
	now := nowString()
	if _, err := s.db.ExecContext(ctx, `UPDATE plans SET rollback_available=?, rollback_ref=?, rollback_note=?, updated_at=? WHERE id=?`,
		available, redactManualText(req.RollbackRef), redactManualText(req.RollbackNote), now, id); err != nil {
		return Plan{}, err
	}
	_ = s.AddEvent(ctx, plan.TargetNodeID, "info", fmt.Sprintf("plan rollback metadata recorded: %s", plan.Type))
	return s.GetPlan(ctx, id)
}

func allowedMetadataAction(action string) bool {
	switch strings.TrimSpace(action) {
	case "record_snapshot_ref", "record_rollback_ref", "mark_plan_executed", "mark_plan_verified", "attach_manual_evidence":
		return true
	default:
		return false
	}
}

func (s *Store) appendPlanTimeline(ctx context.Context, id int64, action, level, message string) error {
	var timeline string
	if err := s.db.QueryRowContext(ctx, `SELECT COALESCE(timeline_json, '[]') FROM plans WHERE id=?`, id).Scan(&timeline); err != nil {
		return err
	}
	_, err := s.db.ExecContext(ctx, `UPDATE plans SET timeline_json=? WHERE id=?`, appendTaskTimeline(timeline, action, level, message), id)
	return err
}

func (s *Store) ApplyPlanMetadataAction(ctx context.Context, id int64, req PlanMetadataActionRequest, actor string) (Plan, error) {
	plan, err := s.GetPlan(ctx, id)
	if err != nil {
		return Plan{}, err
	}
	action := strings.TrimSpace(req.Action)
	if !allowedMetadataAction(action) {
		return Plan{}, fmt.Errorf("unsupported metadata action: %s", RedactString(action))
	}
	actor = RedactString(strings.TrimSpace(actor))
	if actor == "" {
		actor = "operator"
	}
	now := nowString()
	switch action {
	case "record_snapshot_ref":
		status := "recorded"
		if strings.TrimSpace(req.SnapshotRef) == "" {
			status = normalizeSnapshotStatus(plan.SnapshotStatus)
			if status == "" || status == "missing" {
				status = "missing"
			}
		}
		if _, err := s.db.ExecContext(ctx, `UPDATE plans SET snapshot_status=?, snapshot_ref=?, snapshot_note=?, updated_at=? WHERE id=?`,
			status, redactManualText(req.SnapshotRef), redactManualText(firstNonEmpty(req.SnapshotNote, req.Note)), now, id); err != nil {
			return Plan{}, err
		}
	case "record_rollback_ref":
		available := strings.TrimSpace(req.RollbackRef) != "" || strings.TrimSpace(req.RollbackNote) != "" || strings.TrimSpace(req.Note) != ""
		if _, err := s.db.ExecContext(ctx, `UPDATE plans SET rollback_available=?, rollback_ref=?, rollback_note=?, updated_at=? WHERE id=?`,
			available, redactManualText(req.RollbackRef), redactManualText(firstNonEmpty(req.RollbackNote, req.Note)), now, id); err != nil {
			return Plan{}, err
		}
	case "mark_plan_executed":
		status := normalizeExecutionStatus(req.ExecutionStatus)
		if strings.TrimSpace(req.ExecutionStatus) == "" || status == "not_run" {
			status = "succeeded"
		}
		if _, err := s.db.ExecContext(ctx, `UPDATE plans SET execution_status=?, execution_note=?, manual_result=?, executed_by=?, executed_at=?, updated_at=? WHERE id=?`,
			status, redactManualText(req.Note), redactManualText(req.Content), actor, now, now, id); err != nil {
			return Plan{}, err
		}
	case "mark_plan_verified":
		status := normalizeVerificationStatus(req.VerificationStatus)
		if strings.TrimSpace(req.VerificationStatus) == "" || status == "not_run" {
			status = "passed"
		}
		report := RedactValue(map[string]any{
			"metadata_action":     action,
			"verification_status": status,
			"verified_by":         actor,
			"note":                req.Note,
			"recorded_at":         now,
			"controller_only":     true,
		})
		if _, err := s.db.ExecContext(ctx, `UPDATE plans SET verification_status=?, verification_note=?, verification_report=?, verified_by=?, verified_at=?, updated_at=? WHERE id=?`,
			status, redactManualText(req.Note), jsonText(report), actor, now, now, id); err != nil {
			return Plan{}, err
		}
	case "attach_manual_evidence":
		if _, err := s.CreatePlanEvidence(ctx, id, PlanEvidenceRequest{EvidenceType: req.EvidenceType, Title: req.Title, Content: firstNonEmpty(req.Content, req.Note)}, actor); err != nil {
			return Plan{}, err
		}
	}
	_ = s.appendPlanTimeline(ctx, id, action, "info", fmt.Sprintf("%s by %s: %s", action, actor, req.Note))
	_ = s.AddEvent(ctx, plan.TargetNodeID, "info", fmt.Sprintf("plan metadata action %s by %s: %s", action, actor, plan.Type))
	return s.GetPlan(ctx, id)
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}

func (s *Store) CreatePlanEvidence(ctx context.Context, id int64, req PlanEvidenceRequest, actor string) (PlanEvidence, error) {
	plan, err := s.GetPlan(ctx, id)
	if err != nil {
		return PlanEvidence{}, err
	}
	actor = RedactString(strings.TrimSpace(actor))
	if actor == "" {
		actor = "operator"
	}
	evidenceType := RedactString(strings.TrimSpace(req.EvidenceType))
	if evidenceType == "" {
		evidenceType = "manual"
	}
	title := RedactString(strings.TrimSpace(req.Title))
	if title == "" {
		title = evidenceType
	}
	content := redactManualText(req.Content)
	now := nowString()
	result, err := s.db.ExecContext(ctx, `INSERT INTO plan_evidence (plan_id, evidence_type, title, content, created_by, created_at, redacted_content) VALUES (?, ?, ?, ?, ?, ?, ?)`,
		id, evidenceType, title, content, actor, now, content)
	if err != nil {
		return PlanEvidence{}, err
	}
	evidenceID, err := result.LastInsertId()
	if err != nil {
		return PlanEvidence{}, err
	}
	_ = s.appendPlanTimeline(ctx, id, "attach_manual_evidence", "info", fmt.Sprintf("manual evidence attached by %s: %s", actor, title))
	_ = s.AddEvent(ctx, plan.TargetNodeID, "info", fmt.Sprintf("plan manual evidence attached by %s: %s", actor, plan.Type))
	return s.GetPlanEvidence(ctx, evidenceID)
}

func (s *Store) GetPlanEvidence(ctx context.Context, evidenceID int64) (PlanEvidence, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT id, plan_id, COALESCE(evidence_type, ''), COALESCE(title, ''), COALESCE(content, ''), COALESCE(created_by, ''), COALESCE(created_at, ''), COALESCE(redacted_content, '') FROM plan_evidence WHERE id=?`, evidenceID)
	if err != nil {
		return PlanEvidence{}, err
	}
	defer rows.Close()
	items, err := scanPlanEvidence(rows)
	if err != nil {
		return PlanEvidence{}, err
	}
	if len(items) == 0 {
		return PlanEvidence{}, sql.ErrNoRows
	}
	return items[0], nil
}

func (s *Store) ListPlanEvidence(ctx context.Context, id int64) ([]PlanEvidence, error) {
	if _, err := s.GetPlan(ctx, id); err != nil {
		return nil, err
	}
	rows, err := s.db.QueryContext(ctx, `SELECT id, plan_id, COALESCE(evidence_type, ''), COALESCE(title, ''), COALESCE(content, ''), COALESCE(created_by, ''), COALESCE(created_at, ''), COALESCE(redacted_content, '') FROM plan_evidence WHERE plan_id=? ORDER BY id DESC`, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanPlanEvidence(rows)
}

func (s *Store) CountPlanEvidence(ctx context.Context, id int64) int {
	var count int
	_ = s.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM plan_evidence WHERE plan_id=?`, id).Scan(&count)
	return count
}

func scanPlanEvidence(rows *sql.Rows) ([]PlanEvidence, error) {
	out := []PlanEvidence{}
	for rows.Next() {
		var item PlanEvidence
		if err := rows.Scan(&item.ID, &item.PlanID, &item.EvidenceType, &item.Title, &item.Content, &item.CreatedBy, &item.CreatedAt, &item.RedactedContent); err != nil {
			return nil, err
		}
		item.EvidenceType = RedactString(item.EvidenceType)
		item.Title = RedactString(item.Title)
		item.Content = RedactString(item.Content)
		item.CreatedBy = RedactString(item.CreatedBy)
		item.RedactedContent = RedactString(item.RedactedContent)
		out = append(out, item)
	}
	return out, rows.Err()
}

func (s *Store) PlanSafetyGate(ctx context.Context, id int64) (SafetyGateResponse, error) {
	plan, err := s.GetPlan(ctx, id)
	if err != nil {
		return SafetyGateResponse{}, err
	}
	return buildSafetyGateWithEvidence(plan, s.CountPlanEvidence(ctx, id)), nil
}

func (s *Store) VerifyPlan(ctx context.Context, id int64) (Plan, error) {
	plan, err := s.GetPlan(ctx, id)
	if err != nil {
		return Plan{}, err
	}
	gate := buildSafetyGateWithEvidence(plan, s.CountPlanEvidence(ctx, id))
	status := "passed"
	if len(gate.BlockedReasons) > 0 {
		status = "failed"
	} else if len(gate.Warnings) > 0 || plan.DryRunStatus == "warning" {
		status = "warning"
	}
	report := RedactValue(map[string]any{
		"plan_id":             plan.ID,
		"verification_status": status,
		"safety_gate":         gate,
		"node_id":             plan.TargetNodeID,
		"dry_run_status":      plan.DryRunStatus,
		"snapshot_policy":     plan.SnapshotPolicy,
		"snapshot_status":     plan.SnapshotStatus,
		"rollback_available":  plan.RollbackAvailable,
		"checked_at":          nowString(),
		"note":                "Controller-side verification only; no Agent task or system change was created.",
	})
	now := nowString()
	if _, err := s.db.ExecContext(ctx, `UPDATE plans SET verification_status=?, verification_report=?, updated_at=? WHERE id=?`,
		status, jsonText(report), now, id); err != nil {
		return Plan{}, err
	}
	_ = s.AddEvent(ctx, plan.TargetNodeID, "info", fmt.Sprintf("plan verification %s: %s", status, plan.Type))
	return s.GetPlan(ctx, id)
}

func (s *Store) ArchivePlan(ctx context.Context, id int64) (Plan, error) {
	now := nowString()
	if _, err := s.db.ExecContext(ctx, `UPDATE plans SET status='archived', updated_at=? WHERE id=?`, now, id); err != nil {
		return Plan{}, err
	}
	plan, err := s.GetPlan(ctx, id)
	if err != nil {
		return Plan{}, err
	}
	_ = s.AddEvent(ctx, plan.TargetNodeID, "info", fmt.Sprintf("plan archived: %s", plan.Type))
	return plan, nil
}

type planArtifacts struct {
	GeneratedCommands      []string
	CommandGroups          []CommandGroup
	Checklist              []string
	Preflight              json.RawMessage
	CapabilityRequirements []string
	Markdown               string
	Warnings               []string
	RollbackInstructions   string
	SafetyLevel            string
	CommandClassification  string
}

func scanCommandGroups(text string) []CommandGroup {
	out := []CommandGroup{}
	if text == "" || text == "null" {
		return out
	}
	_ = json.Unmarshal([]byte(text), &out)
	for i := range out {
		out[i].NodeID = RedactString(out[i].NodeID)
		out[i].NodeName = RedactString(out[i].NodeName)
		out[i].Role = normalizeRole(out[i].Role)
		out[i].Commands = redactStringSlice(out[i].Commands)
	}
	return out
}

func (s *Store) buildPlanArtifacts(ctx context.Context, plan Plan) planArtifacts {
	target := plan.TargetNodeID
	if target == "" {
		target = "target-node"
	}
	nodeID, nodeName, role := s.lookupNodeBrief(ctx, target)
	if nodeID == "" {
		nodeID = target
	}
	if nodeName == "" {
		nodeName = target
	}
	if role == "" {
		role = "unknown"
	}
	payload := map[string]any{}
	_ = json.Unmarshal(plan.PayloadJSON, &payload)
	commands := []string{
		fmt.Sprintf("# Leikwan Panel %s plan: %s", Version, RedactString(plan.Title)),
		"# This plan is manual-only. The agent will not execute it.",
		fmt.Sprintf("# On target node: %s", RedactString(nodeName)),
		"lq --version",
		"lq status",
		"lq doctor",
	}
	warnings := []string{
		"Plans remain manual-only; readonly tasks are separate and never execute Plan commands.",
		"Run lq status and lq doctor on the target node before making changes.",
	}
	checklist := baseChecklist()
	switch plan.Type {
	case "create_entry":
		commands = append(commands,
			"lq status --json",
			"# Manual step: open lq -> Quick setup or Public Entry A to generate/paste the entry pairing code.",
			"# TODO: follow the current Leikwan Core interactive flow; no remote change is performed here.",
		)
		checklist = append(checklist,
			"Confirm whether this is an A public entry node or B relay node before using pairing codes.",
			"Keep the return code visible until B confirms the entry is added.",
		)
	case "create_forward":
		commands = append(commands,
			"lq forward list",
			"# Manual step: open lq -> Relay Host B -> Forward Target Management -> Add forward target.",
			fmt.Sprintf("# Planned target_host: %s", payloadString(payload, "target_host")),
			fmt.Sprintf("# Planned target_port: %s", payloadString(payload, "target_port")),
			fmt.Sprintf("# Planned protocol: %s", payloadString(payload, "protocol")),
			"# TODO: run the matching lq forward add flow according to the current Core CLI/menu.",
		)
		checklist = append(checklist,
			"Confirm the entry port is unused before adding the forward.",
			"Confirm TCP/UDP expectations with the backend owner.",
		)
	case "switch_entry":
		warnings = append(warnings,
			"Switching entry may affect production traffic.",
			"Confirm snapshots and rollback path before doing anything manually.",
		)
		checklist = append(checklist,
			"Verify the new entry is online before any manual switch.",
			"Do not stop or remove the old entry first.",
			"Keep the old entry available for rollback if validation fails.",
			"Manually confirm a low-traffic maintenance window.",
		)
		commands = append(commands,
			"lq ddns overview",
			"lq forward list",
			"# Manual step only: inspect current PRIMARY/BACKUP state in lq.",
			"# Do not switch during high traffic; confirm rollback path first.",
		)
	case "ddns_check":
		commands = append(commands,
			"lq ddns overview",
			"lq status --json",
			"lq doctor --json",
			"# Manual step: review DDNS consistency and relay restart warnings locally.",
		)
	}
	group := CommandGroup{
		NodeID:   RedactString(nodeID),
		NodeName: RedactString(nodeName),
		Role:     normalizeRole(role),
		Commands: redactStringSlice(commands),
	}
	groups := []CommandGroup{group}
	checklist = redactStringSlice(checklist)
	warnings = redactStringSlice(warnings)
	requirements := capabilityRequirementsFor(plan.Type)
	classification, safety, blocked := classifyCommandGroups(groups)
	if len(blocked) > 0 {
		warnings = append(warnings, "Blocked command text was removed from generated commands.")
		groups = sanitizeCommandGroups(groups)
		classification = "blocked"
		safety = "dangerous"
	}
	preflight := s.buildPlanPreflight(ctx, plan, groups, warnings)
	if safety == "safe" && preflightOverall(preflight) != "ok" {
		safety = "caution"
	}
	return planArtifacts{
		GeneratedCommands:      flattenCommandGroups(groups),
		CommandGroups:          groups,
		Checklist:              checklist,
		Preflight:              preflight,
		CapabilityRequirements: requirements,
		Markdown:               buildPlanMarkdown(plan, warnings, groups, checklist, preflight, requirements, rollbackInstructionsForPlan(plan.Type), safety, classification),
		Warnings:               warnings,
		RollbackInstructions:   rollbackInstructionsForPlan(plan.Type),
		SafetyLevel:            normalizeSafetyLevel(safety),
		CommandClassification:  normalizeCommandClassification(classification),
	}
}

func rollbackInstructionsForPlan(planType string) string {
	lines := []string{
		"Manual rollback only. The Panel does not run rollback commands.",
		"Record the exact pre-change state, snapshot path, operator, and time before manual execution.",
	}
	switch planType {
	case "create_forward":
		lines = append(lines,
			"If the forward does not work, use the Leikwan Core interactive menu on the relay node to remove or disable only the newly added forward.",
			"If a pre-change config export or snapshot exists, inspect it and restore manually during a maintenance window.",
			"After rollback, run lq status and lq doctor locally on the relay node.")
	case "create_entry":
		lines = append(lines,
			"If the entry setup fails, keep the old entry configuration unchanged and use the Core interactive menu to disable only the new entry.",
			"Keep the old pairing/return code notes until the relay side confirms the new entry is healthy.",
			"After rollback, run lq status and lq doctor locally on the entry and relay nodes.")
	case "switch_entry":
		lines = append(lines,
			"Do not remove or stop the old entry before validating the new entry.",
			"If validation fails, keep traffic on the old entry and manually switch back in the Core menu.",
			"Perform the switch only during a low-traffic window and record the old PRIMARY/BACKUP state.")
	case "ddns_check":
		lines = append(lines,
			"If DDNS validation shows a bad change, restore the previous DNS/provider setting manually in the DNS provider or external DDNS client.",
			"Re-run lq ddns overview and lq doctor locally after DNS propagation.")
	default:
		lines = append(lines, "Review current Core state and restore manually from your own snapshot or config export.")
	}
	return RedactString(strings.Join(lines, "\n"))
}

func (s *Store) lookupNodeBrief(ctx context.Context, id string) (nodeID, nodeName, role string) {
	if id == "" {
		return "", "", ""
	}
	_ = s.db.QueryRowContext(ctx, `SELECT node_id, COALESCE(node_name, ''), COALESCE(role, 'unknown') FROM nodes WHERE node_id=? OR CAST(id AS TEXT)=?`, id, id).Scan(&nodeID, &nodeName, &role)
	return RedactString(nodeID), RedactString(nodeName), normalizeRole(role)
}

func baseChecklist() []string {
	return []string{
		"Confirm the target node and role.",
		"Run lq status before any manual change.",
		"Run lq doctor before any manual change.",
		"Confirm snapshot and rollback path.",
		"After manual execution, run lq status again.",
		"After manual execution, run lq doctor again.",
	}
}

func flattenCommandGroups(groups []CommandGroup) []string {
	out := []string{}
	for _, group := range groups {
		out = append(out, fmt.Sprintf("# On %s node: %s", normalizeRole(group.Role), RedactString(group.NodeName)))
		out = append(out, redactStringSlice(group.Commands)...)
	}
	return redactStringSlice(out)
}

func allowedReadonlyCommand(command string) bool {
	switch strings.TrimSpace(command) {
	case "lq --version", "lq status", "lq status --json", "lq doctor", "lq doctor --json", "lq forward list", "lq ddns overview":
		return true
	default:
		return false
	}
}

func blockedCommandReason(command string) string {
	lower := strings.ToLower(strings.TrimSpace(command))
	if strings.Contains(lower, "curl") && strings.Contains(lower, "|") && strings.Contains(lower, "bash") {
		return "curl | bash"
	}
	patterns := map[string]string{
		"rm ":               "rm",
		"systemctl restart": "systemctl restart",
		"systemctl stop":    "systemctl stop",
		"nft ":              "nft",
		"iptables":          "iptables",
		"ip route":          "ip route",
		"curl | bash":       "curl | bash",
		"curl|bash":         "curl | bash",
		"bash -c":           "bash -c",
		"eval ":             "eval",
		"> /etc":            "write into /etc",
		">/etc":             "write into /etc",
		"tee /etc":          "write into /etc",
	}
	for needle, reason := range patterns {
		if strings.Contains(lower, needle) {
			return reason
		}
	}
	if lower == "rm" || strings.HasPrefix(lower, "rm -") {
		return "rm"
	}
	if strings.HasPrefix(lower, "nft") {
		return "nft"
	}
	if strings.HasPrefix(lower, "eval") {
		return "eval"
	}
	return ""
}

func classifyCommandGroups(groups []CommandGroup) (classification, safety string, blocked []string) {
	classification = "readonly"
	safety = "safe"
	for _, group := range groups {
		for _, command := range group.Commands {
			text := strings.TrimSpace(command)
			if text == "" {
				continue
			}
			if reason := blockedCommandReason(text); reason != "" {
				blocked = append(blocked, fmt.Sprintf("%s: %s", reason, RedactString(text)))
				classification = "blocked"
				safety = "dangerous"
				continue
			}
			if strings.HasPrefix(text, "#") {
				if classification != "blocked" {
					classification = "manual"
				}
				if safety == "safe" {
					safety = "caution"
				}
				continue
			}
			if !allowedReadonlyCommand(text) {
				if classification != "blocked" {
					classification = "manual"
				}
				if safety == "safe" {
					safety = "caution"
				}
			}
		}
	}
	return classification, safety, redactStringSlice(blocked)
}

func sanitizeCommandGroups(groups []CommandGroup) []CommandGroup {
	out := make([]CommandGroup, 0, len(groups))
	for _, group := range groups {
		clean := group
		clean.Commands = []string{}
		for _, command := range group.Commands {
			if blockedCommandReason(command) == "" {
				clean.Commands = append(clean.Commands, RedactString(command))
			}
		}
		out = append(out, clean)
	}
	return out
}

func capabilityRequirementsFor(planType string) []string {
	requirements := []string{"lq --version", "lq status", "lq doctor"}
	switch planType {
	case "create_forward", "switch_entry":
		requirements = append(requirements, "lq forward list")
	}
	switch planType {
	case "switch_entry", "ddns_check":
		requirements = append(requirements, "lq ddns overview", "lq status --json", "lq doctor --json")
	}
	return redactStringSlice(requirements)
}

func (s *Store) buildPlanPreflight(ctx context.Context, plan Plan, groups []CommandGroup, warnings []string) json.RawMessage {
	checks := []map[string]any{}
	add := func(name string, ok bool, level, message string) {
		checks = append(checks, map[string]any{
			"name":    RedactString(name),
			"ok":      ok,
			"level":   RedactString(level),
			"message": RedactString(message),
		})
	}
	targetSelected := strings.TrimSpace(plan.TargetNodeID) != ""
	add("target node selected", targetSelected, levelFor(targetSelected), selectedMessage(targetSelected))
	node, found, _ := s.GetNode(ctx, plan.TargetNodeID)
	add("target node exists", found, levelFor(found), nodeFoundMessage(found))
	online := found && node.Status == "online"
	add("target node online", online, levelFor(online), fmt.Sprintf("status=%s", RedactString(node.Status)))
	roleOK := !found || roleMatchesPlan(plan.Type, node.Role)
	add("target node role matches plan", roleOK, levelFor(roleOK), fmt.Sprintf("role=%s plan=%s", RedactString(node.Role), RedactString(plan.Type)))
	_, _, blocked := classifyCommandGroups(groups)
	add("plan contains no blocked command", len(blocked) == 0, levelFor(len(blocked) == 0), strings.Join(blocked, "; "))
	markdownGenerated := strings.TrimSpace(plan.Markdown) != "" || len(groups) > 0
	add("markdown generated", markdownGenerated, levelFor(markdownGenerated), "manual guide available")
	add("warnings reviewed", len(warnings) == 0, "info", fmt.Sprintf("warnings=%d", len(warnings)))
	overall := "ok"
	for _, check := range checks {
		if ok, _ := check["ok"].(bool); !ok {
			overall = "warn"
			break
		}
	}
	raw, _ := json.Marshal(RedactValue(map[string]any{
		"overall": overall,
		"checks":  checks,
	}))
	return json.RawMessage(raw)
}

func dryRunActionsForPlan(planType string) []string {
	switch planType {
	case "create_forward":
		return []string{"run_status_json", "run_doctor_json", "list_forwards"}
	case "switch_entry":
		return []string{"run_status_json", "run_doctor_json", "list_forwards", "ddns_overview"}
	case "create_entry":
		return []string{"run_status_json", "run_doctor_json", "ddns_overview"}
	case "ddns_check":
		return []string{"ddns_overview", "run_doctor_json"}
	default:
		return nil
	}
}

func dryRunReport(status, recommendation string, extra map[string]any) json.RawMessage {
	payload := map[string]any{
		"status":         normalizeDryRunStatus(status),
		"recommendation": RedactString(recommendation),
	}
	for k, v := range extra {
		payload[k] = RedactValue(v)
	}
	raw, _ := json.Marshal(RedactValue(payload))
	return json.RawMessage(raw)
}

func snapshotReady(plan Plan) bool {
	switch normalizeSnapshotPolicy(plan.SnapshotPolicy) {
	case "not_required":
		return true
	case "recommended":
		return plan.SnapshotStatus == "recorded" || plan.SnapshotStatus == "verified" || strings.TrimSpace(plan.SnapshotRef) != ""
	case "required":
		return plan.SnapshotStatus == "recorded" || plan.SnapshotStatus == "verified"
	default:
		return false
	}
}

func rollbackReady(plan Plan) bool {
	if strings.TrimSpace(plan.RollbackInstructions) == "" {
		return false
	}
	if plan.SnapshotRequired {
		return plan.RollbackAvailable || strings.TrimSpace(plan.RollbackRef) != "" || strings.TrimSpace(plan.RollbackNote) != ""
	}
	return true
}

func buildSafetyGate(plan Plan) SafetyGateResponse {
	return buildSafetyGateWithEvidence(plan, 0)
}

func buildSafetyGateWithEvidence(plan Plan, evidenceCount int) SafetyGateResponse {
	review := buildActionReview(plan)
	gate := SafetyGateResponse{
		PlanID:                     plan.ID,
		DryRunPassed:               plan.DryRunStatus == "passed",
		ApprovalReady:              plan.SafetyLevel != "dangerous" && plan.CommandClassification != "blocked",
		SnapshotReady:              snapshotReady(plan),
		RollbackReady:              rollbackReady(plan),
		MetadataActionsReady:       true,
		EvidenceCount:              evidenceCount,
		ManualExecutionRecorded:    strings.TrimSpace(plan.ExecutedAt) != "" || plan.ExecutionStatus == "succeeded" || plan.ExecutionStatus == "running_manually",
		ManualVerificationRecorded: strings.TrimSpace(plan.VerifiedAt) != "" || plan.VerificationStatus == "passed" || plan.VerificationStatus == "warning" || plan.VerificationStatus == "failed",
		Overall:                    "ready",
		ActionReview:               &review,
	}
	if !gate.DryRunPassed {
		gate.BlockedReasons = append(gate.BlockedReasons, "dry-run has not passed")
	}
	if !gate.ApprovalReady {
		gate.BlockedReasons = append(gate.BlockedReasons, "plan is dangerous or contains blocked command text")
	}
	switch plan.SnapshotPolicy {
	case "required":
		if !gate.SnapshotReady {
			gate.BlockedReasons = append(gate.BlockedReasons, "required snapshot metadata is missing")
		}
		if !gate.RollbackReady {
			gate.BlockedReasons = append(gate.BlockedReasons, "required rollback metadata is missing")
		}
	case "recommended":
		if !gate.SnapshotReady {
			gate.Warnings = append(gate.Warnings, "snapshot is recommended but not recorded")
		}
		if !gate.RollbackReady {
			gate.Warnings = append(gate.Warnings, "rollback information is recommended but not recorded")
		}
	}
	if plan.DryRunStatus == "warning" {
		gate.Warnings = append(gate.Warnings, "dry-run completed with warnings")
	}
	if plan.VerificationStatus == "failed" {
		gate.BlockedReasons = append(gate.BlockedReasons, "last verification failed")
	}
	if len(gate.BlockedReasons) > 0 {
		gate.Overall = "blocked"
	} else if len(gate.Warnings) > 0 {
		gate.Overall = "warning"
	}
	gate.BlockedReasons = redactStringSlice(gate.BlockedReasons)
	gate.Warnings = redactStringSlice(gate.Warnings)
	return gate
}

func (s *Store) buildDryRunReport(ctx context.Context, plan Plan, tasks []Task) (string, json.RawMessage) {
	node, found, _ := s.GetNode(ctx, plan.TargetNodeID)
	taskSummaries := []map[string]any{}
	pending := 0
	failed := 0
	warnings := []string{}
	doctorWarnings := []string{}
	for _, task := range tasks {
		if task.Status == "queued" || task.Status == "picked" {
			pending++
		}
		if task.Status == "failed" || task.Status == "expired" || task.Status == "canceled" || task.Status == "rejected" {
			failed++
		}
		stdoutLower := strings.ToLower(task.ResultStdout)
		if task.Action == "run_doctor_json" {
			doctorWarnings = append(doctorWarnings, extractDoctorWarnings(task.ResultStdout)...)
			if strings.Contains(stdoutLower, `"overall":"warn"`) || strings.Contains(stdoutLower, `"overall":"fail"`) || strings.Contains(stdoutLower, `"overall":"failed"`) {
				warnings = append(warnings, "doctor reported non-OK overall")
			}
		}
		if task.Action == "list_forwards" && task.Status == "succeeded" && strings.TrimSpace(task.ResultStdout) == "" {
			warnings = append(warnings, "forward list succeeded but returned empty output")
		}
		if task.Action == "ddns_overview" && task.Status == "succeeded" && strings.TrimSpace(task.ResultStdout) == "" {
			warnings = append(warnings, "ddns overview succeeded but returned empty output")
		}
		taskSummaries = append(taskSummaries, map[string]any{
			"id":        task.ID,
			"action":    task.Action,
			"status":    task.Status,
			"exit_code": task.ExitCode,
			"error":     task.Error,
		})
	}
	if !found {
		warnings = append(warnings, "target node has not reported yet")
	} else if node.Status != "online" {
		warnings = append(warnings, "target node status="+node.Status)
	}
	artifacts := s.buildPlanArtifacts(ctx, plan)
	if strings.TrimSpace(plan.RollbackInstructions) == "" {
		plan.RollbackInstructions = artifacts.RollbackInstructions
	}
	_, _, blocked := classifyCommandGroups(artifacts.CommandGroups)
	if len(blocked) > 0 {
		warnings = append(warnings, "blocked command detected in plan artifacts")
	}
	status := "passed"
	recommendation := "readonly dry-run passed; review the manual plan before any SSH execution"
	if pending > 0 {
		status = "running"
		recommendation = "waiting for readonly Agent tasks to finish"
	} else if failed > 0 {
		status = "failed"
		recommendation = "fix failed readonly checks before manual execution"
	} else if len(warnings) > 0 || len(doctorWarnings) > 0 {
		status = "warning"
		recommendation = "review warnings before manual execution"
	}
	report := dryRunReport(status, recommendation, map[string]any{
		"plan_id":                  plan.ID,
		"plan_type":                plan.Type,
		"target_node_id":           plan.TargetNodeID,
		"node_status":              node.Status,
		"node_found":               found,
		"capabilities_satisfied":   dryRunCapabilitiesSatisfied(plan, node),
		"snapshot_policy":          plan.SnapshotPolicy,
		"snapshot_status":          plan.SnapshotStatus,
		"snapshot_ready":           snapshotReady(plan),
		"rollback_available":       plan.RollbackAvailable,
		"rollback_ref":             plan.RollbackRef,
		"rollback_instructions":    strings.TrimSpace(plan.RollbackInstructions) != "",
		"rollback_ready":           rollbackReady(plan),
		"doctor_warnings":          doctorWarnings,
		"warnings":                 warnings,
		"forward_list_readable":    taskSucceeded(tasks, "list_forwards"),
		"ddns_overview_readable":   taskSucceeded(tasks, "ddns_overview"),
		"blocked_commands_present": len(blocked) > 0,
		"tasks":                    taskSummaries,
	})
	return status, report
}

func extractDoctorWarnings(text string) []string {
	warnings := []string{}
	var doc map[string]any
	if err := json.Unmarshal([]byte(text), &doc); err != nil {
		if strings.Contains(strings.ToLower(text), "warn") {
			return []string{"doctor output contains warning text"}
		}
		return warnings
	}
	if list, ok := doc["warnings"].([]any); ok {
		for _, item := range list {
			if s, ok := item.(string); ok && strings.TrimSpace(s) != "" && strings.ToLower(s) != "none" {
				warnings = append(warnings, RedactString(s))
			}
		}
	}
	if overall, ok := doc["overall"].(string); ok && strings.ToLower(overall) != "ok" {
		warnings = append(warnings, "doctor overall="+RedactString(overall))
	}
	return warnings
}

func taskSucceeded(tasks []Task, action string) bool {
	for _, task := range tasks {
		if task.Action == action && task.Status == "succeeded" {
			return true
		}
	}
	return false
}

func dryRunCapabilitiesSatisfied(plan Plan, node Node) bool {
	if node.NodeID == "" {
		return false
	}
	caps := node.Capabilities
	if !caps.LQAvailable {
		return false
	}
	if !caps.SupportsStatusJSON || !caps.SupportsDoctorJSON {
		return false
	}
	switch plan.Type {
	case "create_forward", "switch_entry":
		if !caps.SupportsForwardList {
			return false
		}
	}
	switch plan.Type {
	case "create_entry", "switch_entry", "ddns_check":
		if !caps.SupportsDDNSOverview {
			return false
		}
	}
	return true
}

func levelFor(ok bool) string {
	if ok {
		return "info"
	}
	return "warn"
}

func selectedMessage(ok bool) string {
	if ok {
		return "target node selected"
	}
	return "target node is required"
}

func nodeFoundMessage(ok bool) string {
	if ok {
		return "target node is known to Controller"
	}
	return "target node has not reported yet"
}

func roleMatchesPlan(planType, role string) bool {
	role = normalizeRole(role)
	switch planType {
	case "create_forward", "switch_entry", "ddns_check":
		return role == "relay" || role == "mixed" || role == "unknown"
	case "create_entry":
		return role == "entry" || role == "mixed" || role == "unknown"
	default:
		return true
	}
}

func preflightOverall(raw json.RawMessage) string {
	var data map[string]any
	if err := json.Unmarshal(raw, &data); err != nil {
		return "warn"
	}
	if overall, ok := data["overall"].(string); ok {
		return overall
	}
	return "warn"
}

func buildPlanMarkdown(plan Plan, warnings []string, groups []CommandGroup, checklist []string, preflight json.RawMessage, requirements []string, rollbackInstructions, safety, classification string) string {
	var b strings.Builder
	b.WriteString("# Leikwan Plan Manual Execution Guide\n\n")
	b.WriteString("This plan is manual-only. The agent will not execute it.\n\n")
	b.WriteString(fmt.Sprintf("- Version: %s\n", Version))
	b.WriteString(fmt.Sprintf("- Plan: %s\n", RedactString(plan.Title)))
	b.WriteString(fmt.Sprintf("- Type: %s\n", RedactString(plan.Type)))
	b.WriteString(fmt.Sprintf("- Snapshot policy: %s\n", normalizeSnapshotPolicy(plan.SnapshotPolicy)))
	b.WriteString(fmt.Sprintf("- Snapshot status: %s\n", normalizeSnapshotStatus(plan.SnapshotStatus)))
	b.WriteString(fmt.Sprintf("- Safety level: %s\n", normalizeSafetyLevel(safety)))
	b.WriteString(fmt.Sprintf("- Command classification: %s\n", normalizeCommandClassification(classification)))
	b.WriteString(fmt.Sprintf("- Target node: %s\n", RedactString(plan.TargetNodeID)))
	b.WriteString(fmt.Sprintf("- Execution status: %s\n\n", normalizeExecutionStatus(plan.ExecutionStatus)))
	b.WriteString("## Warnings\n\n")
	if len(warnings) == 0 {
		b.WriteString("- None\n")
	} else {
		for _, warning := range warnings {
			b.WriteString(fmt.Sprintf("- %s\n", RedactString(warning)))
		}
	}
	b.WriteString("\n## Checklist\n\n")
	for _, item := range checklist {
		b.WriteString(fmt.Sprintf("- [ ] %s\n", RedactString(item)))
	}
	b.WriteString("\n## Capability Requirements\n\n")
	for _, item := range requirements {
		b.WriteString(fmt.Sprintf("- %s\n", RedactString(item)))
	}
	b.WriteString("\n## Snapshot / Rollback\n\n")
	b.WriteString("Beta.1 records manual snapshot and rollback metadata only. It does not create snapshots and does not run rollback.\n\n")
	if strings.TrimSpace(rollbackInstructions) == "" {
		b.WriteString("- No rollback instructions generated yet.\n")
	} else {
		for _, line := range strings.Split(RedactString(rollbackInstructions), "\n") {
			if strings.TrimSpace(line) != "" {
				b.WriteString(fmt.Sprintf("- %s\n", line))
			}
		}
	}
	b.WriteString("\n## Preflight\n\n")
	b.WriteString("```json\n")
	if len(preflight) == 0 {
		b.WriteString("{}\n")
	} else {
		b.WriteString(string(RedactJSONBytes(preflight)))
		b.WriteByte('\n')
	}
	b.WriteString("```\n")
	b.WriteString("\n## Commands\n\n")
	for _, group := range groups {
		b.WriteString(fmt.Sprintf("### %s (%s)\n\n", RedactString(group.NodeName), normalizeRole(group.Role)))
		b.WriteString("```bash\n")
		for _, cmd := range group.Commands {
			b.WriteString(RedactString(cmd))
			b.WriteByte('\n')
		}
		b.WriteString("```\n\n")
	}
	b.WriteString("## Payload\n\n")
	b.WriteString("```json\n")
	if len(plan.PayloadJSON) == 0 {
		b.WriteString("{}\n")
	} else {
		b.WriteString(string(RedactJSONBytes(plan.PayloadJSON)))
		b.WriteByte('\n')
	}
	b.WriteString("```\n")
	return RedactString(b.String())
}

func payloadString(payload map[string]any, key string) string {
	if v, ok := payload[key]; ok {
		return RedactString(fmt.Sprint(v))
	}
	return "-"
}

func redactStringSlice(in []string) []string {
	out := make([]string, 0, len(in))
	for _, item := range in {
		out = append(out, RedactString(item))
	}
	return out
}
