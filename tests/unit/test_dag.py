"""Basic DAG integrity tests."""
import pytest
from airflow.models import DagBag


def test_dag_loads_without_errors():
    dagbag = DagBag(dag_folder="dags/", include_examples=False)
    assert "gcs_ingestion_dag" in dagbag.dags
    assert len(dagbag.import_errors) == 0


def test_dag_has_expected_tasks():
    dagbag = DagBag(dag_folder="dags/", include_examples=False)
    dag = dagbag.dags["gcs_ingestion_dag"]
    task_ids = [task.task_id for task in dag.tasks]
    assert "start" in task_ids
    assert "end" in task_ids