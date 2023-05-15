#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# SPDX-FileCopyrightText: 2023 Harald Sitter <sitter@kde.org>

. /lib/dracut-lib.sh

set -x

sysroot="$NEWROOT"

do_overlay() {
    # For the live image we use systemd.volatile, no need to overlay anything.
    getargbool 0 systemdOS.live && return 0

    mount -v -o subvol=/ /dev/gpt-auto-root "${sysroot}/system"

    mount -v \
        -t overlay \
        -o "lowerdir=${sysroot}/etc,upperdir=${sysroot}/system/@etc-overlay/upper,workdir=${sysroot}/system/@etc-overlay/work" \
        overlay "${sysroot}/etc"
    mount -v \
        -t overlay \
        -o "lowerdir=${sysroot}/var,upperdir=${sysroot}/system/@var-overlay/upper,workdir=${sysroot}/system/@var-overlay/work" \
        overlay "${sysroot}/var"

    return 0
}

if do_overlay; then
    return 0
fi

warn "systemdOS failed. Starting emergency shell."
emergency_shell
