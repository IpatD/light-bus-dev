'use client'

import React from 'react'
import { Flame, Calendar, Trophy, Target } from 'lucide-react'
import { 
  formatNextReviewDate, 
  getUserTimezone, 
  debugDateComparison 
} from '@/utils/dateHelpers'

interface StudyStreakCardProps {
  currentStreak: number
  longestStreak: number
  totalStudyDays: number
  weeklyGoal: number
  weeklyProgress: number
  nextReviewDate?: string
}

const StudyStreakCard: React.FC<StudyStreakCardProps> = ({
  currentStreak,
  longestStreak,
  totalStudyDays,
  weeklyGoal = 7,
  weeklyProgress,
  nextReviewDate
}) => {
  const userTimezone = getUserTimezone()
  const streakLevel = getStreakLevel(currentStreak)
  const progressPercentage = Math.min((weeklyProgress / weeklyGoal) * 100, 100)
  const isGoalReached = weeklyProgress >= weeklyGoal
  
  // FIXED: Use timezone-aware next review date formatting
  const formattedNextReviewDate = nextReviewDate 
    ? formatNextReviewDate(nextReviewDate, userTimezone)
    : null
  
  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <StreakBadge level={streakLevel} />
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
          
          {/* Streak Status */}
          <div className="mt-2">
            {currentStreak === 0 ? (
              <span className="text-neutral-gray text-sm">
                Start studying today to begin your streak!
              </span>
            ) : currentStreak < 3 ? (
              <span className="text-learning-600 text-sm font-medium">
                Keep it up! 🌟
              </span>
            ) : currentStreak < 7 ? (
              <span className="text-achievement-600 text-sm font-medium">
                You're on fire! 🚀
              </span>
            ) : (
              <span className="text-green-600 text-sm font-medium">
                Incredible dedication! 🏆
              </span>
            )}
          </div>
        </div>
      </div>

      {/* Statistics Grid */}
      <div className="grid grid-cols-2 gap-4">
        <div className="text-center p-3 bg-focus-50 border border-focus-200 rounded-lg">
          <div className="text-xl font-bold text-focus-600">{longestStreak}</div>
          <div className="text-xs text-focus-700">Best Streak</div>
        </div>
        <div className="text-center p-3 bg-learning-50 border border-learning-200 rounded-lg">
          <div className="text-xl font-bold text-learning-600">{totalStudyDays}</div>
          <div className="text-xs text-learning-700">Total Days</div>
        </div>
      </div>

      {/* Weekly Goal Progress */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <span className="text-sm font-medium text-neutral-charcoal">Weekly Goal</span>
          <span className="text-sm text-neutral-gray">
            {weeklyProgress}/{weeklyGoal} days
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
              {weeklyGoal - weeklyProgress} more days to reach your goal
            </span>
          )}
        </div>
      </div>

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
        <MotivationalMessage currentStreak={currentStreak} weeklyProgress={weeklyProgress} />
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

      {/* Development Debug Panel */}
      {process.env.NODE_ENV === 'development' && (
        <div className="mt-4 pt-4 border-t border-gray-300">
          <details className="text-xs text-gray-500">
            <summary className="cursor-pointer">Debug: Streak Card Info</summary>
            <div className="mt-2 p-2 bg-gray-100 rounded">
              <p><strong>User Timezone:</strong> {userTimezone}</p>
              <p><strong>Current Streak:</strong> {currentStreak}</p>
              <p><strong>Next Review Date (Raw):</strong> {nextReviewDate || 'None'}</p>
              <p><strong>Next Review Date (Formatted):</strong> {formattedNextReviewDate || 'None'}</p>
              <p><strong>Weekly Progress:</strong> {weeklyProgress}/{weeklyGoal}</p>
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
    beginner: { bg: 'bg-gray-100', text: 'text-gray-700', label: 'Beginner' },
    consistent: { bg: 'bg-blue-100', text: 'text-blue-700', label: 'Consistent' },
    dedicated: { bg: 'bg-achievement-100', text: 'text-achievement-700', label: 'Dedicated' },
    master: { bg: 'bg-green-100', text: 'text-green-700', label: 'Master' }
  }

  const { bg, text, label } = config[level]

  return (
    <div className={`${bg} ${text} px-3 py-1 rounded-full text-xs font-semibold`}>
      {label}
    </div>
  )
}

// Motivational Message Component
const MotivationalMessage: React.FC<{ currentStreak: number; weeklyProgress: number }> = ({
  currentStreak,
  weeklyProgress
}) => {
  if (currentStreak === 0) {
    return (
      <div className="text-sm text-neutral-gray">
        💡 <strong>Tip:</strong> Start with just 5 minutes of study to build your habit
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