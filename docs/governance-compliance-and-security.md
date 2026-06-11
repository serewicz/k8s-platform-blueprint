# Governance, Compliance, and Security

**Policy-as-Code, Audit Readiness, and Risk Management for Production Kubernetes**

This document is designed for platform security teams, compliance officers, and CTOs who must demonstrate continuous control to auditors, regulators, and boards.

## Executive Summary for CTOs

- **Problem**: Ad-hoc security reviews, tribal knowledge, and manual checklists fail at scale and during audits. New regulations such as the EU Cyber Resilience Act (CRA) add mandatory cybersecurity requirements, vulnerability handling, and documentation obligations for "products with digital elements".
- **Solution**: Policy-as-code (primarily Kyverno, with OPA/Gatekeeper examples) + GitOps + automated evidence generation + SLSA supply-chain provenance creates continuous compliance and demonstrable secure development lifecycle (SDLC).
- **Business Outcome**: 
  - 80–95% of common SOC 2 / ISO 27001 Kubernetes controls automated.
  - Strong foundation for EU CRA conformity (cybersecurity by design/default, vulnerability management, secure SDLC, evidence).
  - Audit / regulatory evidence generated on-demand (hours instead of weeks).
  - Reduced risk of breaches and misconfigurations reaching production.
  - Clear mapping from technical controls to regulatory frameworks (SOC2, ISO27001, EU CRA) for board reporting and due diligence.

## Core Pillars

1. **Preventive Controls** — Policy-as-code at admission time (Kyverno / Gatekeeper)
2. **Detective Controls** — Continuous scanning, policy reports, audit logs
3. **Corrective & Responsive** — Automated remediation where safe + documented break-glass
4. **Evidence & Reporting** — Structured reports suitable for auditors and executives

## Policy-as-Code Implementation (Kyverno Primary)

Kyverno was chosen as the default because:
- Human-readable YAML policies (lower barrier than Rego for most teams)
- Excellent mutation + validation + generation capabilities
- Strong Kubernetes-native integration and performance
- Good community and enterprise support path

### Required Policy Categories

**1. Workload Hardening**
- No privileged containers
- No hostPath / hostPID / hostIPC except for explicitly allowed system namespaces
- Read-only root filesystem where possible
- Drop all capabilities except those explicitly required
- Run as non-root

**2. Supply Chain & Provenance**
- Require image signatures (cosign) for all production workloads
- Require SBOM references or in-registry SBOMs (future)
- Block images from unapproved registries
- Enforce image freshness (no images > 90 days old without exception)

**3. Resource & Cost Governance**
- All pods must have requests and limits
- All pods must carry cost allocation labels
- Enforce namespace ResourceQuotas and LimitRanges

**4. Network & Data Protection**
- Default deny ingress/egress for application namespaces (generated NetworkPolicies)
- Require mTLS for sensitive services (via service mesh or sidecar)
- Prevent cross-namespace traffic unless explicitly allowed via labels

**5. Operational Excellence**
- Require owner/team labels for alerting and escalation
- Require environment label
- Disallow `latest` tag in production

Example policy location: `manifests/clusters/policies/kyverno/` (including the new `verify-slsa-provenance.yaml` for SLSA + CRA supply-chain enforcement)

### Sample Kyverno Policy (Illustrative)

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-cost-labels-and-resources
  annotations:
    policies.kyverno.io/title: Require Cost Labels and Resources
    policies.kyverno.io/category: Cost & FinOps
    policies.kyverno.io/severity: medium
    policies.kyverno.io/subject: Pod
    policies.kyverno.io/description: >-
      All workloads must declare cost-center, team, and resource requests/limits.
spec:
  validationFailureAction: Enforce
  background: true
  rules:
  - name: check-labels
    match:
      resources:
        kinds: [Pod]
        namespaces:
        - "!kube-system"
        - "!platform-*"
    validate:
      message: "Pods must have cost-center, team, product, and environment labels."
      pattern:
        metadata:
          labels:
            cost-center: "?*"
            team: "?*"
            product: "?*"
            environment: "dev | staging | prod"
  - name: require-resources
    match:
      resources:
        kinds: [Pod]
    validate:
      message: "Containers must specify requests and limits."
      pattern:
        spec:
          containers:
          - resources:
              requests:
                memory: "?*"
                cpu: "?*"
              limits:
                memory: "?*"
                cpu: "?*"
