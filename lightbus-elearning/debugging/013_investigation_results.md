-- =============================================================================
-- COMPREHENSIVE STUDENT DATA INVESTIGATION
-- =============================================================================
-- 
-- This query investigates student 46246124-a43f-4980-b05e-97670eed3f32
-- to analyze their cards, reviews, due sessions, and study analytics
-- for comparison with frontend debug panels
-- =============================================================================

-- Set the student ID as a variable for easy reference
\set student_id '46246124-a43f-4980-b05e-97670eed3f32'

-- =============================================================================
-- 1. STUDENT BASIC INFO AND PROFILE
-- =============================================================================

| section                             | student_id                           | student_name | student_email             | role    | account_created               | last_profile_update           |
| ----------------------------------- | ------------------------------------ | ------------ | ------------------------- | ------- | ----------------------------- | ----------------------------- |
| === STUDENT PROFILE INFORMATION === | 46246124-a43f-4980-b05e-97670eed3f32 | Test         | owczarek.patryk@yahoo.com | student | 2025-06-02 13:59:13.749795+00 | 2025-06-02 13:59:13.749795+00 |
-- =============================================================================
-- 2. STUDENT'S LESSON PARTICIPATION
-- =============================================================================

| section                      | lesson_id                            | lesson_name | lesson_scheduled       | teacher_name | student_enrolled_date         | total_cards_in_lesson |
| ---------------------------- | ------------------------------------ | ----------- | ---------------------- | ------------ | ----------------------------- | --------------------- |
| === LESSON PARTICIPATION === | fe2ca0c6-511c-47eb-9b8a-4e90bab80786 | test        | 2025-06-04 08:00:00+00 | Patryk       | 2025-06-03 17:28:14.800646+00 | 2                     |
| === LESSON PARTICIPATION === | 3a87e495-1a24-4360-a078-0ea601368e90 | test 1      | 2025-06-03 08:00:00+00 | Patryk       | 2025-06-02 17:15:53.602247+00 | 0                     |
-- =============================================================================
-- 3. STUDENT'S ACCEPTED CARDS ANALYSIS
-- =============================================================================

| section                         | card_id                              | lesson_id                            | lesson_name | front_content | back_content | difficulty_level | card_created                  | first_accepted_date           | current_card_status |
| ------------------------------- | ------------------------------------ | ------------------------------------ | ----------- | ------------- | ------------ | ---------------- | ----------------------------- | ----------------------------- | ------------------- |
| === ACCEPTED CARDS ANALYSIS === | 68dfdadb-424e-4ea0-9456-637526cd0d22 | fe2ca0c6-511c-47eb-9b8a-4e90bab80786 | test        | safs          | sss          | 2                | 2025-06-03 19:12:45.207339+00 | 2025-06-03 19:12:45.207339+00 | accepted            |
| === ACCEPTED CARDS ANALYSIS === | 46b417ed-d44e-4e77-b236-4f26dc5f8636 | fe2ca0c6-511c-47eb-9b8a-4e90bab80786 | test        | asd           | fff          | 2                | 2025-06-03 19:12:39.327635+00 | 2025-06-03 19:12:39.327635+00 | not_accepted        |

-- =============================================================================
-- 4. COMPLETED REVIEWS ANALYSIS WITH TIMEZONE INFO
-- =============================================================================

| section                            | review_id                            | card_id                              | card_front | lesson_name | completed_at_utc              | completed_at_warsaw        | completed_date_utc | completed_date_warsaw | quality_rating | response_time_ms | interval_days | ease_factor | repetition_count | card_status | timezone_date_status |
| ---------------------------------- | ------------------------------------ | ------------------------------------ | ---------- | ----------- | ----------------------------- | -------------------------- | ------------------ | --------------------- | -------------- | ---------------- | ------------- | ----------- | ---------------- | ----------- | -------------------- |
| === COMPLETED REVIEWS ANALYSIS === | aa701437-c640-49b6-b85a-add95597a6ef | 68dfdadb-424e-4ea0-9456-637526cd0d22 | safs       | test        | 2025-06-04 15:06:37.234893+00 | 2025-06-04 17:06:37.234893 | 2025-06-04         | 2025-06-04            | 4              | 3759             | 1             | 2.50        | 1                | accepted    | DATE_ALIGNED         |
| === COMPLETED REVIEWS ANALYSIS === | 0ee8971b-fb2a-48ea-8c1a-98543c7f0be5 | 68dfdadb-424e-4ea0-9456-637526cd0d22 | safs       | test        | 2025-06-03 19:27:50.918564+00 | 2025-06-03 21:27:50.918564 | 2025-06-03         | 2025-06-03            | 4              | 1973             | 1             | 2.50        | 0                | accepted    | DATE_ALIGNED         |
| === COMPLETED REVIEWS ANALYSIS === | 775ecf63-ff70-43c1-b460-3dbbcf324fcf | 46b417ed-d44e-4e77-b236-4f26dc5f8636 | asd        | test        | 2025-06-03 19:25:44.470619+00 | 2025-06-03 21:25:44.470619 | 2025-06-03         | 2025-06-03            | 4              | 5811             | 1             | 2.50        | 0                | accepted    | DATE_ALIGNED         |
-- =============================================================================
-- 5. DUE REVIEWS SESSION ANALYSIS
-- =============================================================================

