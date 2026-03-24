"""Core wrap logic — orchestrates the full pod → xcframework → Package.swift pipeline."""

from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path

from rich.console import Console

from pod2spm.build import build_xcframework, discover_scheme
from pod2spm.detect import scan_pods_dir
from pod2spm.package_gen import generate_package_swift
from pod2spm.podfile import generate_podfile

console = Console()


def _run(cmd: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    console.print(f"[dim]$ {' '.join(cmd)}[/dim]")
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        console.print(f"[red]{result.stderr}[/red]")
        raise RuntimeError(f"Command failed: {' '.join(cmd[:3])}...")
    return result


def _create_temp_xcode_project(work_dir: Path, platform: str) -> None:
    """Create a minimal Xcode project so `pod install` has a .xcodeproj to attach to."""
    proj_dir = work_dir / "TempTarget.xcodeproj"
    proj_dir.mkdir()

    # Minimal pbxproj — CocoaPods only needs the target to exist
    pbxproj = proj_dir / "project.pbxproj"
    pbxproj.write_text(_minimal_pbxproj(platform))


def _minimal_pbxproj(platform: str) -> str:
    """Return a minimal pbxproj that defines a single framework target."""
    sdk_root = {
        "ios": "iphoneos",
        "tvos": "appletvos",
        "macos": "macosx",
    }[platform]

    return f"""\
// !$*UTF8*$!
{{
    archiveVersion = 1;
    classes = {{}};
    objectVersion = 56;
    objects = {{
        00000000000000000000001 /* Project object */ = {{
            isa = PBXProject;
            buildConfigurationList = 00000000000000000000004;
            compatibilityVersion = "Xcode 14.0";
            mainGroup = 00000000000000000000002;
            productRefGroup = 00000000000000000000003;
            projectDirPath = "";
            projectRoot = "";
            targets = (00000000000000000000010);
        }};
        00000000000000000000002 /* Main Group */ = {{
            isa = PBXGroup;
            children = ();
            sourceTree = "<group>";
        }};
        00000000000000000000003 /* Products */ = {{
            isa = PBXGroup;
            children = ();
            name = Products;
            sourceTree = "<group>";
        }};
        00000000000000000000004 /* Build configuration list for PBXProject */ = {{
            isa = XCConfigurationList;
            buildConfigurations = (00000000000000000000005);
            defaultConfigurationIsVisible = 0;
            defaultConfigurationName = Release;
        }};
        00000000000000000000005 /* Release */ = {{
            isa = XCBuildConfiguration;
            buildSettings = {{
                SDKROOT = {sdk_root};
            }};
            name = Release;
        }};
        00000000000000000000010 /* TempTarget */ = {{
            isa = PBXNativeTarget;
            buildConfigurationList = 00000000000000000000011;
            buildPhases = ();
            buildRules = ();
            dependencies = ();
            name = TempTarget;
            productName = TempTarget;
            productType = "com.apple.product-type.framework";
        }};
        00000000000000000000011 /* Build configuration list for target */ = {{
            isa = XCConfigurationList;
            buildConfigurations = (00000000000000000000012);
            defaultConfigurationIsVisible = 0;
            defaultConfigurationName = Release;
        }};
        00000000000000000000012 /* Release */ = {{
            isa = XCBuildConfiguration;
            buildSettings = {{
                PRODUCT_NAME = "$(TARGET_NAME)";
                SDKROOT = {sdk_root};
            }};
            name = Release;
        }};
    }};
    rootObject = 00000000000000000000001;
}}
"""


def run_wrap(
    pod_name: str,
    version: str,
    platform: str,
    output_dir: Path,
    git_tag: bool = False,
    min_deployment_target: str = "15.0",
) -> None:
    """Execute the full wrap pipeline."""
    output_dir = output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="pod2spm_") as tmp:
        work_dir = Path(tmp)
        console.print(f"[bold]Working in {work_dir}[/bold]\n")

        # Step 1: Create temp Xcode project + Podfile
        console.print("[bold cyan]Step 1:[/bold cyan] Creating temp project and Podfile")
        _create_temp_xcode_project(work_dir, platform)
        generate_podfile(pod_name, version, platform, min_deployment_target, work_dir)

        # Step 2: pod install
        console.print("\n[bold cyan]Step 2:[/bold cyan] Running pod install")
        _run(["pod", "install", "--repo-update"], cwd=work_dir)

        pods_dir = work_dir / "Pods"

        # Step 3: Detect case
        console.print("\n[bold cyan]Step 3:[/bold cyan] Scanning for prebuilt XCFrameworks")
        detection = scan_pods_dir(pods_dir, pod_name)

        xcframework_names: list[str] = []

        if detection.is_prebuilt:
            # Case 1: Copy prebuilt xcframeworks
            console.print(
                f"[green]Found {len(detection.xcframeworks)} prebuilt XCFramework(s)[/green]"
            )
            for xcf in detection.xcframeworks:
                dest = output_dir / xcf.name
                if dest.exists():
                    shutil.rmtree(dest)
                shutil.copytree(xcf, dest)
                xcframework_names.append(xcf.name)
                console.print(f"  Copied {xcf.name}")
        else:
            # Case 2: Build from source
            console.print("[yellow]No prebuilt XCFrameworks — building from source[/yellow]")
            workspace = work_dir / "TempTarget.xcworkspace"
            if not workspace.exists():
                raise RuntimeError("pod install did not create a .xcworkspace")

            scheme = discover_scheme(workspace)
            if not scheme:
                raise RuntimeError("Could not discover a build scheme")

            console.print(f"  Using scheme: {scheme}")
            xcf_path = build_xcframework(
                workspace=workspace,
                scheme=scheme,
                platform=platform,
                output_dir=output_dir,
                framework_name=pod_name.replace("-", ""),
            )
            xcframework_names.append(xcf_path.name)

        # Step 4: Copy resource bundles
        bundle_names: list[str] = []
        if detection.resource_bundles:
            console.print(
                f"\n[bold cyan]Step 4:[/bold cyan] Copying {len(detection.resource_bundles)} resource bundle(s)"
            )
            resources_dir = output_dir / "Resources"
            resources_dir.mkdir(exist_ok=True)
            for bundle in detection.resource_bundles:
                dest = resources_dir / bundle.name
                if dest.exists():
                    shutil.rmtree(dest)
                shutil.copytree(bundle, dest)
                bundle_names.append(bundle.name)
                console.print(f"  Copied {bundle.name}")
        else:
            console.print("\n[bold cyan]Step 4:[/bold cyan] No resource bundles found")

        # Step 5: Generate Package.swift
        console.print("\n[bold cyan]Step 5:[/bold cyan] Generating Package.swift")
        pkg_path = generate_package_swift(
            package_name=pod_name,
            xcframeworks=xcframework_names,
            resource_bundles=bundle_names,
            platform=platform,
            min_deployment_target=min_deployment_target,
            output_dir=output_dir,
        )
        console.print(f"  Written to {pkg_path}")

    # Step 6: Optionally git init + tag
    if git_tag:
        console.print("\n[bold cyan]Step 6:[/bold cyan] Initializing git repo and tagging")
        _run(["git", "init"], cwd=output_dir)
        _run(["git", "add", "."], cwd=output_dir)
        _run(["git", "commit", "-m", f"pod2spm: wrap {pod_name} {version}"], cwd=output_dir)
        _run(["git", "tag", version], cwd=output_dir)
        console.print(f"  Tagged as {version}")

    console.print(f"\n[bold green]Done![/bold green] Output at {output_dir}")
