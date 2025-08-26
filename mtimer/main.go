// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
// SPDX-FileCopyrightText: 2025 Harald Sitter <sitter@kde.org>

package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"flag"
	"io"
	"log"
	"os"
	"path/filepath"
	"runtime"
	"time"

	"golang.org/x/sync/errgroup"
)

type FileInfo struct {
	SHA256 string `json:"sha256"`
	MTime  int64  `json:"mtime"`
}

type SHA256Sums struct {
	Files map[string]FileInfo `json:"files"`
}

type Analysis struct {
	info    FileInfo
	absPath string
	relPath string
}

func loadBlob(jsonPath string) (*SHA256Sums, error) {
	data, err := os.ReadFile(jsonPath)
	if err != nil {
		return nil, err
	}

	var sums SHA256Sums
	err = json.Unmarshal(data, &sums)
	if err != nil {
		return nil, err
	}
	return &sums, nil
}

func sha256SumFile(path string) string {
	f, err := os.Open(path)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		log.Fatal(err)
	}
	return hex.EncodeToString(h.Sum(nil))
}

func recordNewFile(blob *SHA256Sums, absPath string, relPath string, info os.FileInfo) {
	blob.Files[relPath] = FileInfo{
		SHA256: sha256SumFile(absPath),
		MTime:  info.ModTime().Unix(),
	}
}

func analyze(input Analysis) Analysis {
	newSum := sha256SumFile(input.absPath)
	if input.info.SHA256 != newSum {
		// File is really different
		return Analysis{
			info: FileInfo{
				SHA256: newSum,
				MTime:  input.info.MTime,
			},
			absPath: input.absPath,
			relPath: input.relPath,
		}
	}

	// The file has not actually changed. Apply the original mtime.
	log.Println("Restoring mtime for", input.relPath)
	os.Chtimes(input.absPath, time.Unix(input.info.MTime, 0), time.Unix(input.info.MTime, 0))
	return input
}

func main() {
	root := flag.String("root", "", "rootfs to operate on")
	jsonPath := flag.String("json", "", "json file to read and write")
	flag.Parse()

	if *root == "" {
		log.Fatal("no root path specified")
	}
	if *jsonPath == "" {
		log.Fatal("no json path specified")
	}

	blob, err := loadBlob(*jsonPath)
	if err != nil {
		log.Fatal(err)
	}

	newBlob := &SHA256Sums{
		Files: map[string]FileInfo{},
	}

	toAnalyze := []Analysis{}
	err = filepath.Walk(*root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
			return nil
		}

		relPath, err := filepath.Rel(*root, path)
		if err != nil {
			return err
		}

		blobInfo, ok := blob.Files[relPath]
		if !ok {
			// New file, create new entry
			recordNewFile(newBlob, path, relPath, info)
			return nil
		}

		if blobInfo.MTime != info.ModTime().Unix() { // We only care about seconds precision, there is more than that between two builds anyway
			// Changed file, queue for analysis
			toAnalyze = append(toAnalyze, Analysis{
				info:    blobInfo,
				absPath: path,
				relPath: relPath,
			})
			return nil
		}

		// Unchanged, carry over old entry
		newBlob.Files[relPath] = blobInfo
		return nil
	})
	if err != nil {
		log.Fatal(err)
	}

	ctx := context.Background()
	g, ctx := errgroup.WithContext(ctx)
	g.SetLimit(runtime.NumCPU())

	results := make([]Analysis, len(toAnalyze))
	for i, input := range toAnalyze {
		i, input := i, input // https://golang.org/doc/faq#closures_and_goroutines
		g.Go(func() error {
			info := analyze(input)
			results[i] = info
			return nil
		})
	}
	if err := g.Wait(); err != nil {
		log.Fatal(err)
	}

	for _, result := range results {
		newBlob.Files[result.relPath] = result.info
	}

	data, err := json.Marshal(newBlob)
	if err != nil {
		log.Fatal(err)
	}
	if err := os.WriteFile(*jsonPath, data, 0644); err != nil {
		log.Fatal(err)
	}
}
