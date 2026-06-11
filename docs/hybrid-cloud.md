# Hybrid and Multi-Cloud Kubernetes

**Running a Consistent, Portable, and Resilient Platform Across Providers and On-Premises**

This document addresses the architectural and operational patterns required when you cannot (or choose not to) put all workloads in a single cloud provider.

## Executive Summary for CTOs

- **Strategic Value**: Avoid vendor lock-in, optimize regional pricing and latency, satisfy data residency, and increase resilience.
- **Risk Reduction**: Multi-cloud reduces the blast radius of a single provider outage or pricing shock.
- **Complexity Tax**: Requires disciplined abstraction. This blueprint provides the abstractions and guardrails.
- **Real-World Provenance**: Many large education and SaaS platforms run active-active or active-passive across two clouds plus on-prem for specific regulated workloads.

## When to Go Multi-Cloud or Hybrid

Common triggers:
- Data residency or sovereignty requirements (student data, government contracts)
- Best-of-breed pricing or capacity (one provider cheaper for GPU, another for storage)
- Merger & acquisition integration
- Negotiation leverage with cloud vendors
- Disaster recovery / business continuity (provider-level failure domains)
- Existing on-premises investments (VMware, bare metal for training clusters, etc.)

## Architectural Model

**Portable Application Layer** (what developers and platform teams mostly see):
- Standard Kubernetes manifests + Kustomize overlays or Helm
- Policy-as-code (Kyverno) that is cloud-agnostic
- OpenTelemetry instrumentation
- GitOps (Flux/Argo) as the deployment mechanism

**Provider-Specific Infrastructure Layer** (provisioned by Terraform/Crossplane):
- VPC / VNet, subnets, security groups / firewalls
- EKS / GKE / AKS control plane + node groups or Karpenter
- IAM / Workload Identity
- Storage classes, load balancers, DNS
- Billing integration (CUR, BigQuery, Cost Management)

**Connectivity Layer**:
- Cloud-native private connectivity (AWS Transit Gateway, GCP Interconnect, Azure Virtual WAN)
- VPN as fallback
- Service mesh for application-level cross-cluster communication (optional but powerful)
- Global load balancing / traffic steering (latency, health, cost, compliance)

## Cluster Provisioning (Terraform Recommended)

This repo provides modular Terraform under `terraform/aws/`, `terraform/gcp/`, `terraform/azure/`, and `terraform/onprem/`.

Key design:
- Each cloud module outputs a standardized set of values (cluster name, endpoint, CA, OIDC issuer, cost allocation tags, etc.).
- Workload identity is configured consistently (IRSA on AWS, Workload Identity on GCP, AAD Pod Identity / Workload Identity on Azure).
- Karpenter or Cluster Autoscaler is installed via Helm in the post-provisioning phase.
- Base platform components (Kyverno, OpenCost, observability) are applied via GitOps immediately after cluster creation.

**Example high-level flow**:
```bash
terraform -chdir=terraform/aws apply -var-file=prod-us-east.tfvars
# Outputs fed into GitOps or cluster bootstrap job
```

See `terraform/README.md` (in each subdir) for detailed variables and outputs.

### Crossplane Alternative

Crossplane is excellent when you want to manage infrastructure *as Kubernetes resources* and have a single control plane across clouds. Examples are lighter in this repo but the pattern is supported.

## Workload Portability Patterns

1. **Declarative Manifests First**
   - Avoid cloud-specific volume types, LB annotations, or node selectors unless wrapped in abstractions.
   - Use `topology.kubernetes.io/region` and `topology.kubernetes.io/zone` labels.
   - Use `failure-domain.beta.kubernetes.io/zone` only as legacy fallback.

2. **Overlay / Environment Strategy**
   - `manifests/environments/prod/kustomization.yaml` contains base + cloud-specific patches.
   - Common pattern: base workload + `overlays/aws`, `overlays/gcp`, `overlays/onprem`.

3. **Policy-Driven Placement**
   - Kyverno or Gatekeeper can mutate or validate based on labels such as `data-residency: eu-restricted`.
   - Example: "If namespace has label `data-residency=strict`, then pods may only schedule on nodes with matching region label or on-prem taints."

