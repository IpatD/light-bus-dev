'use client'

import React from 'react'
import { useRouter } from 'next/navigation'
import CreateLessonForm from '@/components/lessons/CreateLessonForm'

export default function CreateLessonPage() {
  const router = useRouter()

  const handleSuccess = (lessonId: string) => {
    router.push(`/lessons/${lessonId}/teacher`)
  }

  const handleCancel = () => {
    router.push('/dashboard/teacher')
  }

  return (
    <div className="min-h-screen bg-neutral-white">
      <div className="container-main py-8">
        <CreateLessonForm 
          onSuccess={handleSuccess}
          onCancel={handleCancel}
        />
      </div>
    </div>
  )
}