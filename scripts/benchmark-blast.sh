#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/benchmark-common.sh"
BIN="$SOFTWARE/blast-2.17.0+/$ARCH/bin"; QUERY="${BLAST_QUERY:-$DATA/blast/gencode.v46.pc_transcripts.25k.fa}"; PROTEIN="${BLAST_PROTEIN:-$DATA/blast/gencode.v46.pc_translations.25k.fa}"
require_file "$BIN/blastx"; require_file "$BIN/makeblastdb"; require_file "$QUERY"; require_file "$PROTEIN"
WORK=${BENCH_WORK:-$RESULTS_DIR/work/blast-$ARCH}; mkdir -p "$WORK"; DB="$WORK/proteins"; [ -s "$DB.psq" ] || "$BIN/makeblastdb" -in "$PROTEIN" -dbtype prot -out "$DB" >/dev/null
run_hyperfine blastx "'$BIN/blastx' -num_threads {threads} -db '$DB' -query '$QUERY' -outfmt 6 -max_target_seqs 10 -out /dev/null"
