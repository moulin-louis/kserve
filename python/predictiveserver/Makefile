.PHONY: dev_install test type_check clean

dev_install:
	uv sync --group test

test: type_check
	pytest -W ignore

type_check:
	mypy --ignore-missing-imports predictiveserver

clean:
	rm -rf __pycache__
	rm -rf .pytest_cache
	rm -rf .mypy_cache
	rm -rf *.egg-info
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
