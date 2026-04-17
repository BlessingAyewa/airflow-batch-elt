.PHONY: help infra-up infra-down deploy upload-data local-up local-down test

help:
	@echo "Available commands:"
	@echo "  make infra-up       Provision GCP infrastructure with Terraform"
	@echo "  make infra-down     Destroy all GCP infrastructure"
	@echo "  make deploy         Trigger CI/CD pipeline (push to main)"
	@echo "  make upload-data    Upload sample orders CSV to GCS for today's date"
	@echo "  make local-up       Start Airflow locally with Docker Compose"
	@echo "  make local-down     Stop local Airflow"
	@echo "  make test           Run pytest"
	@echo "  make get-url        Get the Airflow webserver external IP"

infra-up:
	cd terraform && terraform apply

infra-down:
	cd terraform && terraform destroy

deploy:
	git push origin main

upload-data:
	gsutil cp include/sample_data/orders.csv \
		gs://$(shell grep GCS_BUCKET .env | cut -d '=' -f2)/raw/orders/$(shell date +%Y-%m-%d)/orders.csv

local-up:
	docker compose up -d

local-down:
	docker compose down

test:
	pip install uv && uv export --no-hashes > /tmp/requirements.txt && pip install -r /tmp/requirements.txt
	pytest tests/ -v

get-url:
	kubectl get svc -n airflow airflow-webserver --output jsonpath='{.status.loadBalancer.ingress[0].ip}'
	@echo ""
	@echo "Open: http://$(shell kubectl get svc -n airflow airflow-webserver --output jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080"