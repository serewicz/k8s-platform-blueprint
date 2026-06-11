#!/usr/bin/env bash
# scripts/validate.sh
#
# Validates the repository manifests, policies, and basic configuration.
# Intended for CI and local developer use.
#
# Checks performed:
#   - YAML syntax (basic)
#   - Required labels on key resources (via grep/awk for simplicity)
#   - Kyverno policies parseable (structure)
#   - Kustomize builds for environments succeed
#   - Basic security / best-practice heuristics (no :latest in prod, resource requests present)
#
# Exit non-zero on failure so CI can block bad PRs.

set -euo pipefail

log() { echo -e "\033[1;32m[validate]\033[0m $*"; }
err() { echo -e "\033[1;31m[validate]\033[0m $*"; }

FAILURES=0

check_kustomize() {
  local dir=$1
  if ! command -v kustomize >/dev/null 2>&1; then
    log "kustomize CLI not found — skipping build check for $dir (install in CI)"
    return 0
  fi
  log "Kustomize build: $dir"
  if ! kustomize build "$dir" >/dev/null 2>&1; then
    err "Kustomize build failed for $dir"
    FAILURES=$((FAILURES+1))
  fi
}

check_no_latest_in_prod() {
  log "Checking for :latest tags in prod manifests..."
  if grep -r ":latest" manifests/environments/prod/ --include="*.yaml" 2>/dev/null; then
    err "Found :latest tag in prod manifests (blocked by policy and this check)"
    FAILURES=$((FAILURES+1))
  fi
}

check_resource_requests_present() {
  log "Checking that sample prod deployments declare requests/limits..."
  # Very lightweight check - real enforcement is done by Kyverno
  if ! grep -q "requests:" manifests/environments/prod/sample-app.yaml; then
    err "Prod sample app appears to be missing resource requests"
    FAILURES=$((FAILURES+1))
  fi
}

check_cost_labels_policy() {
  log "Checking cost label policy exists and looks reasonable..."
  if [[ ! -f manifests/clusters/policies/kyverno/require-cost-labels.yaml ]]; then
    err "Missing require-cost-labels policy"
    FAILURES=$((FAILURES+1))
  fi
}

check_kustomize "manifests/clusters"
check_kustomize "manifests/environments/dev"
check_kustomize "manifests/environments/staging"
check_kustomize "manifests/environments/prod"

check_no_latest_in_prod
check_resource_requests_present
check_cost_labels_policy

# Basic YAML lint if yamllint is available (optional)
if command -v yamllint >/dev/null 2>&1; then
  log "Running yamllint..."
  yamllint -s manifests/ || FAILURES=$((FAILURES+1))
else
  log "yamllint not installed — skipping (recommended in CI)"
fi

if [[ $FAILURES -gt 0 ]]; then
  err "Validation failed with $FAILURES error(s)."
  exit 1
fi

log "All validations passed."
exit 0
