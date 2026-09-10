# Build-script reference

See the [repository README](../README.md) for the quick start and dataset layout.

## Entry points

- `build.sh {all|deps|minibwa|minimap2|samtools|blast|salmon}`: build/install.
- `fetch-salmon-dependencies.sh`: install private Rust tooling and fetch the
  supplied lockfile's Linux dependencies without compiling Salmon.
- `smoke-test.sh`: functional checks of all five installed applications.
- `common.sh`, `dependencies.sh`: shared helpers sourced by the entry points.

Benchmark runners are named `benchmark-APP.sh`; matching `.slurm` files submit
the same runner through Slurm. They use Hyperfine with a default thread list
of `8,16,32,64,96,128,160,192`. Override `THREADS`, `ARCH`, `RUNS`,
`WARMUP`, `RESULTS_DIR`, or `BENCH_WORK`. `install-hyperfine.sh` installs
Hyperfine 1.19.0 with Cargo when it is not already on `PATH`. Timing results
are written as JSON and Markdown under `results/`.

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

SAMtools builds its bundled HTSlib with libcurl and libdeflate. Minibwa's bundled
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
