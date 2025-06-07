// =============================================================================
// TIMEZONE-AWARE DATE HELPERS FOR FRONTEND
// =============================================================================
// 
// This module provides timezone-aware date handling utilities to fix date 
// discrepancies in the student dashboard learning analytics.
//
// FIXES:
// - Consistent timezone handling across all frontend components
// - Proper date boundary calculations
// - Client-side date formatting that aligns with backend dates
// - Timezone-aware date comparisons and calculations
// - FIXED: Proper mapping of backend weekly progress array to frontend chart
// =============================================================================

/**
 * Get the user's current timezone
 */
export function getUserTimezone(): string {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone;
  } catch (error) {
    console.warn('Could not detect user timezone, falling back to Europe/Warsaw');
    return 'Europe/Warsaw';
  }
}

/**
 * Convert a UTC timestamp string to a Date object in the user's timezone
 */
export function parseUTCDate(utcString: string): Date {
  if (!utcString) return new Date();
  
  // Ensure the string is treated as UTC
  const utcDate = utcString.endsWith('Z') ? utcString : `${utcString}Z`;
  return new Date(utcDate);
}

/**
 * Get the date in the user's timezone from a UTC timestamp
 */
export function getLocalDate(utcTimestamp: string | Date, timezone?: string): Date {
  const userTimezone = timezone || getUserTimezone();
  const date = typeof utcTimestamp === 'string' ? parseUTCDate(utcTimestamp) : utcTimestamp;
  
  // Create a new date object that represents the local date
  const localDateString = date.toLocaleDateString('en-CA', { 
    timeZone: userTimezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  });
  
  return new Date(localDateString + 'T00:00:00');
}

/**
 * Check if two timestamps are on the same date in the user's timezone
 */
export function isSameLocalDate(date1: string | Date, date2: string | Date, timezone?: string): boolean {
  const userTimezone = timezone || getUserTimezone();
  
  const d1 = typeof date1 === 'string' ? parseUTCDate(date1) : date1;
  const d2 = typeof date2 === 'string' ? parseUTCDate(date2) : date2;
  
  const localDate1 = d1.toLocaleDateString('en-CA', { timeZone: userTimezone });
  const localDate2 = d2.toLocaleDateString('en-CA', { timeZone: userTimezone });
  
  return localDate1 === localDate2;
}

/**
 * Check if a timestamp is "today" in the user's timezone
 */
export function isToday(timestamp: string | Date, timezone?: string): boolean {
  return isSameLocalDate(timestamp, new Date(), timezone);
}

/**
 * Check if a timestamp is "yesterday" in the user's timezone
 */
export function isYesterday(timestamp: string | Date, timezone?: string): boolean {
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  return isSameLocalDate(timestamp, yesterday, timezone);
}

/**
 * Get a date offset by a number of days in the user's timezone
 */
export function getDateOffset(offsetDays: number, timezone?: string): Date {
  const userTimezone = timezone || getUserTimezone();
  const today = new Date();
  
  // Get today's date in user timezone
  const todayLocal = today.toLocaleDateString('en-CA', { 
    timeZone: userTimezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  });
  
  // Create date object and offset
  const targetDate = new Date(todayLocal + 'T00:00:00');
  targetDate.setDate(targetDate.getDate() - offsetDays);
  
  return targetDate;
}

/**
 * Generate array of dates for weekly chart data (last 7 days)
 */
export function getWeeklyChartDates(timezone?: string): Array<{ date: Date; label: string; isToday: boolean }> {
  const userTimezone = timezone || getUserTimezone();
  const dates = [];
  
  for (let i = 6; i >= 0; i--) {
    const date = getDateOffset(i, userTimezone);
    const isToday = i === 0;
    const label = date.toLocaleDateString('en-US', { 
      weekday: 'short',
      timeZone: userTimezone 
    });
    
    dates.push({ date, label, isToday });
  }
  
  return dates;
}

