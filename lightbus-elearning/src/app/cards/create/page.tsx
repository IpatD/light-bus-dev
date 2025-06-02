'use client'

import React from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import CardCreationForm from '@/components/sr_cards/CardCreationForm'

export default function CreateCardPage() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const lessonId = searchParams.get('lesson_id') || undefined

  const handleSuccess = (cardId: string) => {
    // If we have a lesson ID, redirect to the lesson management page
    if (lessonId) {
      router.push(`/lessons/${lessonId}/teacher/cards`)
    } else {
      // Otherwise, go back to teacher dashboard
      router.push('/dashboard/teacher')
    }
  }

  const handleCancel = () => {
    if (lessonId) {
      router.push(`/lessons/${lessonId}/teacher`)
    } else {
      router.push('/dashboard/teacher')
    }
  }

  return (
    <div className="min-h-screen bg-neutral-white">
      <div className="container-main py-8">
        <CardCreationForm 
          lessonId={lessonId}
          onSuccess={handleSuccess}
          onCancel={handleCancel}
        />
      </div>
    </div>
  )
}