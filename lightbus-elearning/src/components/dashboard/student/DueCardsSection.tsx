'use client'

import React, { useState } from 'react'
import Link from 'next/link'
import { Clock, CheckCircle2, Play, Plus, Star, Gift } from 'lucide-react'
import Card from '@/components/ui/Card'
import Button from '@/components/ui/Button'
import { supabase } from '@/lib/supabase'

interface StudyCard {
  card_id: string
  lesson_id: string
  lesson_name: string
  front_content: string
  difficulty_level: number
  scheduled_for: string
  card_pool: 'new' | 'due'
  can_accept: boolean
  review_id: string
}

interface DueCardsSectionProps {
  newCards: StudyCard[]
  dueCards: StudyCard[]
  isLoading?: boolean
  onStartSession?: (lessonId?: string) => void
  onRefresh?: () => void
}

const DueCardsSection: React.FC<DueCardsSectionProps> = ({
  newCards,
  dueCards,
  isLoading = false,
  onStartSession,
  onRefresh
}) => {
  const [acceptingCards, setAcceptingCards] = useState(false)
  const [selectedNewCards, setSelectedNewCards] = useState<string[]>([])

  // Group new cards by lesson
  const newCardsByLesson = newCards.reduce((acc, card) => {
    if (!acc[card.lesson_id]) {
      acc[card.lesson_id] = {
        lesson_name: card.lesson_name,
        cards: []
      }
    }
    acc[card.lesson_id].cards.push(card)
    return acc
  }, {} as Record<string, { lesson_name: string; cards: StudyCard[] }>)

  // Group due cards by lesson
  const dueCardsByLesson = dueCards.reduce((acc, card) => {
    if (!acc[card.lesson_id]) {
      acc[card.lesson_id] = {
        lesson_name: card.lesson_name,
        cards: []
      }
    }
    acc[card.lesson_id].cards.push(card)
    return acc
  }, {} as Record<string, { lesson_name: string; cards: StudyCard[] }>)

  const handleAcceptCards = async (cardIds?: string[]) => {
    setAcceptingCards(true)
    try {
      const { data, error } = await supabase.rpc('accept_new_cards', {
        p_student_id: (await supabase.auth.getUser()).data.user?.id,
        p_card_ids: cardIds || null
      })

      if (error) throw error

      // Refresh the data
      onRefresh?.()
      setSelectedNewCards([])
    } catch (error) {
      console.error('Error accepting cards:', error)
    } finally {
      setAcceptingCards(false)
    }
  }

  const toggleCardSelection = (cardId: string) => {
    setSelectedNewCards(prev => 
      prev.includes(cardId) 
        ? prev.filter(id => id !== cardId)
        : [...prev, cardId]
    )
  }

  if (isLoading) {
    return (
      <div className="space-y-6">
        <Card variant="default" padding="lg" className="animate-pulse">
          <div className="h-6 bg-neutral-gray bg-opacity-20 w-1/3 mb-4"></div>
          <div className="space-y-3">
            {[1, 2, 3].map(i => (
              <div key={i} className="h-12 bg-neutral-gray bg-opacity-20"></div>
            ))}
          </div>
        </Card>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* New Cards Section */}
      {newCards.length > 0 && (
        <div>
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-3">
              <div className="bg-blue-100 text-blue-700 px-3 py-1 flex items-center gap-2 text-sm font-semibold">
                <Gift size={16} />
                <span>New Cards Available</span>
                <span className="bg-blue-500 text-white px-2 py-0.5 text-xs font-bold rounded-full">
                  {newCards.length}
                </span>
              </div>
            </div>
            
            <div className="flex gap-2">
              {selectedNewCards.length > 0 && (
                <Button
                  variant="primary"
                  size="sm"
                  onClick={() => handleAcceptCards(selectedNewCards)}
                  disabled={acceptingCards}
                  loading={acceptingCards}
                  className="flex items-center gap-2"
                >
                  <Plus size={16} />
                  Accept Selected ({selectedNewCards.length})
                </Button>
              )}
              <Button
                variant="secondary"
                size="sm"
                onClick={() => handleAcceptCards()}
                disabled={acceptingCards}
                loading={acceptingCards}
                className="flex items-center gap-2"
              >
                <Plus size={16} />
                Accept All New Cards
              </Button>
            </div>
          </div>

          <div className="bg-blue-50 border-l-4 border-blue-500 p-4 mb-4">
            <h4 className="font-semibold text-blue-800 mb-2">🎁 Fresh Learning Materials!</h4>
            <p className="text-blue-700 text-sm">
              You have {newCards.length} new cards from your lessons. Accept them to add to your study routine!
            </p>
          </div>

          <div className="space-y-4">
            {Object.entries(newCardsByLesson).map(([lessonId, lessonData]) => (
              <NewCardsGroup
                key={lessonId}
                lessonId={lessonId}
                lessonName={lessonData.lesson_name}
                cards={lessonData.cards}
                selectedCards={selectedNewCards}
                onToggleCard={toggleCardSelection}
                onAcceptLesson={() => handleAcceptCards(lessonData.cards.map(c => c.card_id))}
                accepting={acceptingCards}
              />
            ))}
          </div>
        </div>
      )}

      {/* Due Cards Section */}
      <div>
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="bg-green-100 text-green-700 px-3 py-1 flex items-center gap-2 text-sm font-semibold">
              <CheckCircle2 size={16} />
              <span>Ready to Study</span>
              <span className="bg-green-500 text-white px-2 py-0.5 text-xs font-bold rounded-full">
                {dueCards.length}
              </span>
            </div>
          </div>
          
          {dueCards.length > 0 && (
            <Button
              variant="primary"
              size="sm"
              onClick={() => onStartSession?.()}
              className="flex items-center gap-2"
            >
              <Play size={16} />
              Start Study Session
            </Button>
          )}
        </div>

        {dueCards.length === 0 ? (
          <div className="text-center py-12">
            <div className="text-6xl mb-4">🎉</div>
            <h3 className="heading-4 mb-2">All caught up!</h3>
            <p className="text-neutral-gray mb-6">
              {newCards.length > 0 
                ? "Accept some new cards above to continue learning!"
                : "You've completed all your reviews for now. Great job!"
              }
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
            <div className="grid grid-cols-2 gap-4 mb-6 p-4 bg-green-50 border-l-4 border-green-500">
              <div className="text-center">
                <div className="text-2xl font-bold text-green-600">{dueCards.length}</div>
                <div className="text-xs text-green-700">Cards Ready</div>
              </div>
              <div className="text-center">
                <div className="text-2xl font-bold text-blue-600">{Object.keys(dueCardsByLesson).length}</div>
                <div className="text-xs text-blue-700">Lessons</div>
              </div>
            </div>

            {/* Cards grouped by lesson */}
            <div className="space-y-4">
              {Object.entries(dueCardsByLesson).map(([lessonId, lessonData]) => (
                <DueCardsGroup
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
              <div className="bg-gradient-to-r from-green-500 to-blue-500 text-white p-6">
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
                  Start Study Session ({dueCards.length} cards)
                </Button>
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  )
}

// New Cards Group Component
interface NewCardsGroupProps {
  lessonId: string
  lessonName: string
  cards: StudyCard[]
  selectedCards: string[]
  onToggleCard: (cardId: string) => void
  onAcceptLesson: () => void
  accepting: boolean
}

const NewCardsGroup: React.FC<NewCardsGroupProps> = ({
  lessonId,
  lessonName,
  cards,
  selectedCards,
  onToggleCard,
  onAcceptLesson,
  accepting
}) => {
  const averageDifficulty = cards.reduce((sum, card) => sum + card.difficulty_level, 0) / cards.length

  return (
    <div className="border border-blue-200 bg-blue-50 p-4">
      <div className="flex items-center justify-between mb-3">
        <div>
          <h4 className="font-semibold text-blue-800">{lessonName}</h4>
          <div className="flex items-center gap-4 text-sm text-blue-600">
            <span>{cards.length} new cards</span>
            <span>Avg. difficulty: {averageDifficulty.toFixed(1)}/5</span>
          </div>
        </div>
        <div className="flex gap-2">
          <Button
            variant="secondary"
            size="sm"
            onClick={onAcceptLesson}
            disabled={accepting}
            className="flex items-center gap-1"
          >
            <Plus size={14} />
            Accept All
          </Button>
        </div>
      </div>

      {/* Show preview of cards with selection */}
      <div className="space-y-2">
        {cards.slice(0, 3).map((card) => (
          <div
            key={card.card_id}
            className={`p-3 border-2 cursor-pointer transition-colors ${
              selectedCards.includes(card.card_id)
                ? 'border-blue-500 bg-blue-100'
                : 'border-blue-200 bg-white hover:border-blue-400'
            }`}
            onClick={() => onToggleCard(card.card_id)}
          >
            <div className="flex items-center justify-between">
              <span className="truncate flex-1 mr-4 text-blue-800">{card.front_content}</span>
              <div className="flex items-center gap-2 text-xs text-blue-600">
                <span>Difficulty {card.difficulty_level}/5</span>
                {selectedCards.includes(card.card_id) && (
                  <CheckCircle2 size={16} className="text-blue-500" />
                )}
              </div>
            </div>
          </div>
        ))}
        {cards.length > 3 && (
          <div className="text-xs text-blue-600 text-center py-2">
            +{cards.length - 3} more cards
          </div>
        )}
      </div>
    </div>
  )
}

// Due Cards Group Component  
interface DueCardsGroupProps {
  lessonId: string
  lessonName: string
  cards: StudyCard[]
  onStartSession?: (lessonId?: string) => void
}

const DueCardsGroup: React.FC<DueCardsGroupProps> = ({
  lessonId,
  lessonName,
  cards,
  onStartSession
}) => {
  const averageDifficulty = cards.reduce((sum, card) => sum + card.difficulty_level, 0) / cards.length

  return (
    <div className="border border-green-200 bg-green-50 p-4">
      <div className="flex items-center justify-between mb-3">
        <div>
          <h4 className="font-semibold text-green-800">{lessonName}</h4>
          <div className="flex items-center gap-4 text-sm text-green-600">
            <span>{cards.length} cards ready</span>
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
            key={card.card_id}
            className="p-3 bg-white border border-green-200 text-sm flex items-center justify-between"
          >
            <span className="truncate flex-1 mr-4 text-green-800">{card.front_content}</span>
            <div className="flex items-center gap-2 text-xs text-green-600">
              <span>Difficulty {card.difficulty_level}/5</span>
              <Star size={14} className="text-green-500" />
            </div>
          </div>
        ))}
        {cards.length > 3 && (
          <div className="text-xs text-green-600 text-center py-2">
            +{cards.length - 3} more cards
          </div>
        )}
      </div>
    </div>
  )
}

export default DueCardsSection