"""
GCS ingestion helpers.
Business logic called by operators in gcs_ingestion_dag.
"""
from __future__ import annotations

import logging
import tempfile
import great_expectations as gx
import pandas as pd
from google.cloud import storage

log = logging.getLogger(__name__)

def validate_orders(gcs_bucket: str, gcs_object: str) -> None:
    """
    Downloads the orders CSV from GCS and validates it
    against the orders_suite expectation suite.
    Raises an exception if validation fails.
    """
    client = storage.Client()
    bucket = client.bucket(gcs_bucket)
    blob = bucket.blob(gcs_object)

    with tempfile.NamedTemporaryFile(suffix=".csv", delete=True) as tmp:
        blob.download_to_filename(tmp.name)
        log.info("Downloaded gs://%s/%s to %s", gcs_bucket, gcs_object, tmp.name)

        df = pd.read_csv(tmp.name)
        log.info("Loaded %d rows from %s", len(df), gcs_object)

        # GX needs to write scaffold directories — copy config to a writable
        # temp dir since the image filesystem is read-only for the airflow user.
        import os, shutil, tempfile
        with tempfile.TemporaryDirectory() as tmp_gx_dir:
            shutil.copytree(
                "/opt/airflow/include/great_expectations",
                os.path.join(tmp_gx_dir, "great_expectations")
            )
            context = gx.get_context(
                mode="file",
                project_root_dir=os.path.join(tmp_gx_dir, "great_expectations")
            )
            batch = context.data_sources.pandas_default.read_dataframe(df)
            suite = context.suites.get("orders_suite")
            results = batch.validate(suite)

        if not results.success:
            failed = [
                r.expectation_config.type
                for r in results.results
                if not r.success
            ]

            log.error(
                "Validation failed for %s | Failed expectations: %s",
                gcs_object,
                failed,
            )

            raise ValueError(
                f"Data validation failed for {gcs_object}. "
                f"Failed expectations: {failed}"
            )
        
        log.info("Validation passed for %s", gcs_object)
