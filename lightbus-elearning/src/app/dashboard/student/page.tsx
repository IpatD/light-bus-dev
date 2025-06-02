'use client'

import React, { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabase'
import { User, UserStats } from '@/types'
import Button from '@/components/ui/Button'
import Card from '@/components/ui/Card'
import ProgressChart from '@/components/dashboard/student/ProgressChart'
import DueCardsSection from '@/components/dashboard/student/DueCardsSection'
import StudyStreakCard from '@/components/dashboard/student/StudyStreakCard'
import RecentLessonsSection from '@/components/dashboard/student/RecentLessonsSection'

interface DueCard {
  id: string
  lesson_id: string
  lesson_name: string
  front_content: string
  difficulty_level: number
  scheduled_for: string
  is_overdue: boolean
}

interface LessonProgress {
  lesson_id: string
  lesson_name: string
  teacher_name: string
  scheduled_at: string
  cards_total: number
  cards_reviewed: number
  cards_learned: number
  cards_due: number
  average_quality: number
  progress_percentage: number
  next_review_date?: string
  last_activity?: string
}

export default function StudentDashboard() {
  const router = useRouter()
  const [user, setUser] = useState<User | null>(null)
  const [stats, setStats] = useState<UserStats | null>(null)
  const [dueCards, setDueCards] = useState<DueCard[]>([])
  const [recentLessons, setRecentLessons] = useState<LessonProgress[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [chartType, setChartType] = useState<'weekly' | 'monthly'>('weekly')

  useEffect(() => {
    fetchDashboardData()
  }, [])

  const fetchDashboardData = async () => {
    try {
      setIsLoading(true)
      
      // Get current user
      const { data: { user: authUser }, error: userError } = await supabase.auth.getUser()
      if (userError || !authUser) {
        router.push('/auth/login')
        return
      }

      // Get user profile
      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', authUser.id)
        .single()

      if (profileError) throw profileError

      const userData: User = {
        id: profile.id,
        email: profile.email,
        name: profile.name,
        role: profile.role,
        created_at: profile.created_at,
        updated_at: profile.updated_at,
      }
      setUser(userData)

      // Get comprehensive user statistics
      const { data: userStats, error: statsError } = await supabase
        .rpc('get_user_stats', { p_user_id: authUser.id })

      if (statsError) {
        console.error('Error fetching user stats:', statsError)
        // Use fallback stats
        setStats({
          total_reviews: 0,
          average_quality: 0.0,
          study_streak: 0,
          cards_learned: 0,
          cards_due_today: 0,
          next_review_date: undefined,
          weekly_progress: [0, 0, 0, 0, 0, 0, 0],
          monthly_progress: new Array(30).fill(0),
        })
      } else if (userStats && userStats.length > 0) {
        const stats = userStats[0]
        setStats({
          total_reviews: Number(stats.total_reviews) || 0,
          average_quality: Number(stats.average_quality) || 0.0,
          study_streak: Number(stats.study_streak) || 0,
          cards_learned: Number(stats.cards_learned) || 0,
          cards_due_today: Number(stats.cards_due_today) || 0,
          next_review_date: stats.next_review_date,
          weekly_progress: stats.weekly_progress || [0, 0, 0, 0, 0, 0, 0],
          monthly_progress: stats.monthly_progress || new Array(30).fill(0),
        })
      }

      // Get due cards
      const { data: dueCardsData, error: dueCardsError } = await supabase
        .rpc('get_cards_due', {
          p_user_id: authUser.id,
          p_limit_count: 10
        })

      if (dueCardsError) {
        console.error('Error fetching due cards:', dueCardsError)
        setDueCards([])
      } else if (dueCardsData) {
        // Transform and enrich the data
        const transformedCards: DueCard[] = await Promise.all(
          dueCardsData.map(async (item: any) => {
            // Get lesson name
            const { data: lesson } = await supabase
              .from('lessons')
              .select('name')
              .eq('id', item.lesson_id)
              .single()

            const scheduledDate = new Date(item.scheduled_for)
            const now = new Date()
            
            return {
              id: item.card_id,
              lesson_id: item.lesson_id,
              lesson_name: lesson?.name || 'Unknown Lesson',
              front_content: item.front_content,
              difficulty_level: item.difficulty_level,
              scheduled_for: item.scheduled_for,
              is_overdue: scheduledDate < now
            }
          })
        )
        setDueCards(transformedCards)
      }

      // Get lesson progress
      const { data: lessonsData, error: lessonsError } = await supabase
        .rpc('get_lesson_progress', { p_student_id: authUser.id })

      if (lessonsError) {
        console.error('Error fetching lesson progress:', lessonsError)
        setRecentLessons([])
      } else if (lessonsData) {
        // Transform and enrich lesson data
        const transformedLessons: LessonProgress[] = await Promise.all(
          lessonsData.slice(0, 5).map(async (item: any) => {
            // Get teacher name and lesson details
            const { data: lesson } = await supabase
              .from('lessons')
              .select(`
                scheduled_at,
                teacher_id,
                profiles!lessons_teacher_id_fkey(name)
              `)
              .eq('id', item.lesson_id)
              .single()

            // Get last activity
            const { data: lastReview } = await supabase
              .from('sr_reviews')
              .select('completed_at')
              .eq('student_id', authUser.id)
              .not('completed_at', 'is', null)
              .order('completed_at', { ascending: false })
              .limit(1)
              .single()

            return {
              lesson_id: item.lesson_id,
              lesson_name: item.lesson_name,
              teacher_name: (lesson?.profiles as any)?.name || 'Unknown Teacher',
              scheduled_at: lesson?.scheduled_at || new Date().toISOString(),
              cards_total: item.cards_total || 0,
              cards_reviewed: item.cards_reviewed || 0,
              cards_learned: item.cards_learned || 0,
              cards_due: item.cards_due || 0,
              average_quality: Number(item.average_quality) || 0,
              progress_percentage: Number(item.progress_percentage) || 0,
              next_review_date: item.next_review_date,
              last_activity: lastReview?.completed_at
            }
          })
        )
        setRecentLessons(transformedLessons)
      }

    } catch (error) {
      console.error('Error fetching dashboard data:', error)
    } finally {
      setIsLoading(false)
    }
  }

  const handleStartStudySession = (lessonId?: string) => {
    if (lessonId) {
      router.push(`/study/${lessonId}`)
    } else {
      // Start general study session with all due cards
      router.push('/study/all')
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
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
              <div className="lg:col-span-2 h-96 bg-neutral-gray bg-opacity-20"></div>
              <div className="space-y-6">
                <div className="h-48 bg-neutral-gray bg-opacity-20"></div>
                <div className="h-48 bg-neutral-gray bg-opacity-20"></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    )
  }

  if (!user) {
    return (
      <div className="bg-neutral-white flex items-center justify-center">
        <Card variant="default" padding="lg" className="text-center">
          <h2 className="heading-3 mb-4">Access Denied</h2>
          <p className="text-neutral-gray mb-6">Please sign in to access your dashboard.</p>
          <Button variant="primary" onClick={() => router.push('/auth/login')}>
            Sign In
          </Button>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-neutral-white to-gray-50">
      {/* Main Dashboard Container */}
      <div className="container mx-auto px-4 py-8 max-w-7xl">
        
        {/* Welcome Header Section */}
        <section className="mb-10">
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-8">
            <h1 className="heading-2 mb-3">
              Welcome back, <span className="text-learning-500">{user.name}</span>! 🎓
            </h1>
            <p className="body-medium text-neutral-gray">
              Ready to continue your learning journey? Let's see what's waiting for you today.
            </p>
          </div>
        </section>

        {/* Key Metrics Overview */}
        <section className="mb-10">
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
            <h2 className="heading-4 mb-6 text-neutral-charcoal">📊 Today's Overview</h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
              <div className="bg-gradient-to-br from-learning-500 to-learning-600 text-white rounded-xl p-6 text-center shadow-lg">
                <div className="text-3xl font-bold mb-2">
                  {stats?.cards_due_today || 0}
                </div>
                <div className="text-sm font-semibold opacity-90">Cards Due Today</div>
              </div>

              <div className="bg-gradient-to-br from-achievement-500 to-achievement-600 text-white rounded-xl p-6 text-center shadow-lg">
                <div className="text-3xl font-bold mb-2">
                  {stats?.study_streak || 0}
                </div>
                <div className="text-sm font-semibold opacity-90">Study Streak</div>
                <div className="text-xs opacity-75">days</div>
              </div>

              <div className="bg-gradient-to-br from-focus-500 to-focus-600 text-white rounded-xl p-6 text-center shadow-lg">
                <div className="text-3xl font-bold mb-2">
                  {stats?.cards_learned || 0}
                </div>
                <div className="text-sm font-semibold opacity-90">Cards Learned</div>
              </div>

              <div className="bg-gradient-to-br from-gray-600 to-gray-700 text-white rounded-xl p-6 text-center shadow-lg">
                <div className="text-3xl font-bold mb-2">
                  {stats?.total_reviews || 0}
                </div>
                <div className="text-sm font-semibold opacity-90">Total Reviews</div>
              </div>
            </div>
          </div>
        </section>

        {/* Main Dashboard Grid */}
        <div className="grid grid-cols-1 xl:grid-cols-12 gap-8">
          
          {/* Primary Content Area */}
          <div className="xl:col-span-8 space-y-8">
            
            {/* Study Session Section */}
            <section>
              <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                <div className="p-6 border-b border-gray-100">
                  <h2 className="heading-4 text-neutral-charcoal">📚 Study Session</h2>
                  <p className="text-sm text-neutral-gray mt-1">Review your due cards and keep your streak alive</p>
                </div>
                <div className="p-6">
                  <DueCardsSection
                    cards={dueCards}
                    totalDue={stats?.cards_due_today || 0}
                    isLoading={false}
                    onStartSession={handleStartStudySession}
                  />
                </div>
              </div>
            </section>

            {/* Analytics Section */}
            <section>
              <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                <div className="p-6 border-b border-gray-100">
                  <div className="flex items-center justify-between">
                    <div>
                      <h2 className="heading-4 text-neutral-charcoal">📈 Learning Analytics</h2>
                      <p className="text-sm text-neutral-gray mt-1">Track your progress and study patterns</p>
                    </div>
                    <div className="flex gap-2">
                      <Button
                        variant={chartType === 'weekly' ? 'primary' : 'ghost'}
                        size="sm"
                        onClick={() => setChartType('weekly')}
                      >
                        Week
                      </Button>
                      <Button
                        variant={chartType === 'monthly' ? 'primary' : 'ghost'}
                        size="sm"
                        onClick={() => setChartType('monthly')}
                      >
                        Month
                      </Button>
                    </div>
                  </div>
                </div>
                <div className="p-6">
                  <ProgressChart
                    weeklyData={stats?.weekly_progress || [0, 0, 0, 0, 0, 0, 0]}
                    monthlyData={stats?.monthly_progress || new Array(30).fill(0)}
                    type={chartType}
                  />
                </div>
              </div>
            </section>
          </div>

          {/* Sidebar Content */}
          <div className="xl:col-span-4 space-y-8">
            
            {/* Study Streak Section */}
            <section>
              <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                <div className="p-6 border-b border-gray-100">
                  <h3 className="heading-5 text-neutral-charcoal">🔥 Study Streak</h3>
                  <p className="text-sm text-neutral-gray mt-1">Keep the momentum going</p>
                </div>
                <div className="p-6">
                  <StudyStreakCard
                    currentStreak={stats?.study_streak || 0}
                    longestStreak={stats?.study_streak || 0}
                    totalStudyDays={Math.min(stats?.total_reviews || 0, 100)}
                    weeklyGoal={7}
                    weeklyProgress={Math.min(stats?.study_streak || 0, 7)}
                    nextReviewDate={stats?.next_review_date}
                  />
                </div>
              </div>
            </section>

            {/* Recent Lessons Section */}
            <section>
              <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                <div className="p-6 border-b border-gray-100">
                  <h3 className="heading-5 text-neutral-charcoal">📖 Recent Lessons</h3>
                  <p className="text-sm text-neutral-gray mt-1">Continue where you left off</p>
                </div>
                <div className="p-6">
                  <RecentLessonsSection
                    lessons={recentLessons}
                    isLoading={false}
                    onStartStudy={handleStartStudySession}
                  />
                </div>
              </div>
            </section>

            {/* Quick Actions Section */}
            <section>
              <div className="bg-gradient-to-br from-focus-50 to-learning-50 rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                <div className="p-6 border-b border-white/50">
                  <h3 className="heading-5 text-neutral-charcoal">⚡ Quick Actions</h3>
                  <p className="text-sm text-neutral-gray mt-1">Navigate to key features</p>
                </div>
                <div className="p-6">
                  <div className="space-y-3">
                    <Button
                      variant="ghost"
                      size="sm"
                      className="w-full justify-start bg-white/60 border-white/80 text-focus-700 hover:bg-white/80 shadow-sm"
                      onClick={() => router.push('/progress')}
                    >
                      📊 View Detailed Progress
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      className="w-full justify-start bg-white/60 border-white/80 text-focus-700 hover:bg-white/80 shadow-sm"
                      onClick={() => router.push('/lessons')}
                    >
                      📚 Browse All Lessons
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      className="w-full justify-start bg-white/60 border-white/80 text-focus-700 hover:bg-white/80 shadow-sm"
                      onClick={() => router.push('/settings')}
                    >
                      ⚙️ Settings
                    </Button>
                  </div>
                </div>
              </div>
            </section>
          </div>
        </div>

        {/* Footer Spacer */}
        <div className="mt-16"></div>
      </div>
    </div>
  )
}
