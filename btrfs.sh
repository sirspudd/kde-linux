#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# SPDX-FileCopyrightText: 2023 Harald Sitter <sitter@kde.org>

# Executed inside an image to reshuffle the subvolumes.

set -ex

NAME=$1
VERSION=$2
ID=$3

[ "$NAME" = "" ] && exit 1;
[ "$VERSION" = "" ] && exit 1;
[ "$ID" = "" ] && exit 1;

btrfs subvolume create "@$ID.import"
rsync --archive --update --remove-source-files "@$NAME/" "@$ID.import/"
btrfs subvolume snapshot -r "@$ID.import/" "@$ID"
btrfs subvolume delete "@$ID.import/"
rm -rf "@$NAME"
ln -sv "@$ID" "@$NAME"
btrfs subvolume create @home
btrfs subvolume create @var-overlay
btrfs subvolume create @etc-overlay
mkdir @var-overlay/upper @var-overlay/work @etc-overlay/upper @etc-overlay/work
btrfs subvolume set-default "@$NAME"
