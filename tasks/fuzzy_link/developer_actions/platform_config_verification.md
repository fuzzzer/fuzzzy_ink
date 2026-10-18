# FuzzyLink — Platform Configuration Verification

> **Priority:** 🟡 High
> **Requires:** Physical Android + iOS devices, Xcode, Android Studio
> **When:** Before first real-device test, after any native config changes

---

## Android Verification

### 1. Verify `AndroidManifest.xml` intent filter

**File:** `android/app/src/main/AndroidManifest.xml`

Confirm the following intent filter exists inside `<activity>`:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="fuzzylink" />
</intent-filter>
```

### 2. Verify `launchMode`

The activity should use `singleTask` or `singleTop` to prevent duplicate instances when a link is tapped while the app is already running:

```xml
<activity
    android:launchMode="singleTask"
    ...>
```

> If `launchMode` is `standard`, tapping a link while the app is backgrounded will create a new activity instance → broken navigation.

### 3. Quick smoke test

```bash
# Install debug APK
fvm flutter run -d <device-id>

# Send a test deep link
adb shell am start -a android.intent.action.VIEW \
  -d "fuzzylink://invite/eyJ2IjoxLCJ0IjoiaW52In0="

# Expected: app opens (or foregrounds) and shows snackbar (invalid link is fine for smoke test)
```

### 4. Check logcat for link reception

```bash
adb logcat | grep -i "fuzzylink\|app_links\|deeplink"
```

---

## iOS Verification

### 1. Verify `Info.plist` URL scheme

**File:** `ios/Runner/Info.plist`

Confirm:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Viewer</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>fuzzylink</string>
        </array>
    </dict>
</array>
```

### 2. Verify AppDelegate

Check that the app delegate (or `SceneDelegate` for scene-based apps) doesn't override link handling in a way that conflicts with `app_links`.

**File:** `ios/Runner/AppDelegate.swift`

`app_links` handles link reception automatically via Flutter's method channel. If there's custom URL handling code, make sure it calls `super` and doesn't swallow the event.

### 3. Quick smoke test

```bash
# On simulator
xcrun simctl openurl booted "fuzzylink://invite/eyJ2IjoxLCJ0IjoiaW52In0="

# On real device — open Safari and type:
# fuzzylink://invite/eyJ2IjoxLCJ0IjoiaW52In0=
# Then tap "Open" when iOS prompts
```

### 4. Check Xcode console for link reception

Run the app from Xcode and watch the console for `app_links` debug output.

---

## macOS Verification (if applicable)

### 1. Verify `Info.plist`

**File:** `macos/Runner/Info.plist`

Same `CFBundleURLTypes` structure as iOS.

### 2. Test from Terminal

```bash
open "fuzzylink://invite/eyJ2IjoxLCJ0IjoiaW52In0="
```

---

## Common Issues & Fixes

| Issue | Platform | Fix |
|-------|----------|-----|
| Link doesn't open the app | Android | Check `<data android:scheme="fuzzylink" />` is inside an `<intent-filter>` with `VIEW` action and `BROWSABLE` category |
| Link opens but nothing happens | Both | Check `FuzzyLinkListener` is wrapping `MaterialApp.router` in `app.dart` |
| App opens but creates duplicate instance | Android | Set `android:launchMode="singleTask"` on the activity |
| Link works in debug but not release | Android | ProGuard/R8 may strip `app_links` code. Check proguard-rules.pro |
| iOS shows "Open in App?" but app crashes | iOS | Check `Info.plist` scheme matches exactly (`fuzzylink`, not `fuzzyLink` or `FuzzyLink`) |
| macOS ignores the link | macOS | macOS requires signing and entitlements. Custom schemes may need sandbox exceptions |

---

## Sign-Off

| Platform | Config Verified | Smoke Test Passed | Date |
|----------|----------------|-------------------|------|
| Android  |                |                   |      |
| iOS      |                |                   |      |
| macOS    |                |                   |      |
