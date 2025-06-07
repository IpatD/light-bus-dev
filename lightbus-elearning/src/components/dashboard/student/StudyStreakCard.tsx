'use client'

import React from 'react'
import { Flame, Calendar, Trophy, Target, TrendingUp, Award } from 'lucide-react'
import { 
  formatNextReviewDate, 
  getUserTimezone, 
  debugDateComparison 
} from '@/utils/dateHelpers'

interface StudyStreakCardProps {
  // REFACTORED: Accept raw stats data instead of processed values
  rawStats?: {
    study_streak?: number
    longest_streak?: number
    total_reviews?: number
    weekly_progress?: number[]
    next_review_date?: string
  }
  // Backward compatibility props (optional)
  currentStreak?: number
  longestStreak?: number
  totalStudyDays?: number
  weeklyGoal?: number
  weeklyProgress?: number | number[]
  nextReviewDate?: string
}

const StudyStreakCard: React.FC<StudyStreakCardProps> = ({
  rawStats,
  // Backward compatibility props
  currentStreak: legacyCurrentStreak,
  longestStreak: legacyLongestStreak,
  totalStudyDays: legacyTotalStudyDays,
  weeklyGoal = 7,
  weeklyProgress: legacyWeeklyProgress,
  nextReviewDate: legacyNextReviewDate
}) => {
  const userTimezone = getUserTimezone()
  
  // REFACTORED: Calculate longest streak from weekly progress data (moved from dashboard)
  const calculateLongestStreakFromProgress = (weeklyProgress: number[]): number => {
    if (!Array.isArray(weeklyProgress) || weeklyProgress.length === 0) {
      return 0
    }
    
    let longestStreak = 0
    let currentStreakCalc = 0
    
    // Convert weekly progress to binary activity (1 if reviews > 0, 0 if not)
    const activityPattern = weeklyProgress.map(reviews => Number(reviews) > 0 ? 1 : 0)
    
    // Find longest consecutive sequence of 1s
    for (const hasActivity of activityPattern) {
      if (hasActivity) {
        currentStreakCalc++
        longestStreak = Math.max(longestStreak, currentStreakCalc)
      } else {
        currentStreakCalc = 0
      }
    }
    
    return longestStreak
  }

  // REFACTORED: Process raw stats data internally (moved from dashboard)
  const processStreakData = () => {
    // Use rawStats if provided, otherwise fall back to legacy props
    if (rawStats) {
      const weeklyProgress = rawStats.weekly_progress || [0, 0, 0, 0, 0, 0, 0]
      
      // Calculate longest streak from available data (moved logic from dashboard)
      const calculatedLongestStreak = Math.max(
        Number(rawStats.longest_streak) || 0, // Use if available
        Number(rawStats.study_streak) || 0,   // Fallback to current streak
        calculateLongestStreakFromProgress(weeklyProgress) // Calculate from weekly data
      )
      
      return {
        currentStreak: Number(rawStats.study_streak) || 0,
        longestStreak: calculatedLongestStreak,
        totalStudyDays: Math.min(Number(rawStats.total_reviews) || 0, 100),
        weeklyProgress,
        nextReviewDate: rawStats.next_review_date
      }
    }
    
    // Backward compatibility: use legacy props
    return {
      currentStreak: legacyCurrentStreak || 0,
      longestStreak: legacyLongestStreak || 0,
      totalStudyDays: legacyTotalStudyDays || 0,
      weeklyProgress: legacyWeeklyProgress || [0, 0, 0, 0, 0, 0, 0],
      nextReviewDate: legacyNextReviewDate
    }
  }

  // Get processed streak data
  const streakData = processStreakData()
  const { currentStreak, longestStreak, totalStudyDays, weeklyProgress, nextReviewDate } = streakData
  
  const streakLevel = getStreakLevel(currentStreak)
  
  // FIXED: Calculate weekly progress days from array if needed
  const calculateWeeklyProgressDays = (progressData: number | number[]): number => {
    if (typeof progressData === 'number') {
      return progressData  // Already calculated
    }
    
    if (!Array.isArray(progressData)) {
      return 0
    }
    
    // Count how many days had reviews (non-zero values)
    return progressData.filter(dayReviews => Number(dayReviews) > 0).length
  }
  
  const actualWeeklyProgress = calculateWeeklyProgressDays(weeklyProgress)
  const progressPercentage = Math.min((actualWeeklyProgress / weeklyGoal) * 100, 100)
  const isGoalReached = actualWeeklyProgress >= weeklyGoal
  
  // ADDED: Enhanced streak analysis
  const streakAnalysis = getStreakAnalysis(currentStreak, longestStreak, totalStudyDays)
  const streakMotivation = getStreakMotivation(currentStreak, longestStreak)
  
  // FIXED: Use timezone-aware next review date formatting
  const formattedNextReviewDate = nextReviewDate
    ? formatNextReviewDate(nextReviewDate, userTimezone)
    : null

  // ADDED: Debug logging for streak calculations (moved from dashboard)
  if (process.env.NODE_ENV === 'development') {
    console.log('🔥 StudyStreakCard - Streak calculation:', {
      currentStreak,
      longestStreak,
      calculatedFromWeekly: calculateLongestStreakFromProgress(Array.isArray(weeklyProgress) ? weeklyProgress : []),
      weeklyPattern: weeklyProgress,
      rawStats: rawStats || 'Using legacy props'
    })
  }
  
  return (
    <div className="space-y-6">
      {/* Header with Level Badge */}
      <div className="flex items-center justify-between">
        <StreakBadge level={streakLevel} />
        {longestStreak > currentStreak && (
          <div className="flex items-center gap-1 text-xs text-gray-500">
            <Award size={12} />
            <span>Best: {longestStreak}</span>
          </div>
        )}
      </div>

      {/* Main Streak Display */}
      <div className="text-center py-4">
        <div className="relative">
          {/* Flame Animation */}
          <div className={`text-6xl mb-2 ${getFlameAnimation(currentStreak)}`}>
            {currentStreak > 0 ? '🔥' : '💨'}
          </div>
          
          {/* Streak Number */}
          <div className="text-4xl font-bold text-achievement-500 mb-1">
            {currentStreak}
          </div>
          <div className="text-sm font-semibold text-neutral-charcoal">
            {currentStreak === 1 ? 'Day Streak' : 'Days Streak'}
          </div>
          
          {/* ENHANCED: Dynamic Streak Status */}
          <div className="mt-2">
            {streakMotivation.message && (
              <span className={`text-sm font-medium ${streakMotivation.color}`}>
                {streakMotivation.icon} {streakMotivation.message}
              </span>
            )}
          </div>
        </div>
      </div>

      {/* ENHANCED: Statistics Grid with Better Streak Info */}
      <div className="grid grid-cols-2 gap-4">
        <div className="text-center p-3 bg-focus-50 border border-focus-200 rounded-lg">
          <div className="text-xl font-bold text-focus-600">{longestStreak}</div>
          <div className="text-xs text-focus-700">Best Streak</div>
          {longestStreak > 0 && currentStreak < longestStreak && (
            <div className="text-xs text-gray-500 mt-1">
              -{longestStreak - currentStreak} to beat
            </div>
          )}
        </div>
        <div className="text-center p-3 bg-learning-50 border border-learning-200 rounded-lg">
          <div className="text-xl font-bold text-learning-600">{totalStudyDays}</div>
          <div className="text-xs text-learning-700">Total Days</div>
          {streakAnalysis.consistency && (
            <div className="text-xs text-green-600 mt-1">
              {streakAnalysis.consistency}% consistent
            </div>
          )}
        </div>
      </div>

      {/* ENHANCED: Streak Progress Visualization */}
      {Array.isArray(weeklyProgress) && (
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium text-neutral-charcoal">This Week</span>
            <span className="text-sm text-neutral-gray">
              {actualWeeklyProgress}/{weeklyGoal} days
            </span>
          </div>
          
          {/* Visual Week Progress */}
          <div className="flex space-x-1">
            {weeklyProgress.map((dayReviews, index) => {
              const hasActivity = Number(dayReviews) > 0
              const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
              return (
                <div key={index} className="flex-1 text-center">
                  <div
                    className={`h-8 border border-gray-300 rounded transition-all duration-300 ${
                      hasActivity 
                        ? 'bg-orange-500 border-orange-600' 
                        : 'bg-gray-100 border-gray-200'
                    }`}
                    title={`${dayNames[index]}: ${dayReviews} reviews`}
                  >
                    {hasActivity && (
                      <div className="text-white text-xs pt-1 font-bold">
                        {dayReviews}
                      </div>
                    )}
                  </div>
                  <div className="text-xs text-gray-500 mt-1">
                    {dayNames[index]}
                  </div>
                </div>
              )
            })}
          </div>
        </div>
      )}

      {/* Weekly Goal Progress - ENHANCED: Better visualization */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <span className="text-sm font-medium text-neutral-charcoal">Weekly Goal</span>
          <span className="text-sm text-neutral-gray">
            {actualWeeklyProgress}/{weeklyGoal} days
          </span>
        </div>
        
        <div className="relative">
          <div className="w-full bg-neutral-gray bg-opacity-20 rounded-full h-3">
            <div 
              className={`h-3 rounded-full transition-all duration-500 ${
                isGoalReached ? 'bg-green-500' : 'bg-achievement-500'
              }`}
              style={{ width: `${progressPercentage}%` }}
            ></div>
          </div>
          
          {/* Goal Achievement Badge */}
          {isGoalReached && (
            <div className="absolute -top-1 -right-1">
              <div className="bg-green-500 text-white p-1 rounded-full text-xs font-bold">
                <Trophy size={12} />
              </div>
            </div>
          )}
        </div>
        
        <div className="text-center">
          {isGoalReached ? (
            <span className="text-green-600 text-sm font-medium">
              🎉 Weekly goal achieved!
            </span>
          ) : (
            <span className="text-neutral-gray text-sm">
              {weeklyGoal - actualWeeklyProgress} more days to reach your goal
            </span>
          )}
        </div>
      </div>

      {/* ENHANCED: Streak Insights */}
      {streakAnalysis.insights.length > 0 && (
        <div className="space-y-2">
          <h4 className="text-sm font-semibold text-neutral-charcoal">Streak Insights</h4>
          <div className="space-y-1">
            {streakAnalysis.insights.map((insight, index) => (
              <div key={index} className="flex items-start gap-2 text-xs">
                <span className="text-blue-500">{insight.icon}</span>
                <span className="text-gray-600">{insight.text}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Next Review Info - FIXED: Timezone-aware date display */}
      {formattedNextReviewDate && (
        <div className="p-3 bg-learning-50 border-l-4 border-learning-500 rounded">
          <div className="flex items-center gap-2 text-sm">
            <Calendar size={16} className="text-learning-600" />
            <span className="text-learning-700">
              Next review: {formattedNextReviewDate}
            </span>
          </div>
          {/* Debug info in development */}
          {process.env.NODE_ENV === 'development' && nextReviewDate && (
            <div className="mt-1 text-xs text-gray-400">
              Debug: {JSON.stringify(debugDateComparison(nextReviewDate, userTimezone))}
            </div>
          )}
        </div>
      )}

      {/* Motivational Messages */}
      <div className="text-center">
        <MotivationalMessage 
          currentStreak={currentStreak} 
          longestStreak={longestStreak}
          weeklyProgress={actualWeeklyProgress} 
        />
      </div>

      {/* Achievement Preview */}
      <div className="space-y-2">
        <h4 className="text-sm font-semibold text-neutral-charcoal">Upcoming Achievements</h4>
        <div className="space-y-1">
          {getUpcomingAchievements(currentStreak).map((achievement, index) => (
            <div key={index} className="flex items-center justify-between text-xs">
              <span className="text-neutral-gray">{achievement.name}</span>
              <span className="text-achievement-600 font-medium">
                {achievement.daysLeft} days
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* Development Debug Panel - ENHANCED with refactored info */}
      {process.env.NODE_ENV === 'development' && (
        <div className="mt-4 pt-4 border-t border-gray-300">
          <details className="text-xs text-gray-500">
            <summary className="cursor-pointer">Debug: Streak Card Info (Refactored)</summary>
            <div className="mt-2 p-2 bg-gray-100 rounded">
              <p><strong>Data Source:</strong> {rawStats ? 'Raw Stats (Refactored)' : 'Legacy Props'}</p>
              <p><strong>User Timezone:</strong> {userTimezone}</p>
              <p><strong>Current Streak:</strong> {currentStreak}</p>
              <p><strong>Longest Streak (Calculated):</strong> {longestStreak}</p>
              <p><strong>Longest from Weekly:</strong> {calculateLongestStreakFromProgress(Array.isArray(weeklyProgress) ? weeklyProgress : [])}</p>
              <p><strong>Raw Stats:</strong> {rawStats ? JSON.stringify(rawStats) : 'None'}</p>
              <p><strong>Next Review Date (Raw):</strong> {nextReviewDate || 'None'}</p>
              <p><strong>Next Review Date (Formatted):</strong> {formattedNextReviewDate || 'None'}</p>
              <p><strong>Weekly Progress (Raw):</strong> {JSON.stringify(weeklyProgress)}</p>
              <p><strong>Weekly Progress (Calculated):</strong> {actualWeeklyProgress}/{weeklyGoal}</p>
              <p><strong>Progress Type:</strong> {Array.isArray(weeklyProgress) ? 'Array (backend data)' : 'Number (pre-calculated)'}</p>
              <p><strong>Streak Analysis:</strong> {JSON.stringify(streakAnalysis)}</p>
              <p><strong>Component Self-Contained:</strong> ✅ All streak calculations moved here</p>
            </div>
          </details>
        </div>
      )}
    </div>
  )
}

// Streak Badge Component
interface StreakBadgeProps {
  level: 'beginner' | 'consistent' | 'dedicated' | 'master'
}

const StreakBadge: React.FC<StreakBadgeProps> = ({ level }) => {
  const config = {
    beginner: { bg: 'bg-gray-100', text: 'text-gray-700', label: 'Beginner', icon: '🌱' },
    consistent: { bg: 'bg-blue-100', text: 'text-blue-700', label: 'Consistent', icon: '⚡' },
    dedicated: { bg: 'bg-achievement-100', text: 'text-achievement-700', label: 'Dedicated', icon: '🔥' },
    master: { bg: 'bg-green-100', text: 'text-green-700', label: 'Master', icon: '👑' }
  }

  const { bg, text, label, icon } = config[level]

  return (
    <div className={`${bg} ${text} px-3 py-1 rounded-full text-xs font-semibold flex items-center gap-1`}>
      <span>{icon}</span>
      <span>{label}</span>
    </div>
  )
}

// ENHANCED: Motivational Message Component
const MotivationalMessage: React.FC<{ 
  currentStreak: number; 
  longestStreak: number;
  weeklyProgress: number 
}> = ({ currentStreak, longestStreak, weeklyProgress }) => {
  if (currentStreak === 0) {
    return (
      <div className="text-sm text-neutral-gray">
        💡 <strong>Tip:</strong> Start with just 5 minutes of study to build your habit
      </div>
    )
  }

  if (currentStreak === longestStreak && currentStreak > 1) {
    return (
      <div className="text-sm text-purple-600">
        🏆 Personal record! You're at your best streak ever
      </div>
    )
  }

  if (currentStreak < 3) {
    return (
      <div className="text-sm text-learning-600">
        🌱 Great start! Consistency is key to building lasting learning habits
      </div>
    )
  }

  if (currentStreak < 7) {
    return (
      <div className="text-sm text-achievement-600">
        ⚡ You're building momentum! Keep up the excellent work
      </div>
    )
  }

  if (currentStreak < 30) {
    return (
      <div className="text-sm text-green-600">
        🏆 Outstanding dedication! You're developing true mastery
      </div>
    )
  }

  return (
    <div className="text-sm text-purple-600">
      👑 Legendary learner! Your commitment is truly inspiring
    </div>
  )
}

// ADDED: Streak Analysis Helper
function getStreakAnalysis(currentStreak: number, longestStreak: number, totalStudyDays: number) {
  const insights = []
  let consistency = 0
  
  if (totalStudyDays > 0) {
    consistency = Math.round((currentStreak / Math.max(totalStudyDays, 1)) * 100)
  }

  if (currentStreak === longestStreak && currentStreak > 0) {
    insights.push({ icon: '🏆', text: 'This is your personal best!' })
  }
  
  if (currentStreak > 0 && currentStreak < longestStreak) {
    const daysToRecord = longestStreak - currentStreak
    insights.push({ icon: '🎯', text: `${daysToRecord} more days to beat your record` })
  }
  
  if (currentStreak >= 7) {
    insights.push({ icon: '💪', text: 'You\'ve built a solid study habit' })
  }
  
  if (currentStreak >= 30) {
    insights.push({ icon: '🧠', text: 'Your brain is optimized for learning' })
  }

  return {
    consistency,
    insights
  }
}

// ADDED: Streak Motivation Helper
function getStreakMotivation(currentStreak: number, longestStreak: number) {
  if (currentStreak === 0) {
    return {
      message: 'Start studying today to begin your streak!',
      color: 'text-neutral-gray',
      icon: '💡'
    }
  }

  if (currentStreak === longestStreak && currentStreak > 1) {
    return {
      message: 'Personal record! 🏆',
      color: 'text-purple-600',
      icon: '🚀'
    }
  }

  if (currentStreak < 3) {
    return {
      message: 'Keep it up! 🌟',
      color: 'text-learning-600',
      icon: '⭐'
    }
  }

  if (currentStreak < 7) {
    return {
      message: 'You\'re on fire! 🚀',
      color: 'text-achievement-600',
      icon: '🔥'
    }
  }

  return {
    message: 'Incredible dedication! 🏆',
    color: 'text-green-600',
    icon: '👑'
  }
}

// Helper Functions
function getStreakLevel(streak: number): 'beginner' | 'consistent' | 'dedicated' | 'master' {
  if (streak < 3) return 'beginner'
  if (streak < 7) return 'consistent'
  if (streak < 30) return 'dedicated'
  return 'master'
}

function getFlameAnimation(streak: number): string {
  if (streak === 0) return ''
  if (streak < 3) return 'animate-pulse'
  if (streak < 7) return 'animate-bounce'
  return 'animate-pulse'
}

function getUpcomingAchievements(currentStreak: number): Array<{ name: string; daysLeft: number }> {
  const achievements = [
    { milestone: 3, name: '🌟 First Spark' },
    { milestone: 7, name: '🔥 Week Warrior' },
    { milestone: 14, name: '⚡ Two Week Thunder' },
    { milestone: 30, name: '🏆 Monthly Master' },
    { milestone: 60, name: '💎 Diamond Dedication' },
    { milestone: 100, name: '👑 Century Scholar' }
  ]

  return achievements
    .filter(a => a.milestone > currentStreak)
    .slice(0, 3)
    .map(a => ({
      name: a.name,
      daysLeft: a.milestone - currentStreak
    }))
}

export default StudyStreakCard