variable "create_project" {
  description = "Whether to create a new project."
  type        = bool
  default     = false
}

variable "project_id" {
  description = "Project ID (new or existing)."
  type        = string
}

variable "billing_account_id" {
  description = "Billing account ID (required if create_project is true)."
  type        = string
  default     = ""
}

variable "org_id" {
  description = "Organization ID."
  type        = string
  default     = ""
}

variable "folder_id" {
  description = "Folder ID."
  type        = string
  default     = ""
}

variable "region" {
  description = "The region to deploy resources in."
  type        = string
  default     = "us-central1"
}

variable "workstation_users" {
  description = "A map where keys are workstation IDs (usernames) and values are user emails."
  type        = map(string)
  default     = {}
}

variable "litellm_master_key" {
  description = "The Master API Key used to authorize requests on the centralized LiteLLM proxy."
  type        = string
  sensitive   = true
  default     = "sk-litellm-master-key-1234" # A sensible secure default key
}
