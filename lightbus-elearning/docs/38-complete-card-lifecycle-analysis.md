# Complete Card Lifecycle Analysis: Frontend to Backend Flow

**Date**: 2025-01-06  
**Status**: COMPREHENSIVE ANALYSIS  

## Overview

This document traces the complete flow of a flashcard from creation by a teacher to study completion by a student, including all frontend interactions, backend function calls, database mutations, and table transformations.

---

## **PHASE 1: CARD CREATION BY TEACHER**

### 1.1 Frontend: Card Creation Interface

**Entry Point**: [`/cards/create`](../src/app/cards/create/page.tsx:41)

**Components Chain**:
- [`CreateCardPage`](../src/app/cards/create/page.tsx:41) → [`CardCreationForm`](../src/components/sr_cards/CardCreationForm.tsx:51)

**User Interaction Flow**:
1. Teacher navigates to card creation page
2. Form loads with lesson selection via [`get_teacher_lessons`](../src/components/sr_cards/CardCreationForm.tsx:77) RPC call
3. Teacher fills form fields:
   - `lesson_id` (from dropdown or URL param)
   - `front_content` (question)
   - `back_content` (answer)
   - `card_type` ('basic', 'cloze', 'multiple_choice', 'audio')
   - `difficulty_level` (1-5)
   - `tags` (optional, comma-separated)

**Frontend Validation**:
- Front content: min 3 characters
- Back content: min 3 characters  
- Each tag: min 2 characters
- Lesson selection required

### 1.2 Backend: Card Creation Function Call

**Function Called**: [`create_sr_card`](../supabase/migrations/021_comprehensive_duplicate_fix.sql:160)

**Request**:
```javascript
await supabase.rpc('create_sr_card', {
  p_lesson_id: formData.lesson_id,
  p_front_content: formData.front_content.trim(),
  p_back_content: formData.back_content.trim(),
  p_card_type: formData.card_type,
  p_difficulty_level: formData.difficulty_level,
  p_tags: tags
})
```

**Backend Processing**:
1. **Authentication Check**: Verify user is logged in
2. **Authorization Check**: Verify user is teacher of the lesson
3. **Input Validation**: 
   - Front/back content ≥ 3 characters
   - Difficulty level 1-5
4. **Database Insert**: Insert into `sr_cards` table

### 1.3 Database Mutation: sr_cards Table

**Table**: `public.sr_cards`

**INSERT Operation**:
```sql
INSERT INTO public.sr_cards (
    lesson_id,
    front_content,
    back_content,
    card_type,
    difficulty_level,
    tags,
    status,        -- 'approved' (auto-approved for teachers)
    created_by
) VALUES (...)
```

