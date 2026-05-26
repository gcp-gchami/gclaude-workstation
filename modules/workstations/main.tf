terraform {
  required_providers {
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.0.0"
    }
  }
}

resource "google_workstations_workstation_cluster" "cluster" {
  provider               = google-beta
  project                = var.project_id
  workstation_cluster_id = var.cluster_id
  network                = var.network_id
  subnetwork             = var.subnetwork_id
  location               = var.region
}

resource "google_workstations_workstation_config" "config" {
  provider               = google-beta
  project                = var.project_id
  workstation_config_id  = var.config_id
  workstation_cluster_id = google_workstations_workstation_cluster.cluster.workstation_cluster_id
  location               = var.region
  
  enable_audit_agent = true

  idle_timeout    = var.idle_timeout
  running_timeout = var.running_timeout

  host {
    gce_instance {
      machine_type                = var.machine_type
      boot_disk_size_gb           = var.disk_size_gb
      disable_public_ip_addresses = true
      service_account             = var.service_account_email

      shielded_instance_config {
        enable_secure_boot          = true
        enable_vtpm                 = true
        enable_integrity_monitoring = true
      }
    }
  }

  container {
    image = var.image_url != "" ? var.image_url : "us-central1-docker.pkg.dev/cloud-workstations-images/predefined/code-oss:latest"
    env = {
      ANTHROPIC_VERTEX_PROJECT_ID = var.project_id
      CLOUD_ML_REGION             = var.region
      CLAUDE_CODE_USE_VERTEX      = "1"
      LITELLM_BASE_URL            = "http://localhost:4000"
      LITELLM_UPSTREAM_URL        = var.litellm_url
      LITELLM_SERVICE_NAME        = var.litellm_service_name
    }
  }

  persistent_directories {
    mount_path = "/home"
    gce_pd {
      size_gb        = var.disk_size_gb
      fs_type        = "ext4"
      disk_type      = "pd-balanced"
      reclaim_policy = "RETAIN"
    }
  }
}

resource "google_workstations_workstation" "workstation" {
  for_each = var.workstation_users

  provider               = google-beta
  project                = var.project_id
  workstation_id         = each.key
  workstation_config_id  = google_workstations_workstation_config.config.workstation_config_id
  workstation_cluster_id = google_workstations_workstation_cluster.cluster.workstation_cluster_id
  location               = var.region
}

resource "google_workstations_workstation_iam_member" "workstation_user" {
  for_each = var.workstation_users

  provider               = google-beta
  project                = var.project_id
  location               = var.region
  workstation_cluster_id = google_workstations_workstation_cluster.cluster.workstation_cluster_id
  workstation_config_id  = google_workstations_workstation_config.config.workstation_config_id
  workstation_id         = google_workstations_workstation.workstation[each.key].workstation_id
  
  role   = "roles/workstations.user"
  member = "user:${each.value}"
}

# Create Secret Manager secrets for user-specific LiteLLM virtual keys
resource "google_secret_manager_secret" "user_key" {
  for_each = var.workstation_users

  project   = var.project_id
  secret_id = "litellm-user-key-${each.key}"

  replication {
    auto {}
  }
}

# Grant workstations service account permissions to write (add versions) and read (access versions) user keys
resource "google_secret_manager_secret_iam_member" "user_key_version_manager" {
  for_each = var.workstation_users

  project   = var.project_id
  secret_id = google_secret_manager_secret.user_key[each.key].secret_id
  role      = "roles/secretmanager.secretVersionManager"
  member    = "serviceAccount:${var.service_account_email}"
}

resource "google_secret_manager_secret_iam_member" "user_key_accessor" {
  for_each = var.workstation_users

  project   = var.project_id
  secret_id = google_secret_manager_secret.user_key[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.service_account_email}"
}

# Grant workstations service account read permission on the LiteLLM master key secret to allow dynamic key generation
resource "google_secret_manager_secret_iam_member" "master_key_accessor_workstation" {
  project   = var.project_id
  secret_id = var.litellm_master_key_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.service_account_email}"
}
