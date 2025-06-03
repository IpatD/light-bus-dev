-- Debug query to check what's failing in record_sr_review
-- Run this to see the recent logs for the failing reviews

SELECT 
    attempted_at,
    card_id,
    quality_rating,
    success,
    error_message
FROM sr_review_logs
WHERE student_id = '46246124-a43f-4980-b05e-97670eed3f32'
  AND attempted_at >= NOW() - INTERVAL '1 hour'
ORDER BY attempted_at DESC;

-- Also check if the cards exist and are accessible
SELECT 
    c.id,
    c.lesson_id,
    c.status,
    l.name as lesson_name,
    lp.student_id as is_participant
FROM sr_cards c
INNER JOIN lessons l ON c.lesson_id = l.id
LEFT JOIN lesson_participants lp ON l.id = lp.lesson_id AND lp.student_id = '46246124-a43f-4980-b05e-97670eed3f32'
WHERE c.id IN (
    '46b417ed-d44e-4e77-b236-4f26dc5f8636',
    '68dfdadb-424e-4ea0-9456-637526cd0d22'
);

-- Check if there are any pending reviews for these cards
SELECT 
    r.id,
    r.card_id,
    r.student_id,
    r.scheduled_for,
    r.completed_at,
    r.card_status
FROM sr_reviews r
WHERE r.card_id IN (
    '46b417ed-d44e-4e77-b236-4f26dc5f8636',
    '68dfdadb-424e-4ea0-9456-637526cd0d22'
)
  AND r.student_id = '46246124-a43f-4980-b05e-97670eed3f32'
ORDER BY r.created_at DESC;