output "project_id" {
  description = "The ID of the GCP project"
  value       = var.create_project ? google_project.workstation_project[0].project_id : var.project_id
}
