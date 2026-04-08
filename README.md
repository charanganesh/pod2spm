[![pod2spm](https://www.charan.sh/images/pod2spm-cover.jpg)](https://www.charan.sh/blog/pod2spm)

Convert any CocoaPod into a Swift Package Manager binary package.

pod2spm handles the full pipeline: installing the pod, extracting or building XCFrameworks, copying resource bundles, and generating a `Package.swift`. Works for pods that ship prebuilt binaries and pods that ship source only.

## Install

```bash
brew install charanganesh/tap/pod2spm
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

# Wrap a subspec
pod2spm wrap Firebase/Analytics --version 11.0.0 --platform ios --output ./FirebaseAnalyticsPackage

# Git init + tag the output (useful for private SPM hosting)
pod2spm wrap SomeSDK --version 3.2.0 -p ios -o ./SomeSDKPackage --tag

# Keep the temp directory on failure to inspect build logs
pod2spm wrap SomeSDK --version 3.2.0 -p ios -o ./out --keep-temp
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
| `--no-repo-update` | off | Skip `--repo-update` in pod install (faster) |
| `--keep-temp` | off | Preserve temp working directory for debugging |
| `--verbose`, `-V` | off | Print all shell commands and output |
| `--json` | off | Print a JSON summary of the result to stdout |

### check-versions

```bash
pod2spm check-versions ./Podfile
```

Queries CocoaPods Trunk for each pod in a Podfile and prints a comparison table against pinned versions.

## How it works

pod2spm runs `pod install` in a temporary Xcode project, then takes one of two paths.

**Prebuilt XCFrameworks:** If the pod vendors `.xcframework` bundles in `Pods/`, they're copied directly into the output. No compilation.

**Source-only pods:** `xcodebuild archive` runs for device and simulator slices, then `xcodebuild -create-xcframework` merges them. The build scheme is resolved automatically — exact pod name match first, then case-insensitive, then first non-aggregate scheme.

Resource bundles (`*.bundle`) are detected in both cases and included as a separate SPM resource target.

The generated `Package.swift` is validated with `swift package dump-package` before the tool exits.

## Output

```
SomeSDKPackage/
├── Package.swift
├── SomeSDK.xcframework/
└── Resources/
    └── SomeSDKResources.bundle/
```

## Known limitations

- Plain `.framework` binaries (not `.xcframework`) are not supported — the tool will warn and attempt a source build instead.
- Static-only pods and pods with complex build settings (gRPC, BoringSSL, Realm) may fail at the `xcodebuild archive` step.
- Loose resource files declared in podspecs are not reconstructed — only `.bundle` directories are copied.
- No `linkerSettings` are emitted for system framework dependencies; those may need manual `Package.swift` edits.

## SDK redistribution

This tool repackages SDK binaries. Check the SDK's license for redistribution rights before distributing the output. Consider hosting in a private repo to limit access.

## License

MIT
