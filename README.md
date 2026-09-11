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
| STAR | 2.7.11b | Spliced RNA-seq alignment | GCC/G++ |

## Build

Run on a Linux x86-64 machine with enough CPU, RAM, and storage:

```bash
./scripts/build.sh all
# Build a single application:
./scripts/build.sh blast
# Build STAR:
./scripts/build.sh star
# Choose parallelism and the benchmark CPU explicitly:
JOBS=32 ARCH=skylake-avx512 ./scripts/build.sh all
```

The build runs in the current shell. `JOBS` defaults to 8 and `ARCH` defaults to
`native`, which targets the current machine. Use an explicit architecture when
building for another benchmark machine. Examples include `znver3` for AMD EPYC
Milan and `skylake-avx512` for compatible Intel Xeon processors. The target CPU
must support the selected instruction set.

The scripts choose the newest versioned GCC module unless GCC on `PATH` is
newer. GCC 13.2.0 was available during validation. Set
`GCC_MODULE=gcc/13.2.0` to pin the module. Systems without modules use GCC/G++
from PATH.

The default optimization flags are `-O3 -march=$ARCH -mtune=$ARCH -flto=$JOBS`.
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
and development libraries for zlib, bzip2, xz/liblzma, OpenSSL, and ncurses.
The scripts download missing libcurl, libdeflate, and SQLite sources into `src`
and build them under `software/deps/ARCH`. They also install Salmon's private
Rust toolchain and fetch its locked Cargo dependencies. The first build needs
network access. If Rust downloads are blocked, copy a compatible Rust
installation and Cargo cache onto the host and set
`RUST_SYSTEM=1 RUST_OFFLINE=1 CARGO_HOME=...` for the Salmon build. See the
build-script reference for the required cache contents.

See [build details](scripts/README.md) for dependency versions, overrides and
rebuild behavior.

## Benchmark

Each application has a direct runner and a Slurm wrapper in `scripts/`:

```bash
MAX_THREADS=192 ./scripts/benchmark-minimap2.sh
MAX_THREADS=192 sbatch scripts/benchmark-minimap2.slurm
# Optional scaling sequence: 1,2,4,8,16,24,...,MAX_THREADS
THREAD_MODE=scaling MAX_THREADS=64 ./scripts/benchmark-minimap2.sh
MAX_THREADS=192 ./scripts/benchmark-star.sh
```

When `ARCH` is unset, each runner uses `native` if installed or the only other
installed architecture. Set `ARCH` explicitly when more than one architecture
is installed. The default sequence starts at 8 threads and increases by 8
through `MAX_THREADS` (192 by default). Set `THREAD_MODE=scaling` to use 1, 2,
4, then 8-thread increments. You can set `THREADS` to a comma-separated list
as an advanced override. Set `RUNS`, `WARMUP`, `RESULTS_DIR`, or `BENCH_WORK`
as needed. Results are JSON
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

The supplied source archives, datasets, installed software, and dependency
caches stay local. Git tracks the build scripts and documentation. Preserve the
archives in `src` when removing intermediate build trees.

## Benchmark inputs

- `data/ref/`: GRCh38 primary-assembly reference genome.
- `data/fastq/`: HG002 paired short reads, RNA-seq reads, and PacBio CCS reads.
- `data/bam/`: HG002 PacBio CCS alignments.
- `data/blast/`: GENCODE v46 transcript and protein sequence subsets.

Inputs are supplied separately. Generate reference indexes and BLAST/Salmon
databases with the relevant application before timing workloads. The smoke tests
use small synthetic inputs and leave these datasets unchanged.

## Validate

Run on a CPU compatible with the selected installed binaries:

```bash
ARCH=skylake-avx512 ./scripts/smoke-test.sh
```

The checks exercise minibwa/minimap2 mapping, SAMtools BAM conversion and
validation, BLAST database creation/search, and Salmon indexing/quantification.
STAR is version-checked during its build and has a separate benchmark runner.
Synthetic inputs and results remain in `software/smoke.*`. SAMtools also runs
its upstream test suite during its build.

Record input checksums, command lines, thread counts, CPU model, application
version, and build settings with benchmark results. Each installation includes
these build details in `build-info.txt`.
