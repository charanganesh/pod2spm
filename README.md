# pod2spm

CLI tool to wrap CocoaPods as Swift Package Manager binary packages (XCFrameworks).

Built for the real-world problem of integrating SDKs into SPM-based projects when the vendor only ships a CocoaPod.

## Install

```bash
brew install charanganesh/tap/pod2spm
```

Or with pip:

```bash
pip install pod2spm
```

Requires macOS with Xcode and CocoaPods installed.

## Usage

### Wrap a pod

```bash
# Case 1: Pod ships prebuilt XCFrameworks
pod2spm wrap SomeSDK --version 3.2.0 --platform ios --output ./SomeSDKPackage

# Case 2: Pod ships source only
pod2spm wrap AnotherSDK --version 1.5.0 --platform tvos --output ./AnotherSDKPackage

# With git init + tag
pod2spm wrap SomeSDK --version 3.2.0 -p ios -o ./SomeSDKPackage --tag
```

This will:
1. Create a temp Xcode project and install the pod
2. Detect if the pod ships prebuilt XCFrameworks or needs building from source
3. Extract or build the XCFramework(s)
4. Copy any resource bundles
5. Generate a `Package.swift` with the correct binary targets

### Check pod versions

```bash
pod2spm check-versions ./Podfile
```

Compares pinned versions in your Podfile against the latest on CocoaPods Trunk. Highlights outdated pods.

## How it works

**Case 1 — Prebuilt XCFrameworks:** Some pods vendor prebuilt `.xcframework` bundles. pod2spm detects these in the `Pods/` directory after install and copies them directly.

**Case 2 — Source-only pods:** For pods that only ship source code, pod2spm runs `xcodebuild archive` for device and simulator slices, then combines them with `xcodebuild -create-xcframework`.

## SDK Redistribution

This tool extracts and repackages SDK binaries. Before distributing the output:
- Check the SDK's license for redistribution terms
- Some SDKs require specific attribution
- Consider hosting the generated package in a private repo

## Development

```bash
pip install -e ".[dev]"
```

## License

MIT
