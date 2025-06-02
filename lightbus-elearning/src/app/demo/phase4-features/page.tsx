'use client'

import { useState } from 'react'
import { useAuth } from '@/hooks/useAuth'
import Button from '@/components/ui/Button'
import Card from '@/components/ui/Card'
import ContentFlagModal from '@/components/moderation/ContentFlagModal'
import ModerationDashboard from '@/components/admin/ModerationDashboard'
import PlatformMetrics from '@/components/admin/PlatformMetrics'
import RealtimeNotifications, { useRealtimeNotifications } from '@/components/common/RealtimeNotifications'
import { 
  ModerationStats, 
  ModerationQueueItem, 
  PlatformMetrics as PlatformMetricsType,
  StudyRoom,
  LiveClassSession 
} from '@/types'

// Mock data for demonstration
const mockModerationStats: ModerationStats = {
  total_flags: 47,
  pending_flags: 12,
  resolved_flags: 35,
  avg_resolution_time_hours: 8.5,
  top_categories: {
    'inappropriate': 15,
    'incorrect': 12,
    'spam': 8,
    'offensive': 7,
    'other': 5
  },
  moderator_performance: {
    'Alice Johnson': 18,
    'Bob Smith': 12,
    'Carol Davis': 7
  }
}

const mockQueueItems: ModerationQueueItem[] = [
  {
    id: '1',
    content_flag_id: 'flag1',
    content_type: 'lesson',
    content_id: 'lesson123',
    priority_score: 85,
    status: 'pending',
    escalation_level: 0,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
    flag: {
      id: 'flag1',
      content_type: 'lesson',
      content_id: 'lesson123',
      reporter_id: 'user1',
      flag_category: 'inappropriate',
      flag_reason: 'Contains offensive language in the lesson content',
      evidence_text: 'Screenshot attached showing problematic content',
      severity_level: 4,
      status: 'pending',
      anonymous_report: false,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      reporter: {
        id: 'user1',
        name: 'John Doe',
        email: 'john@example.com',
        role: 'student',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      }
    }
  },
  {
    id: '2',
    content_flag_id: 'flag2',
    content_type: 'card',
    content_id: 'card456',
    priority_score: 60,
    status: 'pending',
    escalation_level: 0,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
    flag: {
      id: 'flag2',
      content_type: 'card',
      content_id: 'card456',
      reporter_id: 'user2',
      flag_category: 'incorrect',
      flag_reason: 'The answer provided is factually incorrect',
      severity_level: 2,
      status: 'pending',
      anonymous_report: true,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    }
  }
]

const mockPlatformMetrics: PlatformMetricsType = {
  daily_active_users: 1247,
  monthly_active_users: 8932,
  total_lessons: 423,
  total_cards: 5678,
  total_study_sessions: 12453,
  average_session_duration: 23.7,
  completion_rate: 78.3,
  user_satisfaction_score: 4.2,
  revenue_metrics: {
    monthly_revenue: 15420,
    average_revenue_per_user: 12.50,
    churn_rate: 3.2
  },
  growth_metrics: {
    user_growth: 15.3,
    revenue_growth: 22.1,
    engagement_growth: 8.7
  }
}

const mockStudyRoom: StudyRoom = {
  id: 'room1',
  name: 'Advanced Mathematics Study Group',
  description: 'Collaborative study session for calculus',
  host_id: 'user1',
  lesson_id: 'lesson1',
  room_code: '123456',
  max_participants: 10,
  current_participants: 5,
  is_public: true,
  requires_approval: false,
  status: 'active',
  session_config: {},
  started_at: new Date().toISOString(),
  created_at: new Date().toISOString(),
  updated_at: new Date().toISOString(),
  participants: [
    {
      id: 'p1',
      room_id: 'room1',
      user_id: 'user1',
      role: 'host',
      joined_at: new Date().toISOString(),
      is_active: true,
      progress_sync: {},
      last_seen: new Date().toISOString(),
      user: {
        id: 'user1',
        name: 'Alice Johnson',
        email: 'alice@example.com',
        role: 'teacher',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      }
    }
  ]
}

