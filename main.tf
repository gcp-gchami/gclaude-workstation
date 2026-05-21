terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.0.0"
    }
  }
}

provider "google" {
  region = var.region
}

provider "google-beta" {
  region = var.region
}

module "project" {
  source = "./modules/project"

  create_project     = var.create_project
  project_id         = var.project_id
  billing_account_id = var.billing_account_id
  org_id             = var.org_id
  folder_id          = var.folder_id
}

module "network" {
  source = "./modules/network"

  project_id = module.project.project_id
  region     = var.region

  depends_on = [module.project]
}

module "workstations" {
  source = "./modules/workstations"

  project_id    = module.project.project_id
  region        = var.region
  network_id    = module.network.network_id
  subnetwork_id = module.network.subnetwork_id
  
  workstation_users = var.workstation_users

  depends_on = [module.project]
}
