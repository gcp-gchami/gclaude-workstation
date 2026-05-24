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

data "google_project" "current" {
  project_id = var.create_project ? google_project.workstation_project[0].project_id : var.project_id
}

locals {
  compute_sa = "${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

# Grant Storage Admin to the default Compute service account (used by Cloud Build to read source tarballs)
resource "google_project_iam_member" "compute_sa_storage" {
  project = data.google_project.current.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${local.compute_sa}"

  depends_on = [google_project_service.project_apis]
}

# Grant Log Writer to the default Compute service account (used by Cloud Build to write build logs)
resource "google_project_iam_member" "compute_sa_logging" {
  project = data.google_project.current.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${local.compute_sa}"

  depends_on = [google_project_service.project_apis]
}

# Grant Artifact Registry Writer to the default Compute service account (used by Cloud Build to push workstation images)
resource "google_project_iam_member" "compute_sa_artifactregistry" {
  project = data.google_project.current.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${local.compute_sa}"

  depends_on = [google_project_service.project_apis]
}



