package controller

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
)

type Server struct {
	store         *Store
	agentToken    string
	operatorToken string
	strictAuth    bool
	log           *log.Logger
}

func NewServer(store *Store, token string, logger *log.Logger) http.Handler {
	return NewServerWithAuth(store, ServerOptions{AgentToken: token}, logger)
}

func NewServerWithAuth(store *Store, opts ServerOptions, logger *log.Logger) http.Handler {
	if logger == nil {
		logger = log.Default()
	}
	s := &Server{store: store, agentToken: opts.AgentToken, operatorToken: opts.OperatorToken, strictAuth: opts.StrictAuth, log: logger}
	mux := http.NewServeMux()
	mux.HandleFunc("/api/v1/health", s.handleHealth)
	mux.HandleFunc("/api/v1/login", s.handleLogin)
	mux.HandleFunc("/api/v1/logout", s.handleLogout)
	mux.HandleFunc("/api/v1/me", s.handleMe)
	mux.HandleFunc("/api/v1/auth/status", s.handleAuthStatus)
	mux.HandleFunc("/api/v1/capabilities", s.handleCapabilities)
	mux.HandleFunc("/api/v1/action-catalog", s.handleActionCatalog)
	mux.HandleFunc("/api/v1/action-catalog/", s.handleActionCatalog)
	mux.HandleFunc("/api/v1/bootstrap/controller-info", s.handleBootstrapControllerInfo)
	mux.HandleFunc("/api/v1/bootstrap/agent-install-command", s.handleBootstrapAgentInstallCommand)
	mux.HandleFunc("/api/v1/bootstrap/agent-token", s.handleBootstrapAgentToken)
	mux.HandleFunc("/api/v1/bootstrap/agent-command", s.handleBootstrapAgentCommand)
	mux.HandleFunc("/api/v1/topology", s.handleTopology)
	mux.HandleFunc("/api/v1/network-profiles", s.handleNetworkProfiles)
	mux.HandleFunc("/api/v1/network-profiles/", s.handleNetworkProfileByID)
	mux.HandleFunc("/api/v1/plans", s.handlePlans)
	mux.HandleFunc("/api/v1/plans/", s.handlePlanByID)
	mux.HandleFunc("/api/v1/tasks", s.handleTasks)
	mux.HandleFunc("/api/v1/tasks/", s.handleTaskByID)
	mux.HandleFunc("/api/v1/agent/tasks", s.handleAgentTasks)
	mux.HandleFunc("/api/v1/agent/tasks/", s.handleAgentTaskByID)
	mux.HandleFunc("/api/v1/agent/register", s.handleRegister)
	mux.HandleFunc("/api/v1/agent/report", s.handleReport)
	mux.HandleFunc("/api/v1/nodes", s.handleNodes)
	mux.HandleFunc("/api/v1/nodes/", s.handleNodeByID)
	mux.HandleFunc("/api/v1/entries", s.handleEntries)
	mux.HandleFunc("/api/v1/entries/", s.handleEntryByID)
	mux.HandleFunc("/api/v1/forwards", s.handleForwards)
	mux.HandleFunc("/api/v1/forwards/", s.handleForwardByID)
	mux.HandleFunc("/api/v1/pbr-policies", s.handlePBRPolicies)
	mux.HandleFunc("/api/v1/pbr-policies/", s.handlePBRPolicyByID)
	mux.HandleFunc("/api/v1/ddns-profiles", s.handleDDNSProfiles)
	mux.HandleFunc("/api/v1/ddns-profiles/", s.handleDDNSProfileByID)
	mux.HandleFunc("/api/v1/events", s.handleEvents)
	return withCORS(s.withReadAuth(mux))
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, OPTIONS")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": RedactString(message)})
}

func (s *Server) requirePOST(w http.ResponseWriter, r *http.Request) bool {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return false
	}
	return true
}

func (s *Server) requireGET(w http.ResponseWriter, r *http.Request) bool {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return false
	}
	return true
}

func (s *Server) requirePUT(w http.ResponseWriter, r *http.Request) bool {
	if r.Method != http.MethodPut {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return false
	}
	return true
}

func (s *Server) requireAgentAuth(w http.ResponseWriter, r *http.Request) bool {
	if s.agentToken == "" {
		writeError(w, http.StatusUnauthorized, "controller token is not configured")
		return false
	}
	if bearerToken(r) != s.agentToken {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return false
	}
	return true
}

func bearerToken(r *http.Request) string {
	header := r.Header.Get("Authorization")
	const prefix = "Bearer "
	if !strings.HasPrefix(header, prefix) {
		return ""
	}
	return strings.TrimSpace(strings.TrimPrefix(header, prefix))
}

func (s *Server) requireOperatorAuth(w http.ResponseWriter, r *http.Request) bool {
	if s.operatorToken == "" {
		writeError(w, http.StatusForbidden, "operator token required")
		return false
	}
	if bearerToken(r) != s.operatorToken {
		writeError(w, http.StatusUnauthorized, "operator unauthorized")
		return false
	}
	return true
}

func (s *Server) withReadAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !s.strictAuth || r.Method == http.MethodOptions || r.URL.Path == "/api/v1/health" || r.URL.Path == "/api/v1/login" || r.URL.Path == "/api/v1/logout" || r.URL.Path == "/api/v1/me" || strings.HasPrefix(r.URL.Path, "/api/v1/agent/") || r.URL.Path == "/api/v1/bootstrap/controller-info" || r.URL.Path == "/api/v1/bootstrap/agent-install-command" {
			next.ServeHTTP(w, r)
			return
		}
		if !s.requireOperatorAuth(w, r) {
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) operatorIdentity(r *http.Request) string {
	return s.operatorIdentityFromToken(bearerToken(r))
}

