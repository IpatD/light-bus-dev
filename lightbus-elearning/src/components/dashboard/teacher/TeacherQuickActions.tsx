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
    <div className={className}>
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
        {quickActions.map((action) => (
          <div
            key={action.id}
            className="bg-white border-2 border-black p-6 text-center hover:shadow-lg transition-all cursor-pointer group"
          >
            <div className="text-4xl mb-4 group-hover:scale-110 transition-transform">
              {action.icon}
            </div>
            
            <h3 className="text-lg font-bold mb-2 text-gray-800">
              {action.title}
            </h3>
            
            <p className="text-gray-600 text-sm mb-4 line-clamp-2">
              {action.description}
            </p>
            
            <Link href={action.href}>
              <Button
                variant="primary"
                size="sm"
                className="bg-white border-2 border-black text-gray-800 hover:bg-orange-100"
              >
                {action.buttonText}
              </Button>
            </Link>
          </div>
        ))}
      </div>

      {/* Featured Action */}
      <div
        className="mt-8 p-6 text-white border-2 border-black"
        style={{ backgroundColor: '#ff6b35' }}
      >
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-xl font-bold mb-2">🎯 Start Your First Lesson</h3>
            <p className="text-orange-100 mb-4">
              Create a lesson, add students, and upload your first recording to get started with AI-powered flashcard generation.
            </p>
            <div className="flex items-center space-x-4">
              <Link href="/lessons/create">
                <Button
                  variant="secondary"
                  className="bg-white text-gray-800 hover:bg-orange-100 border-2 border-black"
                >
                  Create Lesson
                </Button>
              </Link>
              <Link href="/help/getting-started" className="text-orange-100 hover:text-white text-sm underline">
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
        <div className="text-center p-4 bg-orange-50 border-2 border-black">
          <div
            className="text-lg font-bold"
            style={{ color: '#ff6b35' }}
          >
            0
          </div>
          <div className="text-xs text-gray-600">Lessons Created</div>
        </div>
        
        <div className="text-center p-4 bg-orange-50 border-2 border-black">
          <div
            className="text-lg font-bold"
            style={{ color: '#ff6b35' }}
          >
            0
          </div>
          <div className="text-xs text-gray-600">Students Enrolled</div>
        </div>
        
        <div className="text-center p-4 bg-orange-50 border-2 border-black">
          <div
            className="text-lg font-bold"
            style={{ color: '#ff6b35' }}
          >
            0
          </div>
          <div className="text-xs text-gray-600">Cards Created</div>
        </div>
        
        <div className="text-center p-4 bg-orange-50 border-2 border-black">
          <div
            className="text-lg font-bold"
            style={{ color: '#ff6b35' }}
          >
            0
          </div>
          <div className="text-xs text-gray-600">Hours Saved</div>
        </div>
      </div>

      {/* Tips Section */}
      <div className="mt-6 p-4 bg-orange-50 border-2 border-black">
        <h4
          className="font-semibold mb-2 flex items-center"
          style={{ color: '#ff6b35' }}
        >
          💡 Pro Tips
        </h4>
        <div className="space-y-2 text-sm text-gray-600">
          <div className="flex items-start space-x-2">
            <span style={{ color: '#ff6b35' }} className="mt-0.5">•</span>
            <span>Upload high-quality audio for better AI transcription and card generation</span>
          </div>
          <div className="flex items-start space-x-2">
            <span style={{ color: '#ff6b35' }} className="mt-0.5">•</span>
            <span>Add student emails during lesson creation to automatically send invitations</span>
          </div>
          <div className="flex items-start space-x-2">
            <span style={{ color: '#ff6b35' }} className="mt-0.5">•</span>
            <span>Review and edit AI-generated cards before approving for student use</span>
          </div>
        </div>
      </div>
    </div>
  )
}