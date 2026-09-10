#!/usr/bin/env bash
# shellcheck disable=SC2086,SC1090
# Shared build configuration. Source from Bash.
set -Eeuo pipefail
# Compiler flag strings intentionally split into separate arguments.
set -f
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SRC="$ROOT/src"
SOFTWARE=${SOFTWARE:-$ROOT/software}
mkdir -p "$SOFTWARE" "$SRC"
SOFTWARE=$(cd "$SOFTWARE" && pwd)
JOBS=${JOBS:-8}
[[ $JOBS =~ ^[1-9][0-9]*$ ]] || { echo 'JOBS must be a positive integer' >&2; exit 2; }
ARCH=${ARCH:-native}
[[ $ARCH =~ ^[a-zA-Z0-9_.+-]+$ ]] || { echo 'Invalid ARCH' >&2; exit 2; }
BUILD_ROOT=${BUILD_ROOT:-$SOFTWARE/build}
BUILD="$BUILD_ROOT/$ARCH"
DEPS="$SOFTWARE/deps/$ARCH"
mkdir -p "$BUILD" "$DEPS" "$SOFTWARE/logs"
BUILD=$(cd "$BUILD" && pwd)

setup_compiler() {
    if ! type module &>/dev/null; then
        for init in /etc/profile.d/modules.sh /usr/share/Modules/init/bash; do
            if [[ -r $init ]]; then source "$init"; break; fi
        done
    fi
    if type module &>/dev/null; then
        local available newest current
        available=$(module -t avail gcc 2>&1) || { echo "$available" >&2; return 1; }
        newest=$(printf '%s\n' "$available" | sed -nE 's@^[[:space:]]*(gcc/[0-9]+(\.[0-9]+)*).*@\1@p' | sort -Vu | tail -1)
        current=$(gcc -dumpfullversion -dumpversion 2>/dev/null || true)
        if [[ -n ${GCC_MODULE:-} ]]; then
            module load "$GCC_MODULE"
        elif [[ -n $newest && $(printf '%s\n' "$current" "${newest#gcc/}" | sort -V | tail -1) == "${newest#gcc/}" ]]; then
            module load "$newest"
        fi
    elif [[ -n ${GCC_MODULE:-} ]]; then
        echo 'GCC_MODULE requested but modules are unavailable' >&2; return 1
    fi
    CC=$(command -v gcc); CXX=$(command -v g++)
    AR=$(command -v gcc-ar); RANLIB=$(command -v gcc-ranlib)
    export CC CXX AR RANLIB
    OPT="-O3 -march=$ARCH -mtune=${TUNE:-$ARCH}"
    [[ ${LTO:-1} == 0 ]] || OPT+=" -flto=$JOBS"
    [[ ${FAST_MATH:-0} == 0 ]] || OPT+=' -ffast-math'
    export CFLAGS="$OPT" CXXFLAGS="$OPT"
    export CPPFLAGS="-I$DEPS/include ${EXTRA_CPPFLAGS:-}"
    local gcc_lib
    gcc_lib=$(dirname "$("$CXX" -print-file-name=libstdc++.so)")
    export LDFLAGS="$OPT -L$DEPS/lib -Wl,-rpath,$DEPS/lib -Wl,-rpath,$gcc_lib ${EXTRA_LDFLAGS:-}"
    export PKG_CONFIG_PATH="$DEPS/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    export LD_LIBRARY_PATH="$DEPS/lib:$gcc_lib:${LD_LIBRARY_PATH:-}"
    export CMAKE_PREFIX_PATH="$DEPS:${CMAKE_PREFIX_PATH:-}"
    printf 'Compiler: %s\nFlags: %s\n' "$("$CC" --version | head -1)" "$OPT"
    printf 'int main(void){return 0;}\n' | "$CC" $CFLAGS -x c - -o "$BUILD/compiler-check"
    "$BUILD/compiler-check"
}

fetch() {
    local name=$1 url=$2
    if [[ ! -s $SRC/$name ]]; then
        curl --fail --location --retry 3 --proto '=https' "$url" -o "$SRC/$name.part"
        mv "$SRC/$name.part" "$SRC/$name"
    fi
    if [[ -f $SRC/$name.sha256 ]]; then
        (cd "$SRC" && sha256sum --check "$name.sha256")
    else
        (cd "$SRC" && sha256sum "$name" > "$name.sha256")
    fi
}

extract() {
    local archive=$1 dest=$2
    # A fresh private source tree avoids mixing objects built with different flags.
    mkdir -p "$dest"
    tar --extract --file="$SRC/$archive" --directory="$dest" --strip-components=1 --no-same-owner
}

metadata() {
    local prefix=$1 archive=$2
    {
        date -u +'%FT%TZ'
        printf 'archive=%s\narch=%s\njobs=%s\nCC=%s\nCXX=%s\nCFLAGS=%s\nCXXFLAGS=%s\nLDFLAGS=%s\n' "$archive" "$ARCH" "$JOBS" "$CC" "$CXX" "$CFLAGS" "$CXXFLAGS" "$LDFLAGS"
        "$CC" --version
        sha256sum "$SRC/$archive"
        lscpu
        if type module &>/dev/null; then module list 2>&1; fi
    } > "$prefix/build-info.txt"
}