func (s *Server) operatorIdentityFromToken(token string) string {
	if token == "" {
		return "operator"
	}
	sum := sha256.Sum256([]byte(token))
	return "operator:" + hex.EncodeToString(sum[:])[:8]
}

func (s *Server) decodeBody(w http.ResponseWriter, r *http.Request, dst any) ([]byte, bool) {
	defer r.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(r.Body, 4<<20))
	if err != nil {
		writeError(w, http.StatusBadRequest, "read body failed")
		return nil, false
	}
	if err := json.Unmarshal(raw, dst); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return nil, false
	}
	return raw, true
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	if !s.requireGET(w, r) {
		return
	}
	writeJSON(w, http.StatusOK, HealthResponse{Name: "leikwan-controller", Version: Version, Status: "ok"})
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	if !s.requirePOST(w, r) {
		return
	}
	var req LoginRequest
	if _, ok := s.decodeBody(w, r, &req); !ok {
		return
	}
	if s.operatorToken == "" {
		writeError(w, http.StatusForbidden, "operator token required")
		return
	}
	if strings.TrimSpace(req.Token) != s.operatorToken {
		writeError(w, http.StatusUnauthorized, "operator unauthorized")
		return
	}
	writeJSON(w, http.StatusOK, LoginResponse{Status: "ok", Identity: s.operatorIdentityFromToken(req.Token), Version: Version, StrictAuth: s.strictAuth, AgentAuth: s.agentToken != "", OperatorSet: s.operatorToken != ""})
}

func (s *Server) handleLogout(w http.ResponseWriter, r *http.Request) {
	if !s.requirePOST(w, r) {
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) handleMe(w http.ResponseWriter, r *http.Request) {
	if !s.requireGET(w, r) {
		return
	}
	token := bearerToken(r)
	ok := s.operatorToken != "" && token == s.operatorToken
	identity := ""
	if ok {
		identity = s.operatorIdentityFromToken(token)
	}
	writeJSON(w, http.StatusOK, MeResponse{Authenticated: ok, Identity: identity, Version: Version})
}

func (s *Server) handleAuthStatus(w http.ResponseWriter, r *http.Request) {
	if !s.requireGET(w, r) {
		return
	}
	writeJSON(w, http.StatusOK, AuthStatusResponse{
		OperatorAuthConfigured: s.operatorToken != "",
		StrictAuth:             s.strictAuth,
		AgentAuthConfigured:    s.agentToken != "",
		Version:                Version,
	})
}

func (s *Server) handleCapabilities(w http.ResponseWriter, r *http.Request) {
	if !s.requireGET(w, r) {
		return
	}
	writeJSON(w, http.StatusOK, CapabilitiesResponse{
		Version: Version,
		Commands: []CapabilityItem{
			{Command: "lq --version", Class: "readonly", Note: "Core version check"},
			{Command: "lq status", Class: "readonly", Note: "Human status overview"},
			{Command: "lq status --json", Class: "readonly", Note: "Machine-readable status"},
			{Command: "lq doctor", Class: "readonly", Note: "Human diagnostics"},
			{Command: "lq doctor --json", Class: "readonly", Note: "Machine-readable diagnostics"},
			{Command: "lq forward list", Class: "readonly", Note: "Forward inventory"},
			{Command: "lq ddns overview", Class: "readonly", Note: "DDNS overview"},
			{Command: "manual TODO steps", Class: "manual", Note: "Operator performs interactive Core menu work"},
			{Command: "readonly allowlisted tasks", Class: "readonly", Note: "3.0.0-alpha.1 Agent tasks map actions to fixed argv only"},
			{Command: "alpha demo write actions", Class: "manual", Note: "Only fixed Agent handlers can stage Panel-managed JSON when enable_write_actions=true"},
			{Command: "manual snapshot record", Class: "manual", Note: "Controller records operator-provided snapshot metadata only"},
			{Command: "manual rollback record", Class: "manual", Note: "Controller records rollback metadata and instructions only"},
			{Command: "future write tasks", Class: "future", Note: "Reserved for later dry-run, snapshot, rollback, and approval design"},
		},
		Blocked:            []string{"rm", "systemctl restart", "systemctl stop", "nft", "iptables", "ip route", "curl | bash", "bash -c", "eval", "write into /etc"},
		Future:             []string{"write allowlist", "dry-run", "snapshot", "rollback", "operator approval"},
		SafetyLevels:       []string{"safe", "caution", "dangerous"},
		TaskSupport:        "3.0.0-alpha.1 supports readonly tasks and demo alpha write actions gated by enable_write_actions=true; no command strings are accepted",
		AllowedTaskActions: allowedTaskActions(),
	})
}

func (s *Server) handleActionCatalog(w http.ResponseWriter, r *http.Request) {
	if !s.requireGET(w, r) {
		return
	}
	rest := strings.Trim(strings.TrimPrefix(r.URL.Path, "/api/v1/action-catalog"), "/")
	if rest == "" {
		writeJSON(w, http.StatusOK, ActionCatalogResponse{Version: Version, Actions: s.store.ActionCatalog(r.Context())})
		return
	}
	def, err := s.store.ActionDefinition(r.Context(), rest)
	if err != nil {
		writeError(w, http.StatusNotFound, "action not found")
		return
	}
	writeJSON(w, http.StatusOK, def)
}

func (s *Server) handleBootstrapAgentCommand(w http.ResponseWriter, r *http.Request) {
	if !s.requireGET(w, r) {
		return
	}
	s.writeBootstrapAgentCommand(w, r, false)
}

func (s *Server) handleBootstrapControllerInfo(w http.ResponseWriter, r *http.Request) {
	if !s.requireGET(w, r) {
		return
	}
	controllerURL := controllerURLFromRequest(r)
	writeJSON(w, http.StatusOK, ControllerInfoResponse{
		Version:                 Version,
		ControllerURL:           RedactString(controllerURL),
		ControllerURLGuess:      RedactString(controllerURL),
		OperatorAuthConfigured:  s.operatorToken != "",
		AgentAuthConfigured:     s.agentToken != "",
		StrictAuth:              s.strictAuth,
		DemoApply:               true,
		InstallScriptURL:        installScriptURL(),
		SupportedRoles:          []string{"entry", "relay", "mixed", "unknown"},
		SupportedInstallMethods: []string{"curl", "wget"},
		Note:                    "3.0.0-alpha.1 demo apply can stage Panel-managed config files on write-enabled Agent nodes; backend targets are target_host:target_port and do not need an Agent.",
	})
}

func (s *Server) handleBootstrapAgentInstallCommand(w http.ResponseWriter, r *http.Request) {
	if !s.requireGET(w, r) {
		return
	}
	tokenMode := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("token_mode")))
	full := tokenMode == "full"
	if full && !s.requireOperatorAuth(w, r) {
		return
	}
	s.writeBootstrapAgentCommand(w, r, full)
}

