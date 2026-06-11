# Labs & Practical Demos

This directory contains hands-on, kind/minikube-friendly labs that demonstrate the key capabilities of the Kubernetes Platform Blueprint.

Target audience: platform engineers, architects, and technical executives who want to see the architecture working before committing to a full rollout.

## Lab 1: 15-Minute Local Platform (Recommended First Lab)

**Goal**: Reproduce the full reference stack on your laptop and explore the CTO dashboards.

```bash
git clone https://github.com/your-org/k8s-platform-blueprint.git
cd k8s-platform-blueprint

./scripts/setup-kind.sh --name blueprint-lab --nodes 3

# Explore
kubectl get ns
kubectl get pods -n monitoring
kubectl get pods -n opencost

# Access Grafana (CTO dashboards live here)
kubectl port-forward -n monitoring svc/grafana 3000:80
# Username: admin   Password: admin (or check the secret)
```

Inside Grafana:
- Navigate to the **CTO & Executive** folder
- Open "Platform ROI Overview"
- Open "Risk & Compliance Heatmap"

Run a quick cost simulation while the cluster is running:

```bash
./scripts/cost-simulation.sh --scenario education-platform --nodes 8 --spot-percent 60 --output-format markdown
```

## Lab 2: Policy-as-Code in Action

1. Deploy a "bad" pod that violates policy:

```bash
kubectl run bad-pod --image=busybox -- sleep 3600 -n dev-platform
```

2. Observe the denial (Kyverno should block or mutate).

3. Fix by adding proper labels + resources and re-apply.

4. Watch the policy report:

```bash
kubectl get clusterpolicyreports -o wide
```

## Lab 3: Scaling & Karpenter Behavior (Simulated)

Because kind does not have real cloud autoscaling, this lab focuses on:
- HPA behavior under artificial load
- Reviewing Karpenter NodePool definitions
- Running the synthetic scaling test script

```bash
kubectl apply -k manifests/environments/dev/
kubectl get hpa -n dev-platform

# Generate synthetic load report
./scripts/scaling-test.sh --target-cluster kind-blueprint-lab --virtual-users 8000 --duration 10m
```

Review the generated report in `scripts/output/`.

## Lab 4: Compliance Report Generation

```bash
./scripts/compliance-scan.sh --framework soc2
cat compliance-report-*.md
```

This produces artifacts you can hand to an auditor or include in a board pack.

## Lab 5: Multi-Environment Promotion (GitOps Mindset)

1. Make a small change in `manifests/environments/dev/sample-app.yaml` (increase replica count).
2. Promote the same change through staging and prod overlays using Kustomize.
3. (Optional) If Flux/Argo is installed, watch it sync the change.

This demonstrates the progressive delivery model used in real multi-cluster environments.

## Extending the Labs

- Add real load testing with k6 or Locust against the sample service.
- Integrate a real image signing demo (cosign + Kyverno verify).
- Stand up a second kind cluster and practice multi-cluster GitOps + connectivity patterns.

All labs are intentionally lightweight so that a motivated engineer or architect can complete the core tour in under an hour on a modern laptop.

## Feedback

If a lab is confusing or a script fails on your machine, please open an issue with:
- OS + kind/minikube version
- Exact command run
- Full error output

We treat lab friction as a first-class platform DX problem.
