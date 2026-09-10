# Bioinformatics application benchmarks

This repository prepares optimized builds of bioinformatics applications and
holds inputs for benchmarking read alignment, sequence search, RNA-seq
quantification, and BAM/CRAM processing. It provides build, validation, and
Hyperfine timing scripts.

## Applications

| Application | Source version | Purpose | Compiler |
| --- | --- | --- | --- |
| minibwa | 0.7 | Short-read alignment | GCC |
| minimap2 | 2.31 | Read alignment | GCC |
| SAMtools | 1.24 | Alignment-file processing | GCC |
| NCBI BLAST+ | 2.17.0+ | Sequence similarity search | GCC/G++ |
| Salmon | 2.7.0 | Transcript quantification | Rust, plus GCC for native dependencies |

## Build

Run directly on a Linux x86-64 machine with sufficient CPU, RAM and storage:

```bash
./scripts/build.sh all
# Build a single application:
./scripts/build.sh blast
# Choose parallelism and the benchmark CPU explicitly:
JOBS=32 ARCH=skylake-avx512 ./scripts/build.sh all
```

No Slurm submission is required or performed. `JOBS` defaults to 8 and `ARCH`
defaults to `native`. `native` targets the machine performing the build; use an
explicit architecture when building for a different benchmark machine. Examples
include `znver3` for AMD EPYC Milan and `skylake-avx512` for compatible Intel
Xeon processors. Executables require a CPU supporting their compiled instruction
set.

The scripts choose the newest available versioned GCC module, unless GCC on
PATH is newer. GCC 13.2.0 was available during validation. Set
`GCC_MODULE=gcc/13.2.0` to pin the module. Systems without modules use GCC/G++
from PATH.

Default optimization is `-O3 -march=$ARCH -mtune=$ARCH -flto=$JOBS`.
`LTO=0` disables GCC link-time optimization; `FAST_MATH=1` explicitly enables
floating-point transformations that can alter numerical results. Fast-math is
off by default. Salmon uses its Rust release profile with optimization level 3,
thin LTO, one codegen unit, and a CPU-specific target. GCC LTO is omitted for its
native dependencies because Rust uses LLVM bitcode.

For faster intermediate builds on local storage:

```bash
BUILD_ROOT=/fast/local/biobench JOBS=32 ./scripts/build.sh all
```

Build prerequisites include Bash, GNU make, GCC/G++, Python 3, CMake, curl, tar,
and the development libraries for zlib, bzip2, xz/liblzma, OpenSSL and ncurses
already available on this system. Missing libcurl, libdeflate and SQLite are
downloaded into `src` and built under `software/deps/ARCH`. Salmon's private Rust
toolchain and locked Cargo dependencies are also installed/downloaded by the
scripts, without changing the user's existing Rust installation. First-time
setup requires network access.

See [build details](scripts/README.md) for dependency versions, overrides and
rebuild behavior.

## Benchmark

Each application has a direct runner and a Slurm wrapper in `scripts/`:

```bash
THREADS=8,16,32,64,96,128,160,192 ./scripts/benchmark-minimap2.sh
THREADS=8,16,32,64,96,128,160,192 sbatch scripts/benchmark-minimap2.slurm
```

The default thread list is 8 through 192. Set `THREADS`, `ARCH`, `RUNS`,
`WARMUP`, `RESULTS_DIR`, or `BENCH_WORK` in the environment. Results are JSON
and Markdown files under `results/APP/ARCH/`; reusable indexes are under
`results/work/`. Hyperfine is used from `PATH`, or installed with
`scripts/install-hyperfine.sh` under `software/hyperfine`. Adjust the Slurm
resource directives for the target cluster.

## Repository layout

```text
src/                   Supplied source archives and downloaded dependencies
scripts/               Build and functional-validation scripts
software/
  APP-VERSION/ARCH/     Installed applications, including bin/ and build-info.txt
  deps/ARCH/           Private dependency installations
  build/ARCH/          Extracted sources and intermediate builds (default)
  logs/                Timestamped build output
  rustup/              Private Rust toolchains
data/                 Benchmark inputs (described below)
```

`SOFTWARE` can override the installation root. Each build uses a fresh source
tree. Changing ARCH creates a separate installation; changing flags under the
same ARCH replaces that application's installed binary. Do not concurrently
build the same application or dependency prefix.

The supplied source archives, datasets, installed software and dependency caches
are local inputs/artifacts, not part of the build-script commit. Preserve the
archives in `src` when cleaning intermediate build trees.

## Benchmark inputs

- `data/ref/`: GRCh38 primary-assembly reference genome.
- `data/fastq/`: HG002 paired short reads, RNA-seq reads, and PacBio CCS reads.
- `data/bam/`: HG002 PacBio CCS alignments.
- `data/blast/`: GENCODE v46 transcript and protein sequence subsets.

Inputs are supplied separately. Reference indexes and BLAST/Salmon databases
must be generated with the appropriate application before timing workloads.
The smoke tests use small synthetic inputs and do not modify these datasets.

## Validate

Run on a CPU compatible with the selected installed binaries:

```bash
ARCH=skylake-avx512 ./scripts/smoke-test.sh
```

The checks exercise minibwa/minimap2 mapping, SAMtools BAM conversion and
validation, BLAST database creation/search, and Salmon indexing/quantification.
Synthetic inputs and results remain in `software/smoke.*`. SAMtools also runs
its upstream test suite during its build.

For repeatable benchmarks, record input checksums, command lines, thread counts,
CPU model, application version, and build settings. Each installed application's
`build-info.txt` records its source checksum, compiler, flags and CPU details.
