#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/benchmark-common.sh"
BIN="$SOFTWARE/blast-2.17.0+/$ARCH/bin"; QUERY="$DATA/blast/gencode.v46.pc_transcripts.25k.fa"
require_file "$BIN/blastn"; require_file "$BIN/makeblastdb"; require_file "$QUERY"
WORK=${BENCH_WORK:-$RESULTS_DIR/work/blast-$ARCH}; mkdir -p "$WORK"; DB="$WORK/transcripts"; [ -s "$DB.nsq" ] || "$BIN/makeblastdb" -in "$QUERY" -dbtype nucl -out "$DB" >/dev/null
run_hyperfine blastn "'$BIN/blastn' -num_threads {threads} -db '$DB' -query '$QUERY' -outfmt 6 -max_target_seqs 10 -out /dev/null"
