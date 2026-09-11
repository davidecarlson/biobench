#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
app=${1:-}
shift || true
case "$app" in
    minibwa|minimap2|samtools|blast|salmon|star) ;;
    *) echo "Usage: $0 {minibwa|minimap2|samtools|blast|salmon|star} [sbatch options]" >&2; exit 2 ;;
esac
source "$ROOT/scripts/benchmark-common.sh"

for thread_count in ${THREADS//,/ }; do
    job_id=$(sbatch --parsable --job-name="bench-$app-$thread_count" \
        --export="ALL,THREADS=$thread_count" "$@" "$ROOT/scripts/benchmark-$app.slurm")
    printf '%s\t%s\t%s\n' "$job_id" "$app" "$thread_count"
done
