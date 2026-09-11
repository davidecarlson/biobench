#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
RESULTS_DIR=${RESULTS_DIR:-$ROOT/results}
app=${1:-}; ARCH=${ARCH:-${2:-}}
[ -n "$app" ] || { echo "Usage: $0 APP [ARCH]" >&2; exit 2; }
if [ -z "$ARCH" ]; then
    candidates=("$RESULTS_DIR/$app"/*)
    if [ "${#candidates[@]}" -eq 1 ] && [ -d "${candidates[0]}" ]; then ARCH=$(basename "${candidates[0]}"); else
        echo "Set ARCH; could not uniquely select results under $RESULTS_DIR/$app" >&2; printf 'Candidates:\n' >&2; printf '  %s\n' "${candidates[@]}" >&2; exit 1
    fi
fi
result_root="$RESULTS_DIR/$app/$ARCH"
[ -d "$result_root" ] || { echo "Missing result directory: $result_root" >&2; exit 1; }
python3 - "$app" "$ARCH" "$result_root" <<'PY'
import glob
import json
import os
import sys

app, arch, root = sys.argv[1:]
files = sorted(glob.glob(os.path.join(root, "**", "hyperfine.json"), recursive=True))
candidates = []
for filename in files:
    try:
        with open(filename, encoding="utf-8") as stream:
            results = json.load(stream).get("results", [])
    except (OSError, ValueError, TypeError):
        continue
    for result in results:
        if isinstance(result.get("mean"), (int, float)):
            parameters = result.get("parameters") or {}
            threads = parameters.get("threads")
            if threads is None:
                parent = os.path.basename(os.path.dirname(filename))
                if parent.startswith("threads-"):
                    threads = parent[len("threads-"):]
            candidates.append((result["mean"], threads, result.get("command", ""), filename))

if not candidates:
    raise SystemExit(f"No valid Hyperfine results found under {root}")
mean, threads, command, filename = min(candidates, key=lambda item: item[0])
print(f"application={app}")
print(f"architecture={arch}")
print(f"best_mean_seconds={mean:.9g}")
print(f"threads={threads if threads is not None else 'unknown'}")
print(f"result_file={filename}")
print(f"command={command}")
PY