func (s *Server) handleBootstrapAgentToken(w http.ResponseWriter, r *http.Request) {
	if !s.requirePOST(w, r) || !s.requireOperatorAuth(w, r) {
		return
	}
	writeJSON(w, http.StatusOK, AgentTokenResponse{
		Token:     RedactString(s.agentToken),
		TokenMode: "controller-agent-token",
		Warnings:  []string{"3.0.0-alpha.1 reuses the Controller Agent token; one-time join tokens are planned for a later release."},
	})
}

func (s *Server) writeBootstrapAgentCommand(w http.ResponseWriter, r *http.Request, full bool) {
	controllerURL := strings.TrimSpace(r.URL.Query().Get("controller_url"))
	if controllerURL == "" {
		controllerURL = controllerURLFromRequest(r)
	}
	role := normalizeRole(strings.TrimSpace(r.URL.Query().Get("role")))
	nodeName := strings.TrimSpace(r.URL.Query().Get("node_name"))
	if nodeName == "" {
		nodeName = "leikwan-node"
	}
	enableTasks := parseBoolQuery(r.URL.Query().Get("enable_tasks"), true)
	enableWriteActions := parseBoolQuery(r.URL.Query().Get("enable_write_actions"), false)
	method := normalizeInstallMethod(r.URL.Query().Get("method"))
	scriptURL := installScriptURL()
	token := "REDACTED"
	if full && s.agentToken != "" {
		token = s.agentToken
	}
	masked := buildAgentInstallCommand(method, scriptURL, controllerURL, "REDACTED", nodeName, role, enableTasks, enableWriteActions)
	command := masked
	fullCommand := ""
	if full {
		fullCommand = buildAgentInstallCommand(method, scriptURL, controllerURL, token, nodeName, role, enableTasks, enableWriteActions)
		command = fullCommand
	}
	writeJSON(w, http.StatusOK, BootstrapAgentCommandResponse{
		Command:            command,
		MaskedCommand:      masked,
		FullCommand:        fullCommand,
		ControllerURL:      RedactString(controllerURL),
		InstallScriptURL:   scriptURL,
		InstallMethod:      method,
		Role:               role,
		NodeName:           RedactString(nodeName),
		Token:              "REDACTED",
		Note:               "Agent joins by calling Controller; Controller does not SSH to nodes. enable_write_actions is alpha/demo and stages Panel-managed config files only.",
		EnableTasks:        enableTasks,
		EnableWriteActions: enableWriteActions,
		Warnings:           []string{"Run the command on the target VPS as root or with sudo.", "Controller downtime does not stop existing forwarding.", "Backend/landing targets do not need an Agent."},
	})
}

func controllerURLFromRequest(r *http.Request) string {
	scheme := "http"
	if r.TLS != nil {
		scheme = "https"
	}
	return scheme + "://" + r.Host
}

func parseBoolQuery(value string, fallback bool) bool {
	if strings.TrimSpace(value) == "" {
		return fallback
	}
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "1", "true", "yes", "y", "on", "enabled":
		return true
	default:
		return false
	}
}

func normalizeInstallMethod(method string) string {
	switch strings.ToLower(strings.TrimSpace(method)) {
	case "wget":
		return "wget"
	default:
		return "curl"
	}
}

func installScriptURL() string {
	return "https://raw.githubusercontent.com/ike-sh/leikwan-toolkit/main/panel/scripts/install-agent.sh"
}

func buildAgentInstallCommand(method, scriptURL, controllerURL, token, nodeName, role string, enableTasks, enableWriteActions bool) string {
	launcher := "curl -fsSL '" + shellQuote(scriptURL) + "' | sudo bash -s --"
	if normalizeInstallMethod(method) == "wget" {
		launcher = "wget -qO- '" + shellQuote(scriptURL) + "' | sudo bash -s --"
	}
	parts := []string{
		launcher,
		"--controller-url '" + shellQuote(controllerURL) + "'",
		"--token '" + shellQuote(token) + "'",
		"--node-name '" + shellQuote(nodeName) + "'",
		"--role '" + shellQuote(role) + "'",
	}
	if enableTasks {
		parts = append(parts, "--enable-tasks")
	}
	if enableWriteActions {
		parts = append(parts, "--enable-write-actions")
	}
	return strings.Join(parts, " \\\n  ")
}

func shellQuote(s string) string {
	return strings.ReplaceAll(RedactString(s), "'", "'\\''")
}

