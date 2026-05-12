package main

import (
	"context"
	"flag"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/ike-sh/leikwan-toolkit/panel/agent/internal/agent"
)

func main() {
	configPath := flag.String("config", "", "agent config path")
	once := flag.Bool("once", false, "collect and report once")
	debug := flag.Bool("debug", false, "enable debug logging without printing secrets")
	initConfig := flag.Bool("init-config", false, "write agent config and exit")
	controllerURL := flag.String("controller-url", "", "controller URL for --init-config")
	token := flag.String("token", "", "controller bearer token for --init-config")
	nodeName := flag.String("node-name", "", "node name for --init-config")
	role := flag.String("role", "unknown", "node role for --init-config")
	enableTasks := flag.Bool("enable-tasks", true, "enable readonly task polling for --init-config")
	enableWriteActions := flag.Bool("enable-write-actions", false, "enable 2.2 alpha demo write actions for --init-config")
	flag.Parse()

	if *initConfig {
		cfg := agent.Config{
			ControllerURL:       *controllerURL,
			Token:               *token,
			NodeID:              *nodeName,
			NodeName:            *nodeName,
			Role:                *role,
			IntervalSeconds:     30,
			EnableTasks:         *enableTasks,
			EnableWriteActions:  *enableWriteActions,
			TaskIntervalSeconds: 10,
			TaskTimeoutSeconds:  20,
			MaxConcurrentTasks:  1,
			TaskResultLimitKB:   64,
		}
		if err := agent.WriteConfig(*configPath, cfg); err != nil {
			log.Fatal(agent.RedactString(err.Error()))
		}
		log.Printf("agent config written to %s", agent.ConfigPathOrDefault(*configPath))
		return
	}

	cfg, err := agent.LoadConfig(*configPath)
	if err != nil {
		log.Fatalf("load config: %v", err)
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	if err := agent.Run(ctx, cfg, *once, *debug); err != nil {
		log.Fatal(agent.RedactString(err.Error()))
	}
}
