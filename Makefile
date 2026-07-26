SHELL := /usr/bin/env bash

CLUSTER  ?= kprompt-demo
NS       ?= payments
SCENARIO ?= 01-crashloop

KIND     ?= kind
KUBECTL  ?= kubectl
# Empty → scripts/resolve-kprompt.sh picks a binary that has `agent` (v0.5+).
KPROMPT  ?=

SCENARIOS := $(sort $(notdir $(wildcard scenarios/*)))

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@echo "kprompt-examples — local Kubernetes demo scenarios"
	@echo
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "Scenarios (use SCENARIO=<name>):"
	@for s in $(SCENARIOS); do echo "  $$s"; done
	@echo
	@echo "Vars: CLUSTER=$(CLUSTER) NS=$(NS) SCENARIO=$(SCENARIO)"
	@echo "One-shot: make walkthrough   (up → break-all → verify → agent-full)"

.PHONY: doctor
doctor: ## Check required tools (kind, kubectl, kprompt>=0.5 with agent)
	@fail=0; \
	for bin in $(KIND) $(KUBECTL); do \
		if command -v $$bin >/dev/null 2>&1; then echo "ok   $$bin"; \
		else echo "MISS $$bin"; fail=1; fi; \
	done; \
	if docker info >/dev/null 2>&1; then echo "ok   docker daemon"; \
	else echo "MISS docker daemon (start Docker Desktop / colima)"; fail=1; fi; \
	if [ -n "$(KPROMPT)" ]; then KPROMPT="$(KPROMPT)"; \
	elif . scripts/resolve-kprompt.sh; then :; \
	else fail=1; KPROMPT=""; fi; \
	if [ -n "$$KPROMPT" ]; then \
		echo "ok   $$KPROMPT ($$( "$$KPROMPT" version 2>/dev/null || echo agent-ready ))"; \
	fi; \
	exit $$fail

.PHONY: up
up: ## Create the kind cluster and apply the baseline namespace
	@if $(KIND) get clusters 2>/dev/null | grep -qx "$(CLUSTER)"; then \
		echo "==> reusing kind cluster $(CLUSTER)"; \
	else \
		echo "==> creating kind cluster $(CLUSTER)"; \
		$(KIND) create cluster --name $(CLUSTER) --config kind/cluster.yaml --wait 120s; \
	fi
	@$(KUBECTL) config use-context kind-$(CLUSTER)
	@$(MAKE) --no-print-directory base
	@echo
	@echo "Cluster ready. Next: make walkthrough   # or make break && make agent"

.PHONY: base
base: ## Apply namespace + healthy baseline workload
	@echo "==> applying baseline into $(NS)"
	@$(KUBECTL) apply -f base/namespace.yaml
	@$(KUBECTL) rollout status -n $(NS) deployment/web --timeout=120s

.PHONY: break
break: ## Apply one broken scenario (SCENARIO=<name>)
	@test -d scenarios/$(SCENARIO) || { echo "unknown SCENARIO=$(SCENARIO)"; exit 1; }
	@if [ -x scenarios/$(SCENARIO)/break.sh ]; then \
		echo "==> running scenarios/$(SCENARIO)/break.sh"; \
		NS=$(NS) scenarios/$(SCENARIO)/break.sh; \
	else \
		echo "==> applying scenarios/$(SCENARIO)/manifests.yaml"; \
		$(KUBECTL) apply -n $(NS) -f scenarios/$(SCENARIO)/manifests.yaml; \
	fi
	@echo
	@echo "Give it ~30s to fail, then: make verify && make status"

.PHONY: fix
fix: ## Remove one scenario (SCENARIO=<name>)
	@test -d scenarios/$(SCENARIO) || { echo "unknown SCENARIO=$(SCENARIO)"; exit 1; }
	@echo "==> deleting scenarios/$(SCENARIO)"
	@$(KUBECTL) delete -n $(NS) -f scenarios/$(SCENARIO)/manifests.yaml --ignore-not-found

.PHONY: break-all
break-all: ## Apply every scenario at once (messy namespace, good health-score demo)
	@for s in $(SCENARIOS); do $(MAKE) --no-print-directory break SCENARIO=$$s; done

.PHONY: fix-all
fix-all: ## Remove every scenario, keep the cluster and baseline
	@for s in $(SCENARIOS); do $(MAKE) --no-print-directory fix SCENARIO=$$s; done

.PHONY: status
status: ## Show pods, deployments and recent warnings in the namespace
	@$(KUBECTL) get pods -n $(NS) -o wide
	@echo
	@$(KUBECTL) get deploy,sts,job,cronjob,pvc -n $(NS) 2>/dev/null || true
	@echo
	@$(KUBECTL) get events -n $(NS) --field-selector type=Warning \
		--sort-by=.lastTimestamp 2>/dev/null | tail -20 || true

.PHONY: verify
verify: ## Wait until the applied scenarios reach their intended broken states
	@NS=$(NS) scripts/verify.sh

.PHONY: agent
agent: ## Run the Observe agent (heuristic, no LLM key needed)
	@if [ -n "$(KPROMPT)" ]; then KPROMPT="$(KPROMPT)"; else . scripts/resolve-kprompt.sh; fi; \
	"$$KPROMPT" agent run -n $(NS) --analyze --health --heuristic

.PHONY: agent-full
agent-full: ## Run the agent with logs, expanded watches, memory, patterns and propose-only Autopilot
	@if [ -n "$(KPROMPT)" ]; then KPROMPT="$(KPROMPT)"; else . scripts/resolve-kprompt.sh; fi; \
	"$$KPROMPT" agent run -n $(NS) \
		--watch pods,events,deployments,replicasets,jobs,cronjobs,pvc \
		--analyze --fetch-logs --health --heuristic \
		--memory --patterns --autopilot-propose

.PHONY: walkthrough
walkthrough: ## One-shot sellable demo: up → break-all → verify → agent-full (DEMO_SECONDS=45)
	@scripts/walkthrough.sh

.PHONY: record
record: ## Record asciinema (+ GIF if agg is installed). DEMO_SECONDS=60 SKIP_UP=0
	@scripts/record.sh

.PHONY: down
down: ## Delete the kind cluster
	@echo "==> deleting kind cluster $(CLUSTER)"
	@$(KIND) delete cluster --name $(CLUSTER)

.PHONY: lint
lint: ## Validate manifests via server dry-run (needs `make up` first)
	@NS=$(NS) scripts/lint.sh
