// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
// SPDX-FileCopyrightText: 2024 Harald Sitter <sitter@kde.org>

package main

import (
	"errors"
	"io"
	"log"
	"net/http"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/pkg/sftp"
	"golang.org/x/crypto/ssh"
	"gopkg.in/yaml.v2"
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

func readSHA256(url string) string {
	url = strings.Replace(url, os.Getenv("SSH_PATH"), "https://files.kde.org/kde-linux/", 1)

	log.Println("Reading SHA256 from", url)
	var err error
	for i := 1; i <= 10; i++ {
		if i > 1 {
			time.Sleep(8 * time.Second)
		}

		var client http.Client
		resp, err := client.Get(url)
		if err != nil {
			continue
		}
		defer resp.Body.Close()

		if resp.StatusCode == http.StatusOK {
			bodyBytes, err := io.ReadAll(resp.Body)
			if err != nil {
				continue
			}
			return string(bodyBytes)
		}
	}
	log.Println("Failed to read SHA256. Last error was on url", url, err)
	return ""
}

type release struct {
	artifacts []string
}

func readSHA256s(toKeep []string, releases map[string]release) []string {
	sha256s := []string{}
	for _, key := range toKeep {
		artifacts := releases[key].artifacts
		sort.Strings(artifacts) // Sort artifacts to ensure consistent order
		for _, artifact := range artifacts {
			sha256 := readSHA256(artifact + ".sha256")
			if sha256 == "" {
				log.Println("Failed to read SHA256 for", artifact)
				os.Exit(1)
			}
			sha256s = append(sha256s, sha256)
		}
	}
	return sha256s
}

func writeSHA256s(sha256s []string) {
	file, err := os.Create("SHA256SUMS")
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()
	for _, sha256 := range sha256s {
		_, err := file.WriteString(sha256 + "\n")
		if err != nil {
			log.Fatal(err)
		}
	}
}

type config struct {
	TombstoneImages []string `yaml:"tombstone_images"`
	GoldImages      []string `yaml:"gold_images"`
}

func readConfig(client *sftp.Client, path string) (*config, error) {
	configFile, err := client.Open(path)
	if err != nil {
		return nil, err
	}
	defer configFile.Close()

	data, err := io.ReadAll(configFile)
	if err != nil {
		return nil, err
	}

	var config config
	err = yaml.Unmarshal(data, &config)
	if err != nil {
		return nil, err
	}

	return &config, nil
}

func loadReleases(client *sftp.Client, path string, config *config) (map[string]release, error) {
	releases := map[string]release{}

	w := client.Walk(path + "/") // The terminal / is important otherwise we'll walk the symlink
	for w.Step() {
		if w.Err() != nil {
			return releases, errors.New("Failed to walk path: " + w.Err().Error())
		}

		name := w.Stat().Name()
		// NOTE: we want to keep the legacy kdeos_ prefix for as long as we have relevant tombstones around. Which is possibly forever.
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
			return releases, errors.New("Failed to parse release number: " + name)
		}
		release := releases[name]
		release.artifacts = append(releases[name].artifacts, w.Path())
		releases[name] = release
	}

	return releases, nil
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
	defer conn.Close()

	// open an SFTP session over an existing ssh connection.
	client, err := sftp.NewClient(conn)
	if err != nil {
		log.Fatal(err)
	}
	defer client.Close()

	config, err := readConfig(client, path+"/vacuum.yaml")
	if err != nil {
		log.Fatal(err)
	}

	releases, err := loadReleases(client, path, config)
	if err != nil {
		log.Fatal(err)
	}

	if len(releases) == 0 {
		log.Println("No releases found")
		return
	}

	for _, tombstone := range config.TombstoneImages {
		log.Println("Ignoring (keeping) tombstone image", tombstone)
		delete(releases, tombstone)
	}

	for _, gold := range config.GoldImages {
		log.Println("Ignoring (keeping) golden image", gold)
		delete(releases, gold)
	}

	// Sort releases by key
	var toKeep []string
	for key := range releases {
		toKeep = append(toKeep, key)
	}
	sort.Sort(sort.Reverse(sort.StringSlice(toKeep)))

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

	// Start the SHA256SUMS file. It will be completed by the upload script.
	writeSHA256s(readSHA256s(toKeep, releases))
}
