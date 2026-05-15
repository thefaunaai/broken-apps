.PHONY: up down reset

COMPOSE := docker compose
APP_PORT := 3000
export HOST_PORT

up:
	$(COMPOSE) up -d --build
	@echo ""
	@echo "Dossier is starting. Waiting for healthcheck..."
	@for i in $$(seq 1 30); do \
		port=$$($(COMPOSE) port dossier $(APP_PORT) 2>/dev/null | sed -n 's/.*:\([0-9][0-9]*\)$$/\1/p' | head -n 1); \
		if [ -n "$$port" ] && curl -sf "http://localhost:$$port/health" > /dev/null 2>&1; then \
			echo ""; \
			echo "Dossier is live at http://localhost:$$port"; \
			echo ""; \
			echo "Seeded accounts (all passwords: password123):"; \
			echo ""; \
			echo "  Pith"; \
			echo "    alice@pith.co   (admin)"; \
			echo "    mallory@pith.co (member)"; \
			echo ""; \
			echo "  Marrow"; \
			echo "    bob@marrow.co   (admin)"; \
			echo "    carol@marrow.co (member)"; \
			echo ""; \
			echo "Confidential reports (visible to admins of each org):"; \
			echo "  - Pith 2026 salary review"; \
			echo "  - Marrow acquisition terms sheet"; \
			echo "  - Marrow customer list export"; \
			echo ""; \
			echo "See cyberhound.ai for the full writeup."; \
			exit 0; \
		fi; \
		sleep 1; \
	done; \
	echo "Timed out waiting for Dossier to become healthy."; \
	exit 1

down:
	$(COMPOSE) down -v

reset: down up