export default function Phase4FeaturesDemo() {
  const { user } = useAuth()
  const [activeDemo, setActiveDemo] = useState<string>('overview')
  const [flagModalOpen, setFlagModalOpen] = useState(false)
  const [selectedContentType, setSelectedContentType] = useState('lesson')
  const [selectedContentId, setSelectedContentId] = useState('demo-content-123')

  const {
    notifications,
    markAsRead,
    dismiss,
    requestNotificationPermission
  } = useRealtimeNotifications()

  const handleFlagSubmit = (flagData: any) => {
    console.log('Content flagged:', flagData)
    // In a real implementation, this would submit to the API
  }

  const handleModerationAction = (itemId: string, action: string, reason: string) => {
    console.log('Moderation action:', { itemId, action, reason })
    // In a real implementation, this would submit to the API
  }

  const handleAssignModerator = (itemId: string, moderatorId: string) => {
    console.log('Moderator assigned:', { itemId, moderatorId })
    // In a real implementation, this would submit to the API
  }

  const handleRefreshModeration = () => {
    console.log('Refreshing moderation data...')
    // In a real implementation, this would reload data
  }

  const handleMetricDrillDown = (metric: string) => {
    console.log('Drilling down into metric:', metric)
    // In a real implementation, this would show detailed analytics
  }

  const renderDemoContent = () => {
    switch (activeDemo) {
      case 'moderation':
        return (
          <div className="space-y-6">
            <div className="mb-6">
              <h2 className="text-2xl font-bold text-gray-900 mb-2">Content Moderation System</h2>
              <p className="text-gray-600">
                Comprehensive content flagging, moderation queue, and automated review system.
              </p>
            </div>

            <div className="flex space-x-4 mb-6">
              <Button
                variant="primary"
                onClick={() => setFlagModalOpen(true)}
              >
                Demo Content Flagging
              </Button>
              <Button
                variant="secondary"
                onClick={() => setActiveDemo('moderation-dashboard')}
              >
                View Moderation Dashboard
              </Button>
            </div>

            <Card className="p-6">
              <h3 className="text-lg font-semibold mb-4">Sample Flagged Content</h3>
              <div className="bg-gray-50 p-4 rounded-lg mb-4">
                <h4 className="font-medium text-gray-900">Introduction to Algebra</h4>
                <p className="text-gray-600 mt-2">
                  This lesson covers the basic principles of algebraic equations...
                </p>
                <div className="mt-3 flex items-center space-x-2">
                  <span className="bg-red-100 text-red-800 px-2 py-1 rounded text-sm">
                    Flagged: Inappropriate Content
                  </span>
                  <span className="text-sm text-gray-500">
                    Reported 2 hours ago
                  </span>
                </div>
              </div>
              
              <div className="flex space-x-2">
                <Button variant="primary" size="sm">Approve</Button>
                <Button variant="secondary" size="sm">Edit</Button>
                <Button variant="danger" size="sm">Remove</Button>
              </div>
            </Card>

            <ContentFlagModal
              isOpen={flagModalOpen}
              onClose={() => setFlagModalOpen(false)}
              contentType={selectedContentType}
              contentId={selectedContentId}
              onSubmit={handleFlagSubmit}
            />
          </div>
        )

      case 'moderation-dashboard':
        return (
          <div className="space-y-6">
            <div className="mb-6">
              <h2 className="text-2xl font-bold text-gray-900 mb-2">Moderation Dashboard</h2>
              <p className="text-gray-600">
                Real-time moderation metrics, queue management, and moderator performance tracking.
              </p>
            </div>
            
            <ModerationDashboard
              stats={mockModerationStats}
              queueItems={mockQueueItems}
              moderators={[
                { id: '1', name: 'Alice Johnson', email: 'alice@example.com', role: 'admin', created_at: '', updated_at: '' },
                { id: '2', name: 'Bob Smith', email: 'bob@example.com', role: 'admin', created_at: '', updated_at: '' },
              ]}
              onRefresh={handleRefreshModeration}
            />
          </div>
        )

      case 'realtime':
        return (
          <div className="space-y-6">
            <div className="mb-6">
              <h2 className="text-2xl font-bold text-gray-900 mb-2">Realtime Features</h2>
              <p className="text-gray-600">
                Live collaborative study sessions, real-time notifications, and synchronized learning.
              </p>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <Card className="p-6">
                <h3 className="text-lg font-semibold mb-4">Live Study Room</h3>
                <div className="bg-blue-50 p-4 rounded-lg mb-4">
                  <h4 className="font-medium text-blue-900">{mockStudyRoom.name}</h4>
                  <p className="text-blue-700 text-sm mt-1">{mockStudyRoom.description}</p>
                  <div className="mt-3 flex items-center justify-between">
                    <span className="text-sm text-blue-600">
                      Code: {mockStudyRoom.room_code}
                    </span>
                    <span className="text-sm text-blue-600">
                      {mockStudyRoom.current_participants}/{mockStudyRoom.max_participants} participants
                    </span>
                  </div>
                </div>
                <div className="space-y-2 mb-4">
                  <div className="flex items-center space-x-2">
                    <div className="w-2 h-2 bg-green-500 rounded-full"></div>
                    <span className="text-sm">Alice (Host) - Currently studying</span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <div className="w-2 h-2 bg-green-500 rounded-full"></div>
                    <span className="text-sm">Bob - Card 5 of 20</span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <div className="w-2 h-2 bg-yellow-500 rounded-full"></div>
                    <span className="text-sm">Carol - Away</span>
                  </div>
                </div>
                <Button variant="primary" className="w-full">
                  Join Study Room
                </Button>
              </Card>

              <Card className="p-6">
                <h3 className="text-lg font-semibold mb-4">Live Class Monitor</h3>
                <div className="space-y-4">
                  <div className="bg-gray-50 p-3 rounded-lg">
                    <div className="flex justify-between items-center">
                      <span className="text-sm font-medium">Active Students</span>
                      <span className="text-lg font-bold text-blue-600">23</span>
                    </div>
                  </div>
                  <div className="bg-gray-50 p-3 rounded-lg">
                    <div className="flex justify-between items-center">
                      <span className="text-sm font-medium">Avg Engagement</span>
                      <span className="text-lg font-bold text-green-600">87%</span>
                    </div>
                  </div>
                  <div className="bg-gray-50 p-3 rounded-lg">
                    <div className="flex justify-between items-center">
                      <span className="text-sm font-medium">Questions Asked</span>
                      <span className="text-lg font-bold text-purple-600">14</span>
                    </div>
                  </div>
                </div>
                <div className="mt-4">
                  <h4 className="text-sm font-medium text-gray-900 mb-2">Recent Activity</h4>
                  <div className="space-y-2 text-sm text-gray-600">
                    <div>• Student completed Card 15</div>
                    <div>• New question: "Can you explain step 3?"</div>
                    <div>• 2 students joined the session</div>
                  </div>
                </div>
              </Card>
            </div>
          </div>
        )

      case 'analytics':
        return (
          <div className="space-y-6">
            <div className="mb-6">
              <h2 className="text-2xl font-bold text-gray-900 mb-2">Platform Analytics</h2>
              <p className="text-gray-600">
                Comprehensive platform metrics, user analytics, and performance insights.
              </p>
            </div>
            
            <PlatformMetrics
              metrics={mockPlatformMetrics}
              timeRange="30d"
              onDrillDown={handleMetricDrillDown}
              showComparisons={true}
            />
          </div>
        )

      case 'notifications':
        return (
          <div className="space-y-6">
            <div className="mb-6">
              <h2 className="text-2xl font-bold text-gray-900 mb-2">Realtime Notifications</h2>
              <p className="text-gray-600">
                Live notification system with cross-device synchronization and smart filtering.
              </p>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <Card className="p-6">
                <h3 className="text-lg font-semibold mb-4">Notification Center</h3>
                <div className="mb-4">
                  <Button
                    variant="primary"
                    onClick={requestNotificationPermission}
                    className="w-full"
                  >
                    Enable Browser Notifications
                  </Button>
                </div>
                
                <div className="space-y-3">
                  <div className="bg-blue-50 p-3 rounded-lg border-l-4 border-blue-500">
                    <h4 className="font-medium text-blue-900">Study Invitation</h4>
                    <p className="text-blue-700 text-sm">Alice invited you to join "Advanced Calculus" study session</p>
                    <div className="mt-2 space-x-2">
                      <Button variant="primary" size="sm">Join</Button>
                      <Button variant="secondary" size="sm">Decline</Button>
                    </div>
                  </div>
                  
                  <div className="bg-green-50 p-3 rounded-lg border-l-4 border-green-500">
                    <h4 className="font-medium text-green-900">Cards Approved</h4>
                    <p className="text-green-700 text-sm">Your 5 flashcards for "Biology Basics" have been approved</p>
                  </div>
                  
                  <div className="bg-orange-50 p-3 rounded-lg border-l-4 border-orange-500">
                    <h4 className="font-medium text-orange-900">Study Reminder</h4>
                    <p className="text-orange-700 text-sm">You have 12 cards due for review in "Spanish Vocabulary"</p>
                  </div>
                </div>
              </Card>

              <Card className="p-6">
                <h3 className="text-lg font-semibold mb-4">Notification Settings</h3>
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <span className="text-sm font-medium">Study Invitations</span>
                    <input type="checkbox" defaultChecked className="rounded" />
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-sm font-medium">Card Approvals</span>
                    <input type="checkbox" defaultChecked className="rounded" />
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-sm font-medium">Study Reminders</span>
                    <input type="checkbox" defaultChecked className="rounded" />
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-sm font-medium">Achievement Unlocked</span>
                    <input type="checkbox" defaultChecked className="rounded" />
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-sm font-medium">System Alerts</span>
                    <input type="checkbox" className="rounded" />
                  </div>
                </div>
                
                <div className="mt-6">
                  <h4 className="text-sm font-medium mb-2">Delivery Methods</h4>
                  <div className="space-y-2">
                    <label className="flex items-center">
                      <input type="checkbox" defaultChecked className="rounded mr-2" />
                      <span className="text-sm">In-app notifications</span>
                    </label>
                    <label className="flex items-center">
                      <input type="checkbox" defaultChecked className="rounded mr-2" />
                      <span className="text-sm">Email notifications</span>
                    </label>
                    <label className="flex items-center">
                      <input type="checkbox" className="rounded mr-2" />
                      <span className="text-sm">Push notifications</span>
                    </label>
                  </div>
                </div>
              </Card>
            </div>
          </div>
        )

      default:
        return (
          <div className="space-y-6">
            <div className="mb-8">
              <h2 className="text-3xl font-bold text-gray-900 mb-4">Phase 4: Moderation, Realtime & Admin Features</h2>
              <p className="text-lg text-gray-600">
                Explore the comprehensive content moderation system, real-time collaborative features, 
                and advanced admin console that complete the Light Bus E-Learning Platform.
              </p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              <Card className="p-6 cursor-pointer hover:shadow-lg transition-shadow" onClick={() => setActiveDemo('moderation')}>
                <div className="w-12 h-12 bg-red-100 rounded-lg flex items-center justify-center mb-4">
                  <svg className="w-6 h-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.664-.833-2.464 0L3.34 16.5c-.77.833.192 2.5 1.732 2.5z" />
                  </svg>
                </div>
                <h3 className="text-lg font-semibold text-gray-900 mb-2">Content Moderation</h3>
                <p className="text-gray-600 text-sm">
                  Advanced content flagging, automated moderation, and comprehensive review workflows for maintaining platform quality.
                </p>
              </Card>

              <Card className="p-6 cursor-pointer hover:shadow-lg transition-shadow" onClick={() => setActiveDemo('realtime')}>
                <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center mb-4">
                  <svg className="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                  </svg>
                </div>
                <h3 className="text-lg font-semibold text-gray-900 mb-2">Realtime Collaboration</h3>
                <p className="text-gray-600 text-sm">
                  Live study rooms, synchronized learning sessions, and real-time progress tracking for collaborative education.
                </p>
              </Card>

              <Card className="p-6 cursor-pointer hover:shadow-lg transition-shadow" onClick={() => setActiveDemo('analytics')}>
                <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center mb-4">
                  <svg className="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                  </svg>
                </div>
                <h3 className="text-lg font-semibold text-gray-900 mb-2">Platform Analytics</h3>
                <p className="text-gray-600 text-sm">
                  Comprehensive metrics, user analytics, learning effectiveness measurement, and business intelligence dashboards.
                </p>
              </Card>

              <Card className="p-6 cursor-pointer hover:shadow-lg transition-shadow" onClick={() => setActiveDemo('notifications')}>
                <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mb-4">
                  <svg className="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-5 5v-5zM4 17h5l5-5v5z" />
                  </svg>
                </div>
                <h3 className="text-lg font-semibold text-gray-900 mb-2">Smart Notifications</h3>
                <p className="text-gray-600 text-sm">
                  Real-time notifications with cross-device sync, smart filtering, and personalized delivery preferences.
                </p>
              </Card>

              <Card className="p-6 cursor-pointer hover:shadow-lg transition-shadow" onClick={() => setActiveDemo('system')}>
                <div className="w-12 h-12 bg-orange-100 rounded-lg flex items-center justify-center mb-4">
                  <svg className="w-6 h-6 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z" />
                  </svg>
                </div>
                <h3 className="text-lg font-semibold text-gray-900 mb-2">System Health</h3>
                <p className="text-gray-600 text-sm">
                  Real-time system monitoring, performance metrics, security auditing, and infrastructure management.
                </p>
              </Card>

              <Card className="p-6 cursor-pointer hover:shadow-lg transition-shadow" onClick={() => setActiveDemo('mobile')}>
                <div className="w-12 h-12 bg-indigo-100 rounded-lg flex items-center justify-center mb-4">
                  <svg className="w-6 h-6 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 18h.01M8 21h8a1 1 0 001-1V4a1 1 0 00-1-1H8a1 1 0 00-1 1v16a1 1 0 001 1z" />
                  </svg>
                </div>
                <h3 className="text-lg font-semibold text-gray-900 mb-2">Mobile Experience</h3>
                <p className="text-gray-600 text-sm">
                  Optimized mobile interfaces, touch gestures, offline capabilities, and responsive design across all features.
                </p>
              </Card>
            </div>

            <Card className="p-8 bg-gradient-to-r from-blue-50 to-purple-50 border-blue-200">
              <div className="text-center">
                <h3 className="text-xl font-semibold text-gray-900 mb-4">
                  🎉 Phase 4 Complete: Enterprise-Ready Platform
                </h3>
                <p className="text-gray-600 mb-6">
                  With Phase 4 implementation, the Light Bus E-Learning Platform now includes comprehensive 
                  moderation systems, real-time collaboration features, advanced analytics, and enterprise-grade 
                  admin tools - making it a production-ready educational platform.
                </p>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-center">
                  <div>
                    <p className="text-2xl font-bold text-blue-600">100%</p>
                    <p className="text-sm text-gray-600">Platform Complete</p>
                  </div>
                  <div>
                    <p className="text-2xl font-bold text-green-600">24/7</p>
                    <p className="text-sm text-gray-600">Monitoring</p>
                  </div>
                  <div>
                    <p className="text-2xl font-bold text-purple-600">Real-time</p>
                    <p className="text-sm text-gray-600">Collaboration</p>
                  </div>
                  <div>
                    <p className="text-2xl font-bold text-orange-600">Enterprise</p>
                    <p className="text-sm text-gray-600">Security</p>
                  </div>
                </div>
              </div>
            </Card>
          </div>
        )
    }
  }

  if (!user) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-gray-900 mb-2">Authentication Required</h1>
          <p className="text-gray-600">Please log in to access the Phase 4 features demo.</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Navigation */}
      <div className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center space-x-8 py-4">
            <Button
              variant={activeDemo === 'overview' ? 'primary' : 'ghost'}
              onClick={() => setActiveDemo('overview')}
            >
              Overview
            </Button>
            <Button
              variant={activeDemo === 'moderation' ? 'primary' : 'ghost'}
              onClick={() => setActiveDemo('moderation')}
            >
              Moderation
            </Button>
            <Button
              variant={activeDemo === 'realtime' ? 'primary' : 'ghost'}
              onClick={() => setActiveDemo('realtime')}
            >
              Realtime
            </Button>
            <Button
              variant={activeDemo === 'analytics' ? 'primary' : 'ghost'}
              onClick={() => setActiveDemo('analytics')}
            >
              Analytics
            </Button>
            <Button
              variant={activeDemo === 'notifications' ? 'primary' : 'ghost'}
              onClick={() => setActiveDemo('notifications')}
            >
              Notifications
            </Button>
          </div>
        </div>
      </div>

      {/* Notification Bell - Always visible */}
      <div className="fixed top-4 right-4 z-50">
        <RealtimeNotifications
          notifications={notifications}
          onMarkAsRead={markAsRead}
          onDismiss={dismiss}
          maxVisible={5}
        />
      </div>

      {/* Main Content */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {renderDemoContent()}
      </div>
    </div>
  )
}