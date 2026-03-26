# frozen_string_literal: true

require "spec_helper"

RSpec.describe Pod2SPM::Wrap do
  describe ".run" do
    let(:output_dir) { Dir.mktmpdir("pod2spm_test_") }

    after { FileUtils.rm_rf(output_dir) }

    def stub_pod_install_prebuilt(tmp, pod_name)
      pods_dir = File.join(tmp, "Pods")
      xcf_dir = File.join(pods_dir, pod_name, "#{pod_name}.xcframework")
      FileUtils.mkdir_p(xcf_dir)
      FileUtils.touch(File.join(xcf_dir, "Info.plist"))
    end

    def stub_pod_install_source(tmp, pod_name)
      pods_dir = File.join(tmp, "Pods")
      FileUtils.mkdir_p(File.join(pods_dir, pod_name, "Sources"))
      FileUtils.mkdir_p(File.join(tmp, "TempTarget.xcworkspace"))
    end

    it "handles the prebuilt xcframework path" do
      allow(Pod2SPM::Shell).to receive(:run!) do |cmd, **opts|
        if cmd.first == "pod"
          stub_pod_install_prebuilt(opts[:cwd], "Alamofire")
          ""
        elsif cmd.include?("dump-package")
          ""
        else
          ""
        end
      end

      result = described_class.run(
        pod_name: "Alamofire",
        version: "5.9.0",
        platform: "ios",
        output_dir: output_dir,
      )

      expect(result[:source]).to eq(:prebuilt)
      expect(result[:xcframeworks]).to include("Alamofire.xcframework")
      expect(File.directory?(File.join(output_dir, "Alamofire.xcframework"))).to be true
      expect(File.exist?(File.join(output_dir, "Package.swift"))).to be true

      pkg = File.read(File.join(output_dir, "Package.swift"))
      expect(pkg).to include('name: "Alamofire"')
      expect(pkg).to include(".binaryTarget")
    end

    it "handles the source build path" do
      xcf_output = nil

      allow(Pod2SPM::Shell).to receive(:run!) do |cmd, **opts|
        if cmd.first == "pod"
          stub_pod_install_source(opts[:cwd], "SnapKit")
          ""
        elsif cmd.include?("archive")
          ""
        elsif cmd.include?("-create-xcframework")
          xcf_output = cmd.find { |a| a.end_with?(".xcframework") }
          FileUtils.mkdir_p(xcf_output) if xcf_output
          ""
        elsif cmd.include?("dump-package")
          ""
        else
          ""
        end
      end

      allow(Pod2SPM::Build).to receive(:discover_scheme).and_return("SnapKit")
      allow(Pod2SPM::Build).to receive(:xcframework) do |workspace:, scheme:, platform:, output_dir:, framework_name:|
        xcf_path = File.join(output_dir, "#{framework_name}.xcframework")
        FileUtils.mkdir_p(xcf_path)
        xcf_path
      end

      result = described_class.run(
        pod_name: "SnapKit",
        version: "5.7.0",
        platform: "ios",
        output_dir: output_dir,
      )

      expect(result[:source]).to eq(:built)
      expect(result[:xcframeworks]).to include("SnapKit.xcframework")
    end

    it "raises WorkspaceNotFoundError when workspace is missing for source pods" do
      allow(Pod2SPM::Shell).to receive(:run!) do |cmd, **opts|
        if cmd.first == "pod"
          pods_dir = File.join(opts[:cwd], "Pods")
          FileUtils.mkdir_p(File.join(pods_dir, "SomePod", "Sources"))
          ""
        else
          ""
        end
      end

      expect {
        described_class.run(
          pod_name: "SomePod",
          version: "1.0.0",
          platform: "ios",
          output_dir: output_dir,
        )
      }.to raise_error(Pod2SPM::WorkspaceNotFoundError)
    end

    it "normalizes subspec names" do
      allow(Pod2SPM::Shell).to receive(:run!) do |cmd, **opts|
        if cmd.first == "pod"
          stub_pod_install_prebuilt(opts[:cwd], "Firebase")
          ""
        elsif cmd.include?("dump-package")
          ""
        else
          ""
        end
      end

      result = described_class.run(
        pod_name: "Firebase/Analytics",
        version: "11.0.0",
        platform: "ios",
        output_dir: output_dir,
      )

      expect(result[:source]).to eq(:prebuilt)
      pkg = File.read(File.join(output_dir, "Package.swift"))
      expect(pkg).to include('name: "Firebase"')
      expect(pkg).not_to include("Firebase/Analytics")
    end

    it "copies resource bundles" do
      allow(Pod2SPM::Shell).to receive(:run!) do |cmd, **opts|
        if cmd.first == "pod"
          pods_dir = File.join(opts[:cwd], "Pods")
          xcf = File.join(pods_dir, "GoogleAds", "GoogleMobileAds.xcframework")
          FileUtils.mkdir_p(xcf)
          bundle = File.join(pods_dir, "GoogleAds", "GoogleMobileAdsResources.bundle")
          FileUtils.mkdir_p(bundle)
          FileUtils.touch(File.join(bundle, "PrivacyInfo.xcprivacy"))
          ""
        elsif cmd.include?("dump-package")
          ""
        else
          ""
        end
      end

      result = described_class.run(
        pod_name: "GoogleAds",
        version: "12.0.0",
        platform: "ios",
        output_dir: output_dir,
      )

      expect(result[:resource_bundles]).to include("GoogleMobileAdsResources.bundle")
      expect(File.directory?(File.join(output_dir, "Resources", "GoogleMobileAdsResources.bundle"))).to be true
    end

    it "warns about plain .framework vendored binaries" do
      allow(Pod2SPM::Shell).to receive(:run!) do |cmd, **opts|
        if cmd.first == "pod"
          pods_dir = File.join(opts[:cwd], "Pods")
          FileUtils.mkdir_p(File.join(pods_dir, "OldSDK", "OldSDK.framework"))
          FileUtils.mkdir_p(File.join(pods_dir, "OldSDK", "Sources"))
          FileUtils.mkdir_p(File.join(opts[:cwd], "TempTarget.xcworkspace"))
          ""
        elsif cmd.include?("dump-package")
          ""
        else
          ""
        end
      end

      allow(Pod2SPM::Build).to receive(:discover_scheme).and_return("OldSDK")
      allow(Pod2SPM::Build).to receive(:xcframework) do |**kwargs|
        xcf_path = File.join(kwargs[:output_dir], "#{kwargs[:framework_name]}.xcframework")
        FileUtils.mkdir_p(xcf_path)
        xcf_path
      end

      expect {
        described_class.run(
          pod_name: "OldSDK",
          version: "1.0.0",
          platform: "ios",
          output_dir: output_dir,
        )
      }.to output(/plain .framework/).to_stderr
    end

    it "produces valid JSON output when --json is used" do
      allow(Pod2SPM::Shell).to receive(:run!) do |cmd, **opts|
        if cmd.first == "pod"
          stub_pod_install_prebuilt(opts[:cwd], "Alamofire")
          ""
        elsif cmd.include?("dump-package")
          ""
        else
          ""
        end
      end

      output = capture_stdout do
        described_class.run(
          pod_name: "Alamofire",
          version: "5.9.0",
          platform: "ios",
          output_dir: output_dir,
          json_output: true,
        )
      end

      # With all progress on $stderr, stdout contains only the JSON
      parsed = JSON.parse(output.strip)
      expect(parsed["pod"]).to eq("Alamofire")
      expect(parsed["version"]).to eq("5.9.0")
    end
  end

  private

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
