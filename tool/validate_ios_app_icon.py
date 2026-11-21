#!/usr/bin/env python3
"""Reject an iOS .app that would show the generic/default home-screen icon."""
from __future__ import annotations

import argparse
import plistlib
import sys
from pathlib import Path


def validate(app: Path) -> list[str]:
    errors: list[str] = []
    info_path = app / "Info.plist"
    if not info_path.is_file():
        return [f"Missing {info_path}"]
    try:
        info = plistlib.loads(info_path.read_bytes())
    except (ValueError, OSError) as exc:
        return [f"Cannot read Info.plist: {exc}"]

    if not (app / "Assets.car").is_file():
        errors.append("Missing Assets.car (asset catalog was not compiled)")
    for icon in ("AppIcon60x60@2x.png", "AppIcon76x76@2x~ipad.png"):
        if not (app / icon).is_file():
            errors.append(f"Missing {icon}")
    for platform in ("CFBundleIcons", "CFBundleIcons~ipad"):
        primary = info.get(platform, {}).get("CFBundlePrimaryIcon", {})
        if not isinstance(primary, dict) or not primary:
            errors.append(f"Missing {platform}.CFBundlePrimaryIcon")
            continue
        if primary.get("CFBundleIconName") != "AppIcon":
            errors.append(f"{platform} does not point to AppIcon")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path, help="Path to the compiled Runner.app")
    args = parser.parse_args()
    failures = validate(args.app)
    if failures:
        print("FAIL iOS app icon:")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print(f"PASS iOS app icon: {args.app}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
