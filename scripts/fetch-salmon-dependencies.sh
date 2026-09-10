#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
# Download toolchain and locked crates without compiling Salmon.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$ROOT/scripts/dependencies.sh"
setup_rust
work=$(mktemp -d "$BUILD/salmon-fetch.XXXXXX")
extract salmon-2.7.0.tar.gz "$work"
cd "$work"
cargo fetch --locked --target x86_64-unknown-linux-gnu
