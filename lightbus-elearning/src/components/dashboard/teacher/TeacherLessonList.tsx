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
  const [showDeleteModal, setShowDeleteModal] = useState(false)
  const [lessonToDelete, setLessonToDelete] = useState<LessonWithStats | null>(null)
  const [isDeleting, setIsDeleting] = useState(false)

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

  const handleDeleteClick = (lesson: LessonWithStats) => {
    setLessonToDelete(lesson)
    setShowDeleteModal(true)
  }

  const handleDeleteConfirm = async () => {
    if (!lessonToDelete) return

    setIsDeleting(true)
    try {
      const { data, error } = await supabase.rpc('delete_lesson', {
        p_lesson_id: lessonToDelete.id
      })

      if (error) throw error

      if (!data?.success) {
        throw new Error(data?.error || 'Failed to delete lesson')
      }

      // Remove the deleted lesson from the list
      setLessons(prevLessons =>
        prevLessons.filter(lesson => lesson.id !== lessonToDelete.id)
      )

      // Close modal and reset state
      setShowDeleteModal(false)
      setLessonToDelete(null)

      // Show success message (you might want to use a toast notification here)
      console.log('Lesson deleted successfully:', data.message)
    } catch (error: any) {
      console.error('Error deleting lesson:', error)
      alert(error.message || 'Failed to delete lesson')
    } finally {
      setIsDeleting(false)
    }
  }

  const handleDeleteCancel = () => {
    setShowDeleteModal(false)
    setLessonToDelete(null)
  }

  if (isLoading) {
    return (
      <Card variant="default" padding="lg" className={className}>
        <div className="animate-pulse">
          <div className="h-6 bg-neutral-gray bg-opacity-20 w-1/3 mb-4"></div>
          <div className="space-y-3">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-20 bg-neutral-gray bg-opacity-20"></div>
            ))}
          </div>
        </div>
      </Card>
    )
  }

  if (error) {
    return (
      <Card variant="default" padding="lg" className={className}>
        <h3 className="heading-4 mb-4">📖 My Lessons</h3>
        <div className="text-center py-8">
          <div className="text-4xl mb-2">⚠️</div>
          <p className="text-red-600 mb-4">{error}</p>
          <Button variant="secondary" size="sm" onClick={fetchLessons}>
            Try Again
          </Button>
        </div>
      </Card>
    )
  }

  return (
    <Card variant="default" padding="lg" className={className}>
      <div className="flex items-center justify-between mb-6">
        <h3 className="heading-4">📖 My Lessons</h3>
        <Link href="/lessons/create">
          <Button variant="primary" size="sm">
            + New Lesson
          </Button>
        </Link>
      </div>

      {lessons.length === 0 ? (
        <div className="text-center py-8 text-neutral-gray">
          <div className="text-4xl mb-2">📚</div>
          <p className="text-sm mb-2">No lessons created yet</p>
          <p className="text-xs mb-4">Create your first lesson to get started</p>
          <Link href="/lessons/create">
            <Button variant="ghost" size="sm" className="border-teacher-300 text-teacher-600 hover:bg-teacher-50">
              Create First Lesson
            </Button>
          </Link>
        </div>
      ) : (
        <div className="space-y-3">
          {lessons.map((lesson) => (
            <div
              key={lesson.id}
              className="border border-neutral-gray border-opacity-20 p-4 hover:border-teacher-300 transition-colors cursor-pointer"
            >
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <div className="flex items-center space-x-2 mb-2">
                    <h4 className="font-semibold text-neutral-charcoal">{lesson.name}</h4>
                    <span className={`text-xs px-2 py-1 bg-${getStatusColor(lesson)} bg-opacity-10 text-${getStatusColor(lesson)}`}>
                      {getStatusText(lesson)}
                    </span>
                  </div>
                  
                  {lesson.description && (
                    <p className="text-sm text-neutral-gray mb-2 line-clamp-2">
                      {lesson.description}
                    </p>
                  )}
                  
                  <div className="flex items-center space-x-4 text-xs text-neutral-gray">
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
                    <Button variant="ghost" size="sm" className="text-teacher-600 hover:bg-teacher-50">
                      Manage
                    </Button>
                  </Link>
                  
                  <Link href={`/lessons/${lesson.id}/teacher/analytics`}>
                    <Button variant="ghost" size="sm" className="text-learning-600 hover:bg-learning-50">
                      Analytics
                    </Button>
                  </Link>

                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => handleDeleteClick(lesson)}
                    className="text-red-600 hover:bg-red-50"
                    title="Delete lesson"
                  >
                    🗑️
                  </Button>
                </div>
              </div>
            </div>
          ))}
          
          {lessons.length > 3 && (
            <div className="text-center pt-4">
              <Link href="/dashboard/teacher/lessons">
                <Button variant="ghost" size="sm" className="text-teacher-600 hover:bg-teacher-50">
                  View All Lessons ({lessons.length})
                </Button>
              </Link>
            </div>
          )}
        </div>
      )}

      {/* Delete Confirmation Modal */}
      <ConfirmationModal
        isOpen={showDeleteModal}
        onClose={handleDeleteCancel}
        onConfirm={handleDeleteConfirm}
        title="Delete Lesson"
        message={
          lessonToDelete
            ? `Are you sure you want to delete "${lessonToDelete.name}"? This action cannot be undone and will remove all associated cards, student progress, and lesson data.${lessonToDelete.student_count > 0 ? ` This lesson has ${lessonToDelete.student_count} enrolled student${lessonToDelete.student_count > 1 ? 's' : ''}.` : ''}`
            : ''
        }
        confirmText="Delete Lesson"
        cancelText="Cancel"
        isLoading={isDeleting}
        variant="danger"
      />
    </Card>
  )
}