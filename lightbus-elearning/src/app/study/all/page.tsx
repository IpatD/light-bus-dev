'use client'

import React, { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabase'
import { SRCard, StudyCardReview, QualityRating } from '@/types'
import EnhancedFlashcard from '@/components/study/EnhancedFlashcard'
import SessionProgress from '@/components/study/SessionProgress'
import SessionComplete from '@/components/study/SessionComplete'
import Card from '@/components/ui/Card'
import Button from '@/components/ui/Button'
import { ArrowLeft, Pause, RotateCcw } from 'lucide-react'

interface StudySessionState {
  cards: SRCard[]
  currentIndex: number
  showAnswer: boolean
  reviews: StudyCardReview[]
  sessionStartTime: number
  isComplete: boolean
  isLoading: boolean
  error: string | null
}

export default function StudyAllSessionPage() {
  const router = useRouter()
  const [session, setSession] = useState<StudySessionState>({
    cards: [],
    currentIndex: 0,
    showAnswer: false,
    reviews: [],
    sessionStartTime: Date.now(),
    isComplete: false,
    isLoading: true,
    error: null
  })

  // Load cards due for study from all lessons
  useEffect(() => {
    loadStudySession()
  }, [])

  const loadStudySession = async () => {
    try {
      setSession(prev => ({ ...prev, isLoading: true, error: null }))

      // Get current user
      const { data: { user }, error: userError } = await supabase.auth.getUser()
      if (userError || !user) {
        throw new Error('Please sign in to continue')
      }

      // Fetch cards for study from all lessons using positive reinforcement system
      const { data: cardsData, error: cardsError } = await supabase
        .rpc('get_cards_for_study', {
          p_user_id: user.id,
          p_pool_type: 'both',
          p_limit_new: 20,
          p_limit_due: 30,
          p_lesson_id: null // null means all lessons
        })

      if (cardsError) throw cardsError

      if (!cardsData || cardsData.length === 0) {
        setSession(prev => ({ 
          ...prev, 
          isLoading: false, 
          isComplete: true,
          error: 'No cards due for review across all lessons'
        }))
        return
      }

      // Transform the data to match our SRCard interface
      const cards: SRCard[] = cardsData.map((item: any) => ({
        id: item.card_id,
        lesson_id: item.lesson_id,
        created_by: '', // Not needed for study
        front_content: item.front_content,
        back_content: item.back_content,
        card_type: 'basic',
        difficulty_level: item.difficulty_level,
        tags: item.tags || [],
        status: 'approved' as const,
        created_at: '',
        updated_at: ''
      }))

      setSession(prev => ({
        ...prev,
        cards,
        isLoading: false,
        sessionStartTime: Date.now()
      }))

    } catch (error) {
      console.error('Error loading study session:', error)
      setSession(prev => ({
        ...prev,
        isLoading: false,
        error: error instanceof Error ? error.message : 'Failed to load study session'
      }))
    }
  }

  const handleCardFlip = () => {
    setSession(prev => ({ ...prev, showAnswer: !prev.showAnswer }))
  }

  const handleCardReview = async (quality: QualityRating, responseTime: number) => {
    const currentCard = session.cards[session.currentIndex]
    if (!currentCard) return

    try {
      // Get current user
      const { data: { user }, error: userError } = await supabase.auth.getUser()
      if (userError || !user) throw new Error('Authentication required')

      // Record the review using our database function
      const { data, error } = await supabase
        .rpc('record_sr_review', {
          p_user_id: user.id,
          p_card_id: currentCard.id,
          p_quality: quality,
          p_response_time_ms: responseTime
        })

      if (error) throw error

      // Add to reviews array
      const newReview: StudyCardReview = {
        card_id: currentCard.id,
        quality_rating: quality,
        response_time_ms: responseTime
      }

      setSession(prev => {
        const newReviews = [...prev.reviews, newReview]
        const nextIndex = prev.currentIndex + 1
        const isComplete = nextIndex >= prev.cards.length

        return {
          ...prev,
          reviews: newReviews,
          currentIndex: isComplete ? prev.currentIndex : nextIndex,
          showAnswer: false,
          isComplete
        }
      })

    } catch (error) {
      console.error('Error recording review:', error)
      // Still proceed to next card even if recording fails
      setSession(prev => {
        const nextIndex = prev.currentIndex + 1
        const isComplete = nextIndex >= prev.cards.length

        return {
          ...prev,
          currentIndex: isComplete ? prev.currentIndex : nextIndex,
          showAnswer: false,
          isComplete
        }
      })
    }
  }

  const handleRestart = () => {
    setSession(prev => ({
      ...prev,
      currentIndex: 0,
      showAnswer: false,
      reviews: [],
      sessionStartTime: Date.now(),
      isComplete: false
    }))
  }

  const handleExit = () => {
    router.push('/dashboard/student')
  }

  const handlePause = () => {
    // In a real app, you might save session state here
    router.push('/dashboard/student')
  }

  // Loading state
  if (session.isLoading) {
    return (
      <div className="min-h-screen bg-neutral-white">
        <div className="container-main py-8">
          <Card variant="default" padding="lg" className="max-w-4xl mx-auto">
            <div className="animate-pulse text-center py-12">
              <div className="w-16 h-16 bg-learning-500 bg-opacity-20 mx-auto mb-4"></div>
              <div className="h-6 bg-neutral-gray bg-opacity-20 w-1/3 mx-auto mb-2"></div>
              <div className="h-4 bg-neutral-gray bg-opacity-20 w-1/2 mx-auto"></div>
            </div>
          </Card>
        </div>
      </div>
    )
  }

  // Error state
  if (session.error) {
    return (
      <div className="min-h-screen bg-neutral-white">
        <div className="container-main py-8">
          <Card variant="default" padding="lg" className="max-w-4xl mx-auto text-center">
            <div className="text-6xl mb-4">⚠️</div>
            <h2 className="heading-3 mb-4">Study Session Error</h2>
            <p className="text-neutral-gray mb-6">{session.error}</p>
            <div className="flex gap-4 justify-center">
              <Button variant="primary" onClick={loadStudySession}>
                Try Again
              </Button>
              <Button variant="ghost" onClick={handleExit}>
                Back to Dashboard
              </Button>
            </div>
          </Card>
        </div>
      </div>
    )
  }

  // Session complete state
  if (session.isComplete) {
    return (
      <div className="min-h-screen bg-neutral-white">
        <div className="container-main py-8">
          <SessionComplete
            reviews={session.reviews}
            totalCards={session.cards.length}
            sessionDuration={Date.now() - session.sessionStartTime}
            onRestart={handleRestart}
            onExit={handleExit}
            onContinueStudy={() => router.push('/dashboard/student')}
          />
        </div>
      </div>
    )
  }

  const currentCard = session.cards[session.currentIndex]
  const progress = {
    current: session.currentIndex + 1,
    total: session.cards.length,
    completed: session.reviews.length
  }

  return (
    <div className="min-h-screen bg-neutral-white">
      {/* Header */}
      <div className="bg-white border-b border-neutral-gray border-opacity-30">
        <div className="container-main py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <Button
                variant="ghost"
                size="sm"
                onClick={handleExit}
                className="flex items-center gap-2"
              >
                <ArrowLeft size={16} />
                Exit
              </Button>
              <div className="text-sm text-neutral-gray">
                Mixed Study Session - All Lessons
              </div>
            </div>

            <div className="flex items-center gap-4">
              <Button
                variant="ghost"
                size="sm"
                onClick={handlePause}
                className="flex items-center gap-2"
              >
                <Pause size={16} />
                Pause
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={handleRestart}
                className="flex items-center gap-2"
              >
                <RotateCcw size={16} />
                Restart
              </Button>
            </div>
          </div>
        </div>
      </div>

      <div className="container-main py-8">
        {/* Progress Bar */}
        <div className="mb-8">
          <SessionProgress
            current={progress.current}
            total={progress.total}
            completed={progress.completed}
            averageQuality={
              session.reviews.length > 0
                ? session.reviews.reduce((sum, r) => sum + r.quality_rating, 0) / session.reviews.length
                : 0
            }
          />
        </div>

        {/* Main Flashcard */}
        <div className="max-w-4xl mx-auto">
          {currentCard && (
            <EnhancedFlashcard
              card={currentCard}
              showAnswer={session.showAnswer}
              onFlip={handleCardFlip}
              onReview={handleCardReview}
              isLoading={false}
            />
          )}
        </div>

        {/* Session Info */}
        <div className="max-w-4xl mx-auto mt-8">
          <Card variant="default" padding="md" className="text-center">
            <div className="grid grid-cols-3 gap-4 text-sm">
              <div>
                <div className="font-bold text-learning-500">{progress.current}</div>
                <div className="text-neutral-gray">Current Card</div>
              </div>
              <div>
                <div className="font-bold text-focus-500">{progress.completed}</div>
                <div className="text-neutral-gray">Completed</div>
              </div>
              <div>
                <div className="font-bold text-neutral-charcoal">{progress.total - progress.current}</div>
                <div className="text-neutral-gray">Remaining</div>
              </div>
            </div>
          </Card>
        </div>
      </div>
    </div>
  )
}