'use client'

import React, { useState, useEffect } from 'react'
import { useParams, useRouter } from 'next/navigation'
import Link from 'next/link'
import { supabase } from '@/lib/supabase'
import { Lesson, SRCard } from '@/types'
import Button from '@/components/ui/Button'
import Card from '@/components/ui/Card'
import Input from '@/components/ui/Input'
import Modal from '@/components/ui/Modal'
import ConfirmationModal from '@/components/ui/ConfirmationModal'

interface LessonParticipant {
  student_id: string
  student_name: string
  student_email: string
  enrolled_at: string
}

interface LessonDetailData {
  lesson: Lesson
  participants: LessonParticipant[]
  cards: SRCard[]
  pending_cards: SRCard[]
}

export default function TeacherLessonDetailPage() {
  const params = useParams()
  const router = useRouter()
  const lessonId = params.lesson_id as string

  const [lessonData, setLessonData] = useState<LessonDetailData | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [showAddStudent, setShowAddStudent] = useState(false)
  const [newStudentEmail, setNewStudentEmail] = useState('')
  const [isAddingStudent, setIsAddingStudent] = useState(false)
  const [showDeleteModal, setShowDeleteModal] = useState(false)
  const [isDeleting, setIsDeleting] = useState(false)
  const [showDeleteCardModal, setShowDeleteCardModal] = useState(false)
  const [cardToDelete, setCardToDelete] = useState<string | null>(null)
  const [isDeletingCard, setIsDeletingCard] = useState(false)

  useEffect(() => {
    if (lessonId) {
      fetchLessonData()
    }
  }, [lessonId])

  const fetchLessonData = async () => {
    try {
      setIsLoading(true)
      setError(null)

      // Get lesson analytics which includes lesson details and participants
      const { data: analyticsData, error: analyticsError } = await supabase.rpc('get_lesson_analytics', {
        p_lesson_id: lessonId
      })

      if (analyticsError) throw analyticsError

      if (!analyticsData?.success) {
        throw new Error(analyticsData?.error || 'Failed to fetch lesson data')
      }

      // Get lesson basic info
      const { data: lessons, error: lessonError } = await supabase
        .from('lessons')
        .select('*')
        .eq('id', lessonId)
        .single()

      if (lessonError) throw lessonError

      // Get cards for this lesson
      const { data: cards, error: cardsError } = await supabase
        .from('sr_cards')
        .select('*')
        .eq('lesson_id', lessonId)
        .order('created_at', { ascending: false })

      if (cardsError) throw cardsError

      const approvedCards = cards?.filter(card => card.status === 'approved') || []
      const pendingCards = cards?.filter(card => card.status === 'pending') || []

      setLessonData({
        lesson: lessons,
        participants: analyticsData.data.student_progress || [],
        cards: approvedCards,
        pending_cards: pendingCards
      })
    } catch (err: any) {
      console.error('Error fetching lesson data:', err)
      setError(err.message || 'Failed to load lesson data')
    } finally {
      setIsLoading(false)
    }
  }

  const handleAddStudent = async () => {
    if (!newStudentEmail.trim()) return

    setIsAddingStudent(true)
    try {
      const { data, error } = await supabase.rpc('add_lesson_participant', {
        p_lesson_id: lessonId,
        p_student_email: newStudentEmail.trim()
      })

      if (error) throw error

      if (!data?.success) {
        throw new Error(data?.error || 'Failed to add student')
      }

      // Refresh lesson data
      await fetchLessonData()
      setNewStudentEmail('')
      setShowAddStudent(false)
    } catch (error: any) {
      console.error('Error adding student:', error)
      alert(error.message || 'Failed to add student')
    } finally {
      setIsAddingStudent(false)
    }
  }

  const handleRemoveStudent = async (studentId: string) => {
    if (!confirm('Are you sure you want to remove this student from the lesson?')) {
      return
    }

    try {
      const { data, error } = await supabase.rpc('remove_lesson_participant', {
        p_lesson_id: lessonId,
        p_student_id: studentId
      })

      if (error) throw error

      if (!data?.success) {
        throw new Error(data?.error || 'Failed to remove student')
      }

      // Refresh lesson data
      await fetchLessonData()
    } catch (error: any) {
      console.error('Error removing student:', error)
      alert(error.message || 'Failed to remove student')
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

  const handleDeleteLesson = async () => {
    if (!lessonData?.lesson) return

    setIsDeleting(true)
    try {
      const { data, error } = await supabase.rpc('delete_lesson', {
        p_lesson_id: lessonId
      })

      if (error) throw error

      if (!data?.success) {
        throw new Error(data?.error || 'Failed to delete lesson')
      }

      // Redirect to teacher dashboard after successful deletion
      router.push('/dashboard/teacher')
    } catch (error: any) {
      console.error('Error deleting lesson:', error)
      alert(error.message || 'Failed to delete lesson')
    } finally {
      setIsDeleting(false)
      setShowDeleteModal(false)
    }
  }

  const handleDeleteCard = async () => {
    if (!cardToDelete) return

    setIsDeletingCard(true)
    try {
      const { data, error } = await supabase.rpc('delete_sr_card', {
        p_card_id: cardToDelete
      })

      if (error) throw error

      // The function returns a table, so data is an array
      const result = data && data[0]
      if (!result?.success) {
        throw new Error(result?.error || 'Failed to delete card')
      }

      // Refresh lesson data to show updated card list
      await fetchLessonData()
      
      // Show success message
      alert(result.message || 'Card deleted successfully')
    } catch (error: any) {
      console.error('Error deleting card:', error)
      alert(error.message || 'Failed to delete card')
    } finally {
      setIsDeletingCard(false)
      setShowDeleteCardModal(false)
      setCardToDelete(null)
    }
  }

  const handleDeleteCardClick = (cardId: string) => {
    setCardToDelete(cardId)
    setShowDeleteCardModal(true)
  }

  if (isLoading) {
    return (
      <div className="min-h-screen bg-neutral-white">
        <div className="container-main py-8">
          <div className="animate-pulse">
            <div className="h-8 bg-neutral-gray bg-opacity-20 w-1/3 mb-6"></div>
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
              <div className="lg:col-span-2 space-y-6">
                {[1, 2].map((i) => (
                  <div key={i} className="h-64 bg-neutral-gray bg-opacity-20"></div>
                ))}
              </div>
              <div className="space-y-6">
                {[1, 2].map((i) => (
                  <div key={i} className="h-48 bg-neutral-gray bg-opacity-20"></div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    )
  }

  if (error || !lessonData) {
    return (
      <div className="min-h-screen bg-neutral-white">
        <div className="container-main py-8">
          <Card variant="default" padding="lg" className="text-center">
            <div className="text-4xl mb-4">⚠️</div>
            <h2 className="heading-3 mb-4">Error Loading Lesson</h2>
            <p className="text-neutral-gray mb-6">{error || 'Lesson not found'}</p>
            <div className="space-x-4">
              <Button variant="secondary" onClick={() => router.back()}>
                Go Back
              </Button>
              <Button variant="primary" onClick={fetchLessonData}>
                Try Again
              </Button>
            </div>
          </Card>
        </div>
      </div>
    )
  }

  const { lesson, participants, cards, pending_cards } = lessonData

  return (
    <div className="min-h-screen bg-neutral-white">
      <div className="container-main py-8">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center justify-between mb-4">
            <div>
              <nav className="text-sm text-neutral-gray mb-2">
                <Link href="/dashboard/teacher" className="hover:text-teacher-600">Dashboard</Link>
                <span className="mx-2">→</span>
                <span>Lesson Management</span>
              </nav>
              <h1 className="heading-2">{lesson.name}</h1>
              {lesson.description && (
                <p className="text-neutral-gray mt-2">{lesson.description}</p>
              )}
            </div>
            <div className="space-x-3">
              <Link href={`/lessons/${lessonId}/teacher/analytics`}>
                <Button variant="ghost" className="text-learning-600 hover:bg-learning-50">
                  📊 Analytics
                </Button>
              </Link>
              <Link href={`/cards/create?lesson_id=${lessonId}`}>
                <Button variant="primary">
                  + Add Cards
                </Button>
              </Link>
            </div>
          </div>

          <div className="flex items-center space-x-6 text-sm text-neutral-gray">
            <span>📅 {formatDate(lesson.scheduled_at)}</span>
            <span>👥 {participants.length} students</span>
            <span>📝 {cards.length} cards</span>
            {pending_cards.length > 0 && (
              <span className="text-focus-600">⏳ {pending_cards.length} pending</span>
            )}
            {lesson.duration_minutes && (
              <span>⏱️ {lesson.duration_minutes}min</span>
            )}
          </div>
        </div>

        {/* Main Content */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Left Column */}
          <div className="lg:col-span-2 space-y-8">
            {/* Students */}
            <Card variant="default" padding="lg">
              <div className="flex items-center justify-between mb-6">
                <h2 className="heading-3">👥 Students ({participants.length})</h2>
                <Button 
                  variant="secondary" 
                  size="sm"
                  onClick={() => setShowAddStudent(true)}
                >
                  + Add Student
                </Button>
              </div>

              {participants.length === 0 ? (
                <div className="text-center py-8 text-neutral-gray">
                  <div className="text-4xl mb-2">👤</div>
                  <p className="text-sm mb-2">No students enrolled yet</p>
                  <p className="text-xs mb-4">Add students to start tracking their progress</p>
                  <Button 
                    variant="ghost" 
                    size="sm" 
                    onClick={() => setShowAddStudent(true)}
                    className="border-teacher-300 text-teacher-600 hover:bg-teacher-50"
                  >
                    Add First Student
                  </Button>
                </div>
              ) : (
                <div className="space-y-3">
                  {participants.map((participant) => (
                    <div
                      key={participant.student_id}
                      className="flex items-center justify-between p-4 border border-neutral-gray border-opacity-20 hover:border-teacher-300 transition-colors"
                    >
                      <div>
                        <div className="font-medium text-neutral-charcoal">
                          {participant.student_name}
                        </div>
                        <div className="text-sm text-neutral-gray">
                          {participant.student_email}
                        </div>
                      </div>
                      <div className="flex items-center space-x-3">
                        <div className="text-sm text-neutral-gray">
                          Enrolled {new Date(participant.enrolled_at).toLocaleDateString()}
                        </div>
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleRemoveStudent(participant.student_id)}
                          className="text-red-600 hover:bg-red-50"
                        >
                          Remove
                        </Button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </Card>

            {/* Flashcards */}
            <Card variant="default" padding="lg" data-cards-section>
              <div className="flex items-center justify-between mb-6">
                <h2 className="heading-3">📝 Flashcards ({cards.length})</h2>
                <div className="space-x-2">
                  <Link href={`/cards/import?lesson_id=${lessonId}`}>
                    <Button variant="ghost" size="sm">
                      📋 Import
                    </Button>
                  </Link>
                  <Link href={`/cards/create?lesson_id=${lessonId}`}>
                    <Button variant="primary" size="sm">
                      + Create Card
                    </Button>
                  </Link>
                </div>
              </div>

              {cards.length === 0 ? (
                <div className="text-center py-8 text-neutral-gray">
                  <div className="text-4xl mb-2">📝</div>
                  <p className="text-sm mb-2">No flashcards created yet</p>
                  <p className="text-xs mb-4">Create flashcards for students to study</p>
                  <Link href={`/cards/create?lesson_id=${lessonId}`}>
                    <Button variant="ghost" size="sm" className="border-focus-300 text-focus-600 hover:bg-focus-50">
                      Create First Card
                    </Button>
                  </Link>
                </div>
              ) : (
                <div className="space-y-3">
                  {cards.slice(0, 5).map((card) => (
                    <div
                      key={card.id}
                      className="p-4 border border-neutral-gray border-opacity-20 hover:border-focus-300 transition-colors"
                    >
                      <div className="flex items-start justify-between">
                        <div className="flex-1">
                          <div className="text-sm font-medium text-neutral-charcoal mb-1">
                            {card.front_content}
                          </div>
                          <div className="text-sm text-neutral-gray">
                            {card.back_content}
                          </div>
                          <div className="flex items-center space-x-2 mt-2">
                            <span className="text-xs px-2 py-1 bg-learning-100 text-learning-600">
                              {card.card_type}
                            </span>
                            <span className="text-xs px-2 py-1 bg-focus-100 text-focus-600">
                              Level {card.difficulty_level}
                            </span>
                            {card.tags && card.tags.length > 0 && (
                              <span className="text-xs text-neutral-gray">
                                {card.tags.join(', ')}
                              </span>
                            )}
                          </div>
                        </div>
                        <div className="flex items-center gap-2">
                          <Button variant="ghost" size="sm" className="text-neutral-gray hover:text-neutral-charcoal">
                            Edit
                          </Button>
                          <Button
                            variant="ghost"
                            size="sm"
                            className="text-red-500 hover:text-red-700 hover:bg-red-50"
                            onClick={() => handleDeleteCardClick(card.id)}
                          >
                            Delete
                          </Button>
                        </div>
                      </div>
                    </div>
                  ))}
                  
                  {cards.length > 5 && (
                    <div className="text-center pt-4">
                      <Link href={`/lessons/${lessonId}/cards`}>
                        <Button
                          variant="ghost"
                          size="sm"
                          className="text-focus-600 hover:bg-focus-50"
                        >
                          View All Cards ({cards.length})
                        </Button>
                      </Link>
                    </div>
                  )}
                </div>
              )}
            </Card>
          </div>

          {/* Right Column */}
          <div className="space-y-6">
            {/* Quick Actions */}
            <Card variant="default" padding="lg">
              <h3 className="heading-4 mb-4">🚀 Quick Actions</h3>
              <div className="space-y-3">
                <Link href={`/cards/create?lesson_id=${lessonId}`}>
                  <Button variant="ghost" className="w-full justify-start text-left">
                    📝 Create Flashcard
                  </Button>
                </Link>
                <Link href={`/cards/import?lesson_id=${lessonId}`}>
                  <Button variant="ghost" className="w-full justify-start text-left">
                    📋 Import Cards
                  </Button>
                </Link>
                <Button 
                  variant="ghost" 
                  className="w-full justify-start text-left"
                  onClick={() => setShowAddStudent(true)}
                >
                  👥 Add Student
                </Button>
                <Link href={`/lessons/${lessonId}/teacher/analytics`}>
                  <Button variant="ghost" className="w-full justify-start text-left">
                    📊 View Analytics
                  </Button>
                </Link>
              </div>
            </Card>

            {/* Pending Cards */}
            {pending_cards.length > 0 && (
              <Card variant="default" padding="lg">
                <h3 className="heading-4 mb-4">⏳ Pending Approval ({pending_cards.length})</h3>
                <div className="space-y-3">
                  {pending_cards.slice(0, 3).map((card) => (
                    <div
                      key={card.id}
                      className="p-3 bg-focus-50 border border-focus-200"
                    >
                      <div className="text-sm font-medium mb-1 line-clamp-1">
                        {card.front_content}
                      </div>
                      <div className="text-xs text-neutral-gray line-clamp-1 mb-2">
                        {card.back_content}
                      </div>
                      <div className="flex items-center space-x-2">
                        <Button variant="ghost" size="sm" className="text-achievement-600 hover:bg-achievement-50">
                          Approve
                        </Button>
                        <Button variant="ghost" size="sm" className="text-red-600 hover:bg-red-50">
                          Reject
                        </Button>
                      </div>
                    </div>
                  ))}
                  {pending_cards.length > 3 && (
                    <Link href={`/cards/approve?lesson_id=${lessonId}`}>
                      <Button variant="ghost" size="sm" className="w-full text-focus-600 hover:bg-focus-50">
                        View All Pending ({pending_cards.length})
                      </Button>
                    </Link>
                  )}
                </div>
              </Card>
            )}

            {/* Lesson Stats */}
            <Card variant="default" padding="lg">
              <h3 className="heading-4 mb-4">📈 Lesson Stats</h3>
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-sm text-neutral-gray">Total Students</span>
                  <span className="font-medium">{participants.length}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-sm text-neutral-gray">Active Cards</span>
                  <span className="font-medium">{cards.length}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-sm text-neutral-gray">Pending Cards</span>
                  <span className="font-medium">{pending_cards.length}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-sm text-neutral-gray">Created</span>
                  <span className="font-medium">{new Date(lesson.created_at).toLocaleDateString()}</span>
                </div>
              </div>
            </Card>
          </div>
        </div>

        {/* Danger Zone - Delete Section */}
        <div className="mt-12 pt-8 border-t border-neutral-gray border-opacity-20">
          <Card variant="default" padding="lg" className="border-red-200 bg-red-50">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="heading-4 text-red-800 mb-2">⚠️ Danger Zone</h3>
                <p className="text-sm text-red-600 mb-1">
                  Delete this lesson permanently
                </p>
                <p className="text-xs text-red-500">
                  This action cannot be undone. All associated cards, student progress, and lesson data will be removed.
                  {participants.length > 0 && (
                    <span className="block mt-1">
                      <strong>Warning:</strong> This lesson has {participants.length} enrolled student{participants.length > 1 ? 's' : ''}.
                    </span>
                  )}
                </p>
              </div>
              <Button
                variant="ghost"
                onClick={() => setShowDeleteModal(true)}
                className="text-red-700 border-red-300 hover:bg-red-100 hover:border-red-400 font-medium"
              >
                🗑️ Delete Lesson
              </Button>
            </div>
          </Card>
        </div>

        {/* Add Student Modal */}
        <Modal
          isOpen={showAddStudent}
          onClose={() => setShowAddStudent(false)}
          title="Add Student to Lesson"
          size="md"
        >
          <div className="space-y-4">
            <Input
              type="email"
              label="Student Email"
              placeholder="student@example.com"
              value={newStudentEmail}
              onChange={(e) => setNewStudentEmail(e.target.value)}
              required
            />
            <div className="flex items-center justify-end space-x-3">
              <Button 
                variant="ghost" 
                onClick={() => setShowAddStudent(false)}
                disabled={isAddingStudent}
              >
                Cancel
              </Button>
              <Button 
                variant="primary" 
                onClick={handleAddStudent}
                disabled={isAddingStudent || !newStudentEmail.trim()}
                loading={isAddingStudent}
              >
                {isAddingStudent ? 'Adding...' : 'Add Student'}
              </Button>
            </div>
          </div>
        </Modal>

        {/* Delete Confirmation Modal */}
        <ConfirmationModal
          isOpen={showDeleteModal}
          onClose={() => setShowDeleteModal(false)}
          onConfirm={handleDeleteLesson}
          title="Delete Lesson"
          message={
            lessonData?.lesson
              ? `Are you sure you want to delete "${lessonData.lesson.name}"? This action cannot be undone and will remove all associated cards, student progress, and lesson data.${participants.length > 0 ? ` This lesson has ${participants.length} enrolled student${participants.length > 1 ? 's' : ''}.` : ''}`
              : 'Are you sure you want to delete this lesson?'
          }
          confirmText="Delete Lesson"
          cancelText="Cancel"
          isLoading={isDeleting}
          variant="danger"
        />

        {/* Card Delete Modal */}
        <ConfirmationModal
          isOpen={showDeleteCardModal}
          onClose={() => {
            setShowDeleteCardModal(false)
            setCardToDelete(null)
          }}
          onConfirm={handleDeleteCard}
          title="Delete Flashcard"
          message="Are you sure you want to delete this flashcard? This action cannot be undone and will remove the card from all student study sessions."
          confirmText="Delete Card"
          cancelText="Cancel"
          isLoading={isDeletingCard}
          variant="danger"
        />
      </div>
    </div>
  )
}