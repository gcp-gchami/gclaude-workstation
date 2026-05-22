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
  
  host {
    gce_instance {
      machine_type                = var.machine_type
      boot_disk_size_gb           = var.disk_size_gb
      disable_public_ip_addresses = true

      shielded_instance_config {
        enable_secure_boot          = true
        enable_vtpm                 = true
        enable_integrity_monitoring = true
      }
    }
  }

  container {
    image = var.image_url != "" ? var.image_url : "us-central1-docker.pkg.dev/cloud-workstations-images/predefined/code-oss:latest"
  }

  persistent_directories {
    mount_path = "/home/user"
    gce_pd {
      size_gb        = var.disk_size_gb
      fs_type        = "ext4"
      disk_type      = "pd-standard"
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
