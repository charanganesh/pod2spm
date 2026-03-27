# frozen_string_literal: true

module Pod2SPM
  module UI
    # ANSI codes — only emitted when stderr is a TTY
    RESET   = "\e[0m"
    BOLD    = "\e[1m"
    DIM     = "\e[2m"
    RED     = "\e[31m"
    GREEN   = "\e[32m"
    YELLOW  = "\e[33m"
    CYAN    = "\e[36m"
    GRAY    = "\e[90m"

    BANNER_ART = [
      "██████╗  ██████╗ ██████╗ ██████╗ ███████╗██████╗ ███╗   ███╗",
      "██╔══██╗██╔═══██╗██╔══██╗╚════██╗██╔════╝██╔══██╗████╗ ████║",
      "██████╔╝██║   ██║██║  ██║ █████╔╝███████╗██████╔╝██╔████╔██║",
      "██╔═══╝ ██║   ██║██║  ██║██╔═══╝ ╚════██║██╔═══╝ ██║╚██╔╝██║",
      "██║     ╚██████╔╝██████╔╝███████╗███████║██║     ██║ ╚═╝ ██║",
      "╚═╝      ╚═════╝ ╚═════╝ ╚══════╝╚══════╝╚═╝     ╚═╝     ╚═╝",
    ].freeze

    def self.tty?
      $stderr.isatty
    end

    def self.c(code, text)
      tty? ? "#{code}#{text}#{RESET}" : text
    end

    def self.banner
      $stderr.puts
      BANNER_ART.each { |line| $stderr.puts c(CYAN + BOLD, "  #{line}") }
      $stderr.puts c(GRAY, "  CocoaPods → Swift Package Manager  ·  v#{Pod2SPM::VERSION}")
      $stderr.puts c(GRAY, "  " + "─" * 63)
      $stderr.puts
    end

    def self.step(number, label)
      $stderr.puts "  #{c(CYAN + BOLD, "◆ Step #{number}")}  #{c(BOLD, label)}"
    end

    def self.substep(label)
      $stderr.puts "    #{c(GRAY, "›")} #{label}"
    end

    def self.success(label)
      $stderr.puts "    #{c(GREEN, "✓")} #{label}"
    end

    def self.warn(label)
      $stderr.puts "    #{c(YELLOW, "⚠")} #{label}"
    end

    def self.info(label)
      $stderr.puts "    #{c(GRAY, "·")} #{label}"
    end

    def self.working_in(path)
      $stderr.puts c(GRAY, "  Working in #{path}")
      $stderr.puts
    end

    def self.fetching_version(pod_name)
      $stderr.puts "  #{c(GRAY, "◇")} Resolving #{c(BOLD, pod_name)}#{c(GRAY, "...")} "
    end

    def self.resolved_version(version)
      $stderr.puts "  #{c(GREEN, "✓")} Latest: #{c(BOLD, version)}"
      $stderr.puts
    end

    def self.done(output_dir)
      $stderr.puts
      $stderr.puts "  #{c(GREEN + BOLD, "✓ Done!")}"
      $stderr.puts "  #{c(GRAY, "Output:")} #{c(BOLD, output_dir)}"
      $stderr.puts
    end

    def self.error(msg)
      $stderr.puts
      $stderr.puts "  #{c(RED + BOLD, "✗ Error:")} #{msg}"
      $stderr.puts
    end
  end
end
