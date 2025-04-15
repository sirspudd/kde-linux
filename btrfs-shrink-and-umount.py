#!/usr/bin/env python3

# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# SPDX-FileCopyrightText: 2024 Harald Sitter <sitter@kde.org>

# Shrink btrfs. It's a bit awkward because we don't really have a reliable way
# to calculate how much space we actually need. So we first chop off a dynamic
# portion but leave a bit of a buffer behind. Then we keep resizing until the
# resize starts failing.

import json
import os
import math
import subprocess
from subprocess import check_output

os.chdir('root.raw.mnt')

drive_size = check_output(['findmnt', '--bytes', '--noheadings', '--output', 'size', '.']).strip()
drive_size = int(drive_size)

out = check_output(["btrfs", "--format", "json", "filesystem", "df", "."])
data = json.loads(out)
df = data["filesystem-df"]

size = 0
for block_group in df:
    size += block_group["total"]

# Give 50% buffer space. We'll shrink from there in smaller steps. Make sure to not blow past the partition size.
size = min(drive_size, math.ceil(size * 1.5))
original_size = size

subprocess.check_call(["btrfs", "filesystem", "resize", str(size), "."])

# With compression one extent is always 128KiB as per btrfs documentation.
# extent_size = 128 * 1024
# For now we use 32MiB as the extent size so as to not slow down the build too much though.
extent_size = 32 * 1024 * 1024
while True:
    try:
        subprocess.check_call(["btrfs", "filesystem", "resize", f"-{extent_size}", "."], stdout=subprocess.DEVNULL, stdin=subprocess.DEVNULL)
        subprocess.check_call(["btrfs", "filesystem", "sync", "."])
        size -= extent_size
    except subprocess.CalledProcessError as e:
        print(e)
        break

# Next we truncate the actual partition file by the according amount. For practical reasons this happens here so we don't
# have to pass the sizes around between different programs.
os.chdir('..')
subprocess.check_call(['umount', 'root.raw.mnt'])
subprocess.check_call(['truncate', f'--size=-{original_size - size}', 'root.raw'])


