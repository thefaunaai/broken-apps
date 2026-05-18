.PHONY: up down reset

COMPOSE := docker compose
APP_PORT := 3000
export HOST_PORT

up:
	$(COMPOSE) up -d --build
	@echo ""
	@echo "Gatehouse is starting. Waiting for healthcheck..."
	@for i in $$(seq 1 30); do \
		cid=$$($(COMPOSE) ps -q gatehouse); \
		if [ -n "$$cid" ] && [ "$$(docker inspect -f '{{.State.Status}}' $$cid 2>/dev/null)" = "exited" ]; then \
			$(COMPOSE) logs --tail=80 gatehouse; \
			exit 1; \
		fi; \
		port=$$($(COMPOSE) port gatehouse $(APP_PORT) 2>/dev/null | sed -n 's/.*:\([0-9][0-9]*\)$$/\1/p' | head -n 1); \
		if [ -n "$$port" ] && curl -sf "http://localhost:$$port/health" > /dev/null 2>&1; then \
			echo ""; \
			echo "Gatehouse is live at http://localhost:$$port"; \
			echo ""; \
			echo "Flow:"; \
			echo "  email -> verification code -> puzzle slider -> protected page"; \
			exit 0; \
		fi; \
		sleep 1; \
	done; \
	echo "Timed out waiting for Gatehouse to become healthy."; \
	exit 1

down:
	$(COMPOSE) down -v

reset: down up
