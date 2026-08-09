# Implementation Plan - Group Room Creation & Expiry Logic Refinement

This plan refines the logic for creating and joining group rooms, focusing on strict time constraints (IST), automatic end-time calculation, and room membership flexibility.

## User Review Required

> [!IMPORTANT]
> **Start Time Limit**: Group creation for the current day will be blocked after **11:00 PM IST**. Users attempting to create after 11:01 PM will receive a notification to try the next day.

> [!NOTE]
> **Automatic Duration**: The end time will default to **Start Time + 2 hours**, but will be capped at **11:59 PM IST** of the same day.

> [!TIP]
> **Switching Rooms**: Users will now be able to join a new room even if they are already hosting or joined in another active room. The latest room joined/created will overwrite the active membership in local memory.

## Proposed Changes

### [Room Setup & Creation]

#### [MODIFY] [room_setup_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/screens/room_setup_screen.dart)
- **Initialize with Current Time**: Update `initState` to set `_startTime` to exactly `now` (rounded to nearest minute).
- **11:00 PM Check**: Add a check in `_createRoom`. If `now > 11:00 PM`, show a toast: "இன்றைய நேரம் முடிந்தது. நாளை புதிய ரூம் உருவாக்கலாம்." (Today's time is over. You can create a new room tomorrow).
- **End Time Logic**:
    - Implement `endTime = max(preference, startTime + 2 hours)`.
    - Hard cap at `23:59`.
- **UI Refresh**: Ensure `_startTime` is updated every time the "Create" button or UI is accessed to prevent stale time errors.

#### [MODIFY] [room_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/services/room_service.dart)
- **Enforce 11 PM Limit**: Add backend validation in `createRoom` to reject attempts after 11:00 PM IST.
- **Membership Overwrite**: Modify `joinRoom` and `createRoom` to allow switching from an existing 'waiting'/'active' room. Instead of returning `already_in_room`, it will update the user's `last_room_played` and `room_history` to the new code.

### [Room Lobby & Expiry]

#### [MODIFY] [waiting_room_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/screens/waiting_room_screen.dart)
- **Expiry Check**: Update `_startTimeCheckTimer` to also check for room expiry (`now > endTime`).
- **Expiry UI**: If the room is expired, change the "Start" button or status text to "Expired" and prevent starting.
- **Admin Control**: Verify only the Host can see/press the "Start" button within the valid time window.
- **Share Card**: Update `_buildPosterGroupIDCard` to show the full "Start Time - End Time" range.

### [Utilities]

#### [MODIFY] [app_date.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/utils/app_date.dart)
- Add a helper `isAfter11PM()` to centralize this check using IST.

## Verification Plan

### Automated Tests
- None, as logic involves Firestore Transactions and complex Time interactions.

### Manual Verification
- **Create Room (Normal)**: Verify Start Time defaults to Now, and End Time is +2 hours.
- **Create Room (Late Night)**: Change device time to 11:05 PM IST and verify the "Next Day" toast appears.
- **End Time Persistence**: Set preference to 4 PM. Set Start to 1 PM -> End stays 4 PM. Set Start to 3 PM -> End moves to 5 PM.
- **Switch Room**: Create a room (Host). Then join another room via code. Verify you are now in the joined room.
- **Expiry**: Set End Time to 2 mins from now. Wait and verify room status changes to Expired.
