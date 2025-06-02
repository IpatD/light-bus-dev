'use client'

import { useState, useEffect } from 'react'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/hooks/useAuth'
import { RealtimeNotificationsProps, RealtimeNotification } from '@/types'
import Button from '@/components/ui/Button'

const RealtimeNotifications: React.FC<RealtimeNotificationsProps> = ({
  notifications,
  onMarkAsRead,
  onDismiss,
  maxVisible = 5
}) => {
  const { user } = useAuth()
  const [isOpen, setIsOpen] = useState(false)
  const [unreadCount, setUnreadCount] = useState(0)

  useEffect(() => {
    const unread = notifications.filter(n => !n.read_at).length
    setUnreadCount(unread)
  }, [notifications])

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case 'urgent': return 'bg-red-100 border-red-500 text-red-800'
      case 'high': return 'bg-orange-100 border-orange-500 text-orange-800'
      case 'normal': return 'bg-blue-100 border-blue-500 text-blue-800'
      case 'low': return 'bg-gray-100 border-gray-500 text-gray-800'
      default: return 'bg-blue-100 border-blue-500 text-blue-800'
    }
  }

  const getNotificationIcon = (type: string) => {
    switch (type) {
      case 'study_invitation':
        return (
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
          </svg>
        )
      case 'lesson_update':
        return (
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
          </svg>
        )
      case 'card_approved':
        return (
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        )
      case 'achievement_unlocked':
        return (
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z" />
          </svg>
        )
      case 'reminder':
        return (
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        )
      case 'system_alert':
        return (
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.664-.833-2.464 0L3.34 16.5c-.77.833.192 2.5 1.732 2.5z" />
          </svg>
        )
      default:
        return (
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-5 5v-5zM9 7H4l5-5v5zm6 10V7h2a2 2 0 012 2v8a2 2 0 01-2 2h-2z" />
          </svg>
        )
    }
  }

  const formatTimeAgo = (timestamp: string) => {
    const now = new Date()
    const time = new Date(timestamp)
    const diffInSeconds = Math.floor((now.getTime() - time.getTime()) / 1000)

    if (diffInSeconds < 60) return 'Just now'
    if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)}m ago`
    if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)}h ago`
    return `${Math.floor(diffInSeconds / 86400)}d ago`
  }

  const visibleNotifications = notifications.slice(0, maxVisible)
  const hasMore = notifications.length > maxVisible

  return (
    <div className="relative">
      {/* Notification Bell */}
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="relative p-2 text-gray-600 hover:text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500 rounded-full"
      >
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-5 5v-5zM4 17h5l5-5v5z" />
        </svg>
        
        {unreadCount > 0 && (
          <span className="absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full h-5 w-5 flex items-center justify-center">
            {unreadCount > 9 ? '9+' : unreadCount}
          </span>
        )}
      </button>

      {/* Notification Dropdown */}
      {isOpen && (
        <div className="absolute right-0 mt-2 w-96 bg-white rounded-lg shadow-lg border border-gray-200 z-50">
          <div className="p-4 border-b border-gray-200">
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-semibold text-gray-900">Notifications</h3>
              {unreadCount > 0 && (
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => {
                    notifications.filter(n => !n.read_at).forEach(n => onMarkAsRead(n.id))
                  }}
                >
                  Mark all read
                </Button>
              )}
            </div>
          </div>

          <div className="max-h-96 overflow-y-auto">
            {visibleNotifications.length === 0 ? (
              <div className="p-8 text-center">
                <svg className="w-12 h-12 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-5 5v-5zM4 17h5l5-5v5z" />
                </svg>
                <p className="text-gray-500">No notifications yet</p>
              </div>
            ) : (
              <div className="divide-y divide-gray-100">
                {visibleNotifications.map((notification) => (
                  <div
                    key={notification.id}
                    className={`p-4 hover:bg-gray-50 transition-colors ${
                      !notification.read_at ? 'bg-blue-50' : ''
                    }`}
                  >
                    <div className="flex items-start space-x-3">
                      <div className={`flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center ${getPriorityColor(notification.priority)}`}>
                        {getNotificationIcon(notification.notification_type)}
                      </div>
                      
                      <div className="flex-1 min-w-0">
                        <div className="flex items-start justify-between">
                          <div className="flex-1">
                            <p className="text-sm font-medium text-gray-900">
                              {notification.title}
                            </p>
                            <p className="text-sm text-gray-600 mt-1">
                              {notification.message}
                            </p>
                            <p className="text-xs text-gray-500 mt-2">
                              {formatTimeAgo(notification.created_at)}
                            </p>
                          </div>
                          
                          <div className="flex items-center space-x-1 ml-4">
                            {!notification.read_at && (
                              <button
                                onClick={() => onMarkAsRead(notification.id)}
                                className="p-1 text-gray-400 hover:text-gray-600 rounded"
                                title="Mark as read"
                              >
                                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                                </svg>
                              </button>
                            )}
                            
                            <button
                              onClick={() => onDismiss(notification.id)}
                              className="p-1 text-gray-400 hover:text-gray-600 rounded"
                              title="Dismiss"
                            >
                              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                              </svg>
                            </button>
                          </div>
                        </div>

                        {/* Action buttons for specific notification types */}
                        {notification.notification_type === 'study_invitation' && notification.data?.room_code && (
                          <div className="mt-3 flex space-x-2">
                            <Button
                              variant="primary"
                              size="sm"
                              onClick={() => {
                                // Navigate to study room
                                window.location.href = `/study/room/${notification.data.room_code}`
                              }}
                            >
                              Join Room
                            </Button>
                            <Button
                              variant="secondary"
                              size="sm"
                              onClick={() => onDismiss(notification.id)}
                            >
                              Decline
                            </Button>
                          </div>
                        )}

                        {notification.notification_type === 'lesson_update' && notification.data?.lesson_id && (
                          <div className="mt-3">
                            <Button
                              variant="primary"
                              size="sm"
                              onClick={() => {
                                // Navigate to lesson
                                window.location.href = `/lessons/${notification.data.lesson_id}`
                              }}
                            >
                              View Lesson
                            </Button>
                          </div>
                        )}

                        {notification.notification_type === 'card_approved' && notification.data?.lesson_id && (
                          <div className="mt-3">
                            <Button
                              variant="primary"
                              size="sm"
                              onClick={() => {
                                // Navigate to study session
                                window.location.href = `/study/${notification.data.lesson_id}`
                              }}
                            >
                              Study Now
                            </Button>
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}

            {hasMore && (
              <div className="p-4 border-t border-gray-200">
                <Button
                  variant="ghost"
                  className="w-full"
                  onClick={() => {
                    // Navigate to full notifications page
                    window.location.href = '/notifications'
                  }}
                >
                  View all notifications ({notifications.length})
                </Button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Backdrop */}
      {isOpen && (
        <div
          className="fixed inset-0 z-40"
          onClick={() => setIsOpen(false)}
        />
      )}
    </div>
  )
}

// Hook for managing realtime notifications
export const useRealtimeNotifications = () => {
  const { user } = useAuth()
  const [notifications, setNotifications] = useState<RealtimeNotification[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!user) return

    loadNotifications()
    subscribeToNotifications()
  }, [user])

  const loadNotifications = async () => {
    try {
      const { data, error } = await supabase
        .from('realtime_notifications')
        .select('*')
        .eq('user_id', user?.id)
        .order('created_at', { ascending: false })
        .limit(50)

      if (error) throw error
      setNotifications(data || [])
    } catch (error) {
      console.error('Error loading notifications:', error)
    } finally {
      setLoading(false)
    }
  }

  const subscribeToNotifications = () => {
    const channel = supabase
      .channel(`notifications:${user?.id}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'realtime_notifications',
          filter: `user_id=eq.${user?.id}`
        },
        (payload) => {
          const newNotification = payload.new as RealtimeNotification
          setNotifications(prev => [newNotification, ...prev])
          
          // Show browser notification if permission granted
          if (Notification.permission === 'granted') {
            new Notification(newNotification.title, {
              body: newNotification.message,
              icon: '/favicon.ico'
            })
          }
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'realtime_notifications',
          filter: `user_id=eq.${user?.id}`
        },
        (payload) => {
          const updatedNotification = payload.new as RealtimeNotification
          setNotifications(prev => 
            prev.map(n => n.id === updatedNotification.id ? updatedNotification : n)
          )
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }

  const markAsRead = async (notificationId: string) => {
    try {
      const { error } = await supabase
        .from('realtime_notifications')
        .update({ read_at: new Date().toISOString() })
        .eq('id', notificationId)

      if (error) throw error

      setNotifications(prev =>
        prev.map(n => 
          n.id === notificationId 
            ? { ...n, read_at: new Date().toISOString() }
            : n
        )
      )
    } catch (error) {
      console.error('Error marking notification as read:', error)
    }
  }

  const dismiss = async (notificationId: string) => {
    try {
      const { error } = await supabase
        .from('realtime_notifications')
        .update({ dismissed_at: new Date().toISOString() })
        .eq('id', notificationId)

      if (error) throw error

      setNotifications(prev => prev.filter(n => n.id !== notificationId))
    } catch (error) {
      console.error('Error dismissing notification:', error)
    }
  }

  // Request notification permission
  const requestNotificationPermission = async () => {
    if ('Notification' in window) {
      const permission = await Notification.requestPermission()
      return permission === 'granted'
    }
    return false
  }

  return {
    notifications,
    loading,
    markAsRead,
    dismiss,
    requestNotificationPermission,
    refresh: loadNotifications
  }
}

export default RealtimeNotifications