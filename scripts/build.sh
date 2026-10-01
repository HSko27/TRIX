#!/bin/bash
set -euo pipefail
trix_root="$(cd "$(dirname "$0")/.." && pwd)"
trix_build="$trix_root/work/build"
mkdir -p "$trix_build/module-cache"
swiftc -target arm64-apple-macosx14.0 -swift-version 5 -parse-as-library \
  -module-cache-path "$trix_build/module-cache" "$trix_root"/Sources/*.swift \
  -o "$trix_build/TRIXAI"
"$trix_build/TRIXAI" --self-test
if [ "${1:-}" = "--test" ]; then exit 0; fi
trix_app="$trix_root/dist/TRIX AI.app"
if [ -n "${1:-}" ]; then
  trix_runtime_app="$1"
  if [ ! -x "$trix_runtime_app/Contents/Resources/runtime/python/bin/python3.10" ]; then
    echo "Chybí přibalený runtime ve zvolené aplikaci TRIX 0.6.0 beta." >&2
    exit 1
  fi
  mkdir -p "$trix_app/Contents/Resources"
  ditto "$trix_runtime_app/Contents/Resources" "$trix_app/Contents/Resources"
fi
if [ ! -x "$trix_app/Contents/Resources/runtime/python/bin/python3.10" ]; then
  echo 'Pro úplnou aplikaci použij: bash scripts/build.sh "/cesta/TRIX AI.app"' >&2
  exit 1
fi
mkdir -p "$trix_app/Contents/MacOS" "$trix_app/Contents/Resources/Voice"
cp "$trix_build/TRIXAI" "$trix_app/Contents/MacOS/TRIXAI"
cp "$trix_root/Info.plist" "$trix_app/Contents/Info.plist"
cp "$trix_root/czech_voice.py" "$trix_root/tts.py" "$trix_app/Contents/Resources/Voice/"
codesign --force --sign - "$trix_app"
codesign --verify --deep --strict "$trix_app"
echo "Hotovo: $trix_app"
