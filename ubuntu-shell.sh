#!/usr/bin/env bash
set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to run this script." >&2
  exit 1
fi

image="local/ubuntu-shell:24.04-curl-ca"
workspace="$(pwd -P)"
container_workspace="/workspace/scripts"

if ! docker image inspect "$image" >/dev/null 2>&1; then
  docker build -f Dockerfile.ubuntu-shell -t "$image" .
fi

exec docker run --rm -it \
  -v "${workspace}:${container_workspace}" \
  -w "$container_workspace" \
  "$image"
