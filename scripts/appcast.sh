#!/usr/bin/env bash
# Signs an update archive with EdDSA and writes a Sparkle appcast with one item for it.
# Called by scripts/release.sh; runnable on its own.
#
#   scripts/appcast.sh APP ZIP DOWNLOAD_URL OUTPUT [NOTES_MD] [RELEASE_PAGE_URL]
#
#   APP               The TokenBar.app inside ZIP (version, minimum macOS, public key are read here)
#   ZIP               The archive Sparkle downloads
#   DOWNLOAD_URL      Where ZIP will be served (the GitHub Release asset URL)
#   OUTPUT            appcast.xml to write
#   NOTES_MD          Optional Markdown release notes shown in the update dialog
#   RELEASE_PAGE_URL  Optional link for "Version History" / full release notes
#
# The private key is read from, in order:
#   SPARKLE_PRIVATE_KEY       the key itself (the Actions secret); passed to sign_update on stdin
#   SPARKLE_PRIVATE_KEY_FILE  a file holding the key
#   the login Keychain        where Sparkle's generate_keys stores it
#
# Fails unless the signature verifies against the app's SUPublicEDKey, so a release can never
# carry a signature that installed copies would reject.
set -euo pipefail

if [[ $# -lt 4 ]]; then
    sed -n '4,6p' "$0" >&2
    exit 64
fi
app=$1 zip=$2 url=$3 out=$4 notes=${5:-} page=${6:-}
root="$(cd "$(dirname "$0")/.." && pwd)"
bin="${SPARKLE_BIN:-$root/build/SourcePackages/artifacts/sparkle/Sparkle/bin}"

if [[ ! -x "$bin/sign_update" ]]; then
    echo "error: $bin/sign_update not found; resolve packages first (scripts/release.sh does)" >&2
    exit 1
fi

plist="$app/Contents/Info.plist"
read_plist() { plutil -extract "$1" raw "$plist"; }
build=$(read_plist CFBundleVersion)
version=$(read_plist CFBundleShortVersionString)
minimum=$(read_plist LSMinimumSystemVersion)
public_key=$(read_plist SUPublicEDKey 2>/dev/null || true)
if [[ -z "$public_key" ]]; then
    echo "error: $app has no SUPublicEDKey; set SPARKLE_PUBLIC_ED_KEY (docs/releasing.md)" >&2
    exit 1
fi

if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
    signature=$(printf '%s' "$SPARKLE_PRIVATE_KEY" | "$bin/sign_update" --ed-key-file - -p "$zip")
elif [[ -n "${SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
    signature=$("$bin/sign_update" --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" -p "$zip")
else
    signature=$("$bin/sign_update" -p "$zip")
fi

# Check with the public key the app ships, not the one derived from the private key.
verifier=$(mktemp -t tokenbar-verify).swift
trap 'rm -f "$verifier"' EXIT
cat > "$verifier" <<'SWIFT'
import CryptoKit
import Foundation
let args = CommandLine.arguments
guard let keyData = Data(base64Encoded: args[1]), let signature = Data(base64Encoded: args[2]),
    let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData),
    let file = FileManager.default.contents(atPath: args[3]),
    key.isValidSignature(signature, for: file)
else { exit(1) }
SWIFT
if ! xcrun swift "$verifier" "$public_key" "$signature" "$zip"; then
    echo "error: the update signature does not match SUPublicEDKey in $app;" \
        "the private key and SPARKLE_PUBLIC_ED_KEY are not a pair" >&2
    exit 1
fi

length=$(stat -f %z "$zip")
pub_date=$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")

{
    echo '<?xml version="1.0" encoding="utf-8"?>'
    echo '<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">'
    echo '  <channel>'
    echo '    <title>TokenBar</title>'
    echo '    <item>'
    echo "      <title>TokenBar $version</title>"
    echo "      <pubDate>$pub_date</pubDate>"
    echo "      <sparkle:version>$build</sparkle:version>"
    echo "      <sparkle:shortVersionString>$version</sparkle:shortVersionString>"
    echo "      <sparkle:minimumSystemVersion>$minimum</sparkle:minimumSystemVersion>"
    if [[ -n "$page" ]]; then
        echo "      <sparkle:fullReleaseNotesLink>$page</sparkle:fullReleaseNotesLink>"
    fi
    if [[ -n "$notes" ]]; then
        if grep -q ']]>' "$notes"; then
            echo "error: $notes contains ']]>', which cannot go in the appcast" >&2
            exit 1
        fi
        echo '      <description sparkle:format="markdown"><![CDATA['
        cat "$notes"
        echo '      ]]></description>'
    fi
    echo "      <enclosure url=\"$url\" length=\"$length\" type=\"application/octet-stream\" sparkle:edSignature=\"$signature\"/>"
    echo '    </item>'
    echo '  </channel>'
    echo '</rss>'
} > "$out"

xmllint --noout "$out"
echo "Appcast: TokenBar $version (build $build) → $out"
