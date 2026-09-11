#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/benchmark-common.sh"
select_arch minimap2 2.31 minimap2
BIN="$SOFTWARE/minimap2-2.31/$ARCH/bin/minimap2"; REF="$DATA/ref/GRCh38.primary_assembly.genome.fa"; R1="$DATA/fastq/HG002_NA24385_combined_10M.1.fq.gz"; R2="$DATA/fastq/HG002_NA24385_combined_10M.2.fq.gz"
require_file "$BIN"; require_file "$REF"; require_file "$R1"; require_file "$R2"
WORK=${BENCH_WORK:-$RESULTS_DIR/work/minimap2-$ARCH}; mkdir -p "$WORK"; INDEX="$WORK/GRCh38.mmi"; [ -s "$INDEX" ] || "$BIN" -d "$INDEX" "$REF"
run_hyperfine minimap2 "$BIN -a -t {threads} '$INDEX' '$R1' '$R2' >/dev/null"
