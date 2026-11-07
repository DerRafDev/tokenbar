#!/usr/bin/env bash
# Builds a TokenBar release: archive → sign → notarize → package → appcast → checksum.
# Output goes to dist/. Used by .github/workflows/release.yml and runnable locally.
#
# Signing and notarization only run when their variables are set. Without them the app
# is ad-hoc signed and artifacts get an "-unsigned" suffix.
#
#   DEVELOPER_ID_IDENTITY  "Developer ID Application: Name (TEAMID)"
#   APPLE_TEAM_ID          Team ID matching the identity
#   NOTARY_KEY_PATH        Path to an App Store Connect API key (.p8)
#   NOTARY_KEY_ID          API key ID
#   NOTARY_ISSUER_ID       API issuer ID
#
# The Sparkle appcast (dist/appcast.xml) is always produced and needs the EdDSA private key:
# SPARKLE_PRIVATE_KEY, SPARKLE_PRIVATE_KEY_FILE or the login Keychain (see scripts/appcast.sh).
#
# For local update tests only (scripts/test-update.sh):
#   RELEASE_DIST            Output directory instead of dist/
#   RELEASE_WORK            Work directory instead of build/release
#   RELEASE_BUILD_SETTINGS  Extra xcodebuild settings, space-separated (e.g. a test feed URL)
#   SPARKLE_DOWNLOAD_URL    Where the zip will be served instead of the GitHub Release
set -euo pipefail
cd "$(dirname "$0")/.."

work="${RELEASE_WORK:-build/release}"
dist="${RELEASE_DIST:-dist}"
packages=build/SourcePackages
archive="$work/TokenBar.xcarchive"
app="$archive/Products/Applications/TokenBar.app"
read -r -a extra_settings <<< "${RELEASE_BUILD_SETTINGS:-}"

rm -rf "$work" "$dist"
mkdir -p "$work" "$dist"

sign_args=()
suffix=""
if [[ -n "${DEVELOPER_ID_IDENTITY:-}" ]]; then
    sign_args=(
        CODE_SIGN_IDENTITY="$DEVELOPER_ID_IDENTITY"
        DEVELOPMENT_TEAM="${APPLE_TEAM_ID:?APPLE_TEAM_ID is required with DEVELOPER_ID_IDENTITY}"
        OTHER_CODE_SIGN_FLAGS=--timestamp
    )
else
    echo "warning: DEVELOPER_ID_IDENTITY not set; producing an ad-hoc signed build" >&2
    suffix="-unsigned"
    # Lets the ad-hoc app load the embedded Sparkle.framework; see the file for why.
    sign_args=(CODE_SIGN_ENTITLEMENTS=Config/TokenBar-AdHoc.entitlements)
fi

if [[ -n "${NOTARY_KEY_ID:-}" && -n "$suffix" ]]; then
    echo "error: notarization requires a Developer ID signed build" >&2
    exit 1
fi

echo "==> Archiving TokenBar"
xcodebuild archive -quiet \
    -project apps/macos/TokenBar.xcodeproj \
    -scheme TokenBar \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$archive" \
    -clonedSourcePackagesDirPath "$packages" \
    ${sign_args[@]+"${sign_args[@]}"} \
    ${extra_settings[@]+"${extra_settings[@]}"}

version=$(plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist")
build=$(plutil -extract CFBundleVersion raw "$app/Contents/Info.plist")
echo "==> Built TokenBar $version (build $build)"

if [[ -z "$(plutil -extract SUPublicEDKey raw "$app/Contents/Info.plist" 2>/dev/null || true)" ]]; then
    echo "error: SPARKLE_PUBLIC_ED_KEY is empty in apps/macos/Config/TokenBar.xcconfig;" \
        "installed copies could not verify updates (docs/releasing.md › Sparkle)" >&2
    exit 1
fi

# Sparkle ships ad-hoc signed helpers. Xcode re-signs only the framework itself, so the
# helpers, then the framework, then the app are signed again, innermost first, with the
# release identity and the hardened runtime (as Sparkle's documentation describes).
echo "==> Signing Sparkle"
identity="${DEVELOPER_ID_IDENTITY:--}"
codesign_args=(--force --sign "$identity" --options runtime)
if [[ -n "${DEVELOPER_ID_IDENTITY:-}" ]]; then codesign_args+=(--timestamp); fi
sparkle="$app/Contents/Frameworks/Sparkle.framework"
codesign "${codesign_args[@]}" "$sparkle/Versions/B/XPCServices/Installer.xpc"
codesign "${codesign_args[@]}" --preserve-metadata=entitlements "$sparkle/Versions/B/XPCServices/Downloader.xpc"
codesign "${codesign_args[@]}" "$sparkle/Versions/B/Autoupdate"
codesign "${codesign_args[@]}" "$sparkle/Versions/B/Updater.app"
codesign "${codesign_args[@]}" "$sparkle"
codesign "${codesign_args[@]}" --preserve-metadata=entitlements,requirements,flags "$app"

codesign --verify --deep --strict "$app"

# Submits a file for notarization and fails unless Apple accepts it. `notarytool --wait` can
# exit 0 for a rejected submission, so the status is checked explicitly.
notarize() {
    xcrun notarytool submit "$1" \
        --key "${NOTARY_KEY_PATH:?}" --key-id "$NOTARY_KEY_ID" --issuer "${NOTARY_ISSUER_ID:?}" \
        --wait --output-format json > "$work/notary.json"
    local status
    status=$(plutil -extract status raw "$work/notary.json")
    if [[ "$status" != "Accepted" ]]; then
        echo "error: notarization of $(basename "$1"): $status" >&2
        exit 1
    fi
}

if [[ -n "${NOTARY_KEY_ID:-}" ]]; then
    echo "==> Notarizing app"
    ditto -c -k --keepParent "$app" "$work/notarize.zip"
    notarize "$work/notarize.zip"
    xcrun stapler staple "$app"
fi

name="TokenBar-$version$suffix"

echo "==> Packaging"
# The zip is also the Sparkle update archive. --sequesterRsrc as Sparkle recommends for ditto.
ditto -c -k --sequesterRsrc --keepParent "$app" "$dist/$name.zip"

staging="$work/dmg"
mkdir -p "$staging"
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
hdiutil create -quiet -volname TokenBar -srcfolder "$staging" -format UDZO "$dist/$name.dmg"
if [[ -n "${DEVELOPER_ID_IDENTITY:-}" ]]; then
    codesign --sign "$DEVELOPER_ID_IDENTITY" --timestamp "$dist/$name.dmg"
fi
if [[ -n "${NOTARY_KEY_ID:-}" ]]; then
    echo "==> Notarizing disk image"
    notarize "$dist/$name.dmg"
    xcrun stapler staple "$dist/$name.dmg"
fi

echo "==> Appcast"
release_page="https://github.com/DerRafDev/tokenbar/releases/tag/v$version"
download_url="${SPARKLE_DOWNLOAD_URL:-https://github.com/DerRafDev/tokenbar/releases/download/v$version/$name.zip}"
notes="docs/release-notes/v$version.md"
[[ -f "$notes" ]] || notes=""
scripts/appcast.sh "$app" "$dist/$name.zip" "$download_url" "$dist/appcast.xml" "$notes" "$release_page"

(cd "$dist" && shasum -a 256 ./*.zip ./*.dmg > SHA256SUMS.txt)
echo "==> Done"
cat "$dist/SHA256SUMS.txt"
