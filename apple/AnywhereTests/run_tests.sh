#!/bin/sh
# XCTest for the native "Lock from other apps" state owner, the Mac
# Services provider and the Mac message box, without the Flutter engine:
# the files under test talk to Dart only through AnywhereCalling, which the
# tests fake. Builds a test bundle with swiftc and runs it with xctest
# (macOS, Xcode installed).
#
#   apple/AnywhereTests/run_tests.sh [build folder]
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
out=${1:-"$root/build/anywhere_tests"}
bundle="$out/AnywhereTests.xctest"
platform=$(xcrun --sdk macosx --show-sdk-platform-path)
rm -rf "$bundle"
mkdir -p "$bundle/Contents/MacOS"
cat > "$bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.fuzzzycore.ink.anywhere-tests</string>
<key>CFBundleExecutable</key><string>AnywhereTests</string>
<key>CFBundlePackageType</key><string>BNDL</string>
</dict></plist>
PLIST
xcrun --sdk macosx swiftc \
  -module-name AnywhereTests \
  -target "$(uname -m)-apple-macos14.0" \
  -F "$platform/Developer/Library/Frameworks" \
  -I "$platform/Developer/usr/lib" -L "$platform/Developer/usr/lib" \
  -framework XCTest \
  -Xlinker -bundle \
  -Xlinker -rpath -Xlinker "$platform/Developer/Library/Frameworks" \
  -Xlinker -rpath -Xlinker "$platform/Developer/usr/lib" \
  -o "$bundle/Contents/MacOS/AnywhereTests" \
  "$root/apple/Anywhere/InkAnywhereContract.swift" \
  "$root/apple/Anywhere/InkAnywhereModel.swift" \
  "$root/apple/Anywhere/InkText.swift" \
  "$root/apple/Anywhere/InkSealedTextBox.swift" \
  "$root/apple/Anywhere/InkSealedTextViewMac.swift" \
  "$root/macos/Runner/Anywhere/InkServiceProvider.swift" \
  "$here/FakeAnywhereChannel.swift" \
  "$here/InkAnywhereModelTests.swift" \
  "$here/InkServiceProviderTests.swift" \
  "$here/InkSealedTextViewTests.swift"
xcrun xctest "$bundle"