func (s *Server) handleTopology(w http.ResponseWriter, r *http.Request) {
	if !s.requireGET(w, r) {
		return
	}
	nodes, err := s.store.ListNodes(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	entries, err := s.store.ListEntries(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	forwards, err := s.store.ListForwards(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, TopologyResponse{
		Nodes:    nodes,
		Entries:  entries,
		Forwards: forwards,
		Links:    inferTopologyLinks(nodes, entries, forwards),
	})
}

func inferTopologyLinks(nodes []Node, entries []Entry, forwards []Forward) []TopologyLink {
	links := []TopologyLink{}
	relays := []Node{}
	entriesByNode := map[string]Node{}
	for _, node := range nodes {
		switch node.Role {
		case "relay", "mixed":
			relays = append(relays, node)
		case "entry":
			entriesByNode[node.NodeID] = node
		}
	}
	for _, entryNode := range entriesByNode {
		for _, relay := range relays {
			links = append(links, TopologyLink{
				Source: entryNode.NodeID,
				Target: relay.NodeID,
				Type:   "entry-relay",
				Label:  "entry -> relay",
				Status: linkStatus(entryNode.Status, relay.Status),
			})
		}
	}
	for _, entry := range entries {
		for _, relay := range relays {
			if entry.NodeID == relay.NodeID {
				links = append(links, TopologyLink{
					Source: relay.NodeID,
					Target: "entry:" + entry.Name,
					Type:   "relay-entry",
					Label:  entry.Name,
					Status: entry.Status,
				})
			}
		}
	}
	for _, forward := range forwards {
		source := forward.NodeID
		if source == "" && len(relays) > 0 {
			source = relays[0].NodeID
		}
		if source == "" {
			continue
		}
		target := "target:" + forward.Name
		if forward.TargetHost != "" {
			target = "target:" + forward.TargetHost
		}
		links = append(links, TopologyLink{
			Source: source,
			Target: target,
			Type:   "relay-target",
			Label:  forward.Name,
			Status: forward.Status,
		})
	}
	return links
}

func linkStatus(a, b string) string {
	if a == "offline" || b == "offline" {
		return "offline"
	}
	if a == "degraded" || b == "degraded" {
		return "degraded"
	}
	return "online"
}

func (s *Server) handleRegister(w http.ResponseWriter, r *http.Request) {
	if !s.requirePOST(w, r) || !s.requireAgentAuth(w, r) {
		return
	}
	var req RegisterRequest
	raw, ok := s.decodeBody(w, r, &req)
	if !ok {
		return
	}
	if err := s.store.Register(r.Context(), req, raw); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok", "node_id": req.NodeID})
}

func (s *Server) handleReport(w http.ResponseWriter, r *http.Request) {
	if !s.requirePOST(w, r) || !s.requireAgentAuth(w, r) {
		return
	}
	var req ReportRequest
	raw, ok := s.decodeBody(w, r, &req)
	if !ok {
		return
	}
	if err := s.store.Report(r.Context(), req, raw); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok", "node_id": req.NodeID})
}

func (s *Server) handleNodes(w http.ResponseWriter, r *http.Request) {
	if !s.requireGET(w, r) {
		return
	}
	nodes, err := s.store.ListNodes(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, nodes)
}

func (s *Server) handleNodeByID(w http.ResponseWriter, r *http.Request) {
	rest := strings.TrimPrefix(r.URL.Path, "/api/v1/nodes/")
	parts := strings.Split(strings.Trim(rest, "/"), "/")
	id := parts[0]
	if id == "" {
		writeError(w, http.StatusNotFound, "node not found")
		return
	}
	if len(parts) > 1 {
		switch parts[1] {
		case "reports":
			if !s.requireGET(w, r) {
				return
			}
			s.handleNodeReports(w, r, id)
		case "events":
			if !s.requireGET(w, r) {
				return
			}
			s.handleNodeEvents(w, r, id)
		case "raw":
			if !s.requireGET(w, r) {
				return
			}
			s.handleNodeRaw(w, r, id)
		case "restart-agent":
			s.handleNodeAction(w, r, id, "restart_agent", "")
		case "restart-easytier":
			s.handleNodeAction(w, r, id, "restart_easytier", "")
		case "reboot":
			s.handleNodeAction(w, r, id, "reboot_node", "REBOOT")
		default:
			writeError(w, http.StatusNotFound, "not found")
		}
		return
	}
	if !s.requireGET(w, r) {
		return
	}
	node, found, err := s.store.GetNode(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if !found {
		writeError(w, http.StatusNotFound, "node not found")
		return
	}
	writeJSON(w, http.StatusOK, node)
}

func (s *Server) handleNodeAction(w http.ResponseWriter, r *http.Request, nodeID, action, requiredConfirm string) {
	if !s.requirePOST(w, r) || !s.requireOperatorAuth(w, r) {
		return
	}
	var req NodeActionRequest
	if r.Body != nil {
		if _, ok := s.decodeBody(w, r, &req); !ok {
			return
		}
	}
	if requiredConfirm != "" && req.Confirm != requiredConfirm {
		writeError(w, http.StatusBadRequest, "confirm="+requiredConfirm+" is required")
		return
	}
	payload := taskPayload(map[string]any{"confirm": req.Confirm})
	task, err := s.store.CreateTask(r.Context(), CreateTaskRequest{NodeID: nodeID, Action: action, RequestedBy: s.operatorIdentity(r), TTLSeconds: 300, MaxAttempts: 1, TaskGroupID: "node-action-" + randomHex(6), PayloadJSON: payload})
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, task)
}

func queryLimit(r *http.Request, fallback int) int {
	limit := fallback
	if raw := r.URL.Query().Get("limit"); raw != "" {
		if n, err := strconv.Atoi(raw); err == nil {
			limit = n
		}
	}
	if limit <= 0 || limit > 200 {
		return fallback
	}
	return limit
}

func (s *Server) handleNodeReports(w http.ResponseWriter, r *http.Request, id string) {
	reports, err := s.store.ListNodeReports(r.Context(), id, queryLimit(r, 100))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, reports)
}

func (s *Server) handleNodeEvents(w http.ResponseWriter, r *http.Request, id string) {
	events, err := s.store.ListNodeEvents(r.Context(), id, queryLimit(r, 100))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, events)
}

