#!/bin/bash
#
# Creates AudioGridder-<version>-source.tar.gz from a committed ref (default HEAD), including all
# submodules (JUCE, clap-juce-extensions and its nested submodules) at the commits they are pinned
# to. GitHub's automatic source downloads do not contain submodules.
#
#   package/makeSourceArchive.sh [output dir] [ref]
#
# The submodules have to be checked out (git submodule update --init --recursive).

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="${1:-$ROOT/package/build/release}"
REF="${2:-HEAD}"
VER=$(git show "$REF:package/VERSION.num")
NAME="AudioGridder-$VER-source"

WORK=$(mktemp -d -t agsource)
trap 'rm -rf "$WORK"' EXIT

# Exports a repository at a ref and then every submodule it contains, recursively.
export_tree() {
    local repo=$1 ref=$2 prefix=$3
    git -C "$repo" archive --format=tar --prefix="$prefix/" "$ref" | tar -x -C "$WORK"
    git -C "$repo" ls-tree -r "$ref" | awk '$1 == "160000" { print $3, $4 }' | while read -r sha path; do
        if ! git -C "$repo/$path" cat-file -e "$sha^{commit}" 2>/dev/null; then
            echo "error: submodule $prefix/$path at $sha is not available, run git submodule update --init --recursive" >&2
            exit 1
        fi
        export_tree "$repo/$path" "$sha" "$prefix/$path"
    done
}

export_tree "$ROOT" "$REF" "$NAME"

mkdir -p "$OUT"
# COPYFILE_DISABLE and --no-mac-metadata keep macOS AppleDouble (._*) files out of the archive
COPYFILE_DISABLE=1 tar -czf "$WORK/$NAME.tar.gz" --no-mac-metadata -C "$WORK" "$NAME"
cp "$WORK/$NAME.tar.gz" "$OUT/"

echo "$OUT/$NAME.tar.gz ($REF $(git rev-parse --short "$REF"), $(git submodule status --recursive | wc -l | tr -d ' ') submodules)"
