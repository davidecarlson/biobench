#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
DB_ROOT=${KRAKEN2_DB_ROOT:-$ROOT/data/kraken2}
DB_NAME=k2_standard_08_GB_20260626
URL="https://genome-idx.s3.amazonaws.com/kraken/${DB_NAME}.tar.gz"
DB="$DB_ROOT/$DB_NAME"
ARCHIVE="$DB_ROOT/$DB_NAME.tar.gz"

is_database() {
    local path=$1
    [ -s "$path/hash.k2d" ] && [ -s "$path/opts.k2d" ] && [ -s "$path/taxo.k2d" ]
}

mkdir -p "$DB_ROOT"
if is_database "$DB"; then
    printf '%s\n' "$DB"
    exit 0
fi

lock="$DB_ROOT/.${DB_NAME}.lock"
while ! mkdir "$lock" 2>/dev/null; do
    if is_database "$DB"; then printf '%s\n' "$DB"; exit 0; fi
    sleep 5
done
cleanup() { rmdir "$lock" 2>/dev/null || true; }
trap cleanup EXIT

if [ ! -s "$ARCHIVE" ]; then
    curl --fail --location --retry 3 --proto '=https' "$URL" -o "$ARCHIVE.part"
    mv "$ARCHIVE.part" "$ARCHIVE"
fi

if ! tar -tzf "$ARCHIVE" >/dev/null; then
    echo "Invalid Kraken2 database archive: $ARCHIVE" >&2
    exit 1
fi

tmp=$(mktemp -d "$DB_ROOT/.${DB_NAME}.XXXXXX")
trap 'rm -rf "$tmp"; cleanup' EXIT
tar -xzf "$ARCHIVE" -C "$tmp" --no-same-owner

if [ -d "$tmp/$DB_NAME" ]; then
    extracted="$tmp/$DB_NAME"
else
    extracted="$tmp"
fi
if ! is_database "$extracted"; then
    echo "Kraken2 archive did not contain a complete database" >&2
    exit 1
fi
mkdir -p "$DB"
cp -a "$extracted"/. "$DB/"
is_database "$DB" || { echo "Kraken2 database validation failed: $DB" >&2; exit 1; }
printf '%s\n' "$DB"
