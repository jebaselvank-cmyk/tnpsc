# Implementation Plan: Add WhatsApp Group Integration

This plan outlines adding a "Join WhatsApp Group" feature to the app, allowing users to easily join the official community for updates and study tips.

## Proposed Changes

### [Utils] [AppLanguage](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/utils/app_language.dart)

- Add `join_whatsapp` and `whatsapp_desc` keys to the `getString` method with Tamil and English translations.

### [Screens] [ProfileScreen](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/screens/profile_screen.dart)

- Add a new `ListTile` in the "Others" section for WhatsApp, using a WhatsApp icon and the link `https://chat.whatsapp.com/`.
- *Note: User should provide the specific invite link.*

### [Screens] [HomeScreen](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/screens/home_screen.dart)

- Add a new "Join Community" banner or card below the Quick Actions section to encourage users to join the WhatsApp group.
- Implement a `_launchURL` method in `HomeScreen` (similar to `ProfileScreen`) to handle external links.

## Verification Plan

### Manual Verification
1. Open the Profile screen and verify the "Join WhatsApp" button exists and opens WhatsApp.
2. Open the Home screen and verify the WhatsApp community banner is visible and functional.
3. Check both Tamil and English language modes to ensure strings are translated correctly.
