'use client'

import React, { useState, useEffect } from 'react'
import { getUserTimezone, getWeeklyChartDates, isToday, formatNextReviewDate } from '@/utils/dateHelpers'

// Interface for the raw stats passed from the dashboard
interface RawStats {
  study_streak?: number
  longest_streak?: number
  total_reviews?: number
  weekly_progress?: number[]
  next_review_date?: string
}

interface StudyStreakCardProps {
  rawStats: RawStats
  weeklyGoal?: number
}

interface Achievement {
  id: string
  name: string
  icon: string
  description: string
  unlocked: boolean
  currentProgress?: number
  targetProgress?: number
}

interface Milestone {
  days: number
  name: string
  icon: string
  description: string
  achieved: boolean
}

// Achievement levels based on streak
const getAchievementLevel = (streak: number): { name: string; icon: string; color: string; bgColor: string } => {
  if (streak >= 30) return { name: 'Master', icon: '👑', color: '#22c55e', bgColor: 'bg-green-100' }
  if (streak >= 7) return { name: 'Dedicated', icon: '🔥', color: '#ff6b35', bgColor: 'bg-orange-100' }
  if (streak >= 3) return { name: 'Consistent', icon: '⚡', color: '#3b82f6', bgColor: 'bg-blue-100' }
  return { name: 'Beginner', icon: '🌱', color: '#22c55e', bgColor: 'bg-green-50' }
}

// Named milestones
const MILESTONES: Milestone[] = [
  { days: 3, name: 'First Spark', icon: '🌟', description: 'You\'ve started your journey!', achieved: false },
  { days: 7, name: 'Week Warrior', icon: '🔥', description: 'A full week of dedication!', achieved: false },
  { days: 14, name: 'Two Week Thunder', icon: '⚡', description: 'Two weeks of consistent learning!', achieved: false },
  { days: 30, name: 'Monthly Master', icon: '🏆', description: 'A month of excellence!', achieved: false },
  { days: 60, name: 'Diamond Dedication', icon: '💎', description: 'Two months of mastery!', achieved: false },
  { days: 100, name: 'Century Scholar', icon: '👑', description: 'A hundred days of wisdom!', achieved: false }
]

// Motivational messages based on streak
const getMotivationalMessage = (currentStreak: number, longestStreak: number): string => {
  if (currentStreak === 0) {
    return longestStreak > 0 
      ? `Ready for a comeback? Your best was ${longestStreak} days!`
      : 'Ready to start your learning journey? Every expert was once a beginner!'
  }
  
  if (currentStreak > longestStreak) {
    return `🎉 NEW RECORD! You've beaten your best streak of ${longestStreak} days!`
  }
  
  if (currentStreak >= 30) {
    return '🏆 Elite performance! You\'re a true learning champion!'
  }
  
  if (currentStreak >= 14) {
    return '💪 Outstanding commitment! You\'re building incredible habits!'
  }
  
  if (currentStreak >= 7) {
    return '🔥 On fire! A full week of consistent learning!'
  }
  
  if (currentStreak >= 3) {
    return '⚡ Great momentum! Keep the energy flowing!'
  }
  
  return '🌱 Great start! Every journey begins with a single step!'
}

// Calculate weekly activity from progress data
const calculateWeeklyActivity = (weeklyProgress: number[]): { studiedDays: number; consistencyPercentage: number } => {
  if (!weeklyProgress || weeklyProgress.length === 0) {
    return { studiedDays: 0, consistencyPercentage: 0 }
  }
  
  const studiedDays = weeklyProgress.filter(day => day > 0).length
  const consistencyPercentage = Math.round((studiedDays / 7) * 100)
  
  return { studiedDays, consistencyPercentage }
}

// Get next milestone
const getNextMilestone = (currentStreak: number): Milestone | null => {
  return MILESTONES.find(milestone => milestone.days > currentStreak) || null
}

