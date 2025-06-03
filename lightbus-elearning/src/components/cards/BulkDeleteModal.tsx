'use client'

import React from 'react'
import ConfirmationModal from '@/components/ui/ConfirmationModal'

interface BulkDeleteModalProps {
  isOpen: boolean
  selectedCount: number
  isLoading: boolean
  onClose: () => void
  onConfirm: () => void
}

export default function BulkDeleteModal({
  isOpen,
  selectedCount,
  isLoading,
  onClose,
  onConfirm
}: BulkDeleteModalProps) {
  return (
    <ConfirmationModal
      isOpen={isOpen}
      onClose={onClose}
      onConfirm={onConfirm}
      title="Delete Multiple Flashcards"
      message={`Are you sure you want to delete ${selectedCount} flashcard${selectedCount > 1 ? 's' : ''}? This action cannot be undone and will remove all selected cards from student study sessions.`}
      confirmText={`Delete ${selectedCount} Card${selectedCount > 1 ? 's' : ''}`}
      cancelText="Cancel"
      isLoading={isLoading}
      variant="danger"
    />
  )
}