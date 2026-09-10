#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SOFTWARE=${SOFTWARE:-$ROOT/software}
VERSION=${HYPERFINE_VERSION:-1.19.0}
PREFIX=${HYPERFINE_PREFIX:-$SOFTWARE/hyperfine}
mkdir -p "$PREFIX/bin"
if [ -x "$PREFIX/bin/hyperfine" ]; then
    "$PREFIX/bin/hyperfine" --version
    exit 0
fi
if command -v hyperfine >/dev/null 2>&1; then
    install -m 0755 "$(command -v hyperfine)" "$PREFIX/bin/hyperfine"
elif command -v cargo >/dev/null 2>&1; then
    cargo install hyperfine --version "$VERSION" --locked --root "$PREFIX"
else
    echo "Install Cargo or provide hyperfine on PATH." >&2
    exit 1
fi
"$PREFIX/bin/hyperfine" --version
