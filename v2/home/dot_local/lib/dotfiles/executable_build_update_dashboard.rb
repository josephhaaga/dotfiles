#!/usr/bin/env ruby

require "json"
require "fileutils"
require "net/http"
require "time"
require "uri"
require "yaml"

PACKAGES_PATH = ENV.fetch("DASHBOARD_PACKAGES", File.expand_path("~/.local/share/dotfiles/update-dashboard/packages.json"))
LOCK_PATH = ENV.fetch("DASHBOARD_LOCK", File.expand_path("~/.config/nvim/lazy-lock.json"))
SOURCES_PATH = ENV.fetch("DASHBOARD_SOURCES", File.expand_path("~/.local/share/dotfiles/update-dashboard/sources.json"))
OUTPUT_PATH = ENV.fetch("DASHBOARD_OUTPUT", File.expand_path("~/.local/share/dotfiles/html/private/updates/data.js"))

def get(url, github: false)
  uri = URI(url)
  request = Net::HTTP::Get.new(uri)
  request["Accept"] = "application/vnd.github+json" if github
  request["User-Agent"] = "dotfiles-update-dashboard"
  request["Authorization"] = "Bearer #{ENV.fetch("GITHUB_TOKEN")}" if github && ENV["GITHUB_TOKEN"]

  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
    http.request(request)
  end
  raise "#{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

  response.body
end

def concurrent_map(items, workers: 8, &block)
  queue = Queue.new
  items.each_with_index { |item, index| queue << [index, item] }
  results = Array.new(items.length)
  [workers, items.length].min.times.map do
    Thread.new do
      loop do
        index, item = queue.pop(true)
        results[index] = block.call(item)
      rescue ThreadError
        break
      end
    end
  end.each(&:join)
  results
end

def version_status(installed, latest)
  return "unknown" if latest.nil? || latest.empty?
  installed.to_s.sub(/^v/, "") == latest.to_s.sub(/^v/, "") ? "current" : "update"
end

def error_entry(entry, error)
  entry.merge("status" => "unknown", "error" => error.message)
end

packages = if File.extname(PACKAGES_PATH) == ".json"
  JSON.parse(File.read(PACKAGES_PATH)).fetch("packages")
else
  YAML.safe_load(File.read(PACKAGES_PATH)).fetch("packages")
end
sources = JSON.parse(File.read(SOURCES_PATH))
lock = JSON.parse(File.read(LOCK_PATH))
apps = []

mise_entries = packages.fetch("mise").merge(packages.fetch("mise_server")).map do |name, installed|
  { "name" => name, "category" => "Toolchain", "manager" => "mise", "installed" => installed.to_s }
end

apps.concat(concurrent_map(mise_entries) do |entry|
  begin
    lookup_name = entry.fetch("name").sub(/^cargo:/, "")
    versions = if entry.fetch("name").start_with?("cargo:")
      crate_data = JSON.parse(get("https://crates.io/api/v1/crates/#{URI.encode_www_form_component(lookup_name)}"))
      [crate_data.fetch("crate").fetch("max_stable_version")]
    else
      get("https://mise-versions.jdx.dev/#{URI.encode_www_form_component(lookup_name)}").lines.map(&:strip)
    end
    latest = versions.reverse.find { |version| version.match?(/^v?\d/) && !version.match?(/(?:alpha|beta|rc|nightly)/i) }
    metadata = sources.fetch("apps", {}).fetch(entry.fetch("name"), {})
    entry.merge(
      "latest" => latest,
      "status" => version_status(entry.fetch("installed"), latest),
      "url" => metadata["repo"] && "https://github.com/#{metadata.fetch("repo")}/releases"
    )
  rescue StandardError => error
    error_entry(entry, error)
  end
end)

npm_entries = packages.fetch("npm").map do |name, installed|
  { "name" => name, "category" => "Toolchain", "manager" => "npm", "installed" => installed.to_s }
end

