.PHONY: test

export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
ELIXIR_VERSION?=1.14

ifeq ($(CI),)
	DOCKER_COMPOSE_OPTS=-f docker-compose.yml -f docker-compose.dev.yml
	export BUILDKIT_INLINE_CACHE=0
else
	DOCKER_COMPOSE_OPTS=-f docker-compose.yml
	export BUILDKIT_INLINE_CACHE=1
endif

console: build
console:
	docker compose $(DOCKER_COMPOSE_OPTS) run app $(CMD)

test: build
test: MIX_TEST_PARTITION=1
test: MIX_TEST_PARTITIONS=1
test:
	docker compose $(DOCKER_COMPOSE_OPTS) run -e MIX_TEST_PARTITION=$(MIX_TEST_PARTITION) app mix test --partitions $(MIX_TEST_PARTITIONS)

build:
	docker compose $(DOCKER_COMPOSE_OPTS) build --build-arg ELIXIR_VERSION=$(ELIXIR_VERSION) app

format.check:
	$(MAKE) console CMD="mix format --check-formatted"
