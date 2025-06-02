'use client'

import React from 'react'
import Link from 'next/link'
import { BookOpen, Calendar, Clock, Users, Play, BarChart3 } from 'lucide-react'
import Card from '@/components/ui/Card'
import Button from '@/components/ui/Button'

interface LessonProgress {
  lesson_id: string
  lesson_name: string
  teacher_name: string
  scheduled_at: string
  cards_total: number
  cards_reviewed: number
  cards_learned: number
  cards_due: number
  average_quality: number
  progress_percentage: number
  next_review_date?: string
  last_activity?: string
}

interface RecentLessonsSectionProps {
  lessons: LessonProgress[]
  isLoading?: boolean
  onStartStudy?: (lessonId: string) => void
}

const RecentLessonsSection: React.FC<RecentLessonsSectionProps> = ({
  lessons,
  isLoading = false,
  onStartStudy
}) => {
  if (isLoading) {
    return (
      <Card variant="default" padding="lg" className="animate-pulse">
        <div className="h-6 bg-neutral-gray bg-opacity-20 w-1/2 mb-4"></div>
        <div className="space-y-4">
          {[1, 2, 3].map(i => (
            <div key={i} className="h-20 bg-neutral-gray bg-opacity-20"></div>
          ))}
        </div>
      </Card>
    )
  }

  return (
    <Card variant="default" padding="lg">
      <div className="flex items-center justify-between mb-6">
        <h3 className="heading-4">📖 Recent Lessons</h3>
        <Link href="/lessons">
          <Button variant="ghost" size="sm">
            View All
          </Button>
        </Link>
      </div>

      {lessons.length === 0 ? (
        <EmptyLessonsState />
      ) : (
        <div className="space-y-4">
          {lessons.map((lesson) => (
            <LessonProgressCard
              key={lesson.lesson_id}
              lesson={lesson}
              onStartStudy={onStartStudy}
            />
          ))}
          
          {lessons.length > 3 && (
            <div className="text-center pt-4">
              <Link href="/lessons">
                <Button variant="ghost" size="sm">
                  View {lessons.length - 3} more lessons
                </Button>
              </Link>
            </div>
          )}
        </div>
      )}
    </Card>
  )
}

// Empty State Component
const EmptyLessonsState: React.FC = () => (
  <div className="text-center py-8">
    <div className="text-4xl mb-4">📚</div>
    <h4 className="font-semibold text-neutral-charcoal mb-2">No lessons yet</h4>
    <p className="text-neutral-gray text-sm mb-4">
      Ask your teacher to add you to a lesson to start learning
    </p>
    <div className="flex flex-col sm:flex-row gap-2 justify-center">
      <Button variant="ghost" size="sm">
        Browse Available Lessons
      </Button>
      <Button variant="ghost" size="sm">
        Contact Teacher
      </Button>
    </div>
  </div>
)

// Lesson Progress Card Component
interface LessonProgressCardProps {
  lesson: LessonProgress
  onStartStudy?: (lessonId: string) => void
}

