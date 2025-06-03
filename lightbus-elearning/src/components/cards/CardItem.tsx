'use client'

import React from 'react'
import { SRCard } from '@/types'
import Button from '@/components/ui/Button'
import Card from '@/components/ui/Card'

interface CardItemProps {
  card: SRCard
  isSelectMode: boolean
  isSelected: boolean
  viewMode: 'grid' | 'list'
  onSelect: (cardId: string) => void
  onDelete: (cardId: string) => void
}

export default function CardItem({
  card,
  isSelectMode,
  isSelected,
  viewMode,
  onSelect,
  onDelete
}: CardItemProps) {
  if (viewMode === 'grid') {
    return (
      <Card
        variant="default"
        padding="lg"
        className={`h-full transition-all ${
          isSelectMode
            ? isSelected
              ? 'ring-2 ring-focus-500 bg-focus-50 cursor-pointer'
              : 'hover:ring-1 hover:ring-focus-300 cursor-pointer'
            : ''
        }`}
        onClick={isSelectMode ? () => onSelect(card.id) : undefined}
      >
        <div className="flex flex-col h-full">
          {/* Selection checkbox when in select mode */}
          {isSelectMode && (
            <div className="mb-3">
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={isSelected}
                  onChange={() => onSelect(card.id)}
                  className="w-4 h-4 text-focus-600 bg-gray-100 border-gray-300 rounded focus:ring-focus-500"
                  onClick={(e) => e.stopPropagation()}
                />
                <span className="text-sm text-neutral-gray">
                  {isSelected ? 'Selected' : 'Select card'}
                </span>
              </div>
            </div>
          )}

          {/* Card Content */}
          <div className="flex-1 mb-4">
            <div className="mb-3">
              <h3 className="font-medium text-neutral-charcoal mb-2">Question</h3>
              <p className="text-sm text-neutral-gray">{card.front_content}</p>
            </div>
            <div className="mb-3">
              <h3 className="font-medium text-neutral-charcoal mb-2">Answer</h3>
              <p className="text-sm text-neutral-gray">{card.back_content}</p>
            </div>
          </div>

          {/* Card Meta */}
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center space-x-2">
              <span className="text-xs px-2 py-1 bg-learning-100 text-learning-600">
                {card.card_type}
              </span>
              <span className="text-xs px-2 py-1 bg-focus-100 text-focus-600">
                Level {card.difficulty_level}
              </span>
            </div>
            {card.tags && card.tags.length > 0 && (
              <div className="text-xs text-neutral-gray">
                {card.tags.slice(0, 2).join(', ')}
                {card.tags.length > 2 && '...'}
              </div>
            )}
          </div>

          {/* Actions - only show when not in select mode */}
          {!isSelectMode && (
            <div className="flex items-center gap-2 pt-3 border-t border-neutral-gray border-opacity-20" onClick={(e) => e.stopPropagation()}>
              <Button variant="ghost" size="sm" className="flex-1 text-neutral-gray hover:text-neutral-charcoal">
                Edit
              </Button>
              <Button
                variant="ghost"
                size="sm"
                className="flex-1 text-red-500 hover:text-red-700 hover:bg-red-50"
                onClick={() => onDelete(card.id)}
              >
                Delete
              </Button>
            </div>
          )}
        </div>
      </Card>
    )
  }

  // List View - Single line with vertical elements
  return (
    <Card
      variant="default"
      padding="lg"
      className={`transition-all ${
        isSelectMode
          ? isSelected
            ? 'ring-2 ring-focus-500 bg-focus-50 cursor-pointer'
            : 'hover:ring-1 hover:ring-focus-300 cursor-pointer'
          : ''
      }`}
      onClick={isSelectMode ? () => onSelect(card.id) : undefined}
    >
      <div className="flex items-center gap-4">
        {/* Selection checkbox when in select mode */}
        {isSelectMode && (
          <div className="flex-shrink-0">
            <input
              type="checkbox"
              checked={isSelected}
              onChange={() => onSelect(card.id)}
              className="w-4 h-4 text-focus-600 bg-gray-100 border-gray-300 rounded focus:ring-focus-500"
              onClick={(e) => e.stopPropagation()}
            />
          </div>
        )}

        {/* Card Content - Vertical layout in single line */}
        <div className="flex-1 min-w-0">
          <div className="flex items-start gap-6">
            {/* Question */}
            <div className="flex-1 min-w-0">
              <div className="text-xs font-medium text-neutral-charcoal mb-1">Question</div>
              <div className="text-sm text-neutral-gray truncate">{card.front_content}</div>
            </div>
            
            {/* Answer */}
            <div className="flex-1 min-w-0">
              <div className="text-xs font-medium text-neutral-charcoal mb-1">Answer</div>
              <div className="text-sm text-neutral-gray truncate">{card.back_content}</div>
            </div>

            {/* Meta info */}
            <div className="flex-shrink-0">
              <div className="flex items-center space-x-2 mb-1">
                <span className="text-xs px-2 py-1 bg-learning-100 text-learning-600">
                  {card.card_type}
                </span>
                <span className="text-xs px-2 py-1 bg-focus-100 text-focus-600">
                  Level {card.difficulty_level}
                </span>
              </div>
              {card.tags && card.tags.length > 0 && (
                <div className="text-xs text-neutral-gray text-right">
                  {card.tags.join(', ')}
                </div>
              )}
            </div>

            {/* Actions - only show when not in select mode */}
            {!isSelectMode && (
              <div className="flex items-center gap-2 flex-shrink-0" onClick={(e) => e.stopPropagation()}>
                <Button variant="ghost" size="sm" className="text-neutral-gray hover:text-neutral-charcoal">
                  Edit
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  className="text-red-500 hover:text-red-700 hover:bg-red-50"
                  onClick={() => onDelete(card.id)}
                >
                  Delete
                </Button>
              </div>
            )}
          </div>
        </div>
      </div>
    </Card>
  )
}