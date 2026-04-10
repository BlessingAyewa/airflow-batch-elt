FROM apache/airflow:2.9.1-python3.11
USER root

RUN apt-get update && apt-get install -y build-essential git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER airflow

COPY pyproject.toml uv.lock ./

RUN pip install --no-cache-dir "uv==0.8.13" \
    && uv sync --frozen --no-dev

ENV AIRFLOW__CORE__LOAD_EXAMPLES=False
ENV AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION=True
ENV PYTHONPATH="/opt/airflow"

COPY dags/ /opt/airflow/dags/
COPY plugins/ /opt/airflow/plugins/
COPY include/ /opt/airflow/include/

WORKDIR /opt/airflow

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD airflow jobs check --job-type SchedulerJob --hostname "$${HOSTNAME}"
