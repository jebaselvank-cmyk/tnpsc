# Implement AI-Generated Current Affairs Feature (Updated)

The goal is to add a "Daily Current Affairs" feature to the TNPSC Master app. This includes AI-driven news generation (triggered by admin), Firestore storage, text-to-speech support, and monetization via **Rewarded Ads** on card clicks.

## User Review Required

> [!IMPORTANT]
> - **Rewarded Ad**: Clicking a news card will trigger a Rewarded Ad. The user will only see the news details after completing the ad (or if ads fail to load).
> - **Collection Name**: The user mentioned `current_affairs_points`. I will investigate if this refers to the content collection or a points-tracking system. Typically, news content should be in `current_affairs`.
> - **Admin Access**: I'll assume that users with access to `AdminPanelScreen` are authorized to generate news.

## Proposed Changes

### [New Data Model]
Create a `NewsItem` model to handle current affairs data consistently.

#### [NEW] [news_item.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/models/news_item.dart)
- Fields: `id`, `titleEn`, `titleTa`, `contentEn`, `contentTa`, `category`, `date`, `timestamp`, `audioUrl` (optional, using TTS).

### [AI Service Update]
Add methods to generate news summaries specifically tailored for TNPSC exams.

#### [MODIFY] [ai_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/services/ai_service.dart)
- Add `generateAndSaveDailyNews(DateTime date)`: Fetches important news items, summarizes them in bilingual format, and saves to Firestore collection `current_affairs`.

### [Admin Dashboard]
Add the trigger for news generation.

#### [MODIFY] [admin_panel_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/screens/admin_panel_screen.dart)
- Add a new tool card: "Generate Daily Current Affairs".
- Implement `_showNewsGenDialog` to trigger AI generation.

### [Home Screen Integration]
Add a dedicated section for current affairs news.

#### [MODIFY] [home_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/screens/home_screen.dart)
- Add a `StreamBuilder` to fetch the latest news from `current_affairs`.
- Implement `_buildCurrentAffairsSection` with stylized news cards.
- Integrate `RewardService.showRewardAd` on card tap.

### [News Detail View]
A new screen to display full news details with audio support.

#### [NEW] [news_detail_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/screens/news_detail_screen.dart)
- Display full content in the selected language.
- Play/Stop audio button using `TtsService`.

## Verification Plan

### Automated Tests
- Check `AiService` logic for news generation.
- Verify Firestore data structure for `current_affairs`.

### Manual Verification
- **Admin**: Trigger news generation and verify success.
- **Home**: Verify news card appearance.
- **Ad Interaction**: Tap card -> Rewarded Ad shows -> On complete -> News Detail opens.
- **Audio**: Test TTS playback for news content.
