# Lessons Learned

**Hard-Won Insights from Scaling Global Education and Training Platforms on Kubernetes**

This document captures the most important real-world lessons, anti-patterns, and organizational patterns observed while operating Kubernetes platforms at significant scale (hundreds of thousands of learners, multi-cloud, strict compliance).

## Executive Summary for CTOs

- Technology choices are rarely the root cause of failure. Process, incentives, and visibility gaps are.
- Cost surprises almost always trace back to missing allocation labels and missing feedback loops to the teams making architectural decisions.
- Compliance and security theater (policies that are not enforced or not understood) is more dangerous than having fewer controls.
- The highest-leverage investments are usually in **observability + GitOps + policy-as-code + simulation tooling** — not in exotic new controllers.
- Organizational alignment between platform, security, finance, and product teams determines success more than any single technical decision.

## Category 1: Cost & FinOps Lessons

### 1.1 "We'll add cost visibility later" is the most expensive sentence in platform engineering

- Teams that deployed OpenCost + mandatory cost labels in month 1 had dramatically better unit economics 18 months later.
- Teams that waited until "we're bigger" discovered they had 40–60% waste that had become culturally normalized.
- **Recommendation**: Treat cost allocation labels as non-negotiable as `app` or `environment` labels. Enforce via policy on day one.

### 1.2 Spot is transformative but requires engineering investment

- Naïve "just turn on spot" leads to frequent interruptions during exams or certification windows.
- Successful teams:
  - Maintain a small but sufficient on-demand buffer for critical paths
  - Use interruption handling + graceful draining
  - Test spot-heavy configurations during real load tests
- Typical sustainable spot ratio in bursty education workloads: 55–75% for stateless, much lower for stateful or latency-critical.

### 1.3 Right-sizing is a cultural change, not a one-time project

- VPA recommendations sitting in a dashboard do nothing until someone is incentivized (or required) to act on them.
- Best results came from:
  - Including right-sizing in the definition of "ready for production"
  - Monthly cost review rituals with team-level accountability
  - PR templates that require justification for large request increases

### 1.4 Shared platform costs must be allocated visibly

- When platform overhead (monitoring, ingress, control plane, shared services) is not allocated, application teams treat it as "free" and over-consume.
- Transparent allocation (even if not charged) dramatically improves behavior.

## Category 2: Governance & Policy Lessons

### 2.1 Policy-as-code without good error messages creates shadow IT

- Early Kyverno policies that only said "denied by policy" led teams to bypass via side channels or "temporary" exceptions that became permanent.
- **Fix**: Every policy denial must include:
  - Clear human-readable explanation
  - Link to the policy source in Git
  - Suggested remediation (often an automated PR or Helm value change)

### 2.2 Start with audit, move to enforce — but set deadlines

- Running everything in `audit` mode for "a while" often becomes "forever."
- Successful programs set explicit dates: "All production namespaces must pass critical policies in enforce mode by 2026-09-01, tracked weekly."

### 2.3 Image signing is worthless without a reliable build pipeline

- Many teams tried to require signed images before their CI could reliably produce them.
- Result: either blanket exceptions or developers disabling verification locally.
- Sequence matters: reliable signed builds first → verification second.

### 2.4 Break-glass procedures must be tested and logged

- Having a break-glass process on paper is common.
- Having one that was actually used in a real incident (with a ticket, time-box, and post-use cleanup PR) is rare and valuable.
- Test it quarterly.

## Category 3: Scaling & Architecture Lessons

### 3.1 Karpenter changed the economics of capacity

- Before Karpenter (or equivalent), teams kept large idle node groups "just in case."
- After: teams could afford to run much closer to actual utilization because provisioning was fast and spot was easy.
- Still need good requests/limits and PDBs, or consolidation will fight you.

### 3.2 Multi-cluster is easier than you fear, harder than you hope

- The hard parts are rarely the Kubernetes layer.
- The hard parts are:
  - Data replication and consistency
  - Cross-cluster observability and debugging
  - Identity and secret propagation
  - Cost of cross-cloud egress
- Start with one non-critical workload across two clusters before you move the crown jewels.

