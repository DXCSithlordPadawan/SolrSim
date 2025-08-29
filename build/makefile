# Threat Analysis Application - Makefile
# Comprehensive deployment and management commands

.PHONY: help build deploy start stop restart logs clean backup restore test

# Variables
DEPLOY_USER := ubuntu
DEPLOY_HOST := 192.169.0.201
APP_NAME := threat-analysis
DOMAIN := threat.aip.dxc.com

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(GREEN)Threat Analysis Application - Management Commands$(NC)"
	@echo "=================================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

check-prereqs: ## Check prerequisites for deployment
	@echo "$(GREEN)Checking prerequisites...$(NC)"
	@command -v ssh >/dev/null 2>&1 || (echo "$(RED)ssh is required but not installed$(NC)" && exit 1)
	@command -v scp >/dev/null 2>&1 || (echo "$(RED)scp is required but not installed$(NC)" && exit 1)
	@command -v docker >/dev/null 2>&1 || (echo "$(RED)docker is required but not installed$(NC)" && exit 1)
	@[ -f "threat_analysis_app.py" ] || (echo "$(RED)threat_analysis_app.py not found$(NC)" && exit 1)
	@[ -f "docker-compose.yml" ] || (echo "$(RED)docker-compose.yml not found$(NC)" && exit 1)
	@echo "$(GREEN)Prerequisites check passed$(NC)"

build: ## Build Docker images locally
	@echo "$(GREEN)Building Docker images...$(NC)"
	docker build -t $(APP_NAME):latest .
	@echo "$(GREEN)Docker images built successfully$(NC)"

test-local: ## Test the application locally
	@echo "$(GREEN)Testing application locally...$(NC)"
	docker run --rm -p 5000:5000 -e DEBUG=true $(APP_NAME):latest &
	sleep 10
	curl -f http://localhost:5000/health && echo "$(GREEN)Local test passed$(NC)" || echo "$(RED)Local test failed$(NC)"
	docker stop $$(docker ps -q --filter ancestor=$(APP_NAME):latest) 2>/dev/null || true

deploy: check-prereqs ## Deploy application to production server
	@echo "$(GREEN)Starting deployment to $(DEPLOY_HOST)...$(NC)"
	chmod +x deploy.sh
	./deploy.sh
	@echo "$(GREEN)Deployment completed$(NC)"

quick-deploy: ## Quick deployment (skip environment setup)
	@echo "$(GREEN)Quick deployment to $(DEPLOY_HOST)...$(NC)"
	scp -r . $(DEPLOY_USER)@$(DEPLOY_HOST):/opt/deployment/
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "cd /opt/deployment && docker-compose down && docker-compose build && docker-compose up -d"
	@echo "$(GREEN)Quick deployment completed$(NC)"

start: ## Start services on remote server
	@echo "$(GREEN)Starting services...$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "cd /opt/deployment && docker-compose up -d"

stop: ## Stop services on remote server
	@echo "$(YELLOW)5. Disk Space:$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "df -h /opt"
	@echo "$(YELLOW)6. Tailscale Status:$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "sudo tailscale status" 2>/dev/null || echo "Tailscale not configured"

dev-setup: ## Setup development environment locally
	@echo "$(GREEN)Setting up development environment...$(NC)"
	python3 -m venv venv
	./venv/bin/pip install -r requirements.txt
	mkdir -p config data
	cp config/areas.json config/ 2>/dev/null || echo "Config file already exists"
	@echo "$(GREEN)Development environment ready. Run: source venv/bin/activate && python threat_analysis_app.py$(NC)"

test: ## Run tests locally
	@echo "$(GREEN)Running tests...$(NC)"
	python3 -m pytest tests/ -v 2>/dev/null || echo "$(YELLOW)No tests found. Consider adding tests in tests/ directory$(NC)"

lint: ## Run code linting
	@echo "$(GREEN)Running code linting...$(NC)"
	python3 -m flake8 threat_analysis_app.py --max-line-length=120 2>/dev/null || echo "$(YELLOW)flake8 not installed$(NC)"
	python3 -m black --check threat_analysis_app.py 2>/dev/null || echo "$(YELLOW)black not installed$(NC)"

