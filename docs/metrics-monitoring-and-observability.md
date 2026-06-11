# Metrics, Monitoring, and Observability

**Full-Stack Observability for Platform Reliability and Executive Decision-Making**

## Executive Summary for CTOs

Observability in this blueprint serves two equally important audiences:
1. **Platform and application teams** — deep, actionable signals for reliability and performance.
2. **CTOs and business leaders** — aggregated views that translate technical health into business outcomes (cost efficiency, risk posture, learner experience, ROI).

The stack is deliberately CNCF-aligned, cost-effective at scale, and includes pre-built executive dashboards.

## Recommended Stack

| Component       | Purpose                              | Why Chosen |
|-----------------|--------------------------------------|----------|
| Prometheus      | Metrics collection & storage         | Kubernetes-native, powerful query language, ecosystem |
| Grafana         | Visualization & alerting             | Best-in-class dashboards, unified data source support, folder/permissions model |
| Loki            | Log aggregation (label-based)        | Low cost, integrates perfectly with Kubernetes labels |
| OpenTelemetry   | Instrumentation & trace collection   | Vendor-neutral, future-proof, broad language support |
| Tempo / Jaeger  | Distributed tracing                  | Correlates with metrics & logs |
| Alertmanager    | Alert routing & grouping             | Integrates with Slack, PagerDuty, email, etc. |
| Thanos (optional)| Long-term + multi-cluster metrics   | Global view + cheap long-term storage |

All components are deployed via GitOps manifests in `manifests/` and configured for multi-cluster.

## Architecture Overview

```mermaid
flowchart TB
    subgraph "Applications & Platform"
        Apps[Workloads + Sidecars<br/>OTel SDKs]
        K8s[Kubernetes Components]
    end

    subgraph "Collection"
        OTEL[OpenTelemetry Collector<br/>(DaemonSet + Deployment)]
        Prom[Prometheus + kube-state-metrics<br/>+ node-exporter + cadvisor]
        Promtail[Promtail / Alloy]
    end

    subgraph "Storage & Processing"
        PromDB[(Prometheus / Thanos)]
        LokiDB[(Loki)]
        TraceDB[(Tempo / Jaeger)]
    end

    subgraph "Presentation & Action"
        Graf[Grafana<br/>(Core + CTO folders)]
        Alert[Alertmanager]
        Reports[Compliance & Cost Reports]
    end

    Apps --> OTEL
    K8s --> Prom & Promtail
    OTEL --> PromDB & TraceDB
    Promtail --> LokiDB
    PromDB & LokiDB & TraceDB --> Graf
    PromDB --> Alert
    Graf --> Reports
```

## Key Metric Categories

### 1. Golden Signals (Platform & Application)
- Latency (p50, p95, p99)
- Traffic / throughput (requests/sec, active learners)
- Errors (rate + types)
- Saturation (CPU, memory, disk, queue depth)

### 2. Kubernetes Control Plane & Node Health
- API server latency and error rate
- etcd health
- Node readiness, pressure (memory/disk), and kubelet
- Pod scheduling latency and failures

### 3. Cost & FinOps Metrics (from OpenCost)
- Hourly / daily cost by namespace, team, product
- Spot vs on-demand utilization
- Idle cost %
- Projected monthly spend vs budget

### 4. Business & Learner Experience Metrics
- Active concurrent users / learners
- Course completion rate (or key funnel steps)
- Certificate issuance latency
- Support ticket volume correlated with platform events

### 5. Security & Compliance Signals
- Policy violation rate (Kyverno reports)
- Image freshness / unsigned image attempts
- RBAC change rate
- Network policy denials (from Cilium / Calico)

## Pre-Built Dashboards

### Core Platform Dashboards
- Kubernetes / Compute Overview
- Node & Pod Health
- Workload Golden Signals
- GitOps Sync Health (Flux or Argo)

### Cost & FinOps
- OpenCost Allocation by Namespace/Team
- Spot Utilization & Savings
- Budget vs Actual + Forecast
- Top Cost Drivers

### Executive / CTO Folder
Located under Grafana folder "CTO & Executive":
- **Platform ROI Overview**: Cost per active learner (trend), infrastructure efficiency, savings realized this quarter.
- **Risk & Compliance Heatmap**: Policy violations by severity, % of namespaces passing all critical policies, open high-severity findings.
- **Multi-Cluster Health**: One row per cluster or provider with health, cost, and traffic.
- **SLA / SLO Status**: Error budget burn for critical user journeys.
- **Capacity & Scaling Readiness**: Current headroom, last peak test results summary.

