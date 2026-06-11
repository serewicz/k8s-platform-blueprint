# Cost Optimization and FinOps

**Strategic Priority for CTOs and Platform Leaders**

This document provides production-grade patterns for achieving transparent, controllable, and optimizable Kubernetes spend across single-cloud, multi-cloud, and hybrid environments.

## Executive Summary for CTOs

- **Problem**: Kubernetes often becomes a cost black box within 6–12 months. Finance cannot attribute spend; teams over-provision "just in case."
- **Solution**: Treat cost as a first-class platform concern with allocation, visibility, automation, and simulation from day one.
- **Expected Outcomes** (validated in large-scale education platform simulations):
  - 30–55% reduction in compute cost through spot + right-sizing + consolidation.
  - Clear per-tenant / per-product unit economics (cost per active learner, cost per certificate).
  - Finance-grade chargeback/showback reports that integrate with ERP or BI systems.
  - Predictable budgeting with alerts before overspend occurs.

## Core Components

### 1. OpenCost (Primary Open-Source Engine)

OpenCost is deployed in every cluster and provides:
- Real-time cost allocation by namespace, label, controller, pod.
- Integration with cloud billing exports (AWS CUR, GCP BigQuery Billing, Azure Cost Management).
- Prometheus metrics for cost (used in Grafana dashboards).
- CSV/JSON export for chargeback pipelines.

**Installation pattern** (see `manifests/` and `scripts/setup-kind.sh`):

```yaml
# Example values for OpenCost Helm
opencost:
  prometheus:
    internal: true
  cloudCost:
    enabled: true
```

**Mandatory Labels** (enforced by Kyverno policy):
- `cost-center`
- `team` / `owner`
- `product` or `service`
- `environment` (dev/staging/prod)
- `data-classification` (optional but recommended)

Without these labels, pods are rejected or placed in a high-visibility "unallocated" bucket that triggers alerts.

### 2. Kubecost-like Feature Parity (Open Source)

While commercial Kubecost offers excellent UX, the following can be achieved with OpenCost + custom Grafana + VPA + scripts:

- Right-sizing recommendations (VPA + custom queries)
- Idle workload detection (low CPU/memory utilization over time)
- Spot vs On-Demand breakdown
- Shared overhead allocation (platform control plane, ingress, monitoring)
- Savings estimation reports

See `scripts/cost-simulation.sh` for modeling.

### 3. Autoscaling for Cost (Karpenter + Cluster Autoscaler)

Karpenter is the recommended cluster autoscaler:

**Benefits**:
- Sub-minute node provisioning
- Native spot support with interruption handling
- Bin-packing and consolidation (removes underutilized nodes)
- Node templates / NodeClaims per workload class (spot, on-demand, GPU, etc.)

**Example NodePool** (in `manifests/clusters/`):

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: spot-general
spec:
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
  template:
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
      nodeClassRef:
        name: default
