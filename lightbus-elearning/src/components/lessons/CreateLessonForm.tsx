'use client'

import React, { useState } from 'react'
import { useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabase'
import { CreateLessonData } from '@/types'
import Button from '@/components/ui/Button'
import Input from '@/components/ui/Input'
import Card from '@/components/ui/Card'

interface CreateLessonFormProps {
  onSuccess?: (lessonId: string) => void
  onCancel?: () => void
}

interface FormData {
  name: string
  description: string
  scheduled_at: string
  scheduled_time: string
  duration_minutes: string
  student_emails: string
}

interface FormErrors {
  name?: string
  description?: string
  scheduled_at?: string
  scheduled_time?: string
  duration_minutes?: string
  student_emails?: string
  general?: string
}

export default function CreateLessonForm({ onSuccess, onCancel }: CreateLessonFormProps) {
  const router = useRouter()
  const [formData, setFormData] = useState<FormData>({
    name: '',
    description: '',
    scheduled_at: '',
    scheduled_time: '',
    duration_minutes: '',
    student_emails: ''
  })
  const [errors, setErrors] = useState<FormErrors>({})
  const [isLoading, setIsLoading] = useState(false)
  const [step, setStep] = useState(1)

  const validateStep1 = () => {
    const newErrors: FormErrors = {}

    if (!formData.name.trim()) {
      newErrors.name = 'Lesson name is required'
    }

    if (!formData.scheduled_at) {
      newErrors.scheduled_at = 'Date is required'
    } else {
      const selectedDate = new Date(formData.scheduled_at)
      const today = new Date()
      today.setHours(0, 0, 0, 0)
      
      if (selectedDate < today) {
        newErrors.scheduled_at = 'Date cannot be in the past'
      }
    }

    if (!formData.scheduled_time) {
      newErrors.scheduled_time = 'Time is required'
    }

    if (formData.duration_minutes && (isNaN(Number(formData.duration_minutes)) || Number(formData.duration_minutes) <= 0)) {
      newErrors.duration_minutes = 'Duration must be a positive number'
    }

    return newErrors
  }

  const validateStep2 = () => {
    const newErrors: FormErrors = {}

    if (formData.student_emails.trim()) {
      const emails = formData.student_emails.split('\n').map(email => email.trim()).filter(email => email)
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
      
      for (const email of emails) {
        if (!emailRegex.test(email)) {
          newErrors.student_emails = `Invalid email format: ${email}`
          break
        }
      }
    }

    return newErrors
  }

  const handleNextStep = () => {
    const stepErrors = validateStep1()
    if (Object.keys(stepErrors).length > 0) {
      setErrors(stepErrors)
      return
    }
    
    setErrors({})
    setStep(2)
  }

  const handlePrevStep = () => {
    setStep(1)
    setErrors({})
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    const step1Errors = validateStep1()
    const step2Errors = validateStep2()
    const allErrors = { ...step1Errors, ...step2Errors }
    
    if (Object.keys(allErrors).length > 0) {
      setErrors(allErrors)
      if (Object.keys(step1Errors).length > 0) {
        setStep(1)
      }
      return
    }

    setIsLoading(true)
    setErrors({})

    try {
      // Combine date and time
      const scheduledDateTime = new Date(`${formData.scheduled_at}T${formData.scheduled_time}`)
      
      const lessonData: CreateLessonData = {
        name: formData.name.trim(),
        description: formData.description.trim() || undefined,
        scheduled_at: scheduledDateTime.toISOString(),
        duration_minutes: formData.duration_minutes ? Number(formData.duration_minutes) : undefined
      }

      // Create lesson
      const { data: lessonResult, error: lessonError } = await supabase.rpc('create_lesson', {
        p_name: lessonData.name,
        p_description: lessonData.description,
        p_scheduled_at: lessonData.scheduled_at,
        p_duration_minutes: lessonData.duration_minutes
      })

      if (lessonError) throw lessonError

      if (!lessonResult?.success) {
        throw new Error(lessonResult?.error || 'Failed to create lesson')
      }

      const lessonId = lessonResult.data.id

      // Add students if provided
      if (formData.student_emails.trim()) {
        const emails = formData.student_emails.split('\n')
          .map(email => email.trim())
          .filter(email => email)

        const enrollmentPromises = emails.map(email =>
          supabase.rpc('add_lesson_participant', {
            p_lesson_id: lessonId,
            p_student_email: email
          })
        )

        const enrollmentResults = await Promise.all(enrollmentPromises)
        
        // Check for enrollment errors (non-critical)
        const enrollmentErrors = enrollmentResults
          .filter(result => result.error || !result.data?.success)
          .map((result, index) => `${emails[index]}: ${result.error?.message || result.data?.error || 'Unknown error'}`)

        if (enrollmentErrors.length > 0) {
          console.warn('Some students could not be enrolled:', enrollmentErrors)
          // We could show these as warnings, but don't fail the entire operation
        }
      }

      // Success!
      if (onSuccess) {
        onSuccess(lessonId)
      } else {
        router.push(`/lessons/${lessonId}/teacher`)
      }
    } catch (error: any) {
      console.error('Error creating lesson:', error)
      setErrors({ general: error.message || 'Failed to create lesson' })
    } finally {
      setIsLoading(false)
    }
  }

  const handleChange = (field: keyof FormData) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const value = e.target.value
    setFormData(prev => ({ ...prev, [field]: value }))
    // Clear error when user starts typing
    if (errors[field as keyof FormErrors]) {
      setErrors(prev => ({ ...prev, [field]: undefined }))
    }
  }

  const getTomorrowDate = () => {
    const tomorrow = new Date()
    tomorrow.setDate(tomorrow.getDate() + 1)
    return tomorrow.toISOString().split('T')[0]
  }

  return (
    <Card variant="default" padding="lg" className="max-w-2xl mx-auto">
      <div className="mb-6">
        <h2 className="heading-2 mb-2">📚 Create New Lesson</h2>
        <p className="text-neutral-gray">
          Set up a new lesson and optionally add students to get started.
        </p>
      </div>

      {/* Progress Indicator */}
      <div className="flex items-center mb-8">
        <div className={`flex items-center justify-center w-8 h-8 text-sm font-bold border-2 ${
          step >= 1 ? 'bg-teacher-500 text-white border-teacher-500' : 'border-neutral-gray text-neutral-gray'
        }`}>
          1
        </div>
        <div className={`flex-1 h-1 mx-2 ${step >= 2 ? 'bg-teacher-500' : 'bg-neutral-gray bg-opacity-20'}`}></div>
        <div className={`flex items-center justify-center w-8 h-8 text-sm font-bold border-2 ${
          step >= 2 ? 'bg-teacher-500 text-white border-teacher-500' : 'border-neutral-gray text-neutral-gray'
        }`}>
          2
        </div>
      </div>

      <form onSubmit={handleSubmit} className="space-y-6">
        {errors.general && (
          <div className="p-4 bg-red-50 border border-red-200 text-red-600 text-sm">
            {errors.general}
          </div>
        )}

        {step === 1 && (
          <div className="space-y-6">
            <h3 className="heading-4 text-teacher-600">📋 Lesson Details</h3>
            
            <Input
              type="text"
              label="Lesson Name"
              placeholder="e.g., Introduction to Biology"
              value={formData.name}
              onChange={handleChange('name')}
              error={errors.name}
              required
            />

            <Input
              type="textarea"
              label="Description (Optional)"
              placeholder="Brief description of what this lesson covers..."
              value={formData.description}
              onChange={handleChange('description')}
              error={errors.description}
            />

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Input
                type="text"
                label="Date"
                placeholder="Select date"
                value={formData.scheduled_at}
                onChange={handleChange('scheduled_at')}
                error={errors.scheduled_at}
                required
                className="[&>input]:appearance-none [&>input]:bg-white"
                // Use a date input type but render as text to avoid browser date picker issues
              />

              <Input
                type="text"
                label="Time"
                placeholder="e.g., 10:00"
                value={formData.scheduled_time}
                onChange={handleChange('scheduled_time')}
                error={errors.scheduled_time}
                required
              />
            </div>

            <Input
              type="number"
              label="Duration (Minutes, Optional)"
              placeholder="e.g., 60"
              value={formData.duration_minutes}
              onChange={handleChange('duration_minutes')}
              error={errors.duration_minutes}
            />

            <div className="flex items-center justify-between pt-4">
              <Button 
                type="button" 
                variant="ghost" 
                onClick={onCancel}
                disabled={isLoading}
              >
                Cancel
              </Button>
              
              <Button 
                type="button" 
                variant="primary"
                onClick={handleNextStep}
                disabled={isLoading}
              >
                Next: Add Students →
              </Button>
            </div>
          </div>
        )}

        {step === 2 && (
          <div className="space-y-6">
            <h3 className="heading-4 text-teacher-600">👥 Add Students (Optional)</h3>
            
            <Input
              type="textarea"
              label="Student Email Addresses"
              placeholder="Enter one email per line:&#10;student1@example.com&#10;student2@example.com&#10;student3@example.com"
              value={formData.student_emails}
              onChange={handleChange('student_emails')}
              error={errors.student_emails}
              className="min-h-32"
            />

            <div className="p-4 bg-learning-50 border border-learning-200">
              <h4 className="font-semibold text-learning-600 mb-2">💡 Pro Tip</h4>
              <p className="text-sm text-neutral-gray">
                You can add students now or later. Students will receive an invitation to join your lesson
                and can start studying once you create flashcards or upload content.
              </p>
            </div>

            <div className="flex items-center justify-between pt-4">
              <Button 
                type="button" 
                variant="ghost" 
                onClick={handlePrevStep}
                disabled={isLoading}
              >
                ← Back
              </Button>
              
              <div className="space-x-3">
                <Button 
                  type="submit" 
                  variant="secondary"
                  disabled={isLoading}
                  className="bg-neutral-gray text-white hover:bg-neutral-charcoal"
                >
                  {isLoading ? 'Creating...' : 'Create Without Students'}
                </Button>
                
                <Button 
                  type="submit" 
                  variant="primary"
                  disabled={isLoading}
                  loading={isLoading}
                >
                  {isLoading ? 'Creating...' : 'Create Lesson'}
                </Button>
              </div>
            </div>
          </div>
        )}
      </form>

      {/* Enhanced date/time picker */}
      <script dangerouslySetInnerHTML={{
        __html: `
          // Simple date/time helper
          document.addEventListener('DOMContentLoaded', function() {
            const dateInput = document.querySelector('input[placeholder="Select date"]');
            const timeInput = document.querySelector('input[placeholder="e.g., 10:00"]');
            
            if (dateInput) {
              dateInput.type = 'date';
              dateInput.min = new Date().toISOString().split('T')[0];
              if (!dateInput.value) {
                const tomorrow = new Date();
                tomorrow.setDate(tomorrow.getDate() + 1);
                dateInput.value = tomorrow.toISOString().split('T')[0];
              }
            }
            
            if (timeInput) {
              timeInput.type = 'time';
              if (!timeInput.value) {
                timeInput.value = '10:00';
              }
            }
          });
        `
      }} />
    </Card>
  )
}