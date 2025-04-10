#!/bin/bash

# ======================================================
# Fix Android Build Issues Script
# ======================================================
# This script fixes build.gradle issues for Android
#
# Usage: ./fix-android-build.sh
# ======================================================

# Color definitions for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check execution status
check_status() {
    if [ $? -eq 0 ]; then
        print_message "$GREEN" "✓ Success: $1"
    else
        print_message "$RED" "✗ Error: $1"
        exit 1
    fi
}

# Base directory for the project
BASE_DIR="/Users/jeremy/Development/Oseer/android_companion_app"

# Check if directory exists
if [ ! -d "$BASE_DIR" ]; then
    print_message "$RED" "Project directory doesn't exist: $BASE_DIR"
    exit 1
fi

cd "$BASE_DIR" || exit 1

# Step 1: Fix app/build.gradle
print_message "$BLUE" "Fixing app/build.gradle..."

# Back up the existing file if not already done
if [ ! -f "android/app/build.gradle.bak2" ]; then
    cp "android/app/build.gradle" "android/app/build.gradle.bak2"
    check_status "Backed up app/build.gradle"
fi

# Create a fixed app/build.gradle
cat > "android/app/build.gradle" << 'EOF'
def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

def flutterRoot = localProperties.getProperty('flutter.sdk')
if (flutterRoot == null) {
    throw new GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")
}

def flutterVersionCode = localProperties.getProperty('flutter.versionCode')
if (flutterVersionCode == null) {
    flutterVersionCode = '1'
}

def flutterVersionName = localProperties.getProperty('flutter.versionName')
if (flutterVersionName == null) {
    flutterVersionName = '1.0'
}

apply plugin: 'com.android.application'
apply plugin: 'kotlin-android'
apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"

android {
    namespace "com.oseerapp.oseer_health_bridge"
    compileSdkVersion 34
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = '17'
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        applicationId "com.oseerapp.oseer_health_bridge"
        // Min SDK 24 is required for Health Connect
        minSdkVersion 24
        targetSdkVersion 34
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig signingConfigs.debug
        }
    }
}

flutter {
    source '../..'
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version"
}

// Java toolchain configuration to ensure compatibility
java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(17)
    }
}
EOF
check_status "Fixed app/build.gradle"

# Step 2: Fix root build.gradle
print_message "$BLUE" "Fixing root build.gradle..."

# Back up the existing file if not already done
if [ ! -f "android/build.gradle.bak2" ]; then
    cp "android/build.gradle" "android/build.gradle.bak2"
    check_status "Backed up root build.gradle"
fi

# Create a fixed root build.gradle
cat > "android/build.gradle" << 'EOF'
buildscript {
    ext.kotlin_version = '1.8.20'
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath 'com.android.tools.build:gradle:8.2.1'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
    // Apply Java compatibility settings to all projects
    plugins.withType(JavaPlugin).configureEach {
        java {
            toolchain {
                languageVersion = JavaLanguageVersion.of(17)
            }
        }
    }
    
    // Disable Java compatibility checks that cause issues with Java 21
    tasks.withType(JavaCompile).configureEach {
        options.compilerArgs += ["-Xlint:-options"]
    }
}

rootProject.buildDir = '../build'
subprojects {
    project.buildDir = "${rootProject.buildDir}/${project.name}"
}

tasks.register("clean", Delete) {
    delete rootProject.buildDir
}
EOF
check_status "Fixed root build.gradle"

# Step 3: Fix gradle.properties
print_message "$BLUE" "Fixing gradle.properties..."

# Find Java 17 path
JAVA17_PATH=""

# Look for common Java 17 installations
if [ -d "/Library/Java/JavaVirtualMachines" ]; then
    # macOS path
    JAVA17_DIR=$(find /Library/Java/JavaVirtualMachines -name "jdk-17*" -o -name "temurin-17*" -o -name "zulu-17*" 2>/dev/null | head -1)
    if [ -n "$JAVA17_DIR" ]; then
        JAVA17_PATH="$JAVA17_DIR/Contents/Home"
    fi
elif [ -d "/usr/lib/jvm" ]; then
    # Linux path
    JAVA17_DIR=$(find /usr/lib/jvm -name "java-17*" -o -name "jdk-17*" -o -name "temurin-17*" -o -name "zulu-17*" 2>/dev/null | head -1)
    if [ -n "$JAVA17_DIR" ]; then
        JAVA17_PATH="$JAVA17_DIR"
    fi
fi

if [ -n "$JAVA17_PATH" ]; then
    print_message "$GREEN" "Found Java 17 at: $JAVA17_PATH"
else
    print_message "$YELLOW" "Could not find Java 17 installation. This might cause issues."
fi

# Back up the existing file if not already done
if [ ! -f "android/gradle.properties.bak2" ]; then
    cp "android/gradle.properties" "android/gradle.properties.bak2" 2>/dev/null || true
    check_status "Backed up gradle.properties (if it existed)"
fi

# Create a fixed gradle.properties
cat > "android/gradle.properties" << EOF
org.gradle.jvmargs=-Xmx4096M -Dfile.encoding=UTF-8 -XX:+UseParallelGC
android.useAndroidX=true
android.enableJetifier=true
android.defaults.buildfeatures.buildconfig=true
android.nonTransitiveRClass=false
android.nonFinalResIds=false

# Java compatibility settings
org.gradle.warning.mode=all
android.suppressUnsupportedCompileSdk=34
EOF

# Add Java home if we found Java 17
if [ -n "$JAVA17_PATH" ]; then
    echo "org.gradle.java.home=$JAVA17_PATH" >> "android/gradle.properties"
fi

check_status "Fixed gradle.properties"

# Step 4: Clean and rebuild
print_message "$BLUE" "Cleaning project..."
flutter clean
check_status "Cleaned project"

print_message "$BLUE" "Getting dependencies..."
flutter pub get
check_status "Got dependencies"

print_message "$GREEN" "====================================================="
print_message "$GREEN" "Android build fixes complete!"
print_message "$GREEN" "====================================================="
print_message "$BLUE" "The following fixes have been applied:"
print_message "$BLUE" "1. Fixed app/build.gradle with proper namespace and SDK settings"
print_message "$BLUE" "2. Fixed root build.gradle with updated Kotlin and Gradle versions"
print_message "$BLUE" "3. Updated gradle.properties with correct Java configuration"
print_message "$BLUE" "4. Cleaned project and refreshed dependencies"
print_message "$BLUE" ""
print_message "$BLUE" "Try building the app now with:"
print_message "$BLUE" "  flutter run --release"
print_message "$BLUE" ""
print_message "$YELLOW" "If you still encounter issues:"
print_message "$YELLOW" "1. Ensure Android SDK version 34 is installed via Android Studio's SDK Manager"
print_message "$YELLOW" "2. If build issues persist, try building with:"
print_message "$YELLOW" "  JAVA_HOME=$JAVA17_PATH flutter run --release"

# Make this script executable
chmod +x "$0"
check_status "Made script executable"