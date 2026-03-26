# frozen_string_literal: true

require "spec_helper"

RSpec.describe Pod2SPM::Detect do
  describe ".scan" do
    it "detects prebuilt xcframeworks scoped to the pod directory" do
      Dir.mktmpdir do |tmp|
        pods_dir = File.join(tmp, "Pods")
        xcf = File.join(pods_dir, "GoogleAds", "GoogleMobileAds.xcframework")
        FileUtils.mkdir_p(xcf)
        FileUtils.touch(File.join(xcf, "Info.plist"))

        result = described_class.scan(pods_dir, "GoogleAds")

        expect(result.prebuilt?).to be true
        expect(result.xcframeworks.length).to eq(1)
        expect(File.basename(result.xcframeworks.first)).to eq("GoogleMobileAds.xcframework")
      end
    end

    it "excludes xcframeworks from other pods" do
      Dir.mktmpdir do |tmp|
        pods_dir = File.join(tmp, "Pods")
        FileUtils.mkdir_p(File.join(pods_dir, "GoogleAds", "GoogleMobileAds.xcframework"))
        FileUtils.mkdir_p(File.join(pods_dir, "OtherPod", "OtherPod.xcframework"))

        result = described_class.scan(pods_dir, "GoogleAds")

        expect(result.xcframeworks.length).to eq(1)
        expect(File.basename(result.xcframeworks.first)).to eq("GoogleMobileAds.xcframework")
      end
    end

    it "falls back to full Pods/ scan when pod directory does not exist" do
      Dir.mktmpdir do |tmp|
        pods_dir = File.join(tmp, "Pods")
        FileUtils.mkdir_p(File.join(pods_dir, "SomeDir", "MyPod.xcframework"))

        result = described_class.scan(pods_dir, "NonExistentPod")

        expect(result.prebuilt?).to be true
        expect(result.xcframeworks.length).to eq(1)
      end
    end

    it "detects resource bundles" do
      Dir.mktmpdir do |tmp|
        pods_dir = File.join(tmp, "Pods")
        bundle = File.join(pods_dir, "GoogleAds", "GoogleMobileAdsResources.bundle")
        FileUtils.mkdir_p(bundle)
        FileUtils.touch(File.join(bundle, "PrivacyInfo.xcprivacy"))

        result = described_class.scan(pods_dir, "GoogleAds")

        expect(result.resource_bundles.length).to eq(1)
      end
    end

    it "detects plain .framework vendored binaries" do
      Dir.mktmpdir do |tmp|
        pods_dir = File.join(tmp, "Pods")
        fw = File.join(pods_dir, "SomePod", "SomePod.framework")
        FileUtils.mkdir_p(fw)

        result = described_class.scan(pods_dir, "SomePod")

        expect(result.vendored_frameworks.length).to eq(1)
        expect(File.basename(result.vendored_frameworks.first)).to eq("SomePod.framework")
      end
    end

    it "does not count .framework inside .xcframework as vendored" do
      Dir.mktmpdir do |tmp|
        pods_dir = File.join(tmp, "Pods")
        nested = File.join(pods_dir, "Pod", "Pod.xcframework", "ios-arm64", "Pod.framework")
        FileUtils.mkdir_p(nested)

        result = described_class.scan(pods_dir, "Pod")

        expect(result.prebuilt?).to be true
        expect(result.vendored_frameworks).to be_empty
      end
    end

    it "returns not prebuilt for source-only pods" do
      Dir.mktmpdir do |tmp|
        pods_dir = File.join(tmp, "Pods")
        FileUtils.mkdir_p(File.join(pods_dir, "SomePod", "Sources"))

        result = described_class.scan(pods_dir, "SomePod")

        expect(result.prebuilt?).to be false
      end
    end

    it "ignores xcframeworks inside Target Support Files" do
      Dir.mktmpdir do |tmp|
        pods_dir = File.join(tmp, "Pods")
        xcf = File.join(pods_dir, "Target Support Files", "Something.xcframework")
        FileUtils.mkdir_p(xcf)

        result = described_class.scan(pods_dir, "Something")

        expect(result.prebuilt?).to be false
      end
    end

    it "returns empty result when Pods dir does not exist" do
      result = described_class.scan("/nonexistent/Pods", "Something")
      expect(result.prebuilt?).to be false
      expect(result.resource_bundles).to be_empty
    end

    it "returns sorted results for deterministic output" do
      Dir.mktmpdir do |tmp|
        pods_dir = File.join(tmp, "Pods")
        FileUtils.mkdir_p(File.join(pods_dir, "MyPod", "Bravo.xcframework"))
        FileUtils.mkdir_p(File.join(pods_dir, "MyPod", "Alpha.xcframework"))

        result = described_class.scan(pods_dir, "MyPod")

        basenames = result.xcframeworks.map { |p| File.basename(p) }
        expect(basenames).to eq(["Alpha.xcframework", "Bravo.xcframework"])
      end
    end
  end
end
