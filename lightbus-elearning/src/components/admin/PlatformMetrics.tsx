'use client'

import { useState, useEffect } from 'react'
import { supabase } from '@/lib/supabase'
import { PlatformMetricsProps, PlatformMetrics as PlatformMetricsType } from '@/types'
import Button from '@/components/ui/Button'
import Card from '@/components/ui/Card'

const PlatformMetrics: React.FC<PlatformMetricsProps> = ({
  metrics,
  timeRange,
  onDrillDown,
  showComparisons = true
}) => {
  const [selectedMetric, setSelectedMetric] = useState<string | null>(null)
  const [comparisonData, setComparisonData] = useState<any>(null)

  const formatNumber = (num: number, type: 'currency' | 'percentage' | 'number' = 'number') => {
    switch (type) {
      case 'currency':
        return new Intl.NumberFormat('en-US', {
          style: 'currency',
          currency: 'USD'
        }).format(num)
      case 'percentage':
        return `${num.toFixed(1)}%`
      default:
        return new Intl.NumberFormat('en-US').format(num)
    }
  }

  const getGrowthColor = (value: number) => {
    if (value > 0) return 'text-green-600'
    if (value < 0) return 'text-red-600'
    return 'text-gray-600'
  }

  const getGrowthIcon = (value: number) => {
    if (value > 0) {
      return (
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 17l9.2-9.2M17 17V7H7" />
        </svg>
      )
    }
    if (value < 0) {
      return (
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 7l-9.2 9.2M7 7v10h10" />
        </svg>
      )
    }
    return (
      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 12h14" />
      </svg>
    )
  }

  // Mock growth data for demonstration
  const getGrowthData = (metric: string) => {
    const growthValues = {
      daily_active_users: 12.5,
      monthly_active_users: 8.2,
      total_lessons: 15.3,
      total_cards: 22.7,
      total_study_sessions: 18.9,
      average_session_duration: -2.3,
      completion_rate: 5.1,
      user_satisfaction_score: 3.2
    }
    return growthValues[metric as keyof typeof growthValues] || 0
  }

  const handleMetricClick = (metricKey: string) => {
    setSelectedMetric(metricKey)
    onDrillDown(metricKey)
  }

  return (
    <div className="space-y-6">
      {/* Key Performance Indicators */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <Card className="p-6 cursor-pointer hover:shadow-lg transition-shadow" onClick={() => handleMetricClick('daily_active_users')}>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500">Daily Active Users</p>
              <p className="text-3xl font-bold text-blue-600">
                {formatNumber(metrics.daily_active_users)}
              </p>
            </div>
            <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center">
              <svg className="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
              </svg>
            </div>
          </div>
          {showComparisons && (
            <div className="mt-4 flex items-center">
              <span className={`flex items-center text-sm font-medium ${getGrowthColor(getGrowthData('daily_active_users'))}`}>
                {getGrowthIcon(getGrowthData('daily_active_users'))}
                <span className="ml-1">{Math.abs(getGrowthData('daily_active_users'))}%</span>
              </span>
              <span className="text-sm text-gray-500 ml-2">vs last {timeRange}</span>
            </div>
          )}
        </Card>

        <Card className="p-6 cursor-pointer hover:shadow-lg transition-shadow" onClick={() => handleMetricClick('monthly_active_users')}>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500">Monthly Active Users</p>
              <p className="text-3xl font-bold text-green-600">
                {formatNumber(metrics.monthly_active_users)}
              </p>
            </div>
            <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center">
              <svg className="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
            </div>
          </div>
          {showComparisons && (
            <div className="mt-4 flex items-center">
              <span className={`flex items-center text-sm font-medium ${getGrowthColor(getGrowthData('monthly_active_users'))}`}>
                {getGrowthIcon(getGrowthData('monthly_active_users'))}
                <span className="ml-1">{Math.abs(getGrowthData('monthly_active_users'))}%</span>
              </span>
              <span className="text-sm text-gray-500 ml-2">vs last {timeRange}</span>
            </div>
          )}
        </Card>

        <Card className="p-6 cursor-pointer hover:shadow-lg transition-shadow" onClick={() => handleMetricClick('completion_rate')}>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500">Completion Rate</p>
              <p className="text-3xl font-bold text-purple-600">
                {formatNumber(metrics.completion_rate, 'percentage')}
              </p>
            </div>
            <div className="w-12 h-12 bg-purple-100 rounded-full flex items-center justify-center">
              <svg className="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
          </div>
          {showComparisons && (
            <div className="mt-4 flex items-center">
              <span className={`flex items-center text-sm font-medium ${getGrowthColor(getGrowthData('completion_rate'))}`}>
                {getGrowthIcon(getGrowthData('completion_rate'))}
                <span className="ml-1">{Math.abs(getGrowthData('completion_rate'))}%</span>
              </span>
              <span className="text-sm text-gray-500 ml-2">vs last {timeRange}</span>
            </div>
          )}
        </Card>

        <Card className="p-6 cursor-pointer hover:shadow-lg transition-shadow" onClick={() => handleMetricClick('user_satisfaction_score')}>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500">Satisfaction Score</p>
              <p className="text-3xl font-bold text-orange-600">
                {metrics.user_satisfaction_score.toFixed(1)}/5.0
              </p>
            </div>
            <div className="w-12 h-12 bg-orange-100 rounded-full flex items-center justify-center">
              <svg className="w-6 h-6 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z" />
              </svg>
            </div>
          </div>
          {showComparisons && (
            <div className="mt-4 flex items-center">
              <span className={`flex items-center text-sm font-medium ${getGrowthColor(getGrowthData('user_satisfaction_score'))}`}>
                {getGrowthIcon(getGrowthData('user_satisfaction_score'))}
                <span className="ml-1">{Math.abs(getGrowthData('user_satisfaction_score'))}%</span>
              </span>
              <span className="text-sm text-gray-500 ml-2">vs last {timeRange}</span>
            </div>
          )}
        </Card>
      </div>

      {/* Content and Engagement Metrics */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card className="p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Content Metrics</h3>
          <div className="space-y-4">
            <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
              <div>
                <p className="text-sm font-medium text-gray-900">Total Lessons</p>
                <p className="text-xs text-gray-600">Created on platform</p>
              </div>
              <div className="text-right">
                <p className="text-lg font-bold text-gray-900">{formatNumber(metrics.total_lessons)}</p>
                {showComparisons && (
                  <p className={`text-xs ${getGrowthColor(getGrowthData('total_lessons'))}`}>
                    +{getGrowthData('total_lessons')}%
                  </p>
                )}
              </div>
            </div>

            <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
              <div>
                <p className="text-sm font-medium text-gray-900">Total Cards</p>
                <p className="text-xs text-gray-600">Flashcards created</p>
              </div>
              <div className="text-right">
                <p className="text-lg font-bold text-gray-900">{formatNumber(metrics.total_cards)}</p>
                {showComparisons && (
                  <p className={`text-xs ${getGrowthColor(getGrowthData('total_cards'))}`}>
                    +{getGrowthData('total_cards')}%
                  </p>
                )}
              </div>
            </div>

            <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
              <div>
                <p className="text-sm font-medium text-gray-900">Study Sessions</p>
                <p className="text-xs text-gray-600">Total sessions completed</p>
              </div>
              <div className="text-right">
                <p className="text-lg font-bold text-gray-900">{formatNumber(metrics.total_study_sessions)}</p>
                {showComparisons && (
                  <p className={`text-xs ${getGrowthColor(getGrowthData('total_study_sessions'))}`}>
                    +{getGrowthData('total_study_sessions')}%
                  </p>
                )}
              </div>
            </div>

            <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
              <div>
                <p className="text-sm font-medium text-gray-900">Avg Session Duration</p>
                <p className="text-xs text-gray-600">Minutes per session</p>
              </div>
              <div className="text-right">
                <p className="text-lg font-bold text-gray-900">{metrics.average_session_duration.toFixed(1)}m</p>
                {showComparisons && (
                  <p className={`text-xs ${getGrowthColor(getGrowthData('average_session_duration'))}`}>
                    {getGrowthData('average_session_duration')}%
                  </p>
                )}
              </div>
            </div>
          </div>
        </Card>

        <Card className="p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Growth Metrics</h3>
          <div className="space-y-4">
            {metrics.growth_metrics && Object.entries(metrics.growth_metrics).map(([key, value]) => (
              <div key={key} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                <div>
                  <p className="text-sm font-medium text-gray-900 capitalize">
                    {key.replace('_', ' ')}
                  </p>
                  <p className="text-xs text-gray-600">Growth rate</p>
                </div>
                <div className="text-right">
                  <p className={`text-lg font-bold ${getGrowthColor(value as number)}`}>
                    {formatNumber(value as number, 'percentage')}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </Card>
      </div>

      {/* Revenue Metrics */}
      {metrics.revenue_metrics && (
        <Card className="p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Revenue Metrics</h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {Object.entries(metrics.revenue_metrics).map(([key, value]) => (
              <div key={key} className="text-center">
                <p className="text-sm font-medium text-gray-500 mb-2 capitalize">
                  {key.replace('_', ' ')}
                </p>
                <p className="text-2xl font-bold text-green-600">
                  {formatNumber(value as number, 'currency')}
                </p>
              </div>
            ))}
          </div>
        </Card>
      )}

      {/* Detailed Breakdown */}
      {selectedMetric && (
        <Card className="p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold text-gray-900">
              {selectedMetric.replace('_', ' ').toUpperCase()} - Detailed View
            </h3>
            <Button
              variant="secondary"
              size="sm"
              onClick={() => setSelectedMetric(null)}
            >
              Close
            </Button>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <h4 className="text-md font-medium text-gray-900 mb-3">Trend Analysis</h4>
              <div className="bg-gray-50 p-4 rounded-lg">
                <p className="text-sm text-gray-600">
                  Detailed trend analysis and insights for {selectedMetric.replace('_', ' ')} would be displayed here.
                  This could include hourly/daily breakdowns, cohort analysis, and predictive modeling.
                </p>
              </div>
            </div>
            
            <div>
              <h4 className="text-md font-medium text-gray-900 mb-3">Key Insights</h4>
              <div className="space-y-2">
                <div className="bg-blue-50 p-3 rounded-lg">
                  <p className="text-sm text-blue-800">
                    📈 Peak activity occurs between 7-9 PM
                  </p>
                </div>
                <div className="bg-green-50 p-3 rounded-lg">
                  <p className="text-sm text-green-800">
                    ✅ 23% improvement over last month
                  </p>
                </div>
                <div className="bg-yellow-50 p-3 rounded-lg">
                  <p className="text-sm text-yellow-800">
                    ⚠️ Weekend engagement is 15% lower
                  </p>
                </div>
              </div>
            </div>
          </div>
        </Card>
      )}
    </div>
  )
}

export default PlatformMetrics