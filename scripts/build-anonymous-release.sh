#!/bin/bash
set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

VERSION=$(python3 - <<'PY'
import pathlib, re
text = pathlib.Path("project.yml").read_text(encoding="utf-8")
match = re.search(r'^\s*MARKETING_VERSION:\s*"([^"]+)"', text, re.M)
if not match:
    raise SystemExit("MARKETING_VERSION not found in project.yml")
print(match.group(1))
PY
)

OUT_DIR="${1:-$REPO_ROOT/.tmp/release/v$VERSION}"
STAGE_DIR="$OUT_DIR/.stage"
MAC_DERIVED="$REPO_ROOT/.tmp/ReleaseMacDerivedData"
IOS_DERIVED="$REPO_ROOT/.tmp/ReleaseIOSDerivedData"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR" "$STAGE_DIR/mac" "$STAGE_DIR/ios/Payload"

cleanup() {
  rm -rf "$STAGE_DIR"
}
trap cleanup EXIT

strip_macho_binaries() {
  local app_path="$1"
  while IFS= read -r -d '' bin; do
    if file -b "$bin" | grep -q 'Mach-O'; then
      codesign --remove-signature "$bin" >/dev/null 2>&1 || true
      xcrun strip -x "$bin"
    fi
  done < <(find "$app_path" -type f -print0)
}

assert_anonymous_bundle() {
  local app_path="$1"
  local mode="$2" # adhoc | unsigned
  local info
  info=$(codesign -dvvv "$app_path" 2>&1 || true)

  if echo "$info" | grep -q '^Authority='; then
    echo "ERROR: signing Authority leaked in $app_path" >&2
    echo "$info" >&2
    exit 1
  fi
  if echo "$info" | grep -E '^TeamIdentifier=' | grep -qv '^TeamIdentifier=not set$'; then
    echo "ERROR: non-empty TeamIdentifier leaked in $app_path" >&2
    echo "$info" >&2
    exit 1
  fi
  if find "$app_path" \( -name "*.provisionprofile" -o -name "embedded.mobileprovision" \) | grep -q .; then
    echo "ERROR: provisioning profile embedded inside $app_path" >&2
    exit 1
  fi
  if [ "$mode" = "adhoc" ]; then
    echo "$info" | grep -q 'Signature=adhoc' || {
      echo "ERROR: expected Signature=adhoc for $app_path" >&2
      echo "$info" >&2
      exit 1
    }
    codesign --verify --deep --strict "$app_path"
  fi

  python3 - "$app_path" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
host_prefixes = (
    b"/" + b"Users" + b"/",
    b"/" + b"home" + b"/",
)
for p in sorted(root.rglob("*")):
    if not p.is_file() or p.is_symlink():
        continue
    raw = p.read_bytes()
    for needle in host_prefixes:
        if needle in raw:
            print(f"ERROR: build-host path prefix {needle!r} leaked in {p}", file=sys.stderr)
            sys.exit(1)
PY
}

assert_universal_macos_binary() {
  local bin_path="$1"
  local archs
  archs=$(lipo -archs "$bin_path" 2>/dev/null || true)
  for required in arm64 x86_64; do
    if ! echo " $archs " | grep -q " $required "; then
      echo "ERROR: $bin_path is missing architecture '$required' (found: '$archs')" >&2
      exit 1
    fi
  done
}

echo "[1/4] Building macOS Release (TeaPulseMac) without team identity..."
xcodebuild -project TeaPulse.xcodeproj \
  -scheme TeaPulseMac \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$MAC_DERIVED" \
  DEVELOPMENT_TEAM="" \
  CODE_SIGNING_ALLOWED=NO \
  build >/dev/null

MAC_APP_SRC="$MAC_DERIVED/Build/Products/Release/TeaPulse.app"
MAC_APP_DST="$STAGE_DIR/mac/TeaPulse.app"
cp -R "$MAC_APP_SRC" "$MAC_APP_DST"
find "$MAC_APP_DST" -name "*.provisionprofile" -delete
strip_macho_binaries "$MAC_APP_DST"

if [ -d "$MAC_APP_DST/Contents/Frameworks" ]; then
  find "$MAC_APP_DST/Contents/Frameworks" -maxdepth 1 \( -name "*.framework" -o -name "*.dylib" \) -print0 \
    | xargs -0 -I{} codesign --force --sign - --timestamp=none "{}"
fi

WIDGET_EXT="$MAC_APP_DST/Contents/PlugIns/TeaPulseMacWidgets.appex"
SHARE_EXT="$MAC_APP_DST/Contents/PlugIns/TeaPulseMacShareExtension.appex"
[ -d "$WIDGET_EXT" ] && codesign --force --sign - --entitlements Config/TeaPulseMacWidgets.entitlements --timestamp=none "$WIDGET_EXT"
[ -d "$SHARE_EXT" ] && codesign --force --sign - --entitlements Config/TeaPulseMacShareExtension.entitlements --timestamp=none "$SHARE_EXT"
codesign --force --sign - --entitlements Config/TeaPulseMac.entitlements --timestamp=none "$MAC_APP_DST"

