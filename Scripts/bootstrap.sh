#!/usr/bin/env bash
# Bootstrap the Notive Xcode project.
# Requires: Xcode 15.4+, XcodeGen (https://github.com/yonaskolb/XcodeGen).
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen not found. Install it with:  brew install xcodegen" >&2
  exit 1
fi

echo "==> Generating Notive.xcodeproj from project.yml"
xcodegen generate

echo "==> Done. Open Notive.xcodeproj in Xcode and run the 'Notive-macOS' scheme."
