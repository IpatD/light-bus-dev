# Debugging Session: Student Data Investigation

## Student ID: 46246124-a43f-4980-b05e-97670eed3f32
## Date: 2025-06-07
## Purpose: Post-migration investigation of date discrepancies

This folder contains individual SQL queries to investigate specific aspects of the student's data. Run these queries one by one in the Supabase SQL editor to get detailed insights.

## ⚠️ IMPORTANT: Run Hotfix First!

**BEFORE running any other queries, execute the hotfix:**
- **012_hotfix_ambiguous_column_reference.sql** - Fixes critical bug in get_user_stats function

## Execution Order:

### Phase 1: Fix Critical Bug
1. **012_hotfix_ambiguous_column_reference.sql** - ⚠️ **RUN THIS FIRST** - Fixes ambiguous column reference

### Phase 2: Investigation Queries
2. **001_student_profile_investigation.sql** - Basic student profile information
3. **002_lesson_participation_investigation.sql** - Lessons the student is enrolled in
4. **003_accepted_cards_investigation.sql** - Cards the student has accepted and their status
5. **004_completed_reviews_timezone_analysis.sql** - Completed reviews with timezone comparisons
6. **005_due_reviews_session_analysis.sql** - Due cards analysis with timezone considerations
7. **006_user_stats_function_comparison.sql** - Compare original vs timezone-aware user stats
8. **007_today_stats_function_comparison.sql** - Compare today's statistics functions
9. **008_progress_tracking_consistency.sql** - Progress table vs actual review data consistency
10. **009_cards_for_study_analysis.sql** - What cards are available for study
11. **010_timezone_boundary_analysis.sql** - Current timezone alignment status
12. **011_investigation_summary.sql** - Summary of all key metrics

## What to Look For:

### 🔍 Critical Issues:
- **Date Mismatches**: `timezone_date_status = 'DATE_MISMATCH'` in query 004
- **Due Status Discrepancies**: Different results between UTC and Warsaw in query 005
- **Function Differences**: Different results between original and timezone-aware functions (queries 006-007)
- **Progress Inconsistencies**: `consistency_status != 'CONSISTENT'` in query 008

### 📊 Key Metrics to Compare:
- Study streak values between original and timezone-aware functions
- Cards due today count differences
- Today's study statistics variations
- Progress table vs actual review date alignment

### 🕐 Timezone Boundaries:
- Check if `date_alignment_status = 'DATES_MISALIGNED'` in query 010
- Look for reviews near midnight hours (22-23 UTC or 0-2 UTC)

## Bug Fixes Applied:

### 012_hotfix_ambiguous_column_reference.sql
**Issue**: PostgreSQL error "column reference 'i' is ambiguous"
**Cause**: Variable naming conflict in generate_series loops
**Fix**: Used explicit aliases (series_day) instead of ambiguous loop variables
**Impact**: Fixes get_user_stats and get_user_stats_with_timezone functions

## Expected Results:
After running all queries, you should have:
1. Complete picture of the student's learning data
2. Identification of any remaining timezone issues
3. Comparison data to match against frontend debug panels
4. Specific inconsistencies that need fixing

## Next Steps:
1. **RUN HOTFIX FIRST** (012_hotfix_ambiguous_column_reference.sql)
2. Run each investigation query in sequence (001-011)
3. Note any errors or unexpected results
4. Compare backend results with frontend debug panels
5. Document any remaining discrepancies for further investigation