#!/usr/bin/env bash
# Checks formatting and lint rules for all Swift sources. Exits non-zero on any finding.
# Uses `swift format`, which ships with Xcode — no extra tools to install.
set -euo pipefail
cd "$(dirname "$0")/.."

swift format lint --strict --recursive --parallel apps/macos
