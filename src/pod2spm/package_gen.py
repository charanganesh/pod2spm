"""Generate Package.swift with binary targets and optional resource targets."""

from __future__ import annotations

from pathlib import Path


def generate_package_swift(
    package_name: str,
    xcframeworks: list[str],
    resource_bundles: list[str],
    platform: str,
    min_deployment_target: str,
    output_dir: Path,
) -> Path:
    """Write a Package.swift to output_dir and return its path.

    Args:
        package_name: SPM package name (usually the pod name).
        xcframeworks: List of xcframework filenames (e.g. ["GoogleMobileAds.xcframework"]).
        resource_bundles: List of .bundle filenames to include as resources.
        platform: ios, tvos, or macos.
        min_deployment_target: e.g. "15.0".
        output_dir: Directory to write Package.swift into.
    """
    platform_map = {
        "ios": ".iOS",
        "tvos": ".tvOS",
        "macos": ".macOS",
    }
    swift_platform = platform_map[platform]

    # Build target declarations
    targets: list[str] = []
    target_names: list[str] = []

    for xcf in xcframeworks:
        name = xcf.replace(".xcframework", "")
        target_names.append(name)
        targets.append(
            f'        .binaryTarget(\n'
            f'            name: "{name}",\n'
            f'            path: "{xcf}"\n'
            f'        )'
        )

    # Resource target if bundles exist
    if resource_bundles:
        res_target_name = f"{package_name}Resources"
        target_names.append(res_target_name)

        resource_lines = ",\n".join(
            f'                .copy("{b}")' for b in resource_bundles
        )
        targets.append(
            f'        .target(\n'
            f'            name: "{res_target_name}",\n'
            f'            path: "Resources",\n'
            f'            resources: [\n'
            f'{resource_lines}\n'
            f'            ]\n'
            f'        )'
        )

    targets_block = ",\n".join(targets)
    target_refs = ", ".join(f'"{t}"' for t in target_names)

    content = f"""\
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "{package_name}",
    platforms: [
        {swift_platform}("{min_deployment_target}")
    ],
    products: [
        .library(
            name: "{package_name}",
            targets: [{target_refs}]
        )
    ],
    targets: [
{targets_block}
    ]
)
"""

    path = output_dir / "Package.swift"
    path.write_text(content)
    return path
