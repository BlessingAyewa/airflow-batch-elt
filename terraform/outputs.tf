output "bucket_name" {
  description = "GCS bucket name for raw data and Airflow logs"
  value       = google_storage_bucket.airflow_data.name
}

output "raw_dataset_id" {
  description = "BigQuery raw dataset ID"
  value       = google_bigquery_dataset.raw.dataset_id
}

output "staging_dataset_id" {
  description = "BigQuery staging dataset ID"
  value       = google_bigquery_dataset.staging.dataset_id
}

output "marts_dataset_id" {
  description = "BigQuery marts dataset ID"
  value       = google_bigquery_dataset.marts.dataset_id
}

output "service_account_email" {
  description = "Airflow service account email — use this in Airflow GCP connection"
  value       = google_service_account.airflow_sa.email
}

output "service_account_key_path" {
  description = "Path to the service account key file on your local machine"
  value       = "keys/gcp-sa.json"
}

output "fernet_key_secret_id" {
  description = "Secret Manager secret ID for the Airflow Fernet key"
  value       = google_secret_manager_secret.fernet_key.secret_id
}
