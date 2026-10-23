#!/usr/bin/env bash
# Builds a TokenBar release: archive → sign → notarize → package → checksum.
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
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(sed -n 's/^MARKETING_VERSION = //p' apps/macos/Config/Version.xcconfig)
work=build/release
archive="$work/TokenBar.xcarchive"
app="$archive/Products/Applications/TokenBar.app"

rm -rf "$work" dist
mkdir -p "$work" dist

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
fi

echo "==> Archiving TokenBar $version"
xcodebuild archive -quiet \
    -project apps/macos/TokenBar.xcodeproj \
    -scheme TokenBar \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$archive" \
    ${sign_args[@]+"${sign_args[@]}"}

codesign --verify --deep --strict "$app"

if [[ -n "${NOTARY_KEY_ID:-}" && -n "$suffix" ]]; then
    echo "error: notarization requires a Developer ID signed build" >&2
    exit 1
fi

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
ditto -c -k --keepParent "$app" "dist/$name.zip"

staging="$work/dmg"
mkdir -p "$staging"
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
hdiutil create -quiet -volname TokenBar -srcfolder "$staging" -format UDZO "dist/$name.dmg"
if [[ -n "${DEVELOPER_ID_IDENTITY:-}" ]]; then
    codesign --sign "$DEVELOPER_ID_IDENTITY" --timestamp "dist/$name.dmg"
fi
if [[ -n "${NOTARY_KEY_ID:-}" ]]; then
    echo "==> Notarizing disk image"
    notarize "dist/$name.dmg"
    xcrun stapler staple "dist/$name.dmg"
fi

(cd dist && shasum -a 256 ./*.zip ./*.dmg > SHA256SUMS.txt)
echo "==> Done"
cat dist/SHA256SUMS.txt
