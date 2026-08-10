# Implementation Plan - Room Creation Cost Logic Update

The goal is to refine the room creation cost logic:
1.  The first room created each day is free for up to 10 users.
2.  Starting from the second room, a base cost of 200 points is applied.
3.  If the number of users exceeds 10, an extra cost of 100 points is applied (even for the first room).

## User Review Required

> [!IMPORTANT]
> The "extra cost" for players will be applied as follows:
> - 11 to 30 players: +100 points.
> - 31 to 100 players: +100 points for every additional 10 players.
> This matches the current logic but ensures it's correctly applied to the first room.

## Proposed Changes

### [Room Service]

#### [MODIFY] [room_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/services/room_service.dart)
- Refine `calculateRoomCost` to explicitly handle the "first room free" and "extra players cost" logic separately.
- Ensure `isAdmin` check remains at the top.

### [Room Setup Screen]

#### [MODIFY] [room_setup_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/screens/room_setup_screen.dart)
- Update the cost display text to show "இலவசம் (Free)" when the required points are 0.
- Ensure the `extra_player_cost` message is only shown when relevant.

## Verification Plan

### Manual Verification
1.  **First Room (10 players)**: Create the first room of the day with 10 players. Verify cost is 0.
2.  **First Room (20 players)**: Create the first room of the day with 20 players. Verify cost is 100.
3.  **Second Room (10 players)**: Create the second room of the day with 10 players. Verify cost is 200.
4.  **Second Room (20 players)**: Create the second room of the day with 20 players. Verify cost is 300.
