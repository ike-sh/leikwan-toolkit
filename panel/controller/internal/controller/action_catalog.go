package controller

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
)

const writeExecutionDisabledReason = "node write execution is limited to fixed 3.0.0-alpha.2 allowlisted actions; arbitrary command dispatch remains disabled"

func actionCatalogDefinitions() []ActionDefinition {
	readonlyCaps := []string{"lq --version", "lq status", "lq doctor"}
	futureBaseGates := []string{"dry-run", "approval", "snapshot", "rollback", "verification"}
	return []ActionDefinition{
		{
			Action:               "probe_core_version",
			Title:                "Probe Core version",
			Category:             "readonly",
			RiskLevel:            "low",
			Description:          "Readonly task mapped to lq --version.",
			RequiredCapabilities: []string{"lq --version"},
			Enabled:              true,
		},
		{
			Action:               "run_status",
			Title:                "Run status",
			Category:             "readonly",
			RiskLevel:            "low",
			Description:          "Readonly task mapped to lq status.",
			RequiredCapabilities: []string{"lq status"},
			Enabled:              true,
		},
		{
			Action:               "run_status_json",
			Title:                "Run status JSON",
			Category:             "readonly",
			RiskLevel:            "low",
			Description:          "Readonly task mapped to lq status --json.",
			RequiredCapabilities: []string{"lq status --json"},
			Enabled:              true,
		},
		{
			Action:               "run_doctor",
			Title:                "Run doctor",
			Category:             "readonly",
			RiskLevel:            "low",
			Description:          "Readonly task mapped to lq doctor.",
			RequiredCapabilities: []string{"lq doctor"},
			Enabled:              true,
		},
		{
			Action:               "run_doctor_json",
			Title:                "Run doctor JSON",
			Category:             "readonly",
			RiskLevel:            "low",
			Description:          "Readonly task mapped to lq doctor --json.",
			RequiredCapabilities: []string{"lq doctor --json"},
			Enabled:              true,
		},
		{
			Action:               "list_forwards",
			Title:                "List forwards",
			Category:             "readonly",
			RiskLevel:            "low",
			Description:          "Readonly task mapped to lq forward list.",
			RequiredCapabilities: []string{"lq forward list"},
			Enabled:              true,
		},
		{
			Action:               "ddns_overview",
			Title:                "DDNS overview",
			Category:             "readonly",
			RiskLevel:            "low",
			Description:          "Readonly task mapped to lq ddns overview.",
			RequiredCapabilities: []string{"lq ddns overview"},
			Enabled:              true,
		},
		readonlyAction("node_status", "Node status", "Readonly Agent status summary."),
		readonlyAction("easytier_status", "EasyTier status", "Readonly systemctl is-active check for leikwan-easytier."),
		readonlyAction("nftables_status", "nftables status", "Readonly nftables ruleset/config check."),
		readonlyAction("pbr_status", "PBR status", "Readonly ip rule status check."),
		readonlyAction("ddns_status", "DDNS status", "Readonly Agent DDNS config/status check."),
		readonlyAction("list_entries", "List entries", "Readonly Panel-managed entry config check."),
		readonlyAction("verify_config", "Verify config", "Readonly Agent config verification."),
		{
			Action:                "create_entry",
			Title:                 "Create public entry",
			Category:              "future_write_guarded",
			RiskLevel:             "high",
			Description:           "Future guarded write action for adding a public entry. Disabled in 3.0.0-alpha.2; Web apply uses fixed lower-level actions instead.",
			RequiredGates:         append([]string(nil), futureBaseGates...),
			RequiredCapabilities:  append([]string(nil), readonlyCaps...),
			RollbackRequired:      true,
			SnapshotRequired:      true,
			ApprovalRequired:      true,
			NodeMutation:          true,
			AgentRequired:         true,
			OperatorTokenRequired: true,
		},
		{
			Action:                "create_forward",
			Title:                 "Create forward target",
			Category:              "future_write_guarded",
			RiskLevel:             "medium",
			Description:           "Future guarded write action for adding a forward target. Disabled in 3.0.0-alpha.2; Web apply uses fixed lower-level actions instead.",
			RequiredGates:         append([]string(nil), futureBaseGates...),
			RequiredCapabilities:  []string{"lq status", "lq doctor", "lq forward list"},
			RollbackRequired:      true,
			SnapshotRequired:      true,
			ApprovalRequired:      true,
			NodeMutation:          true,
			AgentRequired:         true,
			OperatorTokenRequired: true,
		},
		{
			Action:                "switch_entry",
			Title:                 "Switch primary entry",
			Category:              "future_write_dangerous",
			RiskLevel:             "critical",
			Description:           "Future dangerous write action for changing PRIMARY/BACKUP entry state. Disabled in 3.0.0-alpha.2.",
			RequiredGates:         append([]string(nil), futureBaseGates...),
			RequiredCapabilities:  []string{"lq status", "lq doctor", "lq forward list", "lq ddns overview"},
			RollbackRequired:      true,
			SnapshotRequired:      true,
			ApprovalRequired:      true,
			NodeMutation:          true,
			AgentRequired:         true,
			OperatorTokenRequired: true,
		},
		{
			Action:                "update_ddns_config",
			Title:                 "Update DDNS config",
			Category:              "future_write_low",
			RiskLevel:             "medium",
			Description:           "Future guarded write action for changing DDNS configuration. Disabled in 3.0.0-alpha.2.",
			RequiredGates:         append([]string(nil), futureBaseGates...),
			RequiredCapabilities:  []string{"lq ddns overview", "lq doctor"},
			RollbackRequired:      true,
			SnapshotRequired:      true,
			ApprovalRequired:      true,
			NodeMutation:          true,
			AgentRequired:         true,
			OperatorTokenRequired: true,
		},
		{
			Action:                "rollback_config",
			Title:                 "Rollback configuration",
			Category:              "future_write_dangerous",
			RiskLevel:             "critical",
			Description:           "Future dangerous action for restoring prior configuration. Disabled in 3.0.0-alpha.2.",
			RequiredGates:         []string{"dry-run", "approval", "snapshot", "rollback", "verification"},
			RequiredCapabilities:  readonlyCaps,
			RollbackRequired:      true,
			SnapshotRequired:      true,
			ApprovalRequired:      true,
			NodeMutation:          true,
			AgentRequired:         true,
			OperatorTokenRequired: true,
		},
		{
			Action:                "restart_relay",
			Title:                 "Restart relay",
			Category:              "future_write_dangerous",
			RiskLevel:             "high",
			Description:           "Future dangerous action for restarting EasyTier relay. Disabled in 3.0.0-alpha.2.",
			RequiredGates:         []string{"dry-run", "approval", "snapshot", "rollback", "verification", "maintenance-window"},
			RequiredCapabilities:  readonlyCaps,
			RollbackRequired:      true,
			SnapshotRequired:      true,
			ApprovalRequired:      true,
			NodeMutation:          true,
			AgentRequired:         true,
			OperatorTokenRequired: true,
		},
		alphaWriteAction("configure_node_role", "Configure node role", "Fixed Agent action that writes Panel-managed role metadata."),
		alphaWriteAction("apply_network_profile", "Apply network profile", "Fixed Agent action used by legacy alpha apply flows."),
		alphaWriteAction("apply_entry_config", "Apply entry config", "Fixed Agent action used by legacy alpha apply flows."),
		alphaWriteAction("apply_forward_config", "Apply forward config", "Fixed Agent action used by legacy alpha apply flows."),
		alphaWriteAction("reload_leikwan_core", "Reload Leikwan Core verification", "Fixed Agent action that runs readonly validation only."),
		alphaWriteAction("verify_applied_config", "Verify applied config", "Fixed Agent action that verifies Panel-managed config files exist."),
		alphaWriteAction("install_easytier", "Install EasyTier", "Fixed Agent action that detects or prepares EasyTier installation state."),
		alphaWriteAction("configure_easytier_network", "Configure EasyTier network", "Fixed Agent action that writes /etc/leikwan-agent/easytier/config.json and systemd service."),
		alphaWriteAction("start_easytier", "Start EasyTier", "Fixed Agent action mapped to systemctl start leikwan-easytier."),
		alphaWriteAction("restart_easytier", "Restart EasyTier", "Fixed Agent action mapped to systemctl restart leikwan-easytier."),
		alphaWriteAction("stop_easytier", "Stop EasyTier", "Fixed Agent action mapped to systemctl stop leikwan-easytier."),
		alphaWriteAction("apply_entry_ports", "Apply entry ports", "Fixed Agent action that writes Panel nftables entry rules."),
		alphaWriteAction("apply_forward_rules", "Apply forward rules", "Fixed Agent action that writes Panel nftables forward rules."),
		alphaWriteAction("apply_pbr_rules", "Apply PBR rules", "Fixed Agent action that validates PBR payload and applies ip rule/ip route argv."),
		alphaWriteAction("apply_ddns_config", "Apply DDNS config", "Fixed Agent action that writes /etc/leikwan-agent/ddns/config.json."),
		alphaWriteAction("ddns_sync_now", "Sync DDNS now", "Fixed Agent action that syncs supported DDNS providers."),
		alphaWriteAction("reload_firewall_rules", "Reload firewall rules", "Fixed Agent action mapped to nft -f Panel config."),
		alphaWriteAction("restart_agent", "Restart Agent", "Fixed Agent action mapped to systemctl restart leikwan-agent."),
		alphaWriteAction("reboot_node", "Reboot node", "Fixed Agent action mapped to reboot and requires confirm=REBOOT."),
		metadataAction("record_snapshot_ref", "Record snapshot reference", "Controller-only metadata action that records a manual snapshot reference on a Plan."),
		metadataAction("record_rollback_ref", "Record rollback reference", "Controller-only metadata action that records manual rollback information on a Plan."),
		metadataAction("mark_plan_executed", "Mark Plan manually executed", "Controller-only metadata action that records manual execution state."),
		metadataAction("mark_plan_verified", "Mark Plan manually verified", "Controller-only metadata action that records manual verification state."),
		metadataAction("attach_manual_evidence", "Attach manual evidence", "Controller-only metadata action that stores redacted manual evidence on a Plan."),
		blockedAction("arbitrary_command", "Arbitrary command", "Controller never accepts arbitrary command strings."),
		blockedAction("shell_c", "shell -c", "Executing shell -c is permanently blocked."),
		blockedAction("bash_c", "bash -c", "Executing bash -c is permanently blocked."),
		blockedAction("eval", "eval", "eval is permanently blocked."),
		blockedAction("raw_nft", "Raw nft", "Raw nft commands are permanently blocked."),
		blockedAction("raw_iptables", "Raw iptables", "Raw iptables commands are permanently blocked."),
		blockedAction("raw_ip_route", "Raw ip route", "Raw ip route commands are permanently blocked."),
		blockedAction("rm", "rm", "Destructive file removal is permanently blocked."),
		blockedAction("write_etc", "Write /etc", "Direct writes to /etc are permanently blocked."),
		blockedAction("curl_pipe_bash", "curl pipe bash", "curl | bash style execution is permanently blocked."),
	}
}

