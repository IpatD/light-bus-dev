# Database Schema Relationships Analysis

## Overview
This document provides a comprehensive analysis of the relationships between tables in the Spaced Repetition Learning System database schema.

## Entity Relationship Diagram (Textual)

```
profiles (Users: teachers, students, admins)
├── lessons (teacher_id) [1:M] - Teachers create lessons
├── lesson_participants (student_id) [1:M] - Students participate in lessons
├── sr_card_flags (student_id, resolved_by) [1:M] - Students flag cards, users resolve them
├── sr_reviews (student_id) [1:M] - Students review flashcards
├── sr_progress (student_id) [1:M] - Student progress tracking
├── student_lesson_interactions (student_id) [1:M] - Student engagement tracking
└── sr_cards (created_by, approved_by) [1:M] - Users create and approve flashcards

lessons (Core lesson content)
├── lesson_participants (lesson_id) [1:M] - Students assigned to lessons
├── transcripts (lesson_id) [1:1] - Lesson transcription
├── summaries (lesson_id) [1:1] - Lesson summary
├── sr_cards (lesson_id) [1:M] - Flashcards generated from lesson
├── sr_progress (lesson_id) [1:M] - Progress tracking per lesson
└── student_lesson_interactions (lesson_id) [1:M] - Interaction tracking

sr_cards (Flashcards)
├── sr_card_flags (card_id) [1:M] - Quality control flags
└── sr_reviews (card_id) [1:M] - Review sessions
```

## Core Relationships

### 1. User Management
- **profiles**: Central user table for teachers, students, and admins
- **Role-based relationships**: Different user roles have different relationship patterns

### 2. Lesson Ecosystem
- **lessons**: Core content created by teachers
- **lesson_participants**: Many-to-many relationship between lessons and students
- **transcripts**: One-to-one relationship with lessons (auto-generated content)
- **summaries**: One-to-one relationship with lessons (AI-generated summaries)

### 3. Spaced Repetition System
- **sr_cards**: Flashcards generated from lesson content
- **sr_reviews**: Individual review sessions tracking student progress
- **sr_progress**: Aggregated progress metrics per student-lesson pair
- **sr_card_flags**: Quality control system for flagging problematic cards

### 4. Analytics & Tracking
- **student_lesson_interactions**: Detailed engagement tracking
- **sr_progress**: Aggregated learning metrics

## Constraint Analysis

### Primary Keys
- **Standard UUID Primary Keys**: All tables use UUID primary keys for global uniqueness
- **Composite Primary Key**: `lesson_participants(lesson_id, student_id)` ensures unique participation records

### Foreign Key Relationships

#### Core Entity References
1. **lessons.teacher_id → profiles.id**: Links lessons to their creating teacher
2. **lesson_participants.lesson_id → lessons.id**: Links participation to specific lesson
3. **lesson_participants.student_id → profiles.id**: Links participation to specific student

#### Content References
4. **transcripts.lesson_id → lessons.id**: Links transcripts to source lesson
5. **summaries.lesson_id → lessons.id**: Links summaries to source lesson
6. **sr_cards.lesson_id → lessons.id**: Links flashcards to source lesson

#### Spaced Repetition References
7. **sr_cards.created_by → profiles.id**: Links cards to their creator
8. **sr_cards.approved_by → profiles.id**: Links cards to their approver
9. **sr_reviews.card_id → sr_cards.id**: Links reviews to specific flashcard
10. **sr_reviews.student_id → profiles.id**: Links reviews to reviewing student

#### Quality Control References
11. **sr_card_flags.card_id → sr_cards.id**: Links flags to flagged card
12. **sr_card_flags.student_id → profiles.id**: Links flags to reporting student
13. **sr_card_flags.resolved_by → profiles.id**: Links flags to resolver

#### Progress Tracking References
14. **sr_progress.student_id → profiles.id**: Links progress to student
15. **sr_progress.lesson_id → lessons.id**: Links progress to lesson
16. **student_lesson_interactions.student_id → profiles.id**: Links interactions to student
17. **student_lesson_interactions.lesson_id → lessons.id**: Links interactions to lesson

### Unique Constraints

#### Business Logic Constraints
1. **sr_card_flags(card_id, student_id, flag_type)**: Prevents duplicate flags of same type by same student
2. **sr_progress(student_id, lesson_id)**: One progress record per student-lesson pair
3. **student_lesson_interactions(student_id, lesson_id)**: One interaction record per student-lesson pair
4. **profiles(email)**: Unique email addresses for user identification

#### Natural Unique Constraints
5. **lesson_participants(lesson_id, student_id)**: Composite primary key prevents duplicate participation

### Check Constraints

#### Enumeration Constraints
- **profiles.role**: Must be 'teacher', 'student', or 'admin'
- **transcripts.transcript_type**: Must be 'auto', 'manual', or 'corrected'
- **sr_cards.card_type**: Must be 'basic', 'cloze', 'multiple_choice', or 'true_false'
- **sr_cards.status**: Must be 'pending', 'approved', 'rejected', or 'archived'
- **sr_card_flags.flag_type**: Must be 'incorrect', 'unclear', 'duplicate', 'inappropriate', or 'outdated'
- **sr_card_flags.status**: Must be 'open', 'resolved', or 'dismissed'
- **student_lesson_interactions.interaction_type**: Must be 'view', 'study', 'review', or 'complete'

#### Range Constraints
- **lessons.transcription_progress**: Must be between 0 and 100 (percentage)
- **sr_cards.difficulty_level**: Must be between 1 and 5
- **sr_reviews.quality_rating**: Must be between 0 and 5 (SM-2 algorithm rating)

## Data Flow Patterns

### 1. Lesson Creation Flow
```
Teacher (profiles) → creates → lessons
                 → generates → transcripts
                 → generates → summaries  
                 → creates → sr_cards
```

### 2. Student Assignment Flow
```
Teacher assigns → lesson_participants → links students to lessons
Student accesses → student_lesson_interactions → tracks engagement
```

### 3. Spaced Repetition Flow
```
sr_cards → scheduled for → sr_reviews
sr_reviews → aggregated into → sr_progress
Students can → sr_card_flags → for quality control
```

### 4. Quality Control Flow
```
Students → sr_card_flags → flagged cards
Teachers/Admins → resolve → sr_card_flags
Resolved flags → improve → sr_cards quality
```

## Business Rules Enforced by Schema

1. **Role Separation**: Teachers create lessons, students participate
2. **Content Integrity**: All content linked to source lessons
3. **Progress Tracking**: Unique progress records prevent data duplication
4. **Quality Assurance**: Flag system allows collaborative improvement
5. **Audit Trail**: Timestamps and user references provide full audit capability
6. **Data Consistency**: Foreign key constraints ensure referential integrity

## Optimization Notes

1. **Indexes**: Strategic indexes on foreign keys and frequently queried columns
2. **Composite Indexes**: Multi-column indexes for common query patterns
3. **Cascade Deletes**: Automatic cleanup when parent records are deleted
4. **Unique Constraints**: Prevent duplicate data at database level
5. **Check Constraints**: Data validation at database level

## Future Considerations

1. **Soft Deletes**: Consider adding deleted_at columns for audit requirements
2. **Partitioning**: Large tables like sr_reviews might benefit from partitioning
3. **Archiving**: Historical data archiving strategy for old lessons/reviews
4. **Performance**: Monitor query patterns and add indexes as needed