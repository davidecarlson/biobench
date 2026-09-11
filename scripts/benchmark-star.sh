#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/benchmark-common.sh"
select_arch star 2.7.11b STAR
BIN="$SOFTWARE/star-2.7.11b/$ARCH/bin/STAR"; REF="$DATA/ref/GRCh38.primary_assembly.genome.fa"; R1="$DATA/fastq/hg002_gm24385.mrna.25M.R1.fastq.gz"; R2="$DATA/fastq/hg002_gm24385.mrna.25M.R2.fastq.gz"
require_file "$BIN"; require_file "$REF"; require_file "$R1"; require_file "$R2"
WORK=${BENCH_WORK:-$RESULTS_DIR/work/star-$ARCH}; mkdir -p "$WORK"; INDEX="$WORK/genome"
if [ ! -s "$INDEX/Genome" ]; then
    mkdir -p "$INDEX"
    "$BIN" --runMode genomeGenerate --runThreadN "${INDEX_THREADS:-$MAX_THREADS}" --genomeDir "$INDEX" --genomeFastaFiles "$REF" --genomeSAindexNbases "${GENOME_SA_INDEX_NBASES:-14}" --genomeLoad NoSharedMemory
fi
run_hyperfine star "rm -f '$WORK/run-{threads}-'Log.out '$WORK/run-{threads}-'Log.progress.out '$WORK/run-{threads}-'Log.final.out '$WORK/run-{threads}-'Aligned.out.sam && '$BIN' --runThreadN {threads} --genomeDir '$INDEX' --readFilesIn '$R1' '$R2' --readFilesCommand zcat --outFileNamePrefix '$WORK/run-{threads}-' --outSAMtype SAM Unsorted --genomeLoad NoSharedMemory >/dev/null"
