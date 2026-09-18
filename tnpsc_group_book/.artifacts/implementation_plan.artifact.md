# Implementation Plan - Address Android 15 Edge-to-Edge and R8 Recommendations

Address three major recommendations:
1.  **Edge-to-Edge Support**: Ensure the app targets SDK 35 and correctly implements edge-to-edge.
2.  **Deprecated APIs**: Fix a syntax error in `MainActivity.kt` and rely on `enableEdgeToEdge()` to handle system bar colors idiomatic to Android 15.
3.  **R8 Optimization**: Upgrade Android Gradle Plugin (AGP) to 9.0.0 and ensure optimized resource shrinking is enabled.

## Proposed Changes

### Android App Module

#### [MODIFY] [MainActivity.kt](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/android/app/src/main/kotlin/com/tnpsc/groupbook/tnpsc_group_book/MainActivity.kt)
- Fix typo: Change `override function onCreate` to `override fun onCreate`.
- Ensure `enableEdgeToEdge()` is called before `super.onCreate(savedInstanceState)`.

#### [MODIFY] [build.gradle.kts (App)](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/android/app/build.gradle.kts)
- Explicitly set `targetSdk = 35` to ensure Android 15 behavior.
- Ensure `isShrinkResources = true` and `isMinifyEnabled = true` are set (already present).
- Ensure `proguard-android-optimize.txt` is used for ProGuard rules.

### Android Project Configuration

#### [MODIFY] [settings.gradle.kts](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/android/settings.gradle.kts)
- Upgrade `com.android.application` plugin version to `9.0.0-alpha01` (or latest available 9.0 version).

#### [MODIFY] [gradle.properties](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/android/gradle.properties)
- Verify `android.r8.optimizedResourceShrinking=true` is present (already present).

## Verification Plan

### Manual Verification
- Build the Android app and check for compilation errors (especially in `MainActivity.kt`).
- Verify that the app runs on an Android 15 emulator/device and displays edge-to-edge.
- Check the build logs to confirm that R8 is using the optimized resource shrinking (integrated with AGP 9.0).
