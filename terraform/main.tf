resource "google_storage_bucket" "airflow_data" {
  name                        = var.bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false

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
  dataset_id  = "raw"
  location    = var.bq_location
  description = "Raw data loaded by Airflow — do not query directly"
}

resource "google_bigquery_dataset" "staging" {
  dataset_id  = "staging"
  location    = var.bq_location
  description = "Staging views built by dbt — cleaned raw data"
}

resource "google_bigquery_dataset" "marts" {
  dataset_id  = "marts"
  location    = var.bq_location
  description = "Analytics tables built by dbt — source of truth for dashboards"
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
