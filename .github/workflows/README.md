# GitHub Workflows

CI and governance automation for the k8s-platform-blueprint.

## Workflows

- `ci-validate.yml` — Runs on every push/PR. Validates manifests, policies, runs cost simulation smoke test, produces compliance artifacts.
- `slsa-provenance.yml` — Example SLSA provenance generation on release (adapt with real generator for production images/charts).
- `compliance-check.yml` — Nightly compliance report generation. Useful for continuous audit evidence.

## Local Equivalents

Most checks can be run locally:
```bash
./scripts/validate.sh
./scripts/cost-simulation.sh ...
./scripts/compliance-scan.sh ...
```

## Adding Checks

When you add new mandatory policies or cost governance rules, update both the scripts and the CI workflows so that violations are caught before they reach main.
