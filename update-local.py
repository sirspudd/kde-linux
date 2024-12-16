#!/usr/bin/python3
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# SPDX-FileCopyrightText: 2024 Harald Sitter <sitter@kde.org> Ian Monroe <imonroe@kde.org>

import argparse
import configparser
import os
import subprocess
import sys
import tempfile

def update_source(input_file: str, output_file: str, source_type: str, source_path: str):
    """For using the sysupdate.d file on local stores."""

    config = configparser.ConfigParser()
    config.optionxform = str
    config.read(input_file)
    config['Source']['Type'] = source_type
    config['Source']['Path'] = source_path
    with open(output_file, 'w') as f:
        config.write(f)

script_dir = os.path.dirname(os.path.realpath(__file__))

parser = argparse.ArgumentParser(description="Update KDE Linux with image files saved locally.")
parser.add_argument("path",
                    help=f"Directory path to look for kde-linux_*_root-x86-64.tar.zst and a kde-linux_*.efi files.")
parser.add_argument("sysupdate_options", nargs="*",
                    help="Options to pass to systemd-sysupdate. You probably want to pass 'update'.")
args, _ = parser.parse_known_args()

# Make sure user is root before starting
if os.geteuid() != 0:
    print("Please run as root or with run0")
    sys.exit(1)

local_image_path = args.path

if not os.path.isdir(local_image_path):
    print(f"{local_image_path} is not a valid directory.")
    parser.print_help()
    sys.exit(1)

with tempfile.TemporaryDirectory() as definitions:
    update_source(
        input_file  = os.path.join(script_dir, "mkosi.extra/usr/lib/sysupdate.d/50-root-x86-64.conf"),
        output_file = os.path.join(definitions, "50-root-x86-64.conf"),
        source_type = "tar",
        source_path = local_image_path
    )
    update_source(
        input_file  = os.path.join(script_dir, "mkosi.extra/usr/lib/sysupdate.d/60-esp.conf"),
        output_file = os.path.join(definitions, "60-esp.conf"),
        source_type = "regular-file",
        source_path = local_image_path
    )

    # Trigger mount of ESP by accessing it.
    # TODO file bug that sysupdate doesn't do that.
    try:
        os.stat("/efi/EFI")
    except FileNotFoundError:
        pass

    os.environ["TAR_OPTIONS"] = "--zstd"
    # FIXME set up signing shebang so we can run with verify
    subprocess.run([
        "systemd-inhibit",
        "--what=sleep:shutdown",
        "--mode=block",
        "--who=KDE Linux Updater",
        "--why=Updating System",
        "/usr/lib/systemd/systemd-sysupdate",
        f"--definitions={definitions}",
        "--verify=no",
        *args.sysupdate_options  # Pass remaining arguments
    ])
