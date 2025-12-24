package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"
)

// WebhookRequest represents the incoming webhook payload
type WebhookRequest struct {
	Prompt  string `json:"prompt"`
	Timeout int    `json:"timeout,omitempty"` // timeout in seconds, default 60
	Args    []string `json:"args,omitempty"`   // additional CLI arguments
}

// WebhookResponse represents the response sent back
type WebhookResponse struct {
	Success bool   `json:"success"`
	Output  string `json:"output,omitempty"`
	Error   string `json:"error,omitempty"`
	Agent   string `json:"agent"`
}

// Authentication middleware
func authMiddleware(secret string, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		auth := r.Header.Get("Authorization")
		expectedAuth := "Bearer " + secret

		if auth != expectedAuth {
			http.Error(w, `{"error":"Unauthorized"}`, http.StatusUnauthorized)
			return
		}

		next(w, r)
	}
}

// Execute CLI command with timeout and context
func executeAgent(agentCmd string, prompt string, args []string, timeoutSec int) (string, error) {
	if timeoutSec <= 0 {
		timeoutSec = 60
	}
	if timeoutSec > 300 {
		timeoutSec = 300 // max 5 minutes
	}

	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeoutSec)*time.Second)
	defer cancel()

	// Build command arguments
	cmdArgs := []string{}
	if len(args) > 0 {
		cmdArgs = append(cmdArgs, args...)
	}
	cmdArgs = append(cmdArgs, prompt)

	cmd := exec.CommandContext(ctx, agentCmd, cmdArgs...)
	
	// Run as agent user if running as root
	if os.Getuid() == 0 {
		cmd.Env = append(os.Environ(), "USER=agent", "HOME=/home/agent")
	}

	output, err := cmd.CombinedOutput()
	
	if ctx.Err() == context.DeadlineExceeded {
		return string(output), fmt.Errorf("command timed out after %d seconds", timeoutSec)
	}

	return string(output), err
}

// Generic handler for agent webhooks
func agentHandler(agentName, agentCmd string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
			return
		}

		// Parse request body
		body, err := io.ReadAll(io.LimitReader(r.Body, 1048576)) // 1MB limit
		if err != nil {
			respondJSON(w, http.StatusBadRequest, WebhookResponse{
				Success: false,
				Error:   "Failed to read request body",
				Agent:   agentName,
			})
			return
		}
		defer r.Body.Close()

		var req WebhookRequest
		if err := json.Unmarshal(body, &req); err != nil {
			respondJSON(w, http.StatusBadRequest, WebhookResponse{
				Success: false,
				Error:   "Invalid JSON payload",
				Agent:   agentName,
			})
			return
		}

		// Validate prompt
		if strings.TrimSpace(req.Prompt) == "" {
			respondJSON(w, http.StatusBadRequest, WebhookResponse{
				Success: false,
				Error:   "Prompt is required",
				Agent:   agentName,
			})
			return
		}

		// Execute agent command
		log.Printf("[%s] Executing: %s (timeout: %ds)", agentName, req.Prompt, req.Timeout)
		output, err := executeAgent(agentCmd, req.Prompt, req.Args, req.Timeout)

		if err != nil {
			respondJSON(w, http.StatusOK, WebhookResponse{
				Success: false,
				Output:  output,
				Error:   err.Error(),
				Agent:   agentName,
			})
			return
		}

		respondJSON(w, http.StatusOK, WebhookResponse{
			Success: true,
			Output:  output,
			Agent:   agentName,
		})
	}
}

// Helper to send JSON responses
func respondJSON(w http.ResponseWriter, status int, response WebhookResponse) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(response)
}

// Health check handler
func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "healthy",
		"service": "agent-webhook-server",
	})
}

func main() {
	// Get configuration from environment
	secret := os.Getenv("WEBHOOK_SECRET")
	if secret == "" {
		log.Fatal("WEBHOOK_SECRET environment variable is required")
	}

	port := os.Getenv("WEBHOOK_PORT")
	if port == "" {
		port = "8080"
	}

	// Setup routes with authentication
	http.HandleFunc("/webhook/copilot", authMiddleware(secret, agentHandler("copilot", "github-copilot-cli")))
	http.HandleFunc("/webhook/claude", authMiddleware(secret, agentHandler("claude", "claude")))
	http.HandleFunc("/webhook/gemini", authMiddleware(secret, agentHandler("gemini", "gemini")))
	
	// Health check endpoint (no auth required)
	http.HandleFunc("/health", healthHandler)

	// Start server
	addr := ":" + port
	log.Printf("Starting webhook server on %s", addr)
	log.Printf("Available endpoints:")
	log.Printf("  POST /webhook/copilot (GitHub Copilot CLI)")
	log.Printf("  POST /webhook/claude (Claude Code)")
	log.Printf("  POST /webhook/gemini (Google Gemini CLI)")
	log.Printf("  GET  /health (Health check)")
	
	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