assert_anonymous_bundle "$MAC_APP_DST" "adhoc"
[ -d "$WIDGET_EXT" ] && assert_anonymous_bundle "$WIDGET_EXT" "adhoc"
[ -d "$SHARE_EXT" ] && assert_anonymous_bundle "$SHARE_EXT" "adhoc"
assert_universal_macos_binary "$MAC_APP_DST/Contents/MacOS/TeaPulse"
[ -d "$WIDGET_EXT" ] && assert_universal_macos_binary "$WIDGET_EXT/Contents/MacOS/TeaPulseMacWidgets"
[ -d "$SHARE_EXT" ] && assert_universal_macos_binary "$SHARE_EXT/Contents/MacOS/TeaPulseMacShareExtension"

echo "[2/4] Packaging compressed macOS DMG..."
find "$STAGE_DIR/mac" \( -name '._*' -o -name '.DS_Store' \) -delete
ln -s /Applications "$STAGE_DIR/mac/Applications"
DMG_PATH="$OUT_DIR/TeaPulse-$VERSION-macOS.dmg"
hdiutil create -volname "TeaPulse" -srcfolder "$STAGE_DIR/mac" -ov -format UDZO "$DMG_PATH" >/dev/null

echo "[3/4] Building unsigned iOS Release (TeaPulse) for sideloading..."
xcodebuild -project TeaPulse.xcodeproj \
  -scheme TeaPulse \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$IOS_DERIVED" \
  DEVELOPMENT_TEAM="" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build >/dev/null

IOS_APP_SRC="$IOS_DERIVED/Build/Products/Release-iphoneos/TeaPulse.app"
IOS_APP_DST="$STAGE_DIR/ios/Payload/TeaPulse.app"
cp -R "$IOS_APP_SRC" "$IOS_APP_DST"
find "$IOS_APP_DST" \( -name "embedded.mobileprovision" -o -name "*.provisionprofile" \) -delete
rm -rf "$IOS_APP_DST/_CodeSignature"
find "$IOS_APP_DST/PlugIns" -maxdepth 2 -name "_CodeSignature" -exec rm -rf {} + 2>/dev/null || true
strip_macho_binaries "$IOS_APP_DST"
find "$STAGE_DIR/ios" \( -name '._*' -o -name '.DS_Store' \) -delete

assert_anonymous_bundle "$IOS_APP_DST" "unsigned"

IPA_PATH="$OUT_DIR/TeaPulse-$VERSION-iOS-unsigned.ipa"
(cd "$STAGE_DIR/ios" && COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent Payload "$IPA_PATH")

echo "[4/4] Writing SHA256SUMS.txt and RELEASE_NOTES.md..."
(cd "$OUT_DIR" && shasum -a 256 "TeaPulse-$VERSION-macOS.dmg" "TeaPulse-$VERSION-iOS-unsigned.ipa" > SHA256SUMS.txt)

cat > "$OUT_DIR/RELEASE_NOTES.md" <<EOF
# TeaPulse v${VERSION} (Anonymous Open-Source Build)

All binaries in this release are built without an Apple Developer Team ID or certificate authority (\`Signature=adhoc\` on macOS; unsigned \`Payload\` on iOS). Verify artifact integrity against \`SHA256SUMS.txt\`.

## macOS (\`TeaPulse-${VERSION}-macOS.dmg\`, Universal Apple Silicon + Intel)

1. Open the DMG and drag \`TeaPulse.app\` into \`/Applications\`.
2. On first launch, macOS Gatekeeper warns because the app is ad-hoc signed without Apple notarization:
   - **GUI**: Click **Done**, open **System Settings -> Privacy & Security**, scroll down, and click **Open Anyway**.
   - **Terminal**: Run \`xattr -cr /Applications/TeaPulse.app\` once before opening.

## iOS / iPadOS (\`TeaPulse-${VERSION}-iOS-unsigned.ipa\`)

- Install via **AltStore** or **SideStore** using your own Apple ID, or build from source in Xcode with a personal Apple ID.

---

# TeaPulse v${VERSION}（匿名开源构建）

本版本所有安装包均未嵌入开发者 Team ID 或实名证书链（macOS 为 \`adhoc\` 本地签名，iOS 为无签名 \`Payload\`），下载后可结合 \`SHA256SUMS.txt\` 核对校验和。

## macOS（\`TeaPulse-${VERSION}-macOS.dmg\`，Universal 通用版：同时支持 Apple Silicon 与 Intel）

1. 打开 DMG 并把 \`TeaPulse.app\` 拖入「应用程序」。
2. 由于未接入 Apple 实名公证，首次打开时系统会提示来自未验证开发者：
   - **图形界面**：弹窗点「完成」，进入 **系统设置 -> 隐私与安全性** 底部点击 **「仍要打开」** 即可。
   - **终端放行**：执行 \`xattr -cr /Applications/TeaPulse.app\` 清除下载隔离属性后即可直接打开。

## iOS / iPadOS（\`TeaPulse-${VERSION}-iOS-unsigned.ipa\`）

- 可使用 **AltStore / SideStore** 配合个人 Apple ID 自签侧载，或拉取源码后用个人免费 Apple ID 在 Xcode 中编译装机。
EOF

ls -lh "$OUT_DIR"
cat "$OUT_DIR/SHA256SUMS.txt"
