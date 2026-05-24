output "project_id" {
  description = "The ID of the GCP project"
  value       = var.create_project ? google_project.workstation_project[0].project_id : var.project_id
}

output "artifact_registry_id" {
  description = "The ID of the Artifact Registry repository."
  value       = google_artifact_registry_repository.repo.id
}

output "artifact_registry_url" {
  description = "The URL of the Artifact Registry repository."
  value       = "${var.region}-docker.pkg.dev/${var.create_project ? google_project.workstation_project[0].project_id : var.project_id}/${google_artifact_registry_repository.repo.repository_id}"
}

output "workstations_service_account_email" {
  description = "The email of the dedicated workstations service account"
  value       = google_service_account.workstations_sa.email
}

