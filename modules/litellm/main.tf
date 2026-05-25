locals {
  litellm_config = <<EOF
model_list:
  - model_name: claude-3-5-sonnet
    litellm_params:
      model: vertex_ai/claude-3-5-sonnet@20240620
      vertex_ai_project: "os.environ/ANTHROPIC_VERTEX_PROJECT_ID"
      vertex_ai_location: "os.environ/CLOUD_ML_REGION"
  - model_name: claude-3-5-haiku
    litellm_params:
      model: vertex_ai/claude-3-5-haiku@20241022
      vertex_ai_project: "os.environ/ANTHROPIC_VERTEX_PROJECT_ID"
      vertex_ai_location: "os.environ/CLOUD_ML_REGION"
  - model_name: claude-3-opus
    litellm_params:
      model: vertex_ai/claude-3-opus@20240229
      vertex_ai_project: "os.environ/ANTHROPIC_VERTEX_PROJECT_ID"
      vertex_ai_location: "os.environ/CLOUD_ML_REGION"
  - model_name: gemini-1.5-pro
    litellm_params:
      model: vertex_ai/gemini-1.5-pro
      vertex_ai_project: "os.environ/ANTHROPIC_VERTEX_PROJECT_ID"
      vertex_ai_location: "os.environ/CLOUD_ML_REGION"
  - model_name: gemini-1.5-flash
    litellm_params:
      model: vertex_ai/gemini-1.5-flash
      vertex_ai_project: "os.environ/ANTHROPIC_VERTEX_PROJECT_ID"
      vertex_ai_location: "os.environ/CLOUD_ML_REGION"
EOF
}

# Dedicated Service Account for the Cloud Run instance
resource "google_service_account" "litellm_sa" {
  project      = var.project_id
  account_id   = "litellm-sa"
  display_name = "LiteLLM Proxy Service Account"
}

# Grant Vertex AI User to allow LiteLLM proxy to call Vertex models
resource "google_project_iam_member" "litellm_vertex_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.litellm_sa.email}"
}

# Secret Manager secret to store the LiteLLM config
resource "google_secret_manager_secret" "litellm_config" {
  project   = var.project_id
  secret_id = "litellm-config"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "litellm_config_version" {
  secret      = google_secret_manager_secret.litellm_config.id
  secret_data = local.litellm_config
}

# Secret Manager secret to store the Master API Key
resource "google_secret_manager_secret" "litellm_master_key" {
  project   = var.project_id
  secret_id = "litellm-master-key"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "litellm_master_key_version" {
  secret      = google_secret_manager_secret.litellm_master_key.id
  secret_data = var.master_key
}

# Authorize the service account to access the secrets
resource "google_secret_manager_secret_iam_member" "config_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.litellm_config.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.litellm_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "master_key_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.litellm_master_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.litellm_sa.email}"
}

# Deploy LiteLLM to Cloud Run
resource "google_cloud_run_v2_service" "litellm" {
  project  = var.project_id
  name     = "litellm-proxy"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.litellm_sa.email

    containers {
      image = "docker.litellm.ai/berriai/litellm:main-stable"
      args  = ["--config", "/app/config/config.yaml", "--port", "4000", "--host", "0.0.0.0"]

      ports {
        container_port = 4000
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "2Gi"
        }
      }

      # Injected parameters to map backends
      env {
        name  = "ANTHROPIC_VERTEX_PROJECT_ID"
        value = var.project_id
      }

      env {
        name  = "CLOUD_ML_REGION"
        value = var.region
      }

      # Retrieve Master Key at runtime
      env {
        name = "LITELLM_MASTER_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.litellm_master_key.secret_id
            version = "latest"
          }
        }
      }

      volume_mounts {
        name       = "config-volume"
        mount_path = "/app/config"
      }
    }

    volumes {
      name = "config-volume"
      secret {
        secret = google_secret_manager_secret.litellm_config.secret_id
        items {
          version = "latest"
          path    = "config.yaml"
        }
      }
    }
  }

  depends_on = [
    google_secret_manager_secret_version.litellm_config_version,
    google_secret_manager_secret_version.litellm_master_key_version,
    google_secret_manager_secret_iam_member.config_accessor,
    google_secret_manager_secret_iam_member.master_key_accessor,
    google_project_iam_member.litellm_vertex_user
  ]
}

# Grant public invoker permissions to secure endpoint at application-level with Master API Key
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.litellm.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
