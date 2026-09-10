#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ARCH=${ARCH:-native}
SOFTWARE=${SOFTWARE:-$ROOT/software}
DATA=${DATA:-$ROOT/data}
RESULTS_DIR=${RESULTS_DIR:-$ROOT/results}
THREADS=${THREADS:-8,16,32,64,96,128,160,192}
WARMUP=${WARMUP:-1}
RUNS=${RUNS:-3}

ensure_hyperfine() {
    if [ ! -x "$SOFTWARE/hyperfine/bin/hyperfine" ]; then
        "$ROOT/scripts/install-hyperfine.sh"
    fi
    export PATH="$SOFTWARE/hyperfine/bin:$PATH"
    command -v hyperfine >/dev/null 2>&1 || { echo "hyperfine installation failed" >&2; return 1; }
}

run_hyperfine() {
    local app=$1 command_line=$2 result_dir="$RESULTS_DIR/$1/$ARCH"
    mkdir -p "$result_dir"
    ensure_hyperfine
    hyperfine --shell bash --warmup "$WARMUP" --runs "$RUNS" \
        --parameter-list threads "$THREADS" --export-json "$result_dir/hyperfine.json" \
        --export-markdown "$result_dir/hyperfine.md" --command-name "$app" "$command_line"
    printf 'Results: %s\n' "$result_dir/hyperfine.json"
}

require_file() { [ -r "$1" ] || { echo "Missing input: $1" >&2; return 1; }; }
