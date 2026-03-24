"""Podfile creation and parsing utilities."""

from __future__ import annotations

import re
from pathlib import Path


def generate_podfile(
    pod_name: str,
    version: str,
    platform: str,
    min_deployment_target: str,
    directory: Path,
) -> Path:
    """Write a minimal Podfile for installing a single pod and return its path."""
    platform_line = f"platform :{platform}, '{min_deployment_target}'"

    content = f"""\
{platform_line}

target 'TempTarget' do
  use_frameworks!
  pod '{pod_name}', '{version}'
end
"""
    podfile_path = directory / "Podfile"
    podfile_path.write_text(content)
    return podfile_path


def parse_podfile(podfile_path: Path) -> list[tuple[str, str | None]]:
    """Parse a Podfile and return a list of (pod_name, pinned_version | None).

    Handles common formats:
      pod 'Name', '1.2.3'
      pod 'Name', '~> 1.2'
      pod 'Name'
    """
    text = podfile_path.read_text()
    # Match: pod 'Name' or pod 'Name', 'version_spec'
    pattern = re.compile(
        r"""pod\s+['"]([^'"]+)['"]\s*(?:,\s*['"]([^'"]*?)['"])?""",
        re.MULTILINE,
    )

    results: list[tuple[str, str | None]] = []
    for match in pattern.finditer(text):
        name = match.group(1)
        version_spec = match.group(2)
        # Strip leading operators like ~>, >=, etc. to get the base version
        if version_spec:
            version_clean = re.sub(r"^[~>=<!\s]+", "", version_spec).strip()
            results.append((name, version_clean if version_clean else None))
        else:
            results.append((name, None))

    return results