func (s *Server) handleNodeRaw(w http.ResponseWriter, r *http.Request, id string) {
	node, found, err := s.store.GetNode(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if !found {
		writeError(w, http.StatusNotFound, "node not found")
		return
	}
	var raw any
	if err := json.Unmarshal([]byte(node.RawJSON), &raw); err != nil {
		raw = node.RawJSON
	}
	writeJSON(w, http.StatusOK, map[string]any{"node_id": node.NodeID, "raw_json": raw})
}

func (s *Server) handleNetworkProfiles(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		profiles, err := s.store.ListNetworkProfiles(r.Context())
		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, profiles)
	case http.MethodPost:
		if !s.requireOperatorAuth(w, r) {
			return
		}
		var req NetworkProfileRequest
		if _, ok := s.decodeBody(w, r, &req); !ok {
			return
		}
		profile, err := s.store.CreateNetworkProfile(r.Context(), req)
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusCreated, profile)
	default:
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (s *Server) handleNetworkProfileByID(w http.ResponseWriter, r *http.Request) {
	rest := strings.TrimPrefix(r.URL.Path, "/api/v1/network-profiles/")
	parts := strings.Split(strings.Trim(rest, "/"), "/")
	id, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusNotFound, "network profile not found")
		return
	}
	if len(parts) == 2 && parts[1] == "apply" {
		if !s.requirePOST(w, r) || !s.requireOperatorAuth(w, r) {
			return
		}
		resp, err := s.store.ApplyNetworkProfile(r.Context(), id, s.operatorIdentity(r))
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusCreated, resp)
		return
	}
	if len(parts) != 1 {
		writeError(w, http.StatusNotFound, "network profile not found")
		return
	}
	switch r.Method {
	case http.MethodGet:
		profile, err := s.store.GetNetworkProfile(r.Context(), id)
		if err != nil {
			writeError(w, http.StatusNotFound, "network profile not found")
			return
		}
		writeJSON(w, http.StatusOK, profile)
	case http.MethodPut:
		if !s.requireOperatorAuth(w, r) {
			return
		}
		var req NetworkProfileRequest
		if _, ok := s.decodeBody(w, r, &req); !ok {
			return
		}
		profile, err := s.store.UpdateNetworkProfile(r.Context(), id, req)
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, profile)
	default:
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (s *Server) handleEntries(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		entries, err := s.store.ListPanelEntries(r.Context())
		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, entries)
	case http.MethodPost:
		if !s.requireOperatorAuth(w, r) {
			return
		}
		var req PanelEntryRequest
		if _, ok := s.decodeBody(w, r, &req); !ok {
			return
		}
		entry, err := s.store.CreatePanelEntry(r.Context(), req)
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusCreated, entry)
	default:
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (s *Server) handleEntryByID(w http.ResponseWriter, r *http.Request) {
	rest := strings.TrimPrefix(r.URL.Path, "/api/v1/entries/")
	parts := strings.Split(strings.Trim(rest, "/"), "/")
	id, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusNotFound, "entry not found")
		return
	}
	if len(parts) == 2 && parts[1] == "apply" {
		if !s.requirePOST(w, r) || !s.requireOperatorAuth(w, r) {
			return
		}
		resp, err := s.store.ApplyPanelEntry(r.Context(), id, s.operatorIdentity(r))
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusCreated, resp)
		return
	}
	if len(parts) != 1 {
		writeError(w, http.StatusNotFound, "entry not found")
		return
	}
	switch r.Method {
	case http.MethodGet:
		entry, err := s.store.GetPanelEntry(r.Context(), id)
		if err != nil {
			writeError(w, http.StatusNotFound, "entry not found")
			return
		}
		writeJSON(w, http.StatusOK, entry)
	case http.MethodPut:
		if !s.requireOperatorAuth(w, r) {
			return
		}
		var req PanelEntryRequest
		if _, ok := s.decodeBody(w, r, &req); !ok {
			return
		}
		entry, err := s.store.UpdatePanelEntry(r.Context(), id, req)
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, entry)
	default:
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (s *Server) handleForwards(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		forwards, err := s.store.ListPanelForwards(r.Context())
		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, forwards)
	case http.MethodPost:
		if !s.requireOperatorAuth(w, r) {
			return
		}
		var req PanelForwardRequest
		if _, ok := s.decodeBody(w, r, &req); !ok {
			return
		}
		forward, err := s.store.CreatePanelForward(r.Context(), req)
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusCreated, forward)
	default:
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (s *Server) handleForwardByID(w http.ResponseWriter, r *http.Request) {
	rest := strings.TrimPrefix(r.URL.Path, "/api/v1/forwards/")
	parts := strings.Split(strings.Trim(rest, "/"), "/")
	id, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusNotFound, "forward not found")
		return
	}
	if len(parts) == 2 && parts[1] == "apply" {
		if !s.requirePOST(w, r) || !s.requireOperatorAuth(w, r) {
			return
		}
		resp, err := s.store.ApplyPanelForward(r.Context(), id, s.operatorIdentity(r))
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusCreated, resp)
		return
	}
	if len(parts) != 1 {
		writeError(w, http.StatusNotFound, "forward not found")
		return
	}
	switch r.Method {
	case http.MethodGet:
		forward, err := s.store.GetPanelForward(r.Context(), id)
		if err != nil {
			writeError(w, http.StatusNotFound, "forward not found")
			return
		}
		writeJSON(w, http.StatusOK, forward)
	case http.MethodPut:
		if !s.requireOperatorAuth(w, r) {
			return
		}
		var req PanelForwardRequest
		if _, ok := s.decodeBody(w, r, &req); !ok {
			return
		}
		forward, err := s.store.UpdatePanelForward(r.Context(), id, req)
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, forward)
	default:
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (s *Server) handleEvents(w http.ResponseWriter, r *http.Request) {
	if !s.requireGET(w, r) {
		return
	}
	events, err := s.store.ListEvents(r.Context(), 100)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, events)
}