const LessonProgressCard: React.FC<LessonProgressCardProps> = ({
  lesson,
  onStartStudy
}) => {
  const isActive = lesson.cards_due > 0
  const qualityColor = getQualityColor(lesson.average_quality)
  
  return (
    <div className={`p-4 border-2 transition-all hover:shadow-md ${
      isActive 
        ? 'border-learning-300 bg-learning-50' 
        : 'border-neutral-gray border-opacity-30 bg-white'
    }`}>
      {/* Header */}
      <div className="flex items-start justify-between mb-3">
        <div className="flex-1">
          <div className="flex items-center gap-2 mb-1">
            <BookOpen size={16} className="text-learning-500" />
            <h4 className="font-semibold text-neutral-charcoal truncate">
              {lesson.lesson_name}
            </h4>
            {isActive && (
              <span className="bg-learning-500 text-white px-2 py-0.5 text-xs font-bold">
                DUE
              </span>
            )}
          </div>
          
          <div className="flex items-center gap-4 text-xs text-neutral-gray">
            <span className="flex items-center gap-1">
              <Users size={12} />
              {lesson.teacher_name}
            </span>
            <span className="flex items-center gap-1">
              <Calendar size={12} />
              {formatDate(lesson.scheduled_at)}
            </span>
            {lesson.last_activity && (
              <span className="flex items-center gap-1">
                <Clock size={12} />
                Last studied {formatRelativeTime(lesson.last_activity)}
              </span>
            )}
          </div>
        </div>

        <div className="flex gap-2 ml-4">
          <Link href={`/lessons/${lesson.lesson_id}`}>
            <Button variant="ghost" size="sm" className="px-2">
              <BarChart3 size={16} />
            </Button>
          </Link>
          {isActive && (
            <Button
              variant="primary"
              size="sm"
              onClick={() => onStartStudy?.(lesson.lesson_id)}
              className="flex items-center gap-1"
            >
              <Play size={14} />
              Study
            </Button>
          )}
        </div>
      </div>

      {/* Progress Bar */}
      <div className="mb-3">
        <div className="flex items-center justify-between text-xs mb-1">
          <span className="text-neutral-gray">Progress</span>
          <span className="font-medium text-neutral-charcoal">
            {lesson.progress_percentage.toFixed(0)}%
          </span>
        </div>
        <div className="w-full bg-neutral-gray bg-opacity-20 h-2">
          <div 
            className="bg-learning-500 h-2 transition-all duration-300"
            style={{ width: `${lesson.progress_percentage}%` }}
          ></div>
        </div>
      </div>

      {/* Statistics Grid */}
      <div className="grid grid-cols-4 gap-3 text-center">
        <div className="space-y-1">
          <div className="text-lg font-bold text-neutral-charcoal">
            {lesson.cards_total}
          </div>
          <div className="text-xs text-neutral-gray">Total</div>
        </div>
        
        <div className="space-y-1">
          <div className="text-lg font-bold text-focus-500">
            {lesson.cards_learned}
          </div>
          <div className="text-xs text-neutral-gray">Learned</div>
        </div>
        
        <div className="space-y-1">
          <div className={`text-lg font-bold ${
            lesson.cards_due > 0 ? 'text-learning-500' : 'text-green-500'
          }`}>
            {lesson.cards_due}
          </div>
          <div className="text-xs text-neutral-gray">Due</div>
        </div>
        
        <div className="space-y-1">
          <div className={`text-lg font-bold ${qualityColor}`}>
            {lesson.average_quality > 0 ? lesson.average_quality.toFixed(1) : '—'}
          </div>
          <div className="text-xs text-neutral-gray">Quality</div>
        </div>
      </div>

      {/* Next Review Info */}
      {lesson.next_review_date && lesson.cards_due > 0 && (
        <div className="mt-3 pt-3 border-t border-neutral-gray border-opacity-20">
          <div className="flex items-center justify-between text-xs">
            <span className="text-neutral-gray">Next review:</span>
            <span className="text-learning-600 font-medium">
              {formatRelativeDate(lesson.next_review_date)}
            </span>
          </div>
        </div>
      )}

      {/* Achievement Indicators */}
      {lesson.progress_percentage === 100 && (
        <div className="mt-3 pt-3 border-t border-green-200">
          <div className="flex items-center gap-2 text-green-600">
            <span className="text-sm">🏆</span>
            <span className="text-xs font-medium">Lesson completed!</span>
          </div>
        </div>
      )}
      
      {lesson.average_quality >= 4.5 && lesson.cards_reviewed > 5 && (
        <div className="mt-3 pt-3 border-t border-achievement-200">
          <div className="flex items-center gap-2 text-achievement-600">
            <span className="text-sm">⭐</span>
            <span className="text-xs font-medium">Excellent performance!</span>
          </div>
        </div>
      )}
    </div>
  )
}

// Helper Functions
function formatDate(dateString: string): string {
  const date = new Date(dateString)
  return date.toLocaleDateString('en-US', { 
    month: 'short', 
    day: 'numeric' 
  })
}

function formatRelativeTime(dateString: string): string {
  const date = new Date(dateString)
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24))

  if (diffDays === 0) return 'today'
  if (diffDays === 1) return 'yesterday'
  if (diffDays < 7) return `${diffDays} days ago`
  if (diffDays < 30) return `${Math.floor(diffDays / 7)} weeks ago`
  return `${Math.floor(diffDays / 30)} months ago`
}

function formatRelativeDate(dateString: string): string {
  const date = new Date(dateString)
  const today = new Date()
  const tomorrow = new Date(today)
  tomorrow.setDate(tomorrow.getDate() + 1)

  if (date.toDateString() === today.toDateString()) {
    return 'Today'
  } else if (date.toDateString() === tomorrow.toDateString()) {
    return 'Tomorrow'
  } else {
    const diffMs = date.getTime() - today.getTime()
    const diffDays = Math.ceil(diffMs / (1000 * 60 * 60 * 24))
    
    if (diffDays < 7) {
      return `In ${diffDays} days`
    } else {
      return date.toLocaleDateString('en-US', { 
        month: 'short', 
        day: 'numeric' 
      })
    }
  }
}

function getQualityColor(quality: number): string {
  if (quality >= 4.5) return 'text-green-500'
  if (quality >= 3.5) return 'text-achievement-500'
  if (quality >= 2.5) return 'text-yellow-500'
  if (quality >= 1.5) return 'text-orange-500'
  if (quality > 0) return 'text-red-500'
  return 'text-neutral-gray'
}

export default RecentLessonsSection