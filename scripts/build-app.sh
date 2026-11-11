#!/usr/bin/env bash
# Builds build/Darktop.app from the Swift package.
#   scripts/build-app.sh              native architecture
#   UNIVERSAL=1 scripts/build-app.sh  arm64 + x86_64 (needs full Xcode)
set -euo pipefail

cd "$(dirname "$0")/.."

build_args=(-c release)
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  build_args+=(--arch arm64 --arch x86_64)
fi

swift build "${build_args[@]}"
bin_dir="$(swift build "${build_args[@]}" --show-bin-path)"

app="build/Darktop.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/Darktop" "$app/Contents/MacOS/Darktop"
cp Support/Info.plist "$app/Contents/Info.plist"

# Ad-hoc signature: enough to run locally, not notarized.
codesign --force --sign - "$app"

echo "Built $app"
