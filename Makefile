# Makefile for k8s-platform-blueprint
# Convenient targets for local development and validation.
# Not required for using the repo — all scripts can be called directly.

.PHONY: help setup-kind validate cost-simulation compliance scaling-test clean

help:
	@echo "k8s-platform-blueprint development targets"
	@echo ""
	@echo "  make setup-kind        - Bootstrap local kind cluster with full platform"
	@echo "  make validate          - Run manifest + policy validation"
	@echo "  make cost-simulation   - Run example cost simulation (education platform)"
	@echo "  make compliance        - Generate SOC2 compliance report"
	@echo "  make scaling-test      - Run synthetic scaling test"
	@echo "  make clean             - Remove generated reports and kind cluster (careful)"

setup-kind:
	./scripts/setup-kind.sh

validate:
	./scripts/validate.sh

cost-simulation:
	./scripts/cost-simulation.sh --scenario education-platform --nodes 80 --spot-percent 60 --rightsize-aggressiveness high --output-format markdown

compliance:
	./scripts/compliance-scan.sh --framework soc2

scaling-test:
	./scripts/scaling-test.sh --target-cluster kind-blueprint --virtual-users 6000 --duration 12m

clean:
	kind delete cluster --name blueprint || true
	rm -f compliance-report-*.json compliance-report-*.md
	rm -rf scripts/output/*
	@echo "Cleaned generated artifacts and (if present) kind cluster 'blueprint'."
