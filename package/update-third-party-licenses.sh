#!/bin/bash
#
# Copies the licence texts of the third-party components that JUCE compiles into
# the AudioGridder binaries into package/licenses/third-party/.
#
# Run this after updating the JUCE submodule and commit the result.

set -e

cd "$(dirname "$0")/.."

JM=JUCE/modules
OUT=package/licenses/third-party

rm -rf "$OUT"
mkdir -p "$OUT"

function copy() {
    local name=$1
    local src=$2
    if [ ! -f "$src" ]; then
        echo "missing licence file: $src" >&2
        exit 1
    fi
    tr -d '\r' < "$src" > "$OUT/$name.txt"
}

copy zlib                $JM/juce_core/zip/zlib/LICENSE
copy HarfBuzz            $JM/juce_graphics/fonts/harfbuzz/COPYING
copy SheenBidi           $JM/juce_graphics/unicode/sheenbidi/LICENSE
copy LunaSVG             $JM/juce_graphics/drawables/lunasvg/LICENSE
copy PlutoVG             $JM/juce_graphics/drawables/lunasvg/plutovg/LICENSE
copy libpng              $JM/juce_graphics/image_formats/pnglib/LICENSE
copy jpeglib-README      $JM/juce_graphics/image_formats/jpglib/README
copy libwebp-JUCE        $JM/juce_graphics/image_formats/libwebp/COPYING
copy FLAC                "$JM/juce_audio_formats/codecs/flac/Flac Licence.txt"
copy libogg              $JM/juce_audio_formats/codecs/ogg/COPYING
copy libvorbis           $JM/juce_audio_formats/codecs/vorbis/COPYING
copy Opus                $JM/juce_audio_formats/codecs/opus/opus/COPYING
copy opusfile            $JM/juce_audio_formats/codecs/opus/opusfile/COPYING
copy libopusenc          $JM/juce_audio_formats/codecs/opus/libopusenc/COPYING
copy VST3-SDK            $JM/juce_audio_processors_headless/format_types/VST3_SDK/LICENSE.txt
copy LV2                 $JM/juce_audio_processors_headless/format_types/LV2_SDK/lv2/COPYING
copy lilv                $JM/juce_audio_processors_headless/format_types/LV2_SDK/lilv/COPYING
copy serd                $JM/juce_audio_processors_headless/format_types/LV2_SDK/serd/COPYING
copy sord                $JM/juce_audio_processors_headless/format_types/LV2_SDK/sord/COPYING
copy sratom              $JM/juce_audio_processors_headless/format_types/LV2_SDK/sratom/COPYING
copy AudioUnitSDK        $JM/juce_audio_plugin_client/AU/AudioUnitSDK/LICENSE.txt
copy CHOC                $JM/juce_javascript/choc/LICENSE.md

# Licence text of the Avid AAX SDK (only the licence text, the SDK itself is not distributed).
# Set AG_AAX_SDK to the SDK folder to include it.
if [ -n "${AG_AAX_SDK:-}" ] && [ -f "$AG_AAX_SDK/LICENSE.txt" ]; then
    mkdir -p "$OUT/AAX-SDK"
    tr -d '\r' < "$AG_AAX_SDK/LICENSE.txt" > "$OUT/AAX-SDK/LICENSE.txt"
fi

# Component inventory with versions and SPDX licence ids, taken from JUCE's SBOM.
python3 -I - JUCE/JUCE.spdx.json "$OUT/COMPONENTS.txt" <<'EOF'
import json, sys
wanted = ["JUCE", "zlib", "HarfBuzz", "SheenBidi", "LunaSVG", "PlutoVG", "libpng", "jpeglib",
          "libwebp", "FLAC", "libogg", "libvorbis", "Opus", "opusfile", "libopusenc", "VST3 SDK",
          "LV2", "lilv", "serd", "sord", "sratom", "AudioUnitSDK", "CHOC"]
pkgs = {p["name"]: p for p in json.load(open(sys.argv[1]))["packages"]}
with open(sys.argv[2], "w") as f:
    f.write("Components compiled in from the JUCE framework source tree\n")
    f.write("==========================================================\n\n")
    for name in wanted:
        p = pkgs[name]
        lic = p.get("licenseConcluded") or p.get("licenseDeclared")
        f.write("%-14s %-12s %s\n" % (name, p.get("versionInfo"), lic))
EOF

echo "licences written to $OUT"
