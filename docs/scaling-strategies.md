# Scaling Strategies

**Proven Patterns for Scaling Kubernetes to Hundreds of Thousands of Users**

This document captures the technical and operational patterns that have supported global education and training platforms through extreme, bursty, and sustained load.

## Executive Summary for CTOs

- **Business Context**: Education platforms experience sharp, predictable peaks (exam windows, enrollment periods, certification deadlines) followed by long troughs. Cost efficiency during troughs and reliability during peaks are both non-negotiable.
- **Key Levers**:
  - Cluster autoscaling (Karpenter) with heavy spot utilization
  - Workload autoscaling (HPA + VPA + custom metrics)
  - GitOps-driven progressive delivery and instant rollback
  - Multi-cluster and hybrid placement for both capacity and resilience
  - Load testing and capacity modeling as first-class platform capabilities
- **Measured Outcomes** (from production-scale simulations and real deployments):
  - Handle 5–10× normal traffic with < 30s node provisioning
  - Maintain > 99.95% availability during global peak events
  - Reduce steady-state cost by 35–55% through intelligent scaling and spot

## Core Scaling Dimensions

1. **Horizontal Pod Autoscaling (HPA)**
2. **Vertical Pod Autoscaling (VPA)**
3. **Cluster Autoscaling (Karpenter primary)**
4. **Application Architecture Patterns**
5. **Multi-Cluster & Geographic Distribution**
6. **Capacity Planning & Load Testing**

## 1. Horizontal Pod Autoscaling (HPA)

**Recommended Configuration**:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: learner-api
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: learner-api
  minReplicas: 3
  maxReplicas: 180
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 65
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
```

**Custom Metrics** (highly recommended for education platforms):
- Requests per second (via ingress controller or app metrics)
- Queue depth (for background job workers)
- Active concurrent learners (business metric)
- Error rate or latency p99 as scale trigger (with care)

Use the Kubernetes Metrics Server + Prometheus Adapter or KEDA for richer event-driven scaling.

## 2. Vertical Pod Autoscaling (VPA)

**Modes**:
- `Off` / Recommendation only (safest for most teams initially)
- `Initial` — sets requests at pod creation
- `Auto` — mutates pods in place (requires restart; use cautiously)

**Best Practice**:
- Run VPA in recommendation mode for 2–4 weeks on new services.
- Review recommendations in Grafana (or VPA dashboard).
- Promote well-understood stateless services to `Auto` or apply recommendations via GitOps PRs.
- Never use VPA Auto on stateful sets or databases without deep understanding.

VPA + HPA can coexist when configured carefully (VPA updates requests; HPA reacts to utilization).

## 3. Cluster Autoscaling with Karpenter (Primary Recommendation)

Karpenter advantages over traditional Cluster Autoscaler + node groups:
- Provisions nodes in seconds to low minutes
- Excellent spot support with automatic interruption handling
- Bin packing and consolidation (removes nodes when utilization drops)
- Flexible NodePools / NodeClaims instead of rigid ASGs

**Production NodePool Examples** (see `manifests/clusters/`):

- `spot-general`: High spot ratio, consolidation enabled, for stateless bursty workloads
- `on-demand-critical`: Small pool for system and latency-sensitive components
- `gpu-training`: For ML/batch workloads with different taints and AMIs

**Disruption Budgets & Consolidation**:
Always define PodDisruptionBudgets. Karpenter respects them during consolidation.

**Example Consolidation Settings**:
```yaml
spec:
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 10m
```

## 4. Application Architecture Patterns That Scale

- **Stateless first**: Design services to be horizontally scalable with external state (databases, caches, object storage).
- **Graceful degradation**: Feature flags or circuit breakers so core learning paths remain available even if secondary services are degraded.
- **Idempotent background jobs**: Use queues (SQS, Pub/Sub, RabbitMQ, or Kubernetes-native) with dead-letter handling.
- **Connection pooling & backpressure**: Prevent cascading failures under load.
- **Read replicas and caching layers**: Reduce load on primary databases during peaks.
- **Asynchronous user flows** where possible (enrollment confirmations, certificate generation).

## 5. Multi-Cluster and Geographic Distribution

**Placement Strategies**:
- **Latency-sensitive user traffic**: Route to nearest healthy cluster (anycast DNS + health checks or global LB).
- **Batch / heavy compute**: Place in the cloud/region with best spot pricing or capacity at that moment.
- **Data residency**: Hard constraints via node affinity + policy (Kyverno).
- **Blast radius reduction**: Critical path services run in at least two clusters; non-critical can be single-cluster with fast restore.

**GitOps for Multi-Cluster**:
- Single repo with directory or Kustomize overlays per cluster/environment.
- Flux or Argo CD ApplicationSets or App-of-Apps pattern.
- Progressive rollout: merge to `staging` overlay → validate → promote to `prod` overlays.

**Global Traffic Management**:
- ExternalDNS + cloud DNS or Cloudflare / Route53 latency / geolocation routing.
- Service mesh with global control plane (Istio) for L7 routing and failover.

## 6. Capacity Planning & Load Testing

This repo includes tooling to make load testing a repeatable platform capability.

### `scripts/scaling-test.sh`

```bash
./scripts/scaling-test.sh \
  --target-cluster staging \
  --scenario exam-window-peak \
  --virtual-users 25000 \
  --duration 45m \
  --ramp-up 10m
