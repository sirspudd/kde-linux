#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# SPDX-FileCopyrightText: 2024 Harald Sitter <sitter@kde.org>

set -e

# For the vacuum helper and this script
export SSH_IDENTITY="$PWD/.secure_files/ssh.key"
export SSH_USER=kdeos
export SSH_HOST=files.kde.org
export SSH_PATH=/home/kdeos/kde-linux
export SSH_REALLY_DELETE=1

go -C ./upload-vacuum/ build -o upload-vacuum .
./upload-vacuum/upload-vacuum

# For this script only
REMOTE=$USER@$HOST:$PATH

scp -i "$IDENTITY" "$REMOTE/SHA256SUMS" SHA256SUMS || true
[ -f SHA256SUMS ] || touch SHA256SUMS

# More readable this way, ignore shellcheck
# shellcheck disable=SC2129
sha256sum -- *.efi >> SHA256SUMS
sha256sum -- *.raw >> SHA256SUMS
sha256sum -- *.tar.zst >> SHA256SUMS

scp -i "$IDENTITY" ./*.efi ./*.raw ./*.tar.zst "$REMOTE"
scp -i "$IDENTITY" SHA256SUMS "$REMOTE" # upload as last artifact to finalize the upload
