#!/bin/bash
#
# Creates AudioGridder-<version>-source.tar.gz from the committed HEAD, including
# the JUCE submodule at the commit it is pinned to. GitHub's automatic source
# downloads do not contain submodules.
#
#   package/makeSourceArchive.sh [output dir]

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="${1:-$ROOT/package/build/release}"
VER=$(git show HEAD:package/VERSION.num)
NAME="AudioGridder-$VER-source"
JUCE_COMMIT=$(git ls-tree HEAD JUCE | awk '{print $3}')

if ! git -C JUCE cat-file -e "$JUCE_COMMIT^{commit}" 2>/dev/null; then
    echo "error: JUCE commit $JUCE_COMMIT is not available, run git submodule update --init" >&2
    exit 1
fi

WORK=$(mktemp -d -t agsource)
trap 'rm -rf "$WORK"' EXIT

git archive --format=tar --prefix="$NAME/" HEAD | tar -x -C "$WORK"
git -C JUCE archive --format=tar --prefix="$NAME/JUCE/" "$JUCE_COMMIT" | tar -x -C "$WORK"

mkdir -p "$OUT"
# COPYFILE_DISABLE and --no-mac-metadata keep macOS AppleDouble (._*) files out of the archive
COPYFILE_DISABLE=1 tar -czf "$WORK/$NAME.tar.gz" --no-mac-metadata -C "$WORK" "$NAME"
cp "$WORK/$NAME.tar.gz" "$OUT/"

echo "$OUT/$NAME.tar.gz (AudioGridder $(git rev-parse --short HEAD), JUCE ${JUCE_COMMIT:0:10})"
