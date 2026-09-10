#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SOFTWARE=${SOFTWARE:-$ROOT/software}
ARCH=${ARCH:-native}
work=$(mktemp -d "$SOFTWARE/smoke.XXXXXX")
python3 - "$work" <<'PY'
import random, sys
from pathlib import Path
r=random.Random(42)
s=''.join(r.choice('ACGT') for _ in range(2000))
p=Path(sys.argv[1])
(p/'ref.fa').write_text('>ref\n'+s+'\n')
(p/'read.fa').write_text('>read\n'+s[500:1000]+'\n')
(p/'reads.fq').write_text(''.join('@r%d\n%s\n+\n%s\n' % (i,s[i:i+100],'I'*100) for i in range(100,1100)))
PY
"$SOFTWARE/minimap2-2.31/$ARCH/bin/minimap2" -a "$work/ref.fa" "$work/read.fa" > "$work/mm.sam"
"$SOFTWARE/minibwa-0.7/$ARCH/bin/minibwa" index "$work/ref.fa"
"$SOFTWARE/minibwa-0.7/$ARCH/bin/minibwa" map "$work/ref.fa" "$work/read.fa" > "$work/mb.sam"
"$SOFTWARE/samtools-1.24/$ARCH/bin/samtools" view -b -o "$work/read.bam" "$work/mm.sam"
"$SOFTWARE/samtools-1.24/$ARCH/bin/samtools" quickcheck "$work/read.bam"
[[ $("$SOFTWARE/samtools-1.24/$ARCH/bin/samtools" view -c -F 4 "$work/read.bam") -ge 1 ]]
[[ $("$SOFTWARE/samtools-1.24/$ARCH/bin/samtools" view -c -F 4 "$work/mb.sam") -ge 1 ]]
"$SOFTWARE/blast-2.17.0+/$ARCH/bin/makeblastdb" -in "$work/ref.fa" -dbtype nucl -out "$work/db"
"$SOFTWARE/blast-2.17.0+/$ARCH/bin/blastn" -query "$work/read.fa" -db "$work/db" -outfmt 6 -out "$work/hits.tsv"
test -s "$work/hits.tsv"
"$SOFTWARE/salmon-2.7.0/$ARCH/bin/salmon" index -t "$work/ref.fa" -i "$work/salmon-index" -p 2
"$SOFTWARE/salmon-2.7.0/$ARCH/bin/salmon" quant -i "$work/salmon-index" -l U -r "$work/reads.fq" -o "$work/quant" -p 2 --fldMean 150 --fldSD 20
python3 - "$work/quant/quant.sf" <<'PYQUANT'
import csv, sys
with open(sys.argv[1]) as f:
    rows=list(csv.DictReader(f, delimiter="\t"))
assert rows and sum(float(row["NumReads"]) for row in rows) > 0
PYQUANT
printf 'Smoke checks passed; artifacts: %s\n' "$work"
