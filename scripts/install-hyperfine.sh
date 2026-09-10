#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SOFTWARE=${SOFTWARE:-$ROOT/software}
VERSION=${HYPERFINE_VERSION:-1.19.0}
PREFIX=${HYPERFINE_PREFIX:-$SOFTWARE/hyperfine}
if command -v hyperfine >/dev/null 2>&1; then hyperfine --version; exit 0; fi
command -v cargo >/dev/null 2>&1 || { echo "Install Cargo or provide hyperfine on PATH." >&2; exit 1; }
mkdir -p "$PREFIX"
cargo install hyperfine --version "$VERSION" --locked --root "$PREFIX"
"$PREFIX/bin/hyperfine" --version
