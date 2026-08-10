# Implementation Plan - Comprehensive General Studies Syllabus Update

This plan expands the **General Studies** curriculum with 21 specialized topics, enhancing AI rotation and manual study navigation.

## Proposed Changes

### [AI Service]

#### [MODIFY] [ai_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/services/ai_service.dart)
- **Add GS Topic Definitions**: Define `_gsTopics` with 21 items:
    1. General Science, Science and Technology, Environment and Ecology.
    2. Indian History, National Movement, Polity, Economy, Geography.
    3. Tamil Nadu History, Culture, Heritage, Administration, Development Admin.
    4. Social Issues, Government Schemes.
    5. Important Personalities, Awards, Sports, Books and Authors.
    6. Mixed General Studies Quiz.
- **Implement `_getGsTopicsForDate`**: Deterministically select 3-5 focus topics each day.
- **Update Prompts**: Integrate GS focus topics into `generateAndSaveDailyQuiz` and `generateAndSaveMockQuiz`.

### [Subject Data]

#### [MODIFY] [subject.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_app/tnpsc_group_book/lib/models/subject.dart)
- **Redistribute Topics**: Update the `tnpscSubjects` list to include these 21 topics under their respective domains:
    - **General Science**: + Science & Tech, Environment.
    - **Indian History**: + National Movement (as subtopic if needed).
    - **TN History (Unit 8 & 9)**: + Culture, Heritage, Administration, Development Admin, Social Issues.
    - **Current Affairs**: Restore/Enable subject and add Government Schemes, Personalities, Awards, Sports, Books.

## Verification Plan

### Automated Tests
- Run `analyze_file` to ensure code correctness.

### Manual Verification
- Verify that the GS section in the "Select Category" bottom sheet correctly shows the expanded topics.
- Confirm that AI-generated GS questions follow the daily focus topics.
