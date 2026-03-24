"""Tests for Package.swift generation."""

from pathlib import Path

from pod2spm.package_gen import generate_package_swift


def test_basic_package_swift(tmp_path: Path) -> None:
    path = generate_package_swift(
        package_name="GoogleAds",
        xcframeworks=["GoogleMobileAds.xcframework"],
        resource_bundles=[],
        platform="ios",
        min_deployment_target="15.0",
        output_dir=tmp_path,
    )
    content = path.read_text()
    assert 'name: "GoogleAds"' in content
    assert ".binaryTarget" in content
    assert 'path: "GoogleMobileAds.xcframework"' in content
    assert ".iOS" in content


def test_package_swift_with_resources(tmp_path: Path) -> None:
    path = generate_package_swift(
        package_name="GoogleAds",
        xcframeworks=["GoogleMobileAds.xcframework"],
        resource_bundles=["GoogleMobileAdsResources.bundle"],
        platform="ios",
        min_deployment_target="15.0",
        output_dir=tmp_path,
    )
    content = path.read_text()
    assert "GoogleAdsResources" in content
    assert ".copy(" in content
    assert "GoogleMobileAdsResources.bundle" in content


def test_tvos_platform(tmp_path: Path) -> None:
    path = generate_package_swift(
        package_name="CleverTap",
        xcframeworks=["CleverTapSDK.xcframework"],
        resource_bundles=[],
        platform="tvos",
        min_deployment_target="15.0",
        output_dir=tmp_path,
    )
    content = path.read_text()
    assert ".tvOS" in content


def test_multiple_xcframeworks(tmp_path: Path) -> None:
    path = generate_package_swift(
        package_name="Ads",
        xcframeworks=["GoogleMobileAds.xcframework", "UserMessagingPlatform.xcframework"],
        resource_bundles=[],
        platform="ios",
        min_deployment_target="15.0",
        output_dir=tmp_path,
    )
    content = path.read_text()
    assert "GoogleMobileAds" in content
    assert "UserMessagingPlatform" in content
    # Both should be in the product targets list
    assert '"GoogleMobileAds"' in content
    assert '"UserMessagingPlatform"' in content
