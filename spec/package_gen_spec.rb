# frozen_string_literal: true

require "spec_helper"

RSpec.describe Pod2SPM::PackageGen do
  describe ".generate" do
    it "generates a basic Package.swift for a single xcframework" do
      Dir.mktmpdir do |tmp|
        path = described_class.generate(
          package_name: "GoogleAds",
          xcframeworks: ["GoogleMobileAds.xcframework"],
          resource_bundles: [],
          platform: "ios",
          min_deployment_target: "15.0",
          output_dir: tmp,
        )
        content = File.read(path)

        expect(content).to include('name: "GoogleAds"')
        expect(content).to include(".binaryTarget")
        expect(content).to include('path: "GoogleMobileAds.xcframework"')
        expect(content).to include(".iOS")
      end
    end

    it "includes resource bundle target when bundles are present" do
      Dir.mktmpdir do |tmp|
        path = described_class.generate(
          package_name: "GoogleAds",
          xcframeworks: ["GoogleMobileAds.xcframework"],
          resource_bundles: ["GoogleMobileAdsResources.bundle"],
          platform: "ios",
          min_deployment_target: "15.0",
          output_dir: tmp,
        )
        content = File.read(path)

        expect(content).to include("GoogleAdsResources")
        expect(content).to include(".copy(")
        expect(content).to include("GoogleMobileAdsResources.bundle")
      end
    end

    it "uses .tvOS platform for tvos" do
      Dir.mktmpdir do |tmp|
        path = described_class.generate(
          package_name: "CleverTap",
          xcframeworks: ["CleverTapSDK.xcframework"],
          resource_bundles: [],
          platform: "tvos",
          min_deployment_target: "15.0",
          output_dir: tmp,
        )
        content = File.read(path)

        expect(content).to include(".tvOS")
      end
    end

    it "handles multiple xcframeworks" do
      Dir.mktmpdir do |tmp|
        path = described_class.generate(
          package_name: "Ads",
          xcframeworks: ["GoogleMobileAds.xcframework", "UserMessagingPlatform.xcframework"],
          resource_bundles: [],
          platform: "ios",
          min_deployment_target: "15.0",
          output_dir: tmp,
        )
        content = File.read(path)

        expect(content).to include("GoogleMobileAds")
        expect(content).to include("UserMessagingPlatform")
        expect(content).to include('"GoogleMobileAds"')
        expect(content).to include('"UserMessagingPlatform"')
      end
    end

    it "uses .macOS platform for macos" do
      Dir.mktmpdir do |tmp|
        path = described_class.generate(
          package_name: "SomeMacPod",
          xcframeworks: ["SomeMacPod.xcframework"],
          resource_bundles: [],
          platform: "macos",
          min_deployment_target: "12.0",
          output_dir: tmp,
        )
        content = File.read(path)

        expect(content).to include(".macOS")
      end
    end
  end
end
