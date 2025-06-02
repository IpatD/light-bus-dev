'use client'

import React, { useState, useEffect } from 'react'
import Link from 'next/link'
import { supabase } from '@/lib/supabase'
import { Lesson } from '@/types'
import Button from '@/components/ui/Button'
import Card from '@/components/ui/Card'
import ConfirmationModal from '@/components/ui/ConfirmationModal'

interface TeacherLessonListProps {
  className?: string
}

interface LessonWithStats extends Lesson {
  student_count: number
  card_count: number
  pending_cards: number
}

export default function TeacherLessonList({ className = '' }: TeacherLessonListProps) {
  const [lessons, setLessons] = useState<LessonWithStats[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    fetchLessons()
  }, [])

  const fetchLessons = async () => {
    try {
      setIsLoading(true)
      setError(null)
      
      const { data, error: rpcError } = await supabase.rpc('get_teacher_lessons')
      
      if (rpcError) throw rpcError
      
      if (data?.success) {
        setLessons(data.data || [])
      } else {
        throw new Error(data?.error || 'Failed to fetch lessons')
      }
    } catch (err: any) {
      console.error('Error fetching lessons:', err)
      setError(err.message || 'Failed to load lessons')
    } finally {
      setIsLoading(false)
    }
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      weekday: 'short',
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    })
  }

  const getStatusColor = (lesson: LessonWithStats) => {
    if (lesson.pending_cards > 0) return 'focus-500'
    if (lesson.student_count === 0) return 'neutral-400'
    return 'achievement-500'
  }

  const getStatusText = (lesson: LessonWithStats) => {
    if (lesson.pending_cards > 0) return `${lesson.pending_cards} pending`
    if (lesson.student_count === 0) return 'No students'
    return 'Active'
  }


  if (isLoading) {
    return (
      <div className={className}>
        <div className="animate-pulse">
          <div className="h-6 bg-gray-200 w-1/3 mb-4"></div>
          <div className="space-y-3">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-20 bg-gray-200"></div>
            ))}
          </div>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className={className}>
        <div className="text-center py-8">
          <div className="text-4xl mb-2">⚠️</div>
          <p className="text-red-600 mb-4">{error}</p>
          <Button
            variant="secondary"
            size="sm"
            onClick={fetchLessons}
            className="bg-white border-2 border-black text-gray-800 hover:bg-orange-100"
          >
            Try Again
          </Button>
        </div>
      </div>
    )
  }

  return (
    <div className={className}>
      <div className="flex items-center justify-between mb-6">
        <Link href="/lessons/create">
          <Button
            variant="primary"
            size="sm"
            className="bg-white border-2 border-black text-gray-800 hover:bg-orange-100"
          >
            + New Lesson
          </Button>
        </Link>
      </div>

      {lessons.length === 0 ? (
        <div className="text-center py-8 text-gray-600">
          <div className="text-4xl mb-2">📚</div>
          <p className="text-sm mb-2">No lessons created yet</p>
          <p className="text-xs mb-4">Create your first lesson to get started</p>
          <Link href="/lessons/create">
            <Button
              variant="ghost"
              size="sm"
              className="bg-white border-2 border-black text-gray-800 hover:bg-orange-100"
            >
              Create First Lesson
            </Button>
          </Link>
        </div>
      ) : (
        <div className="space-y-3">
          {lessons.map((lesson) => (
            <div
              key={lesson.id}
              className="border-2 border-black p-4 bg-white hover:bg-orange-50 transition-colors cursor-pointer"
            >
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <div className="flex items-center space-x-2 mb-2">
                    <h4 className="font-semibold text-gray-800">{lesson.name}</h4>
                    <span
                      className="text-xs px-2 py-1 bg-orange-100 border border-black text-gray-800"
                      style={{ color: '#ff6b35' }}
                    >
                      {getStatusText(lesson)}
                    </span>
                  </div>
                  
                  {lesson.description && (
                    <p className="text-sm text-gray-600 mb-2 line-clamp-2">
                      {lesson.description}
                    </p>
                  )}
                  
                  <div className="flex items-center space-x-4 text-xs text-gray-600">
                    <span>📅 {formatDate(lesson.scheduled_at)}</span>
                    <span>👥 {lesson.student_count} students</span>
                    <span>📝 {lesson.card_count} cards</span>
                    {lesson.duration_minutes && (
                      <span>⏱️ {lesson.duration_minutes}min</span>
                    )}
                  </div>
                </div>
                
                <div className="flex items-center space-x-2 ml-4">
                  <Link href={`/lessons/${lesson.id}/teacher`}>
                    <Button
                      variant="ghost"
                      size="sm"
                      className="bg-white border-2 border-black text-gray-800 hover:bg-orange-100"
                    >
                      Manage
                    </Button>
                  </Link>
                  
                  <Link href={`/lessons/${lesson.id}/teacher/analytics`}>
                    <Button
                      variant="ghost"
                      size="sm"
                      className="bg-white border-2 border-black text-gray-800 hover:bg-orange-100"
                    >
                      Analytics
                    </Button>
                  </Link>

                </div>
              </div>
            </div>
          ))}
          
          {lessons.length > 3 && (
            <div className="text-center pt-4">
              <Link href="/dashboard/teacher/lessons">
                <Button
                  variant="ghost"
                  size="sm"
                  className="bg-white border-2 border-black text-gray-800 hover:bg-orange-100"
                >
                  View All Lessons ({lessons.length})
                </Button>
              </Link>
            </div>
          )}
        </div>
      )}

    </div>
  )
}