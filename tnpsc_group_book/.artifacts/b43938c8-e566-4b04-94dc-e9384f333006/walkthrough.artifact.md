# Walkthrough - Fixed Leaderboard Rank Refresh

I have fixed the issue where the user's rank in the sticky card at the bottom of the leaderboard screen was not updating when the refresh button was pressed.

## Changes Made

### 1. Firestore Service Enhancement
In [firestore_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/services/firestore_service.dart), I updated `getUserBestResultToday()`:
- **`forceRefresh` Parameter**: Added a parameter to allow explicitly bypassing the local cache.
- **Cache Invalidation**: When `forceRefresh` is true, it calls `HiveService.invalidateRankCache()` to clear old data.
- **Server Fetch**: Forces Firestore to fetch from the server instead of the cache when refreshing.

### 2. Leaderboard Screen UI Update
In [leaderboard_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/screens/leaderboard_screen.dart):
- **Refresh Action**: Updated the refresh button's `onPressed` logic to call the enhanced service method with `forceRefresh: true`.
- **State Management**: Ensured the UI rebuilds immediately with the latest server-side data.

## Verification Results

- [x] **Refresh Button**: Confirmed that clicking the button now triggers a server-side fetch and clears the local cache.
- [x] **Tab Consistency**: Verified that switching between Daily and Mock tabs still loads data correctly while respecting the new refresh logic.
- [x] **Cost Efficiency**: Local caching is still used by default to save Firestore reads; it is only bypassed when the user manually requests a refresh.

> [!TIP]
> Users can now manually sync their latest rank if they see others moving ahead on the main leaderboard list.
