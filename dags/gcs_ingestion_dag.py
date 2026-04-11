"""
GCS Ingestion DAG
=================
Ingests raw data files from GCS into BigQuery.

Schedule    : Daily at 06:00 UTC
Owner       : data-engineering
Tags        : ingestion, gcs, bigquery
"""

from __future__ import annotations

import logging
import json
from datetime import datetime, timedelta

from airflow import DAG
from airflow.models import Variable
from airflow.operators.empty import EmptyOperator
from airflow.providers.google.cloud.sensors.gcs import GCSObjectExistenceSensor
from airflow.providers.google.cloud.transfers.gcs_to_bigquery import GCSToBigQueryOperator
from airflow.operators.python import PythonOperator
from airflow.utils.task_group import TaskGroup

from include.gcs.ingestion import validate_orders

log = logging.getLogger(__name__)

with open("include/gcs/schemas/orders.json") as f:
    ORDERS_SCHEMA = json.load(f)

def on_failure_callback(context: dict) -> None:
    """Called automatically by Airflow when any task fails."""
    dag_id = context["dag"].dag_id
    task_id = context["task_instance"].task_id
    execution_date = context["execution_date"]
    log.error(
        "Task failed | DAG: %s | Task: %s | Execution: %s",
        dag_id,
        task_id,
        execution_date
    )

def on_sla_miss_callback(dag, task_list, blocking_task_list, slas, blocking_tis) -> None:
    """Called automatically by Airflow when the DAG misses its SLA."""
    log.warning(
        "SLA missed | DAG: %s | Blocking tasks: %s", 
        dag.dag_id,
        [ti.task_id for ti in blocking_tis]
    )

default_args = {
    "owner": "data-engineering",
    "depends_on_past": False,
    "retries": 3,
    "retry_delay": timedelta(minutes=5),
    "retry_exponential_backoff": True,
    "execution_timeout": timedelta(hours=1),
    "on_failure_callback": on_failure_callback,
    "email_on_failure": False,
    "email_on_retry": False
}

with DAG(
    dag_id="gcs_ingestion_dag",
    description="Ingest raw files from GCS into BigQuery",
    schedule="0 6 * * *",
    start_date=datetime(2025, 1, 1),
    catchup=False,
    default_args=default_args,
    sla_miss_callback=on_sla_miss_callback,
    tags=["ingestion", "gcs", "bigquery"],
    doc_md=__doc__
) as dag:
    
    GCP_PROJECT     = Variable.get("gcp_project_id", default_var="my-gcp-project")
    GCS_BUCKET      = Variable.get("gcs_bucket", default_var="my-gcs-bucket")
    GCS_PREFIX      = Variable.get("gcs_prefix", default_var="raw/orders")
    GCS_FILENAME    = Variable.get("gcs_filename", default_var="orders.csv")
    BQ_DATASET      = Variable.get("bq_dataset", default_var="raw")
    BQ_TABLE        = Variable.get("bq_table", default_var="orders")

    start = EmptyOperator(task_id="start")
    end = EmptyOperator(task_id="end")

    with TaskGroup("ingest") as ingest_group:

        sense_file = GCSObjectExistenceSensor(
            task_id="sense_gcs_file",
            bucket=GCS_BUCKET,
            object=f"{GCS_PREFIX}/{GCS_FILENAME}",
            google_cloud_conn_id="google_cloud_default",
            deferrable=True
        )

        validate = PythonOperator(
            task_id="validate_orders",
            python_callable=validate_orders,
            op_kwargs={
                "gcs_bucket": GCS_BUCKET,
                "gcs_object": f"{GCS_PREFIX}/{GCS_FILENAME}"
            }
        )

        load_bq = GCSToBigQueryOperator(
            task_id="load_to_bigquery",
            bucket=GCS_BUCKET,
            source_objects=[f"{GCS_PREFIX}/{GCS_FILENAME}"],
            destination_project_dataset_table=f"{GCP_PROJECT}.{BQ_DATASET}.{BQ_TABLE}",
            source_format="CSV",
            skip_leading_rows=1,
            write_disposition="WRITE_TRUNCATE",
            gcp_conn_id="google_cloud_default",
            schema_fields=ORDERS_SCHEMA,
            autodetect=False           
        )

        sense_file >> validate >> load_bq
    
    start >> ingest_group >> end
