#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# SPDX-FileCopyrightText: 2024 Harald Sitter <sitter@kde.org>

set -e

# Trigger mount of ESP by accessing it.
# TODO file bug that sysupdate doesn't do that.
stat /efi/EFI

export TAR_OPTIONS="--zstd"
# FIXME set up signing shebang so we can run with verify
exec /usr/lib/systemd/systemd-sysupdate --verify=no "$@"
