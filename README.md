# Google Cloud Workstations Terraform Environment

This repository contains Terraform modules to provision a fully managed Google Cloud Workstations environment. It is designed to be flexible, allowing you to either spin up a brand new Google Cloud Project from scratch or deploy the workstations into an existing project.

## Architecture

The infrastructure is broken down into three main modules:

1.  **`project`**: Conditionally creates a new GCP project and enables the required APIs (`workstations.googleapis.com`, `compute.googleapis.com`, etc.).
2.  **`network`**: Provisions a private VPC and Subnetwork with Private Google Access. It also configures a Cloud Router and Cloud NAT to provide secure outbound internet access without exposing the workstations via public IPs.
3.  **`workstations`**: Provisions the Workstation Cluster, Workstation Configuration (using `e2-standard-4` machines and Code-OSS base images), and dynamically provisions the individual Workstation instances and IAM bindings for your developers.

## Prerequisites

*   [Terraform](https://developer.hashicorp.com/terraform/downloads) (>= 1.0.0)
*   [Google Cloud CLI (`gcloud`)](https://cloud.google.com/sdk/docs/install)
*   Permissions to create projects/resources in your GCP Organization (if creating a new project).

## Getting Started

### 1. Authenticate

Ensure you are authenticated with Google Cloud:

```bash
gcloud auth application-default login
```

### 2. Configure Variables

Copy the example variables template to create your active configuration file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your specific values. 

**Important:**
*   To create a new project, set `create_project = true` and provide a `billing_account_id` and either an `org_id` or `folder_id`.
*   To use an existing project, set `create_project = false` and simply provide your existing `project_id`.
*   Update the `workstation_users` map with the usernames and Google account emails of your developers.

### 3. Deploy

Initialize the Terraform working directory:

```bash
terraform init
```

Preview the changes:

```bash
terraform plan
```

Apply the configuration:

```bash
terraform apply
```

## Running AI Assistants

Because the workstations are configured with secure outbound internet access via Cloud NAT and have sufficient compute resources, you can easily install and run AI assistants like Claude Code and Anti-gravity. 

Simply connect to your provisioned workstation and use the terminal to install them (e.g., `npm install -g @your-org/assistant`).
