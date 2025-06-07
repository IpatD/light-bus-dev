# Streak Calculation Tests - Folder 024

## Overview
This folder contains individual SQL test files to debug and test the streak calculation functionality for student ID: `46246124-a43f-4980-b05e-97670eed3f32`

Each file is designed to be run independently in the Supabase SQL editor.

## Test Files (Run in Order)

### 001_current_streak_status.sql
**Purpose**: Check the current streak status in the `sr_progress` table
**What it shows**: Current streak value, last review date, cards reviewed, etc.

### 002_student_profile_check.sql
**Purpose**: Verify the student exists and basic profile info
**What it shows**: Student name, email, role, creation date

### 003_lesson_participation.sql
**Purpose**: Check which lessons the student is enrolled in
**What it shows**: Lesson IDs, names, enrollment dates

### 004_review_history.sql
**Purpose**: Check total review history
**What it shows**: Total reviews, completed reviews, first/last review dates

### 005_reviews_by_date.sql
**Purpose**: Break down reviews by date (last 7 days)
**What it shows**: Daily review counts, quality ratings

### 006_test_user_stats_function.sql
**Purpose**: Test the `get_user_stats_with_timezone` function
**What it shows**: Function output including streak value

### 007_test_direct_user_stats.sql
**Purpose**: Test the direct `get_user_stats` function
**What it shows**: Direct function output for comparison

### 008_test_recalculate_streaks.sql
**Purpose**: Run the streak recalculation function
**What it shows**: Before/after streak values if any changes were made

### 009_test_manual_review_recording.sql
**Purpose**: Find available cards for manual testing
**What it shows**: Cards that can be used for test review recording

### 010_check_today_status.sql
**Purpose**: Check if student has completed any reviews today
**What it shows**: Today's activity status

## How to Use

1. **Run tests in order** (001 through 010)
2. **Copy/paste each file** into the Supabase SQL editor
3. **Execute each query individually**
4. **Document results** for analysis

## Expected Results

After running migration 036 (streak calculation fix):
- **001**: Should show current streak status
- **006/007**: Should show consistent streak values
- **008**: Should fix any incorrect streaks
- **010**: Should show if user studied today

## Troubleshooting

If streak is still 0 after testing:
1. Check if user has any completed reviews (004, 005)
2. Run the recalculation function (008)
3. Check if reviews are from today (010)
4. Manually trigger a review using available cards (009)

## Next Steps

After running all tests:
1. **Identify the issue** based on test results
2. **Run recalculation** if needed (008)
3. **Test manual review** if streak logic needs verification
4. **Report findings** for further debugging