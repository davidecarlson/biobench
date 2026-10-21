#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/benchmark-common.sh"

select_arch kraken2 2.18.0-RC1 kraken2
BIN="$SOFTWARE/kraken2-2.18.0-RC1/$ARCH/bin/kraken2"
R1="$DATA/fastq/HG002_NA24385_combined_10M.1.fq.gz"
R2="$DATA/fastq/HG002_NA24385_combined_10M.2.fq.gz"
require_file "$BIN"
require_file "$R1"
require_file "$R2"

: "${KRAKEN2_DB:?Set KRAKEN2_DB to a prepared Kraken2 database directory}"
[ -d "$KRAKEN2_DB" ] || { echo "Missing Kraken2 database: $KRAKEN2_DB" >&2; exit 1; }

run_hyperfine kraken2 "'$BIN' --db '$KRAKEN2_DB' --threads {threads} --paired --gzip-compressed --output /dev/null --report /dev/null '$R1' '$R2'"
