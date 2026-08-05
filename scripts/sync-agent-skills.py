#!/usr/bin/env python3
"""Synchronize and install the skills mapped to Veredra."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT_ID = "veredra"
CENTRAL_REPOSITORY = "TSWill03/AgentsSkills"


def run(command: list[str], cwd: Path | None = None) -> None:
    print("[agent-skills] " + " ".join(command))
    subprocess.run(command, cwd=cwd, check=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--agent", default="codex")
    parser.add_argument(
        "--cache-dir",
        type=Path,
        default=Path(os.environ.get("AGENT_SKILLS_HOME", Path.home() / ".cache" / "wicolly-agent-skills")) / "AgentsSkills",
    )
    args = parser.parse_args()

    root = Path(
        subprocess.run(["git", "rev-parse", "--show-toplevel"], check=True, capture_output=True, text=True).stdout.strip()
    ).resolve()
    cache = args.cache_dir.expanduser().resolve()
    if (cache / ".git").exists():
        run(["git", "fetch", "--depth", "1", "origin", "main"], cache)
        run(["git", "reset", "--hard", "origin/main"], cache)
    else:
        cache.parent.mkdir(parents=True, exist_ok=True)
        gh = shutil.which("gh")
        if gh:
            run([gh, "repo", "clone", CENTRAL_REPOSITORY, str(cache), "--", "--depth", "1"])
        else:
            run(["git", "clone", "--depth", "1", f"https://github.com/{CENTRAL_REPOSITORY}.git", str(cache)])

    run([
        sys.executable,
        str(cache / "scripts" / "install_project_skills.py"),
        "--project",
        PROJECT_ID,
        "--root",
        str(root),
        "--agent",
        args.agent,
    ], root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