func (s *Server) handlePBRPolicies(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		items, err := s.store.ListPBRPolicies(r.Context())
		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, items)
	case http.MethodPost:
		if !s.requireOperatorAuth(w, r) {
			return
		}
		var req PBRPolicyRequest
		if _, ok := s.decodeBody(w, r, &req); !ok {
			return
		}
		item, err := s.store.CreatePBRPolicy(r.Context(), req)
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusCreated, item)
	default:
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (s *Server) handlePBRPolicyByID(w http.ResponseWriter, r *http.Request) {
	rest := strings.TrimPrefix(r.URL.Path, "/api/v1/pbr-policies/")
	parts := strings.Split(strings.Trim(rest, "/"), "/")
	id, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusNotFound, "pbr policy not found")
		return
	}
	if len(parts) == 2 && parts[1] == "apply" {
		if !s.requirePOST(w, r) || !s.requireOperatorAuth(w, r) {
			return
		}
		resp, err := s.store.ApplyPBRPolicy(r.Context(), id, s.operatorIdentity(r))
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusCreated, resp)
		return
	}
	if len(parts) != 1 {
		writeError(w, http.StatusNotFound, "pbr policy not found")
		return
	}
	switch r.Method {
	case http.MethodGet:
		item, err := s.store.GetPBRPolicy(r.Context(), id)
		if err != nil {
			writeError(w, http.StatusNotFound, "pbr policy not found")
			return
		}
		writeJSON(w, http.StatusOK, item)
	case http.MethodPut:
		if !s.requireOperatorAuth(w, r) {
			return
		}
		var req PBRPolicyRequest
		if _, ok := s.decodeBody(w, r, &req); !ok {
			return
		}
		item, err := s.store.UpdatePBRPolicy(r.Context(), id, req)
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, item)
	default:
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (s *Server) handleDDNSProfiles(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		items, err := s.store.ListDDNSProfiles(r.Context())
		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, items)
	case http.MethodPost:
		if !s.requireOperatorAuth(w, r) {
			return
		}
		var req DDNSProfileRequest
		if _, ok := s.decodeBody(w, r, &req); !ok {
			return
		}
		item, err := s.store.CreateDDNSProfile(r.Context(), req)
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusCreated, item)
	default:
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (s *Server) handleDDNSProfileByID(w http.ResponseWriter, r *http.Request) {
	rest := strings.TrimPrefix(r.URL.Path, "/api/v1/ddns-profiles/")
	parts := strings.Split(strings.Trim(rest, "/"), "/")
	id, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusNotFound, "ddns profile not found")
		return
	}
	if len(parts) == 2 && (parts[1] == "apply" || parts[1] == "sync") {
		if !s.requirePOST(w, r) || !s.requireOperatorAuth(w, r) {
			return
		}
		var resp ApplyResponse
		if parts[1] == "apply" {
			resp, err = s.store.ApplyDDNSProfile(r.Context(), id, s.operatorIdentity(r))
		} else {
			resp, err = s.store.SyncDDNSProfile(r.Context(), id, s.operatorIdentity(r))
		}
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusCreated, resp)
		return
	}
	if len(parts) != 1 {
		writeError(w, http.StatusNotFound, "ddns profile not found")
		return
	}
	switch r.Method {
	case http.MethodGet:
		item, err := s.store.GetDDNSProfile(r.Context(), id)
		if err != nil {
			writeError(w, http.StatusNotFound, "ddns profile not found")
			return
		}
		writeJSON(w, http.StatusOK, item)
	case http.MethodPut:
		if !s.requireOperatorAuth(w, r) {
			return
		}
		var req DDNSProfileRequest
		if _, ok := s.decodeBody(w, r, &req); !ok {
			return
		}
		item, err := s.store.UpdateDDNSProfile(r.Context(), id, req)
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, item)
	default:
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (s *Server) handleTasks(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		tasks, err := s.store.ListTasks(r.Context())
		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, tasks)
	case http.MethodPost:
		if !s.requireOperatorAuth(w, r) {
			return
		}
		var req CreateTaskRequest
		if _, ok := s.decodeBody(w, r, &req); !ok {
			return
		}
		if strings.TrimSpace(req.RequestedBy) == "" {
			req.RequestedBy = s.operatorIdentity(r)
		}
		task, err := s.store.CreateTask(r.Context(), req)
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusCreated, task)
	default:
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (s *Server) handleTaskByID(w http.ResponseWriter, r *http.Request) {
	rest := strings.TrimPrefix(r.URL.Path, "/api/v1/tasks/")
	parts := strings.Split(strings.Trim(rest, "/"), "/")
	id, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusNotFound, "task not found")
		return
	}
	if len(parts) == 1 {
		if !s.requireGET(w, r) {
			return
		}
		task, err := s.store.GetTask(r.Context(), id)
		if err != nil {
			writeError(w, http.StatusNotFound, "task not found")
			return
		}
		writeJSON(w, http.StatusOK, task)
		return
	}
	switch parts[1] {
	case "cancel":
		if !s.requirePOST(w, r) || !s.requireOperatorAuth(w, r) {
			return
		}
		task, err := s.store.CancelTask(r.Context(), id)
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, task)
	case "retry":
		if !s.requirePOST(w, r) || !s.requireOperatorAuth(w, r) {
			return
		}
		task, err := s.store.RetryTask(r.Context(), id)
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusCreated, task)
	case "approve":
		if !s.requirePOST(w, r) || !s.requireOperatorAuth(w, r) {
			return
		}
		var req TaskApprovalRequest
		if _, ok := s.decodeBody(w, r, &req); !ok {
			return
		}
		if strings.TrimSpace(req.Actor) == "" {
			req.Actor = s.operatorIdentity(r)
		}
		task, err := s.store.ApproveTask(r.Context(), id, req)
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, task)
	case "reject":
		if !s.requirePOST(w, r) || !s.requireOperatorAuth(w, r) {
			return
		}
		var req TaskApprovalRequest
		if _, ok := s.decodeBody(w, r, &req); !ok {
			return
		}
		if strings.TrimSpace(req.Actor) == "" {
			req.Actor = s.operatorIdentity(r)
		}
		task, err := s.store.RejectTask(r.Context(), id, req)
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, task)
	case "timeline":
		if !s.requireGET(w, r) {
			return
		}
		timeline, err := s.store.TaskTimeline(r.Context(), id)
		if err != nil {
			writeError(w, http.StatusNotFound, "task not found")
			return
		}
		writeJSON(w, http.StatusOK, timeline)
	default:
		writeError(w, http.StatusNotFound, "not found")
	}
}

