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

# Update the system and install packages we'll need for building KDE Linux.
# Even though we use mkosi from Git, we'll grab the package,
# to make sure all the dependencies are properly pulled.
pacman --sync --refresh --noconfirm --sysupgrade \
    mkosi \
    base-devel \
    btrfs-progs \
    compsize \
    cpio \
    dosfstools \
    duperemove \
    erofs-utils \
    git \
    go \
    openssh \
    qemu-img \
    rsync \
    ruby \
    ruby-nokogiri \
    squashfs-tools \
    transmission-cli \
    tree \
    ukify

# Use mkosi from Git so we don't have to wait for releases when things break.
# OTOH, things may break in Git. Therefore, which version is used may change over time.
git clone https://github.com/systemd/mkosi.git /tmp/mkosi
ln --symbolic /tmp/mkosi/bin/mkosi /usr/local/bin/mkosi
