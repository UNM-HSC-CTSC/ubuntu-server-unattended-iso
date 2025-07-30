# Ubuntu Server Unattended ISO Builder
# Professional Makefile following industry best practices

# Configuration
SHELL := /bin/bash
.DEFAULT_GOAL := help
.ONESHELL:
.EXPORT_ALL_VARIABLES:

# Version and build info
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

# Directories
BIN_DIR := bin
LIB_DIR := lib
SCRIPTS_DIR := scripts
PROFILES_DIR := profiles
OUTPUT_DIR := output
CACHE_DIR := downloads

# Default profile if not specified
PROFILE ?= minimal-server

# Colors for output (respect NO_COLOR env var)
ifndef NO_COLOR
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m
endif

# Help target - default when just running 'make'
.PHONY: help
help:
	@echo "$(BLUE)Ubuntu Server Unattended ISO Builder$(NC)"
	@echo "Version: $(VERSION)"
	@echo ""
	@echo "$(YELLOW)Setup:$(NC)"
	@echo "  make install        Install system dependencies"
	@echo "  make test           Run test suite"
	@echo "  make check          Quick dependency check"
	@echo ""
	@echo "$(YELLOW)Build:$(NC)"
	@echo "  make build          Build ISO (PROFILE=minimal-server)"
	@echo "  make build-all      Build all profiles"
	@echo "  make list-profiles  List available profiles"
	@echo ""
	@echo "$(YELLOW)Advanced:$(NC)"
	@echo "  make generate       Interactive profile generator"
	@echo "  make validate       Validate all profiles"
	@echo "  make clean          Remove build artifacts"
	@echo "  make distclean      Remove all generated files"
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make build PROFILE=web-server"
	@echo "  make build PROFILE=database-server"

# Install dependencies
.PHONY: install
install:
	@echo "$(BLUE)Installing dependencies...$(NC)"
	@if [ -z "$(shell which apt-get 2>/dev/null)" ]; then \
		echo "$(RED)Error: This system does not have apt-get. Manual installation required.$(NC)"; \
		exit 1; \
	fi
	@echo "Installing system packages..."
	@sudo apt-get update -qq
	@sudo apt-get install -y -qq wget curl python3 python3-yaml genisoimage || \
		(echo "$(RED)Failed to install system packages$(NC)" && exit 1)
	@echo "Installing GitHub CLI..."
	@curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
	@echo "deb [arch=$$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
	@sudo apt-get update -qq
	@sudo apt-get install -y -qq gh || \
		(echo "$(YELLOW)Warning: GitHub CLI installation failed (optional)$(NC)")
	@if [ -f requirements.txt ]; then \
		echo "Installing Python dependencies..."; \
		pip3 install -r requirements.txt 2>/dev/null || \
		pip3 install --user -r requirements.txt 2>/dev/null || \
		echo "$(YELLOW)Warning: Could not install Python packages. YAML validation may be limited.$(NC)"; \
	fi
	@if [ -f .env.example ] && [ ! -f .env ]; then \
		echo "Creating .env from template..."; \
		cp .env.example .env; \
	fi
	@echo "$(GREEN)✓ Installation complete!$(NC)"
	@echo "$(YELLOW)Next step: make test$(NC)"

# Run tests
.PHONY: test
test:
	@echo "$(BLUE)Running test suite...$(NC)"
	@if [ -x test.sh ]; then \
		./test.sh; \
	elif [ -x $(SCRIPTS_DIR)/test.sh ]; then \
		$(SCRIPTS_DIR)/test.sh; \
	else \
		echo "$(RED)Error: test.sh not found$(NC)"; \
		exit 1; \
	fi

# Quick dependency check
.PHONY: check
check:
	@echo "$(BLUE)Checking dependencies...$(NC)"
	@missing=0; \
	for cmd in wget curl python3 genisoimage mkisofs; do \
		if command -v $$cmd >/dev/null 2>&1; then \
			echo "$(GREEN)✓$(NC) $$cmd"; \
		else \
			echo "$(RED)✗$(NC) $$cmd"; \
			missing=1; \
		fi; \
	done; \
	if [ $$missing -eq 1 ]; then \
		echo ""; \
		echo "$(YELLOW)Missing dependencies. Run: make install$(NC)"; \
		exit 1; \
	else \
		echo ""; \
		echo "$(GREEN)All dependencies satisfied!$(NC)"; \
	fi

