| test_section             | lesson_id                            | study_streak | last_review_date | cards_reviewed | cards_learned | average_quality | next_review_date | created_at                    | updated_at                    |
| ------------------------ | ------------------------------------ | ------------ | ---------------- | -------------- | ------------- | --------------- | ---------------- | ----------------------------- | ----------------------------- |
| Current Progress Records | fe2ca0c6-511c-47eb-9b8a-4e90bab80786 | 0            | 2025-06-07       | 3              | 0             | 4.00            | 2025-06-08       | 2025-06-03 17:28:14.800646+00 | 2025-06-07 12:29:58.422563+00 |

| test_section    | id                                   | name | email                     | role    | created_at                    |
| --------------- | ------------------------------------ | ---- | ------------------------- | ------- | ----------------------------- |
| Student Profile | 46246124-a43f-4980-b05e-97670eed3f32 | Test | owczarek.patryk@yahoo.com | student | 2025-06-02 13:59:13.749795+00 |

| test_section         | lesson_id                            | lesson_name | teacher_id                           | enrolled_at                   |
| -------------------- | ------------------------------------ | ----------- | ------------------------------------ | ----------------------------- |
| Lesson Participation | fe2ca0c6-511c-47eb-9b8a-4e90bab80786 | test        | d097bb55-a9b8-4829-a7c9-449a5d3ae3a7 | 2025-06-03 17:28:14.800646+00 |
| Lesson Participation | 3a87e495-1a24-4360-a078-0ea601368e90 | test 1      | d097bb55-a9b8-4829-a7c9-449a5d3ae3a7 | 2025-06-02 17:15:53.602247+00 |

| test_section            | total_reviews | completed_reviews | first_review                  | latest_review                 |
| ----------------------- | ------------- | ----------------- | ----------------------------- | ----------------------------- |
| Total Completed Reviews | 8             | 5                 | 2025-06-03 19:25:44.470619+00 | 2025-06-07 12:29:58.422563+00 |

| test_section                  | review_date | reviews_count | avg_quality        | quality_ratings |
| ----------------------------- | ----------- | ------------- | ------------------ | --------------- |
| Reviews by Date (Last 7 Days) | 2025-06-07  | 2             | 4.0000000000000000 | 4, 4            |
| Reviews by Date (Last 7 Days) | 2025-06-04  | 1             | 4.0000000000000000 | 4               |
| Reviews by Date (Last 7 Days) | 2025-06-03  | 2             | 4.0000000000000000 | 4, 4            |

| test_section                         | total_reviews | average_quality    | study_streak | cards_learned | cards_due_today | next_review_date | weekly_progress               | monthly_progress                                                                                                          | total_lessons | lessons_with_progress |
| ------------------------------------ | ------------- | ------------------ | ------------ | ------------- | --------------- | ---------------- | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ------------- | --------------------- |
| get_user_stats_with_timezone Results | 10            | 4.0000000000000000 | 0            | 0             | 0               | 2025-06-08       | ["2","0","0","1","2","0","0"] | ["2","0","0","1","2","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"] | 2             | 1                     |

| test_section                    | total_reviews | average_quality    | study_streak | cards_learned | cards_due_today | next_review_date | weekly_progress               | monthly_progress                                                                                                          | total_lessons | lessons_with_progress |
| ------------------------------- | ------------- | ------------------ | ------------ | ------------- | --------------- | ---------------- | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ------------- | --------------------- |
| get_user_stats Results (Direct) | 10            | 4.0000000000000000 | 0            | 0             | 0               | 2025-06-08       | ["2","0","0","1","2","0","0"] | ["2","0","0","1","2","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"] | 2             | 1                     |

ERROR:  42883: operator does not exist: date - bigint
HINT:  No operator matches the given name and argument types. You might need to add explicit type casts.
QUERY:  WITH daily_activity AS (
                SELECT DISTINCT get_client_date(r.completed_at, p_client_timezone) as review_date
                FROM public.sr_reviews r
                INNER JOIN public.sr_cards c ON r.card_id = c.id
                WHERE r.student_id = progress_record.student_id
                  AND c.lesson_id = progress_record.lesson_id
                  AND r.completed_at IS NOT NULL
                ORDER BY review_date DESC
				
				
				
| test_section                | card_id                              | lesson_id                            | front_content | status   | lesson_name |
| --------------------------- | ------------------------------------ | ------------------------------------ | ------------- | -------- | ----------- |
| Available Cards for Testing | 46b417ed-d44e-4e77-b236-4f26dc5f8636 | fe2ca0c6-511c-47eb-9b8a-4e90bab80786 | asd           | approved | test        |
| Available Cards for Testing | 68dfdadb-424e-4ea0-9456-637526cd0d22 | fe2ca0c6-511c-47eb-9b8a-4e90bab80786 | safs          | approved | test        |
| Available Cards for Testing | ca3d9b60-e900-4c4e-bab3-1312304f32d4 | fe2ca0c6-511c-47eb-9b8a-4e90bab80786 | aq23e         | approved | test        |
| Available Cards for Testing | d60a639d-d1f3-40b5-8668-90f75fa46f7b | fe2ca0c6-511c-47eb-9b8a-4e90bab80786 | 123           | approved | test        |

| test_section            | reviews_today | first_review_today | last_review_today | today_in_timezone   |
| ----------------------- | ------------- | ------------------ | ----------------- | ------------------- |
| Reviews Completed Today | 0             | null               | null              | 2025-06-07 02:00:00 |