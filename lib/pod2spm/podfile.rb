# frozen_string_literal: true

module Pod2SPM
  module Podfile
    # Write a minimal Podfile for installing a single pod. Returns the path.
    def self.generate(pod_name, version, platform, min_deployment_target, directory)
      content = <<~PODFILE
        platform :#{platform}, '#{min_deployment_target}'

        target 'TempTarget' do
          use_frameworks!
          pod '#{pod_name}', '#{version}'
        end
      PODFILE

      path = File.join(directory, "Podfile")
      File.write(path, content)
      path
    end

    # Parse a Podfile and return an array of [pod_name, version_or_nil] pairs.
    #
    # Handles:
    #   pod 'Name', '1.2.3'
    #   pod 'Name', '~> 1.2'
    #   pod 'Name'
    def self.parse(podfile_path)
      text = File.read(podfile_path)
      pattern = /pod\s+['"]([^'"]+)['"]\s*(?:,\s*['"]([^'"]*?)['"])?/

      results = []
      text.scan(pattern) do |name, version_spec|
        if version_spec && !version_spec.empty?
          # Strip leading operators: ~>, >=, <=, >, <, !=
          clean = version_spec.sub(/\A[~>=<!\s]+/, "").strip
          results << [name, clean.empty? ? nil : clean]
        else
          results << [name, nil]
        end
      end
      results
    end
  end
end
