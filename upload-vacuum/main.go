// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
// SPDX-FileCopyrightText: 2024 Harald Sitter <sitter@kde.org>

package main

import (
	"errors"
	"log"
	"os"
	"sort"
	"strconv"
	"strings"

	"github.com/pkg/sftp"
	"golang.org/x/crypto/ssh"
)

func connectToHost(user, host, identity string) (*ssh.Client, *ssh.Session, error) {
	key, err := os.ReadFile(identity)
	if err != nil {
		log.Fatalf("unable to read private key: %v", err)
	}

	// Create the Signer for this private key.
	signer, err := ssh.ParsePrivateKey(key)
	if err != nil {
		log.Fatalf("unable to parse private key: %v", err)
	}

	// You can use `ssh-keyscan origin.files.kde.org` to get the host key
	_, _, hostKey, _, _, err := ssh.ParseKnownHosts([]byte("origin.files.kde.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILUjdH4S7otYIdLUkOZK+owIiByjNQPzGi7GQ5HOWjO6"))
	if err != nil {
		log.Fatalf("unable to parse host public key: %v", err)
	}
	sshConfig := &ssh.ClientConfig{
		User:              user,
		Auth:              []ssh.AuthMethod{ssh.PublicKeys(signer)},
		HostKeyAlgorithms: []string{"ssh-ed25519"},
		HostKeyCallback:   ssh.FixedHostKey(hostKey),
	}

	client, err := ssh.Dial("tcp", host, sshConfig)
	if err != nil {
		return nil, nil, err
	}

	session, err := client.NewSession()
	if err != nil {
		client.Close()
		return nil, nil, err
	}

	return client, session, nil
}

type release struct {
	artifacts []string
}

func main() {
	identity := os.Getenv("SSH_IDENTITY")
	host := os.Getenv("SSH_HOST")
	user := os.Getenv("SSH_USER")
	path := os.Getenv("SSH_PATH")

	var errs []error
	if identity == "" {
		errs = append(errs, errors.New("SSH_IDENTITY not set"))
	}
	if host == "" {
		errs = append(errs, errors.New("SSH_HOST not set"))
	}
	if user == "" {
		errs = append(errs, errors.New("SSH_USER not set"))
	}
	if path == "" {
		errs = append(errs, errors.New("SSH_PATH not set"))
	}
	for _, err := range errs {
		log.Println(err)
	}
	if len(errs) > 0 {
		os.Exit(1)
	}

	conn, _, err := connectToHost(user, host+":22", identity)
	if err != nil {
		log.Fatal(err)
	}

	// open an SFTP session over an existing ssh connection.
	client, err := sftp.NewClient(conn)
	if err != nil {
		log.Fatal(err)
	}
	defer client.Close()

	releases := map[string]release{}

	w := client.Walk(path + "/") // The terminal / is important otherwise we'll walk the symlink
	for w.Step() {
		if w.Err() != nil {
			continue
		}
		name := w.Stat().Name()
		if !strings.HasPrefix(name, "kdeos_") && !strings.HasPrefix(name, "kde-linux_") {
			continue
		}
		name = strings.TrimPrefix(name, "kdeos_")
		name = strings.TrimPrefix(name, "kde-linux_")
		name = strings.SplitN(name, ".", 2)[0]
		name = strings.SplitN(name, "_", 2)[0]
		if _, ok := releases[name]; !ok {
			releases[name] = release{}
		}
		_, err := strconv.Atoi(name)
		if err != nil {
			log.Fatal("Bad release name: ", name)
			continue
		}
		release := releases[name]
		release.artifacts = append(releases[name].artifacts, w.Path())
		releases[name] = release
	}

	// Sort releases by key
	var toKeep []string
	for key := range releases {
		toKeep = append(toKeep, key)
	}
	sort.Sort(sort.Reverse(sort.StringSlice(toKeep)))

	if len(toKeep) == 0 {
		log.Println("No releases found")
		return
	}

	var toDelete []string
	for len(toKeep) > 4 {
		log.Println("Marking for deletion", toKeep[len(toKeep)-1])
		toDelete = append(toDelete, toKeep[len(toKeep)-1])
		toKeep = toKeep[:len(toKeep)-1]
	}

	for _, key := range toDelete {
		log.Println("Deleting", key)
		for _, artifact := range releases[key].artifacts {
			log.Println("Deleting", artifact)
			if os.Getenv("SSH_REALLY_DELETE") == "1" {
				err := client.Remove(artifact)
				if err != nil {
					log.Println("Failed to delete", artifact, err)
				}
			} else {
				log.Println("... not really deleting")
			}
		}
	}

	for _, key := range toKeep {
		log.Println("Keeping", key)
	}
}
