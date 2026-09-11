#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ARCH=${ARCH:-}
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
    if [[ $THREADS != *,* ]]; then
        result_dir+="/threads-$THREADS"
    fi
    mkdir -p "$result_dir"
    ensure_hyperfine
    hyperfine --shell bash --warmup "$WARMUP" --runs "$RUNS" \
        --parameter-list threads "$THREADS" --export-json "$result_dir/hyperfine.json" \
        --export-csv "$result_dir/hyperfine.csv" --export-markdown "$result_dir/hyperfine.md" \
        --command-name "$app" "$command_line"
    python3 - "$result_dir/hyperfine.json" "$result_dir/best.txt" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    results = json.load(stream)["results"]
best = min(results, key=lambda item: item["mean"])
with open(sys.argv[2], "w", encoding="utf-8") as stream:
    stream.write(f"mean_seconds={best['mean']:.9g}\n")
    for name, value in best.get("parameters", {}).items():
        stream.write(f"{name}={value}\n")
    stream.write(f"command={best['command']}\n")
PY
    printf 'Results: %s\nBest run: %s\n' "$result_dir/hyperfine.json" "$result_dir/best.txt"
}

require_file() { [ -r "$1" ] || { echo "Missing input: $1" >&2; return 1; }; }

prepare_once() {
    local marker=$1 lock="$1.lock"
    shift
    [ -e "$marker" ] && return
    while ! mkdir "$lock" 2>/dev/null; do sleep 5; done
    if [ ! -e "$marker" ]; then
        if ! "$@"; then rmdir "$lock"; return 1; fi
    fi
    rmdir "$lock"
}

select_arch() {
    local app=$1 version=$2 executable=$3 root="$SOFTWARE/$1-$2" candidate
    if [ -n "$ARCH" ]; then return; fi
    if [ -x "$root/native/bin/$executable" ]; then
        ARCH=native
        return
    fi
    local candidates=("$root"/*/bin/"$executable")
    if [ "${#candidates[@]}" -eq 1 ] && [ -x "${candidates[0]}" ]; then
        candidate=${candidates[0]}
        ARCH=$(basename "$(dirname "$(dirname "$candidate")")")
        return
    fi
    echo "Set ARCH; could not uniquely select an installed $app architecture under $root" >&2
    printf 'Candidates:\n' >&2
    printf '  %s\n' "${candidates[@]}" >&2
    return 1
}
