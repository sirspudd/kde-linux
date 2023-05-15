#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# SPDX-FileCopyrightText: 2023 Harald Sitter <sitter@kde.org>

# called by dracut
check() {
    return 0
}

# called by dracut
depends() {
    return 0
}

# called by dracut
installkernel() {
    hostonly='' instmods overlay
}

# called by dracut
install() {
    inst_hook pre-pivot 90 "$moddir/systemdOS.sh"
}
