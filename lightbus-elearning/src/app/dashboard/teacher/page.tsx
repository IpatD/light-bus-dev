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
    <div className="min-h-screen bg-gray-50">
      {/* Main Dashboard Container with Bento Layout */}
      <div className="container mx-auto px-6 py-8 max-w-7xl">
        
        {/* Welcome Hero Bento */}
        <div className="mb-8">
          <div
            className="bg-white border-4 border-black shadow-xl p-8 overflow-hidden relative"
            style={{ backgroundColor: '#ff6b35' }}
          >
            <div className="relative z-10">
              <h1 className="text-4xl font-bold mb-3 text-white">
                Welcome, <span className="text-yellow-200">{user.name}</span>!
                <span className="ml-2">👨‍🏫</span>
              </h1>
              <p className="text-orange-100 text-lg">
                Create amazing lessons, inspire students, and track their progress!
              </p>
            </div>
            <div className="absolute -top-4 -right-4 text-8xl opacity-20">🎓</div>
          </div>
        </div>

        {/* Main Bento Grid Layout */}
        <div className="grid grid-cols-12 gap-6">
          
          {/* Stats Overview Bento - Spans 12 columns */}
          <div className="col-span-12">
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
              {/* Active Lessons Bento */}
              <div className="bg-white border-4 border-black shadow-lg p-6 hover:shadow-xl transition-all duration-300 group">
                <div className="flex items-center justify-between mb-4">
                  <div
                    className="p-3 text-white shadow-lg border-2 border-black"
                    style={{ backgroundColor: '#ff6b35' }}
                  >
                    <span className="text-2xl">📚</span>
                  </div>
                  <div className="text-right">
                    <div
                      className="text-3xl font-bold group-hover:scale-110 transition-transform"
                      style={{ color: '#ff6b35' }}
                    >
                      {stats?.total_lessons || 0}
                    </div>
                    <div className="text-sm font-semibold text-gray-600">Active Lessons</div>
                  </div>
                </div>
                <div className="w-full bg-orange-100 h-3 border-2 border-black">
                  <div
                    className="h-full transition-all duration-500 border-r-2 border-black"
                    style={{
                      backgroundColor: '#ff6b35',
                      width: `${Math.min((stats?.total_lessons || 0) / 10 * 100, 100)}%`
                    }}
                  ></div>
                </div>
              </div>

              {/* Total Students Bento */}
              <div className="bg-white border-4 border-black shadow-lg p-6 hover:shadow-xl transition-all duration-300 group">
                <div className="flex items-center justify-between mb-4">
                  <div
                    className="p-3 text-white shadow-lg border-2 border-black"
                    style={{ backgroundColor: '#ff6b35' }}
                  >
                    <span className="text-2xl">👥</span>
                  </div>
                  <div className="text-right">
                    <div
                      className="text-3xl font-bold group-hover:scale-110 transition-transform"
                      style={{ color: '#ff6b35' }}
                    >
                      {stats?.total_students || 0}
                    </div>
                    <div className="text-sm font-semibold text-gray-600">Total Students</div>
                  </div>
                </div>
                <div className="text-xs font-medium" style={{ color: '#ff6b35' }}>
                  +{Math.floor((stats?.total_students || 0) * 0.1)} this month
                </div>
              </div>

              {/* Cards Created Bento */}
              <div className="bg-white border-4 border-black shadow-lg p-6 hover:shadow-xl transition-all duration-300 group">
                <div className="flex items-center justify-between mb-4">
                  <div
                    className="p-3 text-white shadow-lg border-2 border-black"
                    style={{ backgroundColor: '#ff6b35' }}
                  >
                    <span className="text-2xl">🃏</span>
                  </div>
                  <div className="text-right">
                    <div
                      className="text-3xl font-bold group-hover:scale-110 transition-transform"
                      style={{ color: '#ff6b35' }}
                    >
                      {stats?.total_cards_created || 0}
                    </div>
                    <div className="text-sm font-semibold text-gray-600">Cards Created</div>
                  </div>
                </div>
                <div className="text-xs font-medium" style={{ color: '#ff6b35' }}>
                  All time total
                </div>
              </div>

              {/* Pending Review Bento */}
              <div className="bg-white border-4 border-black shadow-lg p-6 hover:shadow-xl transition-all duration-300 group">
                <div className="flex items-center justify-between mb-4">
                  <div
                    className="p-3 text-white shadow-lg border-2 border-black"
                    style={{ backgroundColor: '#ff6b35' }}
                  >
                    <span className="text-2xl">⏳</span>
                  </div>
                  <div className="text-right">
                    <div
                      className="text-3xl font-bold group-hover:scale-110 transition-transform"
                      style={{ color: '#ff6b35' }}
                    >
                      {stats?.pending_cards || 0}
                    </div>
                    <div className="text-sm font-semibold text-gray-600">Pending Review</div>
                  </div>
                </div>
                <div className="text-xs font-medium" style={{ color: '#ff6b35' }}>
                  Needs attention
                </div>
              </div>
            </div>
          </div>

          {/* Quick Actions Bento - Large */}
          <div className="col-span-12">
            <div className="bg-white border-4 border-black shadow-xl overflow-hidden">
              <div
                className="p-6 text-white border-b-4 border-black"
                style={{ backgroundColor: '#ff6b35' }}
              >
                <div className="flex items-center justify-between">
                  <div>
                    <h2 className="text-2xl font-bold mb-2">🚀 Quick Actions</h2>
                    <p className="text-orange-100">Jump-start your teaching workflow</p>
                  </div>
                  <div className="text-4xl opacity-50">⚡</div>
                </div>
              </div>
              <div className="p-6">
                <TeacherQuickActions />
              </div>
            </div>
          </div>

          {/* Teacher Lessons Bento - Large */}
          <div className="col-span-12 lg:col-span-8">
            <div className="bg-white border-4 border-black shadow-xl overflow-hidden h-full">
              <div
                className="p-6 text-white border-b-4 border-black"
                style={{ backgroundColor: '#ff6b35' }}
              >
                <div className="flex items-center justify-between">
                  <div>
                    <h2 className="text-2xl font-bold mb-2">📚 My Lessons</h2>
                    <p className="text-orange-100">Manage and organize your teaching content</p>
                  </div>
                  <div className="text-4xl opacity-50">📖</div>
                </div>
              </div>
              <div className="p-6">
                <TeacherLessonList />
              </div>
            </div>
          </div>

          {/* Getting Started & Student Activity Bento - Compact */}
          <div className="col-span-12 lg:col-span-4 space-y-6">
            
            {/* Recent Student Activity Compact Bento */}
            <div className="bg-orange-50 border-4 border-black shadow-xl overflow-hidden">
              <div
                className="p-4 text-white border-b-4 border-black"
                style={{ backgroundColor: '#ff6b35' }}
              >
                <h3 className="text-lg font-bold">👥 Student Activity</h3>
                <p className="text-orange-100 text-sm">Latest student progress</p>
              </div>
              <div className="p-4">
                <RecentStudentActivity />
              </div>
            </div>

            {/* Getting Started Compact Bento */}
            <div className="bg-orange-50 border-4 border-black shadow-xl overflow-hidden">
              <div
                className="p-4 text-white border-b-4 border-black"
                style={{ backgroundColor: '#ff6b35' }}
              >
                <h3 className="text-lg font-bold">🌟 Getting Started</h3>
                <p className="text-orange-100 text-sm">Your teaching roadmap</p>
              </div>
              <div className="p-4">
                <div className="space-y-3">
                  <div className="flex items-center space-x-3 text-sm">
                    <div
                      className="w-6 h-6 text-white text-xs flex items-center justify-center font-bold border-2 border-black"
                      style={{ backgroundColor: '#ff6b35' }}
                    >
                      1
                    </div>
                    <span>Create your first lesson</span>
                  </div>
                  <div className="flex items-center space-x-3 text-sm text-neutral-gray">
                    <div className="w-6 h-6 bg-neutral-gray text-white text-xs flex items-center justify-center font-bold border-2 border-black">2</div>
                    <span>Add students to your lesson</span>
                  </div>
                  <div className="flex items-center space-x-3 text-sm text-neutral-gray">
                    <div className="w-6 h-6 bg-neutral-gray text-white text-xs flex items-center justify-center font-bold border-2 border-black">3</div>
                    <span>Create or upload content</span>
                  </div>
                  <div className="flex items-center space-x-3 text-sm text-neutral-gray">
                    <div className="w-6 h-6 bg-neutral-gray text-white text-xs flex items-center justify-center font-bold border-2 border-black">4</div>
                    <span>Monitor student progress</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Analytics Bento - Wide */}
          <div className="col-span-12 lg:col-span-8">
            <div className="bg-white border-4 border-black shadow-xl overflow-hidden">
              <div
                className="p-6 text-white border-b-4 border-black"
                style={{ backgroundColor: '#ff6b35' }}
              >
                <div className="flex items-center justify-between">
                  <div>
                    <h2 className="text-2xl font-bold mb-2">📊 Class Analytics</h2>
                    <p className="text-orange-100">Track student performance and engagement</p>
                  </div>
                  <div className="text-4xl opacity-50">📈</div>
                </div>
              </div>
              <div className="p-6">
                <ClassAnalyticsSummary />
              </div>
            </div>
          </div>

          {/* Teaching Tip Bento - Compact */}
          <div className="col-span-12 lg:col-span-4">
            <div className="bg-orange-50 border-4 border-black shadow-xl overflow-hidden h-full">
              <div
                className="p-4 text-white border-b-4 border-black"
                style={{ backgroundColor: '#ff6b35' }}
              >
                <h3 className="text-lg font-bold">💡 Teaching Tip</h3>
                <p className="text-orange-100 text-sm">Expert advice</p>
              </div>
              <div className="p-4">
                <div className="flex items-start space-x-4">
                  <div
                    className="p-3 text-2xl border-2 border-black"
                    style={{ backgroundColor: '#ff6b35', color: 'white' }}
                  >
                    🎓
                  </div>
                  <div>
                    <h4 className="font-semibold mb-2">Effective Flashcards</h4>
                    <p className="text-sm text-neutral-gray">
                      Focus on one concept at a time and use clear, concise language. Consider adding images or examples to make complex topics more memorable.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Footer Spacer */}
        <div className="mt-12"></div>
      </div>
    </div>
  )
}