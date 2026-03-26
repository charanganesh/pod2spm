# frozen_string_literal: true

require "spec_helper"

RSpec.describe Pod2SPM::Build do
  describe ".parse_schemes" do
    it "extracts scheme names from xcodebuild -list output" do
      output = <<~OUTPUT
        Information about workspace "TempTarget":
            Schemes:
                Pods-TempTarget
                Alamofire
                AlamofireImage

      OUTPUT
      expect(described_class.parse_schemes(output)).to eq(["Pods-TempTarget", "Alamofire", "AlamofireImage"])
    end

    it "returns empty array when there are no schemes" do
      expect(described_class.parse_schemes("Information about workspace:\n")).to eq([])
    end
  end

  describe ".discover_scheme" do
    def stub_xcodebuild(workspace, schemes)
      scheme_lines = schemes.map { |s| "        #{s}" }.join("\n")
      output = "Information about workspace:\n    Schemes:\n#{scheme_lines}\n\n"
      allow(Open3).to receive(:capture3)
        .with("xcodebuild", "-workspace", workspace, "-list")
        .and_return([output, "", double(success?: true)])
    end

    it "returns exact pod-name match first" do
      stub_xcodebuild("/tmp/w.xcworkspace", ["Pods-TempTarget", "Alamofire", "AlamofireImage"])
      expect(described_class.discover_scheme("/tmp/w.xcworkspace", "Alamofire")).to eq("Alamofire")
    end

    it "falls back to case-insensitive match" do
      stub_xcodebuild("/tmp/w.xcworkspace", ["Pods-TempTarget", "alamofire"])
      expect(described_class.discover_scheme("/tmp/w.xcworkspace", "Alamofire")).to eq("alamofire")
    end

    it "falls back to first non-Pods, non-aggregate scheme" do
      stub_xcodebuild("/tmp/w.xcworkspace", ["Pods-TempTarget", "SomeOtherScheme-Aggregate", "GoogleMobileAds"])
      expect(described_class.discover_scheme("/tmp/w.xcworkspace", "UnknownPod")).to eq("GoogleMobileAds")
    end

    it "raises SchemeNotFoundError when no usable scheme exists" do
      stub_xcodebuild("/tmp/w.xcworkspace", ["Pods-TempTarget"])
      expect {
        described_class.discover_scheme("/tmp/w.xcworkspace", "SomePod")
      }.to raise_error(Pod2SPM::SchemeNotFoundError, /No buildable scheme found/)
    end

    it "lists available schemes in the error message" do
      stub_xcodebuild("/tmp/w.xcworkspace", ["Pods-TempTarget", "Pods-App"])
      expect {
        described_class.discover_scheme("/tmp/w.xcworkspace", "SomePod")
      }.to raise_error(Pod2SPM::SchemeNotFoundError, /Pods-TempTarget/)
    end

    it "raises SchemeNotFoundError when xcodebuild fails" do
      allow(Open3).to receive(:capture3)
        .with("xcodebuild", "-workspace", "/bad.xcworkspace", "-list")
        .and_return(["", "error", double(success?: false)])
      expect {
        described_class.discover_scheme("/bad.xcworkspace", "SomePod")
      }.to raise_error(Pod2SPM::SchemeNotFoundError)
    end

    it "works without a pod_name hint" do
      stub_xcodebuild("/tmp/w.xcworkspace", ["Pods-TempTarget", "MyFramework"])
      expect(described_class.discover_scheme("/tmp/w.xcworkspace")).to eq("MyFramework")
    end
  end
end
