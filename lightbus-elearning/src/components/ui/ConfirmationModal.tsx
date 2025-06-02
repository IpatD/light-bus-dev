'use client'

import React from 'react'
import Modal from './Modal'
import Button from './Button'

interface ConfirmationModalProps {
  isOpen: boolean
  onClose: () => void
  onConfirm: () => void
  title: string
  message: string
  confirmText?: string
  cancelText?: string
  isLoading?: boolean
  variant?: 'danger' | 'warning' | 'info'
}

const ConfirmationModal: React.FC<ConfirmationModalProps> = ({
  isOpen,
  onClose,
  onConfirm,
  title,
  message,
  confirmText = 'Confirm',
  cancelText = 'Cancel',
  isLoading = false,
  variant = 'danger'
}) => {
  const getIcon = () => {
    switch (variant) {
      case 'danger':
        return '🗑️'
      case 'warning':
        return '⚠️'
      case 'info':
        return 'ℹ️'
      default:
        return '❓'
    }
  }

  const getConfirmButtonVariant = () => {
    switch (variant) {
      case 'danger':
        return 'danger' as const
      case 'warning':
        return 'accent' as const
      default:
        return 'primary' as const
    }
  }

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={title}
      size="sm"
    >
      <div className="text-center">
        <div className="text-6xl mb-4">
          {getIcon()}
        </div>
        
        <div className="mb-6">
          <p className="text-neutral-charcoal text-lg leading-relaxed">
            {message}
          </p>
        </div>

        <div className="flex items-center justify-center space-x-4">
          <Button
            variant="ghost"
            onClick={onClose}
            disabled={isLoading}
            className="px-6"
          >
            {cancelText}
          </Button>
          
          <Button
            variant={getConfirmButtonVariant()}
            onClick={onConfirm}
            disabled={isLoading}
            className="px-6"
          >
            {isLoading ? (
              <div className="flex items-center space-x-2">
                <div className="animate-spin rounded-full h-4 w-4 border-2 border-white border-t-transparent"></div>
                <span>Processing...</span>
              </div>
            ) : (
              confirmText
            )}
          </Button>
        </div>
      </div>
    </Modal>
  )
}

export default ConfirmationModal