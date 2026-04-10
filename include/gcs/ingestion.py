"""
GCS ingestion business logic.
All functions called by the gcs_ingestion_dag.
"""
from __future__ import annotations

import logging

log = logging.getLogger(__name__)

def check_gcs_file() -> None:
    """Check that the expected file exists in the GCS bucket."""
    log.info("Checking for files in GCS bucket...")

def load_to_bigquery() -> None:
    """Load the validated file from GCS into BigQuery."""
    log.info("Loading data into BigQuery...")