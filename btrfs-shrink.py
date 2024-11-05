#!/usr/bin/env python3

# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# SPDX-FileCopyrightText: 2024 Harald Sitter <sitter@kde.org>

# Shrink btrfs. It's a bit awkward because we don't really have a reliable way
# to calculate how much space we actually need. So we first chop off a dynamic
# portion but leave a bit of a buffer behind. Then we keep resizing until the
# resize starts failing.

import json
import subprocess
from subprocess import check_output

out = check_output(["btrfs", "--format", "json", "filesystem", "df", "."])
data = json.loads(out)
df = data["filesystem-df"]

size = 0
for block_group in df:
    size += block_group["total"]

# Give 512MiB of buffer space. We'll shrink from there in smaller steps.
size += 512 * 1024 * 1024

subprocess.run(["btrfs", "filesystem", "resize", str(size), "."])

# With compression one extent is always 128KiB as per btrfs documentation.
extent_size = 128 * 1024
while True:
    try:
        subprocess.run(["btrfs", "filesystem", "resize", f"-{extent_size}", "."], stdout=subprocess.DEVNULL, stdin=subprocess.DEVNULL, check=True)
        size -= extent_size
    except subprocess.CalledProcessError as e:
        print(e)
        break

with open("btrfs.json", "w") as file:
    # Writing data to a file
    file.write(json.dumps({"size": size}))
