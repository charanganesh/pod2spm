# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module Pod2SPM
  module Versions
    TRUNK_API = "https://trunk.cocoapods.org/api/v1/pods"

    # Query CocoaPods Trunk API for the latest version of a pod.
    # Returns a version string.
    # Raises VersionFetchError on network/API failures.
    # Returns nil only when the pod exists but has no published versions.
    def self.fetch_latest(pod_name)
      uri = URI("#{TRUNK_API}/#{URI.encode_www_form_component(pod_name)}")
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 10) do |http|
        http.get(uri.path)
      end

      unless response.code == "200"
        raise Pod2SPM::VersionFetchError,
          "CocoaPods Trunk returned HTTP #{response.code} for '#{pod_name}'"
      end

      data     = JSON.parse(response.body)
      versions = data["versions"] || []
      return nil if versions.empty?

      versions.last["name"]
    rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EHOSTUNREACH,
           Net::OpenTimeout, Net::ReadTimeout, SocketError => e
      raise Pod2SPM::VersionFetchError,
        "Network error fetching version for '#{pod_name}': #{e.message}"
    rescue JSON::ParserError => e
      raise Pod2SPM::VersionFetchError,
        "Invalid JSON from Trunk API for '#{pod_name}': #{e.message}"
    end

    # Parse a Podfile, query Trunk for each pod, and print a comparison table.
    def self.check(podfile_path)
      pods = Pod2SPM::Podfile.parse(podfile_path)

      if pods.empty?
        puts "No pods found in Podfile."
        return
      end

      col_widths = { pod: 3, pinned: 6, latest: 6 }
      pods.each do |(name, _)|
        col_widths[:pod] = [col_widths[:pod], name.length].max
      end

      header = format("%-#{col_widths[:pod]}s  %-#{col_widths[:pinned]}s  %-#{col_widths[:latest]}s  %s",
                      "Pod", "Pinned", "Latest", "Status")
      separator = "-" * header.length

      puts "\nPod Version Check"
      puts separator
      puts header
      puts separator

      pods.each do |(name, pinned)|
        latest = begin
          fetch_latest(name)
        rescue Pod2SPM::VersionFetchError
          nil
        end

        status, pinned_display = if pinned.nil?
          ["unpinned", "-"]
        elsif latest.nil?
          ["unknown", pinned]
        elsif pinned == latest
          ["current", pinned]
        else
          ["outdated", pinned]
        end

        puts format("%-#{col_widths[:pod]}s  %-#{col_widths[:pinned]}s  %-#{col_widths[:latest]}s  %s",
                    name, pinned_display, latest || "?", status)
      end

      puts separator
    end
  end
end
