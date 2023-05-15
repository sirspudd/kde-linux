#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# SPDX-FileCopyrightText: 2023 Harald Sitter <sitter@kde.org>

# Build image using mkosi, well, somehwat. mkosi is actually a bit too inflexible for our purposes so we generate a OS
# tree using mkosi and then construct shipable raw images (for installation) and tarballs (for systemd-sysupdate)
# ourselves.

set -ex

NAME=systemdOS
VERSION=$(($(cat version)+1))
ID=${NAME}_$VERSION
EFI=$ID.efi
TAR=${ID}_root-x86-64.tar
IMG=$ID.raw

echo "$VERSION" > ./mkosi.extra/usr/lib/image_version

mkosi --distribution arch "$@"

rm -rv image/efi/EFI/Linux/
mkdir -p image/efi/EFI/Linux/
mv -v image/${NAME}*.efi "image/efi/EFI/Linux/$EFI"
mv -v image/live.efi .

rm -rf "$TAR" ./*.tar
tar -C image/ -cf "$TAR" .

rm -f "$IMG" ./*.raw
touch "$IMG"
# The root partition contains the shipable efi image.
systemd-repart --no-pager --empty=allow --size=auto --dry-run=no --root=image --definitions=mkosi.repart --defer-partitions=esp "$IMG"
systemd-dissect --with "$IMG" "$(pwd)/btrfs.sh" $NAME $VERSION $ID
# The esp of the image contains the live efi image (divergent cmdline).
cp -v live.efi "image/efi/EFI/Linux/$EFI"
systemd-repart --no-pager --empty=allow --size=auto --dry-run=no --root=image --definitions=mkosi.repart --defer-partitions=root "$IMG"

# TODO before accepting new uploads perofm sanity checks on the artifacts (E.g. the tar being well formed)
chmod go+r ./*.efi # efi images are 700, make them readable so the server can serve them
scp "image/efi/EFI/Linux/$EFI" root@web.local:/var/www/html
scp "$TAR" root@web.local:/var/www/html
scp "$IMG" root@web.local:/var/www/html
scp "live.efi" root@web.local:/var/www/html
ssh root@web.local -- /bin/sh -c "'cd /var/www/html/ && ./update.sh'"

echo "$VERSION" > version