4. **Storage Abstraction**
   - Use CSI drivers that are available across clouds (e.g., Ceph via Rook for portable block/file, or cloud-native with storage class parameters abstracted).
   - For stateful workloads that must stay on-prem, use dedicated storage classes and node affinity.

## Connectivity Options

### Option A — Cloud-Native Private Networking (Recommended for most)

- AWS Transit Gateway + VPC attachments
- GCP Cloud Interconnect or HA VPN + VPC peering
- Azure Virtual WAN / ExpressRoute equivalents
- Central hub VPC / VNet with inspection (firewall, packet mirroring)

### Option B — Service Mesh Multi-Cluster

- Istio multi-cluster (primary-remote or multi-primary)
- Linkerd multi-cluster
- Provides:
  - mTLS across clusters
  - Locality-aware load balancing
  - Failover
  - Observability of east-west traffic

Good when you have many microservices that need to call each other across clusters without exposing them publicly.

### Option C — Submariner / Liqo / Cluster Federation

Useful for:
- Direct pod-to-pod or service-to-service across clusters without mesh
- On-prem + cloud bridging where native cloud networking is difficult

## Data Residency & Compliance Considerations

- Label namespaces and workloads with data classification and residency requirements.
- Use Kyverno policies to enforce scheduling constraints.
- For regulated workloads, consider dedicated clusters (or node pools with taints) in sovereign regions or on-prem.
- Logging and metrics must also respect residency (some providers allow regional backends).

## Failover & Resilience Patterns

- **Active-Active** (global education platform example): Two clouds, traffic split by DNS or anycast. State replicated asynchronously or via active-active database.
- **Active-Passive**: Primary in one cloud, warm standby in another. GitOps makes promoting the standby fast (change overlay or weights).
- **Regional Failover within Cloud** first, then cross-cloud.
- Database and object storage replication must be designed and tested separately from Kubernetes layer.

## Cost in Multi-Cloud

- Different providers have different spot pricing, savings plans, and egress costs.
- OpenCost + per-cloud billing export gives unified visibility.
- Egress between clouds can become a major cost driver — minimize cross-cloud chatter or use private interconnect pricing.
- Use the cost simulation tooling to model "what if 40% of traffic moves to the cheaper region/provider?"

## Operational Model

- **One GitOps control plane** (or federated) that can reach all clusters (via OIDC + network).
- **Central observability** (Thanos, Loki multi-tenant, or Grafana Cloud / commercial) with per-cluster retention policies.
- **Central policy** (Kyverno can be deployed per-cluster or with a central reporting aggregator).
- **Platform team owns the abstractions**, application teams own workload overlays.

## Common Pitfalls & Mitigations

| Pitfall                        | Mitigation |
|--------------------------------|------------|
| Drift between cloud implementations | Strong Terraform modules + automated drift detection |
| "It works on AWS but not GKE" | Integration tests in CI against all target clouds (kind + cloud test accounts) |
| Egress cost explosion          | NetworkPolicy + service mesh + caching + private links |
| Identity & auth inconsistency  | Workload Identity federation + consistent service accounts |
| Stateful workloads that assume single cloud | Design for portability early or isolate them deliberately |
| Different Kubernetes versions  | Standardize on N-1 or N-2 and upgrade all clusters together |

## Example Layout in This Repo

```
terraform/
  aws/          # EKS + VPC + IAM + Karpenter node templates
  gcp/          # GKE + networking + workload identity
  azure/        # AKS + ...
  onprem/       # Cluster API or manual + Talos/VMware examples (light)
manifests/
  environments/
    prod/
      base/
      overlays/
        aws/
        gcp/
        hybrid/
```

## Next Steps for Implementation

1. Choose primary + secondary cloud (or on-prem + one cloud).
2. Stand up one cluster in each using the Terraform modules.
3. Deploy the common GitOps + policy + observability stack via the same manifests.
4. Define your first portable application and prove cross-cluster traffic + failover.
5. Add cost allocation and run a multi-cloud cost simulation.

For detailed Terraform variable references and example `tfvars`, see the subdirectories under `terraform/`.

Hybrid and multi-cloud done right is a strategic advantage. Done poorly, it is the most expensive form of technical debt. This blueprint gives you the guardrails to do it right.
