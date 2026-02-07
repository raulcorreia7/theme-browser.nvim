SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
.ONESHELL:

NVIM ?= nvim
PYTHON ?= python3
PLENARY_RTP ?=
# CI=true makes missing plenary a hard failure.
CI ?=

ROOT := $(CURDIR)

.PHONY: all setup build test lint fmt clean package smoke verify

all: verify

setup:
	@command -v $(NVIM) >/dev/null
	@command -v $(PYTHON) >/dev/null
	@printf "Environment OK (nvim + python)\n"

build:
	@printf "Nothing to build (Lua plugin)\n"

lint:
	@$(PYTHON) scripts/lint_lua.py

fmt:
	@printf "No formatter configured; skipped\n"

test:
	@PLENARY_PATH="$(PLENARY_RTP)"; \
	REQUIRE_PLENARY="$(CI)"; \
	if [[ -z "$$PLENARY_PATH" && -d "$$HOME/.local/share/nvim/lazy/plenary.nvim" ]]; then \
		PLENARY_PATH="$$HOME/.local/share/nvim/lazy/plenary.nvim"; \
	fi; \
	if [[ -n "$$PLENARY_PATH" && -d "$$PLENARY_PATH" ]]; then \
		$(NVIM) --headless -u NONE \
			"+set rtp+=$$PLENARY_PATH" \
			"+set rtp+=$(ROOT)" \
			"+lua require('plenary.test_harness').test_directory('tests', { minimal_init = 'tests/helpers/fixtures/plenary.lua' })" \
			+qa; \
	elif [[ "$$REQUIRE_PLENARY" == "1" || "$$REQUIRE_PLENARY" == "true" || "$$REQUIRE_PLENARY" == "TRUE" || "$$REQUIRE_PLENARY" == "True" || "$$REQUIRE_PLENARY" == "yes" || "$$REQUIRE_PLENARY" == "YES" || "$$REQUIRE_PLENARY" == "on" || "$$REQUIRE_PLENARY" == "ON" ]]; then \
		printf "PLENARY_RTP not set and plenary.nvim not found; failing in CI mode\n"; \
		exit 1; \
	else \
		printf "PLENARY_RTP not set; skipping plenary tests (set CI=true to fail instead)\n"; \
	fi

smoke:
	@$(PYTHON) scripts/smoke.py

verify: setup lint smoke test

package:
	@mkdir -p dist
	@tar --exclude='./dist' --exclude='./.ruff_cache' -czf dist/theme-browser.nvim.local.tar.gz .
	@printf "Created dist/theme-browser.nvim.local.tar.gz\n"

clean:
	@rm -rf dist
	@printf "Cleaned dist/\n"
