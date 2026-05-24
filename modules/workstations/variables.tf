variable "project_id" {
  description = "The project ID."
  type        = string
}

variable "region" {
  description = "The region for the workstation cluster."
  type        = string
}

variable "network_id" {
  description = "The VPC network ID."
  type        = string
}

variable "subnetwork_id" {
  description = "The VPC subnetwork ID."
  type        = string
}

variable "cluster_id" {
  description = "ID of the workstation cluster."
  type        = string
  default     = "workstation-cluster"
}

variable "config_id" {
  description = "ID of the workstation config."
  type        = string
  default     = "workstation-config"
}

variable "machine_type" {
  description = "Machine type for the workstation (e.g. e2-standard-4)."
  type        = string
  default     = "e2-standard-4"
}

variable "disk_size_gb" {
  description = "Size of the persistent disk in GB."
  type        = number
  default     = 50
}

variable "workstation_users" {
  description = "A map where keys are workstation IDs (usernames) and values are user emails."
  type        = map(string)
  default     = {}
}

variable "image_url" {
  description = "The URL of the custom Docker image to use for the workstations."
  type        = string
  default     = ""
}

variable "service_account_email" {
  description = "The service account email attached to workstation VMs."
  type        = string
}

