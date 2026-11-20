#!/usr/bin/env bash
# Regenerates doc/assets/* from real package output.
# Requires: Flutter/Dart SDK and Google Chrome (for typesetting only).
set -euo pipefail
cd "$(dirname "$0")/../.."

WORK="build/readme_assets"
OUT="doc/assets"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"

rm -rf "$WORK"
mkdir -p "$WORK"
echo "Rendering tiles with the engine..."
dart run tool/readme_assets/render.dart prepare "$WORK"

echo "Typesetting pages with headless Chrome..."
while read -r name width height || [[ -n "${name:-}" ]]; do
  # Label sprites need a transparent background; other pages paint their own.
  bg="--default-background-color=0B0C0FFF"
  [[ "$name" == label_* ]] && bg="--default-background-color=00000000"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
    --virtual-time-budget=4000 --window-size="${width},${height}" "$bg" \
    --screenshot="$PWD/$WORK/$name.png" "file://$PWD/$WORK/$name.html" >/dev/null 2>&1
done < "$WORK/pages.txt"

echo "Encoding outputs..."
dart run tool/readme_assets/render.dart finish "$WORK" "$OUT"
