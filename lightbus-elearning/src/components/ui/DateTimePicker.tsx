'use client'

import React from 'react'

interface DateTimePickerProps {
  dateValue?: string
  timeValue?: string
  onDateChange: (date: string) => void
  onTimeChange: (time: string) => void
  dateLabel?: string
  timeLabel?: string
  dateError?: string
  timeError?: string
  required?: boolean
  className?: string
  minDate?: string
  disabled?: boolean
}

export default function DateTimePicker({
  dateValue = '',
  timeValue = '',
  onDateChange,
  onTimeChange,
  dateLabel = 'Date',
  timeLabel = 'Time',
  dateError,
  timeError,
  required = false,
  className = '',
  minDate,
  disabled = false
}: DateTimePickerProps) {
  // Get today's date in YYYY-MM-DD format
  const getTodayDate = () => {
    const today = new Date()
    return today.toISOString().split('T')[0]
  }

  // Get tomorrow's date as default minimum
  const getTomorrowDate = () => {
    const tomorrow = new Date()
    tomorrow.setDate(tomorrow.getDate() + 1)
    return tomorrow.toISOString().split('T')[0]
  }

  const minimumDate = minDate || getTomorrowDate()

  const baseInputStyles = `
    w-full px-4 py-3 border-2 bg-white text-neutral-charcoal placeholder-neutral-gray
    focus:outline-none transition-colors duration-200 font-inter
    disabled:opacity-50 disabled:cursor-not-allowed
  `

  const getInputStyles = (hasError: boolean) => {
    const borderStyles = hasError
      ? 'border-red-500 focus:border-red-600'
      : 'border-neutral-gray focus:border-learning-500'
    
    return `${baseInputStyles} ${borderStyles}`
  }

  return (
    <div className={`space-y-4 ${className}`}>
      {/* Date Input */}
      <div className="w-full">
        {dateLabel && (
          <label className="block text-sm font-semibold text-neutral-charcoal mb-2">
            {dateLabel}
            {required && <span className="text-red-500 ml-1">*</span>}
          </label>
        )}
        
        <input
          type="date"
          value={dateValue}
          onChange={(e) => onDateChange(e.target.value)}
          min={minimumDate}
          disabled={disabled}
          required={required}
          className={getInputStyles(!!dateError)}
          style={{ borderRadius: '0px' }}
        />
        
        {dateError && (
          <p className="mt-2 text-sm text-red-600 font-medium">
            {dateError}
          </p>
        )}
      </div>

      {/* Time Input */}
      <div className="w-full">
        {timeLabel && (
          <label className="block text-sm font-semibold text-neutral-charcoal mb-2">
            {timeLabel}
            {required && <span className="text-red-500 ml-1">*</span>}
          </label>
        )}
        
        <input
          type="time"
          value={timeValue}
          onChange={(e) => onTimeChange(e.target.value)}
          disabled={disabled}
          required={required}
          className={getInputStyles(!!timeError)}
          style={{ borderRadius: '0px' }}
        />
        
        {timeError && (
          <p className="mt-2 text-sm text-red-600 font-medium">
            {timeError}
          </p>
        )}
      </div>

      {/* Combined DateTime Display */}
      {dateValue && timeValue && (
        <div className="p-3 bg-learning-50 border border-learning-200">
          <p className="text-sm font-medium text-learning-600 mb-1">📅 Scheduled for:</p>
          <p className="text-neutral-charcoal">
            {new Date(`${dateValue}T${timeValue}`).toLocaleDateString('en-US', {
              weekday: 'long',
              year: 'numeric',
              month: 'long',
              day: 'numeric',
              hour: '2-digit',
              minute: '2-digit'
            })}
          </p>
        </div>
      )}
    </div>
  )
}