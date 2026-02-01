cd /home/claude/eventid-system && cat > Makefile << 'EOF'
.PHONY: help run stop status logs test test-event db-connect clean

help: ## Show this help message
	@echo "EventID - Regulatory Compliance Event System"
	@echo ""
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

run: ## Start all services
	@echo "Starting EventID system..."
	docker-compose up -d
	@echo "Waiting for services to be healthy..."
	@sleep 15
	@echo "\nServices started!"
	@echo "  API Server:         http://localhost:8081"
	@echo "  Auth Server:        http://localhost:8082"
	@echo "  Kafka UI:           http://localhost:8080"
	@echo "  Prometheus:         http://localhost:9090"
	@echo "  Grafana:            http://localhost:3001 (admin/admin)"
	@echo ""

stop: ## Stop all services
	@echo "Stopping EventID system..."
	docker-compose down

status: ## Check service status
	@docker-compose ps

logs: ## View consumer logs
	docker-compose logs -f event-consumer workspace-monitor

logs-all: ## View all service logs
	docker-compose logs -f

test-event: ## Send a test regulatory event
	@echo "Sending test regulatory event..."
	@./scripts/send-test-event.sh

test: ## Run integration test
	@echo "Running integration test..."
	@./scripts/integration-test.sh

db-connect: ## Connect to workspace database
	docker exec -it eventid-postgres-workspaces psql -U eventid -d eventid_workspaces

db-events: ## Show recent events
	docker exec -it eventid-postgres-events psql -U eventid -d eventid_events -c "SELECT event_id, event_type, platform, timestamp FROM events ORDER BY timestamp DESC LIMIT 10;"

metrics: ## View Prometheus metrics
	@echo "Opening Prometheus metrics..."
	@open http://localhost:9090 || xdg-open http://localhost:9090 || echo "Visit: http://localhost:9090"

clean: ## Stop and remove all containers, volumes
	@echo "Cleaning up EventID system..."
	docker-compose down -v
	@echo "Clean complete!"

build: ## Build all Docker images
	docker-compose build

restart: stop run ## Restart all services

.DEFAULT_GOAL := help
EOF
echo "Makefile created"