---
name: flutter-apk-build
description: Build Flutter projects into release APKs — locate SDK, fix compilation errors, handle Android build issues, and output the final APK.
---

# Flutter APK Build Workflow

Build a Flutter project into a release APK. This workflow handles the common cycle of: locate Flutter SDK → attempt build → fix errors → retry → locate output APK.

## When To Use

- User asks to "打包" (package) a Flutter project
- User asks for "apk" output
- User asks to "生成安卓apk" (generate Android APK)

## Workflow

### Step 1: Discover Project Structure

```bash
# List project root
ls -la "<project_path>"

# Find key files
Glob: pubspec.yaml in <project_path>
Glob: build.gradle* in <project_path>/android
Glob: lib/**/*.dart in <project_path>
```

### Step 2: Locate Flutter SDK

Flutter is NOT in PATH on this machine. Known locations:

```bash
# Primary location
D:\flutter\bin\flutter.bat

# Check if it exists
ls "D:/flutter/bin/flutter.bat"
```

If not found at `D:\flutter`, search common locations:
```bash
ls "C:/flutter/bin/flutter.bat"
ls "$LOCALAPPDATA/flutter/bin/flutter.bat"
where flutter 2>/dev/null
```

### Step 3: Read Build Configuration

Read and check:
1. `pubspec.yaml` — dependencies, SDK constraints
2. `android/app/build.gradle.kts` or `build.gradle` — compileSdkVersion, minSdkVersion
3. `android/build.gradle.kts` — Kotlin/AGP versions

### Step 4: Attempt Build

**Always use cmd.exe for Flutter commands on Windows:**

```bash
cmd /c "cd /d <project_path> && D:\flutter\bin\flutter.bat build apk --release"
```

**Alternative (if cmd fails):**
```powershell
powershell -Command "Set-Location '<project_path>'; D:\flutter\bin\flutter.bat build apk --release"
```

**Timeout:** Set to 600000ms (10 minutes) for Flutter builds.

### Step 5: Fix Common Build Errors

**Error: `import` not found / unresolved types**
- Read the file with the error
- Check if the imported package exists in `pubspec.yaml`
- Fix import paths (relative vs package imports)

**Error: `flutter: command not found` in bash**
- Use `cmd /c` wrapper or full path `D:\flutter\bin\flutter.bat`

**Error: Gradle version mismatch**
- Check `android/gradle/wrapper/gradle-wrapper.properties`
- Update `distributionUrl` to compatible version

**Error: SDK version too low/high**
- Update `compileSdkVersion` and `minSdkVersion` in `android/app/build.gradle.kts`
- Current recommended: `compileSdk = 34`, `minSdk = 21`

**Error: Kotlin/AGP version conflict**
- Check `android/build.gradle.kts` for Kotlin plugin version
- Ensure AGP version matches Gradle version

### Step 6: Retry Build

After fixing errors, retry the build command. Track iteration count — if more than 3 retries, summarize remaining issues for user.

### Step 7: Locate Output APK

```bash
# Standard Flutter output location
ls -la <project_path>/build/app/outputs/flutter-apk/

# The release APK is typically:
# <project_path>/build/app/outputs/flutter-apk/app-release.apk
```

### Step 8: Report

- APK file path and size
- Any warnings during build
- Summary of errors that were fixed

## Common Pitfalls

1. **Flutter not in PATH** — Always use full path: `D:\flutter\bin\flutter.bat`
2. **Bash vs cmd** — Flutter/Gradle work better with `cmd /c` on Windows
3. **Build cache corruption** — Try `flutter clean` before rebuild
4. **Missing Android SDK** — Flutter needs Android SDK with platform-tools and build-tools
5. **Java version** — Flutter/Gradle may need specific Java version (usually Java 17)

## Build Command Quick Reference

```bash
# Clean build
cmd /c "cd /d <path> && D:\flutter\bin\flutter.bat clean"

# Get dependencies
cmd /c "cd /d <path> && D:\flutter\bin\flutter.bat pub get"

# Build release APK
cmd /c "cd /d <path> && D:\flutter\bin\flutter.bat build apk --release"

# Build debug APK (faster, for testing)
cmd /c "cd /d <path> && D:\flutter\bin\flutter.bat build apk --debug"
```
