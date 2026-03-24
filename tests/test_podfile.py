"""Tests for Podfile generation and parsing."""

from pathlib import Path
from textwrap import dedent

from pod2spm.podfile import generate_podfile, parse_podfile


def test_generate_podfile(tmp_path: Path) -> None:
    path = generate_podfile("GoogleAds", "12.0.0", "ios", "15.0", tmp_path)
    content = path.read_text()
    assert "platform :ios, '15.0'" in content
    assert "pod 'GoogleAds', '12.0.0'" in content
    assert "use_frameworks!" in content


def test_parse_podfile_pinned(tmp_path: Path) -> None:
    podfile = tmp_path / "Podfile"
    podfile.write_text(dedent("""\
        platform :ios, '15.0'
        target 'App' do
          pod 'GoogleAds', '12.0.0'
          pod 'CleverTap', '~> 7.3'
          pod 'SomePod'
        end
    """))
    result = parse_podfile(podfile)
    assert result == [
        ("GoogleAds", "12.0.0"),
        ("CleverTap", "7.3"),
        ("SomePod", None),
    ]


def test_parse_podfile_empty(tmp_path: Path) -> None:
    podfile = tmp_path / "Podfile"
    podfile.write_text("platform :ios, '15.0'\ntarget 'App' do\nend\n")
    assert parse_podfile(podfile) == []
