#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# SPDX-FileCopyrightText: 2024 Harald Sitter <sitter@kde.org>
# SPDX-FileCopyrightText: 2024 Bruno Pajdek <brupaj@proton.me>

# Builds KDE Linux inside of an Arch Linux Docker container.

# Exit immediately if any command fails.
set -e

# Exit if Docker is not available.
if ! command -v docker 2>&1 > /dev/null; then
  echo "Docker not available on the system! Make sure it is installed."
  exit 1
fi


# Print some configuration instructions if we're not running Docker on btrfs, then exit.
if ! docker info | grep --quiet "Storage Driver: btrfs"; then
  echo "You should run this on a btrfs'd Docker instance."
  echo "Other Docker storage drivers will not work at all!"
  echo
  echo "If your host system is already running on btrfs,"
  echo "add the following to /etc/docker/daemon.json:"
  echo
  echo "{"
  echo "  \"storage-driver\": \"btrfs\""
  echo "}"
  echo
  echo "And run:"
  echo
  echo "# systemctl restart docker.socket docker.service"
  echo
  echo "If not, create a btrfs filesystem inside of a file and mount it so Docker can use it:"
  echo
  echo "# fallocate -l 64G /docker.btrfs"
  echo "# mkfs.btrfs /docker.btrfs"
  echo "# mkdir -p /var/lib/docker"
  echo "# mount /docker.btrfs /var/lib/docker"
  echo
  echo "Then edit /etc/docker/daemon.json as described above, restart Docker and re-run this script."
  exit 1
fi

# Print all commands before they are executed.
# We only do this now not to clutter the printed configuration instructions above.
set -x

# Make sure we have the latest available Arch Linux Docker image.
docker pull archlinux:latest

# Store the absolute path the script is located in to $SCRIPT_DIR.
SCRIPT_DIR="$(readlink --canonicalize "$(dirname "$0")")"

# Spin up a new Arch Linux Docker container and run the in_docker.sh script inside of it,
# passing any command line arguments to it and mounting $SCRIPT_DIR to /workspace.
docker run \
  --privileged \
  --volume="${SCRIPT_DIR}:/workspace" \
  --volume="${SCRIPT_DIR}/kde-linux.cache/pacman:/var/cache/pacman/pkg" \
  --volume="/dev:/dev" \
  --workdir="/workspace" \
  --rm \
  archlinux:latest \
  /workspace/in_docker.sh "$@"
