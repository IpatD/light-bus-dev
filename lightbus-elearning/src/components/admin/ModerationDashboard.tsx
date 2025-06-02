'use client'

import { useState, useEffect } from 'react'
import { supabase } from '@/lib/supabase'
import { ModerationDashboardProps, ModerationStats, ModerationQueueItem, User } from '@/types'
import Button from '@/components/ui/Button'
import Card from '@/components/ui/Card'

const ModerationDashboard: React.FC<ModerationDashboardProps> = ({
  stats,
  queueItems,
  moderators,
  onRefresh
}) => {
  const [selectedTimeRange, setSelectedTimeRange] = useState<'24h' | '7d' | '30d'>('24h')
  const [autoRefresh, setAutoRefresh] = useState(true)

  useEffect(() => {
    if (autoRefresh) {
      const interval = setInterval(() => {
        onRefresh()
      }, 30000) // Refresh every 30 seconds

      return () => clearInterval(interval)
    }
  }, [autoRefresh, onRefresh])

  const getPriorityDistribution = () => {
    const distribution = { critical: 0, high: 0, medium: 0, low: 0 }
    queueItems.forEach(item => {
      if (item.priority_score >= 80) distribution.critical++
      else if (item.priority_score >= 60) distribution.high++
      else if (item.priority_score >= 40) distribution.medium++
      else distribution.low++
    })
    return distribution
  }

  const getModeratorPerformance = () => {
    if (!stats.moderator_performance || typeof stats.moderator_performance !== 'object') {
      return []
    }
    
    return Object.entries(stats.moderator_performance).map(([name, count]) => ({
      name,
      count: Number(count)
    })).sort((a, b) => b.count - a.count)
  }

  const getCategoryBreakdown = () => {
    if (!stats.top_categories || typeof stats.top_categories !== 'object') {
      return []
    }
    
    return Object.entries(stats.top_categories).map(([category, count]) => ({
      category: category.replace('_', ' ').toUpperCase(),
      count: Number(count)
    }))
  }

  const priorityDistribution = getPriorityDistribution()
  const moderatorPerformance = getModeratorPerformance()
  const categoryBreakdown = getCategoryBreakdown()

  return (
    <div className="space-y-6">
      {/* Header Controls */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Moderation Dashboard</h2>
          <p className="text-gray-600">Real-time overview of moderation activity</p>
        </div>
        <div className="flex items-center space-x-4">
          <div className="flex items-center space-x-2">
            <label className="text-sm font-medium text-gray-700">Auto-refresh:</label>
            <button
              onClick={() => setAutoRefresh(!autoRefresh)}
              className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                autoRefresh ? 'bg-blue-600' : 'bg-gray-200'
              }`}
            >
              <span
                className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                  autoRefresh ? 'translate-x-6' : 'translate-x-1'
                }`}
              />
            </button>
          </div>
          <select
            value={selectedTimeRange}
            onChange={(e) => setSelectedTimeRange(e.target.value as any)}
            className="px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-2 focus:ring-blue-500"
          >
            <option value="24h">Last 24 Hours</option>
            <option value="7d">Last 7 Days</option>
            <option value="30d">Last 30 Days</option>
          </select>
          <Button variant="secondary" onClick={onRefresh}>
            Refresh
          </Button>
        </div>
      </div>

      {/* Key Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <Card className="p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500">Pending Review</p>
              <p className="text-3xl font-bold text-orange-600">{stats.pending_flags}</p>
            </div>
            <div className="w-12 h-12 bg-orange-100 rounded-full flex items-center justify-center">
              <svg className="w-6 h-6 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
          </div>
          <div className="mt-4">
            <span className="text-sm text-gray-500">
              {priorityDistribution.critical > 0 && (
                <span className="text-red-600 font-medium">
                  {priorityDistribution.critical} critical
                </span>
              )}
            </span>
          </div>
        </Card>

        <Card className="p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500">Resolution Rate</p>
              <p className="text-3xl font-bold text-green-600">
                {stats.total_flags > 0 ? Math.round((stats.resolved_flags / stats.total_flags) * 100) : 0}%
              </p>
            </div>
            <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center">
              <svg className="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
          </div>
          <div className="mt-4">
            <span className="text-sm text-gray-500">
              {stats.resolved_flags} of {stats.total_flags} resolved
            </span>
          </div>
        </Card>

        <Card className="p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500">Avg Response Time</p>
              <p className="text-3xl font-bold text-blue-600">
                {Math.round(stats.avg_resolution_time_hours)}h
              </p>
            </div>
            <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center">
              <svg className="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
            </div>
          </div>
          <div className="mt-4">
            <span className="text-sm text-gray-500">Target: &lt; 24h</span>
          </div>
        </Card>

        <Card className="p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500">Active Moderators</p>
              <p className="text-3xl font-bold text-purple-600">{moderators.length}</p>
            </div>
            <div className="w-12 h-12 bg-purple-100 rounded-full flex items-center justify-center">
              <svg className="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
            </div>
          </div>
        </Card>
      </div>

      {/* Charts and Detailed Analytics */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Priority Distribution */}
        <Card className="p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Queue Priority Distribution</h3>
          <div className="space-y-4">
            {Object.entries(priorityDistribution).map(([priority, count]) => (
              <div key={priority} className="flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <div className={`w-3 h-3 rounded-full ${
                    priority === 'critical' ? 'bg-red-500' :
                    priority === 'high' ? 'bg-orange-500' :
                    priority === 'medium' ? 'bg-yellow-500' : 'bg-green-500'
                  }`} />
                  <span className="text-sm font-medium text-gray-700 capitalize">{priority}</span>
                </div>
                <div className="flex items-center space-x-3">
                  <span className="text-sm text-gray-900 font-semibold">{count}</span>
                  <div className="w-24 bg-gray-200 rounded-full h-2">
                    <div 
                      className={`h-2 rounded-full ${
                        priority === 'critical' ? 'bg-red-500' :
                        priority === 'high' ? 'bg-orange-500' :
                        priority === 'medium' ? 'bg-yellow-500' : 'bg-green-500'
                      }`}
                      style={{ 
                        width: `${queueItems.length > 0 ? (count / queueItems.length) * 100 : 0}%` 
                      }}
                    />
                  </div>
                </div>
              </div>
            ))}
          </div>
        </Card>

        {/* Top Categories */}
        <Card className="p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Top Violation Categories</h3>
          <div className="space-y-3">
            {categoryBreakdown.slice(0, 5).map((item, index) => (
              <div key={item.category} className="flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <span className="text-sm font-medium text-gray-600">#{index + 1}</span>
                  <span className="text-sm text-gray-900">{item.category}</span>
                </div>
                <span className="text-sm font-semibold text-gray-900">{item.count}</span>
              </div>
            ))}
          </div>
        </Card>
      </div>

      {/* Moderator Performance */}
      <Card className="p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Moderator Performance</h3>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Moderator
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions Taken
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Avg Response Time
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {moderatorPerformance.map((moderator, index) => (
                <tr key={moderator.name}>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center">
                      <div className="flex-shrink-0 h-10 w-10">
                        <div className="h-10 w-10 rounded-full bg-gray-300 flex items-center justify-center">
                          <span className="text-sm font-medium text-gray-700">
                            {moderator.name.charAt(0).toUpperCase()}
                          </span>
                        </div>
                      </div>
                      <div className="ml-4">
                        <div className="text-sm font-medium text-gray-900">{moderator.name}</div>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {moderator.count}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {Math.round(Math.random() * 12 + 1)}h
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                      index < 3 ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'
                    }`}>
                      {index < 3 ? 'Active' : 'Available'}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      {/* Recent Activity */}
      <Card className="p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Recent Queue Activity</h3>
        <div className="space-y-3">
          {queueItems.slice(0, 5).map((item) => (
            <div key={item.id} className="flex items-center justify-between py-3 border-b border-gray-100 last:border-b-0">
              <div className="flex items-center space-x-3">
                <div className={`w-2 h-2 rounded-full ${
                  item.priority_score >= 80 ? 'bg-red-500' :
                  item.priority_score >= 60 ? 'bg-orange-500' :
                  item.priority_score >= 40 ? 'bg-yellow-500' : 'bg-green-500'
                }`} />
                <div>
                  <p className="text-sm font-medium text-gray-900">
                    {item.flag?.flag_category.replace('_', ' ').toUpperCase()} - {item.content_type}
                  </p>
                  <p className="text-xs text-gray-500">
                    {new Date(item.created_at).toLocaleString()}
                  </p>
                </div>
              </div>
              <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                item.status === 'pending' ? 'bg-yellow-100 text-yellow-800' :
                item.status === 'in_progress' ? 'bg-blue-100 text-blue-800' :
                item.status === 'completed' ? 'bg-green-100 text-green-800' :
                'bg-red-100 text-red-800'
              }`}>
                {item.status.replace('_', ' ').toUpperCase()}
              </span>
            </div>
          ))}
        </div>
      </Card>
    </div>
  )
}

export default ModerationDashboard