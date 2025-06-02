'use client'

import React, { useState, useEffect, useRef } from 'react'

interface Option {
  value: string
  label: string
  email?: string
}

interface MultiSelectProps {
  options: Option[]
  value: string[]
  onChange: (selectedValues: string[]) => void
  placeholder?: string
  label?: string
  error?: string
  required?: boolean
  className?: string
  searchable?: boolean
  maxHeight?: string
}

export default function MultiSelect({
  options,
  value,
  onChange,
  placeholder = 'Select items...',
  label,
  error,
  required = false,
  className = '',
  searchable = true,
  maxHeight = 'max-h-48'
}: MultiSelectProps) {
  const [isOpen, setIsOpen] = useState(false)
  const [searchTerm, setSearchTerm] = useState('')
  const containerRef = useRef<HTMLDivElement>(null)

  // Filter options based on search term
  const filteredOptions = options.filter(option =>
    option.label.toLowerCase().includes(searchTerm.toLowerCase()) ||
    (option.email && option.email.toLowerCase().includes(searchTerm.toLowerCase()))
  )

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setIsOpen(false)
        setSearchTerm('')
      }
    }

    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  const handleToggleOption = (optionValue: string) => {
    const newValue = value.includes(optionValue)
      ? value.filter(v => v !== optionValue)
      : [...value, optionValue]
    
    onChange(newValue)
  }

  const handleRemoveOption = (optionValue: string) => {
    onChange(value.filter(v => v !== optionValue))
  }

  const selectedOptions = options.filter(option => value.includes(option.value))

  const baseStyles = `
    w-full border-2 bg-white text-neutral-charcoal
    focus-within:outline-none transition-colors duration-200 font-inter
    disabled:opacity-50 disabled:cursor-not-allowed
  `

  const borderStyles = error
    ? 'border-red-500 focus-within:border-red-600'
    : 'border-neutral-gray focus-within:border-learning-500'

  return (
    <div className="w-full">
      {label && (
        <label className="block text-sm font-semibold text-neutral-charcoal mb-2">
          {label}
          {required && <span className="text-red-500 ml-1">*</span>}
        </label>
      )}

      <div ref={containerRef} className="relative">
        <div
          className={`${baseStyles} ${borderStyles} ${className}`}
          style={{ borderRadius: '0px' }}
        >
          {/* Selected items display */}
          <div className="min-h-[48px] p-3 flex flex-wrap gap-2 items-center">
            {selectedOptions.map(option => (
              <span
                key={option.value}
                className="inline-flex items-center px-2 py-1 bg-learning-100 text-learning-700 text-sm font-medium"
                style={{ borderRadius: '0px' }}
              >
                {option.label}
                <button
                  type="button"
                  onClick={() => handleRemoveOption(option.value)}
                  className="ml-2 text-learning-500 hover:text-learning-700 focus:outline-none"
                >
                  ×
                </button>
              </span>
            ))}
            
            {/* Search input or placeholder */}
            <div className="flex-1 min-w-[120px]">
              {searchable ? (
                <input
                  type="text"
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  onFocus={() => setIsOpen(true)}
                  placeholder={selectedOptions.length === 0 ? placeholder : 'Search...'}
                  className="w-full bg-transparent border-none outline-none placeholder-neutral-gray"
                />
              ) : (
                <button
                  type="button"
                  onClick={() => setIsOpen(!isOpen)}
                  className="w-full text-left bg-transparent border-none outline-none"
                >
                  {selectedOptions.length === 0 ? (
                    <span className="text-neutral-gray">{placeholder}</span>
                  ) : null}
                </button>
              )}
            </div>

            {/* Dropdown arrow */}
            <button
              type="button"
              onClick={() => setIsOpen(!isOpen)}
              className="text-neutral-gray hover:text-neutral-charcoal focus:outline-none"
            >
              <svg
                className={`w-5 h-5 transition-transform duration-200 ${isOpen ? 'rotate-180' : ''}`}
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
              </svg>
            </button>
          </div>
        </div>

        {/* Dropdown options */}
        {isOpen && (
          <div
            className={`absolute z-50 w-full mt-1 bg-white border-2 border-neutral-gray shadow-lg ${maxHeight} overflow-y-auto`}
            style={{ borderRadius: '0px' }}
          >
            {filteredOptions.length === 0 ? (
              <div className="px-4 py-3 text-neutral-gray text-sm">
                {searchTerm ? 'No results found' : 'No options available'}
              </div>
            ) : (
              filteredOptions.map(option => (
                <button
                  key={option.value}
                  type="button"
                  onClick={() => handleToggleOption(option.value)}
                  className={`w-full px-4 py-3 text-left hover:bg-learning-50 focus:outline-none focus:bg-learning-50 transition-colors duration-150 ${
                    value.includes(option.value) ? 'bg-learning-100 text-learning-700 font-medium' : 'text-neutral-charcoal'
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <div>
                      <div className="font-medium">{option.label}</div>
                      {option.email && (
                        <div className="text-sm text-neutral-gray">{option.email}</div>
                      )}
                    </div>
                    {value.includes(option.value) && (
                      <svg className="w-5 h-5 text-learning-500" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                      </svg>
                    )}
                  </div>
                </button>
              ))
            )}
          </div>
        )}
      </div>

      {error && (
        <p className="mt-2 text-sm text-red-600 font-medium">
          {error}
        </p>
      )}
    </div>
  )
}