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
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
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
  region             = var.region
}

module "network" {
  source = "./modules/network"

  project_id = module.project.project_id
  region     = var.region

  depends_on = [module.project]
}

resource "null_resource" "build_custom_image" {
  triggers = {
    dockerfile = filemd5("${path.module}/workstation-image/Dockerfile")
  }

  provisioner "local-exec" {
    command = "gcloud builds submit ${path.module}/workstation-image --project=${module.project.project_id} --tag=${module.project.artifact_registry_url}/custom-workstation:latest"
  }

  depends_on = [module.project]
}

module "litellm" {
  source = "./modules/litellm"

  project_id = module.project.project_id
  region     = var.region
  master_key = var.litellm_master_key

  depends_on = [module.project]
}

module "workstations" {
  source = "./modules/workstations"

  project_id    = module.project.project_id
  region        = var.region
  network_id    = module.network.network_id
  subnetwork_id = module.network.subnetwork_id
  
  workstation_users     = var.workstation_users
  image_url             = "${module.project.artifact_registry_url}/custom-workstation:latest"
  service_account_email = module.project.workstations_service_account_email

  litellm_url        = module.litellm.litellm_url
  litellm_master_key = module.litellm.master_key

  idle_timeout    = var.workstation_idle_timeout
  running_timeout = var.workstation_running_timeout

  depends_on = [module.project, null_resource.build_custom_image, module.litellm]
}
