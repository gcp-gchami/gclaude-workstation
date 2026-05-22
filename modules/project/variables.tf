variable "create_project" {
  description = "Whether to create a new project or use an existing one."
  type        = bool
  default     = false
}

variable "project_id" {
  description = "The project ID. If create_project is true, this is the desired ID. If false, this is the existing project ID."
  type        = string
}

variable "project_name" {
  description = "The name of the project. Only used if create_project is true."
  type        = string
  default     = ""
}

variable "billing_account_id" {
  description = "The alphanumeric ID of the billing account this project belongs to."
  type        = string
  default     = ""
}

variable "org_id" {
  description = "The organization ID."
  type        = string
  default     = ""
}

variable "folder_id" {
  description = "The folder ID."
  type        = string
  default     = ""
}

variable "region" {
  description = "The region to deploy the Artifact Registry in."
  type        = string
}
