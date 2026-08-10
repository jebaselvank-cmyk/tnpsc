# Walkthrough - Auto-expiry of Room Cards

I have implemented the logic to automatically remove expired room cards from the `RoomSetupScreen` and restore the "Create Room" option once a hosted room expires.

## Changes Made

### 1. Room Service Logic Update
In [room_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/services/room_service.dart), I modified `getActiveHostRoom()` and `getActiveJoinedRoom()`:
- **Expiry Detection**: Added a check to compare the room's `endTime` with the current time (IST).
- **Auto-Finish**: If a hosted room is found to be expired, its status is automatically updated to `'finished'` in Firestore.
- **Null Safety**: Expired rooms are now returned as `null`, causing the UI to hide the corresponding cards.
- **Status Support**: Included the `'starting'` status in active room checks to ensure rooms in countdown are also handled.

### 2. Room Setup Screen UI Enhancement
In [room_setup_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/screens/room_setup_screen.dart):
- **Periodic Refresh**: Added a `_refreshTimer` that triggers every 30 seconds to check for room expiry while the user is on the screen.
- **Dynamic UI**: When `_activeRoomData` becomes `null` (due to expiry), the "Create Room" form automatically reappears, allowing the user to host a new session immediately.

### 3. Room Creation Cost Logic
I have updated the cost calculation to match your requirements:
- **First Room Free**: The first room created each day is **free (0 pts)** if it has 10 or fewer players.
- **Extra Players**: If you increase the players beyond 10 in the first room, an **extra cost** is applied.
- **Subsequent Rooms**: From the second room onwards, a **base cost of 200 pts** is applied, plus any extra player costs.
- **UI Clarity**: The `RoomSetupScreen` now correctly displays "Free" when the total cost is 0 and provides a clear breakdown of base vs extra costs.

### 4. Strict Point Verification & Contextual Messages
I have improved the room creation flow to handle insufficient points more gracefully:
- **Strict Verification**: The app now checks for points **before** starting any ads. If points are insufficient, it immediately shows a message instead of an ad.
- **Contextual Messages**:
    - If it's the **first room** but the user selected > 10 players: "Only 10 players are free. You need extra points for more players."
    - If it's a **subsequent room**: "Creating a second room requires 200 points."
- **Earn Points Option**: Added an "Earn 100 Points" button directly in the error dialog. This allows users to watch a rewarded ad and get exactly **100 points** to help them reach their goal.
- **Limit Handling**: The "Earn Points" option respects the daily rewarded ad limit (3 per day) and provides a clear message when the limit is reached.

## Verification Results

- [x] **Point Check**: Verified that `_createRoom` stops immediately and shows `_showNeedPointsMessage` when balance is too low.
- [x] **Ad Reward**: Confirmed that the "Earn 100 Points" button awards exactly 100 points upon completion.
- [x] **Localization**: Verified that the new specific error messages are correctly displayed in both Tamil and English.

> [!TIP]
> This change ensures that users aren't stuck with "ghost" rooms that have already ended, providing a much smoother user experience.
