---
description: Build and deploy iOS app to TestFlight or App Store
---

# iOS Deployment Workflow

This workflow handles building the Flutter iOS app and uploading to TestFlight or App Store.

## Prerequisites

Before running this workflow, ensure:
1. Xcode is installed with valid signing certificates
2. CocoaPods is installed and working
3. App Store Connect API key is configured in `ios/fastlane/.env`
4. The app exists on App Store Connect with bundle ID `com.algoclouds.serein`

## Deployment Options

### Option 1: Quick TestFlight Upload (Existing IPA)

If an IPA was already built, upload it directly:

// turbo
```bash
cd ios && fastlane upload_testflight
```

### Option 2: Full TestFlight Deployment

Build and upload to TestFlight:

// turbo
```bash
cd ios && fastlane beta
```

### Option 3: TestFlight with Version Bump

Increment build number, build, and upload:

// turbo
```bash
cd ios && fastlane deploy_testflight
```

### Option 4: App Store Deployment

Build and upload to App Store (for review):

// turbo
```bash
cd ios && fastlane release
```

### Option 5: Manual Build Only

Build IPA without uploading:

// turbo
```bash
flutter build ipa --release
```

The IPA will be at: `build/ios/ipa/my_day.ipa`

## Troubleshooting

### CocoaPods Issues

If CocoaPods is broken after Ruby update:

```bash
gem install --user-install cocoapods
export PATH="$HOME/.gem/ruby/4.0.0/bin:$PATH"
```

### Code Signing Issues

If you get "errSecInternalComponent" errors:
1. Open Keychain Access
2. Find your Apple Development certificate
3. Right-click → Get Info → Access Control → Allow all applications

Or recreate certificates in Xcode:
1. Open `ios/Runner.xcworkspace` in Xcode
2. Go to Runner target → Signing & Capabilities
3. Uncheck then re-check "Automatically manage signing"

### API Key Issues

If upload fails with authentication errors:
1. Verify `ios/fastlane/.env` has correct values
2. Ensure the `.p8` key file path is correct (relative to `ios/` directory)
3. Check the API key has "App Manager" role in App Store Connect

## Configuration Files

- **Appfile**: `ios/fastlane/Appfile` - Bundle ID and team settings
- **Fastfile**: `ios/fastlane/Fastfile` - Deployment lanes
- **API Key**: `ios/fastlane/.env` - App Store Connect API credentials
- **Key File**: `ios/fastlane/AuthKey_*.p8` - API key file (never commit!)

## Post-Upload

After upload:
1. Build appears in App Store Connect within 15-30 minutes
2. Add testers in TestFlight section
3. For App Store release, complete app metadata and submit for review
