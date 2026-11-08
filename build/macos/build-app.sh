#!/usr/bin/env bash
# Builds RemnantOverseer.app (macOS, Apple Silicon) and zips it.
# Works on macOS or Linux with the .NET 10 SDK installed.
#
#   ./build/macos/build-app.sh            -> dist/RemnantOverseer-mac-arm64.zip
#   RID=osx-x64 ./build/macos/build-app.sh -> Intel build
#
# On macOS the bundle is ad-hoc signed with `codesign`. Elsewhere it is left
# unsigned; users then sign it locally (see README, "macOS").
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RID="${RID:-osx-arm64}"
OUT="$ROOT/dist"
APP="$OUT/RemnantOverseer.app"
VERSION="$(sed -n 's:.*<AssemblyVersion>\(.*\)</AssemblyVersion>.*:\1:p' "$ROOT/RemnantOverseer/RemnantOverseer.csproj")"

rm -rf "$APP" "$OUT/publish-$RID"
dotnet publish "$ROOT/RemnantOverseer/RemnantOverseer.csproj" \
  -c Release -r "$RID" --self-contained true -o "$OUT/publish-$RID"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp -R "$OUT/publish-$RID/." "$APP/Contents/MacOS/"
sed "s/__VERSION__/$VERSION/g" "$ROOT/build/macos/Info.plist" > "$APP/Contents/Info.plist"
chmod +x "$APP/Contents/MacOS/RemnantOverseer"

# App icon (optional): needs Python + Pillow
if command -v python3 >/dev/null && python3 -c "import PIL" 2>/dev/null; then
  python3 - "$ROOT/RemnantOverseer/Assets/IconShadow.ico" "$APP/Contents/Resources/AppIcon.icns" <<'PY'
import sys
from PIL import Image
im = Image.open(sys.argv[1]); im.size = max(im.ico.sizes())
im.convert("RGBA").resize((1024, 1024), Image.LANCZOS).save(sys.argv[2])
PY
fi

if [[ "$(uname)" == "Darwin" ]]; then
  codesign --force --deep --sign - "$APP"
fi

ZIP="$OUT/RemnantOverseer-mac-${RID#osx-}.zip"
rm -f "$ZIP"
(cd "$OUT" && zip -qry "$(basename "$ZIP")" RemnantOverseer.app)
echo "Built $ZIP (version $VERSION)"
