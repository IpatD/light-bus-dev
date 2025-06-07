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
import { getUserTimezone } from '@/utils/dateHelpers'

interface StudyCard {
  card_id: string
  lesson_id: string
  lesson_name: string
  front_content: string
  difficulty_level: number
  scheduled_for: string
  card_pool: 'new' | 'due'
  can_accept: boolean
  review_id: string
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

interface DashboardData {
  user: User
  stats: UserStats
  analyticsData: any
  newCards: StudyCard[]
  dueCards: StudyCard[]
  recentLessons: LessonProgress[]
}

const DEFAULT_STATS: UserStats = {
  total_reviews: 0,
  average_quality: 0.0,
  study_streak: 0,
  longest_streak: 0,
  cards_learned: 0,
  cards_due_today: 0,
  next_review_date: undefined,
  weekly_progress: [0, 0, 0, 0, 0, 0, 0],
  monthly_progress: new Array(30).fill(0),
}

export default function StudentDashboard() {
  const router = useRouter()
  const [dashboardData, setDashboardData] = useState<Partial<DashboardData>>({})
  const [isLoading, setIsLoading] = useState(true)
  const [chartType, setChartType] = useState<'weekly' | 'monthly'>('weekly')
  const userTimezone = getUserTimezone()

  useEffect(() => {
    fetchDashboardData()
  }, [])

  const processStatsData = (rawStats: any): UserStats => {
    if (!rawStats) return DEFAULT_STATS
    
    const weeklyProgress = rawStats.weekly_progress || [0, 0, 0, 0, 0, 0, 0]
    
    const processedStats = {
      total_reviews: Number(rawStats.total_reviews) || 0,
      average_quality: Number(rawStats.average_quality) || 0.0,
      study_streak: Number(rawStats.study_streak) || 0,
      longest_streak: Number(rawStats.longest_streak) || 0,
      cards_learned: Number(rawStats.cards_learned) || 0,
      cards_due_today: Number(rawStats.cards_due_today) || 0,
      next_review_date: rawStats.next_review_date,
      weekly_progress: weeklyProgress,
      monthly_progress: rawStats.monthly_progress || new Array(30).fill(0),
    }
    
    return processedStats
  }

  const fetchUserStats = async (userId: string): Promise<UserStats> => {
    try {
      const { data: userStats, error: statsError } = await supabase
        .rpc('get_user_stats_with_timezone', { 
          p_user_id: userId,
          p_client_timezone: userTimezone
        })

      if (!statsError && userStats?.[0]) {
        return processStatsData(userStats[0])
      }

      const { data: fallbackStats, error: fallbackError } = await supabase
        .rpc('get_user_stats', { p_user_id: userId })
      
      if (!fallbackError && fallbackStats?.[0]) {
        return processStatsData(fallbackStats[0])
      }

      throw new Error('Both stats functions failed')
    } catch (error) {
      console.error('Error fetching user stats:', error)
      return DEFAULT_STATS
    }
  }

  const separateCards = (cardsData: any[]): { newCards: StudyCard[], dueCards: StudyCard[] } => {
    const newCards: StudyCard[] = []
    const dueCards: StudyCard[] = []

    cardsData.forEach((card: any) => {
      if (card.card_pool === 'new') {
        newCards.push(card)
      } else if (card.card_pool === 'due') {
        dueCards.push(card)
      }
    })

    return { newCards, dueCards }
  }

  const enrichLessonData = async (userId: string, lessonItem: any): Promise<LessonProgress> => {
    try {
      const { data: lesson } = await supabase
        .from('lessons')
        .select(`scheduled_at, teacher_id, profiles!lessons_teacher_id_fkey(name)`)
        .eq('id', lessonItem.lesson_id)
        .single()

      return {
        lesson_id: lessonItem.lesson_id,
        lesson_name: lessonItem.lesson_name || 'Unknown Lesson',
        teacher_name: (lesson?.profiles as any)?.name || 'Unknown Teacher',
        scheduled_at: lesson?.scheduled_at || new Date().toISOString(),
        cards_total: lessonItem.cards_total || 0,
        cards_reviewed: lessonItem.cards_reviewed || 0,
        cards_learned: lessonItem.cards_learned || 0,
        cards_due: lessonItem.cards_due || 0,
        average_quality: Number(lessonItem.average_quality) || 0,
        progress_percentage: Number(lessonItem.progress_percentage) || 0,
        next_review_date: lessonItem.next_review_date,
        last_activity: undefined
      }
    } catch (error) {
      console.error('Error enriching lesson:', lessonItem.lesson_id, error)
      return {
        lesson_id: lessonItem.lesson_id,
        lesson_name: lessonItem.lesson_name || 'Unknown Lesson',
        teacher_name: 'Unknown Teacher',
        scheduled_at: new Date().toISOString(),
        cards_total: lessonItem.cards_total || 0,
        cards_reviewed: lessonItem.cards_reviewed || 0,
        cards_learned: lessonItem.cards_learned || 0,
        cards_due: lessonItem.cards_due || 0,
        average_quality: Number(lessonItem.average_quality) || 0,
        progress_percentage: Number(lessonItem.progress_percentage) || 0,
        next_review_date: lessonItem.next_review_date,
        last_activity: undefined
      }
    }
  }

  const fetchDashboardData = async () => {
    try {
      setIsLoading(true)
      
      const { data: { user: authUser }, error: userError } = await supabase.auth.getUser()
      if (userError || !authUser) {
        router.push('/auth/login')
        return
      }

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

      const [stats, analyticsData, cardsData, lessonsData] = await Promise.allSettled([
        fetchUserStats(authUser.id),
        
        supabase.rpc('get_enhanced_learning_analytics', { p_user_id: authUser.id })
          .then(({ data, error }) => {
            if (error || !data?.[0]) {
              return {
                lessons_participated: 0,
                cards_added: 0,
                cards_studied: 0,
                current_month_name: new Date().toLocaleDateString('en-US', { 
                  month: 'long', 
                  year: 'numeric',
                  timeZone: userTimezone
                })
              }
            }
            return data[0]
          }),
        
        supabase.rpc('get_cards_for_study', {
          p_user_id: authUser.id,
          p_pool_type: 'both',
          p_limit_new: 10,
          p_limit_due: 15
        }).then(({ data, error }) => {
          if (error || !data) return []
          return data
        }),
        
        supabase.rpc('get_lesson_progress', { p_student_id: authUser.id })
          .then(({ data, error }) => {
            if (error || !data) return []
            return data.slice(0, 5)
          })
      ])

      const userStats = stats.status === 'fulfilled' ? stats.value : DEFAULT_STATS
      const analytics = analyticsData.status === 'fulfilled' ? analyticsData.value : null
      const cards = cardsData.status === 'fulfilled' ? cardsData.value : []
      const lessons = lessonsData.status === 'fulfilled' ? lessonsData.value : []

      const { newCards, dueCards } = separateCards(cards)
      
      const enrichedLessons = await Promise.all(
        lessons.map((lesson: any) => enrichLessonData(authUser.id, lesson))
      )

      setDashboardData({
        user: userData,
        stats: userStats,
        analyticsData: analytics,
        newCards,
        dueCards,
        recentLessons: enrichedLessons
      })

    } catch (error) {
      console.error('Error fetching dashboard data:', error)
      setDashboardData({
        stats: DEFAULT_STATS,
        newCards: [],
        dueCards: [],
        recentLessons: []
      })
    } finally {
      setIsLoading(false)
    }
  }

  const handleStartStudySession = (lessonId?: string) => {
    router.push(lessonId ? `/study/${lessonId}` : '/study/all')
  }

  const StatCard = ({ 
    icon, 
    value, 
    label, 
    color, 
    bgColor, 
    progressValue, 
    maxProgress = 100,
    subtitle 
  }: {
    icon: string
    value: number
    label: string
    color: string
    bgColor: string
    progressValue?: number
    maxProgress?: number
    subtitle?: string
  }) => (
    <div className="bg-white border-4 border-black shadow-lg p-6 hover:shadow-xl transition-all duration-300 group">
      <div className="flex items-center justify-between mb-4">
        <div className="p-3 text-white shadow-lg border-2 border-black" style={{ backgroundColor: color }}>
          <span className="text-2xl">{icon}</span>
        </div>
        <div className="text-right">
          <div className="text-3xl font-bold group-hover:scale-110 transition-transform" style={{ color }}>
            {value}
          </div>
          <div className="text-sm font-semibold text-gray-600">{label}</div>
        </div>
      </div>
      {progressValue !== undefined ? (
        <div className={`w-full ${bgColor} h-3 border-2 border-black`}>
          <div
            className="h-full transition-all duration-500 border-r-2 border-black"
            style={{
              backgroundColor: color,
              width: `${Math.min((progressValue / maxProgress) * 100, 100)}%`
            }}
          />
        </div>
      ) : subtitle ? (
        <div className="text-xs font-medium" style={{ color }}>
          {subtitle}
        </div>
      ) : null}
    </div>
  )

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

  if (!dashboardData.user) {
    return (
      <div className="bg-neutral-white flex items-center justify-center min-h-screen">
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

  const { user, stats, analyticsData, newCards, dueCards, recentLessons } = dashboardData

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="container mx-auto px-6 py-8 max-w-7xl">
        
        {/* Welcome Hero */}
        <div className="mb-8">
          <div className="bg-white border-4 border-black shadow-xl p-8 overflow-hidden relative" style={{ backgroundColor: '#ff6b35' }}>
            <div className="relative z-10">
              <h1 className="text-4xl font-bold mb-3 text-white">
                Welcome back, <span className="text-yellow-200">{user?.name}</span>!
                <span className="ml-2">🚀</span>
              </h1>
              <p className="text-orange-100 text-lg">
                Ready to supercharge your learning? Let's dive into today's adventure!
              </p>
            </div>
            <div className="absolute -top-4 -right-4 text-8xl opacity-20">📚</div>
          </div>
        </div>

        {/* Main Grid */}
        <div className="grid grid-cols-12 gap-6">
          
          {/* Stats Overview */}
          <div className="col-span-12">
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
              <StatCard
                icon="🎯"
                value={dueCards?.length || 0}
                label="Ready to Study"
                color="#ff6b35"
                bgColor="bg-orange-100"
                progressValue={dueCards?.length || 0}
                maxProgress={20}
              />
              <StatCard
                icon="🎁"
                value={newCards?.length || 0}
                label="New Cards"
                color="#4ade80"
                bgColor="bg-green-100"
                progressValue={newCards?.length || 0}
                maxProgress={10}
              />
              <StatCard
                icon="🔥"
                value={stats?.study_streak || 0}
                label="Day Streak"
                color="#ff6b35"
                bgColor=""
              />
              <StatCard
                icon="🎓"
                value={stats?.cards_learned || 0}
                label="Mastered"
                color="#ff6b35"
                bgColor=""
                subtitle={`+${Math.floor((stats?.cards_learned || 0) * 0.1)} this week`}
              />
            </div>
          </div>

          {/* Study Session */}
          <div className="col-span-12 lg:col-span-8">
            <div className="bg-white border-4 border-black shadow-xl overflow-hidden h-full">
              <div className="p-6 text-white border-b-4 border-black" style={{ backgroundColor: '#ff6b35' }}>
                <div className="flex items-center justify-between">
                  <div>
                    <h2 className="text-2xl font-bold mb-2">📚 Study Session</h2>
                    <p className="text-orange-100">Master your cards and boost your knowledge</p>
                  </div>
                  <div className="text-4xl opacity-50">🎯</div>
                </div>
              </div>
              <div className="p-6">
                <DueCardsSection
                  newCards={newCards || []}
                  dueCards={dueCards || []}
                  isLoading={false}
                  onStartSession={handleStartStudySession}
                  onRefresh={fetchDashboardData}
                />
              </div>
            </div>
          </div>

          {/* Study Streak */}
          <div className="col-span-12 lg:col-span-4">
            <div className="bg-orange-50 border-4 border-black shadow-xl overflow-hidden h-full">
              <div className="p-6 text-white border-b-4 border-black" style={{ backgroundColor: '#ff6b35' }}>
                <div className="flex items-center justify-between">
                  <div>
                    <h3 className="text-xl font-bold">🔥 Streak Power</h3>
                    <p className="text-orange-100 text-sm">Keep the fire burning</p>
                  </div>
                  <div className="text-3xl opacity-50">🚀</div>
                </div>
              </div>
              <div className="p-6">
                <StudyStreakCard
                  rawStats={{
                    study_streak: stats?.study_streak,
                    longest_streak: stats?.longest_streak,
                    total_reviews: stats?.total_reviews,
                    weekly_progress: stats?.weekly_progress,
                    next_review_date: stats?.next_review_date
                  }}
                  weeklyGoal={7}
                />
              </div>
            </div>
          </div>

          {/* Analytics */}
          <div className="col-span-12 lg:col-span-8">
            <div className="bg-white border-4 border-black shadow-xl overflow-hidden">
              <div className="p-6 text-white border-b-4 border-black" style={{ backgroundColor: '#ff6b35' }}>
                <div className="flex items-center justify-between">
                  <div>
                    <h2 className="text-2xl font-bold mb-2">📈 Learning Analytics</h2>
                    <p className="text-orange-100">Track your progress and celebrate growth</p>
                  </div>
                  <div className="flex gap-2">
                    {['weekly', 'monthly'].map((type) => (
                      <Button
                        key={type}
                        variant={chartType === type ? 'accent' : 'ghost'}
                        size="sm"
                        onClick={() => setChartType(type as 'weekly' | 'monthly')}
                        className="bg-white/20 text-white border-white/30 hover:bg-white/30"
                      >
                        {type === 'weekly' ? 'Week' : 'Month'}
                      </Button>
                    ))}
                  </div>
                </div>
              </div>
              <div className="p-6">
                <ProgressChart
                  weeklyData={stats?.weekly_progress || [0, 0, 0, 0, 0, 0, 0]}
                  monthlyData={stats?.monthly_progress || new Array(30).fill(0)}
                  type={chartType}
                  analyticsData={analyticsData}
                />
              </div>
            </div>
          </div>

          {/* Recent Lessons & Quick Actions */}
          <div className="col-span-12 lg:col-span-4 space-y-6">
            
            {/* Recent Lessons */}
            <div className="bg-orange-50 border-4 border-black shadow-xl overflow-hidden">
              <div className="p-4 text-white border-b-4 border-black" style={{ backgroundColor: '#ff6b35' }}>
                <h3 className="text-lg font-bold">📖 Recent Lessons</h3>
                <p className="text-orange-100 text-sm">Continue your journey</p>
              </div>
              <div className="p-4">
                <RecentLessonsSection
                  lessons={recentLessons || []}
                  isLoading={false}
                  onStartStudy={handleStartStudySession}
                />
              </div>
            </div>

            {/* Quick Actions */}
            <div className="bg-orange-50 border-4 border-black shadow-xl overflow-hidden">
              <div className="p-4 text-white border-b-4 border-black" style={{ backgroundColor: '#ff6b35' }}>
                <h3 className="text-lg font-bold">⚡ Quick Actions</h3>
                <p className="text-orange-100 text-sm">Jump to key features</p>
              </div>
              <div className="p-4">
                <div className="space-y-3">
                  {[
                    { icon: '📊', label: 'Detailed Progress', path: '/progress' },
                    { icon: '📚', label: 'Browse Lessons', path: '/lessons' },
                    { icon: '⚙️', label: 'Settings', path: '/settings' }
                  ].map((action) => (
                    <Button
                      key={action.path}
                      variant="ghost"
                      size="sm"
                      className="w-full justify-start bg-white border-2 border-black text-gray-800 hover:bg-orange-100 shadow-sm font-medium"
                      onClick={() => router.push(action.path)}
                    >
                      {action.icon} {action.label}
                    </Button>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="mt-12"></div>
      </div>
    </div>
  )
}