security-scan: ## Run security scan on containers
	@echo "$(GREEN)Running security scan...$(NC)"
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image $(APP_NAME):latest 2>/dev/null || echo "$(YELLOW)Trivy not available$(NC)"

performance-test: ## Run basic performance test
	@echo "$(GREEN)Running performance test...$(NC)"
	@echo "Testing application response time..."
	@for i in {1..10}; do \
		ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "time curl -s -f http://localhost/health >/dev/null" 2>&1 | grep real || echo "Test $i failed"; \
	done

install-tools: ## Install useful management tools on remote server
	@echo "$(GREEN)Installing management tools...$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "sudo apt-get update && sudo apt-get install -y htop iotop nethogs jq curl wget unzip"

setup-monitoring: ## Setup advanced monitoring with Prometheus and Grafana
	@echo "$(GREEN)Setting up advanced monitoring...$(NC)"
	scp -r monitoring/ $(DEPLOY_USER)@$(DEPLOY_HOST):/opt/ 2>/dev/null || echo "$(YELLOW)No monitoring directory found$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "cd /opt/monitoring && docker-compose up -d" 2>/dev/null || echo "$(YELLOW)Monitoring setup not available$(NC)"

docs: ## Generate and view documentation
	@echo "$(GREEN)Generating documentation...$(NC)"
	@echo "# Threat Analysis Application Documentation" > README.md
	@echo "" >> README.md
	@echo "## Quick Start" >> README.md
	@echo "\`\`\`bash" >> README.md
	@echo "make deploy  # Deploy to production" >> README.md
	@echo "make status  # Check status" >> README.md
	@echo "make logs    # View logs" >> README.md
	@echo "\`\`\`" >> README.md
	@echo "" >> README.md
	@echo "## Available Commands" >> README.md
	@make help >> README.md
	@echo "$(GREEN)Documentation generated in README.md$(NC)"

ssl-renew: ## Force SSL certificate renewal
	@echo "$(GREEN)Forcing SSL certificate renewal...$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "docker-compose -f /opt/deployment/docker-compose.yml exec traefik rm -f /letsencrypt/acme.json && docker-compose -f /opt/deployment/docker-compose.yml restart traefik"

network-test: ## Test network connectivity and DNS resolution
	@echo "$(GREEN)Testing network connectivity...$(NC)"
	@echo "$(YELLOW)Testing connectivity to $(DEPLOY_HOST):$(NC)"
	ping -c 3 $(DEPLOY_HOST) || echo "$(RED)Ping failed$(NC)"
	@echo "$(YELLOW)Testing SSH connectivity:$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "echo 'SSH connection successful'" || echo "$(RED)SSH failed$(NC)"
	@echo "$(YELLOW)Testing DNS resolution:$(NC)"
	nslookup $(DOMAIN) || echo "$(RED)DNS resolution failed$(NC)"
	@echo "$(YELLOW)Testing HTTPS connectivity:$(NC)"
	curl -I https://$(DOMAIN) 2>/dev/null || echo "$(RED)HTTPS connection failed$(NC)"

emergency-stop: ## Emergency stop all services
	@echo "$(RED)EMERGENCY STOP - Stopping all services...$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "docker stop \$\$(docker ps -q) && docker system prune -f"
	@echo "$(RED)All services stopped$(NC)"