func readonlyAction(action, title, description string) ActionDefinition {
	return ActionDefinition{
		Action:      action,
		Title:       title,
		Category:    "readonly",
		RiskLevel:   "low",
		Description: description,
		Enabled:     true,
	}
}

func blockedAction(action, title, description string) ActionDefinition {
	return ActionDefinition{
		Action:      action,
		Title:       title,
		Category:    "blocked",
		RiskLevel:   "critical",
		Description: description,
		Enabled:     false,
	}
}

func metadataAction(action, title, description string) ActionDefinition {
	return ActionDefinition{
		Action:                action,
		Title:                 title,
		Category:              "metadata_write",
		RiskLevel:             "low",
		Description:           description,
		RequiredGates:         []string{"operator-auth", "redaction", "audit-timeline"},
		RequiredCapabilities:  []string{"controller-db"},
		ApprovalRequired:      true,
		NodeMutation:          false,
		AgentRequired:         false,
		CommandDispatch:       false,
		OperatorTokenRequired: true,
		Enabled:               true,
	}
}

func alphaWriteAction(action, title, description string) ActionDefinition {
	return ActionDefinition{
		Action:                action,
		Title:                 title,
		Category:              "alpha_write",
		RiskLevel:             "medium",
		Description:           description + " Enabled only for nodes that report enable_write_actions=true.",
		RequiredGates:         []string{"operator-auth", "agent-write-enabled", "fixed-action-allowlist", "redaction"},
		RequiredCapabilities:  []string{"agent enable_write_actions=true"},
		ApprovalRequired:      true,
		NodeMutation:          true,
		AgentRequired:         true,
		CommandDispatch:       false,
		OperatorTokenRequired: true,
		Enabled:               true,
	}
}

