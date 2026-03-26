# frozen_string_literal: true

require "spec_helper"

RSpec.describe Pod2SPM::Podfile do
  describe ".generate" do
    it "writes a valid Podfile for a single pod" do
      Dir.mktmpdir do |tmp|
        path = described_class.generate("GoogleAds", "12.0.0", "ios", "15.0", tmp)
        content = File.read(path)

        expect(content).to include("platform :ios, '15.0'")
        expect(content).to include("pod 'GoogleAds', '12.0.0'")
        expect(content).to include("use_frameworks!")
      end
    end
  end

  describe ".parse" do
    it "parses exact versions, version specs, and unpinned pods" do
      Dir.mktmpdir do |tmp|
        podfile = File.join(tmp, "Podfile")
        File.write(podfile, <<~PODFILE)
          platform :ios, '15.0'
          target 'App' do
            pod 'GoogleAds', '12.0.0'
            pod 'CleverTap', '~> 7.3'
            pod 'SomePod'
          end
        PODFILE

        result = described_class.parse(podfile)

        expect(result).to eq([
          ["GoogleAds", "12.0.0"],
          ["CleverTap", "7.3"],
          ["SomePod", nil],
        ])
      end
    end

    it "returns empty array for a Podfile with no pods" do
      Dir.mktmpdir do |tmp|
        podfile = File.join(tmp, "Podfile")
        File.write(podfile, "platform :ios, '15.0'\ntarget 'App' do\nend\n")

        expect(described_class.parse(podfile)).to eq([])
      end
    end

    it "handles double-quoted pod declarations" do
      Dir.mktmpdir do |tmp|
        podfile = File.join(tmp, "Podfile")
        File.write(podfile, 'pod "Alamofire", "5.9.0"')

        result = described_class.parse(podfile)
        expect(result).to eq([["Alamofire", "5.9.0"]])
      end
    end

    it "strips >= and other operators" do
      Dir.mktmpdir do |tmp|
        podfile = File.join(tmp, "Podfile")
        File.write(podfile, "pod 'SomePod', '>= 2.0'")

        result = described_class.parse(podfile)
        expect(result).to eq([["SomePod", "2.0"]])
      end
    end
  end
end
