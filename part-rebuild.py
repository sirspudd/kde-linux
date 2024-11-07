#!/usr/bin/env python3

# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# SPDX-FileCopyrightText: 2024 Harald Sitter <sitter@kde.org>

# Rebuilds the image using appropriate partition sizes.

import json
import math
import subprocess
from subprocess import check_output
import sys
import os

RAW = sys.argv[1]

# Load the partition table
out = check_output(["sfdisk", "--json", RAW])
data = json.loads(out)
partitiontable = data["partitiontable"]
sectorsize = partitiontable["sectorsize"]
partitions = partitiontable["partitions"]

# Find the root partition
root_partition = None
for index, partition in enumerate(partitions):
    if partition["name"] == "KDELinuxLive":
        root_partition = partition

# Update its size to what it actually is on the filesystem level
btrfs = json.loads(open("btrfs.json").read())
root_partition["size"] = math.ceil(btrfs['size'] / sectorsize)

# Fish out the partitions with appropriate skip and count values (i.e. the actual filesystem sizes)
for index, partition in enumerate(partitions):
    subprocess.run(["dd", f"if={RAW}", f"of={partition["name"]}.raw", f"bs={sectorsize}", f"skip={partition["start"]}", f"count={partition["size"]}"], check=True)

# Then reassemble them into a new image using those squeezed partition images.
open(RAW, "w").close()
subprocess.run(["systemd-repart", "--size=auto", "--empty=allow", "--dry-run=no", "--definitions=mkosi.repart-rebuild", "--root", os.getcwd(), RAW], check=True)

# Clean up the partitions again
for partition in partitions:
    os.remove(f"{partition["name"]}.raw")
