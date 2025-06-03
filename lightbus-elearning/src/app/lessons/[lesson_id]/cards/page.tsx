'use client'

import React, { useState, useEffect } from 'react'
import { useParams, useRouter } from 'next/navigation'
import Link from 'next/link'
import { supabase } from '@/lib/supabase'
import { Lesson, SRCard } from '@/types'
import Button from '@/components/ui/Button'
import Card from '@/components/ui/Card'
import ConfirmationModal from '@/components/ui/ConfirmationModal'
import CardItem from '@/components/cards/CardItem'
import BulkDeleteModal from '@/components/cards/BulkDeleteModal'
import { ArrowLeft, Plus, Search, Filter, Grid3X3, List } from 'lucide-react'

interface LessonCardsData {
  lesson: Lesson
  cards: SRCard[]
}

export default function LessonCardsPage() {
  const params = useParams()
  const router = useRouter()
  const lessonId = params.lesson_id as string

  const [lessonData, setLessonData] = useState<LessonCardsData | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [searchTerm, setSearchTerm] = useState('')
  const [filterDifficulty, setFilterDifficulty] = useState<number | null>(null)
  const [showDeleteCardModal, setShowDeleteCardModal] = useState(false)
  const [cardToDelete, setCardToDelete] = useState<string | null>(null)
  const [isDeletingCard, setIsDeletingCard] = useState(false)
  const [isSelectMode, setIsSelectMode] = useState(false)
  const [selectedCards, setSelectedCards] = useState<Set<string>>(new Set())
  const [showBulkDeleteModal, setShowBulkDeleteModal] = useState(false)
  const [isBulkDeleting, setIsBulkDeleting] = useState(false)
  const [viewMode, setViewMode] = useState<'grid' | 'list'>('grid')

  useEffect(() => {
    if (lessonId) {
      fetchLessonData()
    }
  }, [lessonId])

  const fetchLessonData = async () => {
    try {
      setIsLoading(true)
      setError(null)

      // Get current user
      const { data: { user }, error: userError } = await supabase.auth.getUser()
      if (userError || !user) {
        throw new Error('Please sign in to continue')
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

      setLessonData({
        lesson: lessons,
        cards: approvedCards
      })
    } catch (error: any) {
      console.error('Error fetching lesson data:', error)
      setError(error.message || 'Failed to load lesson data')
    } finally {
      setIsLoading(false)
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

  const handleSelectModeToggle = () => {
    setIsSelectMode(!isSelectMode)
    if (isSelectMode) {
      setSelectedCards(new Set())
    }
  }

  const handleCardSelect = (cardId: string) => {
    const newSelected = new Set(selectedCards)
    if (newSelected.has(cardId)) {
      newSelected.delete(cardId)
    } else {
      newSelected.add(cardId)
    }
    setSelectedCards(newSelected)
  }

  const handleSelectAll = () => {
    if (selectedCards.size === filteredCards.length) {
      setSelectedCards(new Set())
    } else {
      setSelectedCards(new Set(filteredCards.map(card => card.id)))
    }
  }

  const handleBulkDelete = async () => {
    if (selectedCards.size === 0) return

    setIsBulkDeleting(true)
    let successCount = 0
    let errorCount = 0
    let totalReviewsAffected = 0

    try {
      // Delete cards one by one and collect results
      for (const cardId of selectedCards) {
        try {
          const { data, error } = await supabase.rpc('delete_sr_card', {
            p_card_id: cardId
          })

          if (error) throw error

          const result = data && data[0]
          if (result?.success) {
            successCount++
            // Extract number from message like "Card deleted successfully. Removed 5 student review records."
            const match = result.message?.match(/Removed (\d+) student/)
            if (match) {
              totalReviewsAffected += parseInt(match[1])
            }
          } else {
            errorCount++
          }
        } catch (error) {
          console.error(`Error deleting card ${cardId}:`, error)
          errorCount++
        }
      }

      // Refresh lesson data to show updated card list
      await fetchLessonData()
      
      // Show results
      if (errorCount === 0) {
        alert(`Successfully deleted ${successCount} cards. Removed ${totalReviewsAffected} student review records.`)
      } else {
        alert(`Deleted ${successCount} cards successfully, ${errorCount} failed. Removed ${totalReviewsAffected} student review records.`)
      }

      // Exit select mode and clear selection
      setIsSelectMode(false)
      setSelectedCards(new Set())
    } catch (error: any) {
      console.error('Error in bulk delete:', error)
      alert('Bulk delete failed. Please try again.')
    } finally {
      setIsBulkDeleting(false)
      setShowBulkDeleteModal(false)
    }
  }

  const handleBulkDeleteClick = () => {
    if (selectedCards.size === 0) return
    setShowBulkDeleteModal(true)
  }

  const filteredCards = lessonData?.cards.filter(card => {
    const matchesSearch = searchTerm === '' || 
      card.front_content.toLowerCase().includes(searchTerm.toLowerCase()) ||
      card.back_content.toLowerCase().includes(searchTerm.toLowerCase())
    
    const matchesDifficulty = filterDifficulty === null || card.difficulty_level === filterDifficulty

    return matchesSearch && matchesDifficulty
  }) || []

  if (isLoading) {
    return (
      <div className="min-h-screen bg-neutral-white">
        <div className="container-main py-8">
          <div className="animate-pulse">
            <div className="h-8 bg-neutral-gray bg-opacity-20 w-1/3 mb-6"></div>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {[1, 2, 3, 4, 5, 6].map((i) => (
                <div key={i} className="h-48 bg-neutral-gray bg-opacity-20"></div>
              ))}
            </div>
          </div>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="min-h-screen bg-neutral-white">
        <div className="container-main py-8">
          <Card variant="default" padding="lg" className="text-center max-w-md mx-auto">
            <div className="text-6xl mb-4">⚠️</div>
            <h2 className="heading-3 mb-4">Error Loading Lesson</h2>
            <p className="text-neutral-gray mb-6">{error}</p>
            <div className="flex gap-4 justify-center">
              <Button variant="primary" onClick={fetchLessonData}>
                Try Again
              </Button>
              <Button variant="ghost" onClick={() => router.push('/dashboard/teacher')}>
                Back to Dashboard
              </Button>
            </div>
          </Card>
        </div>
      </div>
    )
  }

  if (!lessonData) {
    return null
  }

  return (
    <div className="min-h-screen bg-neutral-white">
      {/* Header */}
      <div className="bg-white border-b border-neutral-gray border-opacity-30">
        <div className="container-main py-6">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <div className="flex items-center gap-4">
              <Link href={`/lessons/${lessonId}/teacher`}>
                <Button variant="ghost" size="sm" className="flex items-center gap-2">
                  <ArrowLeft size={16} />
                  <span className="hidden sm:inline">Back to Lesson</span>
                  <span className="sm:hidden">Back</span>
                </Button>
              </Link>
              <div>
                <h1 className="heading-2">{lessonData.lesson.name}</h1>
                <p className="text-neutral-gray">All Flashcards</p>
              </div>
            </div>
            
            <div className="flex items-center justify-between gap-3">
              {/* View Toggle */}
              <div className="flex items-center border border-neutral-gray border-opacity-30 rounded">
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setViewMode('grid')}
                  className={`px-3 py-2 ${viewMode === 'grid' ? 'bg-focus-100 text-focus-600' : 'text-neutral-gray'}`}
                >
                  <Grid3X3 size={16} />
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setViewMode('list')}
                  className={`px-3 py-2 ${viewMode === 'list' ? 'bg-focus-100 text-focus-600' : 'text-neutral-gray'}`}
                >
                  <List size={16} />
                </Button>
              </div>

              {/* Action buttons */}
              <div className="flex items-center gap-2 lg:gap-3">
                {!isSelectMode ? (
                  <>
                    <Button
                      variant="ghost"
                      onClick={handleSelectModeToggle}
                      className="flex items-center gap-2 text-xs sm:text-sm"
                    >
                      <span className="hidden sm:inline">Select Cards</span>
                      <span className="sm:hidden">Select</span>
                    </Button>
                    <Link href={`/cards/create?lesson_id=${lessonId}`}>
                      <Button variant="primary" className="flex items-center gap-2 text-xs sm:text-sm">
                        <Plus size={16} />
                        <span className="hidden sm:inline">Create Card</span>
                        <span className="sm:hidden">Create</span>
                      </Button>
                    </Link>
                  </>
                ) : (
                  <>
                    <Button
                      variant="ghost"
                      onClick={handleSelectModeToggle}
                      className="flex items-center gap-2 text-xs sm:text-sm"
                    >
                      Cancel
                    </Button>
                    <Button
                      variant="ghost"
                      onClick={handleSelectAll}
                      disabled={filteredCards.length === 0}
                      className="flex items-center gap-2 text-xs sm:text-sm"
                    >
                      <span className="hidden sm:inline">
                        {selectedCards.size === filteredCards.length && filteredCards.length > 0 ? 'Deselect All' : 'Select All'}
                      </span>
                      <span className="sm:hidden">
                        {selectedCards.size === filteredCards.length && filteredCards.length > 0 ? 'Deselect' : 'All'}
                      </span>
                    </Button>
                    <Button
                      variant="ghost"
                      onClick={handleBulkDeleteClick}
                      disabled={selectedCards.size === 0}
                      className="flex items-center gap-2 text-red-500 hover:text-red-700 hover:bg-red-50 text-xs sm:text-sm"
                    >
                      <span className="hidden sm:inline">Delete Selected ({selectedCards.size})</span>
                      <span className="sm:hidden">Delete ({selectedCards.size})</span>
                    </Button>
                  </>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="container-main py-8">
        {/* Filters and Search */}
        <div className="mb-8">
          <Card variant="default" padding="lg">
            <div className="flex flex-col md:flex-row gap-4 items-start md:items-center justify-between">
              <div className="flex flex-col sm:flex-row gap-4 flex-1">
                {/* Search */}
                <div className="relative flex-1 max-w-md">
                  <Search size={16} className="absolute left-3 top-1/2 transform -translate-y-1/2 text-neutral-gray" />
                  <input
                    type="text"
                    placeholder="Search cards..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="w-full pl-10 pr-4 py-2 border border-neutral-gray border-opacity-30 focus:border-focus-500 focus:outline-none"
                  />
                </div>

                {/* Difficulty Filter */}
                <div className="flex items-center gap-2">
                  <Filter size={16} className="text-neutral-gray" />
                  <select
                    value={filterDifficulty || ''}
                    onChange={(e) => setFilterDifficulty(e.target.value ? parseInt(e.target.value) : null)}
                    className="px-3 py-2 border border-neutral-gray border-opacity-30 focus:border-focus-500 focus:outline-none"
                  >
                    <option value="">All Difficulties</option>
                    <option value="1">Level 1</option>
                    <option value="2">Level 2</option>
                    <option value="3">Level 3</option>
                    <option value="4">Level 4</option>
                    <option value="5">Level 5</option>
                  </select>
                </div>
              </div>

              <div className="text-sm text-neutral-gray">
                Showing {filteredCards.length} of {lessonData.cards.length} cards
              </div>
            </div>
          </Card>
        </div>

        {/* Cards Display */}
        {filteredCards.length > 0 ? (
          <div className={viewMode === 'grid' ? 'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6' : 'space-y-4'}>
            {filteredCards.map((card) => (
              <CardItem
                key={card.id}
                card={card}
                isSelectMode={isSelectMode}
                isSelected={selectedCards.has(card.id)}
                viewMode={viewMode}
                onSelect={handleCardSelect}
                onDelete={handleDeleteCardClick}
              />
            ))}
          </div>
        ) : (
          <Card variant="default" padding="lg" className="text-center">
            <div className="text-6xl mb-4">📚</div>
            <h3 className="heading-4 mb-2">
              {lessonData.cards.length === 0 ? 'No Cards Yet' : 'No Cards Match Your Search'}
            </h3>
            <p className="text-neutral-gray mb-6">
              {lessonData.cards.length === 0 
                ? 'Start building your lesson by creating some flashcards.'
                : 'Try adjusting your search terms or filters.'
              }
            </p>
            {lessonData.cards.length === 0 && (
              <Link href={`/cards/create?lesson_id=${lessonId}`}>
                <Button variant="primary">Create First Card</Button>
              </Link>
            )}
            {lessonData.cards.length > 0 && (
              <Button variant="ghost" onClick={() => {
                setSearchTerm('')
                setFilterDifficulty(null)
              }}>
                Clear Filters
              </Button>
            )}
          </Card>
        )}

        {/* Bulk Delete Modal */}
        <BulkDeleteModal
          isOpen={showBulkDeleteModal}
          selectedCount={selectedCards.size}
          isLoading={isBulkDeleting}
          onClose={() => setShowBulkDeleteModal(false)}
          onConfirm={handleBulkDelete}
        />

        {/* Single Card Delete Modal */}
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