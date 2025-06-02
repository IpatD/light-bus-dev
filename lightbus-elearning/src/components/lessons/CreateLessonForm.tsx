'use client'

import React, { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabase'
import { CreateLessonData } from '@/types'
import Button from '@/components/ui/Button'
import Input from '@/components/ui/Input'
import Card from '@/components/ui/Card'
import DateTimePicker from '@/components/ui/DateTimePicker'
import MultiSelect from '@/components/ui/MultiSelect'

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
  selected_students: string[]
}

interface Student {
  id: string
  name: string
  email: string
}

interface FormErrors {
  name?: string
  description?: string
  scheduled_at?: string
  scheduled_time?: string
  duration_minutes?: string
  selected_students?: string
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
    selected_students: []
  })
  const [errors, setErrors] = useState<FormErrors>({})
  const [isLoading, setIsLoading] = useState(false)
  const [loadingStudents, setLoadingStudents] = useState(false)
  const [students, setStudents] = useState<Student[]>([])
  const [step, setStep] = useState(1)

  // Set default date and time
  useEffect(() => {
    const tomorrow = new Date()
    tomorrow.setDate(tomorrow.getDate() + 1)
    const tomorrowDate = tomorrow.toISOString().split('T')[0]
    
    setFormData(prev => ({
      ...prev,
      scheduled_at: tomorrowDate,
      scheduled_time: '10:00'
    }))
  }, [])

  // Fetch available students
  useEffect(() => {
    const fetchStudents = async () => {
      setLoadingStudents(true)
      try {
        const { data, error } = await supabase.rpc('get_available_students')
        
        if (error) throw error
        
        if (data?.success && data?.data) {
          setStudents(data.data)
        }
      } catch (error: any) {
        console.error('Error fetching students:', error)
        setErrors(prev => ({ ...prev, general: 'Failed to load students' }))
      } finally {
        setLoadingStudents(false)
      }
    }

    fetchStudents()
  }, [])

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
    // No validation needed for student selection as it's optional
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
      if (formData.selected_students.length > 0) {
        const enrollmentPromises = formData.selected_students.map(studentId => {
          const student = students.find(s => s.id === studentId)
          return supabase.rpc('add_lesson_participant', {
            p_lesson_id: lessonId,
            p_student_email: student?.email || ''
          })
        })

        const enrollmentResults = await Promise.all(enrollmentPromises)
        
        // Check for enrollment errors (non-critical)
        const enrollmentErrors = enrollmentResults
          .filter(result => result.error || !result.data?.success)
          .map((result, index) => {
            const student = students.find(s => s.id === formData.selected_students[index])
            return `${student?.email}: ${result.error?.message || result.data?.error || 'Unknown error'}`
          })

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

  const handleDateChange = (date: string) => {
    setFormData(prev => ({ ...prev, scheduled_at: date }))
    if (errors.scheduled_at) {
      setErrors(prev => ({ ...prev, scheduled_at: undefined }))
    }
  }

  const handleTimeChange = (time: string) => {
    setFormData(prev => ({ ...prev, scheduled_time: time }))
    if (errors.scheduled_time) {
      setErrors(prev => ({ ...prev, scheduled_time: undefined }))
    }
  }

  const handleStudentsChange = (selectedStudents: string[]) => {
    setFormData(prev => ({ ...prev, selected_students: selectedStudents }))
    if (errors.selected_students) {
      setErrors(prev => ({ ...prev, selected_students: undefined }))
    }
  }

  const studentOptions = students.map(student => ({
    value: student.id,
    label: student.name,
    email: student.email
  }))

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

            <DateTimePicker
              dateValue={formData.scheduled_at}
              timeValue={formData.scheduled_time}
              onDateChange={handleDateChange}
              onTimeChange={handleTimeChange}
              dateError={errors.scheduled_at}
              timeError={errors.scheduled_time}
              required
              disabled={isLoading}
            />

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
            
            <MultiSelect
              options={studentOptions}
              value={formData.selected_students}
              onChange={handleStudentsChange}
              placeholder={loadingStudents ? "Loading students..." : "Search and select students..."}
              label="Select Students"
              error={errors.selected_students}
              searchable={true}
              maxHeight="max-h-60"
            />

            {formData.selected_students.length > 0 && (
              <div className="p-4 bg-learning-50 border border-learning-200">
                <h4 className="font-semibold text-learning-600 mb-2">
                  📋 Selected Students ({formData.selected_students.length})
                </h4>
                <div className="space-y-1">
                  {formData.selected_students.map(studentId => {
                    const student = students.find(s => s.id === studentId)
                    return student ? (
                      <div key={studentId} className="text-sm text-neutral-gray">
                        • {student.name} ({student.email})
                      </div>
                    ) : null
                  })}
                </div>
              </div>
            )}

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
    </Card>
  )
}