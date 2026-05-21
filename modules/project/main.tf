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
    "iam.googleapis.com"
  ]
}

resource "google_project_service" "project_apis" {
  for_each = toset(local.apis)

  project = var.create_project ? google_project.workstation_project[0].project_id : var.project_id
  service = each.key

  disable_on_destroy = false
}
