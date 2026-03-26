# frozen_string_literal: true

module Pod2SPM
  # Base error for all pod2spm failures.
  class Error < StandardError; end

  # A shell command exited with a non-zero status.
  class CommandError < Error
    attr_reader :cmd, :stderr

    def initialize(cmd, stderr = nil)
      @cmd    = cmd
      @stderr = stderr
      super("Command failed: #{cmd.first(3).join(" ")}..." + (stderr && !stderr.empty? ? "\n#{stderr}" : ""))
    end
  end

  # xcodebuild -list returned no usable scheme.
  class SchemeNotFoundError < Error; end

  # pod install did not produce a .xcworkspace.
  class WorkspaceNotFoundError < Error; end

  # CocoaPods Trunk API could not resolve a version.
  class VersionFetchError < Error; end
end
