dev_install:
	uv sync --group test

test: type_check
	pytest -W ignore

type_check:
	mypy --ignore-missing-imports aiffairness
