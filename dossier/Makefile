.PHONY: up down reset logs shell seed-info

COMPOSE := docker compose
TARGET_URL := http://localhost:3000

up:
	$(COMPOSE) up -d --build
	@echo ""
	@echo "Dossier is starting. Waiting for healthcheck..."
	@for i in $$(seq 1 30); do \
		if curl -sf $(TARGET_URL)/health > /dev/null 2>&1; then \
			echo ""; \
			$(MAKE) seed-info; \
			exit 0; \
		fi; \
		sleep 1; \
	done; \
	echo "Timed out waiting for Dossier to become healthy."; \
	exit 1

down:
	$(COMPOSE) down -v

reset: down up

logs:
	$(COMPOSE) logs -f dossier

shell:
	$(COMPOSE) exec dossier sh

seed-info:
	@echo "Dossier is live at $(TARGET_URL)"
	@echo ""
	@echo "Seeded accounts (all passwords: password123):"
	@echo ""
	@echo "  Pith"
	@echo "    alice@pith.co   (admin)"
	@echo "    mallory@pith.co (member)"
	@echo ""
	@echo "  Marrow"
	@echo "    bob@marrow.co   (admin)"
	@echo "    carol@marrow.co (member)"
	@echo ""
	@echo "Confidential reports (visible to admins of each org):"
	@echo "  - Pith 2026 salary review"
	@echo "  - Marrow acquisition terms sheet"
	@echo "  - Marrow customer list export"
	@echo ""
	@echo "See cyberhound.ai for the full writeup."
