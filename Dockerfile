ARG ELIXIR_VERSION
FROM elixir:${ELIXIR_VERSION}-alpine

RUN apk add --no-cache \
  inotify-tools bash make busybox-extras openssh-keygen openssh-client git

RUN mix local.hex --force --if-missing && \
  mix local.rebar --force --if-missing

WORKDIR /app

COPY mix.* .
COPY .formatter.exs ./
RUN mix deps.get

COPY config ./config
COPY lib ./lib
COPY test ./test