```

Features:
- Uses Locust, k6, or Vegeta (configurable)
- Records cluster metrics before/during/after (nodes, pods, CPU, cost impact)
- Generates report with saturation points, scaling lag, error budget burn
- Can be run in CI against ephemeral clusters for regression

### Capacity Modeling

- Maintain a simple model: peak concurrent learners → requests/sec → required replicas → required vCPU/memory → nodes (considering bin packing).
- Update the model after every major release and after every real peak event.
- Feed the model into the cost simulation (`scripts/cost-simulation.sh`) to understand cost of headroom.

### Predictive / Scheduled Scaling

For known events (exam seasons):
- Pre-warm node capacity via scheduled Karpenter NodeClaims or Cluster Autoscaler over-provisioner.
- Increase base replica counts via GitOps PRs that are merged ahead of time with time-based comments.
- Use KEDA scaled objects with cron triggers.

## Chaos & Resilience Validation

- Regularly inject failures (node termination, zone outage, database failover) using Chaos Mesh or Litmus.
- Validate that GitOps + autoscaling + circuit breakers recover within SLO.
- Document "game day" results in `docs/lessons-learned.md` updates.

## SLOs and Error Budgets

Define service level objectives that matter to learners and the business:

- Availability: 99.95% for core learning path during peak windows
- Latency: p95 < 800ms for key learner actions
- Error rate: < 0.1% for critical transactions

Tie scaling policies and alerting to error budget burn rate (see `docs/metrics-monitoring-and-observability.md`).

## Common Anti-Patterns to Avoid

- Over-reliance on cluster autoscaler with large node groups (slow and wasteful)
- HPA maxReplicas set too low "because we never tested higher"
- No PDBs → Karpenter or node upgrades evict everything
- Stateful workloads that assume they are the only instance
- Ignoring cold start latency of new nodes for latency-sensitive paths (use over-provisioning or warm pools)
- Manual scaling during incidents (leads to human error and audit issues)

## Rollout & Validation Checklist

- [ ] All production workloads have HPA with reasonable min/max and custom metrics where possible
- [ ] VPA recommendations reviewed for top 20 services
- [ ] Karpenter deployed with at least two NodePools (spot + on-demand)
- [ ] PodDisruptionBudgets and topology spread constraints on all important workloads
- [ ] Load test executed against staging that reaches 3–5× expected peak
- [ ] Multi-cluster failover drill completed successfully
- [ ] Cost impact of scaling captured and reported to finance

## References

- Kubernetes HPA / VPA documentation
- Karpenter production guide: https://karpenter.sh
- KEDA: https://keda.sh (event-driven scaling)
- Google SRE Workbook — Capacity Planning chapter
- CNCF Scalability Working Group materials

Scaling is not just about handling more traffic. It is about doing so predictably, cost-efficiently, and without waking the CTO at 3 a.m. during the biggest enrollment window of the year.
