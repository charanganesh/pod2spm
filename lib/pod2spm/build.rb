# frozen_string_literal: true

require "fileutils"
require "open3"

module Pod2SPM
  module Build
    # Maps platform to [sdk_device, sdk_simulator, arch_device, arch_simulator]
    PLATFORM_CONFIG = {
      "ios"   => ["iphoneos", "iphonesimulator", "arm64", "arm64 x86_64"],
      "tvos"  => ["appletvos", "appletvsimulator", "arm64", "arm64 x86_64"],
      "macos" => ["macosx", "macosx", "arm64 x86_64", "arm64 x86_64"],
    }.freeze

    # Build an XCFramework from source via xcodebuild archive + create-xcframework.
    # Returns the path to the created .xcframework.
    def self.xcframework(workspace:, scheme:, platform:, output_dir:, framework_name:)
      sdk_device, sdk_sim, = PLATFORM_CONFIG.fetch(platform)

      archives_dir   = File.join(output_dir, "_archives")
      FileUtils.mkdir_p(archives_dir)

      device_archive = File.join(archives_dir, "#{framework_name}-device.xcarchive")
      sim_archive    = File.join(archives_dir, "#{framework_name}-simulator.xcarchive")

      $stderr.puts "  Archiving #{framework_name} for #{sdk_device}..."
      Shell.run!([
        "xcodebuild", "archive",
        "-workspace", workspace,
        "-scheme", scheme,
        "-sdk", sdk_device,
        "-archivePath", device_archive,
        "SKIP_INSTALL=NO",
        "BUILD_LIBRARY_FOR_DISTRIBUTION=YES",
      ])

      # Archive for simulator (skip for macOS — same SDK)
      if sdk_device != sdk_sim
        $stderr.puts "  Archiving #{framework_name} for #{sdk_sim}..."
        Shell.run!([
          "xcodebuild", "archive",
          "-workspace", workspace,
          "-scheme", scheme,
          "-sdk", sdk_sim,
          "-archivePath", sim_archive,
          "SKIP_INSTALL=NO",
          "BUILD_LIBRARY_FOR_DISTRIBUTION=YES",
        ])
      end

      xcframework_path = File.join(output_dir, "#{framework_name}.xcframework")
      create_cmd = ["xcodebuild", "-create-xcframework", "-output", xcframework_path]

      [device_archive, sim_archive].each do |archive|
        next unless File.directory?(archive)

        frameworks_dir = File.join(archive, "Products", "Library", "Frameworks")
        unless File.directory?(frameworks_dir)
          frameworks_dir = File.join(archive, "Products", "usr", "local", "lib")
        end

        next unless File.directory?(frameworks_dir)

        Dir.each_child(frameworks_dir) do |entry|
          full = File.join(frameworks_dir, entry)
          if entry.end_with?(".framework")
            create_cmd.push("-framework", full)
            break
          elsif entry.end_with?(".a")
            create_cmd.push("-library", full)
            headers = File.join(archive, "Products", "usr", "local", "include")
            create_cmd.push("-headers", headers) if File.directory?(headers)
            break
          end
        end
      end

      $stderr.puts "  Creating #{framework_name}.xcframework..."
      Shell.run!(create_cmd)

      FileUtils.rm_rf(archives_dir)
      xcframework_path
    end

    # Return the best buildable scheme for the given pod in the workspace.
    #
    # Decision tree (in priority order):
    #   1. Exact match on pod_name
    #   2. Case-insensitive match on pod_name
    #   3. First scheme that is not Pods-* and not an aggregate
    #   4. Raise SchemeNotFoundError listing all available schemes
    #
    # Aggregate schemes are detected by the suffix "-Aggregate" or a scheme
    # name that is literally the workspace name (CocoaPods emits those).
    def self.discover_scheme(workspace, pod_name = nil)
      stdout, _stderr, status = Open3.capture3("xcodebuild", "-workspace", workspace, "-list")
      raise SchemeNotFoundError, "xcodebuild -list failed for workspace: #{workspace}" unless status.success?

      all_schemes = parse_schemes(stdout)
      candidates  = all_schemes.reject { |s| s.start_with?("Pods-") }

      if pod_name
        # 1. Exact match
        return pod_name if candidates.include?(pod_name)

        # 2. Case-insensitive match
        ci = candidates.find { |s| s.casecmp(pod_name).zero? }
        return ci if ci
      end

      # 3. First non-aggregate scheme
      non_aggregate = candidates.reject { |s| aggregate?(s) }
      return non_aggregate.first if non_aggregate.any?

      # 4. Fail loudly
      raise SchemeNotFoundError,
        "No buildable scheme found for '#{pod_name || "unknown"}'.\n" \
        "Available schemes: #{all_schemes.join(", ").then { |s| s.empty? ? "(none)" : s }}"
    end

    # Parse the "Schemes:" section from `xcodebuild -list` stdout.
    def self.parse_schemes(output)
      schemes    = []
      in_schemes = false

      output.each_line do |line|
        stripped = line.strip
        if stripped == "Schemes:"
          in_schemes = true
          next
        end
        if in_schemes
          break if stripped.empty?
          schemes << stripped
        end
      end

      schemes
    end

    def self.aggregate?(scheme_name)
      scheme_name.end_with?("-Aggregate") ||
        scheme_name.end_with?(" Aggregate") ||
        scheme_name == "Aggregate"
    end
    private_class_method :aggregate?
  end
end