func planTypeToFutureAction(planType string) string {
	switch planType {
	case "create_entry":
		return "create_entry"
	case "create_forward":
		return "create_forward"
	case "switch_entry":
		return "switch_entry"
	case "ddns_check":
		return "update_ddns_config"
	default:
		return "arbitrary_command"
	}
}

func lookupActionDefinition(action string) (ActionDefinition, bool) {
	for _, def := range actionCatalogDefinitions() {
		if def.Action == action {
			return redactActionDefinition(def), true
		}
	}
	return ActionDefinition{}, false
}

func redactActionDefinition(def ActionDefinition) ActionDefinition {
	def.Action = RedactString(def.Action)
	def.Title = RedactString(def.Title)
	def.Category = RedactString(def.Category)
	def.RiskLevel = RedactString(def.RiskLevel)
	def.Description = RedactString(def.Description)
	def.RequiredGates = redactStringSlice(def.RequiredGates)
	def.RequiredCapabilities = redactStringSlice(def.RequiredCapabilities)
	return def
}

func (s *Store) ActionCatalog(ctx context.Context) []ActionDefinition {
	_ = ctx
	defs := actionCatalogDefinitions()
	out := make([]ActionDefinition, 0, len(defs))
	for _, def := range defs {
		out = append(out, redactActionDefinition(def))
	}
	return out
}

