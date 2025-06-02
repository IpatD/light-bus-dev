'use client'

import React from 'react'
import { CheckCircle2, Circle, Star } from 'lucide-react'
import Card from '@/components/ui/Card'

interface SessionProgressProps {
  current: number
  total: number
  completed: number
  averageQuality: number
  timeElapsed?: number
}

const SessionProgress: React.FC<SessionProgressProps> = ({
  current,
  total,
  completed,
  averageQuality,
  timeElapsed
}) => {
  const progressPercentage = (completed / total) * 100
  const qualityStars = Math.round(averageQuality)
  
  return (
    <Card variant="default" padding="md" className="bg-white border-learning-300">
      <div className="space-y-4">
        {/* Progress Bar */}
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <h3 className="font-semibold text-neutral-charcoal">Session Progress</h3>
            <span className="text-sm text-neutral-gray">
              {completed} of {total} cards
            </span>
          </div>
          
          <div className="relative">
            <div className="w-full bg-neutral-gray bg-opacity-20 h-3">
              <div 
                className="bg-learning-500 h-3 transition-all duration-300"
                style={{ width: `${progressPercentage}%` }}
              ></div>
            </div>
            
            {/* Progress Markers */}
            <div className="flex justify-between mt-2">
              {Array.from({ length: Math.min(total, 10) }, (_, i) => {
                const cardNumber = Math.floor((i / 9) * (total - 1)) + 1
                const isCompleted = cardNumber <= completed
                const isCurrent = cardNumber === current
                
                return (
                  <div key={i} className="flex flex-col items-center">
                    {isCompleted ? (
                      <CheckCircle2 size={16} className="text-green-500" />
                    ) : isCurrent ? (
                      <Circle size={16} className="text-learning-500 fill-learning-500" />
                    ) : (
                      <Circle size={16} className="text-neutral-gray" />
                    )}
                    <span className="text-xs text-neutral-gray mt-1">
                      {cardNumber}
                    </span>
                  </div>
                )
              })}
            </div>
          </div>
        </div>

        {/* Statistics Row */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="text-center">
            <div className="text-2xl font-bold text-learning-500">{current}</div>
            <div className="text-xs text-neutral-gray">Current</div>
          </div>
          
          <div className="text-center">
            <div className="text-2xl font-bold text-green-500">{completed}</div>
            <div className="text-xs text-neutral-gray">Completed</div>
          </div>
          
          <div className="text-center">
            <div className="text-2xl font-bold text-focus-500">{total - completed}</div>
            <div className="text-xs text-neutral-gray">Remaining</div>
          </div>
          
          <div className="text-center">
            <div className="flex items-center justify-center gap-1">
              {completed > 0 ? (
                <>
                  {Array.from({ length: 5 }, (_, i) => (
                    <Star
                      key={i}
                      size={12}
                      className={
                        i < qualityStars
                          ? 'text-achievement-500 fill-achievement-500'
                          : 'text-neutral-gray'
                      }
                    />
                  ))}
                </>
              ) : (
                <span className="text-lg font-bold text-neutral-gray">—</span>
              )}
            </div>
            <div className="text-xs text-neutral-gray">Quality</div>
          </div>
        </div>

        {/* Time and Performance Indicators */}
        {(timeElapsed || averageQuality > 0) && (
          <div className="pt-2 border-t border-neutral-gray border-opacity-20">
            <div className="flex items-center justify-between text-sm">
              {timeElapsed && (
                <div className="text-neutral-gray">
                  Time: {formatTime(timeElapsed)}
                </div>
              )}
              
              {averageQuality > 0 && (
                <div className="flex items-center gap-2">
                  <span className="text-neutral-gray">Performance:</span>
                  <QualityIndicator quality={averageQuality} />
                </div>
              )}
            </div>
          </div>
        )}

        {/* Motivation Message */}
        {completed > 0 && (
          <div className="text-center">
            <MotivationMessage 
              completed={completed} 
              total={total} 
              averageQuality={averageQuality} 
            />
          </div>
        )}
      </div>
    </Card>
  )
}

// Quality Indicator Component
interface QualityIndicatorProps {
  quality: number
}

const QualityIndicator: React.FC<QualityIndicatorProps> = ({ quality }) => {
  let color = 'text-neutral-gray'
  let label = 'Starting'

  if (quality >= 4.5) {
    color = 'text-green-500'
    label = 'Excellent'
  } else if (quality >= 3.5) {
    color = 'text-achievement-500'
    label = 'Great'
  } else if (quality >= 2.5) {
    color = 'text-yellow-500'
    label = 'Good'
  } else if (quality >= 1.5) {
    color = 'text-orange-500'
    label = 'Needs Work'
  } else if (quality > 0) {
    color = 'text-red-500'
    label = 'Challenging'
  }

  return (
    <span className={`${color} font-medium`}>
      {label} ({quality.toFixed(1)})
    </span>
  )
}

// Motivation Message Component
interface MotivationMessageProps {
  completed: number
  total: number
  averageQuality: number
}

const MotivationMessage: React.FC<MotivationMessageProps> = ({
  completed,
  total,
  averageQuality
}) => {
  const progressRatio = completed / total
  
  if (progressRatio < 0.25) {
    return (
      <div className="text-sm text-learning-600">
        🚀 Great start! You're building momentum
      </div>
    )
  }
  
  if (progressRatio < 0.5) {
    return (
      <div className="text-sm text-focus-600">
        💪 You're making excellent progress!
      </div>
    )
  }
  
  if (progressRatio < 0.75) {
    return (
      <div className="text-sm text-achievement-600">
        ⭐ More than halfway there! Keep it up
      </div>
    )
  }
  
  if (progressRatio < 1) {
    return (
      <div className="text-sm text-green-600">
        🏁 Almost finished! You've got this
      </div>
    )
  }

  // Session complete
  if (averageQuality >= 4) {
    return (
      <div className="text-sm text-green-600">
        🏆 Outstanding performance! Well done
      </div>
    )
  } else if (averageQuality >= 3) {
    return (
      <div className="text-sm text-achievement-600">
        ✨ Great job completing the session!
      </div>
    )
  } else {
    return (
      <div className="text-sm text-learning-600">
        💯 Session complete! Practice makes perfect
      </div>
    )
  }
}

// Helper function to format time
function formatTime(milliseconds: number): string {
  const seconds = Math.floor(milliseconds / 1000)
  const minutes = Math.floor(seconds / 60)
  const remainingSeconds = seconds % 60

  if (minutes > 0) {
    return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`
  }
  return `${remainingSeconds}s`
}

export default SessionProgress