# frozen_string_literal: true

require "spec_helper"

RSpec.describe Pod2SPM::CLI do
  let(:cli) { described_class.new }

  describe "#wrap" do
    it "rejects invalid platform" do
      expect {
        described_class.start(["wrap", "Alamofire", "-o", "/tmp/out", "-p", "watchos"])
      }.to raise_error(SystemExit)
    end

    it "exits when latest version cannot be resolved" do
      allow(Pod2SPM::Versions).to receive(:fetch_latest)
        .with("NonExistentPod")
        .and_raise(Pod2SPM::VersionFetchError, "HTTP 404")

      expect {
        described_class.start(["wrap", "NonExistentPod", "-o", "/tmp/out"])
      }.to raise_error(SystemExit)
    end

    it "sets Shell.verbose when --verbose is passed" do
      allow(Pod2SPM::Versions).to receive(:fetch_latest).and_return("1.0.0")
      allow(Pod2SPM::Wrap).to receive(:run)

      begin
        described_class.start(["wrap", "SomePod", "-o", "/tmp/out", "-V"])
      rescue SystemExit
        # Thor may exit; that's ok
      end

      expect(Pod2SPM::Shell.verbose).to be true
    ensure
      Pod2SPM::Shell.verbose = false
    end

    it "passes correct options to Wrap.run" do
      allow(Pod2SPM::Versions).to receive(:fetch_latest).with("Alamofire").and_return("5.9.0")
      expect(Pod2SPM::Wrap).to receive(:run).with(
        pod_name: "Alamofire",
        version: "5.9.0",
        platform: "ios",
        output_dir: "/tmp/out",
        git_tag: false,
        min_deployment_target: "15.0",
        repo_update: true,
        keep_temp: false,
        json_output: false,
      )

      described_class.start(["wrap", "Alamofire", "-o", "/tmp/out"])
    end

    it "uses explicit version instead of fetching latest" do
      expect(Pod2SPM::Versions).not_to receive(:fetch_latest)
      expect(Pod2SPM::Wrap).to receive(:run).with(hash_including(
        pod_name: "Alamofire",
        version: "5.8.0",
      ))

      described_class.start(["wrap", "Alamofire", "-o", "/tmp/out", "-v", "5.8.0"])
    end

    it "selects correct min deployment target for tvos" do
      expect(Pod2SPM::Wrap).to receive(:run).with(hash_including(
        platform: "tvos",
        min_deployment_target: "15.0",
      ))

      described_class.start(["wrap", "SomePod", "-o", "/tmp/out", "-v", "1.0", "-p", "tvos"])
    end

    it "selects correct min deployment target for macos" do
      expect(Pod2SPM::Wrap).to receive(:run).with(hash_including(
        platform: "macos",
        min_deployment_target: "12.0",
      ))

      described_class.start(["wrap", "SomePod", "-o", "/tmp/out", "-v", "1.0", "-p", "macos"])
    end
  end

  describe "#check_versions" do
    it "exits when podfile does not exist" do
      expect {
        described_class.start(["check-versions", "/nonexistent/Podfile"])
      }.to raise_error(SystemExit)
    end

    it "calls Versions.check with the podfile path" do
      Dir.mktmpdir do |tmp|
        podfile = File.join(tmp, "Podfile")
        File.write(podfile, "platform :ios, '15.0'\n")

        expect(Pod2SPM::Versions).to receive(:check).with(podfile)
        described_class.start(["check-versions", podfile])
      end
    end
  end
end