# Build single ISO
.PHONY: build
build: check
	@echo "$(BLUE)Building ISO for profile: $(PROFILE)$(NC)"
	@if [ -x $(BIN_DIR)/build-iso ]; then \
		$(BIN_DIR)/build-iso --profile $(PROFILE); \
	elif [ -x build-iso.sh ]; then \
		./build-iso.sh --profile $(PROFILE); \
	else \
		echo "$(RED)Error: build-iso script not found$(NC)"; \
		exit 1; \
	fi

# Build all profiles
.PHONY: build-all
build-all: check
	@echo "$(BLUE)Building all profiles...$(NC)"
	@if [ -x $(BIN_DIR)/build-all ]; then \
		$(BIN_DIR)/build-all; \
	elif [ -x build-all.sh ]; then \
		./build-all.sh; \
	else \
		echo "$(RED)Error: build-all script not found$(NC)"; \
		exit 1; \
	fi

# List available profiles
.PHONY: list-profiles
list-profiles:
	@echo "$(BLUE)Available profiles:$(NC)"
	@for profile in $(PROFILES_DIR)/*/; do \
		if [ -f "$$profile/autoinstall.yaml" ]; then \
			name=$$(basename $$profile); \
			desc=$$(grep -m1 "^# " $$profile/autoinstall.yaml 2>/dev/null | sed 's/^# //' || echo "No description"); \
			printf "  %-20s %s\n" "$$name" "$$desc"; \
		fi; \
	done

# Interactive profile generator
.PHONY: generate
generate:
	@echo "$(BLUE)Starting interactive profile generator...$(NC)"
	@if [ -x $(BIN_DIR)/generate-autoinstall ]; then \
		$(BIN_DIR)/generate-autoinstall; \
	elif [ -x generate-autoinstall.sh ]; then \
		./generate-autoinstall.sh; \
	else \
		echo "$(RED)Error: generate-autoinstall script not found$(NC)"; \
		exit 1; \
	fi

# Validate all profiles
.PHONY: validate
validate:
	@echo "$(BLUE)Validating all profiles...$(NC)"
	@failed=0; \
	for profile in $(PROFILES_DIR)/*/autoinstall.yaml; do \
		dir=$$(dirname $$profile); \
		name=$$(basename $$dir); \
		printf "Validating %-20s " "$$name..."; \
		if $(SCRIPTS_DIR)/validate-autoinstall.sh "$$profile" >/dev/null 2>&1; then \
			echo "$(GREEN)✓$(NC)"; \
		else \
			echo "$(RED)✗$(NC)"; \
			failed=1; \
		fi; \
	done; \
	if [ $$failed -eq 1 ]; then \
		echo ""; \
		echo "$(RED)Some profiles failed validation$(NC)"; \
		exit 1; \
	else \
		echo ""; \
		echo "$(GREEN)All profiles valid!$(NC)"; \
	fi

# Clean build artifacts
.PHONY: clean
clean:
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	@rm -rf $(OUTPUT_DIR)/*.iso
	@rm -rf tmp_iso_extract_*
	@rm -f *.log
	@echo "$(GREEN)✓ Clean complete$(NC)"

# Deep clean - remove everything including cache
.PHONY: distclean
distclean: clean
	@echo "$(BLUE)Removing all generated files...$(NC)"
	@rm -rf $(OUTPUT_DIR)
	@rm -rf $(CACHE_DIR)
	@rm -f .env
	@echo "$(GREEN)✓ Distribution clean complete$(NC)"

# Show current configuration
.PHONY: config
config:
	@echo "$(BLUE)Current Configuration:$(NC)"
	@echo "  Version:    $(VERSION)"
	@echo "  Build Date: $(BUILD_DATE)"
	@if [ -f .env ]; then \
		echo ""; \
		echo "$(YELLOW)Environment (.env):$(NC)"; \
		grep -v '^#' .env | grep -v '^$$' | sed 's/^/  /'; \
	fi

# Development target - run shellcheck on scripts
.PHONY: lint
lint:
	@echo "$(BLUE)Running shellcheck...$(NC)"
	@if command -v shellcheck >/dev/null 2>&1; then \
		find . -name "*.sh" -type f | xargs shellcheck || true; \
	else \
		echo "$(YELLOW)shellcheck not installed. Install with: sudo apt-get install shellcheck$(NC)"; \
	fi

# Install git hooks for development
.PHONY: dev-setup
dev-setup: install
	@echo "$(BLUE)Setting up development environment...$(NC)"
	@if [ -d .git/hooks ]; then \
		echo "Installing git hooks..."; \
		echo "#!/bin/bash" > .git/hooks/pre-commit; \
		echo "make validate" >> .git/hooks/pre-commit; \
		chmod +x .git/hooks/pre-commit; \
	fi
	@echo "$(GREEN)✓ Development setup complete$(NC)"

.PHONY: all
all: install test build