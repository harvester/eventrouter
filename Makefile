ROOT := $(realpath $(dir $(realpath $(firstword $(MAKEFILE_LIST)))))
comma := ,

# some systems require opt-in for buildx
DOCKER_BUILDKIT := 1
export DOCKER_BUILDKIT

ifdef CI
BOLD :=
CYAN :=
RESET :=
else
BOLD := \033[1m
CYAN := \033[36m
RESET := \033[0m
endif

BANNER = @printf "$(BOLD)$(CYAN)[target: $@]$(RESET)\n"

# Allocate a TTY in dev (for ctrl+c) but not in CI
MK_DOCKER_RUN_OPTS_TTY := $(if $(CI),,-it)
export MK_DOCKER_RUN_OPTS_TTY

# Safely detect a unique system identifier into a variable
MK_SYSTEM_ID := $(strip $(shell \
	if [ -s /etc/machine-id ]; then \
		cat /etc/machine-id 2>/dev/null; \
	elif command -v hostname >/dev/null 2>&1; then \
		hostname 2>/dev/null; \
	else \
		echo -n "unknown"; \
	fi))

# User might have several repos in a host. Distinguish each by using the abs path of the repo
MK_REPO_ID := $(shell printf '%s' "$(ROOT)$(MK_SYSTEM_ID)" | sha256sum | cut -c1-8)
export MK_REPO_ID

MK_DOCKER_PROGRESS ?= plain
export MK_DOCKER_PROGRESS

MK_VALIDATE_CACHE_IMAGE := eventrouter-image-builder-validate-cache:$(MK_REPO_ID)
MK_TEST_CACHE_IMAGE     := eventrouter-image-builder-test-cache:$(MK_REPO_ID)

# Legacy dapper env variables
REPO ?=
TAG  ?=
export REPO TAG

MK_HOST_ARCH := $(shell uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
export MK_HOST_ARCH

DOCKER_BUILD = docker build \
	--progress=$(MK_DOCKER_PROGRESS) \
	--build-arg MK_REPO_ID \
	--build-arg MK_HOST_ARCH \
	-f $(ROOT)/Dockerfile $(ROOT)

.DEFAULT_GOAL := ci

.PHONY: build ci default package release test validate gen-version-env gen-version-env-debug clean-all


# ---- Directories ----
$(ROOT)/bin:
	@mkdir -p $@


# ---- Pre-generate version env for container builds (no .git needed inside Docker) ----
# Also handles git worktree checkouts where .git is a pointer file to an external directory.
gen-version-env:
	$(BANNER)
	@bash $(ROOT)/scripts/version > /dev/null


# ---- Generate and show the version env for debugging ----
gen-version-env-debug:
	$(BANNER)
	@bash $(ROOT)/scripts/version debug


# ---- Compile eventrouter binaries ----
build: gen-version-env | $(ROOT)/bin
	$(BANNER)
	$(DOCKER_BUILD) --target build-output --output type=local,dest=.


# ---- Validate ----
validate: gen-version-env
	$(BANNER)
	$(DOCKER_BUILD) --target validate -t $(MK_VALIDATE_CACHE_IMAGE)


# ---- Test ----
test: gen-version-env
	$(BANNER)
	$(DOCKER_BUILD) --target test -t $(MK_TEST_CACHE_IMAGE)


# ---- Package eventrouter image ----
package: build
	$(BANNER)
	ARCH=$(MK_HOST_ARCH) $(ROOT)/scripts/package


# ---- Clean cached images ----
clean-all:
	$(BANNER)
	@docker rmi -f $(MK_VALIDATE_CACHE_IMAGE) $(MK_TEST_CACHE_IMAGE) || true

.DEFAULT_GOAL := default

ci: build package validate test

default: build package

release: ci
