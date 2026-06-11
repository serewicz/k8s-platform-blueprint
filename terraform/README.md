# Terraform / Crossplane — Multi-Cloud Provisioning

This directory contains modular, production-grade infrastructure-as-code for provisioning Kubernetes clusters across clouds.

## Structure

```
terraform/
├── aws/       # EKS + VPC + Karpenter IAM + outputs
├── gcp/       # GKE + Workload Identity
├── azure/     # AKS + managed identity + workload identity
└── onprem/    # Guidance for bare metal / VMware / CAPI
```

## Design Goals

- Consistent outputs across providers (cluster name, endpoint, CA data, OIDC/workload identity info)
- Strong cost and ownership tagging from day one
- Ready for immediate GitOps bootstrap after `terraform apply`
- Minimal initial node groups — Karpenter (or cloud equivalent) does the heavy lifting

## Typical Flow

1. `cd terraform/aws`
2. `terraform init`
3. `terraform plan -var-file=prod-us-east.tfvars`
4. `terraform apply ...`
5. Capture outputs and feed into Flux/Argo CD bootstrap or `scripts/setup-*.sh`

## Crossplane Note

If you prefer to manage infrastructure using Kubernetes CRDs, the same patterns apply:
- Use Crossplane providers for AWS/GCP/Azure
- Define `Cluster` and `NodePool` style compositions
- Apply the same GitOps + policy + observability stack on top

Examples are lighter here but the architecture fully supports a Crossplane-based control plane.

## Important

Never commit real `tfstate` or long-lived credentials. Use remote state (S3 + DynamoDB, GCS, Azure Blob + locking) in production.
