'use client'

import React, { Suspense } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import MediaUpload from '@/components/lessons/MediaUpload'

function UploadContentComponent() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const lessonId = searchParams.get('lesson_id') || undefined

  const handleSuccess = (filePath: string) => {
    // If we have a lesson ID, redirect to the lesson management page
    if (lessonId) {
      router.push(`/lessons/${lessonId}/teacher`)
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
    <div className="container-main py-8">
      <MediaUpload
        lessonId={lessonId}
        onSuccess={handleSuccess}
        onCancel={handleCancel}
      />
    </div>
  )
}

export default function UploadContentPage() {
  return (
    <div className="min-h-screen bg-neutral-white">
      <Suspense fallback={
        <div className="container-main py-8">
          <div className="flex items-center justify-center">
            <div className="text-lg">Loading...</div>
          </div>
        </div>
      }>
        <UploadContentComponent />
      </Suspense>
    </div>
  )
}