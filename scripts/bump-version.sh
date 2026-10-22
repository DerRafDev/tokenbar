#!/usr/bin/env bash
# Sets the app version in apps/macos/Config/Version.xcconfig and increments the build number.
#
#   scripts/bump-version.sh 0.2.0
#
# Then commit, merge, and tag: git tag v0.2.0 && git push origin v0.2.0
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:-}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "usage: $0 MAJOR.MINOR.PATCH" >&2
    exit 64
fi

file=apps/macos/Config/Version.xcconfig
build=$(sed -n 's/^CURRENT_PROJECT_VERSION = //p' "$file")

sed -i '' \
    -e "s/^MARKETING_VERSION = .*/MARKETING_VERSION = $version/" \
    -e "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $((build + 1))/" \
    "$file"

echo "TokenBar $version (build $((build + 1)))"
