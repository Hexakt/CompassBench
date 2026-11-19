#!/bin/bash
# Compile l'app pour iPhone sans signature et produit une IPA à signer par le
# logiciel de sideload. Adapté de SmokeSignalIOS/scripts/build-ios.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
python3 scripts/generate-project.py --check
xcodebuild -project CompassBench.xcodeproj -scheme CompassBench -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/device \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
APP="$ROOT/build/device/Build/Products/Release-iphoneos/CompassBench.app"
test -d "$APP"
rm -rf "$ROOT/build/Payload"
mkdir -p "$ROOT/build/Payload"
ditto "$APP" "$ROOT/build/Payload/CompassBench.app"
(cd "$ROOT/build" && /usr/bin/zip -qry CompassBench-unsigned.ipa Payload)
test -s "$ROOT/build/CompassBench-unsigned.ipa"
echo "IPA : build/CompassBench-unsigned.ipa"
