# frozen_string_literal: true

require "spec_helper"

RSpec.describe Pod2SPM::Versions do
  describe ".fetch_latest" do
    it "returns the latest version from CocoaPods Trunk API" do
      stub_request(:get, "https://trunk.cocoapods.org/api/v1/pods/Alamofire")
        .to_return(
          status: 200,
          body: JSON.generate({ "versions" => [{ "name" => "5.8.0" }, { "name" => "5.9.0" }] }),
          headers: { "Content-Type" => "application/json" },
        )

      expect(described_class.fetch_latest("Alamofire")).to eq("5.9.0")
    end

    it "raises VersionFetchError when pod is not found (404)" do
      stub_request(:get, "https://trunk.cocoapods.org/api/v1/pods/NonExistentPod99")
        .to_return(status: 404, body: "")

      expect {
        described_class.fetch_latest("NonExistentPod99")
      }.to raise_error(Pod2SPM::VersionFetchError, /HTTP 404/)
    end

    it "raises VersionFetchError on network error" do
      stub_request(:get, "https://trunk.cocoapods.org/api/v1/pods/SomePod")
        .to_raise(SocketError.new("getaddrinfo: Name or service not known"))

      expect {
        described_class.fetch_latest("SomePod")
      }.to raise_error(Pod2SPM::VersionFetchError, /Network error/)
    end

    it "raises VersionFetchError on invalid JSON" do
      stub_request(:get, "https://trunk.cocoapods.org/api/v1/pods/BadJson")
        .to_return(
          status: 200,
          body: "not json at all",
          headers: { "Content-Type" => "application/json" },
        )

      expect {
        described_class.fetch_latest("BadJson")
      }.to raise_error(Pod2SPM::VersionFetchError, /Invalid JSON/)
    end

    it "returns nil when versions array is empty" do
      stub_request(:get, "https://trunk.cocoapods.org/api/v1/pods/EmptyPod")
        .to_return(
          status: 200,
          body: JSON.generate({ "versions" => [] }),
          headers: { "Content-Type" => "application/json" },
        )

      expect(described_class.fetch_latest("EmptyPod")).to be_nil
    end

    it "raises VersionFetchError on connection timeout" do
      stub_request(:get, "https://trunk.cocoapods.org/api/v1/pods/SlowPod")
        .to_raise(Net::ReadTimeout.new("Net::ReadTimeout"))

      expect {
        described_class.fetch_latest("SlowPod")
      }.to raise_error(Pod2SPM::VersionFetchError, /Network error/)
    end
  end

  describe ".check" do
    it "prints unknown status for a pod that returns 404 without crashing" do
      Dir.mktmpdir do |tmp|
        podfile = File.join(tmp, "Podfile")
        File.write(podfile, "pod 'Missing', '1.0.0'\npod 'Alamofire', '5.9.0'")

        stub_request(:get, "https://trunk.cocoapods.org/api/v1/pods/Missing")
          .to_return(status: 404, body: "")
        stub_request(:get, "https://trunk.cocoapods.org/api/v1/pods/Alamofire")
          .to_return(
            status: 200,
            body: JSON.generate({ "versions" => [{ "name" => "5.9.0" }] }),
            headers: { "Content-Type" => "application/json" },
          )

        # Should not raise — 404 for one pod must not crash the whole command
        expect { described_class.check(podfile) }.not_to raise_error
      end
    end

    it "prints unknown status when network is down without crashing" do
      Dir.mktmpdir do |tmp|
        podfile = File.join(tmp, "Podfile")
        File.write(podfile, "pod 'SomePod', '1.0.0'")

        stub_request(:get, "https://trunk.cocoapods.org/api/v1/pods/SomePod")
          .to_raise(SocketError.new("connection refused"))

        expect { described_class.check(podfile) }.not_to raise_error
      end
    end
  end
end
