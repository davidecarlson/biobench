#!/usr/bin/env bash
#SBATCH --job-name=bench-blast
#SBATCH --cpus-per-task=192
#SBATCH --mem=256G
#SBATCH --time=24:00:00
set -euo pipefail
cd "${SLURM_SUBMIT_DIR:-$(dirname "$0")/..}"
exec scripts/benchmark-blast.sh "$@"
