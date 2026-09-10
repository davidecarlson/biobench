#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/benchmark-common.sh"
BIN="$SOFTWARE/samtools-1.24/$ARCH/bin/samtools"; BAM="$DATA/bam/HG002_combined_PacBio_CCS_15kb_1Msubsample.bam"
require_file "$BIN"; require_file "$BAM"
run_hyperfine samtools "'$BIN' sort -@ {threads} -m 1G -O BAM -o /dev/null '$BAM'"
