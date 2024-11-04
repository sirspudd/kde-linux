#!/usr/bin/env python3

# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# SPDX-FileCopyrightText: 2024 Harald Sitter <sitter@kde.org>

import glob
import os

# Something in gitlab causes bogus permissions to be set, reset them to something sane.

files = glob.glob('mkosi.*/**/*', recursive=True, include_hidden=True)
for file in files:
    if os.path.islink(file):
        continue

    if os.access(file, os.X_OK):
        os.chmod(file, 0o755)
    else:
        os.chmod(file, 0o644)
