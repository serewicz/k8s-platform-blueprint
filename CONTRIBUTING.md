# Contributing to k8s-platform-blueprint

Thank you for your interest in contributing to the Kubernetes Platform Blueprint — a strategic reference architecture designed for CTOs, platform engineering leads, and technical executives.

We welcome contributions that improve clarity, add production-ready patterns, strengthen governance or cost models, or expand real-world applicability for large-scale education, SaaS, and enterprise platforms.

## Code of Conduct

This project follows the [Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/). By participating, you agree to uphold a respectful, inclusive environment.

## How to Contribute

### 1. Reporting Issues

- Use GitHub Issues with the appropriate template.
- Include: environment details, reproduction steps, expected vs actual behavior, relevant logs or manifests.
- For security issues, please email the maintainers privately (see SECURITY.md if present) rather than opening a public issue.

### 2. Suggesting Enhancements

- Open a GitHub Discussion or Issue with the "enhancement" label.
- Clearly articulate the business or technical value, especially for executive stakeholders (ROI, risk, compliance, scalability).

### 3. Pull Requests

- Fork the repo and create a feature branch: `git checkout -b feat/your-improvement`.
- Keep PRs focused and small where possible. Large architectural changes should be discussed first.
- Follow the existing style and structure.
- Update or add documentation (README, ARCHITECTURE.md, relevant docs/*).
- Ensure all manifests, Terraform, and scripts remain production-grade and well-commented.
- Add or update tests/examples where applicable.
- Run local validation (see `scripts/validate.sh`).
- Reference any related issues.

PR template requirements:
- Description of changes and why
- Impact on cost, governance, scalability, or observability
- How this helps CTOs / platform leads (business alignment)
- Screenshots of dashboards or Mermaid diagrams if UI/visual
- Checklist for linting, validation, and documentation

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR-ORG/k8s-platform-blueprint.git
cd k8s-platform-blueprint

# Quick local environment (kind recommended)
./scripts/setup-kind.sh

# Validate manifests and policies
./scripts/validate.sh

# Run cost simulation example
./scripts/cost-simulation.sh --scenario education-platform --nodes 120
```

See [examples/labs/](examples/labs/) and the main [README.md](README.md) Quickstart for more.

## Style Guidelines

- **Manifests**: Use explicit resource requests/limits, meaningful labels (`app.kubernetes.io/*`, `platform.blueprint.tier`, `cost-center`), and comments. Prefer declarative GitOps patterns.
- **Terraform / Crossplane**: Modular, reusable, with variables for multi-cloud. Document billing integration points.
- **Scripts**: Idempotent, support `--dry-run`, output structured logs/JSON. Include usage examples.
- **Documentation**: Executive-friendly. Start with business outcomes, then technical depth. Use Mermaid diagrams. Include "How this helps CTOs" callouts.
- **Diagrams**: Prefer Mermaid for version control friendliness. Export high-res PNGs for board decks if needed.
- **Policies (Kyverno/OPA)**: Include rationale, severity, and remediation guidance. Map to SOC2, ISO27001, or similar controls where relevant.

## Focus Areas (High Priority)

- FinOps & cost optimization patterns (OpenCost, Kubecost parity, chargeback, multi-cloud)
- Policy-as-code and compliance automation (Kyverno, Gatekeeper)
- Executive dashboards and ROI modeling
- Real-world scaling stories (hundreds of thousands of users, global education platforms)
- Hybrid / multi-cloud connectivity and consistency
- SLSA provenance and supply chain security examples
- Accessibility of content for non-technical executives

## Release & Governance

- Main branch is protected. All changes via PR + required reviews.
- Semantic versioning for tagged releases.
- Major architectural shifts require an Architecture Decision Record (ADR) added to `docs/` or `ARCHITECTURE.md`.

## Recognition

Contributors are acknowledged in release notes and a `CONTRIBUTORS` file (generated). Significant contributions may be highlighted in the project README.

## Questions?

Open a GitHub Discussion or reach out via the project maintainers listed in the README.

Thank you for helping build a reference architecture that bridges technology excellence with strategic business outcomes.
