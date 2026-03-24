"""check-versions command — compare pinned pod versions against CocoaPods Trunk."""

from __future__ import annotations

from pathlib import Path

import requests
from rich.console import Console
from rich.table import Table

from pod2spm.podfile import parse_podfile

console = Console()

TRUNK_API = "https://trunk.cocoapods.org/api/v1/pods"


def fetch_latest_version(pod_name: str) -> str | None:
    """Query CocoaPods Trunk API for the latest version of a pod."""
    try:
        resp = requests.get(f"{TRUNK_API}/{pod_name}", timeout=10)
        if resp.status_code != 200:
            return None
        data = resp.json()
        versions = data.get("versions", [])
        if not versions:
            return None
        # versions are ordered oldest → newest
        return versions[-1].get("name")
    except (requests.RequestException, KeyError, IndexError):
        return None


def check_versions(podfile_path: Path) -> None:
    """Parse a Podfile, query Trunk for each pod, and print a comparison table."""
    pods = parse_podfile(podfile_path)

    if not pods:
        console.print("[yellow]No pods found in Podfile.[/yellow]")
        return

    table = Table(title="Pod Version Check")
    table.add_column("Pod", style="bold")
    table.add_column("Pinned")
    table.add_column("Latest")
    table.add_column("Status")

    for name, pinned in pods:
        latest = fetch_latest_version(name)

        if pinned is None:
            status = "[yellow]unpinned[/yellow]"
            pinned_display = "-"
        elif latest is None:
            status = "[dim]unknown[/dim]"
            pinned_display = pinned
        elif pinned == latest:
            status = "[green]current[/green]"
            pinned_display = pinned
        else:
            status = "[red]outdated[/red]"
            pinned_display = pinned

        table.add_row(name, pinned_display, latest or "?", status)

    console.print(table)
