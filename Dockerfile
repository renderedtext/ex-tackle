ARG ELIXIR_VERSION=latest
FROM elixir:${ELIXIR_VERSION}

RUN apt-get update && apt-get install -y docker.io
