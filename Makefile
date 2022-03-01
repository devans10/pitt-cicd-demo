.PHONY: default install test

default: test

install: 
	pipenv install --dev --skip-lock

test: 
	PYTHONPATH=./ pytest --cov