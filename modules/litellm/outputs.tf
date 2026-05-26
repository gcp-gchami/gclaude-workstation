output "litellm_url" {
  description = "The HTTPS URL of the deployed LiteLLM Proxy Cloud Run service."
  value       = google_cloud_run_v2_service.litellm.uri
}

output "master_key" {
  description = "The LiteLLM master API key."
  value       = local.actual_master_key
  sensitive   = true
}

output "master_key_secret_id" {
  description = "The Secret Manager secret ID for the LiteLLM master API key."
  value       = google_secret_manager_secret.litellm_master_key.secret_id
}

output "service_name" {
  description = "The name of the deployed Cloud Run service."
  value       = google_cloud_run_v2_service.litellm.name
}

