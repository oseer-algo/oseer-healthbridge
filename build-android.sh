#!/bin/bash

# ===============================================
# Android Build Script with Java 17
# ===============================================

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Try to find Java 17
JAVA17_PATH=""

# Look for common Java 17 installations
if [ -d "/Library/Java/JavaVirtualMachines" ]; then
    # macOS path
    JAVA17_DIR=$(find /Library/Java/JavaVirtualMachines -name "jdk-17*" -o -name "temurin-17*" -o -name "zulu-17*" | head -1)
    if [ -n "$JAVA17_DIR" ]; then
        JAVA17_PATH="$JAVA17_DIR/Contents/Home"
    fi
elif [ -d "/usr/lib/jvm" ]; then
    # Linux path
    JAVA17_DIR=$(find /usr/lib/jvm -name "java-17*" -o -name "jdk-17*" -o -name "temurin-17*" -o -name "zulu-17*" | head -1)
    if [ -n "$JAVA17_DIR" ]; then
        JAVA17_PATH="$JAVA17_DIR"
    fi
fi

# Store original JAVA_HOME
ORIGINAL_JAVA_HOME=$JAVA_HOME

if [ -n "$JAVA17_PATH" ]; then
    echo -e "${GREEN}Found Java 17 at: $JAVA17_PATH${NC}"
    echo -e "${BLUE}Temporarily setting JAVA_HOME to Java 17 for this build...${NC}"
    export JAVA_HOME="$JAVA17_PATH"
else
    echo -e "${YELLOW}Could not find Java 17 installation. Using current Java version.${NC}"
    echo -e "${YELLOW}If build fails, please install Java 17 and try again.${NC}"
fi

# Clean project
echo -e "${BLUE}Cleaning project...${NC}"
flutter clean

# Get dependencies
echo -e "${BLUE}Getting dependencies...${NC}"
flutter pub get

# Build the APK
echo -e "${BLUE}Building release APK...${NC}"
flutter build apk --release

# Restore original JAVA_HOME
if [ -n "$ORIGINAL_JAVA_HOME" ]; then
    export JAVA_HOME="$ORIGINAL_JAVA_HOME"
    echo -e "${BLUE}Restored original JAVA_HOME: $JAVA_HOME${NC}"
fi

# Check if build was successful
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Build successful!${NC}"
    echo -e "${GREEN}APK location: $(pwd)/build/app/outputs/flutter-apk/app-release.apk${NC}"
else
    echo -e "${RED}Build failed.${NC}"
    exit 1
fi
