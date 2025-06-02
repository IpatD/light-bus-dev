'use client'

import React, { useEffect } from 'react'
import { ModalProps } from '@/types'
import Button from './Button'

const Modal: React.FC<ModalProps> = ({
  isOpen,
  onClose,
  title,
  children,
  size = 'md',
}) => {
  // Handle escape key
  useEffect(() => {
    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose()
      }
    }

    if (isOpen) {
      document.addEventListener('keydown', handleEscape)
      document.body.style.overflow = 'hidden'
    }

    return () => {
      document.removeEventListener('keydown', handleEscape)
      document.body.style.overflow = 'unset'
    }
  }, [isOpen, onClose])

  if (!isOpen) return null

  const sizeStyles = {
    sm: 'max-w-md',
    md: 'max-w-lg',
    lg: 'max-w-2xl',
    xl: 'max-w-4xl',
  }

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto">
      {/* Backdrop */}
      <div className="flex min-h-full items-center justify-center p-4">
        <div
          className="fixed inset-0 bg-black bg-opacity-50 transition-opacity"
          onClick={onClose}
        />
        
        {/* Modal panel */}
        <div
          className={`
            relative bg-white border-4 border-neutral-charcoal shadow-2xl w-full
            ${sizeStyles[size]}
            animate-fade-in
          `}
          style={{ borderRadius: '0px' }} // Pronounced edges
        >
          {/* Header */}
          {title && (
            <div className="border-b-2 border-neutral-gray px-6 py-4">
              <div className="flex items-center justify-between">
                <h3 className="text-2xl font-bold text-neutral-charcoal">
                  {title}
                </h3>
                <button
                  onClick={onClose}
                  className="text-neutral-gray hover:text-neutral-charcoal transition-colors p-1"
                >
                  <svg
                    className="w-6 h-6"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M6 18L18 6M6 6l12 12"
                    />
                  </svg>
                </button>
              </div>
            </div>
          )}

          {/* Content */}
          <div className="px-6 py-6">
            {children}
          </div>

          {/* Close button if no title */}
          {!title && (
            <button
              onClick={onClose}
              className="absolute top-4 right-4 text-neutral-gray hover:text-neutral-charcoal transition-colors p-1"
            >
              <svg
                className="w-6 h-6"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          )}
        </div>
      </div>
    </div>
  )
}

export default Modal