'use client'

import React from 'react'
import Link from 'next/link'
import { Clock, AlertCircle, CheckCircle2, Play } from 'lucide-react'
import Card from '@/components/ui/Card'
import Button from '@/components/ui/Button'

interface DueCard {
  id: string
  lesson_id: string
  lesson_name: string
  front_content: string
  difficulty_level: number
  scheduled_for: string
  is_overdue: boolean
}

interface DueCardsSectionProps {
  cards: DueCard[]
  totalDue: number
  isLoading?: boolean
  onStartSession?: (lessonId?: string) => void
}

const DueCardsSection: React.FC<DueCardsSectionProps> = ({
  cards,
  totalDue,
  isLoading = false,
  onStartSession
}) => {
  // Group cards by lesson
  const cardsByLesson = cards.reduce((acc, card) => {
    if (!acc[card.lesson_id]) {
      acc[card.lesson_id] = {
        lesson_name: card.lesson_name,
        cards: []
      }
    }
    acc[card.lesson_id].cards.push(card)
    return acc
  }, {} as Record<string, { lesson_name: string; cards: DueCard[] }>)

  const overdueCount = cards.filter(card => card.is_overdue).length
  const urgencyLevel = getUrgencyLevel(totalDue, overdueCount)

  if (isLoading) {
    return (
      <Card variant="default" padding="lg" className="animate-pulse">
        <div className="h-6 bg-neutral-gray bg-opacity-20 w-1/3 mb-4"></div>
        <div className="space-y-3">
          {[1, 2, 3].map(i => (
            <div key={i} className="h-12 bg-neutral-gray bg-opacity-20"></div>
          ))}
        </div>
      </Card>
    )
  }

  return (
    <Card variant="default" padding="lg">
      {/* Header with urgency indicator */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <h2 className="heading-3">📚 Due for Review</h2>
          <UrgencyBadge level={urgencyLevel} count={totalDue} overdueCount={overdueCount} />
        </div>
        
        {totalDue > 0 && (
          <Button
            variant="primary"
            size="sm"
            onClick={() => onStartSession?.()}
            className="flex items-center gap-2"
          >
            <Play size={16} />
            Start Session
          </Button>
        )}
      </div>

      {/* No cards due state */}
      {totalDue === 0 ? (
        <div className="text-center py-12">
          <div className="text-6xl mb-4">🎉</div>
          <h3 className="heading-4 mb-2">All caught up!</h3>
          <p className="text-neutral-gray mb-6">
            You've completed all your reviews for now. Great job!
          </p>
          <div className="flex flex-col sm:flex-row gap-3 justify-center">
            <Button variant="ghost" size="md">
              Explore New Lessons
            </Button>
            <Button variant="ghost" size="md">
              Review Past Sessions
            </Button>
          </div>
        </div>
      ) : (
        <>
          {/* Quick stats */}
          <div className="grid grid-cols-3 gap-4 mb-6 p-4 bg-learning-50 border-l-4 border-learning-500">
            <div className="text-center">
              <div className="text-2xl font-bold text-learning-600">{totalDue}</div>
              <div className="text-xs text-learning-700">Total Due</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-red-600">{overdueCount}</div>
              <div className="text-xs text-red-700">Overdue</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-green-600">{totalDue - overdueCount}</div>
              <div className="text-xs text-green-700">On Time</div>
            </div>
          </div>

          {/* Cards grouped by lesson */}
          <div className="space-y-4">
            {Object.entries(cardsByLesson).map(([lessonId, lessonData]) => (
              <LessonCardGroup
                key={lessonId}
                lessonId={lessonId}
                lessonName={lessonData.lesson_name}
                cards={lessonData.cards}
                onStartSession={onStartSession}
              />
            ))}
          </div>

          {/* Study session CTA */}
          <div className="mt-6 pt-6 border-t border-neutral-gray border-opacity-20">
            <div className="bg-gradient-to-r from-learning-500 to-focus-500 text-white p-6">
              <h4 className="font-bold text-lg mb-2">Ready to boost your learning?</h4>
              <p className="text-white text-opacity-90 mb-4">
                Consistent daily practice is the key to long-term retention. Let's tackle these cards!
              </p>
              <Button
                variant="accent"
                size="lg"
                onClick={() => onStartSession?.()}
                className="w-full sm:w-auto"
              >
                Start Study Session ({totalDue} cards)
              </Button>
            </div>
          </div>
        </>
      )}
    </Card>
  )
}

// Urgency Badge Component
interface UrgencyBadgeProps {
  level: 'low' | 'medium' | 'high' | 'critical'
  count: number
  overdueCount: number
}

const UrgencyBadge: React.FC<UrgencyBadgeProps> = ({ level, count, overdueCount }) => {
  const config = {
    low: { 
      bg: 'bg-green-100', 
      text: 'text-green-700', 
      icon: CheckCircle2,
      label: 'On Track' 
    },
    medium: { 
      bg: 'bg-yellow-100', 
      text: 'text-yellow-700', 
      icon: Clock,
      label: 'Due Soon' 
    },
    high: { 
      bg: 'bg-orange-100', 
      text: 'text-orange-700', 
      icon: AlertCircle,
      label: 'Attention Needed' 
    },
    critical: { 
      bg: 'bg-red-100', 
      text: 'text-red-700', 
      icon: AlertCircle,
      label: 'Overdue!' 
    }
  }

  const { bg, text, icon: Icon, label } = config[level]

  return (
    <div className={`${bg} ${text} px-3 py-1 flex items-center gap-2 text-sm font-semibold`}>
      <Icon size={16} />
      <span>{label}</span>
      {overdueCount > 0 && (
        <span className="bg-red-500 text-white px-2 py-0.5 text-xs font-bold">
          {overdueCount}
        </span>
      )}
    </div>
  )
}

// Lesson Card Group Component
interface LessonCardGroupProps {
  lessonId: string
  lessonName: string
  cards: DueCard[]
  onStartSession?: (lessonId?: string) => void
}

const LessonCardGroup: React.FC<LessonCardGroupProps> = ({
  lessonId,
  lessonName,
  cards,
  onStartSession
}) => {
  const overdueCards = cards.filter(card => card.is_overdue)
  const averageDifficulty = cards.reduce((sum, card) => sum + card.difficulty_level, 0) / cards.length

  return (
    <div className="border border-neutral-gray border-opacity-30 p-4">
      <div className="flex items-center justify-between mb-3">
        <div>
          <h4 className="font-semibold text-neutral-charcoal">{lessonName}</h4>
          <div className="flex items-center gap-4 text-sm text-neutral-gray">
            <span>{cards.length} cards due</span>
            {overdueCards.length > 0 && (
              <span className="text-red-600 font-medium">
                {overdueCards.length} overdue
              </span>
            )}
            <span>Avg. difficulty: {averageDifficulty.toFixed(1)}/5</span>
          </div>
        </div>
        <div className="flex gap-2">
          <Link href={`/study/${lessonId}`}>
            <Button variant="ghost" size="sm">
              Study Lesson
            </Button>
          </Link>
          <Button
            variant="primary"
            size="sm"
            onClick={() => onStartSession?.(lessonId)}
          >
            Start
          </Button>
        </div>
      </div>

      {/* Show preview of first few cards */}
      <div className="space-y-2">
        {cards.slice(0, 3).map((card) => (
          <div
            key={card.id}
            className={`p-3 bg-neutral-gray bg-opacity-5 text-sm flex items-center justify-between ${
              card.is_overdue ? 'border-l-4 border-red-500' : ''
            }`}
          >
            <span className="truncate flex-1 mr-4">{card.front_content}</span>
            <div className="flex items-center gap-2 text-xs text-neutral-gray">
              <span>Difficulty {card.difficulty_level}/5</span>
              {card.is_overdue && (
                <span className="text-red-600 font-medium">Overdue</span>
              )}
            </div>
          </div>
        ))}
        {cards.length > 3 && (
          <div className="text-xs text-neutral-gray text-center py-2">
            +{cards.length - 3} more cards
          </div>
        )}
      </div>
    </div>
  )
}

// Helper function to determine urgency level
function getUrgencyLevel(totalDue: number, overdueCount: number): 'low' | 'medium' | 'high' | 'critical' {
  if (overdueCount > 5) return 'critical'
  if (overdueCount > 0) return 'high'
  if (totalDue > 10) return 'medium'
  return 'low'
}

export default DueCardsSection