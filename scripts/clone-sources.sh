#!/usr/bin/env bash
# Obtain immutable maintained source; never rewrite existing source files.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ "$#" -ne 0 ]; then
    echo "Only locked sources are supported; update pins in a reviewed change." >&2
    exit 2
fi
if [ -d "$ROOT/sources/Shipwright" ] && [ -n "$(ls -A "$ROOT/sources/Shipwright")" ]; then
    "$ROOT/scripts/verify-sources.py"
    echo "Verified existing sources; no files changed."
else
    git -C "$ROOT" submodule update --init --recursive -- sources/Shipwright
    # Replay the lock's per-component patches onto the fresh checkout; verify-sources.py
    # then checks the result against the same pins and patches.
    python3 - "$ROOT" <<'PY'
import json
import pathlib
import subprocess
import sys

root = pathlib.Path(sys.argv[1])
for component in json.loads((root / "sources.lock.json").read_text())["components"]:
    for patch in component.get("patches", []):
        args = ["git", "-C", str(root / component["path"]), "apply"]
        if patch.get("ignore_space_change"):
            args.append("--ignore-space-change")
        subprocess.run(args + [str(root / patch["path"])], check=True)
        print(f"Applied {patch['path']} to {component['name']}")
PY
    "$ROOT/scripts/verify-sources.py"
fi
