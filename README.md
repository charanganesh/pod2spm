# pod2spm

Convert any CocoaPod into a Swift Package Manager binary package.

pod2spm handles the full pipeline: installing the pod, extracting or building XCFrameworks, copying resource bundles, and generating a `Package.swift`. Works for pods that ship prebuilt binaries and pods that ship source only.

## Install

```bash
brew install charanganesh/tap/pod2spm
```

```bash
pip install pod2spm
```

Requires macOS, Xcode, and CocoaPods.

## Usage

### wrap

```bash
pod2spm wrap <pod-name> --version <ver> --platform <ios|tvos|macos> --output <dir>
```

```bash
# Automatically fetch and wrap the latest version
pod2spm wrap SomeSDK --platform ios --output ./SomeSDKPackage

# Pin to a specific version
pod2spm wrap SomeSDK --version 3.2.0 --platform ios --output ./SomeSDKPackage

# Pod ships source only — builds XCFramework from scratch
pod2spm wrap AnotherSDK --version 1.5.0 --platform tvos --output ./AnotherSDKPackage

# Git init + tag the output (useful for private SPM hosting)
pod2spm wrap SomeSDK --version 3.2.0 -p ios -o ./SomeSDKPackage --tag
```

| Flag | Default | Description |
|---|---|---|
| `--version`, `-v` | `latest` | Pod version to install |
| `--platform`, `-p` | `ios` | `ios`, `tvos`, or `macos` |
| `--output`, `-o` | required | Output directory |
| `--tag` | off | `git init` + commit + tag |
| `--min-ios` | `15.0` | Minimum iOS deployment target |
| `--min-tvos` | `15.0` | Minimum tvOS deployment target |
| `--min-macos` | `12.0` | Minimum macOS deployment target |

### check-versions

```bash
pod2spm check-versions ./Podfile
```

Queries CocoaPods Trunk for each pod in a Podfile and prints a comparison table against pinned versions.

## How it works

pod2spm runs `pod install` in a temporary Xcode project, then takes one of two paths.

**Prebuilt XCFrameworks:** If the pod vendors `.xcframework` bundles in `Pods/`, they're copied directly into the output. No compilation.

**Source-only pods:** `xcodebuild archive` runs for device and simulator slices, then `xcodebuild -create-xcframework` merges them.

Resource bundles are detected in both cases and included as a separate SPM resource target.

## Output

```
SomeSDKPackage/
├── Package.swift
├── SomeSDK.xcframework/
└── Resources/
    └── SomeSDKResources.bundle/
```

## SDK redistribution

This tool repackages SDK binaries. Check the SDK's license for redistribution rights before distributing the output. Consider hosting in a private repo to limit access.

## License

MIT
