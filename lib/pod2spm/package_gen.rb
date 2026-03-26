# frozen_string_literal: true

module Pod2SPM
  module PackageGen
    PLATFORM_MAP = {
      "ios"   => ".iOS",
      "tvos"  => ".tvOS",
      "macos" => ".macOS",
    }.freeze

    # Generate Package.swift in output_dir. Returns the path.
    def self.generate(package_name:, xcframeworks:, resource_bundles:, platform:, min_deployment_target:, output_dir:)
      swift_platform = PLATFORM_MAP.fetch(platform)

      targets      = []
      target_names = []

      xcframeworks.each do |xcf|
        name = xcf.sub(".xcframework", "")
        target_names << name
        targets << <<~TARGET.chomp
                  .binaryTarget(
                      name: "#{name}",
                      path: "#{xcf}"
                  )
        TARGET
      end

      unless resource_bundles.empty?
        res_name = "#{package_name}Resources"
        target_names << res_name
        resource_lines = resource_bundles.map { |b| "                .copy(\"#{b}\")" }.join(",\n")
        targets << <<~TARGET.chomp
                  .target(
                      name: "#{res_name}",
                      path: "Resources",
                      resources: [
          #{resource_lines}
                      ]
                  )
        TARGET
      end

      targets_block = targets.join(",\n")
      target_refs   = target_names.map { |t| "\"#{t}\"" }.join(", ")

      content = <<~SWIFT
        // swift-tools-version: 5.9
        import PackageDescription

        let package = Package(
            name: "#{package_name}",
            platforms: [
                #{swift_platform}("#{min_deployment_target}")
            ],
            products: [
                .library(
                    name: "#{package_name}",
                    targets: [#{target_refs}]
                )
            ],
            targets: [
        #{targets_block}
            ]
        )
      SWIFT

      path = File.join(output_dir, "Package.swift")
      File.write(path, content)
      path
    end
  end
end
