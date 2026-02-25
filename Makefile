SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
.ONESHELL:

NVIM ?= nvim
PYTHON ?= python3
PLENARY_RTP ?=
CI ?=
USE_ISOLATED ?= true

ROOT := $(CURDIR)

.PHONY: all setup build test test-isolated lint fmt fmt-check clean package smoke verify

all: verify

setup:
	@command -v $(NVIM) >/dev/null
	@command -v $(PYTHON) >/dev/null
	@printf "Environment OK (nvim + python)\n"

build:
	@printf "Nothing to build (Lua plugin)\n"

lint:
	@$(PYTHON) scripts/lint-lua.py
	@if command -v luacheck >/dev/null 2>&1; then \
		luacheck lua tests; \
	elif [[ "$(CI)" == "1" || "$(CI)" == "true" || "$(CI)" == "TRUE" || "$(CI)" == "True" ]]; then \
		printf "luacheck not found; failing in CI mode\n"; \
		exit 1; \
	else \
		printf "luacheck not found; skipping static lint (install luacheck to enable)\n"; \
	fi

fmt:
	@if command -v stylua >/dev/null 2>&1; then \
		stylua lua tests; \
	else \
		printf "stylua not found; skipping format\n"; \
	fi

fmt-check:
	@if command -v stylua >/dev/null 2>&1; then \
		stylua --check lua tests; \
	elif [[ "$(CI)" == "1" || "$(CI)" == "true" || "$(CI)" == "TRUE" || "$(CI)" == "True" ]]; then \
		printf "stylua not found; failing in CI mode\n"; \
		exit 1; \
	else \
		printf "stylua not found; skipping format check\n"; \
	fi

test:
	@if [[ "$(USE_ISOLATED)" == "true" ]]; then \
		bash scripts/test-runner.sh tests; \
	else \
		PLENARY_PATH="$(PLENARY_RTP)"; \
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
		fi \
	fi

test-isolated:
	@bash scripts/test-runner.sh tests

smoke:
	@$(PYTHON) scripts/smoke.py

verify: setup lint fmt-check smoke test

package:
	@mkdir -p dist
	@tar --exclude='./dist' --exclude='./.ruff_cache' -czf dist/theme-browser.nvim.local.tar.gz .
	@printf "Created dist/theme-browser.nvim.local.tar.gz\n"

clean:
	@rm -rf dist
	@printf "Cleaned dist/\n"
