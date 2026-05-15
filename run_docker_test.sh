#!/bin/bash
# Build and run a test container for dotfiles-ng deployment.
# Usage: ./run_docker_test.sh [debian|ubuntu|<custom-image>]
# Default: debian:latest. Pass "ubuntu" for ubuntu:latest, or any docker image
# reference (e.g. "ubuntu:22.04", "debian:bookworm") for something specific.

set -euo pipefail

distro_arg="${1:-debian}"
case "$distro_arg" in
    debian) image="debian:latest" ;;
    ubuntu) image="ubuntu:latest" ;;
    *:*)    image="$distro_arg" ;;
    *)      image="${distro_arg}:latest" ;;
esac

tag="dotfiles-ng-${distro_arg//[:\/]/-}"

echo "Building $tag from $image..."
docker build --build-arg "DISTRO_IMAGE=$image" -t "$tag" .

echo "Running $tag..."
docker run --hostname dotfiles-tester -it --rm "$tag"
