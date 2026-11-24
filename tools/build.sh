#!/usr/bin/env bash
#
# Build the KernelSU module zip from a Xiaomi Market APK.
#
# Usage:
#   ./tools/build.sh [apk] [output.zip]
#
# Defaults to apk/com.xiaomi.market.apk (bundled with this repository).
# Pass a path to build with a newer store version.

set -euo pipefail

APK="${1:-apk/com.xiaomi.market.apk}"
OUT="${2:-miui_market_cn.zip}"

if [ ! -f "$APK" ]; then
    echo "APK not found: $APK (put it at apk/com.xiaomi.market.apk or pass a path)" >&2
    exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

APP_DIR="$WORK/module/system/app/com.xiaomi.market"
mkdir -p "$APP_DIR/lib/arm64" "$APP_DIR/lib/arm"

cp "$ROOT/module/module.prop" \
   "$ROOT/module/post-fs-data.sh" \
   "$ROOT/module/customize.sh" \
   "$WORK/module/"

cp "$APK" "$APP_DIR/com.xiaomi.market.apk"

# Extract native libraries from the APK (they are required at runtime for a
# system-app install because extractNativeLibs=true).
if command -v unzip >/dev/null 2>&1; then
    unzip -qq -o "$APK" 'lib/arm64-v8a/*' -d "$WORK/x" 2>/dev/null || true
    unzip -qq -o "$APK" 'lib/armeabi-v7a/*' -d "$WORK/x" 2>/dev/null || true
else
    python3 - "$APK" "$WORK/x" <<'PY'
import os, sys, zipfile
apk, dst = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(apk) as z:
    for n in z.namelist():
        if n.startswith("lib/arm64-v8a/") or n.startswith("lib/armeabi-v7a/"):
            out = os.path.join(dst, n)
            os.makedirs(os.path.dirname(out), exist_ok=True)
            with z.open(n) as s, open(out, "wb") as f:
                f.write(s.read())
PY
fi

cp "$WORK"/x/lib/arm64-v8a/*.so "$APP_DIR/lib/arm64/" 2>/dev/null || true
cp "$WORK"/x/lib/armeabi-v7a/*.so "$APP_DIR/lib/arm/" 2>/dev/null || true

chmod -R 0755 "$WORK/module"

rm -f "$OUT"
(cd "$WORK/module" && zip -qr - .) > "$OUT"

echo "built: $OUT"
echo "size : $(du -h "$OUT" | cut -f1)"