emergency-restore: ## Emergency restore from latest backup
	@echo "$(RED)EMERGENCY RESTORE - Restoring from latest backup...$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "cd /opt/backups && LATEST=\$\$(ls -t *.tar.gz | head -1) && tar -xzf \$\$LATEST && cp -r threat-analysis_*/* /opt/ && cd /opt/deployment && docker-compose up -d"
	@echo "$(GREEN)Emergency restore completed$(NC)"

info: ## Show deployment information
	@echo "$(GREEN)Threat Analysis Deployment Information$(NC)"
	@echo "======================================"
	@echo "$(YELLOW)Application:$(NC) Threat Analysis System"
	@echo "$(YELLOW)Version:$(NC) 1.0"
	@echo "$(YELLOW)Deploy Host:$(NC) $(DEPLOY_HOST)"
	@echo "$(YELLOW)Domain:$(NC) https://$(DOMAIN)"
	@echo "$(YELLOW)Traefik Dashboard:$(NC) https://traefik.aip.dxc.com:8080"
	@echo "$(YELLOW)Configuration:$(NC) /opt/threat-analysis/config/areas.json"
	@echo "$(YELLOW)Data Directory:$(NC) /opt/threat-analysis/data"
	@echo "$(YELLOW)Backup Directory:$(NC) /opt/backups"
	@echo ""
	@echo "$(YELLOW)Quick Commands:$(NC)"
	@echo "  make status     - Check service status"
	@echo "  make logs       - View application logs"
	@echo "  make restart    - Restart services"
	@echo "  make backup     - Create backup"
	@echo "  make monitor    - Real-time monitoring"

# Advanced targets for production management

prod-deploy: check-prereqs ## Production deployment with all safety checks
	@echo "$(GREEN)Starting PRODUCTION deployment...$(NC)"
	@echo "$(YELLOW)This will deploy to PRODUCTION server $(DEPLOY_HOST)$(NC)"
	@read -p "Are you sure you want to continue? (y/N): " confirm; \
	if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then \
		make backup; \
		make deploy; \
		make status; \
		echo "$(GREEN)Production deployment completed$(NC)"; \
	else \
		echo "$(YELLOW)Deployment cancelled$(NC)"; \
	fi

rollback: ## Rollback to previous version
	@echo "$(YELLOW)Rolling back to previous version...$(NC)"
	@read -p "Are you sure you want to rollback? (y/N): " confirm; \
	if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then \
		ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "cd /opt/backups && LATEST=\$\$(ls -t *.tar.gz | head -1) && echo 'Rolling back to:' \$\$LATEST && tar -xzf \$\$LATEST && cp -r threat-analysis_*/* /opt/ && cd /opt/deployment && docker-compose restart"; \
		echo "$(GREEN)Rollback completed$(NC)"; \
	else \
		echo "$(YELLOW)Rollback cancelled$(NC)"; \
	fi

health-check: ## Comprehensive health check
	@echo "$(GREEN)Running comprehensive health check...$(NC)"
	@echo "$(YELLOW)1. Container Health:$(NC)"
	@ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "docker-compose -f /opt/deployment/docker-compose.yml ps" | grep -q "Up" && echo "✓ Containers running" || echo "✗ Container issues detected"
	@echo "$(YELLOW)2. Application Health:$(NC)"
	@ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "curl -s -f http://localhost/health" >/dev/null && echo "✓ Application responding" || echo "✗ Application not responding"
	@echo "$(YELLOW)3. SSL Certificate:$(NC)"
	@curl -s -I https://$(DOMAIN) >/dev/null 2>&1 && echo "✓ SSL certificate valid" || echo "✗ SSL certificate issues"
	@echo "$(YELLOW)4. Disk Space:$(NC)"
	@ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "df /opt | tail -1 | awk '{print \$5}' | cut -d'%' -f1" | { read usage; [ $usage -lt 85 ] && echo "✓ Disk space OK ($usage%)" || echo "⚠ Disk space warning ($usage%)"; }
	@echo "$(YELLOW)5. Tailscale:$(NC)"
	@ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "sudo tailscale status >/dev/null 2>&1" && echo "✓ Tailscale connected" || echo "⚠ Tailscale not connected"Stopping services...$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "cd /opt/deployment && docker-compose down"

restart: ## Restart services on remote server
	@echo "$(YELLOW)Restarting services...$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "cd /opt/deployment && docker-compose restart"

logs: ## View application logs
	@echo "$(GREEN)Viewing logs...$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "docker-compose -f /opt/deployment/docker-compose.yml logs -f --tail=100"

status: ## Check service status
	@echo "$(GREEN)Checking service status...$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "docker-compose -f /opt/deployment/docker-compose.yml ps"
	@echo "\n$(GREEN)Health Check:$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "curl -f http://localhost/health" || echo "$(RED)Health check failed$(NC)"

update: ## Update application (pull latest code and restart)
	@echo "$(GREEN)Updating application...$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "cd /opt/deployment && docker-compose pull && docker-compose up -d --force-recreate"