apps.concat(concurrent_map(npm_entries) do |entry|
  begin
    metadata = sources.fetch("apps", {}).fetch(entry.fetch("name"), {})
    if metadata["latest"] == "github-release"
      releases = JSON.parse(get("https://api.github.com/repos/#{metadata.fetch("repo")}/releases?per_page=10", github: true))
      release = releases.find { |candidate| !candidate.fetch("draft") && !candidate.fetch("prerelease") }
      raise "No stable GitHub release found" unless release

      latest = release.fetch("tag_name").sub(/^v/, "")
      notes = releases.reject { |candidate| candidate.fetch("draft") || candidate.fetch("prerelease") }.map do |candidate|
        {
          "title" => candidate.fetch("name", candidate.fetch("tag_name")),
          "body" => candidate.fetch("body", "").slice(0, 8_000),
          "url" => candidate.fetch("html_url"),
          "publishedAt" => candidate["published_at"]
        }
      end
      entry.merge(
        "name" => metadata.fetch("name", entry.fetch("name")),
        "latest" => latest,
        "status" => version_status(entry.fetch("installed"), latest),
        "featured" => metadata.fetch("featured", false),
        "url" => release.fetch("html_url"),
        "notes" => notes
      )
    else
      package_name = URI.encode_www_form_component(entry.fetch("name"))
      package_data = JSON.parse(get("https://registry.npmjs.org/#{package_name}/latest"))
      latest = package_data.fetch("version")
      entry.merge("latest" => latest, "status" => version_status(entry.fetch("installed"), latest), "url" => package_data["homepage"])
    end
  rescue StandardError => error
    error_entry(entry, error)
  end
end)

brew_entries = packages.dig("macos", "brews").map { |name| ["formula", name] }
brew_entries.concat(packages.dig("macos", "casks").map { |name| ["cask", name] })
apps.concat(concurrent_map(brew_entries) do |kind, name|
  entry = { "name" => name.split("/").last, "category" => "macOS apps", "manager" => "Homebrew #{kind}", "installed" => "rolling" }
  if name.include?("/")
    entry.merge("latest" => "tap managed", "status" => "tracking")
  else
    begin
      data = JSON.parse(get("https://formulae.brew.sh/api/#{kind}/#{URI.encode_www_form_component(name)}.json"))
      latest = kind == "formula" ? data.dig("versions", "stable") : data["version"]
      entry.merge("latest" => latest, "status" => "tracking", "url" => data["homepage"])
    rescue StandardError => error
      error_entry(entry, error)
    end
  end
end)

packages.fetch("amazon_linux").each do |name|
  apps << { "name" => name, "category" => "Server packages", "manager" => "DNF", "installed" => "OS managed", "latest" => "repository managed", "status" => "tracking" }
end

plugin_entries = lock.map do |name, pin|
  [name, pin, sources.fetch("plugins")[name]]
end
apps.concat(concurrent_map(plugin_entries) do |name, pin, repo|
  entry = {
    "name" => name,
    "category" => "Neovim plugins",
    "manager" => "lazy.nvim",
    "installed" => pin.fetch("commit")[0, 7],
    "url" => "https://github.com/#{repo}"
  }
  begin
    comparison = JSON.parse(get("https://api.github.com/repos/#{repo}/compare/#{pin.fetch("commit")}...#{pin.fetch("branch")}", github: true))
    commits = comparison.fetch("commits", [])
    entry.merge(
      "latest" => comparison.dig("commits", -1, "sha")&.slice(0, 7) || pin.fetch("commit")[0, 7],
      "status" => comparison.fetch("ahead_by", 0).positive? ? "update" : "current",
      "updateCount" => comparison.fetch("ahead_by", 0),
      "url" => comparison.fetch("html_url", entry.fetch("url")),
      "notes" => commits.last(20).reverse.map do |commit|
        {
          "title" => commit.dig("commit", "message").to_s.lines.first.to_s.strip,
          "url" => commit["html_url"],
          "publishedAt" => commit.dig("commit", "author", "date")
        }
      end
    )
  rescue StandardError => error
    error_entry(entry, error)
  end
end)

data = {
  "generatedAt" => Time.now.utc.iso8601,
  "sourceCommit" => ENV["GITHUB_SHA"]&.slice(0, 7),
  "apps" => apps.sort_by { |app| [app["featured"] ? 0 : 1, app.fetch("category"), app.fetch("name").downcase] }
}

FileUtils.mkdir_p(File.dirname(OUTPUT_PATH)) unless Dir.exist?(File.dirname(OUTPUT_PATH))
File.write(OUTPUT_PATH, "window.__UPDATE_DASHBOARD_DATA__ = #{JSON.generate(data)};\n")
warn "Wrote #{apps.length} entries to #{OUTPUT_PATH}"
