# terraform/aws/variables.tf

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "cost_center" {
  description = "Cost center for tagging and chargeback"
  type        = string
  default     = "platform-infra"
}

variable "owner" {
  description = "Team or individual responsible"
  type        = string
  default     = "platform-engineering"
}

variable "vpc_cidr" {
  type    = string
  default = "10.42.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.42.1.0/24", "10.42.2.0/24", "10.42.3.0/24"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.42.101.0/24", "10.42.102.0/24", "10.42.103.0/24"]
}

variable "cluster_endpoint_public_access" {
  type    = bool
  default = true
}
