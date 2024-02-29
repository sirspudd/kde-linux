#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# SPDX-FileCopyrightText: 2024 Harald Sitter <sitter@kde.org>

# Build inside docker

set -ex

docker run \
  --privileged \
  --env CI_PROJECT_DIR=/workspace \
  --volume "$(pwd):/workspace" \
  --volume "$(pwd)/pacman-cache:/var/cache/pacman/pkg" \
  --volume "/dev:/dev" \
  --workdir /workspace \
  --rm=true \
  archlinux:latest \
  /workspace/in_docker.sh "$@"
