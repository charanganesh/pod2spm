# frozen_string_literal: true

require "thor"

module Pod2SPM
  class CLI < Thor
    VALID_PLATFORMS = %w[ios tvos macos].freeze

    desc "wrap POD_NAME", "Wrap a CocoaPod as a Swift Package Manager binary package"
    method_option :version,          aliases: "-v", type: :string,  default: "latest", desc: "Pod version to install, or 'latest'"
    method_option :platform,         aliases: "-p", type: :string,  default: "ios",    desc: "Target platform: ios, tvos, or macos"
    method_option :output,           aliases: "-o", type: :string,  required: true,    desc: "Output directory for the generated SPM package"
    method_option :tag,                             type: :boolean, default: false,    desc: "Initialize a git repo and tag the output"
    method_option :"min-ios",                       type: :string,  default: "15.0",   desc: "Minimum iOS deployment target"
    method_option :"min-tvos",                      type: :string,  default: "15.0",   desc: "Minimum tvOS deployment target"
    method_option :"min-macos",                     type: :string,  default: "12.0",   desc: "Minimum macOS deployment target"
    method_option :"no-repo-update",                type: :boolean, default: false,    desc: "Skip --repo-update in pod install (faster, may use stale specs)"
    method_option :"keep-temp",                     type: :boolean, default: false,    desc: "Keep the temporary working directory (useful for debugging build failures)"
    method_option :verbose,          aliases: "-V", type: :boolean, default: false,    desc: "Print all shell commands and their output"
    method_option :json,                            type: :boolean, default: false,    desc: "Print a JSON summary of the result to stdout"
    def wrap(pod_name)
      platform = options[:platform]
      unless VALID_PLATFORMS.include?(platform)
        error("Invalid platform '#{platform}'. Must be one of: #{VALID_PLATFORMS.join(", ")}")
        exit 1
      end

      Pod2SPM::Shell.verbose = options[:verbose]

      version = options[:version]
      if version == "latest"
        puts "Fetching latest version of #{pod_name}..."
        version = Pod2SPM::Versions.fetch_latest(pod_name)
        if version.nil?
          error("Pod '#{pod_name}' has no published versions on Trunk. Use --version to specify one.")
          exit 1
        end
        puts "Latest version: #{version}"
      end

      min_deployment_target = case platform
      when "ios"   then options[:"min-ios"]
      when "tvos"  then options[:"min-tvos"]
      when "macos" then options[:"min-macos"]
      end

      Pod2SPM::Wrap.run(
        pod_name: pod_name,
        version: version,
        platform: platform,
        output_dir: options[:output],
        git_tag: options[:tag],
        min_deployment_target: min_deployment_target,
        repo_update: !options[:"no-repo-update"],
        keep_temp: options[:"keep-temp"],
        json_output: options[:json],
      )
    rescue Pod2SPM::Error => e
      error(e.message)
      exit 1
    rescue => e
      error(e.message)
      exit 1
    end

    desc "check-versions PODFILE", "Compare pinned pod versions against CocoaPods Trunk"
    def check_versions(podfile_path)
      unless File.exist?(podfile_path)
        error("Podfile not found: #{podfile_path}")
        exit 1
      end
      Pod2SPM::Versions.check(podfile_path)
    rescue Pod2SPM::Error => e
      error(e.message)
      exit 1
    rescue => e
      error(e.message)
      exit 1
    end

    private

    def error(msg)
      $stderr.puts "Error: #{msg}"
    end
  end
end
