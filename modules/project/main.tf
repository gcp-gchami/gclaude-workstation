resource "google_project" "workstation_project" {
  count           = var.create_project ? 1 : 0
  name            = var.project_name != "" ? var.project_name : var.project_id
  project_id      = var.project_id
  billing_account = var.billing_account_id
  org_id          = var.org_id != "" ? var.org_id : null
  folder_id       = var.folder_id != "" ? var.folder_id : null
}

locals {
  apis = [
    "workstations.googleapis.com",
    "compute.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com"
  ]
}

resource "google_project_service" "project_apis" {
  for_each = toset(local.apis)

  project = var.create_project ? google_project.workstation_project[0].project_id : var.project_id
  service = each.key

  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "repo" {
  provider      = google-beta
  project       = var.create_project ? google_project.workstation_project[0].project_id : var.project_id
  location      = var.region
  repository_id = "workstations-repo"
  description   = "Docker repository for custom Workstation images"
  format        = "DOCKER"

  depends_on = [google_project_service.project_apis]
}

resource "google_project_organization_policy" "disable_os_login" {
  project    = var.create_project ? google_project.workstation_project[0].project_id : var.project_id
  constraint = "compute.requireOsLogin"

  boolean_policy {
    enforced = false
  }

  depends_on = [google_project_service.project_apis]
}

resource "google_project_organization_policy" "restore_vpc_peering" {
  project    = var.create_project ? google_project.workstation_project[0].project_id : var.project_id
  constraint = "compute.restrictVpcPeering"

  restore_policy {
    default = true
  }

  depends_on = [google_project_service.project_apis]
}

resource "google_project_organization_policy" "restore_trusted_images" {
  project    = var.create_project ? google_project.workstation_project[0].project_id : var.project_id
  constraint = "compute.trustedImageProjects"

  restore_policy {
    default = true
  }

  depends_on = [google_project_service.project_apis]
}


