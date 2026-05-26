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

variable "vertex_ai_location" {
  description = "The regional location for Vertex AI models (e.g. us-east5)."
  type        = string
  default     = "us-east5"
}

