#!/bin/bash

# KNB iOS Simulator Runner
# This script builds and runs the KNB app in the iOS Simulator

echo "🚀 KNB iOS Simulator Runner"
echo "============================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if Xcode command line tools are properly configured
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ Error: xcodebuild not found${NC}"
    echo "Please run this command first:"
    echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
    exit 1
fi

# Navigate to project directory
cd "$(dirname "$0")"
PROJECT_DIR=$(pwd)

echo -e "${BLUE}📂 Project Directory: ${PROJECT_DIR}${NC}"
echo ""

# Open Simulator app
echo -e "${BLUE}📱 Opening iOS Simulator...${NC}"
open -a Simulator

# Wait a moment for Simulator to open
sleep 2

# Get the scheme name
SCHEME="The KNB App"

# Set destination (you can change the device here)
DESTINATION="platform=iOS Simulator,name=iPhone Air"

echo -e "${BLUE}🔨 Building ${SCHEME}...${NC}"
echo -e "${BLUE}📱 Target: iPhone Air${NC}"
echo ""

# Build and run
xcodebuild \
    -scheme "${SCHEME}" \
    -destination "${DESTINATION}" \
    -configuration Debug \
    clean build \
    | grep -E "^(Build|Clean|Compile|Link|\*\*)" || true

# Check if build succeeded
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Build Successful!${NC}"
    echo -e "${GREEN}📱 App should launch in Simulator${NC}"
    echo ""
    
    # Install and launch the app
    echo -e "${BLUE}🚀 Launching app...${NC}"
    xcodebuild \
        -scheme "${SCHEME}" \
        -destination "${DESTINATION}" \
        -configuration Debug \
        test-without-building \
        2>/dev/null || \
    xcodebuild \
        -scheme "${SCHEME}" \
        -destination "${DESTINATION}" \
        -configuration Debug \
        build \
        2>/dev/null
        
    echo ""
    echo -e "${GREEN}🎉 Done! Check your Simulator.${NC}"
else
    echo ""
    echo -e "${RED}❌ Build Failed!${NC}"
    echo "Please check Xcode for detailed error messages."
    exit 1
fi

