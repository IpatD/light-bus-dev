# Date Discrepancies Investigation - Student Dashboard Learning Analytics

## Investigation Summary
**Issue**: Date discrepancies in student dashboard's learning analytics panel where study dates displayed on cards don't match when students actually studied them, or cards show correct dates in UI but register different dates in database.

**Priority**: HIGH - Date accuracy is critical for learning analytics and spaced repetition effectiveness.

## Key Findings from Code Analysis

### 1. Database Schema Analysis
**Date/Timestamp Fields Identified:**

#### sr_reviews table:
- `scheduled_for TIMESTAMPTZ NOT NULL` - When review is scheduled
- `completed_at TIMESTAMPTZ` - When review was completed
- `created_at TIMESTAMPTZ DEFAULT NOW()` - When review record was created

#### sr_progress table:
- `last_review_date DATE` - Last date student reviewed (DATE only, no time)
- `next_review_date DATE` - Next scheduled review date (DATE only, no time)
- `created_at TIMESTAMPTZ DEFAULT NOW()`
- `updated_at TIMESTAMPTZ DEFAULT NOW()`

#### profiles table:
- `updated_at TIMESTAMPTZ DEFAULT NOW()`
- `created_at TIMESTAMPTZ DEFAULT NOW()`

### 2. Critical Date Conversion Issues Found

#### Issue 1: TIMESTAMPTZ vs DATE Conversion
**Location**: [`record_sr_review()`](lightbus-elearning/supabase/migrations/027_comprehensive_spaced_repetition_fixes.sql:355)
```sql
last_review_date = CURRENT_DATE,
next_review_date = LEAST(next_review_date, v_next_date::DATE),
```
**Problem**: Converting TIMESTAMPTZ to DATE can cause timezone-dependent date shifts.

#### Issue 2: Frontend Date Processing
**Location**: [`ProgressChart.tsx`](lightbus-elearning/src/components/dashboard/student/ProgressChart.tsx:28-38)
```typescript
const date = new Date()
date.setDate(date.getDate() - (6 - index))
const isToday = date.toDateString() === new Date().toDateString()
```
**Problem**: Client-side date manipulation without timezone consideration.

#### Issue 3: Date Comparison Logic
**Location**: [`get_today_study_stats()`](lightbus-elearning/supabase/migrations/030_fix_daily_study_stats_calculation.sql:39)
```sql
AND r.completed_at::DATE = v_today
```
**Problem**: Server timezone casting vs client timezone expectations.

#### Issue 4: StudyStreakCard Date Formatting
**Location**: [`StudyStreakCard.tsx`](lightbus-elearning/src/components/dashboard/student/StudyStreakCard.tsx:243-260)
```typescript
function formatNextReviewDate(dateString: string): string {
  const date = new Date(dateString)
  const today = new Date()
  // ... comparison logic
}
```
**Problem**: No timezone handling for date comparisons.

### 3. Data Flow Analysis

#### Backend → Frontend Data Flow:
1. **Database** (UTC timestamps) 
2. **SQL Functions** (`get_user_stats`, `get_today_study_stats`)
3. **Supabase RPC** (JSON serialization)
4. **Frontend** (Client timezone interpretation)
5. **Components** (Display formatting)

#### Potential Timezone Issues:
- Database stores in UTC
- Client interprets in local timezone (currently Europe/Warsaw, UTC+2)
- No explicit timezone handling in frontend components
- Date casting in SQL functions may not account for client timezone

### 4. Specific Problem Areas

#### A. Study Streak Calculation
**Function**: [`record_sr_review()`](lightbus-elearning/supabase/migrations/027_comprehensive_spaced_repetition_fixes.sql:354-358)
```sql
study_streak = CASE
    WHEN last_review_date = CURRENT_DATE THEN study_streak
    WHEN last_review_date = CURRENT_DATE - 1 THEN study_streak + 1
    ELSE 1
END,
last_review_date = CURRENT_DATE,
```
**Issue**: `CURRENT_DATE` is server timezone, but client may be in different timezone.

#### B. Progress Chart Date Mapping
**Component**: [`ProgressChart.tsx`](lightbus-elearning/src/components/dashboard/student/ProgressChart.tsx:41-55)
```typescript
const monthlyChartData = monthlyData.map((value, index) => {
  const startOfMonth = new Date()
  startOfMonth.setDate(1)
  const date = new Date(startOfMonth)
  date.setDate(index + 1)
  // ... date processing
})
```
**Issue**: Client-side date construction may not align with server-side date boundaries.

#### C. Today's Statistics
**Function**: [`get_today_study_stats()`](lightbus-elearning/supabase/migrations/030_fix_daily_study_stats_calculation.sql:18-40)
```sql
DECLARE
    v_today DATE := CURRENT_DATE;
BEGIN
    -- ... query logic using v_today
```
**Issue**: Server's "today" vs client's "today" timezone mismatch.

## Root Cause Analysis

### Primary Causes:
1. **Timezone Inconsistency**: Database uses UTC, frontend assumes local timezone
2. **Date Boundary Misalignment**: Midnight in server timezone ≠ midnight in client timezone  
3. **Mixed Date Types**: TIMESTAMPTZ vs DATE conversions lose timezone context
4. **Client-Side Date Manipulation**: No timezone-aware date processing

### Secondary Causes:
1. **No Timezone Validation**: Functions don't validate timezone context
2. **Inconsistent Date Formatting**: Different components handle dates differently
3. **Cache Issues**: Potential stale data showing wrong dates
4. **Review Recording Race Conditions**: Fixed in migration 027, but may have created date inconsistencies

## Investigation Plan

### Phase 1: Database Analysis ✅ COMPLETED
- [x] Examine database schema for date fields
- [x] Analyze recent migrations for date-related changes
- [x] Identify timezone handling in SQL functions

### Phase 2: Frontend Analysis ✅ COMPLETED  
- [x] Analyze dashboard components date handling
- [x] Check date formatting and display logic
- [x] Map data flow from API to UI

### Phase 3: Debugging Tools Creation 🔄 IN PROGRESS
- [ ] Create date validation diagnostic queries
- [ ] Build timezone comparison tools
- [ ] Implement comprehensive date logging

### Phase 4: Testing & Verification
- [ ] Create test cases for timezone scenarios
- [ ] Implement date integrity verification
- [ ] Test with different client timezones

### Phase 5: Fix Implementation
- [ ] Database timezone standardization
- [ ] Frontend timezone-aware date handling
- [ ] Consistent date formatting across components
- [ ] Cache invalidation for date-sensitive data

## Next Steps

### Immediate Actions:
1. **Create Diagnostic Tools**: Build queries to compare displayed vs stored dates
2. **Timezone Analysis**: Test current system with different client timezones
3. **Data Validation**: Check for existing date inconsistencies in database

### Implementation Priority:
1. **High**: Fix timezone handling in core functions
2. **Medium**: Update frontend components for timezone awareness  
3. **Low**: Add comprehensive date validation and logging

## Files Modified/Created:
- This investigation document: `docs/43-investigation-date-discrepancies-analysis.md`
- Next: Date diagnostic tools and queries

## Expected Timeline:
- **Investigation**: 1 day ✅ COMPLETED
- **Diagnostic Tools**: 0.5 days 🔄 IN PROGRESS
- **Fix Implementation**: 1-2 days
- **Testing & Validation**: 1 day
- **Total**: 3-4 days