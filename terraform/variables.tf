variable "project_id" {
    description     = "GCP project ID"
    type            = string    
}

variable "region" {
    description     = "GCP region all resources"
    type            = string
    default         = "us-central1"
}

variable "bucket_name" {
  description = "GCS bucket name for raw data and Airflow logs"
  type        = string
}

variable "airflow_fernet_key" {
  description = "Fernet key for Airflow — encrypts connection passwords in the metadata DB"
  type        = string
  sensitive   = true
}

variable "airflow_secret_key" {
  description = "Secret key for Airflow — signs web UI session cookies"
  type        = string
  sensitive   = true
}

variable "bq_location" {
  description = "BigQuery dataset location — must match dbt profiles.yml"
  type        = string
  default     = "US"
}


variable "gke_cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "airflow-cluster"
}

variable "gke_node_count" {
  description = "Number of nodes in the GKE node pool"
  type        = number
  default     = 1
}
