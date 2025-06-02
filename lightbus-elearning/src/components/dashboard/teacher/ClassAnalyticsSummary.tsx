'use client'

import React, { useState, useEffect } from 'react'
import { supabase } from '@/lib/supabase'
import { TeacherStats } from '@/types'
import Card from '@/components/ui/Card'
import Button from '@/components/ui/Button'

interface ClassAnalyticsSummaryProps {
  className?: string
}

interface StudentPerformance {
  student_id: string
  student_name: string
  student_email: string
  total_lessons: number
  total_reviews: number
  average_quality: number
  study_streak: number
  last_activity: string | null
}

interface AnalyticsData {
  overview: {
    total_students: number
    active_students: number
    total_reviews_week: number
    average_performance: number
  }
  top_performers: StudentPerformance[]
  struggling_students: StudentPerformance[]
  recent_activity: Array<{
    type: string
    description: string
    timestamp: string
  }>
}

export default function ClassAnalyticsSummary({ className = '' }: ClassAnalyticsSummaryProps) {
  const [analytics, setAnalytics] = useState<AnalyticsData | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    fetchAnalytics()
  }, [])

  const fetchAnalytics = async () => {
    try {
      setIsLoading(true)
      setError(null)

      // Get teacher stats
      const { data: statsData, error: statsError } = await supabase.rpc('get_teacher_stats')
      
      if (statsError) throw statsError
      
      if (!statsData?.success) {
        throw new Error(statsData?.error || 'Failed to fetch analytics')
      }

      // For now, we'll use mock data for detailed analytics
      // In a real implementation, you'd create additional database functions
      const mockAnalytics: AnalyticsData = {
        overview: {
          total_students: statsData.data.total_students || 0,
          active_students: Math.floor((statsData.data.total_students || 0) * 0.7),
          total_reviews_week: 150,
          average_performance: 3.8
        },
        top_performers: [
          {
            student_id: '1',
            student_name: 'Alice Johnson',
            student_email: 'alice@example.com',
            total_lessons: 5,
            total_reviews: 120,
            average_quality: 4.5,
            study_streak: 15,
            last_activity: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString()
          },
          {
            student_id: '2',
            student_name: 'Bob Smith',
            student_email: 'bob@example.com',
            total_lessons: 4,
            total_reviews: 95,
            average_quality: 4.2,
            study_streak: 12,
            last_activity: new Date(Date.now() - 5 * 60 * 60 * 1000).toISOString()
          }
        ],
        struggling_students: [
          {
            student_id: '3',
            student_name: 'Charlie Brown',
            student_email: 'charlie@example.com',
            total_lessons: 3,
            total_reviews: 25,
            average_quality: 2.1,
            study_streak: 0,
            last_activity: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString()
          }
        ],
        recent_activity: statsData.data.recent_activity || []
      }

      setAnalytics(mockAnalytics)
    } catch (err: any) {
      console.error('Error fetching analytics:', err)
      setError(err.message || 'Failed to load analytics')
    } finally {
      setIsLoading(false)
    }
  }

  const formatTimeAgo = (timestamp: string) => {
    const now = new Date()
    const time = new Date(timestamp)
    const diffHours = Math.floor((now.getTime() - time.getTime()) / (1000 * 60 * 60))
    
    if (diffHours < 1) return 'Just now'
    if (diffHours < 24) return `${diffHours}h ago`
    const diffDays = Math.floor(diffHours / 24)
    if (diffDays < 7) return `${diffDays}d ago`
    return time.toLocaleDateString()
  }

  const getPerformanceColor = (quality: number) => {
    if (quality >= 4) return 'text-achievement-500'
    if (quality >= 3) return 'text-learning-500'
    if (quality >= 2) return 'text-focus-500'
    return 'text-red-500'
  }

  const getPerformanceIcon = (quality: number) => {
    if (quality >= 4) return '🌟'
    if (quality >= 3) return '👍'
    if (quality >= 2) return '⚠️'
    return '🔴'
  }

  if (isLoading) {
    return (
      <Card variant="default" padding="lg" className={className}>
        <div className="animate-pulse">
          <div className="h-6 bg-neutral-gray bg-opacity-20 w-1/3 mb-4"></div>
          <div className="grid grid-cols-2 gap-4 mb-6">
            {[1, 2, 3, 4].map((i) => (
              <div key={i} className="h-16 bg-neutral-gray bg-opacity-20"></div>
            ))}
          </div>
          <div className="space-y-3">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-12 bg-neutral-gray bg-opacity-20"></div>
            ))}
          </div>
        </div>
      </Card>
    )
  }

  if (error) {
    return (
      <Card variant="default" padding="lg" className={className}>
        <h3 className="heading-4 mb-4">📊 Class Analytics</h3>
        <div className="text-center py-8">
          <div className="text-4xl mb-2">⚠️</div>
          <p className="text-red-600 mb-4">{error}</p>
          <Button variant="secondary" size="sm" onClick={fetchAnalytics}>
            Try Again
          </Button>
        </div>
      </Card>
    )
  }

  if (!analytics) return null

  return (
    <Card variant="default" padding="lg" className={className}>
      <div className="flex items-center justify-between mb-6">
        <h3 className="heading-4">📊 Class Analytics</h3>
        <Button variant="ghost" size="sm" className="text-learning-600 hover:bg-learning-50">
          View Detailed Reports
        </Button>
      </div>

      {/* Overview Metrics */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <div className="text-center">
          <div className="text-2xl font-bold text-learning-500 mb-1">
            {analytics.overview.total_students}
          </div>
          <div className="text-xs text-neutral-gray">Total Students</div>
        </div>
        
        <div className="text-center">
          <div className="text-2xl font-bold text-achievement-500 mb-1">
            {analytics.overview.active_students}
          </div>
          <div className="text-xs text-neutral-gray">Active This Week</div>
        </div>
        
        <div className="text-center">
          <div className="text-2xl font-bold text-focus-500 mb-1">
            {analytics.overview.total_reviews_week}
          </div>
          <div className="text-xs text-neutral-gray">Reviews This Week</div>
        </div>
        
        <div className="text-center">
          <div className="text-2xl font-bold text-teacher-500 mb-1">
            {analytics.overview.average_performance.toFixed(1)}
          </div>
          <div className="text-xs text-neutral-gray">Avg Performance</div>
        </div>
      </div>

      {/* Top Performers */}
      {analytics.top_performers.length > 0 && (
        <div className="mb-6">
          <h4 className="font-semibold text-neutral-charcoal mb-3 flex items-center">
            🏆 Top Performers
          </h4>
          <div className="space-y-2">
            {analytics.top_performers.slice(0, 3).map((student) => (
              <div
                key={student.student_id}
                className="flex items-center justify-between p-3 bg-achievement-50 border border-achievement-200"
              >
                <div>
                  <div className="font-medium text-sm">{student.student_name}</div>
                  <div className="text-xs text-neutral-gray">
                    {student.total_reviews} reviews • {student.study_streak} day streak
                  </div>
                </div>
                <div className="text-right">
                  <div className={`font-semibold text-sm ${getPerformanceColor(student.average_quality)}`}>
                    {getPerformanceIcon(student.average_quality)} {student.average_quality.toFixed(1)}
                  </div>
                  <div className="text-xs text-neutral-gray">
                    {formatTimeAgo(student.last_activity || '')}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Struggling Students */}
      {analytics.struggling_students.length > 0 && (
        <div className="mb-6">
          <h4 className="font-semibold text-neutral-charcoal mb-3 flex items-center">
            🆘 Needs Attention
          </h4>
          <div className="space-y-2">
            {analytics.struggling_students.slice(0, 2).map((student) => (
              <div
                key={student.student_id}
                className="flex items-center justify-between p-3 bg-red-50 border border-red-200"
              >
                <div>
                  <div className="font-medium text-sm">{student.student_name}</div>
                  <div className="text-xs text-neutral-gray">
                    {student.total_reviews} reviews • {student.study_streak} day streak
                  </div>
                </div>
                <div className="text-right">
                  <div className={`font-semibold text-sm ${getPerformanceColor(student.average_quality)}`}>
                    {getPerformanceIcon(student.average_quality)} {student.average_quality.toFixed(1)}
                  </div>
                  <div className="text-xs text-neutral-gray">
                    {formatTimeAgo(student.last_activity || '')}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Quick Insights */}
      <div className="bg-teacher-50 border border-teacher-200 p-4">
        <h4 className="font-semibold text-teacher-600 mb-2 flex items-center">
          💡 Quick Insights
        </h4>
        <div className="space-y-1 text-sm">
          <p>• {Math.round((analytics.overview.active_students / analytics.overview.total_students) * 100)}% of students studied this week</p>
          <p>• Average of {Math.round(analytics.overview.total_reviews_week / analytics.overview.active_students)} reviews per active student</p>
          {analytics.struggling_students.length > 0 && (
            <p className="text-red-600">• {analytics.struggling_students.length} student(s) need attention</p>
          )}
        </div>
      </div>
    </Card>
  )
}