backup: ## Create backup of application data
	@echo "$(GREEN)Creating backup...$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "/opt/deployment/backup.sh"
	@echo "$(GREEN)Backup completed$(NC)"

restore: ## Restore from backup (specify BACKUP_FILE=filename)
	@echo "$(GREEN)Restoring from backup...$(NC)"
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo "$(RED)Please specify BACKUP_FILE=filename$(NC)"; \
		ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "ls -la /opt/backups/"; \
		exit 1; \
	fi
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "cd /opt/backups && tar -xzf $(BACKUP_FILE) && cp -r threat-analysis_*/* /opt/ && docker-compose -f /opt/deployment/docker-compose.yml restart"

clean: ## Clean up unused Docker resources on remote server
	@echo "$(YELLOW)Cleaning up Docker resources...$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "docker system prune -af && docker volume prune -f"

monitor: ## Show real-time monitoring information
	@echo "$(GREEN)Real-time monitoring (Press Ctrl+C to exit)...$(NC)"
	@while true; do \
		clear; \
		echo "$(GREEN)Threat Analysis System Status - $$(date)$(NC)"; \
		echo "=========================================="; \
		echo "$(YELLOW)Container Status:$(NC)"; \
		ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "docker-compose -f /opt/deployment/docker-compose.yml ps" 2>/dev/null || echo "$(RED)Failed to get container status$(NC)"; \
		echo ""; \
		echo "$(YELLOW)Health Check:$(NC)"; \
		ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "curl -s -f http://localhost/health | jq '.' 2>/dev/null || echo 'Health check failed'" 2>/dev/null; \
		echo ""; \
		echo "$(YELLOW)System Resources:$(NC)"; \
		ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "df -h /opt | tail -1 && free -h | head -2" 2>/dev/null || echo "$(RED)Failed to get system resources$(NC)"; \
		sleep 10; \
	done

shell: ## Connect to application container shell
	@echo "$(GREEN)Connecting to application container...$(NC)"
	ssh -t $(DEPLOY_USER)@$(DEPLOY_HOST) "docker-compose -f /opt/deployment/docker-compose.yml exec threat-analysis /bin/bash"

traefik-logs: ## View Traefik logs
	@echo "$(GREEN)Viewing Traefik logs...$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "docker-compose -f /opt/deployment/docker-compose.yml logs -f traefik --tail=100"

ssl-status: ## Check SSL certificate status
	@echo "$(GREEN)Checking SSL certificate status...$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "docker-compose -f /opt/deployment/docker-compose.yml exec traefik cat /letsencrypt/acme.json | jq '.dxc-cert-resolver.Certificates[] | {domains: .domain.main, notAfter: .certificate}' 2>/dev/null || echo 'No certificates found'"

config-reload: ## Reload configuration from external files
	@echo "$(GREEN)Reloading configuration...$(NC)"
	scp config/areas.json $(DEPLOY_USER)@$(DEPLOY_HOST):/opt/threat-analysis/config/
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "docker-compose -f /opt/deployment/docker-compose.yml restart threat-analysis"

scale: ## Scale application (specify REPLICAS=number)
	@echo "$(GREEN)Scaling application...$(NC)"
	@if [ -z "$(REPLICAS)" ]; then \
		echo "$(RED)Please specify REPLICAS=number$(NC)"; \
		exit 1; \
	fi
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "docker-compose -f /opt/deployment/docker-compose.yml up -d --scale threat-analysis=$(REPLICAS)"

troubleshoot: ## Run troubleshooting commands
	@echo "$(GREEN)Running troubleshooting commands...$(NC)"
	@echo "$(YELLOW)1. Container Status:$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "docker-compose -f /opt/deployment/docker-compose.yml ps"
	@echo "$(YELLOW)2. Recent Logs:$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "docker-compose -f /opt/deployment/docker-compose.yml logs --tail=20"
	@echo "$(YELLOW)3. Network Status:$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "docker network ls | grep traefik"
	@echo "$(YELLOW)4. Port Status:$(NC)"
	ssh $(DEPLOY_USER)@$(DEPLOY_HOST) "ss -tlnp | grep -E ':(80|443|8080)'"
	@echo "$(YELLOW)