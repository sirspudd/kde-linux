#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# SPDX-FileCopyrightText: 2024 Harald Sitter <sitter@kde.org>

# Build inside docker

set -ex

if ! docker info | grep 'Storage Driver: btrfs'; then
  echo "You should run this on a btrfs'd docker instance. \
        The btrfs can be a local file mounted into place at /var/lib/docker. \
        Other docker backends will perform poorly if at all!"
  exit 1
fi

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
