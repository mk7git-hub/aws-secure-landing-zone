ENV ?= dev
.PHONY: fmt validate lint scan check plan

fmt:
	terraform fmt -recursive

validate:
	cd envs/$(ENV) && terraform init -backend=false -input=false >/dev/null && terraform validate
	cd bootstrap && terraform init -backend=false -input=false >/dev/null && terraform validate

lint:
	tflint --init && tflint --recursive

scan:
	checkov -d . --config-file .checkov.yaml

check: fmt validate lint scan

plan:
	cd envs/$(ENV) && terraform plan
