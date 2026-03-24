"""CLI entry point — typer app with `wrap` and `check-versions` commands."""

from pathlib import Path
from typing import Optional

import typer
from rich.console import Console

from pod2spm.wrap import run_wrap
from pod2spm.versions import check_versions as _check_versions

app = typer.Typer(
    name="pod2spm",
    help="Wrap CocoaPods as Swift Package Manager binary packages.",
    no_args_is_help=True,
)
console = Console()


@app.command()
def wrap(
    pod_name: str = typer.Argument(help="Name of the CocoaPod to wrap"),
    version: str = typer.Option(..., "--version", "-v", help="Pod version to install"),
    platform: str = typer.Option(
        "ios", "--platform", "-p", help="Target platform: ios, tvos, or macos"
    ),
    output: Path = typer.Option(
        ..., "--output", "-o", help="Output directory for the generated SPM package"
    ),
    tag: bool = typer.Option(
        False, "--tag", help="Initialize a git repo and tag the output"
    ),
    min_ios: str = typer.Option("15.0", "--min-ios", help="Minimum iOS deployment target"),
    min_tvos: str = typer.Option("15.0", "--min-tvos", help="Minimum tvOS deployment target"),
    min_macos: str = typer.Option("12.0", "--min-macos", help="Minimum macOS deployment target"),
) -> None:
    """Wrap a CocoaPod as an SPM binary package (XCFramework)."""
    platform = platform.lower()
    if platform not in ("ios", "tvos", "macos"):
        console.print(f"[red]Unsupported platform: {platform}[/red]")
        raise typer.Exit(1)

    deployment_targets = {"ios": min_ios, "tvos": min_tvos, "macos": min_macos}
    min_target = deployment_targets[platform]

    try:
        run_wrap(
            pod_name=pod_name,
            version=version,
            platform=platform,
            output_dir=output,
            git_tag=tag,
            min_deployment_target=min_target,
        )
    except Exception as exc:
        console.print(f"[red]Error:[/red] {exc}")
        raise typer.Exit(1)


@app.command("check-versions")
def check_versions(
    podfile: Path = typer.Argument(help="Path to a Podfile"),
) -> None:
    """Compare pinned pod versions against the latest on CocoaPods Trunk."""
    if not podfile.exists():
        console.print(f"[red]Podfile not found: {podfile}[/red]")
        raise typer.Exit(1)

    _check_versions(podfile)
