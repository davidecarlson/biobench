# Build-script reference

See the [repository README](../README.md) for the quick start and dataset layout.

## Entry points

- `build.sh {all|deps|minibwa|minimap2|samtools|blast|salmon}`: build/install.
- `fetch-salmon-dependencies.sh`: install private Rust tooling and fetch the
  supplied lockfile's Linux dependencies without compiling Salmon.
- `smoke-test.sh`: functional checks of all five installed applications.
- `common.sh`, `dependencies.sh`: shared helpers sourced by the entry points.

Scripts run directly, without a scheduler. Source archives are read from `src`
relative to the repository, regardless of the caller's working directory.

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

Salmon compiles with the supplied Cargo.lock using `--locked --offline` after
fetching the locked dependencies. Cargo packages and Rust's download cache live
under `src`; installed toolchains live under `software/rustup`. Existing private
toolchains are reused. A new private installation downloads the requested Rust
release. The system/user Rust installation is untouched.

## Downloaded dependencies

| Dependency | Pinned source |
| --- | --- |
| libdeflate 1.25 | https://github.com/ebiggers/libdeflate/releases/download/v1.25/libdeflate-1.25.tar.gz |
| curl 8.19.0 | https://curl.se/download/curl-8.19.0.tar.xz |
| SQLite 3.50.4 | https://sqlite.org/2025/sqlite-autoconf-3500400.tar.gz |

Downloads use HTTPS and temporary files; checksums detect changes to cached
archives. Existing private dependency installations are reused. Remove the
relevant `software/deps/ARCH` prefix before rebuilding dependencies with changed
compiler/optimization settings. On another system, install any missing system
development packages reported by the checks.

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
metadata and timestamped logs are written beneath SOFTWARE. Failed build trees
are retained for diagnosis. Once validation succeeds, `software/build` (or the
chosen BUILD_ROOT) can be removed. Keep application installations, dependency
prefixes, source archives and Cargo/Rust caches for reuse.

Native binaries are specific to the CPU that produced them. The validated
Skylake installations use `software/APP-VERSION/skylake-avx512/bin`; they should
be tested and benchmarked on compatible CPUs.