func (s *Server) handleAgentTasks(w http.ResponseWriter, r *http.Request) {
	if !s.requireGET(w, r) || !s.requireAgentAuth(w, r) {
		return
	}
	nodeID := strings.TrimSpace(r.URL.Query().Get("node_id"))
	tasks, err := s.store.PickTasks(r.Context(), nodeID, queryLimit(r, 5))
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, tasks)
}

func (s *Server) handleAgentTaskByID(w http.ResponseWriter, r *http.Request) {
	rest := strings.TrimPrefix(r.URL.Path, "/api/v1/agent/tasks/")
	parts := strings.Split(strings.Trim(rest, "/"), "/")
	if len(parts) != 2 || parts[1] != "result" {
		writeError(w, http.StatusNotFound, "not found")
		return
	}
	id, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusNotFound, "task not found")
		return
	}
	if !s.requirePOST(w, r) || !s.requireAgentAuth(w, r) {
		return
	}
	var req TaskResultRequest
	if _, ok := s.decodeBody(w, r, &req); !ok {
		return
	}
	task, err := s.store.FinishTask(r.Context(), id, req)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, task)
}

func parseIDFromPath(w http.ResponseWriter, path, prefix, notFound string) (int64, bool) {
	rest := strings.TrimPrefix(path, prefix)
	parts := strings.Split(strings.Trim(rest, "/"), "/")
	id, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil || id <= 0 || len(parts) != 1 {
		writeError(w, http.StatusNotFound, notFound)
		return 0, false
	}
	return id, true
}

