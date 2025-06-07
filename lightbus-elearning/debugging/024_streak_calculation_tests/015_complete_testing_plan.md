# Complete Testing Plan for Streak Calculation Fix

## Current Situation
- Student has completed reviews today (2 reviews on 2025-06-07)
- Streak is still showing 0 despite activity
- Multiple migrations have been applied to fix the issue

## Testing Sequence (Run in Supabase SQL Editor)

### Phase 1: Current Status Check
Run these files in order:
1. `001_current_streak_status.sql` - Check current streak in sr_progress
2. `010_check_today_status.sql` - Verify today's activity

### Phase 2: Manual Fix Application
3. `012_manual_streak_fix.sql` - Apply manual streak fix
4. `013_verify_after_fix.sql` - Check if sr_progress was updated

### Phase 3: Function Testing
5. `014_test_user_stats_after_fix.sql` - Test if get_user_stats shows updated streak

## Expected Results After Migration 038

### Before Manual Fix
- `sr_progress.study_streak` = 0
- `get_user_stats().study_streak` = 0

### After Manual Fix (Expected)
- `sr_progress.study_streak` = 1 (since user studied today)
- `get_user_stats().study_streak` = 1

## Key Issues Identified & Resolved

### ✅ Issue 1: Function Name Mismatch
- **Problem**: Frontend calls `record_sr_review_fixed` but fix was in `record_sr_review`
- **Solution**: Migration 037 creates alias `record_sr_review_fixed`

### ✅ Issue 2: Ambiguous Column Reference  
- **Problem**: Variable `last_review_date` conflicts with table column
- **Solution**: Migration 038 renames variable to `v_new_last_review_date`

### 🔄 Issue 3: Streak Not Updating (Testing Needed)
- **Problem**: Despite reviews today, streak remains 0
- **Solution**: Manual fix function + proper streak calculation logic

## Root Cause Analysis

The streak calculation appears to have multiple issues:

1. **Function Call Mismatch**: Reviews were recorded but using wrong function name
2. **Progress Table Not Updated**: streak value in sr_progress table not updating
3. **Backend/Frontend Sync**: get_user_stats function may not reflect actual progress

## Next Steps After Migration 038 Completes

1. **Run Manual Fix**: Execute `012_manual_streak_fix.sql`
2. **Verify Database**: Check `sr_progress` table directly
3. **Test Frontend**: Check if StudyStreakCard shows updated value
4. **Study a New Card**: Test if future reviews properly increment streak

## If Streak Still Shows 0

The issue might be:
- **Cache/State Management**: Frontend not refreshing data
- **Different Data Source**: StudyStreakCard might use different query
- **Date/Timezone Issues**: Still using UTC instead of client timezone

## Emergency Manual Database Fix

If automated fix doesn't work, run this SQL directly:

```sql
-- Direct manual update (use with caution)
UPDATE public.sr_progress 
SET 
    study_streak = 1,
    last_review_date = CURRENT_DATE AT TIME ZONE 'Europe/Warsaw',
    updated_at = NOW()
WHERE student_id = '46246124-a43f-4980-b05e-97670eed3f32'::UUID
  AND EXISTS (
    SELECT 1 FROM public.sr_reviews r
    INNER JOIN public.sr_cards c ON r.card_id = c.id
    WHERE r.student_id = '46246124-a43f-4980-b05e-97670eed3f32'::UUID
      AND c.lesson_id = sr_progress.lesson_id
      AND r.completed_at IS NOT NULL
      AND DATE(r.completed_at AT TIME ZONE 'Europe/Warsaw') = CURRENT_DATE AT TIME ZONE 'Europe/Warsaw'
  );
```

This should immediately fix the streak to show 1 for any lesson where the student completed reviews today.