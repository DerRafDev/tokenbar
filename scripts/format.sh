#!/usr/bin/env bash
# Formats all Swift sources in place.
set -euo pipefail
cd "$(dirname "$0")/.."

swift format format --in-place --recursive --parallel apps/macos
