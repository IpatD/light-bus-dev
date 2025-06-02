'use client'

import { useState, useEffect } from 'react'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/hooks/useAuth'
import { ModerationQueueItem, ModerationStats, User } from '@/types'
import Button from '@/components/ui/Button'
import Card from '@/components/ui/Card'
import Modal from '@/components/ui/Modal'

interface ModerationQueueProps {
  queueItems: ModerationQueueItem[]
  onActionTaken: (itemId: string, action: string, reason: string) => void
  onAssignModerator: (itemId: string, moderatorId: string) => void
  showBulkActions?: boolean
  currentUser: User
}

const ModerationQueue: React.FC<ModerationQueueProps> = ({
  queueItems,
  onActionTaken,
  onAssignModerator,
  showBulkActions = true,
  currentUser
}) => {
  const [selectedItems, setSelectedItems] = useState<string[]>([])
  const [actionModal, setActionModal] = useState<{
    isOpen: boolean
    itemId?: string
    action?: string
  }>({ isOpen: false })
  const [actionReason, setActionReason] = useState('')

  const handleSelectItem = (itemId: string) => {
    setSelectedItems(prev => 
      prev.includes(itemId) 
        ? prev.filter(id => id !== itemId)
        : [...prev, itemId]
    )
  }

  const handleAction = (itemId: string, action: string) => {
    setActionModal({ isOpen: true, itemId, action })
  }

  const confirmAction = () => {
    if (actionModal.itemId && actionModal.action) {
      onActionTaken(actionModal.itemId, actionModal.action, actionReason)
      setActionModal({ isOpen: false })
      setActionReason('')
    }
  }

  const getPriorityColor = (score: number) => {
    if (score >= 80) return 'bg-red-100 text-red-800'
    if (score >= 60) return 'bg-orange-100 text-orange-800'
    if (score >= 40) return 'bg-yellow-100 text-yellow-800'
    return 'bg-green-100 text-green-800'
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'pending': return 'bg-gray-100 text-gray-800'
      case 'in_progress': return 'bg-blue-100 text-blue-800'
      case 'completed': return 'bg-green-100 text-green-800'
      case 'escalated': return 'bg-red-100 text-red-800'
      default: return 'bg-gray-100 text-gray-800'
    }
  }

  return (
    <div className="space-y-6">
      {showBulkActions && selectedItems.length > 0 && (
        <Card className="p-4 bg-blue-50 border-blue-200">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium text-blue-800">
              {selectedItems.length} items selected
            </span>
            <div className="space-x-2">
              <Button
                variant="primary"
                size="sm"
                onClick={() => {
                  selectedItems.forEach(id => onActionTaken(id, 'approve', 'Bulk approval'))
                  setSelectedItems([])
                }}
              >
                Bulk Approve
              </Button>
              <Button
                variant="secondary"
                size="sm"
                onClick={() => {
                  selectedItems.forEach(id => onActionTaken(id, 'reject', 'Bulk rejection'))
                  setSelectedItems([])
                }}
              >
                Bulk Reject
              </Button>
            </div>
          </div>
        </Card>
      )}

      <div className="grid gap-4">
        {queueItems.map((item) => (
          <Card key={item.id} className="p-6">
            <div className="flex items-start justify-between">
              <div className="flex items-start space-x-4">
                {showBulkActions && (
                  <input
                    type="checkbox"
                    checked={selectedItems.includes(item.id)}
                    onChange={() => handleSelectItem(item.id)}
                    className="mt-1 h-4 w-4 text-blue-600 rounded border-gray-300"
                  />
                )}
                <div className="flex-1">
                  <div className="flex items-center space-x-2 mb-2">
                    <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${getPriorityColor(item.priority_score)}`}>
                      Priority: {item.priority_score}
                    </span>
                    <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${getStatusColor(item.status)}`}>
                      {item.status.replace('_', ' ').toUpperCase()}
                    </span>
                    <span className="text-xs text-gray-500">
                      {item.content_type.toUpperCase()}
                    </span>
                  </div>
                  
                  {item.flag && (
                    <div className="mb-4">
                      <h3 className="font-semibold text-gray-900 mb-2">
                        {item.flag.flag_category.replace('_', ' ').toUpperCase()} - {item.flag.flag_reason}
                      </h3>
                      {item.flag.evidence_text && (
                        <p className="text-sm text-gray-600 mb-2">
                          <strong>Evidence:</strong> {item.flag.evidence_text}
                        </p>
                      )}
                      <p className="text-xs text-gray-500">
                        Reported by: {item.flag.anonymous_report ? 'Anonymous' : item.flag.reporter?.name || 'Unknown'} on {new Date(item.flag.created_at).toLocaleDateString()}
                      </p>
                    </div>
                  )}

                  {item.context_data && (
                    <div className="bg-gray-50 p-3 rounded-lg mb-4">
                      <h4 className="text-sm font-medium text-gray-900 mb-2">Content Preview</h4>
                      <div className="text-sm text-gray-600">
                        {JSON.stringify(item.context_data, null, 2).slice(0, 200)}...
                      </div>
                    </div>
                  )}

                  {item.review_deadline && (
                    <p className="text-xs text-gray-500 mb-2">
                      <strong>Deadline:</strong> {new Date(item.review_deadline).toLocaleString()}
                    </p>
                  )}

                  {item.assigned_moderator_id && (
                    <p className="text-xs text-gray-500">
                      <strong>Assigned to:</strong> {item.moderator?.name || 'Unknown Moderator'}
                    </p>
                  )}
                </div>
              </div>

              <div className="flex flex-col space-y-2">
                {item.status === 'pending' && (
                  <>
                    <Button
                      variant="primary"
                      size="sm"
                      onClick={() => handleAction(item.id, 'approve')}
                    >
                      Approve
                    </Button>
                    <Button
                      variant="secondary"
                      size="sm"
                      onClick={() => handleAction(item.id, 'reject')}
                    >
                      Reject
                    </Button>
                    <Button
                      variant="danger"
                      size="sm"
                      onClick={() => handleAction(item.id, 'remove')}
                    >
                      Remove Content
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => handleAction(item.id, 'escalate')}
                    >
                      Escalate
                    </Button>
                  </>
                )}
                
                {!item.assigned_moderator_id && item.status === 'pending' && (
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => onAssignModerator(item.id, currentUser.id)}
                  >
                    Assign to Me
                  </Button>
                )}
              </div>
            </div>
          </Card>
        ))}
      </div>

      <Modal
        isOpen={actionModal.isOpen}
        onClose={() => setActionModal({ isOpen: false })}
        title={`Confirm ${actionModal.action?.toUpperCase()}`}
      >
        <div className="space-y-4">
          <p className="text-sm text-gray-600">
            Please provide a reason for this action:
          </p>
          <textarea
            value={actionReason}
            onChange={(e) => setActionReason(e.target.value)}
            className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            rows={3}
            placeholder="Enter reason for this action..."
            required
          />
          <div className="flex justify-end space-x-2">
            <Button
              variant="secondary"
              onClick={() => setActionModal({ isOpen: false })}
            >
              Cancel
            </Button>
            <Button
              variant="primary"
              onClick={confirmAction}
              disabled={!actionReason.trim()}
            >
              Confirm Action
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  )
}

