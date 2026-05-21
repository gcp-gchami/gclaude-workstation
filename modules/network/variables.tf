variable "project_id" {
  description = "The project ID."
  type        = string
}

variable "region" {
  description = "The region to deploy the network resources in."
  type        = string
}

variable "network_name" {
  description = "Name of the VPC network."
  type        = string
  default     = "workstations-vpc"
}

variable "subnet_name" {
  description = "Name of the subnet."
  type        = string
  default     = "workstations-subnet"
}

variable "subnet_cidr" {
  description = "CIDR range for the subnet."
  type        = string
  default     = "10.0.0.0/24"
}
