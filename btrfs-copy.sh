#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# SPDX-FileCopyrightText: 2023 Harald Sitter <sitter@kde.org>

# Executed inside an image to populate the subvolume via plain old copy

set -ex

OUTPUT_ABS=$1
OUTPUT=$2

[ "$OUTPUT_ABS" = "" ] && exit 1
[ "$OUTPUT" = "" ] && exit 1

cleanup() {
    [ -d @import ] && btrfs subvolume delete @import
    return 0
}
trap cleanup INT TERM EXIT
cleanup

mount -o remount,compress-force=zstd "$PWD"
btrfs property set . compression zstd
btrfs balance start --force -mconvert=single -dconvert=single .

btrfs subvolume create @import
cp -ra "$OUTPUT_ABS/." @import/
btrfs subvolume snapshot -r @import "@$OUTPUT"
btrfs subvolume delete @import

ln -svf "@$OUTPUT" "$ID"
btrfs subvolume set-default "$ID"