export default function ModerationPage() {
  const { user } = useAuth()
  const [queueItems, setQueueItems] = useState<ModerationQueueItem[]>([])
  const [stats, setStats] = useState<ModerationStats | null>(null)
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState<'all' | 'pending' | 'in_progress' | 'escalated'>('pending')

  useEffect(() => {
    loadModerationData()
  }, [filter])

  const loadModerationData = async () => {
    try {
      setLoading(true)
      
      // Load queue items
      let query = supabase
        .from('moderation_queue')
        .select(`
          *,
          flag:content_flags(*,
            reporter:profiles!content_flags_reporter_id_fkey(id, name, email)
          ),
          moderator:profiles!moderation_queue_assigned_moderator_id_fkey(id, name, email)
        `)
        .order('priority_score', { ascending: false })

      if (filter !== 'all') {
        query = query.eq('status', filter)
      }

      const { data: queueData, error: queueError } = await query

      if (queueError) throw queueError

      setQueueItems(queueData || [])

      // Load stats
      const { data: statsData, error: statsError } = await supabase
        .rpc('get_moderation_stats')

      if (statsError) throw statsError

      setStats(statsData?.[0] || null)

    } catch (error) {
      console.error('Error loading moderation data:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleActionTaken = async (itemId: string, action: string, reason: string) => {
    try {
      const { error } = await supabase
        .rpc('process_moderation_queue', {
          p_queue_id: itemId,
          p_action_type: action,
          p_action_reason: reason
        })

      if (error) throw error

      // Reload data
      loadModerationData()
    } catch (error) {
      console.error('Error processing moderation action:', error)
    }
  }

  const handleAssignModerator = async (itemId: string, moderatorId: string) => {
    try {
      const { error } = await supabase
        .from('moderation_queue')
        .update({ 
          assigned_moderator_id: moderatorId,
          status: 'in_progress' 
        })
        .eq('id', itemId)

      if (error) throw error

      // Reload data
      loadModerationData()
    } catch (error) {
      console.error('Error assigning moderator:', error)
    }
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
          <h1 className="text-3xl font-bold text-gray-900">Content Moderation</h1>
          <p className="mt-2 text-gray-600">
            Review and moderate flagged content across the platform
          </p>
        </div>

        {/* Stats Overview */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
            <Card className="p-6">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <div className="w-8 h-8 bg-blue-500 rounded-full flex items-center justify-center">
                    <span className="text-white text-sm font-semibold">T</span>
                  </div>
                </div>
                <div className="ml-4">
                  <p className="text-sm font-medium text-gray-500">Total Flags</p>
                  <p className="text-2xl font-semibold text-gray-900">{stats.total_flags}</p>
                </div>
              </div>
            </Card>

            <Card className="p-6">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <div className="w-8 h-8 bg-yellow-500 rounded-full flex items-center justify-center">
                    <span className="text-white text-sm font-semibold">P</span>
                  </div>
                </div>
                <div className="ml-4">
                  <p className="text-sm font-medium text-gray-500">Pending</p>
                  <p className="text-2xl font-semibold text-gray-900">{stats.pending_flags}</p>
                </div>
              </div>
            </Card>

            <Card className="p-6">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <div className="w-8 h-8 bg-green-500 rounded-full flex items-center justify-center">
                    <span className="text-white text-sm font-semibold">R</span>
                  </div>
                </div>
                <div className="ml-4">
                  <p className="text-sm font-medium text-gray-500">Resolved</p>
                  <p className="text-2xl font-semibold text-gray-900">{stats.resolved_flags}</p>
                </div>
              </div>
            </Card>

            <Card className="p-6">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <div className="w-8 h-8 bg-purple-500 rounded-full flex items-center justify-center">
                    <span className="text-white text-sm font-semibold">A</span>
                  </div>
                </div>
                <div className="ml-4">
                  <p className="text-sm font-medium text-gray-500">Avg Resolution</p>
                  <p className="text-2xl font-semibold text-gray-900">
                    {Math.round(stats.avg_resolution_time_hours)}h
                  </p>
                </div>
              </div>
            </Card>
          </div>
        )}

        {/* Filter Tabs */}
        <div className="mb-6">
          <div className="border-b border-gray-200">
            <nav className="-mb-px flex space-x-8">
              {[
                { key: 'pending', label: 'Pending', count: stats?.pending_flags || 0 },
                { key: 'in_progress', label: 'In Progress', count: 0 },
                { key: 'escalated', label: 'Escalated', count: 0 },
                { key: 'all', label: 'All', count: stats?.total_flags || 0 },
              ].map((tab) => (
                <button
                  key={tab.key}
                  onClick={() => setFilter(tab.key as any)}
                  className={`py-2 px-1 border-b-2 font-medium text-sm ${
                    filter === tab.key
                      ? 'border-blue-500 text-blue-600'
                      : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                  }`}
                >
                  {tab.label} ({tab.count})
                </button>
              ))}
            </nav>
          </div>
        </div>

        {/* Queue Items */}
        {queueItems.length === 0 ? (
          <Card className="p-12 text-center">
            <div className="w-12 h-12 mx-auto bg-gray-100 rounded-full flex items-center justify-center mb-4">
              <span className="text-gray-400 text-xl">✓</span>
            </div>
            <h3 className="text-lg font-medium text-gray-900 mb-2">No items to review</h3>
            <p className="text-gray-500">
              {filter === 'pending' 
                ? "Great! There are no pending moderation items."
                : `No ${filter.replace('_', ' ')} items found.`
              }
            </p>
          </Card>
        ) : (
          <ModerationQueue
            queueItems={queueItems}
            onActionTaken={handleActionTaken}
            onAssignModerator={handleAssignModerator}
            currentUser={user}
          />
        )}
      </div>
    </div>
  )
}