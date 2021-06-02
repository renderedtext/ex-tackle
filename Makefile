.PHONY: test

USER=root
MIX_ENV=dev
HOME_DIR=/home/
WORKDIR=$(HOME_DIR)/ex-tackle

# True if rabbitmq used for testing is running inside docker container.
# Some tests are using rabbitmqctl tool, so it is important to know whether to
# use it localy via system call or inside a docker container.
DOCKER_RABBITMQ=false
DOCKER_RABBITMQ_CONTAINER_NAME=rabbitmq

# base elixir image extended with docker
ELIXIR_IMAGE=registry.semaphoreci.com/elixir
ELIXIR_VERSION ?= 1.6

INTERACTIVE_SESSION=\
          -v $$PWD/home_dir:$(HOME_DIR) \
          -v $$PWD/:$(WORKDIR) \
					-v /var/run/docker.sock:/var/run/docker.sock \
				  --rm \
          -e HOME=$(HOME_DIR) \
					-e MIX_ENV=$(MIX_ENV)\
					-e DOCKER_RABBITMQ=$(DOCKER_RABBITMQ)\
					-e DOCKER_RABBITMQ_CONTAINER_NAME=$(DOCKER_RABBITMQ_CONTAINER_NAME)\
          --workdir=$(WORKDIR) \
          --user=$(USER) \
          -it $(ELIXIR_IMAGE):$(ELIXIR_VERSION)

CMD?=/bin/bash

# For development without docker

local.test:
	mix test --trace

rabbit.reset:
	sudo rabbitmqctl stop_app
	sudo rabbitmqctl reset    # Be sure you really want to do this!
	sudo rabbitmqctl start_app

# Targets for docker based development

console:
	docker run --network=host $(INTERACTIVE_SESSION) $(CMD)

test:
	{ \
		string="1.10 \
	$ELIXIR_VERSION"; \
	if [ "$string" == "$(sort --version-sort <<< "$string")" ]; then \
	$(MAKE) console DOCKER_RABBITMQ=true DOCKER_RABBITMQ_CONTAINER_NAME=$(DOCKER_RABBITMQ_CONTAINER_NAME) MIX_ENV=test CMD="mix do compile --warnings-as-errors, test --trace $(FILE)"; \
	else \
	$(MAKE) console DOCKER_RABBITMQ=true DOCKER_RABBITMQ_CONTAINER_NAME=$(DOCKER_RABBITMQ_CONTAINER_NAME) MIX_ENV=test CMD="mix do compile --warnings-as-errors, test --warnings-as-errors --trace $(FILE)"; \
	fi; \
	}

format.check:
	$(MAKE) console CMD="mix format --check-formatted"

rabbitmq.run:
	docker run -d --rm --name $(DOCKER_RABBITMQ_CONTAINER_NAME) --network=host --memory 512m rabbitmq:3.7

rabbitmq.reset:
	docker kill rabbitmq
	$(MAKE) rabbitmq.run
