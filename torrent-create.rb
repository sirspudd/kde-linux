#!/usr/bin/env ruby
# frozen_string_literal: true

# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# SPDX-FileCopyrightText: 2024 Harald Sitter <sitter@kde.org>

require 'json'
require 'nokogiri'
require 'open-uri'

def mirror_list
  data = URI.open('https://files.kde.org/last-updated.mirrorlist',
    "User-Agent" => "KDELinux/mirror-list.rb #{RUBY_VERSION}",
    "Accept" => "text/html"
  ).read

  urls = Nokogiri::HTML(data).xpath('//a/@href').map(&:value)
  urls = urls.reject { |url| url.include?('last-updated') || url == '/' || !url.end_with?('/') }
  raise if urls.empty?

  urls
end

VERSION = ARGV.fetch(0)
OUTPUT = ARGV.fetch(1)
RAW = ARGV.fetch(2)

base_args = %w[transmission-create
  --tracker udp://tracker.opentrackr.org:1337/announce
  --tracker udp://open.demonii.com:1337/announce
  --tracker udp://open.tracker.cl:1337/announce
  --tracker udp://open.stealth.si:80/announce
  --tracker udp://tracker.torrent.eu.org:451/announce
  --tracker udp://tracker-udp.gbitt.info:80/announce
  --tracker udp://opentracker.io:6969/announce
  --tracker udp://explodie.org:6969/announce]

webseed_args = mirror_list.map do |url|
  ["--webseed", url]
end.flatten

args = base_args + webseed_args
args += ['--comment', "KDE Linux #{VERSION}", "--outfile", "#{OUTPUT}.torrent", RAW]

system(*args) || raise
