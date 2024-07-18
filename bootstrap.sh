#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# SPDX-FileCopyrightText: 2024 Harald Sitter <sitter@kde.org>

# For bootstrapping of a basic arch system so it can build stuff.

set -ex

echo 'https://mirror.23m.com/archlinux/' > /etc/pacman.d/mirrorlist.new
cat /etc/pacman.d/mirrorlist >> /etc/pacman.d/mirrorlist.new
mv /etc/pacman.d/mirrorlist.new /etc/pacman.d/mirrorlist

pacman --sync --refresh --noconfirm archlinux-keyring
pacman-key --init
# Unclear if we need this, should the keys run out of date we probably need to run this manually. Add a comment if that
# is the case for it being here.
# pacman-key --refresh-keys
pacman --sync --refresh --noconfirm --sysupgrade
pacman --sync --refresh --noconfirm mkosi git base-devel ukify vim cpio tree \
    rsync btrfs-progs s3cmd dosfstools qemu-img erofs-utils squashfs-tools

# Use mkosi from git to not have to wait for releases when things break.
# OTOH things may break in git. So which version is used may change over time.
git clone https://github.com/systemd/mkosi
ln -s "$PWD/mkosi/bin/mkosi" /usr/local/bin/mkosi
