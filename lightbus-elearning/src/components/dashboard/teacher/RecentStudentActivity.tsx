'use client'

import React, { useState, useEffect } from 'react'
import { supabase } from '@/lib/supabase'
import Card from '@/components/ui/Card'
import Button from '@/components/ui/Button'

interface RecentStudentActivityProps {
  className?: string
}

interface ActivityItem {
  id: string
  type: 'review' | 'enrollment' | 'card_request' | 'streak' | 'completion'
  student_name: string
  student_email: string
  lesson_name: string
  description: string
  timestamp: string
  metadata?: {
    quality_rating?: number
    streak_days?: number
    completion_percentage?: number
    card_content?: string
  }
}

export default function RecentStudentActivity({ className = '' }: RecentStudentActivityProps) {
  const [activities, setActivities] = useState<ActivityItem[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    fetchRecentActivity()
  }, [])

  const fetchRecentActivity = async () => {
    try {
      setIsLoading(true)
      setError(null)

      // For now, we'll use mock data since we haven't implemented the full activity tracking
      // In a real implementation, you'd create a database function to fetch recent activities
      const mockActivities: ActivityItem[] = [
        {
          id: '1',
          type: 'review',
          student_name: 'Alice Johnson',
          student_email: 'alice@example.com',
          lesson_name: 'Introduction to Biology',
          description: 'Completed review session with excellent performance',
          timestamp: new Date(Date.now() - 15 * 60 * 1000).toISOString(),
          metadata: { quality_rating: 5 }
        },
        {
          id: '2',
          type: 'enrollment',
          student_name: 'Bob Smith',
          student_email: 'bob@example.com',
          lesson_name: 'Chemistry Basics',
          description: 'Enrolled in lesson',
          timestamp: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString()
        },
        {
          id: '3',
          type: 'streak',
          student_name: 'Carol Davis',
          student_email: 'carol@example.com',
          lesson_name: 'Physics Fundamentals',
          description: 'Achieved 7-day study streak',
          timestamp: new Date(Date.now() - 4 * 60 * 60 * 1000).toISOString(),
          metadata: { streak_days: 7 }
        },
        {
          id: '4',
          type: 'card_request',
          student_name: 'David Wilson',
          student_email: 'david@example.com',
          lesson_name: 'Mathematics',
          description: 'Submitted new flashcard for review',
          timestamp: new Date(Date.now() - 6 * 60 * 60 * 1000).toISOString(),
          metadata: { card_content: 'What is the quadratic formula?' }
        },
        {
          id: '5',
          type: 'completion',
          student_name: 'Eva Martinez',
          student_email: 'eva@example.com',
          lesson_name: 'History Basics',
          description: 'Completed 85% of lesson content',
          timestamp: new Date(Date.now() - 8 * 60 * 60 * 1000).toISOString(),
          metadata: { completion_percentage: 85 }
        },
        {
          id: '6',
          type: 'review',
          student_name: 'Frank Taylor',
          student_email: 'frank@example.com',
          lesson_name: 'Literature Review',
          description: 'Struggling with review session',
          timestamp: new Date(Date.now() - 12 * 60 * 60 * 1000).toISOString(),
          metadata: { quality_rating: 2 }
        }
      ]

      setActivities(mockActivities)
    } catch (err: any) {
      console.error('Error fetching recent activity:', err)
      setError(err.message || 'Failed to load recent activity')
    } finally {
      setIsLoading(false)
    }
  }

  const formatTimeAgo = (timestamp: string) => {
    const now = new Date()
    const time = new Date(timestamp)
    const diffMinutes = Math.floor((now.getTime() - time.getTime()) / (1000 * 60))
    
    if (diffMinutes < 1) return 'Just now'
    if (diffMinutes < 60) return `${diffMinutes}m ago`
    
    const diffHours = Math.floor(diffMinutes / 60)
    if (diffHours < 24) return `${diffHours}h ago`
    
    const diffDays = Math.floor(diffHours / 24)
    if (diffDays < 7) return `${diffDays}d ago`
    
    return time.toLocaleDateString()
  }

  const getActivityIcon = (type: string) => {
    switch (type) {
      case 'review': return '📝'
      case 'enrollment': return '👥'
      case 'card_request': return '🃏'
      case 'streak': return '🔥'
      case 'completion': return '🎯'
      default: return '📢'
    }
  }

  const getActivityColor = (type: string, metadata?: ActivityItem['metadata']) => {
    switch (type) {
      case 'review':
        if (metadata?.quality_rating && metadata.quality_rating >= 4) return 'achievement'
        if (metadata?.quality_rating && metadata.quality_rating <= 2) return 'red'
        return 'learning'
      case 'enrollment': return 'teacher'
      case 'card_request': return 'focus'
      case 'streak': return 'achievement'
      case 'completion': return 'learning'
      default: return 'neutral'
    }
  }

  const getQualityText = (rating: number) => {
    if (rating >= 4) return 'Excellent'
    if (rating >= 3) return 'Good'
    if (rating >= 2) return 'Fair'
    return 'Needs Help'
  }

  if (isLoading) {
    return (
      <div className={className}>
        <div className="animate-pulse">
          <div className="h-6 bg-gray-200 w-1/3 mb-4"></div>
          <div className="space-y-3">
            {[1, 2, 3, 4, 5].map((i) => (
              <div key={i} className="flex items-center space-x-3">
                <div className="w-8 h-8 bg-gray-200"></div>
                <div className="flex-1">
                  <div className="h-4 bg-gray-200 w-3/4 mb-1"></div>
                  <div className="h-3 bg-gray-200 w-1/2"></div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className={className}>
        <div className="text-center py-8">
          <div className="text-4xl mb-2">⚠️</div>
          <p className="text-red-600 mb-4">{error}</p>
          <Button
            variant="secondary"
            size="sm"
            onClick={fetchRecentActivity}
            className="bg-white border-2 border-black text-gray-800 hover:bg-orange-100"
          >
            Try Again
          </Button>
        </div>
      </div>
    )
  }

  return (
    <div className={className}>
      <div className="flex items-center justify-between mb-6">
        <Button
          variant="ghost"
          size="sm"
          className="bg-white border-2 border-black text-gray-800 hover:bg-orange-100"
        >
          View All
        </Button>
      </div>

      {activities.length === 0 ? (
        <div className="text-center py-8 text-gray-600">
          <div className="text-4xl mb-2">🎯</div>
          <p className="text-sm mb-2">No recent activity</p>
          <p className="text-xs">Activity will appear here as students engage with your content</p>
        </div>
      ) : (
        <div className="space-y-4">
          {activities.map((activity) => {
            return (
              <div
                key={activity.id}
                className="flex items-start space-x-3 p-3 bg-white border-2 border-black hover:bg-orange-50 transition-colors"
              >
                <div
                  className="text-lg flex-shrink-0 w-8 h-8 flex items-center justify-center border border-black text-white"
                  style={{ backgroundColor: '#ff6b35' }}
                >
                  {getActivityIcon(activity.type)}
                </div>
                
                <div className="flex-1 min-w-0">
                  <div className="flex items-start justify-between">
                    <div className="flex-1">
                      <p className="text-sm font-medium text-gray-800">
                        <span className="font-semibold">{activity.student_name}</span>
                        {' '}
                        <span className="text-gray-600">in</span>
                        {' '}
                        <span className="font-medium">{activity.lesson_name}</span>
                      </p>
                      
                      <p className="text-sm text-gray-600 mt-1">
                        {activity.description}
                        {activity.metadata?.quality_rating && (
                          <span className="ml-2 font-medium" style={{ color: '#ff6b35' }}>
                            ({getQualityText(activity.metadata.quality_rating)})
                          </span>
                        )}
                        {activity.metadata?.streak_days && (
                          <span className="ml-2 font-medium" style={{ color: '#ff6b35' }}>
                            🔥 {activity.metadata.streak_days} days
                          </span>
                        )}
                        {activity.metadata?.completion_percentage && (
                          <span className="ml-2 font-medium" style={{ color: '#ff6b35' }}>
                            {activity.metadata.completion_percentage}%
                          </span>
                        )}
                      </p>
                      
                      {activity.metadata?.card_content && (
                        <p className="text-xs text-gray-600 mt-1 italic truncate">
                          "{activity.metadata.card_content}"
                        </p>
                      )}
                    </div>
                    
                    <div className="text-xs text-gray-600 flex-shrink-0 ml-2">
                      {formatTimeAgo(activity.timestamp)}
                    </div>
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      )}

      {/* Activity Summary */}
      <div className="mt-6 p-4 bg-orange-50 border-2 border-black">
        <div className="flex items-center justify-between text-sm">
          <span className="text-gray-600">Last 24 hours</span>
          <div className="flex items-center space-x-4">
            <span style={{ color: '#ff6b35' }}>
              🎯 {activities.filter(a => a.type === 'review' && a.metadata?.quality_rating && a.metadata.quality_rating >= 4).length} excellent reviews
            </span>
            <span style={{ color: '#ff6b35' }}>
              👥 {activities.filter(a => a.type === 'enrollment').length} new enrollments
            </span>
          </div>
        </div>
      </div>
    </div>
  )
}