**Key Fields Set**:
- `id`: Generated UUID
- `status`: `'approved'` (teachers' cards auto-approved)
- `created_by`: Teacher's user ID
- `created_at`: NOW()
- `updated_at`: NOW()

### 1.4 Trigger Activation: Card Initialization

**Trigger**: [`trigger_initialize_card_for_students`](../supabase/migrations/023_positive_card_system_with_acceptance.sql:191)

**Trigger Condition**: 
- AFTER INSERT OR UPDATE OF status ON `sr_cards`
- When `NEW.status = 'approved'`

**Function Called**: [`initialize_card_for_students()`](../supabase/migrations/023_positive_card_system_with_acceptance.sql:191)

---

## **PHASE 2: AUTOMATIC CARD INITIALIZATION FOR STUDENTS**

### 2.1 Student Identification

**Process**: Find all students enrolled in the lesson
```sql
SELECT DISTINCT student_id 
FROM public.lesson_participants 
WHERE lesson_id = NEW.lesson_id
```

### 2.2 Review Record Creation

**For Each Student**:

**Table**: `public.sr_reviews`

**INSERT Operation**:
```sql
INSERT INTO public.sr_reviews (
    card_id,
    student_id,
    scheduled_for,     -- NOW() (immediately available)
    interval_days,     -- 1
    ease_factor,       -- 2.5 (SM-2 default)
    repetition_count,  -- 0
    card_status,       -- 'new'
    accepted_at        -- NULL (not yet accepted)
) VALUES (...)
```

**Key State**: 
- Card is in "new" pool for all enrolled students
- Available for study immediately
- Not yet "accepted" by any student

### 2.3 Progress Tracking Update

**Table**: `public.sr_progress`

**UPDATE Operation**:
```sql
UPDATE public.sr_progress 
SET 
    cards_total = (COUNT of approved cards in lesson),
    updated_at = NOW()
WHERE lesson_id = NEW.lesson_id
```

---

## **PHASE 3: STUDENT DISCOVERS CARD**

### 3.1 Frontend: Study Session Initialization

**Entry Points**:
- [`/study/[lesson_id]`](../src/app/study/[lesson_id]/page.tsx:44) (specific lesson)
- [`/study/all`](../src/app/study/all/page.tsx:38) (all lessons)

**Function Called**: [`get_cards_for_study`](../supabase/migrations/026_fix_spaced_repetition_card_filtering.sql:12)

**Request**:
```javascript
await supabase.rpc('get_cards_for_study', {
  p_user_id: user.id,
  p_pool_type: 'both',     // 'new', 'due', or 'both'
  p_limit_new: 10,         // max new cards
  p_limit_due: 15,         // max due cards  
  p_lesson_id: lesson_id   // null for all lessons
})
```

### 3.2 Backend: Card Filtering Logic

**NEW CARDS POOL** (Available to all students):
```sql
WITH latest_reviews AS (
    SELECT DISTINCT ON (r.card_id) ...
    ORDER BY r.card_id, r.created_at DESC  -- Latest review per card
)
SELECT ... FROM sr_cards c
JOIN latest_reviews lr ON c.id = lr.card_id
WHERE lr.card_status = 'new'           -- New cards
  AND lr.completed_at IS NULL          -- Not yet studied
```

**DUE CARDS POOL** (Only for active students):
```sql
WHERE lr.card_status = 'accepted'      -- Previously accepted cards
  AND lr.completed_at IS NULL          -- Not yet completed
  AND lr.scheduled_for <= CURRENT_DATE -- Due for review
```

### 3.3 Frontend: Card Display

**Component**: [`EnhancedFlashcard`](../src/components/study/EnhancedFlashcard.tsx:17)

**Data Transformation**:
```javascript
// Backend data → Frontend interface
const cards: SRCard[] = cardsData.map((item: any) => ({
  id: item.card_id,
  lesson_id: item.lesson_id,
  front_content: item.front_content,
  back_content: item.back_content,
  card_type: 'basic',
  difficulty_level: item.difficulty_level,
  tags: item.tags || [],
  status: 'approved' as const
}))
```

---

## **PHASE 4: STUDENT STUDIES CARD**

### 4.1 Frontend: Card Interaction

**User Actions**:
1. **View Question**: Card shows `front_content`
2. **Flip Card**: Click reveals `back_content` 
3. **Rate Performance**: Select quality rating (0-5)

**Quality Options**:
- 0: "Again" - Complete blackout
- 1: "Hard" - Incorrect, but remembered  
- 2: "Hard" - Incorrect, easy to remember
- 3: "Good" - Correct with hesitation
- 4: "Good" - Correct after some thought
- 5: "Easy" - Perfect response

### 4.2 Frontend: Review Submission

**Function Call**: [`handleCardReview`](../src/app/study/[lesson_id]/page.tsx:117)

**Process**:
1. Calculate `response_time_ms` = current_time - start_time
2. Call backend function

**Request**:
```javascript
await supabase.rpc('record_sr_review', {
  p_user_id: user.id,
  p_card_id: currentCard.id,
  p_quality: quality,           // 0-5 rating
  p_response_time_ms: responseTime
})
```

---

## **PHASE 5: BACKEND REVIEW PROCESSING**

### 5.1 Backend: Review Recording Function

**Function**: [`record_sr_review`](../supabase/migrations/023_positive_card_system_with_acceptance.sql:248)

**Process Flow**:

#### Step 1: Find Current Review
```sql
SELECT * FROM public.sr_reviews
WHERE card_id = p_card_id 
  AND student_id = p_user_id 
  AND completed_at IS NULL
  AND card_status IN ('new', 'accepted')
ORDER BY scheduled_for ASC
LIMIT 1
```

#### Step 2: SM-2 Algorithm Calculation
**Function**: [`calculate_sr_interval`](../supabase/migrations/002_sr_functions.sql:13)

**SM-2 Logic**:
- **Quality < 3**: Reset interval to 1 day (restart learning)
- **Quality ≥ 3**: 
  - Update ease factor: `EF = EF + (0.1 - (5-q)*(0.08+(5-q)*0.02))`
  - Calculate new interval:
    - First success: 6 days
    - Subsequent: `previous_interval * ease_factor`

#### Step 3: Update Current Review (Mark Complete)
```sql
UPDATE public.sr_reviews
SET 
    completed_at = NOW(),
    quality_rating = p_quality,
    response_time_ms = p_response_time_ms
WHERE id = current_review.id
```

#### Step 4: Create Next Review Record

**For Quality ≥ 3** (Successful):
```sql
INSERT INTO public.sr_reviews (
    card_id,
    student_id,
    scheduled_for,        -- NOW() + calculated_interval
    interval_days,        -- calculated_interval  
    ease_factor,          -- updated_ease_factor
    repetition_count,     -- incremented
    card_status,          -- 'new' → 'accepted' OR keep 'accepted'
    accepted_at           -- NOW() if first success, else keep existing
)
```

**For Quality < 3** (Failed):
```sql
INSERT INTO public.sr_reviews (
    card_id,
    student_id,  
    scheduled_for,        -- NOW() + 10 minutes (retry soon)
    interval_days,        -- 1 (reset)
    ease_factor,          -- unchanged
    repetition_count,     -- 0 (reset)
    card_status,          -- keep same status
    accepted_at           -- keep same acceptance time
)
```

#### Step 5: Update Progress Tracking
```sql
UPDATE public.sr_progress
SET
    cards_reviewed = cards_reviewed + 1,
    cards_learned = CASE WHEN p_quality >= 4 THEN cards_learned + 1 ELSE cards_learned END,
    average_quality = (average_quality * (cards_reviewed - 1) + p_quality) / cards_reviewed,
    study_streak = (calculated_streak),
    last_review_date = CURRENT_DATE,
    last_activity_date = CURRENT_DATE,
    is_active = TRUE,
    next_review_date = LEAST(next_review_date, new_scheduled_date::DATE)
WHERE student_id = p_user_id AND lesson_id = lesson_id
```

---

## **PHASE 6: CARD STATE TRANSITIONS**

### 6.1 Card Status Lifecycle

**NEW CARD** (`card_status = 'new'`):
- Initial state for all students when card created
- Available in "new cards" pool
- Student has never successfully reviewed

**ACCEPTED CARD** (`card_status = 'accepted'`):
- Student successfully reviewed (quality ≥ 3) at least once
- Card accepted into student's spaced repetition schedule
- Available in "due cards" pool when `scheduled_for <= CURRENT_DATE`

### 6.2 Review Record Lifecycle

**ACTIVE REVIEW** (`completed_at = NULL`):
- Current scheduled review for a card
- Used by `get_cards_for_study` to determine availability

**COMPLETED REVIEW** (`completed_at = NOT NULL`):
- Historical record of past study session
- Contains quality rating and response time
- Used for analytics and progress tracking

---

## **PHASE 7: SUBSEQUENT STUDY SESSIONS**

### 7.1 Card Reappearance Logic

**Fixed Logic** (Post-Migration 026):

1. **Find Latest Review**: Use CTE with `DISTINCT ON (card_id) ORDER BY created_at DESC`
2. **Check Completion**: Only show cards where latest review has `completed_at IS NULL`
3. **Check Schedule**: For accepted cards, only show when `scheduled_for <= CURRENT_DATE`

### 7.2 Spaced Repetition Schedule

**Example Timeline**:
- **Day 0**: New card studied, quality = 4
- **Day 6**: Card reappears (first interval)
- **Day 15**: Card reappears (6 * 1.5 ease factor = ~9 days later)
- **Day 37**: Card reappears (15 * 1.5 = ~22 days later)
- **Etc.**: Progressively longer intervals

---

## **DATABASE TABLES SUMMARY**

### Core Tables and Their Roles

1. **`sr_cards`**: Master card definitions
   - Content, metadata, approval status
   - Created by teachers, auto-approved

2. **`sr_reviews`**: Individual study instances  
   - One record per student per scheduled review
   - Tracks completion, quality, timing
   - Drives spaced repetition scheduling

3. **`sr_progress`**: Aggregated student progress
   - Summary statistics per student per lesson
   - Study streaks, averages, totals

4. **`lesson_participants`**: Enrollment tracking
   - Determines which students get initialized for cards
   - Drives access control

---

## **KEY FIXES IMPLEMENTED**

### Previous Bug: Cards Still Showing After Study

**Problem**: [`get_cards_for_study`](../supabase/migrations/023_positive_card_system_with_acceptance.sql:149) filtered `r.completed_at IS NULL` across ALL reviews

**Fix**: [`get_cards_for_study`](../supabase/migrations/026_fix_spaced_repetition_card_filtering.sql:12) now finds LATEST review per card using CTE with `DISTINCT ON`

**Result**: Cards properly disappear after study and reappear only when due

---

## **TESTING VERIFICATION POINTS**

### End-to-End Flow Testing

1. **Card Creation**: Teacher creates card → appears in students' new pool
2. **First Study**: Student studies new card → disappears from study session
3. **Spaced Repetition**: Card reappears on scheduled date
4. **Quality Impact**: Different quality ratings affect intervals correctly
5. **Progress Tracking**: Analytics reflect actual study behavior

This completes the comprehensive analysis of the card lifecycle from creation to spaced repetition.