package controller

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func testServer(t *testing.T) http.Handler {
	t.Helper()
	store, err := OpenStore(filepath.Join(t.TempDir(), "controller.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = store.Close() })
	return NewServerWithAuth(store, ServerOptions{AgentToken: "test-token", OperatorToken: "operator-token"}, nil)
}

func postJSON(t *testing.T, h http.Handler, path, token string, body any) *httptest.ResponseRecorder {
	t.Helper()
	raw, err := json.Marshal(body)
	if err != nil {
		t.Fatal(err)
	}
	req := httptest.NewRequest(http.MethodPost, path, bytes.NewReader(raw))
	req.Header.Set("Content-Type", "application/json")
	if token == "" && !strings.HasPrefix(path, "/api/v1/agent/") {
		token = "operator-token"
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rr := httptest.NewRecorder()
	h.ServeHTTP(rr, req)
	return rr
}

func withOperator(req *http.Request) *http.Request {
	req.Header.Set("Authorization", "Bearer operator-token")
	return req
}

func TestAgentReportRequiresToken(t *testing.T) {
	h := testServer(t)
	rr := postJSON(t, h, "/api/v1/agent/report", "", ReportRequest{NodeID: "node-a"})
	if rr.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestOperatorAuthBoundaries(t *testing.T) {
	store, err := OpenStore(filepath.Join(t.TempDir(), "controller.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	noOperator := NewServerWithAuth(store, ServerOptions{AgentToken: "agent-token"}, nil)
	mutating := postJSON(t, noOperator, "/api/v1/plans", "agent-token", map[string]any{"type": "ddns_check", "title": "x"})
	if mutating.Code != http.StatusForbidden || !strings.Contains(mutating.Body.String(), "operator token required") {
		t.Fatalf("expected missing operator token to return 403, got %d %s", mutating.Code, mutating.Body.String())
	}
	statusReq := httptest.NewRequest(http.MethodGet, "/api/v1/auth/status", nil)
	statusOut := httptest.NewRecorder()
	noOperator.ServeHTTP(statusOut, statusReq)
	if statusOut.Code != http.StatusOK || !strings.Contains(statusOut.Body.String(), `"operator_auth_configured":false`) || !strings.Contains(statusOut.Body.String(), `"agent_auth_configured":true`) {
		t.Fatalf("auth status unexpected: %d %s", statusOut.Code, statusOut.Body.String())
	}

	authStore, err := OpenStore(filepath.Join(t.TempDir(), "controller-auth.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer authStore.Close()
	h := NewServerWithAuth(authStore, ServerOptions{AgentToken: "agent-token", OperatorToken: "operator-secret", StrictAuth: true}, nil)
	healthOut := httptest.NewRecorder()
	h.ServeHTTP(healthOut, httptest.NewRequest(http.MethodGet, "/api/v1/health", nil))
	if healthOut.Code != http.StatusOK {
		t.Fatalf("health should not require auth, got %d", healthOut.Code)
	}
	nodesOut := httptest.NewRecorder()
	h.ServeHTTP(nodesOut, httptest.NewRequest(http.MethodGet, "/api/v1/nodes", nil))
	if nodesOut.Code != http.StatusUnauthorized {
		t.Fatalf("strict nodes should require operator token, got %d %s", nodesOut.Code, nodesOut.Body.String())
	}
	strictStatusOut := httptest.NewRecorder()
	h.ServeHTTP(strictStatusOut, httptest.NewRequest(http.MethodGet, "/api/v1/auth/status", nil))
	if strictStatusOut.Code != http.StatusUnauthorized {
		t.Fatalf("strict auth/status should require operator token, got %d %s", strictStatusOut.Code, strictStatusOut.Body.String())
	}
	nodesReq := httptest.NewRequest(http.MethodGet, "/api/v1/nodes", nil)
	nodesReq.Header.Set("Authorization", "Bearer operator-secret")
	nodesOK := httptest.NewRecorder()
	h.ServeHTTP(nodesOK, nodesReq)
	if nodesOK.Code != http.StatusOK {
		t.Fatalf("strict nodes with operator token failed: %d %s", nodesOK.Code, nodesOK.Body.String())
	}
	statusReqStrict := httptest.NewRequest(http.MethodGet, "/api/v1/auth/status", nil)
	statusReqStrict.Header.Set("Authorization", "Bearer operator-secret")
	statusOK := httptest.NewRecorder()
	h.ServeHTTP(statusOK, statusReqStrict)
	if statusOK.Code != http.StatusOK || !strings.Contains(statusOK.Body.String(), `"strict_auth":true`) {
		t.Fatalf("strict auth/status with operator token failed: %d %s", statusOK.Code, statusOK.Body.String())
	}
	wrong := postJSON(t, h, "/api/v1/plans", "wrong-token", map[string]any{"type": "ddns_check", "title": "x"})
	if wrong.Code != http.StatusUnauthorized {
		t.Fatalf("wrong operator token should fail, got %d %s", wrong.Code, wrong.Body.String())
	}
	agentCannotOperate := postJSON(t, h, "/api/v1/plans", "agent-token", map[string]any{"type": "ddns_check", "title": "x"})
	if agentCannotOperate.Code != http.StatusUnauthorized {
		t.Fatalf("agent token must not call operator API, got %d %s", agentCannotOperate.Code, agentCannotOperate.Body.String())
	}
	operatorCannotAgent := postJSON(t, h, "/api/v1/agent/report", "operator-secret", ReportRequest{NodeID: "node-a"})
	if operatorCannotAgent.Code != http.StatusUnauthorized {
		t.Fatalf("operator token must not call agent API, got %d %s", operatorCannotAgent.Code, operatorCannotAgent.Body.String())
	}
	ok := postJSON(t, h, "/api/v1/plans", "operator-secret", map[string]any{"type": "ddns_check", "title": "x"})
	if ok.Code != http.StatusCreated {
		t.Fatalf("operator token should create plan, got %d %s", ok.Code, ok.Body.String())
	}
	var plan Plan
	if err := json.Unmarshal(ok.Body.Bytes(), &plan); err != nil {
		t.Fatal(err)
	}
	review := postJSON(t, h, fmt.Sprintf("/api/v1/plans/%d/action-review", plan.ID), "operator-secret", nil)
	if review.Code != http.StatusOK || !strings.Contains(review.Body.String(), "operator:") || strings.Contains(review.Body.String(), "operator-secret") {
		t.Fatalf("review should include fingerprint only: %d %s", review.Code, review.Body.String())
	}
	task := postJSON(t, h, "/api/v1/tasks", "operator-secret", CreateTaskRequest{NodeID: "node-a", Action: "run_status"})
	if task.Code != http.StatusCreated || strings.Contains(task.Body.String(), "operator-secret") || !strings.Contains(task.Body.String(), "operator:") {
		t.Fatalf("task should store fingerprint requested_by only: %d %s", task.Code, task.Body.String())
	}
	var createdTask Task
	if err := json.Unmarshal(task.Body.Bytes(), &createdTask); err != nil {
		t.Fatal(err)
	}
	approve := postJSON(t, h, fmt.Sprintf("/api/v1/tasks/%d/approve", createdTask.ID), "operator-secret", TaskApprovalRequest{Note: "operator_token=operator-secret"})
	if approve.Code != http.StatusOK || strings.Contains(approve.Body.String(), "operator-secret") || !strings.Contains(approve.Body.String(), "operator:") {
		t.Fatalf("approval should store fingerprint and redact note: %d %s", approve.Code, approve.Body.String())
	}
	timelineReq := httptest.NewRequest(http.MethodGet, fmt.Sprintf("/api/v1/tasks/%d/timeline", createdTask.ID), nil)
	timelineReq.Header.Set("Authorization", "Bearer operator-secret")
	timelineOut := httptest.NewRecorder()
	h.ServeHTTP(timelineOut, timelineReq)
	if timelineOut.Code != http.StatusOK || strings.Contains(timelineOut.Body.String(), "operator-secret") || !strings.Contains(timelineOut.Body.String(), "operator:") {
		t.Fatalf("timeline should include fingerprint only: %d %s", timelineOut.Code, timelineOut.Body.String())
	}
	eventsReq := httptest.NewRequest(http.MethodGet, "/api/v1/events", nil)
	eventsReq.Header.Set("Authorization", "Bearer operator-secret")
	eventsOut := httptest.NewRecorder()
	h.ServeHTTP(eventsOut, eventsReq)
	if eventsOut.Code != http.StatusOK || strings.Contains(eventsOut.Body.String(), "operator-secret") {
		t.Fatalf("events must not contain full operator token: %d %s", eventsOut.Code, eventsOut.Body.String())
	}
}

func TestRegisterAndReportWithToken(t *testing.T) {
	h := testServer(t)
	reg := postJSON(t, h, "/api/v1/agent/register", "test-token", RegisterRequest{NodeID: "node-a", NodeName: "A", Role: "entry"})
	if reg.Code != http.StatusOK {
		t.Fatalf("register failed: %d %s", reg.Code, reg.Body.String())
	}
	report := ReportRequest{
		NodeID: "node-a", NodeName: "A", Role: "entry", PublicIP: "1.2.3.4", PrimaryLANIP: "10.0.0.2",
		AgentVersion: Version, CoreVersion: "1.4.0 LTS", Status: "online", HealthScore: 96, IntervalSeconds: 30,
		Services: map[string]string{"nftables": "active"},
		Summary:  json.RawMessage(`{"entries_count":1,"forwards_count":1,"health_score":96}`),
		Doctor:   json.RawMessage(`{"overall":"OK","warnings":[],"suggestions":[]}`),
		Entries:  []EntryPayload{{Name: "public1", ListenPort: 8301, Protocol: "tcp,udp", PublicHost: "home.example.com", Status: "ok"}},
		Forwards: []ForwardPayload{{Name: "hk", EntryName: "public1", TargetHost: "10.0.0.8", TargetPort: 443, Protocol: "tcp,udp", Status: "ok"}},
	}
	rr := postJSON(t, h, "/api/v1/agent/report", "test-token", report)
	if rr.Code != http.StatusOK {
		t.Fatalf("report failed: %d %s", rr.Code, rr.Body.String())
	}
	req := httptest.NewRequest(http.MethodGet, "/api/v1/nodes", nil)
	out := httptest.NewRecorder()
	h.ServeHTTP(out, req)
	if out.Code != http.StatusOK || !strings.Contains(out.Body.String(), "node-a") {
		t.Fatalf("nodes output unexpected: %d %s", out.Code, out.Body.String())
	}
	reportsReq := httptest.NewRequest(http.MethodGet, "/api/v1/nodes/node-a/reports", nil)
	reportsOut := httptest.NewRecorder()
	h.ServeHTTP(reportsOut, reportsReq)
	if reportsOut.Code != http.StatusOK || !strings.Contains(reportsOut.Body.String(), "node-a") {
		t.Fatalf("reports output unexpected: %d %s", reportsOut.Code, reportsOut.Body.String())
	}
	rawReq := httptest.NewRequest(http.MethodGet, "/api/v1/nodes/node-a/raw", nil)
	rawOut := httptest.NewRecorder()
	h.ServeHTTP(rawOut, rawReq)
	if rawOut.Code != http.StatusOK || !strings.Contains(rawOut.Body.String(), "raw_json") {
		t.Fatalf("raw output unexpected: %d %s", rawOut.Code, rawOut.Body.String())
	}
	eventsReq := httptest.NewRequest(http.MethodGet, "/api/v1/nodes/node-a/events", nil)
	eventsOut := httptest.NewRecorder()
	h.ServeHTTP(eventsOut, eventsReq)
	if eventsOut.Code != http.StatusOK || !strings.Contains(eventsOut.Body.String(), "node status changed") {
		t.Fatalf("events output unexpected: %d %s", eventsOut.Code, eventsOut.Body.String())
	}
}

func TestTopologyAndBootstrapCommand(t *testing.T) {
	h := testServer(t)
	relay := ReportRequest{NodeID: "relay-1", NodeName: "relay", Role: "relay", Status: "online", IntervalSeconds: 30,
		Entries:  []EntryPayload{{Name: "public1", ListenPort: 8301, Protocol: "tcp,udp", PublicHost: "home.example.com", Status: "ok"}},
		Forwards: []ForwardPayload{{Name: "hk", EntryName: "public1", TargetHost: "10.0.0.8", TargetPort: 443, Protocol: "tcp,udp", Status: "ok"}},
	}
	entry := ReportRequest{NodeID: "entry-1", NodeName: "entry", Role: "entry", Status: "online", IntervalSeconds: 30}
	for _, report := range []ReportRequest{relay, entry} {
		rr := postJSON(t, h, "/api/v1/agent/report", "test-token", report)
		if rr.Code != http.StatusOK {
			t.Fatalf("report failed: %d %s", rr.Code, rr.Body.String())
		}
	}
	topologyReq := httptest.NewRequest(http.MethodGet, "/api/v1/topology", nil)
	topologyOut := httptest.NewRecorder()
	h.ServeHTTP(topologyOut, topologyReq)
	if topologyOut.Code != http.StatusOK {
		t.Fatalf("topology failed: %d %s", topologyOut.Code, topologyOut.Body.String())
	}
	for _, want := range []string{"relay-1", "entry-1", "entry-relay", "relay-target"} {
		if !strings.Contains(topologyOut.Body.String(), want) {
			t.Fatalf("topology missing %q: %s", want, topologyOut.Body.String())
		}
	}
	bootReq := httptest.NewRequest(http.MethodGet, "/api/v1/bootstrap/agent-command?controller_url=http://panel.local:18080?token=abc&role=relay&node_name=test-node", nil)
	bootOut := httptest.NewRecorder()
	h.ServeHTTP(bootOut, bootReq)
	if bootOut.Code != http.StatusOK {
		t.Fatalf("bootstrap failed: %d %s", bootOut.Code, bootOut.Body.String())
	}
	if strings.Contains(bootOut.Body.String(), "test-token") || strings.Contains(bootOut.Body.String(), "token=abc") || !strings.Contains(bootOut.Body.String(), "REDACTED") {
		t.Fatalf("bootstrap leaked or missed token redaction: %s", bootOut.Body.String())
	}
	infoReq := httptest.NewRequest(http.MethodGet, "/api/v1/bootstrap/controller-info", nil)
	infoOut := httptest.NewRecorder()
	h.ServeHTTP(infoOut, infoReq)
	if infoOut.Code != http.StatusOK || !strings.Contains(infoOut.Body.String(), "supported_install_methods") || !strings.Contains(infoOut.Body.String(), "install-agent.sh") {
		t.Fatalf("controller-info output unexpected: %d %s", infoOut.Code, infoOut.Body.String())
	}
	maskedReq := httptest.NewRequest(http.MethodGet, "/api/v1/bootstrap/agent-install-command?controller_url=http://panel.local:18080&role=relay&node_name=test-node&enable_tasks=true&enable_write_actions=true&method=wget&token_mode=masked", nil)
	maskedOut := httptest.NewRecorder()
	h.ServeHTTP(maskedOut, maskedReq)
	if maskedOut.Code != http.StatusOK || !strings.Contains(maskedOut.Body.String(), "wget -qO-") || !strings.Contains(maskedOut.Body.String(), "--enable-write-actions") || strings.Contains(maskedOut.Body.String(), "test-token") {
		t.Fatalf("masked install command unexpected: %d %s", maskedOut.Code, maskedOut.Body.String())
	}
	fullNoAuth := httptest.NewRequest(http.MethodGet, "/api/v1/bootstrap/agent-install-command?controller_url=http://panel.local:18080&role=relay&node_name=test-node&token_mode=full", nil)
	fullNoAuthOut := httptest.NewRecorder()
	h.ServeHTTP(fullNoAuthOut, fullNoAuth)
	if fullNoAuthOut.Code != http.StatusUnauthorized {
		t.Fatalf("full command should require operator token, got %d %s", fullNoAuthOut.Code, fullNoAuthOut.Body.String())
	}
	fullReq := withOperator(httptest.NewRequest(http.MethodGet, "/api/v1/bootstrap/agent-install-command?controller_url=http://panel.local:18080&role=relay&node_name=test-node&enable_tasks=true&enable_write_actions=true&method=curl&token_mode=full", nil))
	fullOut := httptest.NewRecorder()
	h.ServeHTTP(fullOut, fullReq)
	if fullOut.Code != http.StatusOK || !strings.Contains(fullOut.Body.String(), "test-token") || !strings.Contains(fullOut.Body.String(), "--enable-tasks") || !strings.Contains(fullOut.Body.String(), "--enable-write-actions") {
		t.Fatalf("full install command unexpected: %d %s", fullOut.Code, fullOut.Body.String())
	}
	tokenNoAuth := httptest.NewRequest(http.MethodPost, "/api/v1/bootstrap/agent-token", nil)
	tokenNoAuthOut := httptest.NewRecorder()
	h.ServeHTTP(tokenNoAuthOut, tokenNoAuth)
	if tokenNoAuthOut.Code != http.StatusUnauthorized {
		t.Fatalf("agent-token should require operator token, got %d %s", tokenNoAuthOut.Code, tokenNoAuthOut.Body.String())
	}
	tokenReq := withOperator(httptest.NewRequest(http.MethodPost, "/api/v1/bootstrap/agent-token", nil))
	tokenOut := httptest.NewRecorder()
	h.ServeHTTP(tokenOut, tokenReq)
	if tokenOut.Code != http.StatusOK || !strings.Contains(tokenOut.Body.String(), "test-token") {
		t.Fatalf("agent-token output unexpected: %d %s", tokenOut.Code, tokenOut.Body.String())
	}
}

func TestRedactCleansSecrets(t *testing.T) {
	raw := []byte(`{"token":"abc","operator_token":"operator-secret","controller_token":"agent-secret","secret":"s","password":"p","privateKey":"k","custom_url":"https://example.com?token=abc","custom_cmd":"cmd --token abc","nested":{"Authorization":"Bearer abc"}}`)
	redacted := string(RedactJSONBytes(raw))
	for _, leak := range []string{"abc", "operator-secret", "agent-secret", "Bearer abc", "--token abc", "https://example.com?token=abc"} {
		if strings.Contains(redacted, leak) {
			t.Fatalf("redaction leaked %q in %s", leak, redacted)
		}
	}
	if !strings.Contains(redacted, "REDACTED") {
		t.Fatalf("expected REDACTED in %s", redacted)
	}
}

func TestOfflineAndEmptyCollections(t *testing.T) {
	store, err := OpenStore(filepath.Join(t.TempDir(), "controller.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	h := NewServerWithAuth(store, ServerOptions{AgentToken: "test-token", OperatorToken: "operator-token"}, nil)
	rr := postJSON(t, h, "/api/v1/agent/report", "test-token", ReportRequest{NodeID: "old-node", NodeName: "old", Role: "relay", Status: "online", IntervalSeconds: 1})
	if rr.Code != http.StatusOK {
		t.Fatalf("report failed: %d %s", rr.Code, rr.Body.String())
	}
	_, err = store.db.Exec(`UPDATE nodes SET last_seen=? WHERE node_id=?`, time.Now().Add(-10*time.Second).UTC().Format(time.RFC3339), "old-node")
	if err != nil {
		t.Fatal(err)
	}
	nodesReq := httptest.NewRequest(http.MethodGet, "/api/v1/nodes", nil)
	nodesOut := httptest.NewRecorder()
	h.ServeHTTP(nodesOut, nodesReq)
	if nodesOut.Code != http.StatusOK || !strings.Contains(nodesOut.Body.String(), `"status":"offline"`) {
		t.Fatalf("expected offline node, got %d %s", nodesOut.Code, nodesOut.Body.String())
	}
	entriesReq := httptest.NewRequest(http.MethodGet, "/api/v1/entries", nil)
	entriesOut := httptest.NewRecorder()
	h.ServeHTTP(entriesOut, entriesReq)
	if entriesOut.Code != http.StatusOK || strings.TrimSpace(entriesOut.Body.String()) != "[]" {
		t.Fatalf("expected empty entries array, got %d %s", entriesOut.Code, entriesOut.Body.String())
	}
	forwardsReq := httptest.NewRequest(http.MethodGet, "/api/v1/forwards", nil)
	forwardsOut := httptest.NewRecorder()
	h.ServeHTTP(forwardsOut, forwardsReq)
	if forwardsOut.Code != http.StatusOK || strings.TrimSpace(forwardsOut.Body.String()) != "[]" {
		t.Fatalf("expected empty forwards array, got %d %s", forwardsOut.Code, forwardsOut.Body.String())
	}
}

func TestReportRawJSONRedacted(t *testing.T) {
	h := testServer(t)
	body := map[string]any{
		"node_id":       "node-secret",
		"status":        "online",
		"custom_url":    "https://example.com/update?token=abc",
		"custom_cmd":    "cmd --token abc",
		"Authorization": "Bearer abc",
		"privateKey":    "key",
	}
	rr := postJSON(t, h, "/api/v1/agent/report", "test-token", body)
	if rr.Code != http.StatusOK {
		t.Fatalf("report failed: %d %s", rr.Code, rr.Body.String())
	}
	rawReq := httptest.NewRequest(http.MethodGet, "/api/v1/nodes/node-secret/raw", nil)
	rawOut := httptest.NewRecorder()
	h.ServeHTTP(rawOut, rawReq)
	for _, leak := range []string{"Bearer abc", "token=abc", "cmd --token abc", "privateKey\":\"key"} {
		if strings.Contains(rawOut.Body.String(), leak) {
			t.Fatalf("raw endpoint leaked %q in %s", leak, rawOut.Body.String())
		}
	}
}

func TestPlansLifecycleAndRedaction(t *testing.T) {
	h := testServer(t)
	report := ReportRequest{
		NodeID: "relay-1", NodeName: "liqun-relay", Role: "relay", Status: "online", IntervalSeconds: 30,
		Entries:  []EntryPayload{{Name: "public1", ListenPort: 8301, Protocol: "tcp,udp", PublicHost: "home.example.com", Status: "ok"}},
		Forwards: []ForwardPayload{{Name: "hk", EntryName: "public1", TargetHost: "10.0.0.8", TargetPort: 443, Protocol: "tcp,udp", Status: "ok"}},
	}
	if rr := postJSON(t, h, "/api/v1/agent/report", "test-token", report); rr.Code != http.StatusOK {
		t.Fatalf("report failed: %d %s", rr.Code, rr.Body.String())
	}
	createBody := map[string]any{
		"type":           "create_forward",
		"title":          "Add hk forward",
		"target_node_id": "relay-1",
		"payload_json": map[string]any{
			"target_host": "10.0.0.8",
			"target_port": 443,
			"protocol":    "tcp,udp",
			"token":       "abc",
			"custom_cmd":  "cmd --token abc",
			"privateKey":  "key",
		},
	}
	created := postJSON(t, h, "/api/v1/plans", "", createBody)
	if created.Code != http.StatusCreated {
		t.Fatalf("create plan failed: %d %s", created.Code, created.Body.String())
	}
	if strings.Contains(created.Body.String(), "abc") || strings.Contains(created.Body.String(), "privateKey\":\"key") {
		t.Fatalf("plan create leaked secret: %s", created.Body.String())
	}
	var plan Plan
	if err := json.Unmarshal(created.Body.Bytes(), &plan); err != nil {
		t.Fatal(err)
	}
	listReq := httptest.NewRequest(http.MethodGet, "/api/v1/plans", nil)
	listOut := httptest.NewRecorder()
	h.ServeHTTP(listOut, listReq)
	if listOut.Code != http.StatusOK || !strings.Contains(listOut.Body.String(), "Add hk forward") {
		t.Fatalf("list plans failed: %d %s", listOut.Code, listOut.Body.String())
	}
	nodesBefore := httptest.NewRecorder()
	h.ServeHTTP(nodesBefore, httptest.NewRequest(http.MethodGet, "/api/v1/nodes", nil))
	entriesBefore := httptest.NewRecorder()
	h.ServeHTTP(entriesBefore, httptest.NewRequest(http.MethodGet, "/api/v1/entries", nil))
	forwardsBefore := httptest.NewRecorder()
	h.ServeHTTP(forwardsBefore, httptest.NewRequest(http.MethodGet, "/api/v1/forwards", nil))
	generateReq := withOperator(httptest.NewRequest(http.MethodPost, fmt.Sprintf("/api/v1/plans/%d/generate", plan.ID), nil))
	generateOut := httptest.NewRecorder()
	h.ServeHTTP(generateOut, generateReq)
	if generateOut.Code != http.StatusOK {
		t.Fatalf("generate plan failed: %d %s", generateOut.Code, generateOut.Body.String())
	}
	for _, want := range []string{"command_groups", "checklist", "markdown", "This plan is manual-only", "lq --version"} {
		if !strings.Contains(generateOut.Body.String(), want) {
			t.Fatalf("generated plan missing %q: %s", want, generateOut.Body.String())
		}
	}
	for _, leak := range []string{"abc", "privateKey", "custom_cmd", "systemctl restart", "nft ", "iptables", "curl | bash", "bash -c", "eval "} {
		if strings.Contains(generateOut.Body.String(), leak) {
			t.Fatalf("generated plan leaked or used forbidden command %q: %s", leak, generateOut.Body.String())
		}
	}
	markReq := postJSON(t, h, fmt.Sprintf("/api/v1/plans/%d/mark", plan.ID), "", MarkPlanRequest{
		ExecutionStatus: "succeeded",
		ExecutionNote:   "manual result token=abc",
		ManualResult:    `{"checked":true,"privateKey":"key"}`,
	})
	if markReq.Code != http.StatusOK || !strings.Contains(markReq.Body.String(), `"execution_status":"succeeded"`) {
		t.Fatalf("mark failed: %d %s", markReq.Code, markReq.Body.String())
	}
	if strings.Contains(markReq.Body.String(), "token=abc") || strings.Contains(markReq.Body.String(), "privateKey") {
		t.Fatalf("mark leaked secret: %s", markReq.Body.String())
	}
	markdownReq := httptest.NewRequest(http.MethodGet, fmt.Sprintf("/api/v1/plans/%d/markdown", plan.ID), nil)
	markdownOut := httptest.NewRecorder()
	h.ServeHTTP(markdownOut, markdownReq)
	if markdownOut.Code != http.StatusOK || !strings.Contains(markdownOut.Body.String(), "This plan is manual-only") {
		t.Fatalf("markdown failed: %d %s", markdownOut.Code, markdownOut.Body.String())
	}
	for _, leak := range []string{"abc", "privateKey", "custom_cmd", "Authorization"} {
		if strings.Contains(markdownOut.Body.String(), leak) {
			t.Fatalf("markdown leaked %q: %s", leak, markdownOut.Body.String())
		}
	}
	regenerateReq := withOperator(httptest.NewRequest(http.MethodPost, fmt.Sprintf("/api/v1/plans/%d/regenerate", plan.ID), nil))
	regenerateOut := httptest.NewRecorder()
	h.ServeHTTP(regenerateOut, regenerateReq)
	if regenerateOut.Code != http.StatusOK || !strings.Contains(regenerateOut.Body.String(), "command_groups") {
		t.Fatalf("regenerate failed: %d %s", regenerateOut.Code, regenerateOut.Body.String())
	}
	nodesAfter := httptest.NewRecorder()
	h.ServeHTTP(nodesAfter, httptest.NewRequest(http.MethodGet, "/api/v1/nodes", nil))
	if nodesBefore.Body.String() != nodesAfter.Body.String() {
		t.Fatalf("plan generation changed nodes: before=%s after=%s", nodesBefore.Body.String(), nodesAfter.Body.String())
	}
	entriesAfter := httptest.NewRecorder()
	h.ServeHTTP(entriesAfter, httptest.NewRequest(http.MethodGet, "/api/v1/entries", nil))
	if entriesBefore.Body.String() != entriesAfter.Body.String() {
		t.Fatalf("plan mark/regenerate changed entries: before=%s after=%s", entriesBefore.Body.String(), entriesAfter.Body.String())
	}
	forwardsAfter := httptest.NewRecorder()
	h.ServeHTTP(forwardsAfter, httptest.NewRequest(http.MethodGet, "/api/v1/forwards", nil))
	if forwardsBefore.Body.String() != forwardsAfter.Body.String() {
		t.Fatalf("plan mark/regenerate changed forwards: before=%s after=%s", forwardsBefore.Body.String(), forwardsAfter.Body.String())
	}
	archiveReq := withOperator(httptest.NewRequest(http.MethodPost, fmt.Sprintf("/api/v1/plans/%d/archive", plan.ID), nil))
	archiveOut := httptest.NewRecorder()
	h.ServeHTTP(archiveOut, archiveReq)
	if archiveOut.Code != http.StatusOK || !strings.Contains(archiveOut.Body.String(), `"status":"archived"`) {
		t.Fatalf("archive failed: %d %s", archiveOut.Code, archiveOut.Body.String())
	}
}

func TestSwitchEntryPlanWarnings(t *testing.T) {
	h := testServer(t)
	created := postJSON(t, h, "/api/v1/plans", "", map[string]any{
		"type":           "switch_entry",
		"title":          "Switch primary",
		"target_node_id": "relay-1",
		"payload_json":   map[string]any{"entry": "public2"},
	})
	if created.Code != http.StatusCreated {
		t.Fatalf("create switch plan failed: %d %s", created.Code, created.Body.String())
	}
	var plan Plan
	if err := json.Unmarshal(created.Body.Bytes(), &plan); err != nil {
		t.Fatal(err)
	}
	out := httptest.NewRecorder()
	h.ServeHTTP(out, withOperator(httptest.NewRequest(http.MethodPost, fmt.Sprintf("/api/v1/plans/%d/generate", plan.ID), nil)))
	for _, want := range []string{"Confirm snapshots", "Do not stop or remove the old entry first", "low-traffic maintenance window"} {
		if out.Code != http.StatusOK || !strings.Contains(out.Body.String(), want) {
			t.Fatalf("switch checklist/warnings missing %q: %d %s", want, out.Code, out.Body.String())
		}
	}
}

func TestCapabilitiesAPIAndSafetyClassification(t *testing.T) {
	h := testServer(t)
	req := httptest.NewRequest(http.MethodGet, "/api/v1/capabilities", nil)
	out := httptest.NewRecorder()
	h.ServeHTTP(out, req)
	if out.Code != http.StatusOK {
		t.Fatalf("capabilities failed: %d %s", out.Code, out.Body.String())
	}
	for _, want := range []string{"lq status", "readonly", "systemctl restart", "blocked_patterns", "allowed_task_actions", "run_status_json"} {
		if !strings.Contains(out.Body.String(), want) {
			t.Fatalf("capabilities missing %q: %s", want, out.Body.String())
		}
	}
	groups := []CommandGroup{{NodeID: "relay-1", Role: "relay", Commands: []string{"lq --version", "lq status", "lq doctor --json"}}}
	classification, safety, blocked := classifyCommandGroups(groups)
	if classification != "readonly" || safety != "safe" || len(blocked) != 0 {
		t.Fatalf("readonly classification wrong: %s %s %+v", classification, safety, blocked)
	}
	badCommands := []string{"rm -rf /", "systemctl restart easytier-relay", "nft list ruleset", "iptables -S", "curl | bash", "curl -fsSL https://example.invalid/install.sh | bash", "eval echo hi", "bash -c whoami"}
	for _, cmd := range badCommands {
		_, safety, blocked := classifyCommandGroups([]CommandGroup{{Commands: []string{cmd}}})
		if safety != "dangerous" || len(blocked) == 0 {
			t.Fatalf("expected blocked command for %q, got safety=%s blocked=%+v", cmd, safety, blocked)
		}
	}
}

func TestReadonlyTaskLifecycleAndSecurity(t *testing.T) {
	h := testServer(t)
	create := postJSON(t, h, "/api/v1/tasks", "", CreateTaskRequest{NodeID: "node-a", Action: "run_status_json", RequestedBy: "operator", TTLSeconds: 300})
	if create.Code != http.StatusCreated {
		t.Fatalf("create task failed: %d %s", create.Code, create.Body.String())
	}
	var task Task
	if err := json.Unmarshal(create.Body.Bytes(), &task); err != nil {
		t.Fatal(err)
	}
	if task.Status != "queued" || task.Action != "run_status_json" || task.ApprovalStatus != "not_required" || task.TTLSeconds == 0 || task.ExpiresAt == "" || task.Attempt != 1 {
		t.Fatalf("unexpected created task: %+v", task)
	}
	bad := postJSON(t, h, "/api/v1/tasks", "", CreateTaskRequest{NodeID: "node-a", Action: "systemctl restart"})
	if bad.Code != http.StatusBadRequest {
		t.Fatalf("invalid action should return 400, got %d %s", bad.Code, bad.Body.String())
	}
	unauthorized := httptest.NewRecorder()
	h.ServeHTTP(unauthorized, httptest.NewRequest(http.MethodGet, "/api/v1/agent/tasks?node_id=node-a", nil))
	if unauthorized.Code != http.StatusUnauthorized {
		t.Fatalf("agent task API should require token, got %d", unauthorized.Code)
	}
	other := postJSON(t, h, "/api/v1/tasks", "", CreateTaskRequest{NodeID: "node-b", Action: "run_doctor"})
	if other.Code != http.StatusCreated {
		t.Fatalf("create node-b task failed: %d %s", other.Code, other.Body.String())
	}
	pickReq := httptest.NewRequest(http.MethodGet, "/api/v1/agent/tasks?node_id=node-a", nil)
	pickReq.Header.Set("Authorization", "Bearer test-token")
	pickOut := httptest.NewRecorder()
	h.ServeHTTP(pickOut, pickReq)
	if pickOut.Code != http.StatusOK {
		t.Fatalf("pick failed: %d %s", pickOut.Code, pickOut.Body.String())
	}
	if !strings.Contains(pickOut.Body.String(), `"node_id":"node-a"`) || strings.Contains(pickOut.Body.String(), `"node_id":"node-b"`) {
		t.Fatalf("agent received wrong node tasks: %s", pickOut.Body.String())
	}
	longOut := strings.Repeat("x", 70*1024) + " token=abc privateKey=key"
	result := postJSON(t, h, fmt.Sprintf("/api/v1/agent/tasks/%d/result", task.ID), "test-token", TaskResultRequest{
		Status:       "succeeded",
		ResultStdout: longOut,
		ResultStderr: "Authorization: Bearer abc custom_url=https://example.com?token=abc",
		ExitCode:     0,
		Error:        "password=abc",
	})
	if result.Code != http.StatusOK {
		t.Fatalf("result failed: %d %s", result.Code, result.Body.String())
	}
	body := result.Body.String()
	for _, leak := range []string{"token=abc", "Bearer abc", "privateKey=key", "password=abc"} {
		if strings.Contains(body, leak) {
			t.Fatalf("task result leaked %q: %s", leak, body)
		}
	}
	if !strings.Contains(body, "[TRUNCATED]") || !strings.Contains(body, `"status":"succeeded"`) {
		t.Fatalf("task result should be truncated and succeeded: %s", body)
	}
	timelineReq := httptest.NewRequest(http.MethodGet, fmt.Sprintf("/api/v1/tasks/%d/timeline", task.ID), nil)
	timelineOut := httptest.NewRecorder()
	h.ServeHTTP(timelineOut, timelineReq)
	if timelineOut.Code != http.StatusOK || !strings.Contains(timelineOut.Body.String(), "created") || !strings.Contains(timelineOut.Body.String(), "picked") || !strings.Contains(timelineOut.Body.String(), "result") || !strings.Contains(timelineOut.Body.String(), "succeeded") {
		t.Fatalf("timeline missing lifecycle events: %d %s", timelineOut.Code, timelineOut.Body.String())
	}
	listReq := httptest.NewRequest(http.MethodGet, "/api/v1/tasks", nil)
	listOut := httptest.NewRecorder()
	h.ServeHTTP(listOut, listReq)
	if listOut.Code != http.StatusOK || !strings.Contains(listOut.Body.String(), `"status":"succeeded"`) {
		t.Fatalf("list tasks unexpected: %d %s", listOut.Code, listOut.Body.String())
	}
}

func TestTaskCancelRetryApprovalExpiryAndTimeline(t *testing.T) {
	store, err := OpenStore(filepath.Join(t.TempDir(), "controller.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	h := NewServerWithAuth(store, ServerOptions{AgentToken: "test-token", OperatorToken: "operator-token"}, nil)

	cancelCreate := postJSON(t, h, "/api/v1/tasks", "", CreateTaskRequest{NodeID: "node-a", Action: "run_status"})
	var cancelTask Task
	if err := json.Unmarshal(cancelCreate.Body.Bytes(), &cancelTask); err != nil {
		t.Fatal(err)
	}
	cancelOut := httptest.NewRecorder()
	h.ServeHTTP(cancelOut, withOperator(httptest.NewRequest(http.MethodPost, fmt.Sprintf("/api/v1/tasks/%d/cancel", cancelTask.ID), nil)))
	if cancelOut.Code != http.StatusOK || !strings.Contains(cancelOut.Body.String(), `"status":"canceled"`) {
		t.Fatalf("cancel failed: %d %s", cancelOut.Code, cancelOut.Body.String())
	}

	approveCreate := postJSON(t, h, "/api/v1/tasks", "", CreateTaskRequest{NodeID: "node-a", Action: "run_doctor"})
	var approvalTask Task
	if err := json.Unmarshal(approveCreate.Body.Bytes(), &approvalTask); err != nil {
		t.Fatal(err)
	}
	approveOut := postJSON(t, h, fmt.Sprintf("/api/v1/tasks/%d/approve", approvalTask.ID), "", TaskApprovalRequest{Actor: "alice", Note: "token=abc"})
	if approveOut.Code != http.StatusOK || !strings.Contains(approveOut.Body.String(), `"approval_status":"approved"`) || strings.Contains(approveOut.Body.String(), "token=abc") {
		t.Fatalf("approve failed or leaked: %d %s", approveOut.Code, approveOut.Body.String())
	}
	rejectOut := postJSON(t, h, fmt.Sprintf("/api/v1/tasks/%d/reject", approvalTask.ID), "", TaskApprovalRequest{Actor: "bob"})
	if rejectOut.Code != http.StatusOK || !strings.Contains(rejectOut.Body.String(), `"approval_status":"rejected"`) {
		t.Fatalf("reject failed: %d %s", rejectOut.Code, rejectOut.Body.String())
	}
	approvalTimeline, err := store.TaskTimeline(context.Background(), approvalTask.ID)
	if err != nil {
		t.Fatal(err)
	}
	approvalActions := []string{}
	for _, item := range approvalTimeline {
		approvalActions = append(approvalActions, item.Action)
	}
	if !strings.Contains(strings.Join(approvalActions, ","), "approve") || !strings.Contains(strings.Join(approvalActions, ","), "reject") {
		t.Fatalf("approval timeline missing approve/reject actions: %+v", approvalTimeline)
	}

	failedCreate := postJSON(t, h, "/api/v1/tasks", "", CreateTaskRequest{NodeID: "node-a", Action: "ddns_overview"})
	var failedTask Task
	if err := json.Unmarshal(failedCreate.Body.Bytes(), &failedTask); err != nil {
		t.Fatal(err)
	}
	if _, err := store.db.Exec(`UPDATE tasks SET status='failed', finished_at=? WHERE id=?`, nowString(), failedTask.ID); err != nil {
		t.Fatal(err)
	}
	retryOut := httptest.NewRecorder()
	h.ServeHTTP(retryOut, withOperator(httptest.NewRequest(http.MethodPost, fmt.Sprintf("/api/v1/tasks/%d/retry", failedTask.ID), nil)))
	if retryOut.Code != http.StatusCreated || !strings.Contains(retryOut.Body.String(), `"retry_of_task_id":`) || !strings.Contains(retryOut.Body.String(), `"attempt":2`) {
		t.Fatalf("retry failed: %d %s", retryOut.Code, retryOut.Body.String())
	}

	expiredCreate := postJSON(t, h, "/api/v1/tasks", "", CreateTaskRequest{NodeID: "node-a", Action: "list_forwards", TTLSeconds: 1})
	var expiredTask Task
	if err := json.Unmarshal(expiredCreate.Body.Bytes(), &expiredTask); err != nil {
		t.Fatal(err)
	}
	if _, err := store.db.Exec(`UPDATE tasks SET expires_at=? WHERE id=?`, time.Now().Add(-time.Minute).UTC().Format(time.RFC3339), expiredTask.ID); err != nil {
		t.Fatal(err)
	}
	pickReq := httptest.NewRequest(http.MethodGet, "/api/v1/agent/tasks?node_id=node-a", nil)
	pickReq.Header.Set("Authorization", "Bearer test-token")
	pickOut := httptest.NewRecorder()
	h.ServeHTTP(pickOut, pickReq)
	if pickOut.Code != http.StatusOK || strings.Contains(pickOut.Body.String(), fmt.Sprintf(`"id":%d`, expiredTask.ID)) || strings.Contains(pickOut.Body.String(), `"status":"canceled"`) {
		t.Fatalf("agent pull returned expired/canceled task: %d %s", pickOut.Code, pickOut.Body.String())
	}
	gotExpired, err := store.GetTask(context.Background(), expiredTask.ID)
	if err != nil || gotExpired.Status != "expired" {
		t.Fatalf("expired task not marked: %+v err=%v", gotExpired, err)
	}
	timeline, err := store.TaskTimeline(context.Background(), cancelTask.ID)
	if err != nil || len(timeline) < 2 {
		t.Fatalf("cancel timeline missing: %+v err=%v", timeline, err)
	}
}

func TestPlanDryRunCreatesReadonlyTasksAndAggregates(t *testing.T) {
	h := testServer(t)
	report := ReportRequest{
		NodeID: "relay-1", NodeName: "relay", Role: "relay", Status: "online", IntervalSeconds: 30,
		Capabilities: AgentCapabilities{
			LQAvailable: true, SupportsStatusJSON: true, SupportsDoctorJSON: true,
			SupportsForwardList: true, SupportsDDNSOverview: true, EnableTasks: true,
		},
	}
	if rr := postJSON(t, h, "/api/v1/agent/report", "test-token", report); rr.Code != http.StatusOK {
		t.Fatalf("report failed: %d %s", rr.Code, rr.Body.String())
	}
	created := postJSON(t, h, "/api/v1/plans", "", map[string]any{
		"type":           "create_forward",
		"title":          "dry run forward",
		"target_node_id": "relay-1",
		"payload_json":   map[string]any{"token": "abc", "target_host": "10.0.0.8"},
	})
	if created.Code != http.StatusCreated {
		t.Fatalf("create plan failed: %d %s", created.Code, created.Body.String())
	}
	var plan Plan
	if err := json.Unmarshal(created.Body.Bytes(), &plan); err != nil {
		t.Fatal(err)
	}
	start := httptest.NewRecorder()
	h.ServeHTTP(start, withOperator(httptest.NewRequest(http.MethodPost, fmt.Sprintf("/api/v1/plans/%d/dry-run", plan.ID), nil)))
	if start.Code != http.StatusCreated {
		t.Fatalf("dry-run start failed: %d %s", start.Code, start.Body.String())
	}
	var running Plan
	if err := json.Unmarshal(start.Body.Bytes(), &running); err != nil {
		t.Fatal(err)
	}
	if running.DryRunStatus != "running" || len(running.DryRunTaskIDs) != 3 {
		t.Fatalf("dry-run did not queue expected tasks: %+v body=%s", running, start.Body.String())
	}
	for _, action := range []string{"run_status_json", "run_doctor_json", "list_forwards"} {
		if !strings.Contains(start.Body.String(), action) {
			t.Fatalf("dry-run missing readonly action %s: %s", action, start.Body.String())
		}
	}
	for _, forbidden := range []string{"systemctl", "restart", "nft", "iptables", "curl | bash", "token=abc"} {
		if strings.Contains(start.Body.String(), forbidden) {
			t.Fatalf("dry-run leaked or queued forbidden text %q: %s", forbidden, start.Body.String())
		}
	}
	for _, id := range running.DryRunTaskIDs {
		status := "succeeded"
		stdout := `{"overall":"OK","warnings":[]}`
		if id == running.DryRunTaskIDs[2] {
			stdout = "hk 10001 10.0.0.8 443 tcp,udp"
		}
		rr := postJSON(t, h, fmt.Sprintf("/api/v1/agent/tasks/%d/result", id), "test-token", TaskResultRequest{
			Status:       status,
			ResultStdout: stdout,
			ExitCode:     0,
		})
		if rr.Code != http.StatusOK {
			t.Fatalf("task result failed: %d %s", rr.Code, rr.Body.String())
		}
	}
	refresh := httptest.NewRecorder()
	h.ServeHTTP(refresh, httptest.NewRequest(http.MethodGet, fmt.Sprintf("/api/v1/plans/%d/dry-run", plan.ID), nil))
	if refresh.Code != http.StatusOK || !strings.Contains(refresh.Body.String(), `"dry_run_status":"passed"`) {
		t.Fatalf("dry-run aggregate should pass: %d %s", refresh.Code, refresh.Body.String())
	}
	if strings.Contains(refresh.Body.String(), "token=abc") {
		t.Fatalf("dry-run report leaked token: %s", refresh.Body.String())
	}
}

func TestPlanDryRunWarningFailedAndInvalidPlan(t *testing.T) {
	store, err := OpenStore(filepath.Join(t.TempDir(), "controller.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	h := NewServerWithAuth(store, ServerOptions{AgentToken: "test-token", OperatorToken: "operator-token"}, nil)
	missingReq := withOperator(httptest.NewRequest(http.MethodPost, "/api/v1/plans/999/dry-run", nil))
	missingOut := httptest.NewRecorder()
	h.ServeHTTP(missingOut, missingReq)
	if missingOut.Code != http.StatusNotFound {
		t.Fatalf("expected invalid plan id to return 404, got %d %s", missingOut.Code, missingOut.Body.String())
	}
	noTarget := postJSON(t, h, "/api/v1/plans", "", map[string]any{"type": "ddns_check", "title": "no target"})
	var noTargetPlan Plan
	if err := json.Unmarshal(noTarget.Body.Bytes(), &noTargetPlan); err != nil {
		t.Fatal(err)
	}
	noTargetOut := httptest.NewRecorder()
	h.ServeHTTP(noTargetOut, withOperator(httptest.NewRequest(http.MethodPost, fmt.Sprintf("/api/v1/plans/%d/dry-run", noTargetPlan.ID), nil)))
	if noTargetOut.Code != http.StatusOK && noTargetOut.Code != http.StatusCreated {
		t.Fatalf("no target dry-run should produce failed plan report: %d %s", noTargetOut.Code, noTargetOut.Body.String())
	}
	if !strings.Contains(noTargetOut.Body.String(), `"dry_run_status":"failed"`) || !strings.Contains(noTargetOut.Body.String(), "target node is required") {
		t.Fatalf("no target dry-run missing failed report: %s", noTargetOut.Body.String())
	}

	report := ReportRequest{
		NodeID: "relay-2", NodeName: "relay2", Role: "relay", Status: "online", IntervalSeconds: 30,
		Capabilities: AgentCapabilities{LQAvailable: true, SupportsStatusJSON: true, SupportsDoctorJSON: true, SupportsDDNSOverview: true, EnableTasks: true},
	}
	if rr := postJSON(t, h, "/api/v1/agent/report", "test-token", report); rr.Code != http.StatusOK {
		t.Fatalf("report failed: %d %s", rr.Code, rr.Body.String())
	}
	warnCreated := postJSON(t, h, "/api/v1/plans", "", map[string]any{"type": "ddns_check", "title": "warn", "target_node_id": "relay-2"})
	var warnPlan Plan
	if err := json.Unmarshal(warnCreated.Body.Bytes(), &warnPlan); err != nil {
		t.Fatal(err)
	}
	warnStart := httptest.NewRecorder()
	h.ServeHTTP(warnStart, withOperator(httptest.NewRequest(http.MethodPost, fmt.Sprintf("/api/v1/plans/%d/dry-run", warnPlan.ID), nil)))
	var warnRunning Plan
	if err := json.Unmarshal(warnStart.Body.Bytes(), &warnRunning); err != nil {
		t.Fatal(err)
	}
	if len(warnRunning.DryRunTaskIDs) != 2 {
		t.Fatalf("ddns_check should queue 2 tasks: %+v", warnRunning.DryRunTaskIDs)
	}
	_ = postJSON(t, h, fmt.Sprintf("/api/v1/agent/tasks/%d/result", warnRunning.DryRunTaskIDs[0]), "test-token", TaskResultRequest{Status: "succeeded", ResultStdout: "DDNS WARN token=abc", ExitCode: 0})
	_ = postJSON(t, h, fmt.Sprintf("/api/v1/agent/tasks/%d/result", warnRunning.DryRunTaskIDs[1]), "test-token", TaskResultRequest{Status: "succeeded", ResultStdout: `{"overall":"WARN","warnings":["token=abc stale ddns"]}`, ExitCode: 0})
	warnRefresh := httptest.NewRecorder()
	h.ServeHTTP(warnRefresh, httptest.NewRequest(http.MethodGet, fmt.Sprintf("/api/v1/plans/%d/dry-run", warnPlan.ID), nil))
	if warnRefresh.Code != http.StatusOK || !strings.Contains(warnRefresh.Body.String(), `"dry_run_status":"warning"`) {
		t.Fatalf("dry-run should warn: %d %s", warnRefresh.Code, warnRefresh.Body.String())
	}
	if strings.Contains(warnRefresh.Body.String(), "token=abc") {
		t.Fatalf("warning dry-run report leaked token: %s", warnRefresh.Body.String())
	}

	failCreated := postJSON(t, h, "/api/v1/plans", "", map[string]any{"type": "ddns_check", "title": "fail", "target_node_id": "relay-2"})
	var failPlan Plan
	if err := json.Unmarshal(failCreated.Body.Bytes(), &failPlan); err != nil {
		t.Fatal(err)
	}
	failStart := httptest.NewRecorder()
	h.ServeHTTP(failStart, withOperator(httptest.NewRequest(http.MethodPost, fmt.Sprintf("/api/v1/plans/%d/dry-run", failPlan.ID), nil)))
	var failRunning Plan
	if err := json.Unmarshal(failStart.Body.Bytes(), &failRunning); err != nil {
		t.Fatal(err)
	}
	_ = postJSON(t, h, fmt.Sprintf("/api/v1/agent/tasks/%d/result", failRunning.DryRunTaskIDs[0]), "test-token", TaskResultRequest{Status: "failed", Error: "password=abc failed", ExitCode: 1})
	_ = postJSON(t, h, fmt.Sprintf("/api/v1/agent/tasks/%d/result", failRunning.DryRunTaskIDs[1]), "test-token", TaskResultRequest{Status: "succeeded", ResultStdout: `{"overall":"OK"}`, ExitCode: 0})
	failRefresh := httptest.NewRecorder()
	h.ServeHTTP(failRefresh, httptest.NewRequest(http.MethodGet, fmt.Sprintf("/api/v1/plans/%d/dry-run", failPlan.ID), nil))
	if failRefresh.Code != http.StatusOK || !strings.Contains(failRefresh.Body.String(), `"dry_run_status":"failed"`) {
		t.Fatalf("dry-run should fail: %d %s", failRefresh.Code, failRefresh.Body.String())
	}
	if strings.Contains(failRefresh.Body.String(), "password=abc") {
		t.Fatalf("failed dry-run report leaked password: %s", failRefresh.Body.String())
	}
}

func TestPlanSnapshotRollbackSafetyGateAndVerify(t *testing.T) {
	store, err := OpenStore(filepath.Join(t.TempDir(), "controller.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	h := NewServerWithAuth(store, ServerOptions{AgentToken: "test-token", OperatorToken: "operator-token"}, nil)

	forwardCreated := postJSON(t, h, "/api/v1/plans", "", map[string]any{
		"type":           "create_forward",
		"title":          "forward with snapshot",
		"target_node_id": "relay-1",
	})
	if forwardCreated.Code != http.StatusCreated {
		t.Fatalf("create forward plan failed: %d %s", forwardCreated.Code, forwardCreated.Body.String())
	}
	var forwardPlan Plan
	if err := json.Unmarshal(forwardCreated.Body.Bytes(), &forwardPlan); err != nil {
		t.Fatal(err)
	}
	if forwardPlan.SnapshotPolicy != "required" || !forwardPlan.SnapshotRequired || forwardPlan.SnapshotStatus != "missing" {
		t.Fatalf("create_forward snapshot defaults wrong: %+v", forwardPlan)
	}

	switchCreated := postJSON(t, h, "/api/v1/plans", "", map[string]any{"type": "switch_entry", "title": "switch", "target_node_id": "relay-1"})
	var switchPlan Plan
	if err := json.Unmarshal(switchCreated.Body.Bytes(), &switchPlan); err != nil {
		t.Fatal(err)
	}
	if switchPlan.SnapshotPolicy != "required" {
		t.Fatalf("switch_entry snapshot policy should be required: %+v", switchPlan)
	}
	ddnsCreated := postJSON(t, h, "/api/v1/plans", "", map[string]any{"type": "ddns_check", "title": "ddns", "target_node_id": "relay-1"})
	var ddnsPlan Plan
	if err := json.Unmarshal(ddnsCreated.Body.Bytes(), &ddnsPlan); err != nil {
		t.Fatal(err)
	}
	if ddnsPlan.SnapshotPolicy != "recommended" || ddnsPlan.SnapshotRequired {
		t.Fatalf("ddns_check snapshot policy should be recommended: %+v", ddnsPlan)
	}

	generateOut := httptest.NewRecorder()
	h.ServeHTTP(generateOut, withOperator(httptest.NewRequest(http.MethodPost, fmt.Sprintf("/api/v1/plans/%d/generate", forwardPlan.ID), nil)))
	if generateOut.Code != http.StatusOK || !strings.Contains(generateOut.Body.String(), "rollback_instructions") {
		t.Fatalf("generate should include rollback instructions: %d %s", generateOut.Code, generateOut.Body.String())
	}
	for _, dangerous := range []string{"systemctl restart", "nft ", "iptables", "rm -", "curl | bash", "bash -c", "eval "} {
		if strings.Contains(generateOut.Body.String(), dangerous) {
			t.Fatalf("rollback instructions contain dangerous command %q: %s", dangerous, generateOut.Body.String())
		}
	}

	gateOut := httptest.NewRecorder()
	h.ServeHTTP(gateOut, httptest.NewRequest(http.MethodGet, fmt.Sprintf("/api/v1/plans/%d/safety-gate", forwardPlan.ID), nil))
	if gateOut.Code != http.StatusOK || !strings.Contains(gateOut.Body.String(), "dry-run has not passed") || !strings.Contains(gateOut.Body.String(), "required snapshot metadata is missing") {
		t.Fatalf("safety gate should block missing dry-run and snapshot: %d %s", gateOut.Code, gateOut.Body.String())
	}

	beforeTasks := countTasks(t, store)
	snapshotOut := postJSON(t, h, fmt.Sprintf("/api/v1/plans/%d/snapshot", forwardPlan.ID), "", PlanSnapshotRequest{
		SnapshotRef:  "snapshot token=abc",
		SnapshotNote: "privateKey=key",
	})
	if snapshotOut.Code != http.StatusOK || !strings.Contains(snapshotOut.Body.String(), `"snapshot_status":"recorded"`) {
		t.Fatalf("snapshot metadata failed: %d %s", snapshotOut.Code, snapshotOut.Body.String())
	}
	if strings.Contains(snapshotOut.Body.String(), "token=abc") || strings.Contains(snapshotOut.Body.String(), "privateKey=key") {
		t.Fatalf("snapshot metadata leaked secret: %s", snapshotOut.Body.String())
	}
	if countTasks(t, store) != beforeTasks {
		t.Fatalf("snapshot metadata should not create tasks")
	}

	rollbackOut := postJSON(t, h, fmt.Sprintf("/api/v1/plans/%d/rollback-info", forwardPlan.ID), "", PlanRollbackInfoRequest{
		RollbackRef:  "rollback token=abc",
		RollbackNote: "password=abc",
	})
	if rollbackOut.Code != http.StatusOK || !strings.Contains(rollbackOut.Body.String(), `"rollback_available":true`) {
		t.Fatalf("rollback metadata failed: %d %s", rollbackOut.Code, rollbackOut.Body.String())
	}
	if strings.Contains(rollbackOut.Body.String(), "token=abc") || strings.Contains(rollbackOut.Body.String(), "password=abc") {
		t.Fatalf("rollback metadata leaked secret: %s", rollbackOut.Body.String())
	}
	if countTasks(t, store) != beforeTasks {
		t.Fatalf("rollback metadata should not create tasks")
	}

	if _, err := store.db.Exec(`UPDATE plans SET dry_run_status='passed' WHERE id=?`, forwardPlan.ID); err != nil {
		t.Fatal(err)
	}
	verifyOut := httptest.NewRecorder()
	h.ServeHTTP(verifyOut, withOperator(httptest.NewRequest(http.MethodPost, fmt.Sprintf("/api/v1/plans/%d/verify", forwardPlan.ID), nil)))
	if verifyOut.Code != http.StatusOK || !strings.Contains(verifyOut.Body.String(), `"verification_status":"passed"`) {
		t.Fatalf("verify should pass after dry-run/snapshot/rollback metadata: %d %s", verifyOut.Code, verifyOut.Body.String())
	}
	if countTasks(t, store) != beforeTasks {
		t.Fatalf("verify should not create tasks")
	}

	missingOut := postJSON(t, h, "/api/v1/plans/999/snapshot", "", PlanSnapshotRequest{SnapshotRef: "x"})
	if missingOut.Code != http.StatusNotFound {
		t.Fatalf("missing plan snapshot should 404, got %d %s", missingOut.Code, missingOut.Body.String())
	}
}

func TestPlanMetadataActionsAreControllerOnly(t *testing.T) {
	store, err := OpenStore(filepath.Join(t.TempDir(), "controller.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	h := NewServerWithAuth(store, ServerOptions{AgentToken: "test-token", OperatorToken: "operator-token"}, nil)
	report := ReportRequest{
		NodeID: "relay-1", NodeName: "relay", Role: "relay", Status: "online", IntervalSeconds: 30,
		Entries:  []EntryPayload{{Name: "public1", ListenPort: 8301, Protocol: "tcp,udp", PublicHost: "home.example.com", Status: "ok"}},
		Forwards: []ForwardPayload{{Name: "hk", EntryName: "public1", TargetHost: "10.0.0.8", TargetPort: 443, Protocol: "tcp,udp", Status: "ok"}},
	}
	if rr := postJSON(t, h, "/api/v1/agent/report", "test-token", report); rr.Code != http.StatusOK {
		t.Fatalf("report failed: %d %s", rr.Code, rr.Body.String())
	}
	created := postJSON(t, h, "/api/v1/plans", "", map[string]any{"type": "create_forward", "title": "metadata", "target_node_id": "relay-1"})
	if created.Code != http.StatusCreated {
		t.Fatalf("create plan failed: %d %s", created.Code, created.Body.String())
	}
	var plan Plan
	if err := json.Unmarshal(created.Body.Bytes(), &plan); err != nil {
		t.Fatal(err)
	}
	noAuthReq := httptest.NewRequest(http.MethodPost, fmt.Sprintf("/api/v1/plans/%d/metadata-action", plan.ID), strings.NewReader(`{"action":"mark_plan_executed"}`))
	noAuthReq.Header.Set("Content-Type", "application/json")
	noAuth := httptest.NewRecorder()
	h.ServeHTTP(noAuth, noAuthReq)
	if noAuth.Code != http.StatusUnauthorized {
		t.Fatalf("metadata action should require operator token, got %d %s", noAuth.Code, noAuth.Body.String())
	}
	agentAuth := postJSON(t, h, fmt.Sprintf("/api/v1/plans/%d/metadata-action", plan.ID), "test-token", PlanMetadataActionRequest{Action: "mark_plan_executed"})
	if agentAuth.Code != http.StatusUnauthorized {
		t.Fatalf("agent token must not call metadata action, got %d %s", agentAuth.Code, agentAuth.Body.String())
	}
	unknown := postJSON(t, h, fmt.Sprintf("/api/v1/plans/%d/metadata-action", plan.ID), "", PlanMetadataActionRequest{Action: "unknown_action"})
	if unknown.Code != http.StatusBadRequest {
		t.Fatalf("unknown metadata action should return 400, got %d %s", unknown.Code, unknown.Body.String())
	}
	blocked := postJSON(t, h, fmt.Sprintf("/api/v1/plans/%d/metadata-action", plan.ID), "", PlanMetadataActionRequest{Action: "restart_relay"})
	if blocked.Code != http.StatusBadRequest {
		t.Fatalf("blocked/future node action should return 400, got %d %s", blocked.Code, blocked.Body.String())
	}

	nodesBefore := httptest.NewRecorder()
	h.ServeHTTP(nodesBefore, httptest.NewRequest(http.MethodGet, "/api/v1/nodes", nil))
	entriesBefore := httptest.NewRecorder()
	h.ServeHTTP(entriesBefore, httptest.NewRequest(http.MethodGet, "/api/v1/entries", nil))
	forwardsBefore := httptest.NewRecorder()
	h.ServeHTTP(forwardsBefore, httptest.NewRequest(http.MethodGet, "/api/v1/forwards", nil))
	beforeTasks := countTasks(t, store)

	snapshot := postJSON(t, h, fmt.Sprintf("/api/v1/plans/%d/metadata-action", plan.ID), "", PlanMetadataActionRequest{
		Action:       "record_snapshot_ref",
		SnapshotRef:  "snapshot token=abc",
		SnapshotNote: "operator_token=operator-token",
	})
	if snapshot.Code != http.StatusOK || !strings.Contains(snapshot.Body.String(), `"snapshot_status":"recorded"`) {
		t.Fatalf("record snapshot metadata failed: %d %s", snapshot.Code, snapshot.Body.String())
	}
	rollback := postJSON(t, h, fmt.Sprintf("/api/v1/plans/%d/metadata-action", plan.ID), "", PlanMetadataActionRequest{
		Action:       "record_rollback_ref",
		RollbackRef:  "rollback controller_token=test-token",
		RollbackNote: "password=rollback-secret",
	})
	if rollback.Code != http.StatusOK || !strings.Contains(rollback.Body.String(), `"rollback_available":true`) {
		t.Fatalf("record rollback metadata failed: %d %s", rollback.Code, rollback.Body.String())
	}
	executed := postJSON(t, h, fmt.Sprintf("/api/v1/plans/%d/metadata-action", plan.ID), "", PlanMetadataActionRequest{
		Action:          "mark_plan_executed",
		ExecutionStatus: "succeeded",
		Note:            "manual execution operator_token=operator-token",
		Content:         "manual result password=secret",
	})
	if executed.Code != http.StatusOK || !strings.Contains(executed.Body.String(), `"execution_status":"succeeded"`) || !strings.Contains(executed.Body.String(), "operator:") {
		t.Fatalf("mark executed failed: %d %s", executed.Code, executed.Body.String())
	}
	verified := postJSON(t, h, fmt.Sprintf("/api/v1/plans/%d/metadata-action", plan.ID), "", PlanMetadataActionRequest{
		Action:             "mark_plan_verified",
		VerificationStatus: "passed",
		Note:               "verified custom_url=https://example.com?token=abc",
	})
	if verified.Code != http.StatusOK || !strings.Contains(verified.Body.String(), `"verification_status":"passed"`) || !strings.Contains(verified.Body.String(), "operator:") {
		t.Fatalf("mark verified failed: %d %s", verified.Code, verified.Body.String())
	}
	evidence := postJSON(t, h, fmt.Sprintf("/api/v1/plans/%d/metadata-action", plan.ID), "", PlanMetadataActionRequest{
		Action:       "attach_manual_evidence",
		EvidenceType: "post-check",
		Title:        "lq status",
		Content:      "status ok custom_cmd=cmd --token abc privateKey=key",
	})
	if evidence.Code != http.StatusOK {
		t.Fatalf("attach evidence metadata action failed: %d %s", evidence.Code, evidence.Body.String())
	}
	directEvidence := postJSON(t, h, fmt.Sprintf("/api/v1/plans/%d/evidence", plan.ID), "", PlanEvidenceRequest{
		EvidenceType: "manual",
		Title:        "operator note",
		Content:      "Authorization: Bearer abc secret=direct",
	})
	if directEvidence.Code != http.StatusCreated {
		t.Fatalf("direct evidence failed: %d %s", directEvidence.Code, directEvidence.Body.String())
	}
	evidenceList := httptest.NewRecorder()
	h.ServeHTTP(evidenceList, httptest.NewRequest(http.MethodGet, fmt.Sprintf("/api/v1/plans/%d/evidence", plan.ID), nil))
	if evidenceList.Code != http.StatusOK || !strings.Contains(evidenceList.Body.String(), "operator:") {
		t.Fatalf("evidence list unexpected: %d %s", evidenceList.Code, evidenceList.Body.String())
	}
	for _, leak := range []string{"token=abc", "operator-token", "test-token", "password=secret", "privateKey=key", "Bearer abc", "secret=direct"} {
		for _, body := range []string{snapshot.Body.String(), rollback.Body.String(), executed.Body.String(), verified.Body.String(), evidence.Body.String(), directEvidence.Body.String(), evidenceList.Body.String()} {
			if strings.Contains(body, leak) {
				t.Fatalf("metadata action leaked %q in %s", leak, body)
			}
		}
	}

	gateOut := httptest.NewRecorder()
	h.ServeHTTP(gateOut, httptest.NewRequest(http.MethodGet, fmt.Sprintf("/api/v1/plans/%d/safety-gate", plan.ID), nil))
	if gateOut.Code != http.StatusOK || !strings.Contains(gateOut.Body.String(), `"metadata_actions_ready":true`) || !strings.Contains(gateOut.Body.String(), `"manual_execution_recorded":true`) || !strings.Contains(gateOut.Body.String(), `"manual_verification_recorded":true`) || !strings.Contains(gateOut.Body.String(), `"evidence_count":2`) {
		t.Fatalf("safety gate missing metadata readiness: %d %s", gateOut.Code, gateOut.Body.String())
	}
	if countTasks(t, store) != beforeTasks {
		t.Fatalf("metadata actions must not create Agent tasks")
	}
	nodesAfter := httptest.NewRecorder()
	h.ServeHTTP(nodesAfter, httptest.NewRequest(http.MethodGet, "/api/v1/nodes", nil))
	entriesAfter := httptest.NewRecorder()
	h.ServeHTTP(entriesAfter, httptest.NewRequest(http.MethodGet, "/api/v1/entries", nil))
	forwardsAfter := httptest.NewRecorder()
	h.ServeHTTP(forwardsAfter, httptest.NewRequest(http.MethodGet, "/api/v1/forwards", nil))
	if nodesBefore.Body.String() != nodesAfter.Body.String() || entriesBefore.Body.String() != entriesAfter.Body.String() || forwardsBefore.Body.String() != forwardsAfter.Body.String() {
		t.Fatalf("metadata actions must not modify nodes/entries/forwards")
	}
	eventsOut := httptest.NewRecorder()
	h.ServeHTTP(eventsOut, httptest.NewRequest(http.MethodGet, "/api/v1/events", nil))
	if strings.Contains(eventsOut.Body.String(), "operator-token") || strings.Contains(eventsOut.Body.String(), "test-token") {
		t.Fatalf("events leaked token: %s", eventsOut.Body.String())
	}
	planOut := httptest.NewRecorder()
	h.ServeHTTP(planOut, httptest.NewRequest(http.MethodGet, fmt.Sprintf("/api/v1/plans/%d", plan.ID), nil))
	if strings.Contains(planOut.Body.String(), "operator-token") || strings.Contains(planOut.Body.String(), "test-token") || !strings.Contains(planOut.Body.String(), "operator:") {
		t.Fatalf("plan timeline should contain fingerprint only: %s", planOut.Body.String())
	}
	missing := postJSON(t, h, "/api/v1/plans/999/metadata-action", "", PlanMetadataActionRequest{Action: "mark_plan_executed"})
	if missing.Code != http.StatusNotFound {
		t.Fatalf("missing plan metadata action should 404, got %d %s", missing.Code, missing.Body.String())
	}
}

func TestActionCatalogAndReviewSafetyBoundary(t *testing.T) {
	store, err := OpenStore(filepath.Join(t.TempDir(), "controller.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	h := NewServerWithAuth(store, ServerOptions{AgentToken: "test-token", OperatorToken: "operator-token"}, nil)
	report := ReportRequest{
		NodeID: "relay-1", NodeName: "relay", Role: "relay", Status: "online", IntervalSeconds: 30,
		Entries:  []EntryPayload{{Name: "public1", ListenPort: 8301, Protocol: "tcp,udp", PublicHost: "home.example.com", Status: "ok"}},
		Forwards: []ForwardPayload{{Name: "hk", EntryName: "public1", TargetHost: "10.0.0.8", TargetPort: 443, Protocol: "tcp,udp", Status: "ok"}},
	}
	if rr := postJSON(t, h, "/api/v1/agent/report", "test-token", report); rr.Code != http.StatusOK {
		t.Fatalf("report failed: %d %s", rr.Code, rr.Body.String())
	}

	catalogOut := httptest.NewRecorder()
	h.ServeHTTP(catalogOut, httptest.NewRequest(http.MethodGet, "/api/v1/action-catalog", nil))
	if catalogOut.Code != http.StatusOK {
		t.Fatalf("catalog failed: %d %s", catalogOut.Code, catalogOut.Body.String())
	}
	body := catalogOut.Body.String()
	for _, want := range []string{"readonly", "future_write_low", "future_write_guarded", "future_write_dangerous", "metadata_write", "record_snapshot_ref", `"node_mutation":false`, `"agent_required":false`, `"command_dispatch":false`, "blocked", "arbitrary_command", `"enabled":false`} {
		if !strings.Contains(body, want) {
			t.Fatalf("catalog missing %q: %s", want, body)
		}
	}
	if !strings.Contains(body, `"action":"record_snapshot_ref"`) || !strings.Contains(body, `"enabled":true`) {
		t.Fatalf("metadata action should be enabled in catalog: %s", body)
	}
	blockedOut := httptest.NewRecorder()
	h.ServeHTTP(blockedOut, httptest.NewRequest(http.MethodGet, "/api/v1/action-catalog/arbitrary_command", nil))
	if blockedOut.Code != http.StatusOK || !strings.Contains(blockedOut.Body.String(), `"category":"blocked"`) || !strings.Contains(blockedOut.Body.String(), `"enabled":false`) {
		t.Fatalf("blocked action detail unexpected: %d %s", blockedOut.Code, blockedOut.Body.String())
	}

	createBody := map[string]any{
		"type":           "create_forward",
		"title":          "review forward",
		"target_node_id": "relay-1",
		"payload_json": map[string]any{
			"target_host": "10.0.0.8",
			"token":       "abc",
			"custom_cmd":  "cmd --token abc",
			"privateKey":  "key",
		},
	}
	created := postJSON(t, h, "/api/v1/plans", "", createBody)
	if created.Code != http.StatusCreated {
		t.Fatalf("create plan failed: %d %s", created.Code, created.Body.String())
	}
	var plan Plan
	if err := json.Unmarshal(created.Body.Bytes(), &plan); err != nil {
		t.Fatal(err)
	}
	nodesBefore := httptest.NewRecorder()
	h.ServeHTTP(nodesBefore, httptest.NewRequest(http.MethodGet, "/api/v1/nodes", nil))
	entriesBefore := httptest.NewRecorder()
	h.ServeHTTP(entriesBefore, httptest.NewRequest(http.MethodGet, "/api/v1/entries", nil))
	forwardsBefore := httptest.NewRecorder()
	h.ServeHTTP(forwardsBefore, httptest.NewRequest(http.MethodGet, "/api/v1/forwards", nil))
	beforeTasks := countTasks(t, store)

	reviewOut := httptest.NewRecorder()
	h.ServeHTTP(reviewOut, withOperator(httptest.NewRequest(http.MethodPost, fmt.Sprintf("/api/v1/plans/%d/action-review", plan.ID), nil)))
	if reviewOut.Code != http.StatusOK {
		t.Fatalf("action review failed: %d %s", reviewOut.Code, reviewOut.Body.String())
	}
	reviewBody := reviewOut.Body.String()
	for _, want := range []string{`"matched_action":"create_forward"`, `"ready_for_future_execution":false`, writeExecutionDisabledReason, "dry-run", "snapshot", "approval", "rollback"} {
		if !strings.Contains(reviewBody, want) {
			t.Fatalf("action review missing %q: %s", want, reviewBody)
		}
	}
	for _, leak := range []string{"token=abc", "--token abc", "privateKey", "custom_cmd"} {
		if strings.Contains(reviewBody, leak) {
			t.Fatalf("action review leaked %q: %s", leak, reviewBody)
		}
	}
	if countTasks(t, store) != beforeTasks {
		t.Fatalf("action review must not create tasks")
	}
	nodesAfter := httptest.NewRecorder()
	h.ServeHTTP(nodesAfter, httptest.NewRequest(http.MethodGet, "/api/v1/nodes", nil))
	entriesAfter := httptest.NewRecorder()
	h.ServeHTTP(entriesAfter, httptest.NewRequest(http.MethodGet, "/api/v1/entries", nil))
	forwardsAfter := httptest.NewRecorder()
	h.ServeHTTP(forwardsAfter, httptest.NewRequest(http.MethodGet, "/api/v1/forwards", nil))
	if nodesBefore.Body.String() != nodesAfter.Body.String() || entriesBefore.Body.String() != entriesAfter.Body.String() || forwardsBefore.Body.String() != forwardsAfter.Body.String() {
		t.Fatalf("action review must not modify node/entry/forward data")
	}

	switchCreated := postJSON(t, h, "/api/v1/plans", "", map[string]any{"type": "switch_entry", "title": "switch", "target_node_id": "relay-1"})
	var switchPlan Plan
	if err := json.Unmarshal(switchCreated.Body.Bytes(), &switchPlan); err != nil {
		t.Fatal(err)
	}
	switchReview := httptest.NewRecorder()
	h.ServeHTTP(switchReview, httptest.NewRequest(http.MethodGet, fmt.Sprintf("/api/v1/plans/%d/action-review", switchPlan.ID), nil))
	if switchReview.Code != http.StatusOK || !(strings.Contains(switchReview.Body.String(), `"risk_level":"critical"`) || strings.Contains(switchReview.Body.String(), `"risk_level":"high"`)) {
		t.Fatalf("switch action review should be high/critical risk: %d %s", switchReview.Code, switchReview.Body.String())
	}
}

func TestPanelDemoNetworkForwardApply(t *testing.T) {
	store, err := OpenStore(filepath.Join(t.TempDir(), "controller.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	h := NewServerWithAuth(store, ServerOptions{AgentToken: "agent-token", OperatorToken: "operator-token"}, nil)
	entryReport := ReportRequest{
		NodeID: "entry-1", NodeName: "entry", Role: "entry", Status: "online", IntervalSeconds: 30,
		Capabilities: AgentCapabilities{WriteActionsSupported: true, SupportedWriteActions: alphaWriteActions(), EnableTasks: true},
	}
	relayReport := ReportRequest{
		NodeID: "relay-1", NodeName: "relay", Role: "relay", Status: "online", IntervalSeconds: 30,
		Capabilities: AgentCapabilities{WriteActionsSupported: true, SupportedWriteActions: alphaWriteActions(), EnableTasks: true},
	}
	disabledReport := ReportRequest{
		NodeID: "relay-disabled", NodeName: "disabled", Role: "relay", Status: "online", IntervalSeconds: 30,
		Capabilities: AgentCapabilities{WriteActionsSupported: false, EnableTasks: true},
	}
	for _, report := range []ReportRequest{entryReport, relayReport, disabledReport} {
		if rr := postJSON(t, h, "/api/v1/agent/report", "agent-token", report); rr.Code != http.StatusOK {
			t.Fatalf("report failed: %d %s", rr.Code, rr.Body.String())
		}
	}
	noAuthReq := httptest.NewRequest(http.MethodPost, "/api/v1/network-profiles", strings.NewReader(`{"name":"n","relay_node_id":"relay-1"}`))
	noAuthReq.Header.Set("Content-Type", "application/json")
	noAuthOut := httptest.NewRecorder()
	h.ServeHTTP(noAuthOut, noAuthReq)
	if noAuthOut.Code != http.StatusUnauthorized {
		t.Fatalf("network profile should require operator token, got %d %s", noAuthOut.Code, noAuthOut.Body.String())
	}
	agentTokenNetwork := postJSON(t, h, "/api/v1/network-profiles", "agent-token", NetworkProfileRequest{Name: "n", RelayNodeID: "relay-1"})
	if agentTokenNetwork.Code != http.StatusUnauthorized {
		t.Fatalf("agent token must not create network profile: %d %s", agentTokenNetwork.Code, agentTokenNetwork.Body.String())
	}
	profileResp := postJSON(t, h, "/api/v1/network-profiles", "", NetworkProfileRequest{Name: "demo", RelayNodeID: "relay-1", NetworkSecret: "network_secret=super-secret"})
	if profileResp.Code != http.StatusCreated {
		t.Fatalf("create network failed: %d %s", profileResp.Code, profileResp.Body.String())
	}
	if strings.Contains(profileResp.Body.String(), "super-secret") || !strings.Contains(profileResp.Body.String(), "REDACTED") {
		t.Fatalf("network secret not redacted: %s", profileResp.Body.String())
	}
	var profile NetworkProfile
	if err := json.Unmarshal(profileResp.Body.Bytes(), &profile); err != nil {
		t.Fatal(err)
	}
	entryResp := postJSON(t, h, "/api/v1/entries", "", PanelEntryRequest{
		NetworkID: profile.ID, EntryNodeID: "entry-1", RelayNodeID: "relay-1", ListenHost: "0.0.0.0", ListenPortStart: 10000, ListenPortEnd: 19999, Protocols: "both",
	})
	if entryResp.Code != http.StatusCreated {
		t.Fatalf("create entry failed: %d %s", entryResp.Code, entryResp.Body.String())
	}
	var entry PanelEntry
	if err := json.Unmarshal(entryResp.Body.Bytes(), &entry); err != nil {
		t.Fatal(err)
	}
	forwardResp := postJSON(t, h, "/api/v1/forwards", "", PanelForwardRequest{
		NetworkID: profile.ID, EntryID: entry.ID, RelayNodeID: "relay-1", Name: "web", ListenPort: 10001, TargetHost: "10.0.0.8", TargetPort: 443, Protocol: "both",
	})
	if forwardResp.Code != http.StatusCreated {
		t.Fatalf("create forward failed: %d %s", forwardResp.Code, forwardResp.Body.String())
	}
	var forward PanelForward
	if err := json.Unmarshal(forwardResp.Body.Bytes(), &forward); err != nil {
		t.Fatal(err)
	}
	beforeTasks := countTasks(t, store)
	applyResp := postJSON(t, h, fmt.Sprintf("/api/v1/forwards/%d/apply", forward.ID), "", nil)
	if applyResp.Code != http.StatusCreated {
		t.Fatalf("apply forward failed: %d %s", applyResp.Code, applyResp.Body.String())
	}
	var apply ApplyResponse
	if err := json.Unmarshal(applyResp.Body.Bytes(), &apply); err != nil {
		t.Fatal(err)
	}
	if len(apply.TaskIDs) != 6 || !strings.Contains(apply.Message, "backend target does not need an Agent") {
		t.Fatalf("apply forward should create entry/relay tasks only: %+v", apply)
	}
	tasks, err := store.GetTasksByIDs(context.Background(), apply.TaskIDs)
	if err != nil {
		t.Fatal(err)
	}
	nodes := map[string]bool{}
	actions := map[string]int{}
	for _, task := range tasks {
		nodes[task.NodeID] = true
		actions[task.Action]++
		if task.TaskGroupID != apply.TaskGroupID {
			t.Fatalf("task group mismatch: %+v", task)
		}
		if strings.Contains(string(task.PayloadJSON), "super-secret") || strings.Contains(string(task.PayloadJSON), "network_secret=super-secret") {
			t.Fatalf("task payload leaked network secret: %s", task.PayloadJSON)
		}
	}
	if len(nodes) != 2 || !nodes["entry-1"] || !nodes["relay-1"] || nodes["10.0.0.8"] {
		t.Fatalf("unexpected apply task nodes: %+v", nodes)
	}
	for _, action := range []string{"apply_entry_ports", "apply_forward_rules", "reload_firewall_rules", "verify_config"} {
		if actions[action] == 0 {
			t.Fatalf("missing apply action %s in %+v", action, actions)
		}
	}
	if countTasks(t, store)-beforeTasks != 6 {
		t.Fatalf("unexpected task count after apply")
	}
	blocked := postJSON(t, h, "/api/v1/tasks", "", CreateTaskRequest{NodeID: "relay-1", Action: "restart_relay"})
	if blocked.Code != http.StatusBadRequest {
		t.Fatalf("restart_relay must remain blocked: %d %s", blocked.Code, blocked.Body.String())
	}
	badPayload := postJSON(t, h, "/api/v1/tasks", "", CreateTaskRequest{NodeID: "relay-1", Action: "apply_forward_rules", PayloadJSON: json.RawMessage(`{"command":"rm -rf /"}`)})
	if badPayload.Code != http.StatusBadRequest {
		t.Fatalf("payload command field must be rejected: %d %s", badPayload.Code, badPayload.Body.String())
	}
	disabledProfileResp := postJSON(t, h, "/api/v1/network-profiles", "", NetworkProfileRequest{Name: "disabled", RelayNodeID: "relay-disabled"})
	var disabledProfile NetworkProfile
	if err := json.Unmarshal(disabledProfileResp.Body.Bytes(), &disabledProfile); err != nil {
		t.Fatal(err)
	}
	disabledEntryResp := postJSON(t, h, "/api/v1/entries", "", PanelEntryRequest{NetworkID: disabledProfile.ID, EntryNodeID: "entry-1", RelayNodeID: "relay-disabled", ListenPortStart: 10000, ListenPortEnd: 10010, Protocols: "tcp"})
	var disabledEntry PanelEntry
	if err := json.Unmarshal(disabledEntryResp.Body.Bytes(), &disabledEntry); err != nil {
		t.Fatal(err)
	}
	disabledForwardResp := postJSON(t, h, "/api/v1/forwards", "", PanelForwardRequest{NetworkID: disabledProfile.ID, EntryID: disabledEntry.ID, RelayNodeID: "relay-disabled", Name: "disabled", ListenPort: 10002, TargetHost: "10.0.0.9", TargetPort: 80, Protocol: "tcp"})
	var disabledForward PanelForward
	if err := json.Unmarshal(disabledForwardResp.Body.Bytes(), &disabledForward); err != nil {
		t.Fatal(err)
	}
	disabledApply := postJSON(t, h, fmt.Sprintf("/api/v1/forwards/%d/apply", disabledForward.ID), "", nil)
	if disabledApply.Code != http.StatusBadRequest || !strings.Contains(disabledApply.Body.String(), "does not enable alpha write actions") {
		t.Fatalf("write-disabled relay should reject apply: %d %s", disabledApply.Code, disabledApply.Body.String())
	}
}

func TestPanel3PBRDDNSLoginAndNodeActions(t *testing.T) {
	store, err := OpenStore(filepath.Join(t.TempDir(), "controller.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	h := NewServerWithAuth(store, ServerOptions{AgentToken: "agent-token", OperatorToken: "operator-token"}, nil)
	if login := postJSON(t, h, "/api/v1/login", "", LoginRequest{Token: "operator-token"}); login.Code != http.StatusOK || !strings.Contains(login.Body.String(), "operator:") {
		t.Fatalf("login failed: %d %s", login.Code, login.Body.String())
	}
	report := ReportRequest{
		NodeID: "relay-1", NodeName: "relay", Role: "relay", Status: "online", IntervalSeconds: 30,
		Capabilities: AgentCapabilities{WriteActionsSupported: true, SupportedWriteActions: alphaWriteActions(), EnableTasks: true},
	}
	if rr := postJSON(t, h, "/api/v1/agent/report", "agent-token", report); rr.Code != http.StatusOK {
		t.Fatalf("report failed: %d %s", rr.Code, rr.Body.String())
	}
	pbrReq := PBRPolicyRequest{Name: "wan", RelayNodeID: "relay-1", SourceCIDR: "10.0.0.0/24", TargetCIDR: "0.0.0.0/0", OutputInterface: "eth0", Gateway: "192.0.2.1", TableID: 100, Priority: 1000}
	if noAuth := postJSON(t, h, "/api/v1/pbr-policies", "agent-token", pbrReq); noAuth.Code != http.StatusUnauthorized {
		t.Fatalf("agent token must not create pbr: %d %s", noAuth.Code, noAuth.Body.String())
	}
	pbrResp := postJSON(t, h, "/api/v1/pbr-policies", "", pbrReq)
	if pbrResp.Code != http.StatusCreated {
		t.Fatalf("create pbr failed: %d %s", pbrResp.Code, pbrResp.Body.String())
	}
	var pbr PBRPolicy
	if err := json.Unmarshal(pbrResp.Body.Bytes(), &pbr); err != nil {
		t.Fatal(err)
	}
	pbrApply := postJSON(t, h, fmt.Sprintf("/api/v1/pbr-policies/%d/apply", pbr.ID), "", nil)
	if pbrApply.Code != http.StatusCreated {
		t.Fatalf("apply pbr failed: %d %s", pbrApply.Code, pbrApply.Body.String())
	}
	ddnsResp := postJSON(t, h, "/api/v1/ddns-profiles", "", DDNSProfileRequest{NodeID: "relay-1", Provider: "manual", Domain: "home.example.com", RecordType: "A", APIToken: "secret-token"})
	if ddnsResp.Code != http.StatusCreated || strings.Contains(ddnsResp.Body.String(), "secret-token") {
		t.Fatalf("create ddns failed or leaked token: %d %s", ddnsResp.Code, ddnsResp.Body.String())
	}
	var ddns DDNSProfile
	if err := json.Unmarshal(ddnsResp.Body.Bytes(), &ddns); err != nil {
		t.Fatal(err)
	}
	ddnsSync := postJSON(t, h, fmt.Sprintf("/api/v1/ddns-profiles/%d/sync", ddns.ID), "", nil)
	if ddnsSync.Code != http.StatusCreated {
		t.Fatalf("sync ddns failed: %d %s", ddnsSync.Code, ddnsSync.Body.String())
	}
	rebootNoConfirm := postJSON(t, h, "/api/v1/nodes/relay-1/reboot", "", NodeActionRequest{})
	if rebootNoConfirm.Code != http.StatusBadRequest {
		t.Fatalf("reboot without confirm should fail: %d %s", rebootNoConfirm.Code, rebootNoConfirm.Body.String())
	}
	reboot := postJSON(t, h, "/api/v1/nodes/relay-1/reboot", "", NodeActionRequest{Confirm: "REBOOT"})
	if reboot.Code != http.StatusCreated || !strings.Contains(reboot.Body.String(), "reboot_node") {
		t.Fatalf("reboot task failed: %d %s", reboot.Code, reboot.Body.String())
	}
}

func countTasks(t *testing.T, store *Store) int {
	t.Helper()
	var n int
	if err := store.db.QueryRow(`SELECT COUNT(*) FROM tasks`).Scan(&n); err != nil {
		t.Fatal(err)
	}
	return n
}

func TestPlanPreflightAndBlockedCommandSanitization(t *testing.T) {
	h := testServer(t)
	missing := postJSON(t, h, "/api/v1/plans", "", map[string]any{
		"type":  "create_forward",
		"title": "Missing target",
	})
	if missing.Code != http.StatusCreated {
		t.Fatalf("create missing plan failed: %d %s", missing.Code, missing.Body.String())
	}
	var missingPlan Plan
	if err := json.Unmarshal(missing.Body.Bytes(), &missingPlan); err != nil {
		t.Fatal(err)
	}
	preflightMissing := httptest.NewRecorder()
	h.ServeHTTP(preflightMissing, withOperator(httptest.NewRequest(http.MethodPost, fmt.Sprintf("/api/v1/plans/%d/preflight", missingPlan.ID), nil)))
	if preflightMissing.Code != http.StatusOK || !strings.Contains(preflightMissing.Body.String(), "target node is required") {
		t.Fatalf("missing target preflight unexpected: %d %s", preflightMissing.Code, preflightMissing.Body.String())
	}
	if strings.Contains(preflightMissing.Body.String(), "token=abc") {
		t.Fatalf("preflight leaked token: %s", preflightMissing.Body.String())
	}

	offlinePlan := postJSON(t, h, "/api/v1/plans", "", map[string]any{
		"type":           "create_forward",
		"title":          "Unknown target",
		"target_node_id": "unknown-relay",
	})
	var plan Plan
	if err := json.Unmarshal(offlinePlan.Body.Bytes(), &plan); err != nil {
		t.Fatal(err)
	}
	out := httptest.NewRecorder()
	h.ServeHTTP(out, withOperator(httptest.NewRequest(http.MethodPost, fmt.Sprintf("/api/v1/plans/%d/preflight", plan.ID), nil)))
	if out.Code != http.StatusOK || !strings.Contains(out.Body.String(), "target node has not reported yet") {
		t.Fatalf("unknown target preflight missing warning: %d %s", out.Code, out.Body.String())
	}

	store, err := OpenStore(filepath.Join(t.TempDir(), "controller.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	h2 := NewServerWithAuth(store, ServerOptions{AgentToken: "test-token", OperatorToken: "operator-token"}, nil)
	report := ReportRequest{NodeID: "offline-relay", NodeName: "offline", Role: "relay", Status: "online", IntervalSeconds: 1}
	if rr := postJSON(t, h2, "/api/v1/agent/report", "test-token", report); rr.Code != http.StatusOK {
		t.Fatalf("report failed: %d %s", rr.Code, rr.Body.String())
	}
	if _, err := store.db.Exec(`UPDATE nodes SET last_seen=? WHERE node_id=?`, time.Now().Add(-10*time.Second).UTC().Format(time.RFC3339), "offline-relay"); err != nil {
		t.Fatal(err)
	}
	offlineCreated := postJSON(t, h2, "/api/v1/plans", "", map[string]any{
		"type":           "create_forward",
		"title":          "Offline target",
		"target_node_id": "offline-relay",
	})
	var offline Plan
	if err := json.Unmarshal(offlineCreated.Body.Bytes(), &offline); err != nil {
		t.Fatal(err)
	}
	offlineOut := httptest.NewRecorder()
	h2.ServeHTTP(offlineOut, withOperator(httptest.NewRequest(http.MethodPost, fmt.Sprintf("/api/v1/plans/%d/preflight", offline.ID), nil)))
	if offlineOut.Code != http.StatusOK || !strings.Contains(offlineOut.Body.String(), "status=offline") {
		t.Fatalf("offline preflight missing status warning: %d %s", offlineOut.Code, offlineOut.Body.String())
	}

	bad := Plan{Type: "create_forward", Title: "bad", TargetNodeID: "relay-1"}
	groups := []CommandGroup{{NodeID: "relay-1", Role: "relay", Commands: []string{"lq status", "systemctl restart easytier-relay", "nft list ruleset"}}}
	classification, safety, blocked := classifyCommandGroups(groups)
	if classification != "blocked" || safety != "dangerous" || len(blocked) != 2 {
		t.Fatalf("expected dangerous blocked classification: %s %s %+v", classification, safety, blocked)
	}
	clean := flattenCommandGroups(sanitizeCommandGroups(groups))
	for _, forbidden := range []string{"systemctl restart", "nft "} {
		if strings.Contains(strings.Join(clean, "\n"), forbidden) {
			t.Fatalf("sanitized commands still contain %q: %+v", forbidden, clean)
		}
	}
	md := buildPlanMarkdown(bad, []string{"warn token=abc"}, sanitizeCommandGroups(groups), baseChecklist(), json.RawMessage(`{"Authorization":"Bearer abc"}`), []string{"lq status"}, rollbackInstructionsForPlan("create_forward"), "dangerous", "blocked")
	for _, leak := range []string{"token=abc", "Bearer abc", "systemctl restart", "nft "} {
		if strings.Contains(md, leak) {
			t.Fatalf("markdown leaked blocked/secret %q: %s", leak, md)
		}
	}
}
