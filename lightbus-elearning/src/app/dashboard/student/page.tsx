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

      // Get comprehensive user statistics with improved error handling
      try {
        const { data: userStats, error: statsError } = await supabase
          .rpc('get_user_stats', { p_user_id: authUser.id })

        if (statsError) {
          console.error('Error fetching user stats:', statsError)
          throw statsError
        }

        if (userStats && userStats.length > 0) {
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
        } else {
          // No stats data found - use defaults
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
        }
      } catch (statsError) {
        console.error('Error in user stats operation:', statsError)
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
      }

      // Get due cards with improved error handling
      try {
        const { data: dueCardsData, error: dueCardsError } = await supabase
          .rpc('get_cards_due', {
            p_user_id: authUser.id,
            p_limit_count: 10
          })

        if (dueCardsError) {
          console.error('Error fetching due cards:', dueCardsError)
          setDueCards([])
        } else if (dueCardsData && dueCardsData.length > 0) {
          // Transform and enrich the data
          const transformedCards: DueCard[] = await Promise.all(
            dueCardsData.map(async (item: any) => {
              try {
                // Get lesson name with error handling
                const { data: lesson, error: lessonError } = await supabase
                  .from('lessons')
                  .select('name')
                  .eq('id', item.lesson_id)
                  .single()

                if (lessonError) {
                  console.error('Error fetching lesson name for card:', item.card_id, lessonError)
                }

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
              } catch (cardError) {
                console.error('Error processing card:', item.card_id, cardError)
                // Return a fallback card
                return {
                  id: item.card_id,
                  lesson_id: item.lesson_id,
                  lesson_name: 'Unknown Lesson',
                  front_content: item.front_content || 'Card content unavailable',
                  difficulty_level: item.difficulty_level || 1,
                  scheduled_for: item.scheduled_for,
                  is_overdue: false
                }
              }
            })
          )
          setDueCards(transformedCards)
        } else {
          setDueCards([])
        }
      } catch (cardsError) {
        console.error('Error in due cards operation:', cardsError)
        setDueCards([])
      }

      // Get lesson progress with improved error handling
      try {
        const { data: lessonsData, error: lessonsError } = await supabase
          .rpc('get_lesson_progress', { p_student_id: authUser.id })

        if (lessonsError) {
          console.error('Error fetching lesson progress:', lessonsError)
          setRecentLessons([])
        } else if (lessonsData && lessonsData.length > 0) {
          // Transform and enrich lesson data
          const transformedLessons: LessonProgress[] = await Promise.all(
            lessonsData.slice(0, 5).map(async (item: any) => {
              try {
                // Get teacher name and lesson details with error handling
                const { data: lesson, error: lessonError } = await supabase
                  .from('lessons')
                  .select(`
                    scheduled_at,
                    teacher_id,
                    profiles!lessons_teacher_id_fkey(name)
                  `)
                  .eq('id', item.lesson_id)
                  .single()

                if (lessonError) {
                  console.error('Error fetching lesson details for:', item.lesson_id, lessonError)
                }

                // Get last activity using the new safe function
                let lastReview = null
                try {
                  const { data: lastReviewData, error: reviewError } = await supabase
                    .rpc('get_student_last_review', { p_student_id: authUser.id })

                  if (reviewError) {
                    console.error('Error fetching last review for student:', authUser.id, reviewError)
                  } else {
                    lastReview = lastReviewData && lastReviewData.length > 0 ? lastReviewData[0] : null
                  }
                } catch (reviewError) {
                  console.error('Error in last review query:', reviewError)
                  lastReview = null
                }

                return {
                  lesson_id: item.lesson_id,
                  lesson_name: item.lesson_name || 'Unknown Lesson',
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
              } catch (lessonError) {
                console.error('Error processing lesson:', item.lesson_id, lessonError)
                // Return a fallback lesson
                return {
                  lesson_id: item.lesson_id,
                  lesson_name: item.lesson_name || 'Unknown Lesson',
                  teacher_name: 'Unknown Teacher',
                  scheduled_at: new Date().toISOString(),
                  cards_total: item.cards_total || 0,
                  cards_reviewed: item.cards_reviewed || 0,
                  cards_learned: item.cards_learned || 0,
                  cards_due: item.cards_due || 0,
                  average_quality: Number(item.average_quality) || 0,
                  progress_percentage: Number(item.progress_percentage) || 0,
                  next_review_date: item.next_review_date,
                  last_activity: undefined
                }
              }
            })
          )
          setRecentLessons(transformedLessons)
        } else {
          setRecentLessons([])
        }
      } catch (lessonsError) {
        console.error('Error in lesson progress operation:', lessonsError)
        setRecentLessons([])
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
                Welcome back, <span className="text-yellow-200">{user.name}</span>!
                <span className="ml-2">🚀</span>
              </h1>
              <p className="text-orange-100 text-lg">
                Ready to supercharge your learning? Let's dive into today's adventure!
              </p>
            </div>
            <div className="absolute -top-4 -right-4 text-8xl opacity-20">📚</div>
          </div>
        </div>

        {/* Main Bento Grid Layout */}
        <div className="grid grid-cols-12 gap-6">
          
          {/* Stats Overview Bento - Spans 12 columns */}
          <div className="col-span-12">
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
              {/* Cards Due Bento */}
              <div className="bg-white border-4 border-black shadow-lg p-6 hover:shadow-xl transition-all duration-300 group">
                <div className="flex items-center justify-between mb-4">
                  <div
                    className="p-3 text-white shadow-lg border-2 border-black"
                    style={{ backgroundColor: '#ff6b35' }}
                  >
                    <span className="text-2xl">🎯</span>
                  </div>
                  <div className="text-right">
                    <div
                      className="text-3xl font-bold group-hover:scale-110 transition-transform"
                      style={{ color: '#ff6b35' }}
                    >
                      {stats?.cards_due_today || 0}
                    </div>
                    <div className="text-sm font-semibold text-gray-600">Due Today</div>
                  </div>
                </div>
                <div className="w-full bg-orange-100 h-3 border-2 border-black">
                  <div
                    className="h-full transition-all duration-500 border-r-2 border-black"
                    style={{
                      backgroundColor: '#ff6b35',
                      width: `${Math.min((stats?.cards_due_today || 0) / 20 * 100, 100)}%`
                    }}
                  ></div>
                </div>
              </div>

              {/* Study Streak Bento */}
              <div className="bg-white border-4 border-black shadow-lg p-6 hover:shadow-xl transition-all duration-300 group">
                <div className="flex items-center justify-between mb-4">
                  <div
                    className="p-3 text-white shadow-lg border-2 border-black"
                    style={{ backgroundColor: '#ff6b35' }}
                  >
                    <span className="text-2xl">🔥</span>
                  </div>
                  <div className="text-right">
                    <div
                      className="text-3xl font-bold group-hover:scale-110 transition-transform"
                      style={{ color: '#ff6b35' }}
                    >
                      {stats?.study_streak || 0}
                    </div>
                    <div className="text-sm font-semibold text-gray-600">Day Streak</div>
                  </div>
                </div>
                <div className="flex space-x-1">
                  {[...Array(7)].map((_, i) => (
                    <div
                      key={i}
                      className={`flex-1 h-3 border border-black ${
                        i < (stats?.study_streak || 0) % 7 + 1
                          ? 'bg-orange-500'
                          : 'bg-gray-200'
                      }`}
                      style={{
                        backgroundColor: i < (stats?.study_streak || 0) % 7 + 1 ? '#ff6b35' : '#e5e7eb'
                      }}
                    />
                  ))}
                </div>
              </div>

              {/* Cards Learned Bento */}
              <div className="bg-white border-4 border-black shadow-lg p-6 hover:shadow-xl transition-all duration-300 group">
                <div className="flex items-center justify-between mb-4">
                  <div
                    className="p-3 text-white shadow-lg border-2 border-black"
                    style={{ backgroundColor: '#ff6b35' }}
                  >
                    <span className="text-2xl">🎓</span>
                  </div>
                  <div className="text-right">
                    <div
                      className="text-3xl font-bold group-hover:scale-110 transition-transform"
                      style={{ color: '#ff6b35' }}
                    >
                      {stats?.cards_learned || 0}
                    </div>
                    <div className="text-sm font-semibold text-gray-600">Mastered</div>
                  </div>
                </div>
                <div className="text-xs font-medium" style={{ color: '#ff6b35' }}>
                  +{Math.floor((stats?.cards_learned || 0) * 0.1)} this week
                </div>
              </div>

              {/* Total Reviews Bento */}
              <div className="bg-white border-4 border-black shadow-lg p-6 hover:shadow-xl transition-all duration-300 group">
                <div className="flex items-center justify-between mb-4">
                  <div
                    className="p-3 text-white shadow-lg border-2 border-black"
                    style={{ backgroundColor: '#ff6b35' }}
                  >
                    <span className="text-2xl">📊</span>
                  </div>
                  <div className="text-right">
                    <div
                      className="text-3xl font-bold group-hover:scale-110 transition-transform"
                      style={{ color: '#ff6b35' }}
                    >
                      {stats?.total_reviews || 0}
                    </div>
                    <div className="text-sm font-semibold text-gray-600">Reviews</div>
                  </div>
                </div>
                <div className="text-xs font-medium" style={{ color: '#ff6b35' }}>
                  All time total
                </div>
              </div>
            </div>
          </div>

          {/* Study Session Bento - Large */}
          <div className="col-span-12 lg:col-span-8">
            <div className="bg-white border-4 border-black shadow-xl overflow-hidden h-full">
              <div
                className="p-6 text-white border-b-4 border-black"
                style={{ backgroundColor: '#ff6b35' }}
              >
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
                  cards={dueCards}
                  totalDue={stats?.cards_due_today || 0}
                  isLoading={false}
                  onStartSession={handleStartStudySession}
                />
              </div>
            </div>
          </div>

          {/* Study Streak Bento - Tall */}
          <div className="col-span-12 lg:col-span-4">
            <div className="bg-orange-50 border-4 border-black shadow-xl overflow-hidden h-full">
              <div
                className="p-6 text-white border-b-4 border-black"
                style={{ backgroundColor: '#ff6b35' }}
              >
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
                  currentStreak={stats?.study_streak || 0}
                  longestStreak={stats?.study_streak || 0}
                  totalStudyDays={Math.min(stats?.total_reviews || 0, 100)}
                  weeklyGoal={7}
                  weeklyProgress={Math.min(stats?.study_streak || 0, 7)}
                  nextReviewDate={stats?.next_review_date}
                />
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
                    <h2 className="text-2xl font-bold mb-2">📈 Learning Analytics</h2>
                    <p className="text-orange-100">Track your progress and celebrate growth</p>
                  </div>
                  <div className="flex gap-2">
                    <Button
                      variant={chartType === 'weekly' ? 'accent' : 'ghost'}
                      size="sm"
                      onClick={() => setChartType('weekly')}
                      className="bg-white/20 text-white border-white/30 hover:bg-white/30"
                    >
                      Week
                    </Button>
                    <Button
                      variant={chartType === 'monthly' ? 'accent' : 'ghost'}
                      size="sm"
                      onClick={() => setChartType('monthly')}
                      className="bg-white/20 text-white border-white/30 hover:bg-white/30"
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
          </div>

          {/* Quick Actions & Recent Lessons Bento - Compact */}
          <div className="col-span-12 lg:col-span-4 space-y-6">
            
            {/* Recent Lessons Compact Bento */}
            <div className="bg-orange-50 border-4 border-black shadow-xl overflow-hidden">
              <div
                className="p-4 text-white border-b-4 border-black"
                style={{ backgroundColor: '#ff6b35' }}
              >
                <h3 className="text-lg font-bold">📖 Recent Lessons</h3>
                <p className="text-orange-100 text-sm">Continue your journey</p>
              </div>
              <div className="p-4">
                <RecentLessonsSection
                  lessons={recentLessons}
                  isLoading={false}
                  onStartStudy={handleStartStudySession}
                />
              </div>
            </div>

            {/* Quick Actions Compact Bento */}
            <div className="bg-orange-50 border-4 border-black shadow-xl overflow-hidden">
              <div
                className="p-4 text-white border-b-4 border-black"
                style={{ backgroundColor: '#ff6b35' }}
              >
                <h3 className="text-lg font-bold">⚡ Quick Actions</h3>
                <p className="text-orange-100 text-sm">Jump to key features</p>
              </div>
              <div className="p-4">
                <div className="space-y-3">
                  <Button
                    variant="ghost"
                    size="sm"
                    className="w-full justify-start bg-white border-2 border-black text-gray-800 hover:bg-orange-100 shadow-sm font-medium"
                    onClick={() => router.push('/progress')}
                  >
                    📊 Detailed Progress
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    className="w-full justify-start bg-white border-2 border-black text-gray-800 hover:bg-orange-100 shadow-sm font-medium"
                    onClick={() => router.push('/lessons')}
                  >
                    📚 Browse Lessons
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    className="w-full justify-start bg-white border-2 border-black text-gray-800 hover:bg-orange-100 shadow-sm font-medium"
                    onClick={() => router.push('/settings')}
                  >
                    ⚙️ Settings
                  </Button>
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
