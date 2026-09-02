.PHONY: setup aws-config

setup: aws-config
	uv sync
	source .venv/bin/activate
