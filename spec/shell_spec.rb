# frozen_string_literal: true

require "spec_helper"

RSpec.describe Pod2SPM::Shell do
  after { described_class.verbose = false }

  describe ".run!" do
    it "returns stdout on success" do
      result = described_class.run!(["echo", "hello"])
      expect(result.strip).to eq("hello")
    end

    it "raises CommandError on non-zero exit" do
      expect {
        described_class.run!(["false"])
      }.to raise_error(Pod2SPM::CommandError)
    end

    it "includes the command in the error" do
      expect {
        described_class.run!(["ls", "/nonexistent_path_xyz"])
      }.to raise_error(Pod2SPM::CommandError, /ls/)
    end

    it "runs in a specified directory" do
      Dir.mktmpdir do |tmp|
        result = described_class.run!(["pwd"], cwd: tmp)
        expect(result.strip).to eq(File.realpath(tmp))
      end
    end
  end
end
