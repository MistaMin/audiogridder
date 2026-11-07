#!/bin/bash
#
# Builds signed and notarized macOS installers from a finished build directory.
#
#   package/buildMacRelease.sh <build dir> [output dir] [--no-notarize] [--legacy]
#
# --legacy packages the macOS 10.7+ build (x86_64 only, built with AG_LEGACY, see DEVELOP.md). It has no AAX
# plug-ins, the installers are named macOS-10.7-x86_64 and the code signatures also carry SHA-1 hashes, which
# macOS 10.7 to 10.10 need to verify a signature.
#
# - Signs all bundles with the Developer ID Application certificate, using the
#   hardened runtime and a secure timestamp.
# - Builds AudioGridderServer_<ver>_macOS-<arch>.pkg and
#   AudioGridderPlugin_<ver>_macOS-<arch>.pkg. Both also install the licence
#   bundle and the macOS permissions guide to /Library/Documentation/AudioGridder.
# - Signs the installers with the Developer ID Installer certificate, then
#   notarizes and staples them (keychain profile AC_NOTARY).
#
# Run this in your own Terminal: codesign and notarytool may need to ask for
# keychain access. The identities can be overridden with AG_SIGN_APP,
# AG_SIGN_INSTALLER and AG_NOTARY_PROFILE.

set -e

AG_SIGN_APP=${AG_SIGN_APP:-"Developer ID Application: Marcos Deida (ZQYU67JUBH)"}
AG_SIGN_INSTALLER=${AG_SIGN_INSTALLER:-"Developer ID Installer: Marcos Deida (ZQYU67JUBH)"}
AG_NOTARY_PROFILE=${AG_NOTARY_PROFILE:-AC_NOTARY}
AG_WRAPTOOL=${AG_WRAPTOOL:-/Applications/PACEAntiPiracy/Eden/Fusion/bin/wraptool}

NOTARIZE=1
LEGACY=0
ARGS=()
for a in "$@"; do
    if [ "$a" == "--no-notarize" ]; then
        NOTARIZE=0
    elif [ "$a" == "--legacy" ]; then
        LEGACY=1
    else
        ARGS+=("$a")
    fi
done

