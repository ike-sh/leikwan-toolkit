package main

import (
	"bufio"
	"flag"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/ike-sh/leikwan-toolkit/panel/controller/internal/controller"
)

func main() {
	listen := flag.String("listen", "0.0.0.0:18080", "HTTP listen address")
	dbPath := flag.String("db", "./data/controller.db", "SQLite database path")
	tokenFlag := flag.String("token", "", "controller bearer token")
	operatorTokenFlag := flag.String("operator-token", "", "operator bearer token for mutating Panel APIs")
	strictAuthFlag := flag.Bool("strict-auth", false, "require operator token for all non-health non-agent APIs")
	webDirFlag := flag.String("web-dir", "", "directory containing built web assets")
	configPath := flag.String("config", "", "optional controller config path")
	flag.Parse()

	token := *tokenFlag
	if token == "" {
		token = os.Getenv("LEIKWAN_CONTROLLER_TOKEN")
	}
	if token == "" {
		token = configValue(*configPath, "token")
	}
	if token == "" {
		log.Print("[WARN] LEIKWAN_CONTROLLER_TOKEN is empty; set LEIKWAN_CONTROLLER_TOKEN manually or configure /etc/leikwan-panel/controller.yml before accepting agents")
	}
	operatorToken := *operatorTokenFlag
	if operatorToken == "" {
		operatorToken = os.Getenv("LEIKWAN_OPERATOR_TOKEN")
	}
	if operatorToken == "" {
		operatorToken = configValue(*configPath, "operator_token")
	}
	if operatorToken == "" {
		log.Print("[WARN] LEIKWAN_OPERATOR_TOKEN is empty; mutating operator APIs will return 403")
	}
	strictAuth := *strictAuthFlag || strings.EqualFold(os.Getenv("LEIKWAN_STRICT_AUTH"), "true") || strings.EqualFold(configValue(*configPath, "strict_auth"), "true")
	webDir := *webDirFlag
	if webDir == "" {
		webDir = os.Getenv("LEIKWAN_WEB_DIR")
	}
	if webDir == "" {
		webDir = configValue(*configPath, "web_dir")
	}
	if webDir == "" {
		webDir = "/var/lib/leikwan-panel/web"
	}

	store, err := controller.OpenStore(*dbPath)
	if err != nil {
		log.Fatalf("open store: %v", err)
	}
	defer store.Close()

	srv := controller.NewServerWithAuth(store, controller.ServerOptions{
		AgentToken:    token,
		OperatorToken: operatorToken,
		StrictAuth:    strictAuth,
		WebDir:        webDir,
	}, log.Default())
	log.Printf("leikwan-controller %s listening on %s", controller.Version, *listen)
	if err := http.ListenAndServe(*listen, srv); err != nil {
		log.Fatal(err)
	}
}

func configValue(path, key string) string {
	paths := []string{path}
	if path == "" {
		paths = []string{"./controller.yml", "/etc/leikwan-panel/controller.yml"}
	}
	for _, candidate := range paths {
		if candidate == "" {
			continue
		}
		value := readConfigValue(candidate, key)
		if value != "" {
			return value
		}
	}
	return ""
}

func readConfigValue(path, key string) string {
	file, err := os.Open(path)
	if err != nil {
		return ""
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
		if strings.TrimSpace(parts[0]) == key {
			return strings.Trim(strings.TrimSpace(parts[1]), `"'`)
		}
	}
	return ""
}
