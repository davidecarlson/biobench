#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/benchmark-common.sh"
BIN="$SOFTWARE/salmon-2.7.0/$ARCH/bin/salmon"; TX="$DATA/blast/gencode.v46.pc_transcripts.25k.fa"; R1="$DATA/fastq/hg002_gm24385.mrna.25M.R1.fastq.gz"; R2="$DATA/fastq/hg002_gm24385.mrna.25M.R2.fastq.gz"
require_file "$BIN"; require_file "$TX"; require_file "$R1"; require_file "$R2"
WORK=${BENCH_WORK:-$RESULTS_DIR/work/salmon-$ARCH}; mkdir -p "$WORK"; INDEX="$WORK/index"; [ -s "$INDEX/versionInfo.json" ] || "$BIN" index -t "$TX" -i "$INDEX" -k 31 >/dev/null
run_hyperfine salmon "rm -rf '$WORK/quant-{threads}' && '$BIN' quant -i '$INDEX' -l A -1 '$R1' -2 '$R2' -p {threads} --validateMappings -o '$WORK/quant-{threads}' --no-version-check >/dev/null"
