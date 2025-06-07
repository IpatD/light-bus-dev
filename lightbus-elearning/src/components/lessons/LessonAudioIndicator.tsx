'use client'

import React from 'react'

interface LessonAudioIndicatorProps {
  hasAudio: boolean
  audioCount?: number
  size?: 'sm' | 'md' | 'lg'
  showCount?: boolean
  className?: string
}

export default function LessonAudioIndicator({ 
  hasAudio, 
  audioCount = 0, 
  size = 'md',
  showCount = true,
  className = '' 
}: LessonAudioIndicatorProps) {
  if (!hasAudio) {
    return null
  }

  const getSizeClasses = () => {
    switch (size) {
      case 'sm':
        return 'text-xs px-1.5 py-0.5'
      case 'lg':
        return 'text-sm px-3 py-1.5'
      default:
        return 'text-xs px-2 py-1'
    }
  }

  const getIconSize = () => {
    switch (size) {
      case 'sm':
        return 'text-xs'
      case 'lg':
        return 'text-lg'
      default:
        return 'text-sm'
    }
  }

  return (
    <div className={`
      inline-flex items-center gap-1 
      bg-learning-100 text-learning-700 
      rounded-full font-medium
      ${getSizeClasses()}
      ${className}
    `}>
      <span className={getIconSize()}>🎵</span>
      {showCount && audioCount > 0 && (
        <span>{audioCount} audio file{audioCount !== 1 ? 's' : ''}</span>
      )}
      {!showCount && <span>Audio</span>}
    </div>
  )
}