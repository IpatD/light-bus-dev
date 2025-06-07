# Study Streak Weekly Display Fix
## Date: 2025-06-07
## Issue: Weekly progress showing wrong days + zero streak despite study session

## 🐛 **Problem Identified**

### **Symptoms:**
- ✅ Backend correctly records study session for Saturday
- ❌ Frontend shows session on Monday in weekly display
- ❌ Study streak shows 0 despite session completion
- ❌ Weekly progress day mapping is incorrect

### **Root Cause:**
StudyStreakCard uses **direct array mapping** while ProgressChart uses **timezone-aware date mapping**

## 🔍 **Backend Calls Analysis**

### **Data Flow:**
```
Dashboard → fetchUserStats() → get_user_stats_with_timezone() → StudyStreakCard
```

### **Backend RPC Call:**
```typescript
supabase.rpc('get_user_stats_with_timezone', { 
  p_user_id: userId,
  p_client_timezone: 'Europe/Warsaw'
})
```

### **Data Passed to StudyStreakCard:**
```typescript
rawStats={{
  study_streak: stats?.study_streak,        // 0 (wrong)
  weekly_progress: stats?.weekly_progress,  // [0,5,0,0,0,0,0] (Saturday data in wrong position)
  // ... other fields
}}
```

## 🚨 **Current Problematic Code**

### **StudyStreakCard Lines 206-232:**
```typescript
{weeklyProgress.map((dayReviews, index) => {
  const hasActivity = Number(dayReviews) > 0
  const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']  // ❌ HARDCODED
  return (
    <div key={index} className="flex-1 text-center">
      <div className={`h-8 border border-gray-300 rounded transition-all duration-300 ${
        hasActivity ? 'bg-orange-500 border-orange-600' : 'bg-gray-100 border-gray-200'
      }`}>
        {hasActivity && (
          <div className="text-white text-xs pt-1 font-bold">
            {dayReviews}  {/* Shows 5 reviews on Monday instead of Saturday */}
          </div>
        )}
      </div>
      <div className="text-xs text-gray-500 mt-1">
        {dayNames[index]}  {/* ❌ WRONG: Maps array[0] → Monday always */}
      </div>
    </div>
  )
})}
```

## ✅ **Correct Approach (Used by ProgressChart)**

### **ProgressChart uses mapReviewDataToChart():**
```typescript
const chartData = type === 'weekly' 
  ? mapReviewDataToChart(weeklyData, 'weekly', userTimezone)  // ✅ CORRECT
  : mapReviewDataToChart(monthlyData, 'monthly', userTimezone)
```

### **mapReviewDataToChart() properly maps:**
- Backend array position → Correct calendar day
- Timezone-aware date calculation
- Proper day name assignment

## 🛠️ **Fix Required**

### **Option 1: Use mapReviewDataToChart in StudyStreakCard**
```typescript
import { mapReviewDataToChart, getUserTimezone } from '@/utils/dateHelpers'

// In StudyStreakCard component:
const userTimezone = getUserTimezone()
const chartData = mapReviewDataToChart(weeklyProgress, 'weekly', userTimezone)

// Then map chartData instead of raw weeklyProgress:
{chartData.map((dayData, index) => {
  const hasActivity = dayData.reviews > 0
  return (
    <div key={index} className="flex-1 text-center">
      <div className={`h-8 border border-gray-300 rounded transition-all duration-300 ${
        hasActivity ? 'bg-orange-500 border-orange-600' : 'bg-gray-100 border-gray-200'
      }`}>
        {hasActivity && (
          <div className="text-white text-xs pt-1 font-bold">
            {dayData.reviews}
          </div>
        )}
      </div>
      <div className="text-xs text-gray-500 mt-1">
        {dayData.day}  {/* ✅ Correct day name from mapping */}
      </div>
    </div>
  )
})}
```

### **Option 2: Create StudyStreakCard-specific mapping**
Similar logic but tailored for the streak card display.

## 🎯 **Expected Fix Results**

After implementing the fix:
- ✅ Saturday study session shows on Saturday (not Monday)
- ✅ Study streak shows 1 (correct for first day)
- ✅ Weekly progress aligns with ProgressChart
- ✅ Day names match actual calendar days

## 📋 **Files to Modify**

1. **`src/components/dashboard/student/StudyStreakCard.tsx`**
   - Import mapReviewDataToChart
   - Replace direct array mapping with timezone-aware mapping
   - Update weekly progress visualization logic

The fix will align StudyStreakCard with ProgressChart's correct date handling approach.