| section                              | review_id                            | card_id                              | card_front | lesson_name | scheduled_for_utc             | scheduled_for_warsaw       | scheduled_date_utc | scheduled_date_warsaw | today_utc  | today_warsaw | interval_days | ease_factor | repetition_count | card_status | due_status_utc | due_status_warsaw | days_until_due_utc | days_until_due_warsaw |
| ------------------------------------ | ------------------------------------ | ------------------------------------ | ---------- | ----------- | ----------------------------- | -------------------------- | ------------------ | --------------------- | ---------- | ------------ | ------------- | ----------- | ---------------- | ----------- | -------------- | ----------------- | ------------------ | --------------------- |
| === DUE REVIEWS SESSION ANALYSIS === | dedba258-b860-4a15-ab6c-f231e55fde7c | 68dfdadb-424e-4ea0-9456-637526cd0d22 | safs       | test        | 2025-06-10 15:06:37.234893+00 | 2025-06-10 17:06:37.234893 | 2025-06-10         | 2025-06-10            | 2025-06-07 | 2025-06-07   | 6             | 2.50        | 2                | accepted    | NOT_DUE_UTC    | NOT_DUE_WARSAW    | 3                  | 3                     |

-- =============================================================================
-- 6. STUDY ANALYTICS - USER STATS FUNCTION RESULTS
-- =============================================================================

| section                                               | function_type                | total_reviews | average_quality    | study_streak | cards_learned | cards_due_today | next_review_date | weekly_progress               | monthly_progress                                                                                                          | total_lessons | lessons_with_progress |
| ----------------------------------------------------- | ---------------------------- | ------------- | ------------------ | ------------ | ------------- | --------------- | ---------------- | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ------------- | --------------------- |
| === TIMEZONE-AWARE get_user_stats_with_timezone() === | get_user_stats_with_timezone | 6             | 4.0000000000000000 | 0            | 0             | 0               | 2025-06-10       | ["0","0","0","1","2","0","0"] | ["0","0","0","1","2","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"] | 2             | 1                     |

-- =============================================================================
-- 7. TODAY'S STUDY STATISTICS COMPARISON
-- =============================================================================

| section                                                      | function_type                       | cards_studied_today | total_cards_ready | study_time_minutes | sessions_completed | new_cards_accepted_today | cards_mastered_today |
| ------------------------------------------------------------ | ----------------------------------- | ------------------- | ----------------- | ------------------ | ------------------ | ------------------------ | -------------------- |
| === TIMEZONE-AWARE get_today_study_stats_with_timezone() === | get_today_study_stats_with_timezone | 0                   | 0                 | 0                  | 0                  | 0                        | 0                    |

-- =============================================================================
-- 8. PROGRESS TRACKING TABLE ANALYSIS
-- =============================================================================

| section                                  | lesson_id                            | lesson_name | cards_total | cards_reviewed | cards_learned | average_quality | study_streak | progress_last_review_date | progress_next_review_date | progress_created              | progress_updated              | actual_last_review_date_utc | actual_last_review_date_warsaw | consistency_status |
| ---------------------------------------- | ------------------------------------ | ----------- | ----------- | -------------- | ------------- | --------------- | ------------ | ------------------------- | ------------------------- | ----------------------------- | ----------------------------- | --------------------------- | ------------------------------ | ------------------ |
| === PROGRESS TRACKING TABLE ANALYSIS === | fe2ca0c6-511c-47eb-9b8a-4e90bab80786 | test        | 2           | 1              | 0             | 4.00            | 0            | 2025-06-04                | 2025-06-10                | 2025-06-03 17:28:14.800646+00 | 2025-06-04 15:06:37.234893+00 | 2025-06-04                  | 2025-06-04                     | CONSISTENT         |
-- =============================================================================
-- 9. CARDS FOR STUDY FUNCTION RESULTS
-- =============================================================================

returned: Success. No rows returned

-- =============================================================================
-- 10. TIMEZONE BOUNDARY ANALYSIS
-- =============================================================================

| section                            | current_utc_time              | current_warsaw_time        | current_utc_date | current_warsaw_date | date_alignment_status | current_utc_hour | current_warsaw_hour |
| ---------------------------------- | ----------------------------- | -------------------------- | ---------------- | ------------------- | --------------------- | ---------------- | ------------------- |
| === TIMEZONE BOUNDARY ANALYSIS === | 2025-06-07 11:00:50.019779+00 | 2025-06-07 13:00:50.019779 | 2025-06-07       | 2025-06-07          | DATES_ALIGNED         | 11               | 13                  |

-- =============================================================================
-- 11. INVESTIGATION SUMMARY
-- =============================================================================

| section                       | total_lessons_enrolled | total_cards_ever_studied | total_completed_reviews | total_pending_reviews | progress_records_count | timezone_date_mismatches | reviews_last_7_days | cards_due_now_utc | cards_due_now_warsaw |
| ----------------------------- | ---------------------- | ------------------------ | ----------------------- | --------------------- | ---------------------- | ------------------------ | ------------------- | ----------------- | -------------------- |
| === INVESTIGATION SUMMARY === | 2                      | 2                        | 3                       | 1                     | 1                      | 0                        | 3                   | 0                 | 0                    |

Front End:
 Debug: Timezone & Date Info
User Timezone: Europe/Warsaw

Cards Due: 0 | New Cards: 0

Study Streak: 0

Next Review: None

Debug: Streak Card Info
User Timezone: Europe/Warsaw

Current Streak: 0

Next Review Date (Raw): None

Next Review Date (Formatted): None

Weekly Progress: 0/7

Debug: Date Processing Info
User Timezone: Europe/Warsaw

Chart Type: weekly

Data Points: 7

Today's Data: {"day":"Sat","reviews":0,"date":"2025-06-06","isToday":true}

Debug: Due Cards Section
User Timezone: Europe/Warsaw

New Cards: 0

Due Cards: 0

Today Stats Loading: No

Today Stats: {"cards_studied_today":0,"total_cards_ready":0,"study_time_minutes":0,"sessions_completed":0,"new_cards_accepted_today":0,"cards_mastered_today":0}