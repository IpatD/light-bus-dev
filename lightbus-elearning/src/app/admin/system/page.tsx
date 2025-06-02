'use client'

import { useState, useEffect } from 'react'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/hooks/useAuth'
import { SystemHealthDashboardProps, SystemHealthMetric, SystemHealth } from '@/types'
import Button from '@/components/ui/Button'
import Card from '@/components/ui/Card'

interface SystemAlert {
  id: string
  type: 'warning' | 'critical' | 'info'
  title: string
  description: string
  timestamp: string
  acknowledged: boolean
}

const SystemHealthDashboard: React.FC<SystemHealthDashboardProps> = ({
  metrics,
  health,
  alerts,
  onAcknowledgeAlert
}) => {
  const getStatusColor = (status: string) => {
    switch (status) {
      case 'critical': return 'text-red-600 bg-red-100'
      case 'warning': return 'text-yellow-600 bg-yellow-100'
      case 'normal': return 'text-green-600 bg-green-100'
      default: return 'text-gray-600 bg-gray-100'
    }
  }

  const getMetricColor = (value: number, warning: number, critical: number) => {
    if (value >= critical) return 'text-red-600'
    if (value >= warning) return 'text-yellow-600'
    return 'text-green-600'
  }

  return (
    <div className="space-y-6">
      {/* System Status Overview */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <Card className="p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500">CPU Usage</p>
              <p className={`text-3xl font-bold ${getMetricColor(health.cpu_usage, 70, 90)}`}>
                {Math.round(health.cpu_usage)}%
              </p>
            </div>
            <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center">
              <svg className="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z" />
              </svg>
            </div>
          </div>
          <div className="mt-4">
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div 
                className={`h-2 rounded-full ${
                  health.cpu_usage >= 90 ? 'bg-red-500' :
                  health.cpu_usage >= 70 ? 'bg-yellow-500' : 'bg-green-500'
                }`}
                style={{ width: `${Math.min(health.cpu_usage, 100)}%` }}
              />
            </div>
          </div>
        </Card>

        <Card className="p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500">Memory Usage</p>
              <p className={`text-3xl font-bold ${getMetricColor(health.memory_usage, 80, 95)}`}>
                {Math.round(health.memory_usage)}%
              </p>
            </div>
            <div className="w-12 h-12 bg-purple-100 rounded-full flex items-center justify-center">
              <svg className="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
              </svg>
            </div>
          </div>
          <div className="mt-4">
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div 
                className={`h-2 rounded-full ${
                  health.memory_usage >= 95 ? 'bg-red-500' :
                  health.memory_usage >= 80 ? 'bg-yellow-500' : 'bg-green-500'
                }`}
                style={{ width: `${Math.min(health.memory_usage, 100)}%` }}
              />
            </div>
          </div>
        </Card>

        <Card className="p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500">Response Time</p>
              <p className={`text-3xl font-bold ${getMetricColor(health.response_time_ms, 500, 1000)}`}>
                {Math.round(health.response_time_ms)}ms
              </p>
            </div>
            <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center">
              <svg className="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
            </div>
          </div>
          <div className="mt-4">
            <span className="text-sm text-gray-500">Target: &lt; 200ms</span>
          </div>
        </Card>

        <Card className="p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500">Active Users</p>
              <p className="text-3xl font-bold text-blue-600">{health.active_connections}</p>
            </div>
            <div className="w-12 h-12 bg-orange-100 rounded-full flex items-center justify-center">
              <svg className="w-6 h-6 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z" />
              </svg>
            </div>
          </div>
          <div className="mt-4">
            <span className="text-sm text-gray-500">Last 5 minutes</span>
          </div>
        </Card>
      </div>

      {/* System Status */}
      <Card className="p-6">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-xl font-semibold text-gray-900">System Status</h2>
          <span className={`inline-flex px-3 py-1 text-sm font-semibold rounded-full ${getStatusColor(health.status)}`}>
            {health.status.toUpperCase()}
          </span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div>
            <h3 className="text-lg font-medium text-gray-900 mb-4">Database Performance</h3>
            <div className="space-y-3">
              <div className="flex justify-between items-center">
                <span className="text-sm text-gray-600">Query Response Time</span>
                <span className="text-sm font-medium">45ms</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm text-gray-600">Active Connections</span>
                <span className="text-sm font-medium">{health.active_connections}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm text-gray-600">Slow Queries</span>
                <span className="text-sm font-medium text-yellow-600">2</span>
              </div>
            </div>
          </div>

          <div>
            <h3 className="text-lg font-medium text-gray-900 mb-4">API Performance</h3>
            <div className="space-y-3">
              <div className="flex justify-between items-center">
                <span className="text-sm text-gray-600">Requests/min</span>
                <span className="text-sm font-medium">1,247</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm text-gray-600">Error Rate</span>
                <span className="text-sm font-medium text-green-600">{health.error_rate}%</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm text-gray-600">Avg Response</span>
                <span className="text-sm font-medium">{Math.round(health.response_time_ms)}ms</span>
              </div>
            </div>
          </div>

          <div>
            <h3 className="text-lg font-medium text-gray-900 mb-4">Storage</h3>
            <div className="space-y-3">
              <div className="flex justify-between items-center">
                <span className="text-sm text-gray-600">Database Size</span>
                <span className="text-sm font-medium">2.3 GB</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm text-gray-600">Files Storage</span>
                <span className="text-sm font-medium">15.7 GB</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm text-gray-600">Backup Status</span>
                <span className="text-sm font-medium text-green-600">Healthy</span>
              </div>
            </div>
          </div>
        </div>
      </Card>

      {/* Alerts */}
      {alerts && alerts.length > 0 && (
        <Card className="p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-6">System Alerts</h2>
          <div className="space-y-4">
            {alerts.map((alert: SystemAlert) => (
              <div
                key={alert.id}
                className={`p-4 rounded-lg border-l-4 ${
                  alert.type === 'critical' ? 'bg-red-50 border-red-500' :
                  alert.type === 'warning' ? 'bg-yellow-50 border-yellow-500' :
                  'bg-blue-50 border-blue-500'
                }`}
              >
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center">
                      <h3 className={`text-lg font-medium ${
                        alert.type === 'critical' ? 'text-red-800' :
                        alert.type === 'warning' ? 'text-yellow-800' :
                        'text-blue-800'
                      }`}>
                        {alert.title}
                      </h3>
                      <span className={`ml-2 inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                        alert.type === 'critical' ? 'bg-red-100 text-red-800' :
                        alert.type === 'warning' ? 'bg-yellow-100 text-yellow-800' :
                        'bg-blue-100 text-blue-800'
                      }`}>
                        {alert.type.toUpperCase()}
                      </span>
                    </div>
                    <p className={`mt-2 text-sm ${
                      alert.type === 'critical' ? 'text-red-700' :
                      alert.type === 'warning' ? 'text-yellow-700' :
                      'text-blue-700'
                    }`}>
                      {alert.description}
                    </p>
                    <p className="mt-1 text-xs text-gray-500">
                      {new Date(alert.timestamp).toLocaleString()}
                    </p>
                  </div>
                  {!alert.acknowledged && (
                    <Button
                      variant="secondary"
                      size="sm"
                      onClick={() => onAcknowledgeAlert(alert.id)}
                    >
                      Acknowledge
                    </Button>
                  )}
                </div>
              </div>
            ))}
          </div>
        </Card>
      )}

      {/* Detailed Metrics */}
      <Card className="p-6">
        <h2 className="text-xl font-semibold text-gray-900 mb-6">Detailed Metrics</h2>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Metric
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Current Value
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Last Updated
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {metrics.map((metric) => (
                <tr key={metric.id}>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    {metric.metric_type.replace('_', ' ').toUpperCase()}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {metric.metric_value} {metric.metric_unit}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${getStatusColor(metric.status)}`}>
                      {metric.status.toUpperCase()}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {new Date(metric.recorded_at).toLocaleString()}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  )
}

export default function SystemHealthPage() {
  const { user } = useAuth()
  const [metrics, setMetrics] = useState<SystemHealthMetric[]>([])
  const [health, setHealth] = useState<SystemHealth>({
    cpu_usage: 0,
    memory_usage: 0,
    active_connections: 0,
    error_rate: 0,
    response_time_ms: 0,
    status: 'normal'
  })
  const [alerts, setAlerts] = useState<SystemAlert[]>([])
  const [loading, setLoading] = useState(true)
  const [autoRefresh, setAutoRefresh] = useState(true)

  useEffect(() => {
    loadSystemData()
  }, [])

  useEffect(() => {
    if (autoRefresh) {
      const interval = setInterval(() => {
        loadSystemData()
      }, 30000) // Refresh every 30 seconds

      return () => clearInterval(interval)
    }
  }, [autoRefresh])

  const loadSystemData = async () => {
    try {
      setLoading(true)

      // Load system health
      const { data: healthData, error: healthError } = await supabase
        .rpc('get_system_health')

      if (healthError) throw healthError

      if (healthData && healthData.length > 0) {
        setHealth(healthData[0])
      }

      // Load metrics
      const { data: metricsData, error: metricsError } = await supabase
        .from('system_health_metrics')
        .select('*')
        .order('recorded_at', { ascending: false })
        .limit(20)

      if (metricsError) throw metricsError

      setMetrics(metricsData || [])

      // Generate mock alerts based on metrics
      const mockAlerts: SystemAlert[] = []
      
      if (healthData?.[0]?.cpu_usage > 90) {
        mockAlerts.push({
          id: 'cpu-high',
          type: 'critical',
          title: 'High CPU Usage',
          description: `CPU usage is at ${Math.round(healthData[0].cpu_usage)}%, which is above the critical threshold.`,
          timestamp: new Date().toISOString(),
          acknowledged: false
        })
      }

      if (healthData?.[0]?.memory_usage > 95) {
        mockAlerts.push({
          id: 'memory-high',
          type: 'critical',
          title: 'High Memory Usage',
          description: `Memory usage is at ${Math.round(healthData[0].memory_usage)}%, which is critically high.`,
          timestamp: new Date().toISOString(),
          acknowledged: false
        })
      }

      if (healthData?.[0]?.response_time_ms > 1000) {
        mockAlerts.push({
          id: 'response-slow',
          type: 'warning',
          title: 'Slow Response Times',
          description: `API response time is ${Math.round(healthData[0].response_time_ms)}ms, which is above acceptable limits.`,
          timestamp: new Date().toISOString(),
          acknowledged: false
        })
      }

      setAlerts(mockAlerts)

    } catch (error) {
      console.error('Error loading system data:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleAcknowledgeAlert = (alertId: string) => {
    setAlerts(prev => prev.map(alert => 
      alert.id === alertId ? { ...alert, acknowledged: true } : alert
    ))
  }

  if (!user || user.role !== 'admin') {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-gray-900 mb-2">Access Denied</h1>
          <p className="text-gray-600">You need admin privileges to access this page.</p>
        </div>
      </div>
    )
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-8">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">System Health</h1>
              <p className="mt-2 text-gray-600">
                Monitor system performance and health metrics in real-time
              </p>
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
              <Button variant="secondary" onClick={loadSystemData}>
                Refresh Now
              </Button>
            </div>
          </div>
        </div>

        <SystemHealthDashboard
          metrics={metrics}
          health={health}
          alerts={alerts}
          onAcknowledgeAlert={handleAcknowledgeAlert}
        />
      </div>
    </div>
  )
}