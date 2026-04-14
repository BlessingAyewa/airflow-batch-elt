resource "google_storage_bucket" "airflow_data" {
  name                        = var.bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_bigquery_dataset" "raw" {
  dataset_id                 = "raw"
  location                   = var.bq_location
  description                = "Raw data loaded by Airflow — do not query directly"
  delete_contents_on_destroy = true
}

resource "google_bigquery_dataset" "staging" {
  dataset_id                 = "staging"
  location                   = var.bq_location
  description                = "Staging views built by dbt — cleaned raw data"
  delete_contents_on_destroy = true
}

resource "google_bigquery_dataset" "marts" {
  dataset_id                 = "marts"
  location                   = var.bq_location
  description                = "Analytics tables built by dbt — source of truth for dashboards"
  delete_contents_on_destroy = true
}

resource "google_service_account" "airflow_sa" {
  account_id   = "airflow-sa"
  display_name = "Airflow Service Account"
  description  = "Used by Airflow to access GCS, BigQuery and Secret Manager"
}

resource "google_project_iam_member" "airflow_bq_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.airflow_sa.email}"
}

resource "google_project_iam_member" "airflow_bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.airflow_sa.email}"
}

resource "google_project_iam_member" "airflow_storage_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.airflow_sa.email}"
}

resource "google_project_iam_member" "airflow_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.airflow_sa.email}"
}

resource "google_project_iam_member" "airflow_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.airflow_sa.email}"
}

resource "google_project_iam_member" "airflow_gke_developer" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.airflow_sa.email}"
}

resource "google_secret_manager_secret" "fernet_key" {
  secret_id = "airflow-fernet-key"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "fernet_key_value" {
  secret      = google_secret_manager_secret.fernet_key.id
  secret_data = var.airflow_fernet_key
}

resource "google_secret_manager_secret" "secret_key" {
  secret_id = "airflow-secret-key"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "secret_key_value" {
  secret      = google_secret_manager_secret.secret_key.id
  secret_data = var.airflow_secret_key
}

resource "google_service_account_key" "airflow_sa_key" {
  service_account_id = google_service_account.airflow_sa.name
}

resource "local_file" "airflow_sa_key_file" {
  content         = base64decode(google_service_account_key.airflow_sa_key.private_key)
  filename        = "${path.module}/../keys/gcp-sa.json"
  file_permission = "0600"
}

# ── Artifact Registry ──────────────────────────────────────────────────────────

resource "google_project_service" "artifact_registry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "airflow" {
  repository_id = "airflow"
  format        = "DOCKER"
  location      = var.region
  description   = "Docker images for Airflow"
  depends_on = [google_project_service.artifact_registry]
}

# ── GKE ────────────────────────────────────────────────────────────────────────

resource "google_project_service" "container" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_container_cluster" "airflow" {
  name                = var.gke_cluster_name
  location            = "${var.region}-b"
  deletion_protection = false

  remove_default_node_pool = true
  initial_node_count       = 1

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  depends_on = [google_project_service.container]
}

resource "google_container_node_pool" "airflow_nodes" {
  name       = "airflow-node-pool"
  cluster    = google_container_cluster.airflow.id
  node_count = var.gke_node_count

  node_config {
    machine_type = "e2-standard-4"

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.airflow_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[airflow/airflow]"
}