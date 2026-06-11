# terraform/gcp/main.tf
# GKE cluster provisioning module for the platform blueprint.
# Uses Autopilot or Standard with workload identity + node auto-provisioning hints.

terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# GKE Cluster (Standard with initial node pool + node auto-provisioning)
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  release_channel {
    channel = "REGULAR"
  }

  initial_node_count       = 1
  remove_default_node_pool = true

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Enable network policy (Calico)
  network_policy {
    enabled = true
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  # Cost allocation labels for billing export
  resource_labels = {
    managedby   = "k8s-platform-blueprint"
    environment = var.environment
    costcenter  = var.cost_center
  }
}

# Primary node pool (small on-demand equivalent)
resource "google_container_node_pool" "primary_nodes" {
  name     = "primary"
  cluster  = google_container_cluster.primary.name
  location = var.region

  node_count = 2

  node_config {
    machine_type = "e2-standard-2"
    disk_size_gb = 50

    labels = {
      "node-pool" = "on-demand-critical"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    service_account = google_service_account.gke_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# Workload Identity service account
resource "google_service_account" "gke_nodes" {
  account_id   = "${var.cluster_name}-nodes"
  display_name = "GKE nodes for ${var.cluster_name}"
}

# Output for GitOps bootstrap
output "cluster_name" {
  value = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  value = google_container_cluster.primary.endpoint
}

output "cluster_ca_certificate" {
  value     = google_container_cluster.primary.master_auth.0.cluster_ca_certificate
  sensitive = true
}

output "workload_identity_pool" {
  value = google_container_cluster.primary.workload_identity_config[0].workload_pool
}