if [ ${#ARGS[@]} -lt 1 ]; then
    echo "Usage: $0 <build dir> [output dir] [--no-notarize]" >&2
    exit 1
fi

# Sets folders and executables to 755 and other files to 644, so the installed copies are readable by
# every user whatever the modes of the source folder were. Restrictive modes (drwx------, common on
# external volumes) are copied into the installer, and macOS then reports the installed app as damaged.
normalize_modes() {
    find "$1" -type d -exec chmod 755 {} +
    find "$1" -type f -perm -u+x -exec chmod 755 {} +
    find "$1" -type f ! -perm -u+x -exec chmod 644 {} +
}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$(cd "${ARGS[0]}" && pwd)"
OUT="${ARGS[1]:-$ROOT/package/build/release}"
VER=$(cat "$ROOT/package/VERSION.num")
ENTITLEMENTS="$ROOT/package/AudioGridderServer.entitlements"
GUIDE="$ROOT/package/docs/AudioGridder-macOS-Permissions.pdf"

SERVER_BUNDLES="bin/AudioGridderServer.app"
PLUGIN_BUNDLES="bin/AudioGridderPluginTray.app lib/AudioGridder.component lib/AudioGridderInst.component
                lib/AudioGridderMidi.component lib/AudioGridder.vst3 lib/AudioGridderInst.vst3 lib/AudioGridderMidi.vst3
                lib/AudioGridder.clap lib/AudioGridderInst.clap lib/AudioGridderMidi.clap"
# LV2 bundles are plain folders, not app bundles, so codesign rejects them. Their binaries are signed instead.
LV2_BUNDLES="lib/AudioGridder.lv2 lib/AudioGridderInst.lv2 lib/AudioGridderMidi.lv2"
AAX_BUNDLES="lib/AudioGridder.aaxplugin lib/AudioGridderInst.aaxplugin lib/AudioGridderMidi.aaxplugin"
DIGEST=""
if [ $LEGACY -eq 1 ]; then
    AAX_BUNDLES=""
    DIGEST="--digest-algorithm=sha1,sha256"
fi
# AAX bundles already signed by PACE wraptool (see DEVELOP.md). They are copied as they are and are not re-signed.
AG_AAX_SIGNED_DIR=${AG_AAX_SIGNED_DIR:-}
if [ -z "$AG_AAX_SIGNED_DIR" ] && [ $LEGACY -eq 0 ]; then
    echo "error: set AG_AAX_SIGNED_DIR to the folder with the PACE-signed AAX bundles (see DEVELOP.md)" >&2
    exit 1
fi

for b in $SERVER_BUNDLES $PLUGIN_BUNDLES; do
    if [ ! -d "$BUILD/$b" ]; then
        echo "error: $BUILD/$b not found, build first" >&2
        exit 1
    fi
done
if [ ! -f "$GUIDE" ]; then
    echo "error: $GUIDE not found, run package/docs/make_macos_permissions_guide.py" >&2
    exit 1
fi
for id in "$AG_SIGN_APP" "$AG_SIGN_INSTALLER"; do
    if ! security find-identity -v | grep -qF "\"$id\""; then
        echo "error: signing identity not found in the keychain: $id" >&2
        exit 1
    fi
done

ARCH=$(lipo -archs "$BUILD/bin/AudioGridderServer.app/Contents/MacOS/AudioGridderServer" | sed 's/ /-/g')
if [ "$ARCH" == "x86_64-arm64" ] || [ "$ARCH" == "arm64-x86_64" ]; then
    ARCH=universal
fi
OSNAME="macOS"
OSMIN="11.1"
HOSTARCHS="arm64,x86_64"
if [ $LEGACY -eq 1 ]; then
    OSNAME="macOS-10.7"
    OSMIN="10.7"
    HOSTARCHS="x86_64"
fi

# Work on the internal disk: copying with ditto --norsrc drops AppleDouble (._*) files and extended
# attributes, which external (non-APFS) volumes add and which codesign rejects.
WORK=$(mktemp -d -t agrelease)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/stage/bin" "$WORK/stage/lib" "$WORK/pkgs" "$WORK/docs" "$WORK/resources"

echo "==> staging bundles"
for b in $SERVER_BUNDLES $PLUGIN_BUNDLES $LV2_BUNDLES; do
    ditto --norsrc --noextattr --noqtn "$BUILD/$b" "$WORK/stage/$b"
done
for b in $AAX_BUNDLES; do
    if [ ! -d "$AG_AAX_SIGNED_DIR/$(basename "$b")" ]; then
        echo "error: $AG_AAX_SIGNED_DIR/$(basename "$b") not found, sign the AAX bundles with PACE first" >&2
        exit 1
    fi
    ditto --norsrc --noextattr --noqtn "$AG_AAX_SIGNED_DIR/$(basename "$b")" "$WORK/stage/$b"
done
find "$WORK/stage" -name "._*" -delete
normalize_modes "$WORK/stage"

echo "==> signing bundles with: $AG_SIGN_APP"
for b in $PLUGIN_BUNDLES; do
    codesign --force --timestamp --options runtime $DIGEST --sign "$AG_SIGN_APP" "$WORK/stage/$b"
done
for b in $LV2_BUNDLES; do
    for so in "$WORK/stage/$b"/*.so; do
        codesign --force --timestamp --options runtime $DIGEST --sign "$AG_SIGN_APP" "$so"
    done
done
codesign --force --timestamp --options runtime $DIGEST --entitlements "$ENTITLEMENTS" --sign "$AG_SIGN_APP" \
    "$WORK/stage/bin/AudioGridderServer.app"

echo "==> verifying signatures"
for b in $SERVER_BUNDLES $PLUGIN_BUNDLES $AAX_BUNDLES; do
    codesign --verify --strict --deep "$WORK/stage/$b"
    info=$(codesign -dvv "$WORK/stage/$b" 2>&1)
    if ! echo "$info" | grep -qF "Authority=$AG_SIGN_APP" || ! echo "$info" | grep -q "^Timestamp="; then
        echo "error: $b is not signed with a Developer ID and a secure timestamp" >&2
        echo "$info" >&2
        exit 1
    fi
    echo "   ok  $b"
done

echo "==> verifying LV2 binaries"
for b in $LV2_BUNDLES; do
    for so in "$WORK/stage/$b"/*.so; do
        info=$(codesign -dvv "$so" 2>&1)
        if ! echo "$info" | grep -qF "Authority=$AG_SIGN_APP" || ! echo "$info" | grep -q "^Timestamp="; then
            echo "error: $so is not signed with a Developer ID and a secure timestamp" >&2
            exit 1
        fi
        echo "   ok  $(basename "$so")"
    done
done

echo "==> collecting documentation"
ditto --norsrc --noextattr "$ROOT/package/licenses" "$WORK/docs/Licenses"
cp "$GUIDE" "$WORK/docs/"
find "$WORK/docs" -name "._*" -delete
normalize_modes "$WORK/docs"

cp "$ROOT/package/licenses/LICENSES.txt" "$WORK/resources/license.txt"
cat > "$WORK/resources/conclusion.html" <<EOF
<html><body style="font-family: -apple-system, Helvetica; font-size: 13px">
<p><b>AudioGridder $VER has been installed.</b></p>
<p>On the Mac that runs AudioGridder Server, allow the <b>Accessibility</b> and <b>Screen Recording</b>
permissions in System Settings &gt; Privacy &amp; Security. The guide explains each step:</p>
<p>/Library/Documentation/AudioGridder/AudioGridder-macOS-Permissions.pdf</p>
<p>Licences and third-party notices are in /Library/Documentation/AudioGridder/Licenses.</p>
</body></html>
EOF

echo "==> building component packages"
pkgc() {
    pkgbuild --component "$2" --install-location "$3" --version "$VER" --identifier "$1" \
        "$WORK/pkgs/$4" >/dev/null
}
AU=/Library/Audio/Plug-Ins/Components
V3=/Library/Audio/Plug-Ins/VST3
pkgc com.e47.audiogridder.server "$WORK/stage/bin/AudioGridderServer.app" /Applications server.pkg
pkgc com.e47.audiogridder.plugintray "$WORK/stage/bin/AudioGridderPluginTray.app" /Applications tray.pkg
pkgc com.e47.audiogridder.au "$WORK/stage/lib/AudioGridder.component" $AU au-fx.pkg
pkgc com.e47.audiogridder.au.inst "$WORK/stage/lib/AudioGridderInst.component" $AU au-inst.pkg
pkgc com.e47.audiogridder.au.midi "$WORK/stage/lib/AudioGridderMidi.component" $AU au-midi.pkg
pkgc com.e47.audiogridder.vst3 "$WORK/stage/lib/AudioGridder.vst3" $V3 vst3-fx.pkg
pkgc com.e47.audiogridder.vst3.inst "$WORK/stage/lib/AudioGridderInst.vst3" $V3 vst3-inst.pkg
pkgc com.e47.audiogridder.vst3.midi "$WORK/stage/lib/AudioGridderMidi.vst3" $V3 vst3-midi.pkg
LV2=/Library/Audio/Plug-Ins/LV2
CLAP=/Library/Audio/Plug-Ins/CLAP
AAXDIR="/Library/Application Support/Avid/Audio/Plug-Ins"
# LV2 bundles are plain folders, so they are packaged from a root folder rather than as components
lv2pkg() {
    mkdir -p "$WORK/lv2root/$2"
    ditto --norsrc --noextattr "$WORK/stage/lib/$1" "$WORK/lv2root/$2/$1"
    pkgbuild --root "$WORK/lv2root/$2" --install-location $LV2 --version "$VER" --identifier "$3" \
        "$WORK/pkgs/$4" >/dev/null
}
lv2pkg AudioGridder.lv2 fx com.e47.audiogridder.lv2 lv2-fx.pkg
lv2pkg AudioGridderInst.lv2 inst com.e47.audiogridder.lv2.inst lv2-inst.pkg
lv2pkg AudioGridderMidi.lv2 midi com.e47.audiogridder.lv2.midi lv2-midi.pkg
pkgc com.e47.audiogridder.clap "$WORK/stage/lib/AudioGridder.clap" $CLAP clap-fx.pkg
pkgc com.e47.audiogridder.clap.inst "$WORK/stage/lib/AudioGridderInst.clap" $CLAP clap-inst.pkg
pkgc com.e47.audiogridder.clap.midi "$WORK/stage/lib/AudioGridderMidi.clap" $CLAP clap-midi.pkg
if [ $LEGACY -eq 0 ]; then
    pkgc com.e47.audiogridder.aax "$WORK/stage/lib/AudioGridder.aaxplugin" "$AAXDIR" aax-fx.pkg
    pkgc com.e47.audiogridder.aax.inst "$WORK/stage/lib/AudioGridderInst.aaxplugin" "$AAXDIR" aax-inst.pkg
    pkgc com.e47.audiogridder.aax.midi "$WORK/stage/lib/AudioGridderMidi.aaxplugin" "$AAXDIR" aax-midi.pkg
fi
pkgbuild --root "$WORK/docs" --install-location /Library/Documentation/AudioGridder --version "$VER" \
    --identifier com.e47.audiogridder.docs "$WORK/pkgs/docs.pkg" >/dev/null

# Writes a distribution file for productbuild: $1 = title, rest = <identifier>:<component package>
distribution() {
    local title=$1
    shift
    local refs="" lines=""
    for entry in "$@"; do
        local id=${entry%%:*}
        local p=${entry#*:}
        refs="$refs        <pkg-ref id=\"$id\"/>\n"
        lines="$lines    <pkg-ref id=\"$id\" version=\"$VER\" onConclusion=\"none\">$p</pkg-ref>\n"
    done
    printf '<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>%s</title>
    <license file="license.txt"/>
    <conclusion file="conclusion.html" mime-type="text/html"/>
    <options customize="never" require-scripts="false" hostArchitectures="%s"/>
    <volume-check><allowed-os-versions><os-version min="%s"/></allowed-os-versions></volume-check>
    <choices-outline><line choice="default"><line choice="ag"/></line></choices-outline>
    <choice id="default"/>
    <choice id="ag" visible="false">
%b    </choice>
%b</installer-gui-script>\n' "$title" "$HOSTARCHS" "$OSMIN" "$refs" "$lines"
}

mkdir -p "$OUT"
SERVER_PKG="AudioGridderServer_${VER}_${OSNAME}-${ARCH}.pkg"
PLUGIN_PKG="AudioGridderPlugin_${VER}_${OSNAME}-${ARCH}.pkg"

echo "==> building installers"
E=com.e47.audiogridder
AAX_REFS=""
if [ $LEGACY -eq 0 ]; then
    AAX_REFS="$E.aax:aax-fx.pkg $E.aax.inst:aax-inst.pkg $E.aax.midi:aax-midi.pkg"
fi
distribution "AudioGridder Server $VER" $E.server:server.pkg $E.docs:docs.pkg > "$WORK/server.dist"
distribution "AudioGridder Plugin $VER" $E.plugintray:tray.pkg $E.au:au-fx.pkg $E.au.inst:au-inst.pkg \
    $E.au.midi:au-midi.pkg $E.vst3:vst3-fx.pkg $E.vst3.inst:vst3-inst.pkg $E.vst3.midi:vst3-midi.pkg \
    $E.lv2:lv2-fx.pkg $E.lv2.inst:lv2-inst.pkg $E.lv2.midi:lv2-midi.pkg \
    $E.clap:clap-fx.pkg $E.clap.inst:clap-inst.pkg $E.clap.midi:clap-midi.pkg \
    $AAX_REFS $E.docs:docs.pkg > "$WORK/plugin.dist"
productbuild --distribution "$WORK/server.dist" --package-path "$WORK/pkgs" --resources "$WORK/resources" \
    "$WORK/server-unsigned.pkg" >/dev/null
productbuild --distribution "$WORK/plugin.dist" --package-path "$WORK/pkgs" --resources "$WORK/resources" \
    "$WORK/plugin-unsigned.pkg" >/dev/null

echo "==> signing installers with: $AG_SIGN_INSTALLER"
productsign --timestamp --sign "$AG_SIGN_INSTALLER" "$WORK/server-unsigned.pkg" "$WORK/$SERVER_PKG" >/dev/null
productsign --timestamp --sign "$AG_SIGN_INSTALLER" "$WORK/plugin-unsigned.pkg" "$WORK/$PLUGIN_PKG" >/dev/null
pkgutil --check-signature "$WORK/$SERVER_PKG" | grep -q "signed by a developer certificate issued by Apple"
pkgutil --check-signature "$WORK/$PLUGIN_PKG" | grep -q "signed by a developer certificate issued by Apple"

if [ $NOTARIZE -eq 1 ]; then
    for pkg in "$SERVER_PKG" "$PLUGIN_PKG"; do
        echo "==> notarizing $pkg (this can take a few minutes)"
        result=$(xcrun notarytool submit "$WORK/$pkg" --keychain-profile "$AG_NOTARY_PROFILE" --wait \
                     --output-format plist || true)
        status=$(echo "$result" | plutil -extract status raw - 2>/dev/null || echo "submission failed")
        if [ "$status" != "Accepted" ]; then
            id=$(echo "$result" | plutil -extract id raw - 2>/dev/null || true)
            echo "error: notarization of $pkg returned '$status'" >&2
            if [ -n "$id" ]; then
                echo "Apple's log:" >&2
                xcrun notarytool log "$id" --keychain-profile "$AG_NOTARY_PROFILE" >&2
            else
                echo "$result" >&2
            fi
            exit 1
        fi
        xcrun stapler staple "$WORK/$pkg" >/dev/null
        xcrun stapler validate "$WORK/$pkg" >/dev/null
        spctl --assess --type install "$WORK/$pkg"
        echo "   ok  notarized and stapled"
    done
else
    echo "==> skipping notarization (--no-notarize)"
fi

# cp instead of mv: moving across volumes fails on some external drives
cp "$WORK/$SERVER_PKG" "$WORK/$PLUGIN_PKG" "$OUT/"
cp "$GUIDE" "$OUT/"
find "$OUT" -name "._*" -delete 2>/dev/null || true

echo "==> done"
echo "   $OUT/$SERVER_PKG"
echo "   $OUT/$PLUGIN_PKG"
echo "   $OUT/$(basename "$GUIDE")"
