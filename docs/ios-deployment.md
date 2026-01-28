# My Day - iOS Deployment Guide

This document provides complete instructions for building and deploying the My Day Flutter app to TestFlight and the App Store.

## Table of Contents

- [Quick Reference](#quick-reference)
- [Setup (One-Time)](#setup-one-time)
- [Deployment Commands](#deployment-commands)
- [Configuration Files](#configuration-files)
- [Troubleshooting](#troubleshooting)
- [CI/CD Integration](#cicd-integration)

---

## Quick Reference

| Action | Command |
|--------|---------|
| Deploy to TestFlight | `./deploy.sh testflight` |
| Deploy to App Store | `./deploy.sh release` |
| Build IPA only | `flutter build ipa --release` |
| Upload existing IPA | `cd ios && fastlane upload_testflight` |
| Bump build number | `cd ios && fastlane bump` |
| Run on device | `flutter run -d <device-id>` |

---

## Setup (One-Time)

### 1. Install Dependencies

```bash
# Install Fastlane via Homebrew
brew install fastlane

# If CocoaPods breaks after updates
gem install --user-install cocoapods
```

### 2. Apple Developer Setup

1. **Apple Developer Account**: Ensure you have an active Apple Developer membership
2. **App Store Connect App**: Create the app at [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
   - Bundle ID: `com.algoclouds.serein`
   - SKU: Any unique identifier

### 3. App Store Connect API Key

1. Go to [App Store Connect → Users and Access → Keys](https://appstoreconnect.apple.com/access/integrations/api)
2. Click **+** to generate a new key
3. Name: `Fastlane`
4. Role: **App Manager**
5. Download the `.p8` file (only available once!)
6. Note the **Key ID** and **Issuer ID**

### 4. Configure Credentials

Move the `.p8` key file:
```bash
mv ~/Downloads/AuthKey_XXXXXX.p8 ios/fastlane/
```

Create the environment file at `ios/fastlane/.env`:
```bash
APPLE_ID="your-email@example.com"
APP_STORE_CONNECT_API_KEY_KEY_ID="YOUR_KEY_ID"
APP_STORE_CONNECT_API_KEY_ISSUER_ID="YOUR_ISSUER_ID"
APP_STORE_CONNECT_API_KEY_KEY_FILEPATH="./fastlane/AuthKey_YOUR_KEY_ID.p8"
```

> ⚠️ **Security**: Never commit `.env` or `.p8` files to version control!

---

## Deployment Commands

### TestFlight Deployment

**Full deployment (recommended):**
```bash
./deploy.sh testflight
```

**With Fastlane directly:**
```bash
cd ios
fastlane beta           # Build + upload
fastlane deploy_testflight  # Bump version + build + upload
```

### App Store Deployment

```bash
./deploy.sh release
# or
cd ios && fastlane release
```

### Build Only (No Upload)

```bash
flutter build ipa --release
```

IPA location: `build/ios/ipa/my_day.ipa`

### Version Management

```bash
cd ios && fastlane bump  # Increment build number
```

---

## Configuration Files

### Project Structure

```
my_day/
├── ios/
│   ├── fastlane/
│   │   ├── Appfile         # App identifier & team
│   │   ├── Fastfile        # Deployment lanes
│   │   ├── .env            # API credentials (gitignored)
│   │   └── AuthKey_*.p8    # API key file (gitignored)
│   ├── Runner.xcodeproj/
│   └── Podfile
├── deploy.sh               # Convenience script
└── .agent/workflows/
    └── ios-deploy.md       # AI assistant workflow
```

### Appfile (`ios/fastlane/Appfile`)

```ruby
app_identifier("com.algoclouds.serein")
apple_id(ENV["APPLE_ID"] || "your-apple-id@email.com")
team_id("B7MQS4W75C")
```

### Key Settings

| Setting | Value |
|---------|-------|
| Bundle ID | `com.algoclouds.serein` |
| Team ID | `B7MQS4W75C` |
| iOS Deployment Target | 13.0 |
| App Name | My Day |

---

## Troubleshooting

### Build Failures

#### "CocoaPods not installed or not in valid state"

```bash
# Reinstall CocoaPods
gem install --user-install cocoapods

# Add to PATH and rebuild
export PATH="$HOME/.gem/ruby/4.0.0/bin:$PATH"
flutter build ipa --release
```

#### "Framework TensorFlowLiteSelectTfOps not found" (Simulator)

This error occurs when building for iOS Simulator. The `flutter_gemma` package only works on real devices.

**Solution**: Build for a real device instead:
```bash
flutter build ios --no-codesign
flutter run -d <device-id>
```

#### "errSecInternalComponent" (Code Signing)

This is a keychain access issue:

1. Open **Keychain Access** app
2. Find "Apple Development: Your Name"
3. Right-click → **Get Info** → **Access Control**
4. Select "Allow all applications to access this item"

Or recreate certificates:
1. Open Xcode
2. Go to Runner target → Signing & Capabilities
3. Toggle "Automatically manage signing" off then on

### Upload Failures

#### "Couldn't find app on App Store Connect"

The app doesn't exist yet. Create it at:
1. [App Store Connect](https://appstoreconnect.apple.com) → My Apps → **+** → New App
2. Use Bundle ID: `com.algoclouds.serein`

#### "Authentication failed"

1. Verify `.env` file has correct Key ID and Issuer ID
2. Check the `.p8` file path is correct
3. Ensure API key has "App Manager" role

### Pod Installation Issues

```bash
# Clean and reinstall pods
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy to TestFlight

on:
  push:
    tags:
      - 'v*'

jobs:
  deploy:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Setup Fastlane
        run: |
          cd ios
          echo "${{ secrets.APP_STORE_CONNECT_KEY }}" | base64 -d > fastlane/AuthKey.p8
          cat > fastlane/.env << EOF
          APP_STORE_CONNECT_API_KEY_KEY_ID=${{ secrets.ASC_KEY_ID }}
          APP_STORE_CONNECT_API_KEY_ISSUER_ID=${{ secrets.ASC_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY_KEY_FILEPATH=./fastlane/AuthKey.p8
          EOF
      
      - name: Deploy to TestFlight
        run: cd ios && fastlane beta
```

### Required Secrets

| Secret | Description |
|--------|-------------|
| `APP_STORE_CONNECT_KEY` | Base64-encoded `.p8` file |
| `ASC_KEY_ID` | App Store Connect Key ID |
| `ASC_ISSUER_ID` | App Store Connect Issuer ID |

---

## Version History

| Date | Version | Notes |
|------|---------|-------|
| 2026-01-27 | 1.0.0+1 | Initial TestFlight deployment |

---

## Support

For issues with:
- **Flutter/Dart**: Check `flutter doctor`
- **Xcode/Signing**: Open project in Xcode and check Signing & Capabilities
- **App Store Connect**: Visit [developer.apple.com](https://developer.apple.com)
