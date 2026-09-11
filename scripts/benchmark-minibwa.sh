#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/benchmark-common.sh"
select_arch minibwa 0.7 minibwa
BIN="$SOFTWARE/minibwa-0.7/$ARCH/bin/minibwa"; REF="$DATA/ref/GRCh38.primary_assembly.genome.fa"; R1="$DATA/fastq/HG002_NA24385_combined_10M.1.fq.gz"; R2="$DATA/fastq/HG002_NA24385_combined_10M.2.fq.gz"
require_file "$BIN"; require_file "$REF"; require_file "$R1"; require_file "$R2"
WORK=${BENCH_WORK:-$RESULTS_DIR/work/minibwa-$ARCH}; mkdir -p "$WORK"; IREF="$WORK/GRCh38.fa"; [ -e "$IREF" ] || ln -s "$REF" "$IREF"; prepare_once "$IREF.l2b" "$BIN" index "$IREF"
run_hyperfine minibwa "$BIN map -t {threads} '$IREF' '$R1' '$R2' >/dev/null"
