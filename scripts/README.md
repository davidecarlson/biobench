# Build-script reference

See the [repository README](../README.md) for the quick start and dataset layout.

## Entry points

- `build.sh {all|deps|minibwa|minimap2|samtools|blast|salmon|star}`: build/install.
- `fetch-salmon-dependencies.sh`: install private Rust tooling and fetch the
  supplied lockfile's Linux dependencies without compiling Salmon.
- `smoke-test.sh`: functional checks of minibwa, minimap2, SAMtools, BLAST, and Salmon.
- `common.sh`, `dependencies.sh`: shared helpers sourced by the entry points.

Benchmark runners are named `benchmark-APP.sh`; matching `.slurm` files run one
thread count through Slurm. Use `submit-benchmark.sh` to submit a separate job
for every generated count. The runners use Hyperfine with a default sequence of
8-thread increments from 8 through `MAX_THREADS` (192 by default). Set
`THREAD_MODE=scaling` for 1, 2, 4, then 8-thread increments. Override
`THREADS` with a comma-separated list when needed. Set `MAX_THREADS`, `ARCH`,
`RUNS`, `WARMUP`, `RESULTS_DIR`, or `BENCH_WORK`. `install-hyperfine.sh` installs
Hyperfine 1.19.0 with Cargo when it is not already on `PATH`. Timing results
are written as JSON, CSV, and Markdown under `results/`; `best.txt` identifies
the thread count with the lowest mean time.

If `ARCH` is unset, a runner selects `native` when available or the sole other
installed architecture. Set `ARCH` explicitly when several architectures are
installed.

Use `submit-benchmark.sh APP` to submit one Slurm job per generated thread
count. Additional arguments are passed to `sbatch`:

```bash
MAX_THREADS=192 ./scripts/submit-benchmark.sh star --partition=compute
THREAD_MODE=scaling MAX_THREADS=64 ./scripts/submit-benchmark.sh salmon
```

Each job receives one value through `THREADS`, so Hyperfine measures that value
using the configured `RUNS` and `WARMUP`. Shared indexes and databases use a
filesystem lock during first creation. The submitter also requests one task and
the matching `cpus-per-task` value for each job. A cluster configured for
whole-node allocation may still show more allocated CPUs than requested; check
`ReqTRES` and `CPUs/Task` for the actual request.

Single-thread jobs write to `results/APP/ARCH/threads-N/`, so separate Slurm
jobs cannot overwrite one another. A direct runner with several thread values
continues to write the combined result files in `results/APP/ARCH/`.

Scripts run from the current shell. They find source archives in the repository's
`src` directory regardless of the caller's working directory.

## Settings

| Variable | Default | Meaning |
| --- | --- | --- |
| `JOBS` | `8` | Parallel make/Cargo jobs and GCC LTO workers |
| `ARCH` | `native` | GCC architecture and installation directory label |
| `TUNE` | value of ARCH | GCC scheduling/tuning target |
| `LTO` | `1` | Set to 0 to disable GCC LTO |
| `FAST_MATH` | `0` | Set to 1 to enable fast-math explicitly |
| `GCC_MODULE` | auto-selected | Pin a GCC module |
| `SOFTWARE` | repository/software | Installation root |
| `BUILD_ROOT` | SOFTWARE/build | Intermediate build root; ARCH is appended |
| `RUST_TOOLCHAIN` | `stable` | Private Rust toolchain; pin a release for reproducibility |
| `RUST_CPU` | value of ARCH | Override Rust's CPU target spelling |
| `EXTRA_CPPFLAGS` | empty | Additional include/preprocessor flags |
| `EXTRA_LDFLAGS` | empty | Additional linker flags |

Salmon compiles with the supplied Cargo.lock using `--locked --offline` after the
scripts fetch the locked dependencies. Cargo packages and Rust's download cache
live under `src`; installed toolchains live under `software/rustup`. Existing
private toolchains are reused, and new installations download the requested Rust
release. The scripts leave the system Rust installation unchanged.

On systems without access to Rust's download servers, copy a compatible Rust
toolchain and its Cargo cache onto the system, then run Salmon with
`RUST_SYSTEM=1 RUST_OFFLINE=1 CARGO_HOME=/path/to/cargo-home`. `RUST_MODE=auto`
uses a system or module Rust installation when the private toolchain is absent.
The copied Cargo cache must contain every locked package required by Salmon.

## Downloaded dependencies

| Dependency | Pinned source |
| --- | --- |
| libdeflate 1.25 | https://github.com/ebiggers/libdeflate/releases/download/v1.25/libdeflate-1.25.tar.gz |
| curl 8.19.0 | https://curl.se/download/curl-8.19.0.tar.xz |
| SQLite 3.50.4 | https://sqlite.org/2025/sqlite-autoconf-3500400.tar.gz |

Downloads use HTTPS and temporary files. Checksums detect changes to cached
archives. Existing dependency installations are reused. Remove the relevant
`software/deps/ARCH` prefix before rebuilding with different compiler or
optimization settings. Install any system development packages reported by the
checks when moving to another system.

The curl dependency disables symbol hiding because some newer binutils toolchains
produce an empty libtool symbol pipeline otherwise. libdeflate keeps the selected
CPU flags but disables GCC LTO and forces its documented VNNI fallback
implementations because the available assembler rejects `vpdpbusd`. SAMtools
builds its bundled
HTSlib with libcurl and libdeflate. Minibwa's bundled
mimalloc is explicitly compiled with the selected optimization flags because its
Makefile otherwise hard-codes that object's flags. BLAST uses its bundled LMDB
(`--without-lmdb` selects the internal copy), the toolkit's `AR="gcc-ar cr"`
convention, and the `all_r` target. SQLite is required explicitly so configuration
fails promptly if it is unavailable. Installation checks that the principal
BLAST executables were actually produced: the upstream makefiles can otherwise
return success while skipping projects with unmet requirements. Optional SRA/VDB
integration remains disabled as in the upstream release wrapper.

## Artifacts and cleanup

Each application uses a fresh extracted build tree. Installed binaries, compiler
metadata, and timestamped logs are written beneath `SOFTWARE`. Failed build
trees remain available for diagnosis. After validation, remove `software/build`
or the selected `BUILD_ROOT` if space is needed. Keep application installations,
dependency prefixes, source archives, and Cargo/Rust caches for reuse.

Native binaries are specific to the CPU that produced them. The validated
Skylake installations use `software/APP-VERSION/skylake-avx512/bin`; they should
be tested and benchmarked on compatible CPUs.
