# Admin Full Access Update

Ensure Admin users (e.g., `adminjeba@gmail.com`) have unrestricted access to all app features, specifically bypassing time limits and daily match limits.

## User Review Required

> [!IMPORTANT]
> Admin users will now be able to:
> 1. **Bypass the 11 PM limit**: Create rooms at any time of the day.
> 2. **Bypass Daily Limits**: Join or create an unlimited number of rooms per day.
> 3. **Points**: Continue to have 0 point costs for all operations.

## Proposed Changes

### [Component] Room Service Logic

#### [MODIFY] [room_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/services/room_service.dart)
- `createRoom`: Bypass the `AppDate.isAfter11PM()` check if the user is an admin.
- `canPlayToday`: Always return `true` if the user is an admin.

### [Component] UI - Room Setup Screen

#### [MODIFY] [room_setup_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/screens/room_setup_screen.dart)
- `_createRoom`: Bypass the `AppDate.isAfter11PM()` UI check if `_isAdmin` is true.

## Verification Plan

### Manual Verification
1. Login as Admin and attempt to create a room after 11 PM (mocked or real).
2. Login as Admin and verify that the daily limit doesn't block room entry/creation after multiple attempts.
3. Verify regular users are still subject to the 11 PM and daily limits.