export default function StudyStreakCard({ rawStats, weeklyGoal = 7 }: StudyStreakCardProps) {
  const [animateFlame, setAnimateFlame] = useState(false)
  const [weeklyDates, setWeeklyDates] = useState<Array<{ date: Date; label: string; isToday: boolean }>>([])
  
  // Process raw stats with safe defaults
  const currentStreak = rawStats?.study_streak || 0
  const longestStreak = rawStats?.longest_streak || 0
  const totalReviews = rawStats?.total_reviews || 0
  const weeklyProgress = rawStats?.weekly_progress || [0, 0, 0, 0, 0, 0, 0]
  const nextReviewDate = rawStats?.next_review_date
  
  const userTimezone = getUserTimezone()
  const achievementLevel = getAchievementLevel(currentStreak)
  const motivationalMessage = getMotivationalMessage(currentStreak, longestStreak)
  const weeklyActivity = calculateWeeklyActivity(weeklyProgress)
  const nextMilestone = getNextMilestone(currentStreak)
  
  // Update milestones based on current streak
  const milestonesWithStatus = MILESTONES.map(milestone => ({
    ...milestone,
    achieved: currentStreak >= milestone.days
  }))

  useEffect(() => {
    // Generate weekly dates for calendar
    setWeeklyDates(getWeeklyChartDates(userTimezone))
    
    // Animate flame icon on mount if streak > 0
    if (currentStreak > 0) {
      setAnimateFlame(true)
      const timer = setTimeout(() => setAnimateFlame(false), 1000)
      return () => clearTimeout(timer)
    }
  }, [currentStreak, userTimezone])

  // Weekly calendar component
  const WeeklyCalendar = () => {
    // Reverse weekly progress to match frontend date order (oldest to newest)
    const reversedProgress = [...weeklyProgress].reverse()
    
    return (
      <div className="grid grid-cols-7 gap-1 mb-4">
        {weeklyDates.map((dateInfo, index) => {
          const hasActivity = reversedProgress[index] > 0
          const activityCount = reversedProgress[index] || 0
          const isCurrentDay = dateInfo.isToday
          
          return (
            <div key={index} className="text-center">
              <div className={`text-xs font-medium mb-1 ${isCurrentDay ? 'text-orange-600' : 'text-gray-600'}`}>
                {dateInfo.label}
              </div>
              <div 
                className={`
                  h-8 w-8 mx-auto border-2 flex items-center justify-center text-xs font-bold transition-all duration-300
                  ${isCurrentDay ? 'border-orange-500' : 'border-gray-300'}
                  ${hasActivity 
                    ? 'bg-orange-500 text-white shadow-md hover:shadow-lg' 
                    : 'bg-gray-100 text-gray-400 hover:bg-gray-200'
                  }
                `}
                title={`${dateInfo.date.toLocaleDateString()}: ${activityCount} reviews`}
              >
                {hasActivity ? activityCount : '•'}
              </div>
            </div>
          )
        })}
      </div>
    )
  }

  // Achievement badges component
  const AchievementBadges = () => (
    <div className="space-y-2">
      <h4 className="text-sm font-semibold text-gray-700">Achievements</h4>
      <div className="grid grid-cols-2 gap-2">
        {milestonesWithStatus.slice(0, 4).map((milestone) => (
          <div
            key={milestone.days}
            className={`
              p-2 rounded-lg border-2 text-center transition-all duration-300
              ${milestone.achieved
                ? 'border-orange-300 bg-orange-50 text-orange-800'
                : 'border-gray-200 bg-gray-50 text-gray-400'
              }
            `}
          >
            <div className="text-lg">{milestone.icon}</div>
            <div className="text-xs font-medium">{milestone.name}</div>
          </div>
        ))}
      </div>
    </div>
  )

  // Progress statistics component
  const ProgressStats = () => (
    <div className="space-y-3">
      <div className="flex justify-between items-center">
        <span className="text-sm text-gray-600">Best Streak</span>
        <span className="font-bold text-orange-600">{longestStreak} days</span>
      </div>
      <div className="flex justify-between items-center">
        <span className="text-sm text-gray-600">This Week</span>
        <span className="font-bold text-orange-600">{weeklyActivity.studiedDays}/7 days</span>
      </div>
      <div className="flex justify-between items-center">
        <span className="text-sm text-gray-600">Consistency</span>
        <span className="font-bold text-orange-600">{weeklyActivity.consistencyPercentage}%</span>
      </div>
      <div className="flex justify-between items-center">
        <span className="text-sm text-gray-600">Total Reviews</span>
        <span className="font-bold text-orange-600">{totalReviews.toLocaleString()}</span>
      </div>
    </div>
  )

  // Weekly goal progress component
  const WeeklyGoalProgress = () => {
    const goalProgress = Math.min((weeklyActivity.studiedDays / weeklyGoal) * 100, 100)
    const isGoalMet = weeklyActivity.studiedDays >= weeklyGoal
    
    return (
      <div className="space-y-3">
        <div className="flex justify-between items-center">
          <span className="text-sm font-medium text-gray-700">Weekly Goal</span>
          <span className={`text-sm font-bold ${isGoalMet ? 'text-green-600' : 'text-orange-600'}`}>
            {weeklyActivity.studiedDays}/{weeklyGoal} days
          </span>
        </div>
        <div className="w-full bg-gray-200 h-3 border-2 border-black">
          <div
            className={`h-full transition-all duration-500 ${isGoalMet ? 'bg-green-500' : 'bg-orange-500'}`}
            style={{ width: `${goalProgress}%` }}
          />
        </div>
        {isGoalMet && (
          <div className="text-xs text-green-600 font-medium flex items-center">
            <span className="mr-1">🎉</span>
            Goal achieved! Keep it up!
          </div>
        )}
      </div>
    )
  }

  // Next milestone preview component
  const NextMilestonePreview = () => {
    if (!nextMilestone) {
      return (
        <div className="p-3 bg-gradient-to-r from-purple-50 to-pink-50 border-2 border-purple-200 rounded-lg">
          <div className="text-center">
            <div className="text-2xl mb-2">🏆</div>
            <div className="text-sm font-bold text-purple-800">Master Level!</div>
            <div className="text-xs text-purple-600">You've achieved all milestones!</div>
          </div>
        </div>
      )
    }

    const daysToGo = nextMilestone.days - currentStreak
    const progress = currentStreak / nextMilestone.days * 100

    return (
      <div className="p-3 bg-gradient-to-r from-blue-50 to-indigo-50 border-2 border-blue-200 rounded-lg">
        <div className="text-center mb-2">
          <div className="text-xl mb-1">{nextMilestone.icon}</div>
          <div className="text-sm font-bold text-blue-800">{nextMilestone.name}</div>
          <div className="text-xs text-blue-600">{daysToGo} days to go!</div>
        </div>
        <div className="w-full bg-blue-100 h-2 rounded-full">
          <div
            className="h-full bg-blue-500 rounded-full transition-all duration-500"
            style={{ width: `${progress}%` }}
          />
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Main Streak Display */}
      <div className="text-center">
        <div className="flex items-center justify-center mb-3">
          <div 
            className={`text-6xl transition-all duration-300 ${
              animateFlame ? 'animate-bounce scale-110' : ''
            }`}
          >
            {achievementLevel.icon}
          </div>
        </div>
        
        <div className="mb-2">
          <div className="text-4xl font-bold text-orange-600 mb-1">
            {currentStreak}
          </div>
          <div className="text-sm font-medium text-gray-600">
            day{currentStreak !== 1 ? 's' : ''} streak
          </div>
        </div>
        
        <div className={`inline-flex items-center px-3 py-1 rounded-full text-xs font-medium ${achievementLevel.bgColor}`}>
          <span className="mr-1">{achievementLevel.icon}</span>
          {achievementLevel.name}
        </div>
      </div>

      {/* Motivational Message */}
      <div className="text-center p-3 bg-gradient-to-r from-orange-50 to-yellow-50 border-2 border-orange-200 rounded-lg">
        <div className="text-sm font-medium text-orange-800">
          {motivationalMessage}
        </div>
      </div>

      {/* Weekly Calendar */}
      <div>
        <h4 className="text-sm font-semibold text-gray-700 mb-3">This Week</h4>
        <WeeklyCalendar />
      </div>

      {/* Weekly Goal Progress */}
      <WeeklyGoalProgress />

      {/* Progress Statistics */}
      <ProgressStats />

      {/* Achievement Badges */}
      <AchievementBadges />

      {/* Next Milestone Preview */}
      <NextMilestonePreview />

      {/* Next Review Date */}
      {nextReviewDate && (
        <div className="text-center p-3 bg-gray-50 border-2 border-gray-200 rounded-lg">
          <div className="text-xs text-gray-600 mb-1">Next Review</div>
          <div className="text-sm font-medium text-gray-800">
            {formatNextReviewDate(nextReviewDate, userTimezone)}
          </div>
        </div>
      )}
    </div>
  )
}