```

Combine with:
- **HPA** for application scaling (CPU, memory, custom metrics like requests-per-second or queue depth).
- **VPA** in recommendation mode (or auto for stateless services after validation).
- Pod Disruption Budgets and topology spread constraints.

### 4. Resource Quotas, Limits, and Namespace Budgets

Every tenant namespace must declare:
- `ResourceQuota` for CPU/memory/pods.
- `LimitRange` for default requests/limits.
- Budget annotations consumed by OpenCost and Alertmanager.

Example in `manifests/environments/prod/tenant-quotas.yaml`.

### 5. Chargeback & Showback

Two delivery mechanisms:

1. **Automated Reports** (`scripts/cost-simulation.sh --export-chargeback`)
   - Generates per-namespace monthly CSV + JSON.
   - Includes platform overhead allocation.

2. **Grafana + Export**
   - CTO dashboard contains "Cost by Team / Product" panels with "Export to CSV" and "Send to Finance" webhook examples.

Integration points:
- Push to S3 / GCS bucket for finance ingestion.
- Webhook to Slack/Teams + email for budget owners.
- API export for internal billing systems.

### 6. Idle Cost Reduction

Common sources of waste and mitigations:

| Source              | Detection                     | Mitigation                              | Typical Savings |
|---------------------|-------------------------------|-----------------------------------------|-----------------|
| Over-provisioned requests | VPA + utilization dashboards | Right-size via VPA / manual PR         | 15-30%         |
| Idle deployments    | Low 7-day avg CPU < 5%        | Scale to zero or reduce replicas        | 10-20%         |
| Orphaned volumes    | OpenCost + cloud reports      | Policy + cleanup jobs                   | 5-8%           |
| Dev/staging left running | Scheduled scaling + budgets | Karpenter consolidation + time-based shutdown | 8-15%     |
| Over-provisioned node pools | Karpenter logs          | Use mixed capacity + spot               | 20-40%         |

### 7. Multi-Cloud Billing Integration

- **AWS**: CUR (Cost and Usage Report) + Athena or OpenCost CUR integration.
- **GCP**: BigQuery billing export + OpenCost cloudCost.
- **Azure**: Cost Management exports to storage account.
- **On-Prem / VMware**: Use node cost modeling (fixed cost per core or negotiated rate) configured in OpenCost.

**Unified View**: All clusters export cost metrics in the same Prometheus format. Grafana aggregates across clusters using labels (`cluster`, `provider`, `region`).

### 8. Budgeting, Alerts, and Forecasting

- Namespace-level budget via annotations: `cost.platform.blueprint/budget-monthly: "4500"`.
- Alertmanager rules fire when projected monthly spend > 80% / 100% of budget.
- Forecasting: Use historical data + simple linear regression in scripts or Grafana.
- "FinOps Friday" automation: weekly email to budget owners with top 5 cost drivers and recommended actions.

### 9. Simulation & ROI Tooling

`scripts/cost-simulation.sh` supports scenarios:

```bash
./scripts/cost-simulation.sh \
  --scenario education-platform \
  --nodes 180 \
  --spot-percent 65 \
  --rightsize-aggressiveness medium \
  --duration-days 90
```

Outputs:
- Baseline monthly cost
- Optimized monthly cost
- Savings (absolute + %)
- Payback period for engineering effort
- Recommended PRs / policy changes

Use these numbers directly in business cases and board decks.

### 10. Governance of Cost

- Kyverno policies require cost labels and reasonable requests/limits.
- PR checks (in `.github/workflows`) can block merges that would materially increase cost without justification.
- Cost center owners are paged on budget breaches (via Alertmanager + PagerDuty/Opsgenie integration examples).

## Recommended Rollout Sequence

1. Deploy OpenCost + labels policy (Week 1)
2. Instrument all existing namespaces with labels (Week 1-2)
3. Deploy Karpenter + initial NodePools (Week 2-3)
4. Enable VPA recommendations + review top 20 workloads (Week 3-4)
5. Stand up chargeback reports and share with finance (Week 4-5)
6. Implement budget alerts and FinOps rituals (Week 5-6)
7. Run first major savings simulation and present to leadership (Week 6-8)

## Metrics That Matter to Executives

- Cost per active learner / tenant / transaction (monthly trend)
- % of workloads on spot
- Idle capacity % (cluster and workload)
- Unallocated spend %
- Forecast accuracy (actual vs predicted spend)
- Savings realized vs. baseline (tracked in CTO dashboard)

For dashboards and sample queries, see:
- `docs/metrics-monitoring-and-observability.md`
- `docs/cto-dashboard-and-roi.md`
- `manifests/apps/opencost/`

## References & Further Reading

- OpenCost documentation: https://www.opencost.io
- Karpenter: https://karpenter.sh
- FinOps Foundation: https://www.finops.org
- CNCF Cost Optimization Whitepaper

This FinOps foundation turns Kubernetes from a potential cost liability into a strategic advantage with measurable, defensible unit economics.
