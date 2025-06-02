'use client'

import React, { useState, useEffect } from 'react'
import Link from 'next/link'
import { getCurrentUser, supabase } from '@/lib/supabase'
import { User, TeacherStats } from '@/types'
import Button from '@/components/ui/Button'
import Card from '@/components/ui/Card'
import TeacherLessonList from '@/components/dashboard/teacher/TeacherLessonList'
import ClassAnalyticsSummary from '@/components/dashboard/teacher/ClassAnalyticsSummary'
import TeacherQuickActions from '@/components/dashboard/teacher/TeacherQuickActions'
import RecentStudentActivity from '@/components/dashboard/teacher/RecentStudentActivity'

export default function TeacherDashboard() {
  const [user, setUser] = useState<User | null>(null)
  const [stats, setStats] = useState<TeacherStats | null>(null)
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    fetchUserData()
  }, [])

  const fetchUserData = async () => {
    try {
      const currentUser = await getCurrentUser()
      if (currentUser) {
        // In a real app, you'd fetch from your profiles table
        const userData: User = {
          id: currentUser.id,
          email: currentUser.email || '',
          name: currentUser.user_metadata?.name || currentUser.email?.split('@')[0] || 'Teacher',
          role: 'teacher',
          created_at: currentUser.created_at,
          updated_at: currentUser.updated_at || currentUser.created_at,
        }
        setUser(userData)

        // Fetch real stats using the database function
        try {
          const { data: statsData, error: statsError } = await supabase.rpc('get_teacher_stats')
          
          if (statsError) {
            console.error('Error fetching stats:', statsError)
            // Fallback to mock stats
            setStats({
              total_lessons: 0,
              total_students: 0,
              total_cards_created: 0,
              pending_cards: 0,
              recent_activity: [],
            })
          } else if (statsData?.success) {
            setStats(statsData.data)
          } else {
            throw new Error(statsData?.error || 'Failed to fetch stats')
          }
        } catch (statsErr) {
          console.error('Stats error:', statsErr)
          // Fallback to mock stats
          setStats({
            total_lessons: 0,
            total_students: 0,
            total_cards_created: 0,
            pending_cards: 0,
            recent_activity: [],
          })
        }
      }
    } catch (error) {
      console.error('Error fetching user data:', error)
    } finally {
      setIsLoading(false)
    }
  }

  if (isLoading) {
    return (
      <div className="min-h-screen bg-neutral-white">
        <div className="container-main py-8">
          <div className="animate-pulse">
            <div className="h-8 bg-neutral-gray bg-opacity-20 w-1/3 mb-6"></div>
            <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
              {[1, 2, 3, 4].map((i) => (
                <div key={i} className="h-32 bg-neutral-gray bg-opacity-20"></div>
              ))}
            </div>
          </div>
        </div>
      </div>
    )
  }

  if (!user) {
    return (
      <div className="min-h-screen bg-neutral-white flex items-center justify-center">
        <Card variant="default" padding="lg" className="text-center">
          <h2 className="heading-3 mb-4">Access Denied</h2>
          <p className="text-neutral-gray mb-6">Please sign in to access your dashboard.</p>
          <Link href="/auth/login">
            <Button variant="primary">Sign In</Button>
          </Link>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-neutral-white">
      <div className="container-main py-8">
        {/* Header */}
        <div className="mb-8">
          <h1 className="heading-2 mb-2">
            Welcome, <span className="text-teacher-500">{user.name}</span>! 👨‍🏫
          </h1>
          <p className="body-medium text-neutral-gray">
            Manage your lessons, create engaging content, and track your students' progress.
          </p>
        </div>

        {/* Stats Overview */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <Card variant="primary" padding="lg" className="text-center">
            <div className="text-3xl font-bold text-teacher-500 mb-2">
              {stats?.total_lessons || 0}
            </div>
            <div className="text-sm font-semibold text-neutral-charcoal">Active Lessons</div>
          </Card>

          <Card variant="default" padding="lg" className="text-center">
            <div className="text-3xl font-bold text-learning-500 mb-2">
              {stats?.total_students || 0}
            </div>
            <div className="text-sm font-semibold text-neutral-charcoal">Total Students</div>
          </Card>

          <Card variant="default" padding="lg" className="text-center">
            <div className="text-3xl font-bold text-achievement-500 mb-2">
              {stats?.total_cards_created || 0}
            </div>
            <div className="text-sm font-semibold text-neutral-charcoal">Cards Created</div>
          </Card>

          <Card variant="default" padding="lg" className="text-center">
            <div className="text-3xl font-bold text-focus-500 mb-2">
              {stats?.pending_cards || 0}
            </div>
            <div className="text-sm font-semibold text-neutral-charcoal">Pending Review</div>
          </Card>
        </div>

        {/* Main Content Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Quick Actions - Full width on top */}
          <div className="lg:col-span-3">
            <TeacherQuickActions />
          </div>

          {/* Left Column - Lessons and Analytics */}
          <div className="lg:col-span-2 space-y-8">
            <TeacherLessonList />
            <ClassAnalyticsSummary />
          </div>

          {/* Right Sidebar */}
          <div className="space-y-6">
            <RecentStudentActivity />

            {/* Getting Started */}
            <Card variant="accent" padding="lg">
              <h3 className="heading-4 mb-4">🌟 Getting Started</h3>
              <div className="space-y-3">
                <div className="flex items-center space-x-3 text-sm">
                  <div className="w-6 h-6 bg-focus-500 text-white text-xs flex items-center justify-center font-bold">1</div>
                  <span>Create your first lesson</span>
                </div>
                <div className="flex items-center space-x-3 text-sm text-neutral-gray">
                  <div className="w-6 h-6 bg-neutral-gray text-white text-xs flex items-center justify-center font-bold">2</div>
                  <span>Add students to your lesson</span>
                </div>
                <div className="flex items-center space-x-3 text-sm text-neutral-gray">
                  <div className="w-6 h-6 bg-neutral-gray text-white text-xs flex items-center justify-center font-bold">3</div>
                  <span>Create or upload content</span>
                </div>
                <div className="flex items-center space-x-3 text-sm text-neutral-gray">
                  <div className="w-6 h-6 bg-neutral-gray text-white text-xs flex items-center justify-center font-bold">4</div>
                  <span>Monitor student progress</span>
                </div>
              </div>
            </Card>
          </div>
        </div>

        {/* Help Section */}
        <div className="mt-8">
          <Card variant="default" padding="lg">
            <div className="flex items-start space-x-4">
              <div className="bg-teacher-100 text-teacher-600 p-3 text-2xl">
                🎓
              </div>
              <div>
                <h3 className="heading-4 mb-2">Teaching Tip</h3>
                <p className="text-neutral-gray">
                  The most effective flashcards focus on one concept at a time and use clear, 
                  concise language. Consider adding images or examples to make complex topics more memorable.
                </p>
              </div>
            </div>
          </Card>
        </div>
      </div>
    </div>
  )
}