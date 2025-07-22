#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# SPDX-FileCopyrightText: 2024 Harald Sitter <sitter@kde.org>
# SPDX-FileCopyrightText: 2024 Bruno Pajdek <brupaj@proton.me>

set -eux

SYSROOT=${SYSROOT:-/}

# Ensure the packages repo and the base image do not go out of sync
# by using the same snapshot date from build_date.txt for both
BUILD_DATE=$(curl --fail --silent https://cdn.kde.org/kde-linux/packaging/build_date.txt)
if [ -z "$BUILD_DATE" ]; then
  echo "ERROR: Could not fetch build_date.txt — refusing to build out-of-sync image." >&2
  exit 1
fi

echo "Server = https://archive.archlinux.org/repos/${BUILD_DATE}/\$repo/os/\$arch" > $SYSROOT/etc/pacman.d/mirrorlist
