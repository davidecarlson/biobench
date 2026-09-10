#!/usr/bin/env bash
# shellcheck disable=SC2086,SC1091
set -Eeuo pipefail
# Flags intentionally undergo word splitting, with glob expansion disabled.
set -f
if [[ ${1:-} == --help || $# == 0 ]]; then
    echo 'Usage: scripts/build.sh {all|deps|minibwa|minimap2|samtools|blast|salmon}'
    echo 'Environment: ARCH=native JOBS=8 LTO=1 FAST_MATH=0 GCC_MODULE=gcc/13.2.0'
    exit 0
fi
app=$1
case $app in all|deps|minibwa|minimap2|samtools|blast|salmon) ;; *) echo "Unknown application: $app" >&2; exit 2;; esac
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$ROOT/scripts/dependencies.sh"
exec > >(tee "$SOFTWARE/logs/$app-$(date +%Y%m%dT%H%M%S)-$$.log") 2>&1
trap 'echo "Build failed at line $LINENO; see $SOFTWARE/logs" >&2' ERR
setup_compiler
if [[ $app == all ]]; then
    for target in deps minibwa minimap2 samtools blast salmon; do "$ROOT/scripts/build.sh" "$target"; done
    exit 0
fi
if [[ $app == deps ]]; then build_dependencies; exit 0; fi
case $app in
    minibwa) archive=minibwa-0.7.tar.gz; version=0.7 ;;
    minimap2) archive=minimap2-2.31.tar.gz; version=2.31 ;;
    samtools) archive=samtools-1.24.tar.bz2; version=1.24 ;;
    blast) archive=ncbi-blast-2.17.0+-src.tar.gz; version=2.17.0+ ;;
    salmon) archive=salmon-2.7.0.tar.gz; version=2.7.0 ;;
esac
prefix="$SOFTWARE/$app-$version/$ARCH"
mkdir -p "$prefix/bin"
work=$(mktemp -d "$BUILD/$app.XXXXXX")
extract "$archive" "$work"
metadata "$prefix" "$archive"
case $app in
    minibwa|minimap2)
        if [[ $app == minibwa ]]; then
            # The upstream mimalloc rule hard-codes -O3 and omits CFLAGS.
            "$CC" $CFLAGS -std=gnu11 -Wall -Wextra -DNDEBUG -DMI_MALLOC_OVERRIDE \
                -DMI_OSX_INTERPOSE=1 -DMI_OSX_ZONE=1 -I"$work/mimalloc" \
                -c "$work/mimalloc/static.c" -o "$work/mimalloc.o"
            make -C "$work" -j "$JOBS" CC="$CC" AR="$AR" \
                CFLAGS="$CFLAGS -std=c99" CPPFLAGS="$CPPFLAGS" LDFLAGS="$LDFLAGS"
        else
            make -C "$work" -j "$JOBS" CC="$CC" AR="$AR" CFLAGS="$CFLAGS" \
                CPPFLAGS="$CPPFLAGS -DHAVE_KALLOC" LIBS="$LDFLAGS -lm -lz -lpthread"
        fi
        install -m755 "$work/$app" "$prefix/bin/"
        install -m644 "$work/LICENSE.txt" "$prefix/"
        if [[ $app == minibwa ]]; then "$prefix/bin/$app" version; else "$prefix/bin/$app" --version; fi
        ;;
    samtools)
        build_dependencies
        (cd "$work" && ./configure --prefix="$prefix" --enable-libcurl --with-libdeflate \
            && make -j "$JOBS" && make test && make install)
        "$prefix/bin/samtools" --version
        ;;
    blast)
        build_dependencies
        # BLAST's configure wrapper supplies its release, MT and OpenMP defaults.
        (cd "$work/c++" && AR="$AR cr" FAST_CFLAGS="$CFLAGS" FAST_CXXFLAGS="$CXXFLAGS" \
          FAST_LDFLAGS="$LDFLAGS" ./configure --prefix="$prefix" --without-debug \
          --with-build-root="$work/c++/ReleaseMT" --without-caution \
          --without-boost --without-lmdb --without-openssl --without-fastcgi \
          --without-fastcgipp --without-libuv --without-libssh --without-libssh2 \
          --with-sqlite3="$DEPS" \
            && make -C ReleaseMT/build -j "$JOBS" all_r)
        # The toolkit can return success while skipping applications.
        for program in blastn blastp blastx tblastn tblastx psiblast rpsblast rpstblastn deltablast blast_formatter makeblastdb blastdbcmd; do
            test -x "$work/c++/ReleaseMT/bin/$program" || {
                echo "BLAST build omitted required executable: $program" >&2; exit 1;
            }
        done
        cp -a "$work/c++/ReleaseMT/bin/." "$prefix/bin/"
        "$prefix/bin/blastn" -version
        "$prefix/bin/makeblastdb" -version
        ;;
    salmon)
        setup_rust
        RUSTFLAGS="-C target-cpu=${RUST_CPU:-$ARCH} -C linker=$CC -C link-arg=-Wl,-rpath,$(dirname "$("$CXX" -print-file-name=libstdc++.so)")"
        export RUSTFLAGS
        # Rust uses LLVM LTO; GCC LTO objects cannot be consumed by Rust's linker.
        export CFLAGS="${CFLAGS//-flto=$JOBS/}" CXXFLAGS="${CXXFLAGS//-flto=$JOBS/}"
        export CARGO_TARGET_DIR="$work/target"
        (cd "$work" && cargo fetch --locked --target x86_64-unknown-linux-gnu && cargo build --release --locked --offline -j "$JOBS" -p salmon-cli)
        install -m755 "$work/target/release/salmon" "$prefix/bin/"
        { rustc --version; cargo --version; printf 'RUSTFLAGS=%s\nNative CFLAGS=%s\n' "$RUSTFLAGS" "$CFLAGS"; sha256sum "$work/Cargo.lock"; } >> "$prefix/build-info.txt"
        "$prefix/bin/salmon" --version
        ;;
esac
printf 'Installed %s in %s\n' "$app" "$prefix"
