package agent

import "encoding/json"

const Version = "3.0.0-alpha.1"

type Config struct {
	ControllerURL       string
	Token               string
	NodeID              string
	NodeName            string
	Role                string
	IntervalSeconds     int
	EnableTasks         bool
	EnableWriteActions  bool
	TaskIntervalSeconds int
	TaskTimeoutSeconds  int
	MaxConcurrentTasks  int
	TaskResultLimitKB   int
}

type RegisterRequest struct {
	NodeID   string `json:"node_id"`
	NodeName string `json:"node_name"`
	Role     string `json:"role"`
	Hostname string `json:"hostname"`
}

type ReportRequest struct {
	NodeID          string            `json:"node_id"`
	NodeName        string            `json:"node_name"`
	Role            string            `json:"role"`
	Hostname        string            `json:"hostname"`
	PublicIP        string            `json:"public_ip"`
	PrimaryLANIP    string            `json:"primary_lan_ip"`
	EasyTierIP      string            `json:"easytier_ip"`
	AgentVersion    string            `json:"agent_version"`
	CoreVersion     string            `json:"core_version"`
	Status          string            `json:"status"`
	HealthScore     int               `json:"health_score"`
	IntervalSeconds int               `json:"interval_seconds"`
	Summary         json.RawMessage   `json:"summary,omitempty"`
	Doctor          json.RawMessage   `json:"doctor,omitempty"`
	LQStatus        json.RawMessage   `json:"lq_status,omitempty"`
	LQDoctor        json.RawMessage   `json:"lq_doctor,omitempty"`
	Services        map[string]string `json:"services,omitempty"`
	Entries         []EntryPayload    `json:"entries,omitempty"`
	Forwards        []ForwardPayload  `json:"forwards,omitempty"`
	RecentErrors    []string          `json:"recent_errors,omitempty"`
	Errors          []string          `json:"errors,omitempty"`
	Capabilities    Capabilities      `json:"capabilities,omitempty"`
}

type Capabilities struct {
	LQAvailable                        bool     `json:"lq_available"`
	CoreVersion                        string   `json:"core_version"`
	SupportsStatusJSON                 bool     `json:"supports_status_json"`
	SupportsDoctorJSON                 bool     `json:"supports_doctor_json"`
	SupportsForwardList                bool     `json:"supports_forward_list"`
	SupportsDDNSOverview               bool     `json:"supports_ddns_overview"`
	EnableTasks                        bool     `json:"enable_tasks"`
	SupportsSnapshotManualRecord       bool     `json:"supports_snapshot_manual_record"`
	SupportsRollbackManualRecord       bool     `json:"supports_rollback_manual_record"`
	WriteActionsSupported              bool     `json:"write_actions_supported"`
	SupportedWriteActions              []string `json:"supported_write_actions,omitempty"`
	ControllerMetadataActionsSupported bool     `json:"controller_metadata_actions_supported"`
	AllowedTaskActions                 []string `json:"allowed_task_actions,omitempty"`
}

type EntryPayload struct {
	Name       string          `json:"name"`
	ListenPort int             `json:"listen_port"`
	Protocol   string          `json:"protocol"`
	PublicHost string          `json:"public_host"`
	Status     string          `json:"status"`
	RawJSON    json.RawMessage `json:"raw_json,omitempty"`
}

type ForwardPayload struct {
	Name       string          `json:"name"`
	EntryName  string          `json:"entry_name"`
	TargetHost string          `json:"target_host"`
	TargetPort int             `json:"target_port"`
	Protocol   string          `json:"protocol"`
	Status     string          `json:"status"`
	RawJSON    json.RawMessage `json:"raw_json,omitempty"`
}

type Task struct {
	ID          int64           `json:"id"`
	NodeID      string          `json:"node_id"`
	Action      string          `json:"action"`
	Status      string          `json:"status"`
	PayloadJSON json.RawMessage `json:"payload_json,omitempty"`
}

type TaskResultRequest struct {
	Status       string `json:"status"`
	ResultStdout string `json:"result_stdout"`
	ResultStderr string `json:"result_stderr"`
	ExitCode     int    `json:"exit_code"`
	Error        string `json:"error"`
}
