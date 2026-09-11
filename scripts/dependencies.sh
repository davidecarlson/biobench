#!/usr/bin/env bash
# Source after common.sh and setup_compiler.
# Compiler flags intentionally split; common.sh disables glob expansion.
# shellcheck disable=SC2086
build_dependencies() {
    # System zlib, bzip2, xz, OpenSSL and curses development packages are present
    # on this cluster. Check with the selected compiler, not only package metadata.
    local header lib
    for pair in zlib.h:z bzlib.h:bz2 lzma.h:lzma openssl/ssl.h:ssl curses.h:ncurses; do
        header=${pair%:*}; lib=${pair#*:}
        printf '#include <%s>\nint main(void){return 0;}\n' "$header" |
            "$CC" $CPPFLAGS -x c - -o "$BUILD/dependency-check" $LDFLAGS -l"$lib" || {
                echo "Missing system dependency $header; see scripts/README.md" >&2; return 1;
            }
    done
    local work
    if [[ ! -f $DEPS/lib/pkgconfig/sqlite3.pc ]]; then
        fetch sqlite-autoconf-3500400.tar.gz https://sqlite.org/2025/sqlite-autoconf-3500400.tar.gz
        work=$(mktemp -d "$BUILD/sqlite.XXXXXX")
        extract sqlite-autoconf-3500400.tar.gz "$work"
        (cd "$work" && CFLAGS="$CFLAGS -DSQLITE_ENABLE_UNLOCK_NOTIFY" \
            ./configure --prefix="$DEPS" --libdir="$DEPS/lib" --disable-readline \
            && make -j "$JOBS" && make install)
    fi
    if [[ ! -f $DEPS/lib/pkgconfig/libdeflate.pc ]]; then
        fetch libdeflate-1.25.tar.gz https://github.com/ebiggers/libdeflate/releases/download/v1.25/libdeflate-1.25.tar.gz
        work=$(mktemp -d "$BUILD/libdeflate.XXXXXX")
        extract libdeflate-1.25.tar.gz "$work"
        # Keep libdeflate out of GCC LTO: some system assemblers reject
        # instructions emitted by the LTO-generated temporary assembly.
        local libdeflate_cflags libdeflate_ldflags
        libdeflate_cflags=$(printf '%s\n' "$CFLAGS" | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]+)?//g')
        libdeflate_ldflags=$(printf '%s\n' "$LDFLAGS" | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]+)?//g')
        CFLAGS="$libdeflate_cflags" LDFLAGS="$libdeflate_ldflags" \
        cmake -S "$work" -B "$work/build" -DCMAKE_INSTALL_PREFIX="$DEPS" \
            -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_COMPILER="$CC" -DCMAKE_C_FLAGS_RELEASE="$libdeflate_cflags" \
            -DCMAKE_C_FLAGS="$libdeflate_cflags" -DCMAKE_EXE_LINKER_FLAGS="$libdeflate_ldflags" \
            -DCMAKE_SHARED_LINKER_FLAGS="$libdeflate_ldflags" \
            -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON
        cmake --build "$work/build" --parallel "$JOBS"
        cmake --install "$work/build"
    fi
    if [[ ! -f $DEPS/lib/pkgconfig/libcurl.pc ]]; then
        fetch curl-8.19.0.tar.xz https://curl.se/download/curl-8.19.0.tar.xz
        work=$(mktemp -d "$BUILD/curl.XXXXXX")
        extract curl-8.19.0.tar.xz "$work"
        (cd "$work" && ./configure --prefix="$DEPS" --libdir="$DEPS/lib" \
            --with-openssl --with-zlib --without-libpsl --without-libidn2 \
            --without-brotli --without-zstd --without-nghttp2 --without-libssh2 \
            --disable-ldap --disable-ldaps --disable-docs --disable-symbol-hiding &&
            make -j "$JOBS" && make install)
    fi
}

setup_rust() {
    local rust_mode=${RUST_MODE:-auto}
    if [[ ${RUST_SYSTEM:-0} == 1 ]]; then
        command -v cargo >/dev/null 2>&1 && command -v rustc >/dev/null 2>&1 &&
            cargo --version >/dev/null 2>&1 && rustc --version >/dev/null 2>&1 || {
            echo 'RUST_SYSTEM=1 requires cargo and rustc on PATH' >&2; return 1;
        }
        echo "Using system/module Rust: $(rustc --version)"
        return 0
    fi
    if [[ $rust_mode == auto ]] && command -v cargo >/dev/null 2>&1 && command -v rustc >/dev/null 2>&1 && cargo --version >/dev/null 2>&1 && rustc --version >/dev/null 2>&1 && [[ ! -x $SOFTWARE/rustup/toolchains/${RUST_TOOLCHAIN:-stable}-x86_64-unknown-linux-gnu/bin/rustc ]]; then
        echo "Using system/module Rust: $(rustc --version)"
        return 0
    fi
    [[ $rust_mode == private || $rust_mode == auto ]] || {
        echo 'RUST_MODE must be auto or private' >&2; return 2;
    }
    # Keep the user's existing Rust installation untouched; all downloaded
    # registry/git dependencies and rustup downloads live beneath src.
    export CARGO_HOME="$SRC/cargo-home"
    export RUSTUP_HOME="$SOFTWARE/rustup"
    mkdir -p "$CARGO_HOME" "$RUSTUP_HOME" "$SRC/rust-downloads"
    if [[ ! -e $RUSTUP_HOME/downloads ]]; then ln -s "$SRC/rust-downloads" "$RUSTUP_HOME/downloads"; fi
    export PATH="$CARGO_HOME/bin:$PATH"
    if [[ ! -x $CARGO_HOME/bin/rustup ]]; then
        fetch rustup-init https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init
        chmod +x "$SRC/rustup-init"
        "$SRC/rustup-init" -y --no-modify-path --profile minimal --default-toolchain "${RUST_TOOLCHAIN:-stable}"
    fi
    if ! rustup run "${RUST_TOOLCHAIN:-stable}" rustc --version >/dev/null 2>&1; then
        rustup toolchain install "${RUST_TOOLCHAIN:-stable}" --profile minimal
    fi
    export RUSTUP_TOOLCHAIN=${RUST_TOOLCHAIN:-stable}
}

cargo_fetch() {
    if [[ ${RUST_OFFLINE:-0} == 1 ]]; then
        cargo fetch --locked --offline --target x86_64-unknown-linux-gnu
    else
        cargo fetch --locked --target x86_64-unknown-linux-gnu
    fi
}
