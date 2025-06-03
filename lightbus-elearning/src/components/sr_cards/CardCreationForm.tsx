'use client'

import React, { useState, useEffect } from 'react'
import { supabase } from '@/lib/supabase'
import { Lesson, CreateSRCardData } from '@/types'
import Button from '@/components/ui/Button'
import Input from '@/components/ui/Input'
import Card from '@/components/ui/Card'

interface CardCreationFormProps {
  lessonId?: string
  onSuccess?: (cardId: string) => void
  onCancel?: () => void
  className?: string
}

interface FormData {
  lesson_id: string
  front_content: string
  back_content: string
  card_type: string
  difficulty_level: number
  tags: string
}

interface FormErrors {
  lesson_id?: string
  front_content?: string
  back_content?: string
  card_type?: string
  difficulty_level?: string
  tags?: string
  general?: string
}

const cardTypes = [
  { value: 'basic', label: 'Basic Card', description: 'Simple question and answer' },
  { value: 'cloze', label: 'Cloze Deletion', description: 'Fill in the blank' },
  { value: 'multiple_choice', label: 'Multiple Choice', description: 'Multiple choice question' },
  { value: 'audio', label: 'Audio Card', description: 'Includes audio content' }
]

const difficultyLevels = [
  { value: 1, label: 'Beginner', color: 'achievement' },
  { value: 2, label: 'Easy', color: 'learning' },
  { value: 3, label: 'Medium', color: 'focus' },
  { value: 4, label: 'Hard', color: 'teacher' },
  { value: 5, label: 'Expert', color: 'red' }
]

