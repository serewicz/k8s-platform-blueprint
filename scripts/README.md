# Scripts

Production-grade, documented automation for the Kubernetes platform blueprint.

## Key Scripts

| Script                  | Purpose                                                                 | Typical Use |
|-------------------------|-------------------------------------------------------------------------|-------------|
| `setup-kind.sh`         | One-command local cluster + full platform (Kyverno, OpenCost, monitoring, samples) | Quickstart, demos, development |
| `setup-minikube.sh`     | Similar to above but for minikube                                       | Alternative local env |
| `validate.sh`           | YAML, Kustomize, policy, and best-practice validation                   | CI gate + pre-PR |
| `cost-simulation.sh`    | Model spot, right-sizing, consolidation savings with realistic parameters | Board decks, FinOps planning, "what-if" analysis |
| `compliance-scan.sh`    | Generate SOC2/ISO-style evidence reports + policy summary               | Audit prep, monthly governance review |
| `scaling-test.sh`       | Execute and record controlled load tests against staging/kind           | Peak readiness validation, capacity modeling |

## Common Patterns

```bash
# Full local reproduction
./scripts/setup-kind.sh --name blueprint --nodes 3

# Validate before pushing
./scripts/validate.sh

# Model a major education platform peak
./scripts/cost-simulation.sh \
  --scenario education-platform \
  --nodes 180 \
  --spot-percent 65 \
  --rightsize-aggressiveness high \
  --active-learners 420000 \
  --output-format markdown > savings-q3.md

# Generate audit package
./scripts/compliance-scan.sh --framework soc2 --output audit-q2.json

# Run a peak simulation
./scripts/scaling-test.sh --target-cluster staging --virtual-users 25000 --duration 45m
```

All scripts are idempotent where possible, support `--dry-run` or `--help`, and output structured data (JSON/Markdown/CSV) suitable for automation and executive consumption.

## Adding New Scripts

- Keep them executable (`chmod +x`)
- Add usage examples in the header comment
- Update this README
- Prefer bash for portability; Python only when complex data processing is required
- Output machine-readable formats for the CTO dashboard / reporting pipeline
