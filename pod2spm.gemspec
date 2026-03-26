require_relative "lib/pod2spm/version"

Gem::Specification.new do |spec|
  spec.name          = "pod2spm"
  spec.version       = Pod2SPM::VERSION
  spec.authors       = ["Charan Ganesh"]
  spec.summary       = "CLI tool to wrap CocoaPods as Swift Package Manager binary packages"
  spec.description   = "Automates the full pipeline: pod install → extract/build XCFrameworks → generate Package.swift"
  spec.homepage      = "https://github.com/charanganesh/pod2spm"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.files         = Dir["lib/**/*.rb", "exe/*", "LICENSE", "README.md"]
  spec.bindir        = "exe"
  spec.executables   = ["pod2spm"]

  spec.add_dependency "thor", "~> 1.3"

  spec.add_development_dependency "rspec",   "~> 3.13"
  spec.add_development_dependency "webmock", "~> 3.23"
end