### 3.3 Load testing must be a platform capability, not a heroics event

- Teams that could spin up a realistic load test against a staging environment in < 30 minutes with one command found scaling problems early.
- Teams that only tested "when we were worried" shipped fragile systems.
- Invest in `scripts/scaling-test.sh` and CI jobs that run against ephemeral environments.

### 3.4 Stateful workloads are the exception that proves the rule

- Most education platform state should live in managed databases, object storage, or caches — not in Kubernetes.
- When you must run stateful in-cluster (training clusters, certain search engines), treat them as special snowflakes with dedicated NodePools, taints, and much more conservative scaling policies.

## Category 4: Observability & Incident Lessons

### 4.1 Dashboards for executives must be deliberately designed, not derived

- Giving the CTO the same 47-panel SRE dashboard as the on-call engineer does not help.
- The CTO folder in Grafana was created by starting with the questions executives actually ask and building backward to the data.
- Update these dashboards after every major incident or cost surprise.

### 4.2 Error budgets beat threshold alerts for business alignment

- "Latency p99 > 800ms" is technical.
- "We burned 12% of our monthly error budget for assessment submission in the last 4 hours" is actionable and strategic.
- Tie scaling, rollback, and feature-freeze decisions to error budget.

### 4.3 Observability debt compounds faster than technical debt

- Missing labels, high-cardinality metrics, and absent traces become exponentially more painful as you add clusters and teams.
- Enforce basic instrumentation standards via policy and code review checklists.

## Category 5: Organizational & Process Lessons

### 5.1 Platform teams that report cost and risk numbers monthly to leadership have more influence

- When the platform team can walk into a meeting with "here is the ROI of the last three initiatives and the current risk heatmap," they stop being seen as a cost center.
- This requires the dashboards and simulation tooling in this repo.

### 5.2 Finance partnership is a superpower

- The most successful programs had a finance partner who understood Kubernetes unit economics and helped design the chargeback model.
- This person often became the strongest advocate for platform investment because they could see the margin impact.

### 5.3 "Just add another cluster" is rarely the right answer

- New clusters increase operational surface area, policy surface area, and observability complexity.
- Prefer scaling within a cluster (with good multi-tenancy) until you have a clear resiliency, residency, or capacity reason for another cluster.

### 5.4 The best reference architectures are living documents

- This repo is a snapshot. The teams that got the most value updated their internal copy after every major release, incident, or cost review.
- Treat `docs/lessons-learned.md` as a required update in your post-incident and post-peak rituals.

## Anti-Patterns Observed

1. **The "We'll fix it in the next cluster"** — accumulating technical and process debt because "this one is almost end-of-life."
2. **The compliance checkbox** — having beautiful policies that are all in audit mode or have massive exception lists.
3. **The cost black hole** — no labels, no one owns the bill, surprise $400k cloud invoice.
4. **The heroic on-call** — manual scaling and firefighting during every peak because automation and testing were never prioritized.
5. **The beautiful dashboard no one looks at** — 60 panels, zero executive or business context, used only during incidents.
6. **The one true cluster** — everything in a single massive cluster with no blast radius boundaries.

## Positive Patterns That Scaled

- GitOps + small, frequent, reviewed changes
- Policy-as-code with excellent developer experience (clear messages, auto-remediation where possible)
- Cost visibility and accountability at the team level from the beginning
- Regular game days and load tests treated as platform features
- Executive dashboards that are intentionally curated and maintained
- Cross-functional rituals (Platform + Finance + Security + Product) on a predictable cadence

## How to Use This Document

- When planning a new environment or major initiative, review the relevant category.
- After every significant incident or cost event, add a new entry (or update an existing one).
- Use excerpts in onboarding for new platform engineers and in presentations to leadership.
- Turn the most painful lessons into automated checks or policy where possible.

## Contributing New Lessons

If you operate this blueprint (or something derived from it) at scale and learn something important, please contribute back via PR. Update this file with:
- Context (scale, industry, constraints)
- What happened
- What we learned
- What changed in process, policy, or tooling as a result
- "How this helps CTOs" if applicable

The goal is to make the next team that follows this path avoid at least some of the pain we went through.