Dashboard JSONs are stored in `manifests/apps/grafana/dashboards/` and automatically provisioned.

## Alerting Philosophy

- **Page on symptoms that impact users or business**, not just infrastructure.
- **Warning on leading indicators** (rising error rate, budget burn, policy drift).
- Every alert includes:
  - Runbook link
  - Business impact annotation
  - Cost or compliance context where relevant
  - Graph panel link

Example high-severity rules:
- `LearnerAPIErrorRateHigh` → impacts course access
- `MonthlyCostProjectionOverBudget` → financial risk
- `CriticalPolicyViolationsInProd` → compliance & security risk
- `ErrorBudgetBurnRateFast` → SLO breach imminent

Alertmanager routes:
- Critical → PagerDuty / Opsgenie + Slack #incidents
- Warning → Slack #platform-alerts
- FinOps / Compliance → dedicated channels + email to budget owners

## Distributed Tracing & OpenTelemetry

- Instrument services with OpenTelemetry SDKs (auto-instrumentation where available).
- Export traces to Tempo or Jaeger.
- Correlate trace ID in logs (Loki) and metrics (exemplars in Prometheus).
- Use traces to debug tail latencies and cross-service issues that metrics alone miss.

Example instrumentation (Node.js, simplified):

```js
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');

const sdk = new NodeSDK({
  serviceName: 'learner-api',
  instrumentations: [getNodeAutoInstrumentations()],
});
sdk.start();
```

## Log Strategy (Loki)

- Use structured logging (JSON) with consistent fields: `level`, `trace_id`, `span_id`, `user_id` (hashed where PII), `tenant`, `request_id`.
- Keep high-cardinality labels out of Loki labels — put them in the log line and use parsers.
- Retention: 7–30 days hot, longer in cold storage or cloud logging export for compliance.

## Multi-Cluster Observability

- **Metrics**: Prometheus remote write to a central Thanos or VictoriaMetrics instance, or use Thanos sidecar + query layer.
- **Logs**: Loki multi-tenant or separate Loki instances with a query frontend.
- **Traces**: Single Tempo/Jaeger backend with cluster label or separate backends with federation.
- **Dashboards**: Use Grafana templating with `cluster` and `provider` variables.

## SLOs, Error Budgets, and Business Alignment

Define SLOs that map to learner outcomes and business goals:

| User Journey          | SLO Target     | Error Budget (monthly) | Alert on Burn Rate |
|-----------------------|----------------|------------------------|--------------------|
| View course content   | 99.9%          | ~43 min downtime       | 2% budget / hour   |
| Submit assessment     | 99.95%         | ~22 min downtime       | 1% budget / hour   |
| Issue certificate     | 99.5%          | ~3.6 hrs downtime      | Lower priority     |

Error budget burn rate alerts are more actionable than static "5xx rate > 1%" rules.

## Cost of Observability

- Prometheus + Loki is very cost-effective compared to commercial all-in-one solutions.
- Control retention and cardinality aggressively.
- Use recording rules and downsampling for long-term trends.
- The executive dashboards themselves have low query load.

## Implementation & Configuration Locations

- `manifests/apps/monitoring/` — Prometheus, Grafana, Loki, Alertmanager, OTel collector
- `manifests/apps/opencost/` — Cost metrics
- `manifests/clusters/policies/` — Policies that emit compliance signals
- `scripts/` — Validation and report generation
- Grafana dashboard provisioning: `manifests/apps/grafana/dashboards/`

## Operational Playbooks (Summary)

- High error rate on learner API → Check traces for slow dependency → Check recent GitOps change → Rollback via GitOps if needed.
- Sudden cost spike → OpenCost dashboard → Identify namespace + workload → Check for missing limits or new replica count → Create cost optimization PR.
- Policy violation in prod → Kyverno report → Find PR or manual change that introduced it → Remediate + add test.

## References

- Prometheus + Grafana best practices
- OpenTelemetry specification
- Loki label best practices
- Google SRE Workbook (SLIs, SLOs, Error Budgets)
- CNCF Observability Whitepapers

Good observability turns "the platform feels slow" into "p99 latency for certificate issuance increased 40% after the 14:22 deployment in us-west-2 — here is the exact trace and the rollback PR."

This is the level of precision and executive transparency this architecture delivers.
