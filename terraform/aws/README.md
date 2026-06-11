# Terraform AWS - EKS Provisioning

This module provisions a production-grade Amazon EKS cluster with:
- VPC with public + private subnets
- EKS control plane + small initial managed node group
- OIDC provider for IRSA (required for Karpenter, etc.)
- Karpenter IAM role

## Usage

```bash
cd terraform/aws

terraform init
terraform plan -var-file=../../environments/aws-prod.tfvars
terraform apply -var-file=../../environments/aws-prod.tfvars
```

After apply, use the outputs to bootstrap GitOps (Flux or Argo CD) and install platform components (Kyverno, OpenCost, monitoring).

## Important Outputs for Platform Bootstrap

- `cluster_name`
- `cluster_endpoint`
- `cluster_ca_certificate`
- `oidc_provider_arn`
- `karpenter_iam_role_arn`

Feed these into your GitOps configuration or `scripts/setup-*.sh` bootstrap jobs.

## Multi-Environment Pattern

Create one tfvars file per environment/region:

- `dev-us-east-1.tfvars`
- `staging-us-west-2.tfvars`
- `prod-us-east-1.tfvars`
- `prod-eu-central-1.tfvars`

## Cost Tagging

All resources receive consistent tags for OpenCost + cloud billing correlation:
- ManagedBy
- Environment
- CostCenter
- Owner

## Next Steps After Provisioning

1. Update your kubeconfig
2. Apply or let GitOps install Kyverno + policies
3. Install Karpenter (using the IAM role ARN from outputs)
4. Install OpenCost + configure cloudCost with CUR
5. Deploy observability stack

See root README and `scripts/` for automation.
