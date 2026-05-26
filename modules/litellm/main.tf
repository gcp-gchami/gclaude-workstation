resource "random_password" "litellm_master_key" {
  count   = var.master_key == "" || var.master_key == "sk-litellm-master-key-1234" ? 1 : 0
  length  = 32
  special = false
}

locals {
  actual_master_key = var.master_key == "" || var.master_key == "sk-litellm-master-key-1234" ? random_password.litellm_master_key[0].result : var.master_key

  litellm_config = <<EOF
model_list:
  - model_name: claude-3-5-sonnet
    litellm_params:
      model: vertex_ai/claude-3-5-sonnet@20240620
      vertex_ai_project: "os.environ/ANTHROPIC_VERTEX_PROJECT_ID"
      vertex_ai_location: "os.environ/VERTEX_AI_LOCATION"
  - model_name: claude-3-5-haiku
    litellm_params:
      model: vertex_ai/claude-3-5-haiku@20241022
      vertex_ai_project: "os.environ/ANTHROPIC_VERTEX_PROJECT_ID"
      vertex_ai_location: "os.environ/VERTEX_AI_LOCATION"
  - model_name: claude-3-opus
    litellm_params:
      model: vertex_ai/claude-3-opus@20240229
      vertex_ai_project: "os.environ/ANTHROPIC_VERTEX_PROJECT_ID"
      vertex_ai_location: "os.environ/VERTEX_AI_LOCATION"
  - model_name: claude-opus-4-6
    litellm_params:
      model: vertex_ai/claude-opus-4-6
      vertex_ai_project: "os.environ/ANTHROPIC_VERTEX_PROJECT_ID"
      vertex_ai_location: "os.environ/VERTEX_AI_LOCATION"
  - model_name: claude-opus-4-7
    litellm_params:
      model: vertex_ai/claude-opus-4-7
      vertex_ai_project: "os.environ/ANTHROPIC_VERTEX_PROJECT_ID"
      vertex_ai_location: "os.environ/VERTEX_AI_LOCATION"
  - model_name: claude-sonnet-4-6
    litellm_params:
      model: vertex_ai/claude-sonnet-4-6
      vertex_ai_project: "os.environ/ANTHROPIC_VERTEX_PROJECT_ID"
      vertex_ai_location: "os.environ/VERTEX_AI_LOCATION"
  - model_name: gemini-1.5-pro
    litellm_params:
      model: vertex_ai/gemini-1.5-pro
      vertex_ai_project: "os.environ/ANTHROPIC_VERTEX_PROJECT_ID"
      vertex_ai_location: "os.environ/VERTEX_AI_LOCATION"
  - model_name: gemini-1.5-flash
    litellm_params:
      model: vertex_ai/gemini-1.5-flash
      vertex_ai_project: "os.environ/ANTHROPIC_VERTEX_PROJECT_ID"
      vertex_ai_location: "os.environ/VERTEX_AI_LOCATION"
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
  secret_data = local.actual_master_key
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

resource "random_password" "db_password" {
  length  = 16
  special = false
}

resource "google_sql_database_instance" "postgres" {
  project             = var.project_id
  name                = "litellm-postgres"
  database_version    = "POSTGRES_15"
  region              = var.region
  deletion_protection = false

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
    }
  }

  # Ensure Database is only created after VPC Peering Connection is fully established!
  depends_on = [var.private_vpc_connection_id]
}

resource "google_sql_database" "litellm_db" {
  project  = var.project_id
  name     = "litellm"
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_user" "litellm_user" {
  project  = var.project_id
  name     = "litellm"
  instance = google_sql_database_instance.postgres.name
  password = random_password.db_password.result
}

# Secret Manager secret for the Database URL connection string
resource "google_secret_manager_secret" "litellm_db_url" {
  project   = var.project_id
  secret_id = "litellm-db-url"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "litellm_db_url_version" {
  secret      = google_secret_manager_secret.litellm_db_url.id
  secret_data = "postgresql://${google_sql_user.litellm_user.name}:${random_password.db_password.result}@localhost/${google_sql_database.litellm_db.name}?host=/cloudsql/${google_sql_database_instance.postgres.connection_name}"
}

# Authorize service account to read the database URL secret
resource "google_secret_manager_secret_iam_member" "db_url_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.litellm_db_url.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.litellm_sa.email}"
}

# Grant Cloud SQL Client role to allow the service account to connect to private SQL instance
resource "google_project_iam_member" "litellm_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.litellm_sa.email}"
}

# Deploy LiteLLM to Cloud Run
resource "google_cloud_run_v2_service" "litellm" {
  project  = var.project_id
  name     = "litellm-proxy"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.litellm_sa.email

    # Direct VPC Egress routing all traffic through our custom subnet
    vpc_access {
      network_interfaces {
        network    = var.network_id
        subnetwork = var.subnetwork_id
      }
      egress = "ALL_TRAFFIC"
    }

    containers {
      image = "docker.io/litellm/litellm:main-stable"
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

      env {
        name  = "VERTEX_AI_LOCATION"
        value = var.vertex_ai_location
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

      # Retrieve Database URL at runtime
      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.litellm_db_url.secret_id
            version = "latest"
          }
        }
      }

      volume_mounts {
        name       = "config-volume"
        mount_path = "/app/config"
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
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

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.postgres.connection_name]
      }
    }
  }

  depends_on = [
    google_secret_manager_secret_version.litellm_config_version,
    google_secret_manager_secret_version.litellm_master_key_version,
    google_secret_manager_secret_version.litellm_db_url_version,
    google_secret_manager_secret_iam_member.config_accessor,
    google_secret_manager_secret_iam_member.master_key_accessor,
    google_secret_manager_secret_iam_member.db_url_accessor,
    google_project_iam_member.litellm_cloudsql_client,
    google_project_iam_member.litellm_vertex_user
  ]
}

# Grant invoker permissions to authorized users and workstation service account
resource "google_cloud_run_v2_service_iam_member" "invokers" {
  for_each = toset(var.authorized_invokers)

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.litellm.name
  role     = "roles/run.invoker"
  member   = each.value
}