func (s *Server) handlePlans(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		plans, err := s.store.ListPlans(r.Context())
		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, plans)
	case http.MethodPost:
		if !s.requireOperatorAuth(w, r) {
			return
		}
		var req CreatePlanRequest
		_, ok := s.decodeBody(w, r, &req)
		if !ok {
			return
		}
		plan, err := s.store.CreatePlan(r.Context(), req)
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusCreated, plan)
	default:
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (s *Server) handlePlanByID(w http.ResponseWriter, r *http.Request) {
	rest := strings.TrimPrefix(r.URL.Path, "/api/v1/plans/")
	parts := strings.Split(strings.Trim(rest, "/"), "/")
	id, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusNotFound, "plan not found")
		return
	}
	if len(parts) > 1 {
		switch parts[1] {
		case "generate":
			if !s.requirePOST(w, r) || !s.requireOperatorAuth(w, r) {
				return
			}
			plan, err := s.store.GeneratePlan(r.Context(), id)
			if err != nil {
				writeError(w, http.StatusBadRequest, err.Error())
				return
			}
			writeJSON(w, http.StatusOK, plan)
		case "regenerate":
			if !s.requirePOST(w, r) || !s.requireOperatorAuth(w, r) {
				return
			}
			plan, err := s.store.RegeneratePlan(r.Context(), id)
			if err != nil {
				writeError(w, http.StatusBadRequest, err.Error())
				return
			}
			writeJSON(w, http.StatusOK, plan)
		case "mark":
			if !s.requirePOST(w, r) || !s.requireOperatorAuth(w, r) {
				return
			}
			var req MarkPlanRequest
			if _, ok := s.decodeBody(w, r, &req); !ok {
				return
			}
			plan, err := s.store.MarkPlanBy(r.Context(), id, req, s.operatorIdentity(r))
			if err != nil {
				writeError(w, http.StatusBadRequest, err.Error())
				return
			}
			writeJSON(w, http.StatusOK, plan)
		case "preflight":
			if !s.requirePOST(w, r) || !s.requireOperatorAuth(w, r) {
				return
			}
			plan, err := s.store.PlanPreflight(r.Context(), id)
			if err != nil {
				writeError(w, http.StatusBadRequest, err.Error())
				return
			}
			writeJSON(w, http.StatusOK, plan)
		case "dry-run":
			switch r.Method {
			case http.MethodPost:
				if !s.requireOperatorAuth(w, r) {
					return
				}
				plan, err := s.store.StartPlanDryRun(r.Context(), id)
				if err != nil {
					writeError(w, http.StatusNotFound, "plan not found")
					return
				}
				writeJSON(w, http.StatusCreated, plan)
			case http.MethodGet:
				plan, err := s.store.PlanDryRun(r.Context(), id)
				if err != nil {
					writeError(w, http.StatusNotFound, "plan not found")
					return
				}
				writeJSON(w, http.StatusOK, plan)
			default:
				writeError(w, http.StatusMethodNotAllowed, "method not allowed")
			}
		case "snapshot":
			if !s.requirePOST(w, r) || !s.requireOperatorAuth(w, r) {
				return
			}
			var req PlanSnapshotRequest
			if _, ok := s.decodeBody(w, r, &req); !ok {
				return
			}
			plan, err := s.store.RecordPlanSnapshot(r.Context(), id, req)
			if err != nil {
				writeError(w, http.StatusNotFound, "plan not found")
				return
			}
			writeJSON(w, http.StatusOK, plan)
		case "rollback-info":
			if !s.requirePOST(w, r) || !s.requireOperatorAuth(w, r) {
				return
			}
			var req PlanRollbackInfoRequest
			if _, ok := s.decodeBody(w, r, &req); !ok {
				return
			}
			plan, err := s.store.RecordPlanRollbackInfo(r.Context(), id, req)
			if err != nil {
				writeError(w, http.StatusNotFound, "plan not found")
				return
			}
			writeJSON(w, http.StatusOK, plan)
		case "metadata-action":
			if !s.requirePOST(w, r) || !s.requireOperatorAuth(w, r) {
				return
			}
			var req PlanMetadataActionRequest
			if _, ok := s.decodeBody(w, r, &req); !ok {
				return
			}
			plan, err := s.store.ApplyPlanMetadataAction(r.Context(), id, req, s.operatorIdentity(r))
			if err != nil {
				if err == sql.ErrNoRows {
					writeError(w, http.StatusNotFound, "plan not found")
					return
				}
				writeError(w, http.StatusBadRequest, err.Error())
				return
			}
			writeJSON(w, http.StatusOK, plan)
		case "evidence":
			switch r.Method {
			case http.MethodGet:
				evidence, err := s.store.ListPlanEvidence(r.Context(), id)
				if err != nil {
					writeError(w, http.StatusNotFound, "plan not found")
					return
				}
				writeJSON(w, http.StatusOK, evidence)
			case http.MethodPost:
				if !s.requireOperatorAuth(w, r) {
					return
				}
				var req PlanEvidenceRequest
				if _, ok := s.decodeBody(w, r, &req); !ok {
					return
				}
				evidence, err := s.store.CreatePlanEvidence(r.Context(), id, req, s.operatorIdentity(r))
				if err != nil {
					if err == sql.ErrNoRows {
						writeError(w, http.StatusNotFound, "plan not found")
						return
					}
					writeError(w, http.StatusBadRequest, err.Error())
					return
				}
				writeJSON(w, http.StatusCreated, evidence)
			default:
				writeError(w, http.StatusMethodNotAllowed, "method not allowed")
			}
		case "safety-gate":
			if !s.requireGET(w, r) {
				return
			}
			gate, err := s.store.PlanSafetyGate(r.Context(), id)
			if err != nil {
				writeError(w, http.StatusNotFound, "plan not found")
				return
			}
			writeJSON(w, http.StatusOK, gate)
		case "verify":
			if !s.requirePOST(w, r) || !s.requireOperatorAuth(w, r) {
				return
			}
			plan, err := s.store.VerifyPlan(r.Context(), id)
			if err != nil {
				writeError(w, http.StatusNotFound, "plan not found")
				return
			}
			writeJSON(w, http.StatusOK, plan)
		case "action-review":
			switch r.Method {
			case http.MethodGet:
				review, err := s.store.PlanActionReview(r.Context(), id)
				if err != nil {
					writeError(w, http.StatusNotFound, "plan not found")
					return
				}
				writeJSON(w, http.StatusOK, review)
			case http.MethodPost:
				if !s.requireOperatorAuth(w, r) {
					return
				}
				review, err := s.store.PlanActionReview(r.Context(), id)
				if err != nil {
					writeError(w, http.StatusNotFound, "plan not found")
					return
				}
				review.ReviewedBy = s.operatorIdentity(r)
				writeJSON(w, http.StatusOK, review)
			default:
				writeError(w, http.StatusMethodNotAllowed, "method not allowed")
			}
		case "markdown":
			if !s.requireGET(w, r) {
				return
			}
			markdown, err := s.store.PlanMarkdown(r.Context(), id)
			if err != nil {
				writeError(w, http.StatusBadRequest, err.Error())
				return
			}
			w.Header().Set("Content-Type", "text/markdown; charset=utf-8")
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write([]byte(markdown))
		case "archive":
			if !s.requirePOST(w, r) || !s.requireOperatorAuth(w, r) {
				return
			}
			plan, err := s.store.ArchivePlan(r.Context(), id)
			if err != nil {
				writeError(w, http.StatusBadRequest, err.Error())
				return
			}
			writeJSON(w, http.StatusOK, plan)
		default:
			writeError(w, http.StatusNotFound, "not found")
		}
		return
	}
	if !s.requireGET(w, r) {
		return
	}
	plan, err := s.store.GetPlan(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusNotFound, "plan not found")
		return
	}
	writeJSON(w, http.StatusOK, plan)
}
