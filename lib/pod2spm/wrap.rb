# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "json"

module Pod2SPM
  module Wrap
    SDK_ROOT = {
      "ios"   => "iphoneos",
      "tvos"  => "appletvos",
      "macos" => "macosx",
    }.freeze

    # Execute the full wrap pipeline.
    #
    # Options:
    #   git_tag:              bool   — init git repo and tag the output
    #   min_deployment_target: str   — e.g. "15.0"
    #   repo_update:          bool   — pass --repo-update to pod install (default true)
    #   keep_temp:            bool   — do not delete the tmpdir (useful for debugging)
    #   json_output:          bool   — print a JSON result summary at the end
    def self.run(
      pod_name:,
      version:,
      platform:,
      output_dir:,
      git_tag: false,
      min_deployment_target: "15.0",
      repo_update: true,
      keep_temp: false,
      json_output: false
    )
      output_dir = File.expand_path(output_dir)
      FileUtils.mkdir_p(output_dir)

      # Subspecs (e.g. "Firebase/Analytics") keep the full name for CocoaPods
      # but use the base name for framework naming, detection, and Package.swift.
      base_pod_name = pod_name.split("/").first
      framework_name = base_pod_name.gsub("-", "")

      if base_pod_name != pod_name
        $stderr.puts "Subspec detected: using '#{base_pod_name}' as the package name"
      end

      result = {}

      work_proc = lambda do |tmp|
        $stderr.puts "Working in #{tmp}\n"

        # Step 1: Create temp Xcode project + Podfile
        $stderr.puts "Step 1: Creating temp project and Podfile"
        create_temp_xcode_project(tmp, platform)
        Pod2SPM::Podfile.generate(pod_name, version, platform, min_deployment_target, tmp)

        # Step 2: pod install
        $stderr.puts "\nStep 2: Running pod install"
        pod_install_cmd = ["pod", "install"]
        pod_install_cmd << "--repo-update" if repo_update
        Shell.run!(pod_install_cmd, cwd: tmp)

        pods_dir = File.join(tmp, "Pods")

        # Step 3: Detect case
        $stderr.puts "\nStep 3: Scanning for prebuilt XCFrameworks"
        detection = Pod2SPM::Detect.scan(pods_dir, base_pod_name)

        unless detection.vendored_frameworks.empty?
          $stderr.puts "  Warning: found #{detection.vendored_frameworks.length} plain .framework bundle(s) " \
            "(not .xcframework). These are not supported and will be skipped:"
          detection.vendored_frameworks.each { |f| $stderr.puts "    - #{File.basename(f)}" }
        end

        xcframework_names = []

        if detection.prebuilt?
          $stderr.puts "  Found #{detection.xcframeworks.length} prebuilt XCFramework(s)"
          result[:source] = :prebuilt
          detection.xcframeworks.each do |xcf|
            name = File.basename(xcf)
            dest = File.join(output_dir, name)
            FileUtils.rm_rf(dest)
            FileUtils.cp_r(xcf, dest)
            xcframework_names << name
            $stderr.puts "  Copied #{name}"
          end
        else
          $stderr.puts "  No prebuilt XCFrameworks — building from source"
          result[:source] = :built
          workspace = File.join(tmp, "TempTarget.xcworkspace")
          raise WorkspaceNotFoundError, "pod install did not create a .xcworkspace" unless File.directory?(workspace)

          scheme = Pod2SPM::Build.discover_scheme(workspace, base_pod_name)
          $stderr.puts "  Using scheme: #{scheme}"

          xcf_path = Pod2SPM::Build.xcframework(
            workspace: workspace,
            scheme: scheme,
            platform: platform,
            output_dir: output_dir,
            framework_name: framework_name,
          )
          xcframework_names << File.basename(xcf_path)
        end

        # Step 4: Copy resource bundles
        bundle_names = []
        if detection.resource_bundles.empty?
          $stderr.puts "\nStep 4: No resource bundles found"
        else
          $stderr.puts "\nStep 4: Copying #{detection.resource_bundles.length} resource bundle(s)"
          resources_dir = File.join(output_dir, "Resources")
          FileUtils.mkdir_p(resources_dir)
          detection.resource_bundles.each do |bundle|
            name = File.basename(bundle)
            dest = File.join(resources_dir, name)
            FileUtils.rm_rf(dest)
            FileUtils.cp_r(bundle, dest)
            bundle_names << name
            $stderr.puts "  Copied #{name}"
          end
        end

        # Step 5: Generate Package.swift
        $stderr.puts "\nStep 5: Generating Package.swift"
        pkg_path = Pod2SPM::PackageGen.generate(
          package_name: base_pod_name,
          xcframeworks: xcframework_names,
          resource_bundles: bundle_names,
          platform: platform,
          min_deployment_target: min_deployment_target,
          output_dir: output_dir,
        )
        $stderr.puts "  Written to #{pkg_path}"

        result.merge!(
          pod: pod_name,
          version: version,
          platform: platform,
          xcframeworks: xcframework_names,
          resource_bundles: bundle_names,
          output_dir: output_dir,
        )
      end

      if keep_temp
        tmp = Dir.mktmpdir("pod2spm_")
        $stderr.puts "(--keep-temp) Working directory: #{tmp}"
        work_proc.call(tmp)
      else
        Dir.mktmpdir("pod2spm_") { |tmp| work_proc.call(tmp) }
      end

      validate_package_swift(output_dir)

      # Step 6: Optionally git init + tag
      if git_tag
        $stderr.puts "\nStep 6: Initializing git repo and tagging"
        Shell.run!(["git", "init"], cwd: output_dir)
        Shell.run!(["git", "add", "."], cwd: output_dir)
        Shell.run!(["git", "commit", "-m", "pod2spm: wrap #{pod_name} #{version}"], cwd: output_dir)
        Shell.run!(["git", "tag", version], cwd: output_dir)
        $stderr.puts "  Tagged as #{version}"
        result[:git_tag] = version
      end

      $stderr.puts "\nDone! Output at #{output_dir}"

      if json_output
        puts JSON.pretty_generate(result.transform_keys(&:to_s))
      end

      result
    end

    def self.create_temp_xcode_project(work_dir, platform)
      proj_dir = File.join(work_dir, "TempTarget.xcodeproj")
      FileUtils.mkdir_p(proj_dir)
      File.write(File.join(proj_dir, "project.pbxproj"), minimal_pbxproj(platform))
    end
    private_class_method :create_temp_xcode_project

    def self.minimal_pbxproj(platform)
      sdk_root = SDK_ROOT.fetch(platform)

      <<~PBXPROJ
        // !$*UTF8*$!
        {
            archiveVersion = 1;
            classes = {};
            objectVersion = 56;
            objects = {
                00000000000000000000001 /* Project object */ = {
                    isa = PBXProject;
                    buildConfigurationList = 00000000000000000000004;
                    compatibilityVersion = "Xcode 14.0";
                    mainGroup = 00000000000000000000002;
                    productRefGroup = 00000000000000000000003;
                    projectDirPath = "";
                    projectRoot = "";
                    targets = (00000000000000000000010);
                };
                00000000000000000000002 /* Main Group */ = {
                    isa = PBXGroup;
                    children = ();
                    sourceTree = "<group>";
                };
                00000000000000000000003 /* Products */ = {
                    isa = PBXGroup;
                    children = ();
                    name = Products;
                    sourceTree = "<group>";
                };
                00000000000000000000004 /* Build configuration list for PBXProject */ = {
                    isa = XCConfigurationList;
                    buildConfigurations = (00000000000000000000005);
                    defaultConfigurationIsVisible = 0;
                    defaultConfigurationName = Release;
                };
                00000000000000000000005 /* Release */ = {
                    isa = XCBuildConfiguration;
                    buildSettings = {
                        SDKROOT = #{sdk_root};
                    };
                    name = Release;
                };
                00000000000000000000010 /* TempTarget */ = {
                    isa = PBXNativeTarget;
                    buildConfigurationList = 00000000000000000000011;
                    buildPhases = ();
                    buildRules = ();
                    dependencies = ();
                    name = TempTarget;
                    productName = TempTarget;
                    productType = "com.apple.product-type.framework";
                };
                00000000000000000000011 /* Build configuration list for target */ = {
                    isa = XCConfigurationList;
                    buildConfigurations = (00000000000000000000012);
                    defaultConfigurationIsVisible = 0;
                    defaultConfigurationName = Release;
                };
                00000000000000000000012 /* Release */ = {
                    isa = XCBuildConfiguration;
                    buildSettings = {
                        PRODUCT_NAME = "$(TARGET_NAME)";
                        SDKROOT = #{sdk_root};
                    };
                    name = Release;
                };
            };
            rootObject = 00000000000000000000001;
        }
      PBXPROJ
    end
    private_class_method :minimal_pbxproj

    def self.validate_package_swift(output_dir)
      pkg_file = File.join(output_dir, "Package.swift")
      return unless File.exist?(pkg_file)

      $stderr.puts "\nValidating Package.swift..."
      Shell.run!(["swift", "package", "dump-package"], cwd: output_dir)
      $stderr.puts "  Package.swift is valid"
    rescue Pod2SPM::CommandError => e
      $stderr.puts "  Warning: Package.swift validation failed. The file may have syntax errors."
      $stderr.puts "  #{e.stderr}" if e.stderr && !e.stderr.empty?
    end
    private_class_method :validate_package_swift
  end
end
