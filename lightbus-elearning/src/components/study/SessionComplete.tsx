'use client'

import React from 'react'
import { Trophy, Star, Clock, RotateCcw, Home, BookOpen, TrendingUp } from 'lucide-react'
import { StudyCardReview } from '@/types'
import Card from '@/components/ui/Card'
import Button from '@/components/ui/Button'

interface SessionCompleteProps {
  reviews: StudyCardReview[]
  totalCards: number
  sessionDuration: number
  onRestart: () => void
  onExit: () => void
  onContinueStudy: () => void
}

const SessionComplete: React.FC<SessionCompleteProps> = ({
  reviews,
  totalCards,
  sessionDuration,
  onRestart,
  onExit,
  onContinueStudy
}) => {
  // Calculate session statistics
  const averageQuality = reviews.length > 0 
    ? reviews.reduce((sum, review) => sum + review.quality_rating, 0) / reviews.length 
    : 0

  const averageResponseTime = reviews.length > 0
    ? reviews.reduce((sum, review) => sum + review.response_time_ms, 0) / reviews.length
    : 0

  const qualityDistribution = reviews.reduce((acc, review) => {
    acc[review.quality_rating] = (acc[review.quality_rating] || 0) + 1
    return acc
  }, {} as Record<number, number>)

  const excellentCards = reviews.filter(r => r.quality_rating >= 4).length
  const goodCards = reviews.filter(r => r.quality_rating === 3).length
  const needsWorkCards = reviews.filter(r => r.quality_rating <= 2).length

  const performanceLevel = getPerformanceLevel(averageQuality)
  const achievements = getSessionAchievements(reviews, sessionDuration, averageQuality)

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Header Card */}
      <Card variant="primary" padding="lg" className="text-center">
        <div className="space-y-4">
          <div className="text-6xl">
            {performanceLevel.emoji}
          </div>
          
          <div>
            <h1 className="heading-2 mb-2">Session Complete!</h1>
            <p className="text-lg text-neutral-gray">
              {performanceLevel.message}
            </p>
          </div>

          {/* Main Stats */}
          <div className="grid grid-cols-3 gap-6 mt-6">
            <div className="space-y-2">
              <div className="text-3xl font-bold text-learning-500">{totalCards}</div>
              <div className="text-sm text-neutral-gray">Cards Studied</div>
            </div>
            
            <div className="space-y-2">
              <div className="flex items-center justify-center gap-1">
                {Array.from({ length: 5 }, (_, i) => (
                  <Star
                    key={i}
                    size={20}
                    className={
                      i < Math.round(averageQuality)
                        ? 'text-achievement-500 fill-achievement-500'
                        : 'text-neutral-gray'
                    }
                  />
                ))}
              </div>
              <div className="text-sm text-neutral-gray">
                Average Quality ({averageQuality.toFixed(1)})
              </div>
            </div>
            
            <div className="space-y-2">
              <div className="text-3xl font-bold text-focus-500">
                {formatDuration(sessionDuration)}
              </div>
              <div className="text-sm text-neutral-gray">Study Time</div>
            </div>
          </div>
        </div>
      </Card>

      {/* Detailed Statistics */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Performance Breakdown */}
        <Card variant="default" padding="lg">
          <h3 className="heading-4 mb-4">📊 Performance Breakdown</h3>
          
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <span className="text-green-600 flex items-center gap-2">
                <div className="w-3 h-3 bg-green-500"></div>
                Excellent (4-5)
              </span>
              <span className="font-bold">{excellentCards} cards</span>
            </div>
            
            <div className="flex items-center justify-between">
              <span className="text-achievement-600 flex items-center gap-2">
                <div className="w-3 h-3 bg-achievement-500"></div>
                Good (3)
              </span>
              <span className="font-bold">{goodCards} cards</span>
            </div>
            
            <div className="flex items-center justify-between">
              <span className="text-orange-600 flex items-center gap-2">
                <div className="w-3 h-3 bg-orange-500"></div>
                Needs Work (0-2)
              </span>
              <span className="font-bold">{needsWorkCards} cards</span>
            </div>

            {/* Performance Bar */}
            <div className="mt-4">
              <div className="flex h-4 bg-neutral-gray bg-opacity-20 overflow-hidden">
                <div 
                  className="bg-green-500"
                  style={{ width: `${(excellentCards / totalCards) * 100}%` }}
                ></div>
                <div 
                  className="bg-achievement-500"
                  style={{ width: `${(goodCards / totalCards) * 100}%` }}
                ></div>
                <div 
                  className="bg-orange-500"
                  style={{ width: `${(needsWorkCards / totalCards) * 100}%` }}
                ></div>
              </div>
            </div>
          </div>
        </Card>

        {/* Session Insights */}
        <Card variant="default" padding="lg">
          <h3 className="heading-4 mb-4">💡 Session Insights</h3>
          
          <div className="space-y-3">
            <div className="flex items-center gap-3">
              <Clock size={16} className="text-focus-500" />
              <div>
                <div className="font-medium">Average Response Time</div>
                <div className="text-sm text-neutral-gray">
                  {(averageResponseTime / 1000).toFixed(1)} seconds
                </div>
              </div>
            </div>

            <div className="flex items-center gap-3">
              <TrendingUp size={16} className="text-learning-500" />
              <div>
                <div className="font-medium">Study Efficiency</div>
                <div className="text-sm text-neutral-gray">
                  {(totalCards / (sessionDuration / 60000)).toFixed(1)} cards/minute
                </div>
              </div>
            </div>

            <div className="flex items-center gap-3">
              <Star size={16} className="text-achievement-500" />
              <div>
                <div className="font-medium">Mastery Rate</div>
                <div className="text-sm text-neutral-gray">
                  {((excellentCards / totalCards) * 100).toFixed(0)}% excellent responses
                </div>
              </div>
            </div>
          </div>
        </Card>
      </div>

      {/* Achievements */}
      {achievements.length > 0 && (
        <Card variant="accent" padding="lg">
          <h3 className="heading-4 mb-4">🏆 Achievements Unlocked</h3>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {achievements.map((achievement, index) => (
              <div key={index} className="flex items-center gap-3 p-3 bg-white">
                <div className="text-2xl">{achievement.icon}</div>
                <div>
                  <div className="font-semibold text-neutral-charcoal">
                    {achievement.title}
                  </div>
                  <div className="text-sm text-neutral-gray">
                    {achievement.description}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </Card>
      )}

      {/* Next Steps */}
      <Card variant="default" padding="lg">
        <h3 className="heading-4 mb-4">🎯 Next Steps</h3>
        
        <div className="space-y-4">
          {needsWorkCards > 0 && (
            <div className="p-4 bg-orange-50 border-l-4 border-orange-500">
              <div className="font-medium text-orange-700 mb-1">
                Focus Areas Identified
              </div>
              <div className="text-sm text-orange-600">
                {needsWorkCards} cards need additional practice. 
                These will appear more frequently in future sessions.
              </div>
            </div>
          )}

          <div className="p-4 bg-learning-50 border-l-4 border-learning-500">
            <div className="font-medium text-learning-700 mb-1">
              Spaced Repetition Scheduled
            </div>
            <div className="text-sm text-learning-600">
              Your next review sessions have been automatically scheduled based on your performance.
            </div>
          </div>

          {excellentCards === totalCards && (
            <div className="p-4 bg-green-50 border-l-4 border-green-500">
              <div className="font-medium text-green-700 mb-1">
                Perfect Session! 🌟
              </div>
              <div className="text-sm text-green-600">
                All cards mastered! Consider exploring more advanced topics.
              </div>
            </div>
          )}
        </div>
      </Card>

      {/* Action Buttons */}
      <div className="flex flex-col sm:flex-row gap-4 justify-center">
        <Button
          variant="primary"
          size="lg"
          onClick={onContinueStudy}
          className="flex items-center gap-2"
        >
          <BookOpen size={20} />
          Continue Studying
        </Button>
        
        <Button
          variant="secondary"
          size="lg"
          onClick={onRestart}
          className="flex items-center gap-2"
        >
          <RotateCcw size={20} />
          Study Again
        </Button>
        
        <Button
          variant="ghost"
          size="lg"
          onClick={onExit}
          className="flex items-center gap-2"
        >
          <Home size={20} />
          Back to Dashboard
        </Button>
      </div>
    </div>
  )
}

// Helper Functions
function getPerformanceLevel(averageQuality: number) {
  if (averageQuality >= 4.5) {
    return {
      emoji: '🏆',
      message: 'Outstanding performance! You\'ve mastered these concepts excellently.'
    }
  } else if (averageQuality >= 3.5) {
    return {
      emoji: '⭐',
      message: 'Great work! You showed strong understanding of the material.'
    }
  } else if (averageQuality >= 2.5) {
    return {
      emoji: '👍',
      message: 'Good effort! You\'re making solid progress with these concepts.'
    }
  } else if (averageQuality >= 1.5) {
    return {
      emoji: '💪',
      message: 'Keep practicing! These concepts need more attention.'
    }
  } else {
    return {
      emoji: '🎯',
      message: 'Challenge accepted! These topics require focused study.'
    }
  }
}

function getSessionAchievements(reviews: StudyCardReview[], duration: number, averageQuality: number) {
  const achievements = []

  // Perfect session
  if (reviews.every(r => r.quality_rating >= 4)) {
    achievements.push({
      icon: '🌟',
      title: 'Perfect Session',
      description: 'All cards rated 4 or higher!'
    })
  }

  // Speed achievement
  const avgResponseTime = reviews.reduce((sum, r) => sum + r.response_time_ms, 0) / reviews.length
  if (avgResponseTime < 3000) {
    achievements.push({
      icon: '⚡',
      title: 'Lightning Fast',
      description: 'Average response under 3 seconds!'
    })
  }

  // Consistency achievement
  if (reviews.length >= 10 && reviews.every(r => r.quality_rating >= 3)) {
    achievements.push({
      icon: '🎯',
      title: 'Consistent Performer',
      description: 'All cards rated 3 or higher!'
    })
  }

  // Long session achievement
  if (duration > 20 * 60 * 1000) { // 20 minutes
    achievements.push({
      icon: '⏰',
      title: 'Dedicated Learner',
      description: 'Studied for over 20 minutes!'
    })
  }

  return achievements
}

function formatDuration(milliseconds: number): string {
  const totalSeconds = Math.floor(milliseconds / 1000)
  const minutes = Math.floor(totalSeconds / 60)
  const seconds = totalSeconds % 60

  if (minutes > 0) {
    return `${minutes}:${seconds.toString().padStart(2, '0')}`
  }
  return `${seconds}s`
}

export default SessionComplete