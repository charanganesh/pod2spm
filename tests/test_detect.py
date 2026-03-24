"""Tests for pod detection logic."""

from pathlib import Path

from pod2spm.detect import scan_pods_dir


def test_detects_prebuilt_xcframework(tmp_path: Path) -> None:
    pods_dir = tmp_path / "Pods"
    xcf = pods_dir / "GoogleAds" / "GoogleMobileAds.xcframework"
    xcf.mkdir(parents=True)
    (xcf / "Info.plist").touch()

    result = scan_pods_dir(pods_dir, "GoogleAds")
    assert result.is_prebuilt
    assert len(result.xcframeworks) == 1
    assert result.xcframeworks[0].name == "GoogleMobileAds.xcframework"


def test_detects_resource_bundles(tmp_path: Path) -> None:
    pods_dir = tmp_path / "Pods"
    bundle = pods_dir / "GoogleAds" / "GoogleMobileAdsResources.bundle"
    bundle.mkdir(parents=True)
    (bundle / "PrivacyInfo.xcprivacy").touch()

    result = scan_pods_dir(pods_dir, "GoogleAds")
    assert len(result.resource_bundles) == 1


def test_no_xcframeworks(tmp_path: Path) -> None:
    pods_dir = tmp_path / "Pods"
    (pods_dir / "SomePod" / "Sources").mkdir(parents=True)

    result = scan_pods_dir(pods_dir, "SomePod")
    assert not result.is_prebuilt


def test_ignores_target_support_files(tmp_path: Path) -> None:
    pods_dir = tmp_path / "Pods"
    xcf = pods_dir / "Target Support Files" / "Something.xcframework"
    xcf.mkdir(parents=True)

    result = scan_pods_dir(pods_dir, "Something")
    assert not result.is_prebuilt
