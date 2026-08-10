# Implementation Plan - Fix Leaderboard Rank Refresh

The goal is to fix the issue where the user's rank in the sticky card at the bottom of the leaderboard screen does not refresh when the refresh button is pressed.

## User Review Required

> [!IMPORTANT]
> - The current logic uses a local cache (Hive) for the rank calculation to save Firestore costs.
> - Pressing the "Refresh" button will now explicitly invalidate this cache and force a new server-side calculation.

## Proposed Changes

### [Services]

#### [MODIFY] [firestore_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/services/firestore_service.dart)
- Update `getUserBestResultToday` method:
    - Add `bool forceRefresh = false` parameter.
    - If `forceRefresh` is true, call `HiveService.invalidateRankCache(isDaily)` before checking the cache.
    - Ensure the latest score is fetched from the server by bypassing the local cache if needed (Firestore already does this with default `GetOptions`).

### [Screens]

#### [MODIFY] [leaderboard_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/screens/leaderboard_screen.dart)
- In `_MyRankStickyCardState`:
    - Update `_loadFuture` to accept `bool forceRefresh = false`.
    - Update the `IconButton` (refresh) `onPressed` callback to call `_loadFuture(forceRefresh: true)`.

## Verification Plan

### Manual Verification
1.  Open the Leaderboard screen.
2.  Note the current rank in the bottom sticky card.
3.  Press the refresh button in the sticky card.
4.  Verify that the rank is updated if changes have occurred on the server (you can simulate this by completing a quiz on another device or manually editing Firestore if testing environment allows).
5.  Verify that the rank still appears correctly after switching tabs (Daily vs Mock).
