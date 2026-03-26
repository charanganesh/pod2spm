# frozen_string_literal: true

require "open3"

module Pod2SPM
  # Thin wrapper around Open3 used across all modules.
  #
  # Usage:
  #   Pod2SPM::Shell.run!(["pod", "install"], cwd: work_dir)
  #
  # Set Shell.verbose = true to echo every command and its stdout.
  module Shell
    @verbose = false

    class << self
      attr_accessor :verbose
    end

    # Run a command, raising CommandError on failure.
    # Returns captured stdout on success.
    def self.run!(cmd, cwd: nil)
      $stderr.puts "  $ #{cmd.join(" ")}" if verbose

      opts = cwd ? { chdir: cwd } : {}
      stdout, stderr, status = Open3.capture3(*cmd, opts)

      if verbose && !stdout.empty?
        stdout.each_line { |l| $stderr.puts "    #{l}" }
      end

      return stdout if status.success?

      raise Pod2SPM::CommandError.new(cmd, stderr)
    end
  end
end
