variable "project_id" {
  description = "The GCP project ID to deploy the LiteLLM Proxy in."
  type        = string
}

variable "region" {
  description = "The region to deploy the LiteLLM Cloud Run service in."
  type        = string
}

variable "master_key" {
  description = "The LiteLLM master API key to secure the proxy endpoint."
  type        = string
  sensitive   = true
}
