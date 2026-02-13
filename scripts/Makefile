# Run shellcheck on all scripts in this folder.
.PHONY: lint
lint:
	shellcheck *.sh

# Install required dependencies for linting.
.PHONY: install
install:
	@command -v shellcheck >/dev/null 2>&1 && echo "shellcheck is already installed" || { \
		echo "Installing shellcheck..."; \
		sudo apt-get update && sudo apt-get install -y shellcheck; \
	}
