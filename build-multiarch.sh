#! /bin/bash

# Builds a multiarch image and pushes it to the Docker registry
# Setup:
# - follow https://mirailabs.io/blog/multiarch-docker-with-buildx/
# - run "docker login --username alcol"

export DOCKER_CLI_EXPERIMENTAL=enabled
docker buildx build -t alcol/tiny-godaddy-ddns:1.0.1 \
    --platform=linux/amd64,linux/arm/v6,linux/arm/v7,linux/arm64,linux/386,linux/ppc64le,linux/s390x . --push
