"""xcodebuild invocations for Case 2 — building from source."""

from __future__ import annotations

import subprocess
from pathlib import Path

from rich.console import Console

console = Console()

# Maps platform to (sdk_device, sdk_simulator, arch_device, arch_simulator)
PLATFORM_CONFIG = {
    "ios": ("iphoneos", "iphonesimulator", "arm64", "arm64 x86_64"),
    "tvos": ("appletvos", "appletvsimulator", "arm64", "arm64 x86_64"),
    "macos": ("macosx", "macosx", "arm64 x86_64", "arm64 x86_64"),
}


def _run(cmd: list[str], cwd: Path | None = None) -> None:
    """Run a command, streaming output. Raises on failure."""
    console.print(f"[dim]$ {' '.join(cmd)}[/dim]")
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        console.print(f"[red]{result.stderr}[/red]")
        raise RuntimeError(f"Command failed: {' '.join(cmd[:3])}...")


def build_xcframework(
    workspace: Path,
    scheme: str,
    platform: str,
    output_dir: Path,
    framework_name: str,
) -> Path:
    """Build an xcframework from source using xcodebuild archive + create-xcframework.

    Returns the path to the created .xcframework.
    """
    sdk_device, sdk_sim, _, _ = PLATFORM_CONFIG[platform]
    archives_dir = output_dir / "_archives"
    archives_dir.mkdir(parents=True, exist_ok=True)

    device_archive = archives_dir / f"{framework_name}-device.xcarchive"
    sim_archive = archives_dir / f"{framework_name}-simulator.xcarchive"

    # Archive for device
    console.print(f"[bold]Archiving {framework_name} for {sdk_device}...[/bold]")
    _run([
        "xcodebuild", "archive",
        "-workspace", str(workspace),
        "-scheme", scheme,
        "-sdk", sdk_device,
        "-archivePath", str(device_archive),
        "SKIP_INSTALL=NO",
        "BUILD_LIBRARY_FOR_DISTRIBUTION=YES",
    ])

    # Archive for simulator (skip for macos — same SDK)
    if sdk_device != sdk_sim:
        console.print(f"[bold]Archiving {framework_name} for {sdk_sim}...[/bold]")
        _run([
            "xcodebuild", "archive",
            "-workspace", str(workspace),
            "-scheme", scheme,
            "-sdk", sdk_sim,
            "-archivePath", str(sim_archive),
            "SKIP_INSTALL=NO",
            "BUILD_LIBRARY_FOR_DISTRIBUTION=YES",
        ])

    # Collect .framework paths from archives
    xcframework_path = output_dir / f"{framework_name}.xcframework"

    create_cmd = [
        "xcodebuild", "-create-xcframework",
        "-output", str(xcframework_path),
    ]

    for archive in [device_archive, sim_archive]:
        if not archive.exists():
            continue
        # Find the .framework inside the archive
        frameworks_dir = archive / "Products" / "Library" / "Frameworks"
        if not frameworks_dir.exists():
            # Try the usr/local/lib path for static libs
            frameworks_dir = archive / "Products" / "usr" / "local" / "lib"

        for fw in frameworks_dir.iterdir():
            if fw.suffix == ".framework":
                create_cmd.extend(["-framework", str(fw)])
                break
            elif fw.suffix == ".a":
                create_cmd.extend(["-library", str(fw)])
                # Look for headers
                headers = archive / "Products" / "usr" / "local" / "include"
                if headers.exists():
                    create_cmd.extend(["-headers", str(headers)])
                break

    console.print(f"[bold]Creating {framework_name}.xcframework...[/bold]")
    _run(create_cmd)

    # Clean up archives
    import shutil
    shutil.rmtree(archives_dir, ignore_errors=True)

    return xcframework_path


def discover_scheme(workspace: Path) -> str | None:
    """List schemes in the workspace and return the pod's scheme (not Pods-*)."""
    result = subprocess.run(
        ["xcodebuild", "-workspace", str(workspace), "-list"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        return None

    schemes: list[str] = []
    in_schemes = False
    for line in result.stdout.splitlines():
        stripped = line.strip()
        if stripped == "Schemes:":
            in_schemes = True
            continue
        if in_schemes:
            if not stripped:
                break
            schemes.append(stripped)

    # Filter out Pods-* meta schemes
    pod_schemes = [s for s in schemes if not s.startswith("Pods-")]
    return pod_schemes[0] if pod_schemes else (schemes[0] if schemes else None)
