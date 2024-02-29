#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# SPDX-FileCopyrightText: 2024 Harald Sitter <sitter@kde.org>

set -e

s3="s3cmd \
  --access_key=$AWS_ACCESS_KEY_ID \
  --secret_key=$AWS_SECRET_ACCESS_KEY \
  --host fra1.digitaloceanspaces.com \
  --host-bucket=%(bucket)s.fra1.digitaloceanspaces.com \
  --no-progress"

$s3 get s3://kdeos/SHA256SUMS SHA256SUMS || true
[ -f SHA256SUMS ] || touch SHA256SUMS

# More readable this way.
# shellcheck disable=SC2129
sha256sum -- *.efi >> SHA256SUMS
sha256sum -- *.raw >> SHA256SUMS
sha256sum -- *.tar.zst >> SHA256SUMS

$s3 --acl-public put ./*.efi s3://kdeos
$s3 --acl-public put ./*.raw s3://kdeos
$s3 --acl-public put ./*.tar.zst s3://kdeos
$s3 --acl-public put SHA256SUMS s3://kdeos
