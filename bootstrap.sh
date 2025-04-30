#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# SPDX-FileCopyrightText: 2024 Harald Sitter <sitter@kde.org>
# SPDX-FileCopyrightText: 2024 Bruno Pajdek <brupaj@proton.me>

# Bootstraps an Arch Linux Docker container to be ready for building KDE Linux.

# Exit immediately if any command fails and print all commands before they are executed.
set -ex

# From https://hub.docker.com/_/archlinux/:
#
# "For Security Reasons, these images strip the pacman lsign key.
# This is because the same key would be spread to all containers of the same image,
# allowing for malicious actors to inject packages (via, for example, a man-in-the-middle).
# In order to create a lsign-key run pacman-key --init on the first execution,
# but be careful to not redistribute that key."
#
pacman-key --init

# Restore the pacman.conf file from the pacman package. The docker one is crippled with NoExtract options and the like :(
mkdir /tmp/pacman
pacman --sync --refresh --downloadonly --noconfirm pacman
tar --extract --file "$(find /var/cache/pacman/pkg -name 'pacman-*.pkg.tar.zst')" --directory /tmp/pacman
cp /tmp/pacman/etc/pacman.conf /etc/pacman.conf

cat <<- EOF >> /etc/pacman.conf
[kde-linux]
# Signature checking is not needed because the packages are served over HTTPS and we have no mirrors
SigLevel = Never
Server = https://cdn.kde.org/kde-linux/packaging/packages/

[kde-linux-debug]
SigLevel = Never
Server = https://cdn.kde.org/kde-linux/packaging/packages-debug/
EOF

cp /etc/pacman.conf mkosi.sandbox/etc

# Ensure the packages repo and the base image do not go out of sync
# by using the same snapshot date from build_date.txt for both
BUILD_DATE=$(curl --fail --silent https://cdn.kde.org/kde-linux/packaging/build_date.txt)
if [ -z "$BUILD_DATE" ]; then
  echo "ERROR: Could not fetch build_date.txt — refusing to build out-of-sync image." >&2
    exit 1
fi

mkdir -p mkosi.sandbox/etc/pacman.d
echo "Server = https://archive.archlinux.org/repos/${BUILD_DATE}/\$repo/os/\$arch" > mkosi.sandbox/etc/pacman.d/mirrorlist

# Copy same mirrorlist into the system so pacman operates in sync
cp mkosi.sandbox/etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist

# ParallelDownloads is enabled by default since pacman 7.0.0.r6.gc685ae6-2,
# so no need to uncomment or manually set it unless we want to change the value.

# Update the system and install packages we'll need for building KDE Linux.
# Even though we use mkosi from Git, we'll grab the package,
# to make sure all the dependencies are properly pulled.
pacman --sync --refresh --noconfirm --sysupgrade \
    mkosi \
    arch-install-scripts \
    base-devel \
    btrfs-progs \
    clang \
    compsize \
    cpio \
    dosfstools \
    duperemove \
    erofs-utils \
    flatpak \
    git \
    go \
    openssh \
    qemu-base \
    qemu-img \
    rsync \
    ruby \
    ruby-nokogiri \
    rust \
    squashfs-tools \
    transmission-cli \
    tree \
    ukify

# Use mkosi from Git so we don't have to wait for releases when things break.
# OTOH, things may break in Git. Therefore, which version is used may change over time.
git clone https://github.com/systemd/mkosi.git /tmp/mkosi
ln --symbolic /tmp/mkosi/bin/mkosi /usr/local/bin/mkosi
