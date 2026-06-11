# On-Prem / Bare Metal / VMware

This directory contains guidance and lightweight examples for bringing on-premises or private cloud clusters into the platform blueprint.

## Recommended Approaches

1. **Cluster API (CAPI)** + provider for your infrastructure (vSphere, Metal3, etc.)
2. **Talos Linux** or **Flatcar** for immutable OS nodes
3. **Kubeadm** or **k3s** for simpler edge / training environments

## Key Integration Points

- Ensure nodes are labeled with `topology.kubernetes.io/region` and `topology.kubernetes.io/zone`
- Install a CNI that supports NetworkPolicy (Calico or Cilium recommended)
- Configure local OpenCost "cloud" provider with fixed per-core or negotiated rates
- Use the same Kyverno policies and GitOps manifests
- For hybrid connectivity, evaluate Submariner, Cilium ClusterMesh, or service mesh multi-cluster

## Example Node Labels for On-Prem

```yaml
labels:
  topology.kubernetes.io/region: onprem-dc1
  topology.kubernetes.io/zone: rack-07
  node.kubernetes.io/capacity-type: on-prem
  cost.platform.blueprint/rate: "0.032"   # $/vCPU-hour negotiated
```

## Cost Modeling

Edit `opencost` values or configuration to provide a static cost model for on-prem nodes so that executive dashboards remain accurate.

## Compliance Note

On-prem clusters often have the strictest data residency or air-gap requirements. Use the policy library and consider running a local Kyverno + OpenCost + Prometheus stack with carefully controlled egress.