/**
 * Generate array of dates for monthly chart data (current month)
 */
export function getMonthlyChartDates(timezone?: string): Array<{ date: Date; label: string; isToday: boolean }> {
  const userTimezone = timezone || getUserTimezone();
  const today = new Date();
  
  // Get current year and month in user timezone
  const currentDate = today.toLocaleDateString('en-CA', { 
    timeZone: userTimezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  });
  
  const [year, month] = currentDate.split('-');
  const firstDayStr = `${year}-${month}-01`;
  
  const firstDay = new Date(firstDayStr + 'T00:00:00');
  const daysInMonth = new Date(firstDay.getFullYear(), firstDay.getMonth() + 1, 0).getDate();
  
  const dates = [];
  for (let day = 1; day <= daysInMonth; day++) {
    const date = new Date(firstDay);
    date.setDate(day);
    
    const isToday = isSameLocalDate(date, today, userTimezone);
    const label = day.toString();
    
    dates.push({ date, label, isToday });
  }
  
  return dates;
}

/**
 * Format a date for display in the user's timezone
 */
export function formatDisplayDate(timestamp: string | Date, timezone?: string): string {
  const userTimezone = timezone || getUserTimezone();
  const date = typeof timestamp === 'string' ? parseUTCDate(timestamp) : timestamp;
  
  if (isToday(date, userTimezone)) {
    return 'Today';
  } else if (isYesterday(date, userTimezone)) {
    return 'Yesterday';
  } else {
    return date.toLocaleDateString('en-US', {
      timeZone: userTimezone,
      weekday: 'short',
      month: 'short',
      day: 'numeric'
    });
  }
}

/**
 * Format a next review date for display
 */
export function formatNextReviewDate(dateString: string, timezone?: string): string {
  if (!dateString) return '';
  
  const userTimezone = timezone || getUserTimezone();
  const date = parseUTCDate(dateString);
  const today = new Date();
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);

  if (isSameLocalDate(date, today, userTimezone)) {
    return 'Today';
  } else if (isSameLocalDate(date, tomorrow, userTimezone)) {
    return 'Tomorrow';
  } else {
    return date.toLocaleDateString('en-US', { 
      timeZone: userTimezone,
      weekday: 'short', 
      month: 'short', 
      day: 'numeric' 
    });
  }
}

/**
 * Map review data to chart format with timezone awareness
 * FIXED: Properly handle backend weekly progress array mapping
 */
export function mapReviewDataToChart(
  reviewData: number[], 
  chartType: 'weekly' | 'monthly',
  timezone?: string
): Array<{
  day: string;
  reviews: number;
  date: string;
  isToday: boolean;
  month?: string;
}> {
  const dates = chartType === 'weekly' 
    ? getWeeklyChartDates(timezone)
    : getMonthlyChartDates(timezone);
  
  // CRITICAL FIX: Backend weekly progress array structure
  // Backend: [today, yesterday, 2-days-ago, 3-days-ago, 4-days-ago, 5-days-ago, 6-days-ago]
  // Frontend: [6-days-ago, 5-days-ago, 4-days-ago, 3-days-ago, 2-days-ago, yesterday, today]
  
  if (chartType === 'weekly' && reviewData.length > 0) {
    // Reverse the backend array to match frontend date order
    const reversedData = [...reviewData].reverse();
    
    return dates.map((dateInfo, index) => ({
      day: dateInfo.label,
      reviews: reversedData[index] || 0,
      date: dateInfo.date.toISOString().split('T')[0],
      isToday: dateInfo.isToday,
    }));
  }
  
  // For monthly or normal array mapping
  return dates.map((dateInfo, index) => ({
    day: dateInfo.label,
    reviews: reviewData[index] || 0,
    date: dateInfo.date.toISOString().split('T')[0],
    isToday: dateInfo.isToday,
    month: chartType === 'monthly' 
      ? dateInfo.date.toLocaleDateString('en-US', { 
          month: 'short',
          timeZone: timezone || getUserTimezone()
        })
      : undefined
  }));
}

