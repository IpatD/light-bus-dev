'use client'

import React from 'react'
import Link from 'next/link'
import Button from '@/components/ui/Button'
import Card from '@/components/ui/Card'

interface TeacherQuickActionsProps {
  className?: string
}

interface QuickAction {
  id: string
  title: string
  description: string
  icon: string
  href: string
  color: string
  buttonText: string
  buttonVariant: 'primary' | 'secondary' | 'accent' | 'ghost'
}

const quickActions: QuickAction[] = [
  {
    id: 'create-lesson',
    title: 'Create New Lesson',
    description: 'Start a new lesson and add students to begin creating content',
    icon: '📚',
    href: '/lessons/create',
    color: 'teacher',
    buttonText: 'Create Lesson',
    buttonVariant: 'secondary'
  },
  {
    id: 'upload-content',
    title: 'Upload Recording',
    description: 'Upload audio/video content and generate flashcards automatically',
    icon: '🎧',
    href: '/lessons/upload',
    color: 'learning',
    buttonText: 'Upload Content',
    buttonVariant: 'primary'
  },
  {
    id: 'create-cards',
    title: 'Create Flashcards',
    description: 'Manually create and organize flashcards for your lessons',
    icon: '📝',
    href: '/cards/create',
    color: 'focus',
    buttonText: 'Create Cards',
    buttonVariant: 'accent'
  },
  {
    id: 'bulk-import',
    title: 'Bulk Import Cards',
    description: 'Import multiple flashcards from CSV or text format',
    icon: '📋',
    href: '/cards/import',
    color: 'achievement',
    buttonText: 'Import Cards',
    buttonVariant: 'secondary'
  },
  {
    id: 'review-cards',
    title: 'Review Pending Cards',
    description: 'Approve or reject student-generated flashcards',
    icon: '✅',
    href: '/cards/approve',
    color: 'neutral',
    buttonText: 'Review Cards',
    buttonVariant: 'ghost'
  },
  {
    id: 'view-analytics',
    title: 'View Analytics',
    description: 'Monitor student progress and lesson effectiveness',
    icon: '📊',
    href: '/dashboard/teacher/analytics',
    color: 'achievement',
    buttonText: 'View Reports',
    buttonVariant: 'secondary'
  }
]

export default function TeacherQuickActions({ className = '' }: TeacherQuickActionsProps) {
  return (
    <Card variant="default" padding="lg" className={className}>
      <h2 className="heading-3 mb-6">🚀 Quick Actions</h2>
      
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
        {quickActions.map((action) => (
          <div
            key={action.id}
            className={`bg-${action.color}-50 border-2 border-${action.color}-200 p-6 text-center hover:border-${action.color}-300 transition-colors cursor-pointer group`}
          >
            <div className="text-4xl mb-4 group-hover:scale-110 transition-transform">
              {action.icon}
            </div>
            
            <h3 className={`heading-4 mb-2 text-${action.color}-600`}>
              {action.title}
            </h3>
            
            <p className="text-neutral-gray text-sm mb-4 line-clamp-2">
              {action.description}
            </p>
            
            <Link href={action.href}>
              <Button 
                variant={action.buttonVariant} 
                size="md"
                className={
                  action.buttonVariant === 'secondary' && action.color === 'teacher'
                    ? 'bg-teacher-500 text-white hover:bg-teacher-600'
                    : action.buttonVariant === 'ghost'
                    ? `border-${action.color}-300 text-${action.color}-600 hover:bg-${action.color}-50`
                    : ''
                }
              >
                {action.buttonText}
              </Button>
            </Link>
          </div>
        ))}
      </div>

      {/* Featured Action */}
      <div className="mt-8 p-6 bg-gradient-to-r from-teacher-500 to-learning-500 text-white">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-xl font-bold mb-2">🎯 Start Your First Lesson</h3>
            <p className="text-teacher-100 mb-4">
              Create a lesson, add students, and upload your first recording to get started with AI-powered flashcard generation.
            </p>
            <div className="flex items-center space-x-4">
              <Link href="/lessons/create">
                <Button variant="secondary" className="bg-white text-teacher-600 hover:bg-teacher-50">
                  Create Lesson
                </Button>
              </Link>
              <Link href="/help/getting-started" className="text-teacher-100 hover:text-white text-sm underline">
                View Tutorial
              </Link>
            </div>
          </div>
          <div className="hidden lg:block text-6xl opacity-20">
            🚀
          </div>
        </div>
      </div>

      {/* Quick Stats */}
      <div className="mt-6 grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="text-center p-4 bg-neutral-gray bg-opacity-5">
          <div className="text-lg font-bold text-teacher-500">0</div>
          <div className="text-xs text-neutral-gray">Lessons Created</div>
        </div>
        
        <div className="text-center p-4 bg-neutral-gray bg-opacity-5">
          <div className="text-lg font-bold text-learning-500">0</div>
          <div className="text-xs text-neutral-gray">Students Enrolled</div>
        </div>
        
        <div className="text-center p-4 bg-neutral-gray bg-opacity-5">
          <div className="text-lg font-bold text-focus-500">0</div>
          <div className="text-xs text-neutral-gray">Cards Created</div>
        </div>
        
        <div className="text-center p-4 bg-neutral-gray bg-opacity-5">
          <div className="text-lg font-bold text-achievement-500">0</div>
          <div className="text-xs text-neutral-gray">Hours Saved</div>
        </div>
      </div>

      {/* Tips Section */}
      <div className="mt-6 p-4 bg-focus-50 border border-focus-200">
        <h4 className="font-semibold text-focus-600 mb-2 flex items-center">
          💡 Pro Tips
        </h4>
        <div className="space-y-2 text-sm text-neutral-gray">
          <div className="flex items-start space-x-2">
            <span className="text-focus-500 mt-0.5">•</span>
            <span>Upload high-quality audio for better AI transcription and card generation</span>
          </div>
          <div className="flex items-start space-x-2">
            <span className="text-focus-500 mt-0.5">•</span>
            <span>Add student emails during lesson creation to automatically send invitations</span>
          </div>
          <div className="flex items-start space-x-2">
            <span className="text-focus-500 mt-0.5">•</span>
            <span>Review and edit AI-generated cards before approving for student use</span>
          </div>
        </div>
      </div>
    </Card>
  )
}