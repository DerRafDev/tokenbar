#!/usr/bin/env bash
# Local end-to-end test of in-app updates, with no GitHub Release and no real signing key.
#
#   scripts/test-update.sh build             # two test builds (old 0.90.0, new 0.91.0) + feeds
#   scripts/test-update.sh install           # installs the old build and opens it
#   scripts/test-update.sh serve             # serves the feed on http://127.0.0.1:8765 (foreground)
#   scripts/test-update.sh feed SCENARIO     # switches what the feed offers (while serving):
#                                            #   update         0.91.0, correctly signed
#                                            #   none           0.90.0 (the installed version)
#                                            #   bad-signature  0.91.0 signed with another key
#   scripts/test-update.sh clean             # quits the test app, deletes its files and prefs
#
# The test builds are real release builds (scripts/release.sh, ad-hoc signed) with a different
# bundle ID (io.github.derrafdev.TokenBar.updatetest, so your TokenBar preferences are never
# touched), a throwaway EdDSA key and this local feed. Everything lives in build/update-test/.
# See docs/releasing.md › Testing an update locally.
set -euo pipefail
cd "$(dirname "$0")/.."

dir=build/update-test
bundle_id=io.github.derrafdev.TokenBar.updatetest
port=8765
feed_url="http://127.0.0.1:$port"
installed="$dir/Installed/TokenBar.app"

# A throwaway Ed25519 key pair in Sparkle's format (base64 seed / base64 public key).
make_key() {
    local out=$1
    local gen
    gen=$(mktemp -t tokenbar-key).swift
    cat > "$gen" <<'SWIFT'
import CryptoKit
let key = Curve25519.Signing.PrivateKey()
print(key.rawRepresentation.base64EncodedString())
print(key.publicKey.rawRepresentation.base64EncodedString())
SWIFT
    xcrun swift "$gen" > "$out"
    rm -f "$gen"
}

build_variant() {
    local name=$1 version=$2 build=$3 public_key=$4
    RELEASE_DIST="$dir/$name" \
    RELEASE_WORK="$dir/$name-work" \
    RELEASE_BUILD_SETTINGS="MARKETING_VERSION=$version CURRENT_PROJECT_VERSION=$build PRODUCT_BUNDLE_IDENTIFIER=$bundle_id SPARKLE_PUBLIC_ED_KEY=$public_key SPARKLE_FEED_URL=$feed_url/appcast.xml" \
    SPARKLE_DOWNLOAD_URL="$feed_url/TokenBar-$version-unsigned.zip" \
    SPARKLE_PRIVATE_KEY_FILE="$dir/test.key" \
    DEVELOPER_ID_IDENTITY="" NOTARY_KEY_ID="" \
        scripts/release.sh
}

cmd_build() {
    rm -rf "$dir"
    mkdir -p "$dir/feed"
    make_key "$dir/keys.txt"
    make_key "$dir/other-keys.txt"
    sed -n 1p "$dir/keys.txt" > "$dir/test.key"
    sed -n 1p "$dir/other-keys.txt" > "$dir/other.key"
    local public_key
    public_key=$(sed -n 2p "$dir/keys.txt")

    build_variant old 0.90.0 9000 "$public_key"
    build_variant new 0.91.0 9001 "$public_key"

    local old_app="$dir/old-work/TokenBar.xcarchive/Products/Applications/TokenBar.app"
    local new_app="$dir/new-work/TokenBar.xcarchive/Products/Applications/TokenBar.app"
    cp "$dir/new/TokenBar-0.91.0-unsigned.zip" "$dir/old/TokenBar-0.90.0-unsigned.zip" "$dir/feed/"

    cat > "$dir/notes.md" <<'MD'
**Test update.** If you can read this, Markdown release notes work.

- Installed from a local feed
- Signed with a throwaway key
MD
    SPARKLE_PRIVATE_KEY_FILE="$dir/test.key" scripts/appcast.sh "$new_app" "$dir/feed/TokenBar-0.91.0-unsigned.zip" \
        "$feed_url/TokenBar-0.91.0-unsigned.zip" "$dir/feed/appcast-update.xml" "$dir/notes.md"
    SPARKLE_PRIVATE_KEY_FILE="$dir/test.key" scripts/appcast.sh "$old_app" "$dir/feed/TokenBar-0.90.0-unsigned.zip" \
        "$feed_url/TokenBar-0.90.0-unsigned.zip" "$dir/feed/appcast-none.xml"

    # Same item, but the signature comes from a key the app does not trust.
    local good bad
    good=$(sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' "$dir/feed/appcast-update.xml")
    bad=$(build/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update --ed-key-file "$dir/other.key" -p \
        "$dir/feed/TokenBar-0.91.0-unsigned.zip")
    sed "s|$good|$bad|" "$dir/feed/appcast-update.xml" > "$dir/feed/appcast-bad-signature.xml"

    cp "$dir/feed/appcast-update.xml" "$dir/feed/appcast.xml"
    echo "==> Test builds ready in $dir (feed offers: update)"
}

cmd_install() {
    pkill -f "$PWD/$installed/Contents/MacOS/TokenBar" 2>/dev/null || true
    rm -rf "$dir/Installed"
    mkdir -p "$dir/Installed"
    ditto -x -k "$dir/old/TokenBar-0.90.0-unsigned.zip" "$dir/Installed"
    open "$installed"
    echo "==> Installed and opened $installed (0.90.0)"
}

cmd_serve() {
    echo "==> Serving $dir/feed on $feed_url (Ctrl-C to stop)"
    exec python3 -m http.server "$port" --bind 127.0.0.1 --directory "$dir/feed"
}

cmd_feed() {
    local scenario=${1:-}
    if [[ ! -f "$dir/feed/appcast-$scenario.xml" ]]; then
        echo "usage: $0 feed update|none|bad-signature" >&2
        exit 64
    fi
    cp "$dir/feed/appcast-$scenario.xml" "$dir/feed/appcast.xml"
    echo "==> Feed now offers: $scenario"
}

cmd_clean() {
    pkill -f "$PWD/$installed/Contents/MacOS/TokenBar" 2>/dev/null || true
    defaults delete "$bundle_id" 2>/dev/null || true
    rm -rf "$dir" "$HOME/Library/Caches/$bundle_id"
    echo "==> Removed the test app, its files and its preferences"
}

case "${1:-}" in
    build) cmd_build ;;
    install) cmd_install ;;
    serve) cmd_serve ;;
    feed) cmd_feed "${2:-}" ;;
    clean) cmd_clean ;;
    *)
        sed -n '4,11p' "$0" >&2
        exit 64
        ;;
esac
