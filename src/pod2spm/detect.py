"""Detect whether a pod ships prebuilt XCFrameworks or needs building from source."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class DetectionResult:
    """Result of scanning Pods/ after `pod install`."""

    xcframeworks: list[Path] = field(default_factory=list)
    resource_bundles: list[Path] = field(default_factory=list)

    @property
    def is_prebuilt(self) -> bool:
        return len(self.xcframeworks) > 0


def scan_pods_dir(pods_dir: Path, pod_name: str) -> DetectionResult:
    """Scan the Pods/ directory for xcframeworks and resource bundles.

    Looks for:
      - *.xcframework anywhere under Pods/
      - *.bundle directories (resource bundles with PrivacyInfo.xcprivacy etc.)
    """
    result = DetectionResult()

    if not pods_dir.exists():
        return result

    # Scan for xcframeworks — skip Pods/Target Support Files
    for item in pods_dir.rglob("*.xcframework"):
        if "Target Support Files" not in str(item):
            result.xcframeworks.append(item)

    # Scan for resource bundles
    for item in pods_dir.rglob("*.bundle"):
        if item.is_dir() and "Target Support Files" not in str(item):
            result.resource_bundles.append(item)

    return result