```

### OPA / Gatekeeper (Complementary)

Use Gatekeeper when you need:
- Complex logic best expressed in Rego
- Very large policy libraries already written in Rego
- Integration with existing OPA ecosystems

Examples are provided in `manifests/clusters/policies/gatekeeper/`.

## RBAC Best Practices

- **Least Privilege by Default**: Platform team gets cluster-admin only via break-glass (time-limited).
- **Namespace-scoped roles** for application teams.
- **Aggregated ClusterRoles** for platform services.
- **Impersonation and audit** enabled.
- **Break-glass procedure**: Documented runbook + one-time elevated tokens or short-lived IAM roles (EKS/GKE) with justification ticket.

See `manifests/clusters/rbac/` for reference ClusterRoleBindings and RoleBindings.

## Network Policies

- Default deny for all non-system namespaces.
- Explicit allow rules for:
  - Ingress from ingress-nginx / gateway-api
  - Egress to DNS, monitoring, and approved external endpoints
- Cilium or Calico for enforcement + observability.

## Audit Logging & Evidence Pipeline

- Kubernetes audit logs shipped to Loki or cloud logging service.
- Policy reports (Kyverno) aggregated and exported nightly.
- Git commit history + PR approvals serve as change control evidence.
- Infrastructure changes via Terraform are also in Git with signed commits (recommended).

**Compliance Report Generation**:
```bash
./scripts/compliance-scan.sh --framework soc2 --output compliance-report-$(date +%F).json
```

This produces a structured report with:
- Control ID → Policy → Evidence location → Pass/Fail + remediation guidance

## Mapping to Common Frameworks

### SOC 2 (Common Criteria)

| SOC 2 Control | Kubernetes Implementation | Evidence Source |
|---------------|---------------------------|-----------------|
| CC6.1 Logical Access | RBAC + least privilege + break-glass | Audit logs + Kyverno policy reports + Git history |
| CC6.6 / CC6.7 Encryption in transit | mTLS (service mesh) + TLS everywhere | NetworkPolicy + cert-manager + mesh config |
| CC6.8 / CC7.1 System monitoring | Prometheus + Loki + Alertmanager | Grafana dashboards + alert history |
| CC7.2 Change management | GitOps + PR reviews + policy gates | Git commits + Argo/Flux sync history |
| CC8.1 Vulnerability management | Image scanning + freshness policy | Trivy / Grype reports + Kyverno image age policy |

### ISO 27001 (Annex A)

- A.8.2 Information classification → labels + NetworkPolicies
- A.8.3 Access control → RBAC + policy
- A.8.14 Logging and monitoring → full observability stack
- A.8.16 Monitoring → alerts + evidence
- A.8.19 Installation of software → GitOps + image provenance
- A.8.23 Information security for use of cloud services → multi-cloud governance + policy portability

Full detailed mapping lives in `docs/governance-compliance-and-security.md` (this file) and can be exported from the compliance script.

## Admission Webhooks & Mutating Behavior

Kyverno can mutate:
- Inject standard labels and annotations
- Add default resource requests when missing (with warning)
- Inject sidecars for logging/monitoring (carefully)
- Rewrite images to approved registries

Always prefer validation-first with clear error messages over heavy mutation.

## Runtime Security (Optional Advanced)

- Falco or Tetragon for behavioral detection (syscall level).
- Policy to require Falco agent on nodes or use eBPF-based detection.
- Integrate alerts into the same Slack/Teams + PagerDuty channels as platform incidents.

## Supply Chain Security & SLSA

This blueprint aspires to **SLSA Level 2+** (with a path to Level 3) for both the platform components and the applications built on it.

**Implemented / Recommended Practices**:
- All production images **must** be built with provenance (SLSA v1 predicate recommended).
- GitHub Actions workflow `.github/workflows/slsa-provenance.yml` demonstrates attestation generation (integrate the official `slsa-framework/slsa-github-generator` for real releases; the workflow also supports image build provenance).
- **Verification at admission**: See the policy `manifests/clusters/policies/kyverno/verify-slsa-provenance.yaml`. It uses Kyverno's verifyImages + cosign/Sigstore support (keyless with GitHub OIDC or key-based) to block unsigned or unattested images in `prod-*` namespaces.
- SBOM generation in CI (Syft / Syft + attest) and storage alongside images (or in OCI registry).
- Image freshness and approved registry policies (see other Kyverno policies).
- Signed Git commits + PR requirements for all changes to manifests and infrastructure code.

**How this supports SLSA**:
- Source integrity (Git + signed commits)
- Build integrity & provenance (SLSA attestations)
- Artifact integrity (cosign signatures + verification policy)

See also the detailed layered architecture diagram and security flow in `ARCHITECTURE.md`.

## EU Cyber Resilience Act (CRA) — Mapping & Support

The **EU Cyber Resilience Act** (Regulation (EU) 2024/2847) imposes cybersecurity requirements on "products with digital elements" placed on the EU market. The Kubernetes platform (and many workloads running on it) can fall into scope, especially when offered as part of products or services.

This reference architecture provides a strong foundation for demonstrating conformity with CRA Annex I (essential cybersecurity requirements) and Annex II (documentation & information) obligations.

### Key CRA-Relevant Controls Implemented Here

| CRA Requirement Area (simplified)                  | Implementation in the Blueprint                                                                 | Evidence / Artifacts |
|----------------------------------------------------|--------------------------------------------------------------------------------------------------|----------------------|
| Cybersecurity by design & by default               | Kyverno policies enforce secure baselines (no privileged, read-only FS, non-root, resource limits, network deny-by-default, required labels). | PolicyReports, Git history of policies, `manifests/clusters/policies/kyverno/` |
| Protection against unauthorised access / data      | RBAC (least privilege + break-glass), NetworkPolicies, mTLS options (service mesh), secrets via External Secrets + KMS. | RBAC manifests, audit logs, PolicyReports |
| Resilience & availability                          | Multi-cluster / hybrid patterns, Karpenter + HPA/VPA with PDBs, GitOps rapid rollback, error budget alerting. | Architecture docs, load test reports (`scripts/scaling-test.sh`), SLO dashboards |
| Secure update & vulnerability management           | Image freshness policy, cosign + SLSA provenance verification, recommended Trivy/Grype scanning in CI + compliance script, SBOMs. | `verify-slsa-provenance.yaml`, compliance reports, CI workflows |
| Secure development lifecycle (SDLC)                | GitOps (immutable history + PR reviews), policy gates in admission, SLSA provenance in builds, this architecture document + lessons learned. | Git commit/PR logs, SLSA attestations, `ARCHITECTURE.md`, `.github/workflows/` |
| Documentation & user information                   | This repo (architecture, CRA mappings, runbooks), automated compliance reports (`scripts/compliance-scan.sh`), Grafana executive dashboards. | Generated JSON/Markdown reports, docs/ folder, dashboard exports |
| Incident handling & disclosure                     | Alertmanager with business context, documented break-glass + post-incident GitOps PR requirement, compliance evidence pipeline. | Incident runbooks (to be added), audit + PolicyReport history |

**How the platform helps with CRA obligations**:
- The combination of **preventive policy-as-code + continuous GitOps + provenance verification + automated reporting** directly supports the "cybersecurity by design and default" and "documentation of the product" requirements.
- For organizations building or selling products that incorporate this platform (or run workloads on it), the manifests, policies, and evidence generation tooling reduce the effort to produce the required technical documentation and risk assessments.
- Data residency / hybrid controls in `docs/hybrid-cloud.md` help with certain essential requirements around data protection.

**Limitations & Recommendations**:
- CRA also requires vulnerability disclosure processes and, for certain classes, conformity assessment by notified bodies. This blueprint provides the technical controls and evidence layer; you must still implement organizational processes (PSIRT, disclosure policy, etc.).
- Perform a product-specific CRA scoping assessment. Reference the official EU text and harmonised standards when they become available.
- Extend the compliance script and Kyverno policies for any additional CRA-specific technical controls required for your class of product.

See also `ARCHITECTURE.md` (Security & Compliance Architecture section) and the SLSA section above for overlapping supply-chain controls that support CRA.

### References
- EU Cyber Resilience Act: https://eur-lex.europa.eu/ (Regulation 2024/2847)
- SLSA: https://slsa.dev
- Kyverno + Sigstore integration guidance (for production verification policies)

## Secrets Management

- Never store secrets in Git.
- Recommended: External Secrets Operator + AWS Secrets Manager / GCP Secret Manager / Azure Key Vault / HashiCorp Vault.
- Alternative: SOPS with age or PGP (for smaller setups).
- All secrets must be encrypted at rest in the provider.

## Incident Response & Break-Glass

1. Documented runbook in `docs/incident-response.md` (or link).
2. Short-lived elevated access via:
   - `kubectl auth can-i` checks
   - Cloud IAM role assumption with justification
   - Time-boxed ClusterRoleBinding created via automation + audit log
3. Post-incident: mandatory GitOps PR to restore steady state + retrospective.

## Automated Compliance Scanning

`scripts/compliance-scan.sh` runs:
- Kyverno policy reports
- Trivy / Grype image + filesystem scan (optional)
- Kubescape or similar for CIS benchmark (optional addon)
- Generates JSON + Markdown summary suitable for auditors.

Run in CI nightly and on every major release.

## How This Supports Board & Audit Readiness

- **Continuous Evidence**: Policy reports + Git history + audit logs = living compliance artifact.
- **Traceability**: Every violation or exception has a ticket, PR, or time-limited approval.
- **Risk Quantification**: Dashboard shows % of namespaces in violation, trend of critical policy breaches, time-to-remediation.
- **Due Diligence**: During M&A or funding rounds, this package demonstrates mature platform governance.

## Rollout Recommendations

1. Start with Kyverno + 5-7 high-impact policies in `enforce` mode in dev/staging.
2. Expand to prod with `audit` mode first, then `enforce`.
3. Add image signing verification only after signing pipeline is reliable.
4. Map your specific regulatory requirements (HIPAA, GDPR, FedRAMP, etc.) and extend the policy library.
5. Integrate compliance reports into your GRC tool or share via secure portal for auditors.

## References

- Kyverno: https://kyverno.io
- OPA Gatekeeper: https://open-policy-agent.github.io/gatekeeper/
- CIS Kubernetes Benchmark
- SOC 2 Trust Services Criteria
- ISO/IEC 27001:2022
- SLSA: https://slsa.dev

Governance is not a tax on delivery — it is the mechanism that allows safe, rapid, and defensible scaling.
