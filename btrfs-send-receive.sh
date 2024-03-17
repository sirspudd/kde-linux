#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# SPDX-FileCopyrightText: 2023 Harald Sitter <sitter@kde.org>

# Executed inside an image to populate the subvolume via btrfs snapshot magic

set -ex

OUTPUT_ABS=$1
OUTPUT=$2
ID=$3

[ "$OUTPUT_ABS" = "" ] && exit 1
[ "$OUTPUT" = "" ] && exit 1
[ "$ID" = "" ] && exit 1

EXPORT="$OUTPUT.export"

cleanup() {
    [ -d "$EXPORT" ] && btrfs subvolume delete "$EXPORT"
    return 0
}
trap cleanup INT TERM EXIT
cleanup

mount -o remount,compress-force=zstd "$PWD"
btrfs property set . compression zstd
btrfs balance start --force -mconvert=single -dconvert=single .

btrfs receive -f "$OUTPUT_ABS.btrfs" .
btrfs subvolume snapshot -r "$EXPORT" "@$OUTPUT"
btrfs subvolume delete "$EXPORT"
rm -f "$OUTPUT_ABS.btrfs"

ln -svf "@$OUTPUT" "$ID"
