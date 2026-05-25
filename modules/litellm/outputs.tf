output "litellm_url" {
  description = "The HTTPS URL of the deployed LiteLLM Proxy Cloud Run service."
  value       = google_cloud_run_v2_service.litellm.uri
}

output "master_key" {
  description = "The LiteLLM master API key."
  value       = local.actual_master_key
  sensitive   = true
}
