# AdMob Optimization for TNPSC Master

Optimize the `NativeAdWidget` to reduce unnecessary requests and improve the match rate/impressions.

## Proposed Changes

### [Component: Native Ad]

#### [MODIFY] [pubspec.yaml](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/pubspec.yaml)
- Add `visibility_detector: ^0.4.0+2` to dependencies.

#### [MODIFY] [native_ad_widget.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/widgets/native_ad_widget.dart)
- Implement `VisibilityDetector` to load ads only when visible.
- Implement exponential backoff for ad retry logic (60s, 120s, 240s, 300s).
- Improve ad lifecycle management (pause/resume).
- Remove automatic loading in `initState`.

## Verification Plan

### Manual Verification
- Verify that ads only load when the user scrolls near the `NativeAdWidget`.
- Verify that ad refreshes only occur after an impression is recorded and the specified interval has passed.
- Check logs for "NativeAd loaded successfully" and "NativeAd failed" to verify retry logic.
