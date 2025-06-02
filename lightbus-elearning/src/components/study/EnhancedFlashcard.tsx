'use client'

import React, { useState, useEffect } from 'react'
import { FlashcardProps, QualityOption, QualityRating } from '@/types'
import Button from '../ui/Button'
import Card from '../ui/Card'

const qualityOptions: QualityOption[] = [
  { value: 0, label: 'Again', description: 'Complete blackout', color: 'bg-red-500' },
  { value: 1, label: 'Hard', description: 'Incorrect, but remembered', color: 'bg-orange-500' },
  { value: 2, label: 'Hard', description: 'Incorrect, easy to remember', color: 'bg-yellow-500' },
  { value: 3, label: 'Good', description: 'Correct with hesitation', color: 'bg-blue-500' },
  { value: 4, label: 'Good', description: 'Correct after some thought', color: 'bg-green-500' },
  { value: 5, label: 'Easy', description: 'Perfect response', color: 'bg-emerald-500' },
]

const EnhancedFlashcard: React.FC<FlashcardProps> = ({
  card,
  showAnswer,
  onFlip,
  onReview,
  isLoading = false,
}) => {
  const [startTime, setStartTime] = useState<number>(0)
  const [isFlipping, setIsFlipping] = useState(false)

  useEffect(() => {
    setStartTime(Date.now())
  }, [card])

  const handleFlip = () => {
    if (isLoading) return
    setIsFlipping(true)
    setTimeout(() => {
      onFlip()
      setIsFlipping(false)
    }, 150)
  }

  const handleQualitySelect = (quality: QualityRating) => {
    if (isLoading) return
    const responseTime = Date.now() - startTime
    onReview(quality, responseTime)
  }

  return (
    <div className="flex flex-col items-center w-full max-w-4xl mx-auto">
      {/* Card Container */}
      <div className="w-full mb-8">
        <Card
          variant="bordered"
          padding="lg"
          shadow="xl"
          hover={!showAnswer}
          onClick={!showAnswer ? handleFlip : undefined}
          className={`
            min-h-[400px] flex flex-col justify-center items-center text-center transition-all duration-300
            ${isFlipping ? 'transform scale-95 opacity-75' : ''}
            ${showAnswer ? 'bg-learning-50 border-learning-500' : 'bg-white border-neutral-charcoal'}
            ${!showAnswer ? 'cursor-pointer hover:shadow-2xl' : ''}
          `}
        >
          {!showAnswer ? (
            // Question Side
            <div className="space-y-6">
              <div className="bg-learning-500 text-white px-4 py-2 text-sm font-semibold">
                QUESTION
              </div>
              <div className="text-2xl md:text-3xl font-bold text-neutral-charcoal leading-relaxed">
                {card.front_content}
              </div>
              <div className="text-neutral-gray text-lg mt-8">
                Click to reveal answer
              </div>
            </div>
          ) : (
            // Answer Side
            <div className="space-y-6">
              <div className="bg-focus-500 text-white px-4 py-2 text-sm font-semibold">
                ANSWER
              </div>
              <div className="text-xl md:text-2xl font-semibold text-neutral-charcoal leading-relaxed">
                {card.back_content}
              </div>
              
              {/* Card Metadata */}
              <div className="border-t-2 border-learning-300 pt-4 mt-6">
                <div className="flex flex-wrap justify-center gap-2 text-sm text-neutral-gray">
                  <span className="bg-neutral-gray bg-opacity-10 px-2 py-1">
                    Difficulty: {card.difficulty_level}/5
                  </span>
                  {card.tags && card.tags.length > 0 && (
                    <>
                      {card.tags.map((tag, index) => (
                        <span 
                          key={index}
                          className="bg-focus-100 text-focus-700 px-2 py-1"
                        >
                          {tag}
                        </span>
                      ))}
                    </>
                  )}
                </div>
              </div>
            </div>
          )}
        </Card>
      </div>

      {/* Quality Rating Buttons - Only show when answer is revealed */}
      {showAnswer && (
        <div className="w-full space-y-4">
          <div className="text-center">
            <h3 className="text-xl font-bold text-neutral-charcoal mb-2">
              How well did you know this?
            </h3>
            <p className="text-neutral-gray">
              Rate your response to determine when you'll see this card again
            </p>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
            {qualityOptions.map((option) => (
              <Button
                key={option.value}
                variant="ghost"
                size="md"
                onClick={() => handleQualitySelect(option.value)}
                disabled={isLoading}
                className={`
                  ${option.color} text-white border-0 hover:opacity-80
                  flex flex-col items-center py-4 px-3 min-h-[80px]
                `}
              >
                <span className="font-bold text-lg">{option.label}</span>
                <span className="text-xs opacity-90 text-center leading-tight">
                  {option.description}
                </span>
              </Button>
            ))}
          </div>

          {/* Alternative: Show Answer Again Button */}
          <div className="flex justify-center pt-4">
            <Button
              variant="ghost"
              size="sm"
              onClick={handleFlip}
              disabled={isLoading}
              className="text-neutral-gray border-neutral-gray"
            >
              Show Question Again
            </Button>
          </div>
        </div>
      )}

      {/* Loading State */}
      {isLoading && (
        <div className="absolute inset-0 bg-white bg-opacity-75 flex items-center justify-center">
          <div className="flex items-center space-x-2">
            <div className="spinner"></div>
            <span className="text-neutral-charcoal font-medium">Processing...</span>
          </div>
        </div>
      )}
    </div>
  )
}

export default EnhancedFlashcard