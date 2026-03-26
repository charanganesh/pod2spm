# frozen_string_literal: true

module Pod2SPM
  # Result of scanning Pods/ after `pod install`.
  DetectionResult = Struct.new(:xcframeworks, :resource_bundles, :vendored_frameworks) do
    def initialize(xcframeworks: [], resource_bundles: [], vendored_frameworks: [])
      super(xcframeworks, resource_bundles, vendored_frameworks)
    end

    def prebuilt?
      !xcframeworks.empty?
    end
  end

  module Detect
    # Scan the Pods/ directory for xcframeworks, vendored frameworks, and
    # resource bundles scoped to a specific pod.
    #
    # When pod_name is given the search is restricted to Pods/<pod_name>/.
    # Falls back to a full Pods/ scan only when no pod-specific directory
    # exists (e.g. umbrella pods that don't have their own subdirectory).
    #
    # Also detects plain .framework bundles (vendored_frameworks) and
    # returns them separately so callers can warn or handle them.
    def self.scan(pods_dir, pod_name = nil)
      result = DetectionResult.new

      return result unless File.directory?(pods_dir)

      search_root = pods_dir
      if pod_name
        pod_dir = File.join(pods_dir, pod_name)
        search_root = pod_dir if File.directory?(pod_dir)
      end

      xcframeworks = Dir.glob(File.join(search_root, "**", "*.xcframework"))
        .select { |p| File.directory?(p) }
        .reject { |p| p.include?("Target Support Files") }
        .sort

      vendored = Dir.glob(File.join(search_root, "**", "*.framework"))
        .select { |p| File.directory?(p) }
        .reject { |p| p.include?("Target Support Files") }
        .reject { |p| p.include?(".xcframework") }
        .sort

      bundles = Dir.glob(File.join(search_root, "**", "*.bundle"))
        .select { |p| File.directory?(p) }
        .reject { |p| p.include?("Target Support Files") }
        .sort

      result.xcframeworks        = xcframeworks
      result.vendored_frameworks = vendored
      result.resource_bundles    = bundles
      result
    end
  end
end
