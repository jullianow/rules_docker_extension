#!/bin/bash -e

# Resolve the docker tool path
DOCKER="%{docker_tool_path}"
DOCKER_FLAGS="%{docker_flags}"

if [[ -z "$DOCKER" ]]; then
    echo >&2 "error: docker not found; do you need to manually configure the docker toolchain?"
    exit 1
fi

image_id=$(%{image_id})

# Load the image and remember its name

$DOCKER $DOCKER_FLAGS load -i %{image_tar}

$DOCKER $DOCKER_FLAGS run -it %{docker_run_flags} $image_id
