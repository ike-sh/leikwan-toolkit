package agent

import (
	"bufio"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

const defaultConfigPath = "/etc/leikwan-agent/config.yml"

func ConfigPathOrDefault(path string) string {
	if path == "" {
		return defaultConfigPath
	}
	return path
}

func LoadConfig(path string) (Config, error) {
	if path == "" {
		path = defaultConfigPath
		if _, err := os.Stat(path); err != nil {
			if _, localErr := os.Stat("./agent.yml"); localErr == nil {
				path = "./agent.yml"
			}
		}
	}
	cfg := Config{Role: "unknown", IntervalSeconds: 60, EnableTasks: false, EnableWriteActions: false, TaskIntervalSeconds: 10, TaskTimeoutSeconds: 20, MaxConcurrentTasks: 1, TaskResultLimitKB: 64}
	if path == "" {
		return cfg, nil
	}
	file, err := os.Open(path)
	if err != nil {
		return cfg, err
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, ":", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])
		value = strings.Trim(value, `"'`)
		switch key {
		case "controller_url":
			cfg.ControllerURL = value
		case "token":
			cfg.Token = value
		case "node_id":
			cfg.NodeID = value
		case "node_name":
			cfg.NodeName = value
		case "role":
			cfg.Role = normalizeRole(value)
		case "interval_seconds":
			n, err := strconv.Atoi(value)
			if err == nil && n > 0 {
				cfg.IntervalSeconds = n
			}
		case "enable_tasks":
			cfg.EnableTasks = parseBool(value)
		case "enable_write_actions":
			cfg.EnableWriteActions = parseBool(value)
		case "task_interval_seconds":
			n, err := strconv.Atoi(value)
			if err == nil && n > 0 {
				cfg.TaskIntervalSeconds = n
			}
		case "task_timeout_seconds":
			n, err := strconv.Atoi(value)
			if err == nil && n > 0 {
				cfg.TaskTimeoutSeconds = n
			}
		case "max_concurrent_tasks":
			n, err := strconv.Atoi(value)
			if err == nil && n > 0 {
				cfg.MaxConcurrentTasks = n
			}
		case "task_result_limit_kb":
			n, err := strconv.Atoi(value)
			if err == nil && n > 0 {
				cfg.TaskResultLimitKB = n
			}
		}
	}
	if err := scanner.Err(); err != nil {
		return cfg, err
	}
	if cfg.ControllerURL == "" {
		return cfg, fmt.Errorf("controller_url is required")
	}
	if cfg.TaskIntervalSeconds <= 0 {
		cfg.TaskIntervalSeconds = 10
	}
	if cfg.TaskTimeoutSeconds <= 0 {
		cfg.TaskTimeoutSeconds = 20
	}
	cfg.MaxConcurrentTasks = 1
	if cfg.TaskResultLimitKB <= 0 {
		cfg.TaskResultLimitKB = 64
	}
	if cfg.NodeID == "" {
		cfg.NodeID = stableNodeID(cfg.NodeName)
	}
	if cfg.NodeName == "" {
		cfg.NodeName = cfg.NodeID
	}
	return cfg, nil
}

func WriteConfig(path string, cfg Config) error {
	path = ConfigPathOrDefault(path)
	if cfg.ControllerURL == "" {
		return fmt.Errorf("controller_url is required")
	}
	if cfg.Token == "" {
		return fmt.Errorf("token is required")
	}
	cfg.Role = normalizeRole(cfg.Role)
	if cfg.NodeName == "" {
		host, _ := os.Hostname()
		cfg.NodeName = host
	}
	if cfg.NodeID == "" {
		cfg.NodeID = cfg.NodeName
	}
	if cfg.IntervalSeconds <= 0 {
		cfg.IntervalSeconds = 30
	}
	if cfg.TaskIntervalSeconds <= 0 {
		cfg.TaskIntervalSeconds = 10
	}
	if cfg.TaskTimeoutSeconds <= 0 {
		cfg.TaskTimeoutSeconds = 20
	}
	cfg.MaxConcurrentTasks = 1
	if cfg.TaskResultLimitKB <= 0 {
		cfg.TaskResultLimitKB = 64
	}
	if dir := filepath.Dir(path); dir != "." && dir != "" {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return err
		}
	}
	content := fmt.Sprintf("controller_url: %s\ntoken: %s\nnode_id: %s\nnode_name: %s\nrole: %s\ninterval_seconds: %d\nenable_tasks: %t\nenable_write_actions: %t\ntask_interval_seconds: %d\ntask_timeout_seconds: %d\nmax_concurrent_tasks: 1\ntask_result_limit_kb: %d\n",
		cfg.ControllerURL, cfg.Token, cfg.NodeID, cfg.NodeName, cfg.Role, cfg.IntervalSeconds, cfg.EnableTasks, cfg.EnableWriteActions, cfg.TaskIntervalSeconds, cfg.TaskTimeoutSeconds, cfg.TaskResultLimitKB)
	return os.WriteFile(path, []byte(content), 0o600)
}

func parseBool(value string) bool {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "1", "true", "yes", "y", "on", "enabled":
		return true
	default:
		return false
	}
}

func stableNodeID(nodeName string) string {
	if path := nodeIDStatePath(); path != "" {
		if raw, err := os.ReadFile(path); err == nil {
			if id := strings.TrimSpace(string(raw)); id != "" {
				return id
			}
		}
		id := generatedNodeID(nodeName)
		if dir := filepath.Dir(path); dir != "." && dir != "" {
			_ = os.MkdirAll(dir, 0o700)
		}
		_ = os.WriteFile(path, []byte(id+"\n"), 0o600)
		return id
	}
	return generatedNodeID(nodeName)
}

func nodeIDStatePath() string {
	if v := strings.TrimSpace(os.Getenv("LEIKWAN_AGENT_NODE_ID_FILE")); v != "" {
		return v
	}
	return "/var/lib/leikwan-agent/node_id"
}

func generatedNodeID(nodeName string) string {
	host := strings.TrimSpace(nodeName)
	if host == "" {
		host, _ = os.Hostname()
	}
	if host == "" {
		host = "leikwan-node"
	}
	var b [4]byte
	if _, err := rand.Read(b[:]); err == nil {
		return normalizeNodeID(host) + "-" + hex.EncodeToString(b[:])
	}
	return normalizeNodeID(host)
}

func normalizeNodeID(value string) string {
	value = strings.ToLower(strings.TrimSpace(value))
	var b strings.Builder
	for _, r := range value {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '-' || r == '_' {
			b.WriteRune(r)
		} else if r == '.' || r == ' ' {
			b.WriteRune('-')
		}
	}
	out := strings.Trim(b.String(), "-_")
	if out == "" {
		return "leikwan-node"
	}
	return out
}

func normalizeRole(role string) string {
	switch role {
	case "entry", "relay", "backend", "mixed", "unknown":
		return role
	default:
		return "unknown"
	}
}
