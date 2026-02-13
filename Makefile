# Root Makefile — delegates to sub-directory Makefiles.

SUBDIRS := api scripts

# Forward any target to each sub-directory.
.PHONY: $(SUBDIRS)
$(SUBDIRS):
	$(MAKE) -C $@ $(MAKECMDGOALS)

# Aggregate targets across sub-directories.
.PHONY: lint
lint: $(SUBDIRS)

# Install all required dependencies.
.PHONY: install
install: $(SUBDIRS)

# Run shellcheck on scripts only.
.PHONY: shellcheck
shellcheck:
	$(MAKE) -C scripts lint