/**
 * Get timezone-aware parameters for backend function calls
 */
export function getTimezoneParams() {
  return {
    client_timezone: getUserTimezone()
  };
}

/**
 * Create timezone-aware date boundaries for filtering
 */
export function getDateBoundaries(date: Date, timezone?: string): {
  startOfDay: Date;
  endOfDay: Date;
} {
  const userTimezone = timezone || getUserTimezone();
  
  // Get the date string in user timezone
  const dateStr = date.toLocaleDateString('en-CA', { 
    timeZone: userTimezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  });
  
  // Create start and end of day in user timezone
  const startOfDay = new Date(dateStr + 'T00:00:00');
  const endOfDay = new Date(dateStr + 'T23:59:59.999');
  
  return { startOfDay, endOfDay };
}

/**
 * Debug helper to compare UTC vs local dates
 */
export function debugDateComparison(timestamp: string | Date, timezone?: string) {
  const userTimezone = timezone || getUserTimezone();
  const date = typeof timestamp === 'string' ? parseUTCDate(timestamp) : timestamp;
  
  return {
    utc_timestamp: date.toISOString(),
    utc_date: date.toISOString().split('T')[0],
    local_timestamp: date.toLocaleString('en-US', { timeZone: userTimezone }),
    local_date: date.toLocaleDateString('en-CA', { timeZone: userTimezone }),
    timezone: userTimezone,
    is_today: isToday(date, userTimezone),
    is_yesterday: isYesterday(date, userTimezone)
  };
}

/**
 * Validate that frontend and backend dates align
 */
export function validateDateAlignment(
  frontendDate: Date, 
  backendTimestamp: string, 
  timezone?: string
): {
  aligned: boolean;
  difference_hours: number;
  debug_info: any;
} {
  const userTimezone = timezone || getUserTimezone();
  const backendDate = parseUTCDate(backendTimestamp);
  
  const frontendDateStr = frontendDate.toLocaleDateString('en-CA', { timeZone: userTimezone });
  const backendDateStr = backendDate.toLocaleDateString('en-CA', { timeZone: userTimezone });
  
  const aligned = frontendDateStr === backendDateStr;
  const differenceMs = Math.abs(frontendDate.getTime() - backendDate.getTime());
  const differenceHours = differenceMs / (1000 * 60 * 60);
  
  return {
    aligned,
    difference_hours: differenceHours,
    debug_info: {
      frontend_date: frontendDateStr,
      backend_date: backendDateStr,
      frontend_debug: debugDateComparison(frontendDate, userTimezone),
      backend_debug: debugDateComparison(backendDate, userTimezone)
    }
  };
}

/**
 * Debug helper to analyze backend weekly progress array mapping
 */
export function debugWeeklyProgressMapping(backendArray: number[], timezone?: string) {
  const userTimezone = timezone || getUserTimezone();
  const dates = getWeeklyChartDates(userTimezone);
  const reversedData = [...backendArray].reverse();
  
  console.log('=== WEEKLY PROGRESS DEBUG ===');
  console.log('Backend array (original):', backendArray);
  console.log('Backend array (reversed):', reversedData);
  console.log('Date mapping:');
  
  dates.forEach((dateInfo, index) => {
    console.log(`  ${index}: ${dateInfo.date.toISOString().split('T')[0]} (${dateInfo.label}) ${dateInfo.isToday ? '← TODAY' : ''} → ${reversedData[index] || 0} reviews`);
  });
  
  console.log('Expected frontend display:');
  dates.forEach((dateInfo, index) => {
    if (reversedData[index] > 0) {
      console.log(`  ${dateInfo.label}: ${reversedData[index]} reviews on ${dateInfo.date.toISOString().split('T')[0]}`);
    }
  });
}