func (s *Store) ActionDefinition(ctx context.Context, action string) (ActionDefinition, error) {
	_ = ctx
	def, ok := lookupActionDefinition(strings.TrimSpace(action))
	if !ok {
		return ActionDefinition{}, sql.ErrNoRows
	}
	return def, nil
}

func (s *Store) PlanActionReview(ctx context.Context, id int64) (ActionReviewResponse, error) {
	plan, err := s.GetPlan(ctx, id)
	if err != nil {
		return ActionReviewResponse{}, err
	}
	return buildActionReview(plan), nil
}

func buildActionReview(plan Plan) ActionReviewResponse {
	actionName := planTypeToFutureAction(plan.Type)
	def, ok := lookupActionDefinition(actionName)
	if !ok {
		def, _ = lookupActionDefinition("arbitrary_command")
	}
	missing := missingActionGates(plan, def.RequiredGates)
	review := ActionReviewResponse{
		PlanID:                  plan.ID,
		PlanType:                RedactString(plan.Type),
		MatchedAction:           RedactString(def.Action),
		Category:                RedactString(def.Category),
		RiskLevel:               RedactString(def.RiskLevel),
		RequiredGates:           redactStringSlice(def.RequiredGates),
		RequiredCapabilities:    redactStringSlice(def.RequiredCapabilities),
		MissingGates:            redactStringSlice(missing),
		ReadyForFutureExecution: false,
		Reason:                  writeExecutionDisabledReason,
		Enabled:                 def.Enabled,
	}
	return review
}

func missingActionGates(plan Plan, required []string) []string {
	missing := []string{}
	has := func(name string) bool {
		for _, gate := range required {
			if gate == name {
				return true
			}
		}
		return false
	}
	if has("dry-run") && plan.DryRunStatus != "passed" {
		missing = append(missing, "dry-run")
	}
	if has("approval") {
		missing = append(missing, "approval")
	}
	if has("snapshot") && !snapshotReady(plan) {
		missing = append(missing, "snapshot")
	}
	if has("rollback") && !rollbackReady(plan) {
		missing = append(missing, "rollback")
	}
	if has("verification") && plan.VerificationStatus != "passed" {
		missing = append(missing, "verification")
	}
	if has("maintenance-window") {
		missing = append(missing, "maintenance-window")
	}
	return missing
}

func (s *Store) ActionReviewSummary(ctx context.Context, plan Plan) string {
	review, err := s.PlanActionReview(ctx, plan.ID)
	if err != nil {
		return ""
	}
	return fmt.Sprintf("future action %s is %s: %s", review.MatchedAction, review.Category, review.Reason)
}
