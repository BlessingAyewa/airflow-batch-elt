"""
GCS Ingestion DAG
=================
Ingests raw data files fromGCS into BigQuery.

Schedule    : Daily at 06:00 UTC
Owner       : data-engineering
Tags        : ingestion, gcs, bigquery
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta

from airflow import DAG
from airflow.models import Variable
from airflow.operators.empty import EmptyOperator
from airflow.operators.python import PythonOperator
from airflow.utils.task_group import TaskGroup

from include.gcs.ingestion import check_gcs_file, load_to_bigquery

log = logging.getLogger(__name__)

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
    
    start = EmptyOperator(task_id="start")
    end = EmptyOperator(task_id="end")

    with TaskGroup("ingest") as ingest_group:
        check_file = PythonOperator(
            task_id="check_gcs_file",
            python_callable=check_gcs_file
        )

        load_bq = PythonOperator(
            task_id="load_to_bigquery",
            python_callable=load_to_bigquery
        )

        check_file >> load_bq
    
    start >> ingest_group >> end
