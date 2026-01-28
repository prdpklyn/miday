#!/bin/bash
# ============================================================================
# My Day - iOS Deployment Script
# ============================================================================
# Usage: ./deploy.sh [testflight|release|build]
#
# Commands:
#   testflight  - Build and upload to TestFlight
#   release     - Build and upload to App Store
#   build       - Build IPA only (no upload)
#
# Requirements:
#   - Fastlane installed (brew install fastlane)
#   - ios/fastlane/.env configured with API credentials
#   - App exists on App Store Connect
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Change to script directory
cd "$(dirname "$0")"

echo -e "${BLUE}🚀 My Day iOS Deployment${NC}"
echo "========================="
echo ""

# Check for command argument
DEPLOY_TARGET=${1:-help}

# Ensure CocoaPods is available
export PATH="$HOME/.gem/ruby/4.0.0/bin:$PATH"

case $DEPLOY_TARGET in
    testflight)
        echo -e "${YELLOW}📦 Building Flutter app...${NC}"
        flutter clean
        flutter pub get
        
        echo -e "${YELLOW}🏗️  Building IPA...${NC}"
        flutter build ipa --release
        
        echo -e "${YELLOW}✈️  Uploading to TestFlight...${NC}"
        cd ios && fastlane upload_testflight
        
        echo ""
        echo -e "${GREEN}✅ Done! Check App Store Connect for the build.${NC}"
        echo -e "${BLUE}   Build will appear in TestFlight in ~15-30 minutes.${NC}"
        ;;
        
    release)
        echo -e "${YELLOW}📦 Building Flutter app...${NC}"
        flutter clean
        flutter pub get
        
        echo -e "${YELLOW}🏗️  Building IPA...${NC}"
        flutter build ipa --release
        
        echo -e "${YELLOW}🍎 Uploading to App Store...${NC}"
        cd ios && fastlane release
        
        echo ""
        echo -e "${GREEN}✅ Done! Check App Store Connect for the build.${NC}"
        echo -e "${BLUE}   Complete metadata and submit for review.${NC}"
        ;;
        
    build)
        echo -e "${YELLOW}📦 Building Flutter app...${NC}"
        flutter clean
        flutter pub get
        
        echo -e "${YELLOW}🏗️  Building IPA...${NC}"
        flutter build ipa --release
        
        echo ""
        echo -e "${GREEN}✅ IPA built successfully!${NC}"
        echo -e "${BLUE}   Location: build/ios/ipa/my_day.ipa${NC}"
        ;;
        
    bump)
        echo -e "${YELLOW}📈 Incrementing build number...${NC}"
        cd ios && fastlane bump
        echo -e "${GREEN}✅ Build number incremented!${NC}"
        ;;
        
    help|*)
        echo "Usage: ./deploy.sh [command]"
        echo ""
        echo "Commands:"
        echo "  testflight  - Build and upload to TestFlight"
        echo "  release     - Build and upload to App Store"
        echo "  build       - Build IPA only (no upload)"
        echo "  bump        - Increment build number"
        echo "  help        - Show this help message"
        echo ""
        echo "Examples:"
        echo "  ./deploy.sh testflight    # Deploy to TestFlight"
        echo "  ./deploy.sh release       # Deploy to App Store"
        echo "  ./deploy.sh build         # Build IPA only"
        echo ""
        echo "Documentation: docs/ios-deployment.md"
        ;;
esac
