// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
// SPDX-FileCopyrightText: 2025 Harald Sitter <sitter@kde.org>

use libbtrfsutil::{sync, DeleteSubvolumeOptions, IterateSubvolume};
use std::{env, fs, path::PathBuf};

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        println!("Usage: {} <subvolume_path>", args[0]);
        println!("Cleans up all subvolumes in the given path. Recursively.");
        return;
    }

    let relative_work_path = PathBuf::from(&args[1]);
    let work_path = match fs::canonicalize(&relative_work_path) {
        Ok(path) => path,
        Err(error) => panic!("Problem resolving {relative_work_path:?}: {error:?}"),
    };

    // Find the actual subvolume root. We cannot feed arbitrary paths into libbtrfsutil as it will errno out.
    // Instead try iterating all the way up to / and check if we can find a subvolume.
    // The end result is that subvolume_path contains path of an actual subvolume and iter is an iter.
    let mut subvolume_path = work_path.clone();
    let iter = loop {
        let iter = match IterateSubvolume::new(&subvolume_path).iter_with_info() {
            Ok(iter) => iter,
            Err(error) => {
                if !subvolume_path.pop() {
                    println!("No more parent directories to check.");
                    panic!("Failed to find subvolume root {error:?}");
                }
                continue;
            }
        };
        break iter;
    };

    println!("Subvolume path: {}", subvolume_path.display());
    println!("Work path: {}", work_path.display());

    for (path, _info) in iter.filter_map(|s| s.ok())
    {
        let to_remove = subvolume_path.join(path);
        // Boundary check! The "root" subvolume could be / so we need to filter our subdirectories as otherwise we would
        // end up deleting stuff in /. Not the biggest concern inside docker, but in case someone runs this outside.
        // Better safe than sorry.
        if !to_remove.starts_with(&work_path) {
            println!("Skipping {to_remove:?} as it is not a child of {work_path:?}");
            continue;
        }

        println!("Going to remove {to_remove:?}");

        match DeleteSubvolumeOptions::new().recursive(true).delete(&to_remove) {
            Ok(_) => println!("Deleted subvolume: {to_remove:?}"),
            Err(error) => println!("Problem deleting subvolume {to_remove:?}: {error:?}")
        }
    }

    println!("Syncing {subvolume_path:?}…");
    let _ = sync(subvolume_path);
}
