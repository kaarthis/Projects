SCRIPTS_DIR := $(realpath ../scripts)
PROPOSAL_FILES := $(shell find . -mindepth 2 -name '*.md' -not -name '0000-*' | sort)

ifdef TARGET
LINT_TARGETS := $(TARGET)
else
LINT_TARGETS := $(PROPOSAL_FILES)
endif

# Usage: make lint [TARGET=<file>]
.PHONY: lint
lint:
	@$(SCRIPTS_DIR)/lint-api-proposals.sh $(LINT_TARGETS)

# No dependencies to install for API linting.
.PHONY: install
install:
	@echo "No dependencies required for api."