export default function CardCreationForm({ 
  lessonId, 
  onSuccess, 
  onCancel, 
  className = '' 
}: CardCreationFormProps) {
  const [formData, setFormData] = useState<FormData>({
    lesson_id: lessonId || '',
    front_content: '',
    back_content: '',
    card_type: 'basic',
    difficulty_level: 2,
    tags: ''
  })
  const [errors, setErrors] = useState<FormErrors>({})
  const [isLoading, setIsLoading] = useState(false)
  const [lessons, setLessons] = useState<Lesson[]>([])
  const [isLoadingLessons, setIsLoadingLessons] = useState(true)

  useEffect(() => {
    fetchLessons()
  }, [])

  const fetchLessons = async () => {
    try {
      setIsLoadingLessons(true)
      const { data, error } = await supabase.rpc('get_teacher_lessons')
      
      if (error) throw error
      
      if (data?.success) {
        setLessons(data.data || [])
      }
    } catch (error) {
      console.error('Error fetching lessons:', error)
    } finally {
      setIsLoadingLessons(false)
    }
  }

  const validateForm = () => {
    const newErrors: FormErrors = {}

    if (!formData.lesson_id) {
      newErrors.lesson_id = 'Please select a lesson'
    }

    if (!formData.front_content.trim()) {
      newErrors.front_content = 'Front content is required'
    } else if (formData.front_content.trim().length < 3) {
      newErrors.front_content = 'Front content must be at least 3 characters'
    }

    if (!formData.back_content.trim()) {
      newErrors.back_content = 'Back content is required'
    } else if (formData.back_content.trim().length < 3) {
      newErrors.back_content = 'Back content must be at least 3 characters'
    }

    if (formData.tags.trim()) {
      const tags = formData.tags.split(',').map(tag => tag.trim()).filter(tag => tag)
      if (tags.some(tag => tag.length < 2)) {
        newErrors.tags = 'Each tag must be at least 2 characters'
      }
    }

    return newErrors
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    const formErrors = validateForm()
    if (Object.keys(formErrors).length > 0) {
      setErrors(formErrors)
      return
    }

    setIsLoading(true)
    setErrors({})

    try {
      const tags = formData.tags.trim() 
        ? formData.tags.split(',').map(tag => tag.trim()).filter(tag => tag)
        : []

      const { data, error } = await supabase.rpc('create_sr_card', {
        p_lesson_id: formData.lesson_id,
        p_front_content: formData.front_content.trim(),
        p_back_content: formData.back_content.trim(),
        p_card_type: formData.card_type,
        p_difficulty_level: formData.difficulty_level,
        p_tags: tags
      })

      if (error) throw error

      // The function now returns a table, so data is an array
      const result = data && data[0]
      if (!result?.success) {
        throw new Error(result?.error || 'Failed to create card')
      }

      // Success!
      if (onSuccess) {
        onSuccess(result.data.id)
      } else {
        // Reset form for creating another card
        setFormData(prev => ({
          ...prev,
          front_content: '',
          back_content: '',
          tags: ''
        }))
      }
    } catch (error: any) {
      console.error('Error creating card:', error)
      setErrors({ general: error.message || 'Failed to create card' })
    } finally {
      setIsLoading(false)
    }
  }

  const handleChange = (field: keyof FormData) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    const value = e.target.value
    setFormData(prev => ({ ...prev, [field]: value }))
    // Clear error when user starts typing
    if (errors[field as keyof FormErrors]) {
      setErrors(prev => ({ ...prev, [field]: undefined }))
    }
  }

  const handleDifficultyChange = (level: number) => {
    setFormData(prev => ({ ...prev, difficulty_level: level }))
    if (errors.difficulty_level) {
      setErrors(prev => ({ ...prev, difficulty_level: undefined }))
    }
  }

  return (
    <Card variant="default" padding="lg" className={className}>
      <div className="mb-6">
        <h2 className="heading-2 mb-2">📝 Create Flashcard</h2>
        <p className="text-neutral-gray">
          Create a new flashcard for your lesson. Cards are automatically approved for teachers.
        </p>
      </div>

      <form onSubmit={handleSubmit} className="space-y-6">
        {errors.general && (
          <div className="p-4 bg-red-50 border border-red-200 text-red-600 text-sm">
            {errors.general}
          </div>
        )}

        {/* Lesson Selection */}
        {!lessonId && (
          <div>
            <label className="block text-sm font-semibold text-neutral-charcoal mb-2">
              Lesson <span className="text-red-500">*</span>
            </label>
            {isLoadingLessons ? (
              <div className="animate-pulse h-12 bg-neutral-gray bg-opacity-20"></div>
            ) : (
              <select
                value={formData.lesson_id}
                onChange={handleChange('lesson_id')}
                className="w-full px-4 py-3 border-2 bg-white text-neutral-charcoal border-neutral-gray focus:border-learning-500 focus:outline-none transition-colors duration-200"
                style={{ borderRadius: '0px' }}
                required
              >
                <option value="">Select a lesson</option>
                {lessons.map((lesson) => (
                  <option key={lesson.id} value={lesson.id}>
                    {lesson.name}
                  </option>
                ))}
              </select>
            )}
            {errors.lesson_id && (
              <p className="mt-2 text-sm text-red-600 font-medium">
                {errors.lesson_id}
              </p>
            )}
          </div>
        )}

        {/* Card Type */}
        <div>
          <label className="block text-sm font-semibold text-neutral-charcoal mb-2">
            Card Type
          </label>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {cardTypes.map((type) => (
              <div
                key={type.value}
                className={`p-3 border-2 cursor-pointer transition-colors ${
                  formData.card_type === type.value
                    ? 'border-learning-500 bg-learning-50'
                    : 'border-neutral-gray hover:border-learning-300'
                }`}
                onClick={() => handleChange('card_type')({ target: { value: type.value } } as any)}
              >
                <div className="font-medium text-sm">{type.label}</div>
                <div className="text-xs text-neutral-gray">{type.description}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Front Content */}
        <Input
          type="textarea"
          label="Front Content (Question)"
          placeholder="Enter the question or prompt..."
          value={formData.front_content}
          onChange={handleChange('front_content')}
          error={errors.front_content}
          required
          className="min-h-24"
        />

        {/* Back Content */}
        <Input
          type="textarea"
          label="Back Content (Answer)"
          placeholder="Enter the answer or explanation..."
          value={formData.back_content}
          onChange={handleChange('back_content')}
          error={errors.back_content}
          required
          className="min-h-24"
        />

        {/* Difficulty Level */}
        <div>
          <label className="block text-sm font-semibold text-neutral-charcoal mb-2">
            Difficulty Level
          </label>
          <div className="grid grid-cols-5 gap-2">
            {difficultyLevels.map((level) => (
              <button
                key={level.value}
                type="button"
                className={`p-3 border-2 text-center transition-colors ${
                  formData.difficulty_level === level.value
                    ? `border-${level.color}-500 bg-${level.color}-50 text-${level.color}-600`
                    : 'border-neutral-gray hover:border-neutral-charcoal text-neutral-gray'
                }`}
                onClick={() => handleDifficultyChange(level.value)}
              >
                <div className="font-bold text-lg">{level.value}</div>
                <div className="text-xs">{level.label}</div>
              </button>
            ))}
          </div>
        </div>

        {/* Tags */}
        <Input
          type="text"
          label="Tags (Optional)"
          placeholder="Enter tags separated by commas (e.g., biology, cell, membrane)"
          value={formData.tags}
          onChange={handleChange('tags')}
          error={errors.tags}
        />

        {/* Preview */}
        {(formData.front_content || formData.back_content) && (
          <div className="p-4 bg-neutral-gray bg-opacity-5">
            <h4 className="font-semibold text-neutral-charcoal mb-3">Preview</h4>
            <div className="space-y-3">
              <div className="p-3 bg-white border border-neutral-gray">
                <div className="text-xs text-neutral-gray mb-1">FRONT</div>
                <div className="text-sm">
                  {formData.front_content || <span className="text-neutral-gray italic">Front content...</span>}
                </div>
              </div>
              <div className="p-3 bg-learning-50 border border-learning-200">
                <div className="text-xs text-learning-600 mb-1">BACK</div>
                <div className="text-sm">
                  {formData.back_content || <span className="text-neutral-gray italic">Back content...</span>}
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Actions */}
        <div className="flex items-center justify-between pt-4">
          <Button 
            type="button" 
            variant="ghost" 
            onClick={onCancel}
            disabled={isLoading}
          >
            Cancel
          </Button>
          
          <div className="space-x-3">
            <Button 
              type="submit" 
              variant="primary"
              disabled={isLoading}
              loading={isLoading}
            >
              {isLoading ? 'Creating...' : 'Create Card'}
            </Button>
          </div>
        </div>
      </form>
    </Card>
  )
}