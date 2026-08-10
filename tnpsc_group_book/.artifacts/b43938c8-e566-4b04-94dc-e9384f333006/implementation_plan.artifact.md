# Implementation Plan - Relaxed First Room Point Requirement

The goal is to allow users to create their **first room** of the day even if they have **0 points**, provided they watch a rewarded ad. If they choose more than 10 players (which normally costs 100+ points) and don't have enough points, we will still allow it but show a Toast message explanation.

## User Review Required

> [!IMPORTANT]
> - For the **first room**, the app will proceed to the Reward Ad even if the user has 0 points.
> - For **subsequent rooms**, the strict 200-point check remains. No ad will be shown if points are insufficient.
> - Points will be deducted from the user's balance down to 0 if they have less than the required amount for the first room's extra players.

## Proposed Changes

### [Room Service]

#### [MODIFY] [room_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/services/room_service.dart)
- Modify the `runTransaction` in `createRoom`:
    - Remove the `insufficient_points` return condition specifically when `currentAttempts == 0`.
    - Calculate `pointsToDeduct` as `min(currentPoints, cost)` for the first attempt.

### [Room Setup Screen]

#### [MODIFY] [room_setup_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/screens/room_setup_screen.dart)
- Update `_createRoom`:
    - Bypass the `!_hasEnoughPointsForRoom()` check if it's the first attempt (`attempts == 0`).
    - After room creation, show a SnackBar (Toast) if points were insufficient for the selected player count:
        - Tamil: *"10 வீரர்களுக்கு மேல் சேர்க்க பாயிண்ட்டுகள் தேவை, இருப்பினும் முதல் முறை என்பதால் அனுமதிக்கப்படுகிறது."*
        - English: *"Points required for extra players, but allowed for your first room match."*

## Verification Plan

### Manual Verification
1.  **Scenario A (0 Points, 20 Players, 1st Attempt)**: Verify ad plays, room is created, and "Points required for extra players..." Toast appears.
2.  **Scenario B (0 Points, 10 Players, 2nd Attempt)**: Verify "Points Required" dialog appears immediately.
3.  **Scenario C (100 Points, 20 Players, 1st Attempt)**: Verify ad plays, room is created, points become 0, and no error Toast appears.
