#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ARCH=${ARCH:-native}
SOFTWARE=${SOFTWARE:-$ROOT/software}
DATA=${DATA:-$ROOT/data}
RESULTS_DIR=${RESULTS_DIR:-$ROOT/results}
MAX_THREADS=${MAX_THREADS:-192}
THREAD_MODE=${THREAD_MODE:-linear}
WARMUP=${WARMUP:-1}
RUNS=${RUNS:-3}

if [ -z "${THREADS:-}" ]; then
    THREADS_LIST=()
    if [ "$THREAD_MODE" = scaling ]; then
        for value in 1 2 4; do
            [ "$value" -le "$MAX_THREADS" ] && THREADS_LIST+=("$value")
        done
        next=8
    elif [ "$THREAD_MODE" = linear ]; then
        next=8
    else
        echo "THREAD_MODE must be linear or scaling" >&2
        exit 2
    fi
    while [ "$next" -le "$MAX_THREADS" ]; do
        THREADS_LIST+=("$next")
        next=$((next + 8))
    done
    if [ "${#THREADS_LIST[@]}" -eq 0 ] || [ "${THREADS_LIST[${#THREADS_LIST[@]}-1]}" -ne "$MAX_THREADS" ]; then
        THREADS_LIST+=("$MAX_THREADS")
    fi
    THREADS=$(IFS=,; printf '%s' "${THREADS_LIST[*]}")
fi

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
