#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# SPDX-FileCopyrightText: 2024 Harald Sitter <sitter@kde.org>
# SPDX-FileCopyrightText: 2024 Bruno Pajdek <brupaj@proton.me>

# Something in GitLab causes bogus permissions to be set for mkosi stuff,
# reset them to something sane.

# Enable ** for recursive globbing and include hidden files when doing so.
shopt -s globstar dotglob

# Loop through all mkosi files.
for FILE in mkosi.*/**/*; do
    # Skip symlinks.
    if [ -L "$FILE" ]; then
        continue
    fi

    # If the file is executable, reset permissions to 755, else to 644.
    if [ -x "$FILE" ]; then
        chmod 755 "$FILE"
    else
        chmod 644 "$FILE"
    fi
done
