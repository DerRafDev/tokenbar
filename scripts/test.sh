#!/usr/bin/env bash
# Builds and tests the TokenBarKit package, where all app logic lives.
set -euo pipefail
cd "$(dirname "$0")/../apps/macos/TokenBarKit"

swift test --parallel "$@"
