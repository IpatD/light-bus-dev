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
      <div className="min-h-screen bg-neutral-white flex items-center justify-center">
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
    <div className="min-h-screen bg-neutral-white">
      <div className="container-main py-8">
        {/* Header */}
        <div className="mb-8">
          <h1 className="heading-2 mb-2">
            Welcome back, <span className="text-learning-500">{user.name}</span>! 🎓
          </h1>
          <p className="body-medium text-neutral-gray">
            Ready to continue your learning journey? Let's see what's waiting for you today.
          </p>
        </div>

        {/* Stats Overview */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <Card variant="primary" padding="lg" className="text-center">
            <div className="text-3xl font-bold text-learning-500 mb-2">
              {stats?.cards_due_today || 0}
            </div>
            <div className="text-sm font-semibold text-neutral-charcoal">Cards Due Today</div>
          </Card>

          <Card variant="default" padding="lg" className="text-center">
            <div className="text-3xl font-bold text-achievement-500 mb-2">
              {stats?.study_streak || 0}
            </div>
            <div className="text-sm font-semibold text-neutral-charcoal">Study Streak</div>
            <div className="text-xs text-neutral-gray">days</div>
          </Card>

          <Card variant="default" padding="lg" className="text-center">
            <div className="text-3xl font-bold text-focus-500 mb-2">
              {stats?.cards_learned || 0}
            </div>
            <div className="text-sm font-semibold text-neutral-charcoal">Cards Learned</div>
          </Card>

          <Card variant="default" padding="lg" className="text-center">
            <div className="text-3xl font-bold text-neutral-charcoal mb-2">
              {stats?.total_reviews || 0}
            </div>
            <div className="text-sm font-semibold text-neutral-charcoal">Total Reviews</div>
          </Card>
        </div>

        {/* Main Content Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Due Cards Section - Takes up 2 columns */}
          <div className="lg:col-span-2 space-y-8">
            <DueCardsSection
              cards={dueCards}
              totalDue={stats?.cards_due_today || 0}
              isLoading={false}
              onStartSession={handleStartStudySession}
            />

            {/* Progress Chart */}
            <div className="flex items-center justify-between mb-4">
              <h2 className="heading-3">📈 Learning Analytics</h2>
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
            <ProgressChart
              weeklyData={stats?.weekly_progress || [0, 0, 0, 0, 0, 0, 0]}
              monthlyData={stats?.monthly_progress || new Array(30).fill(0)}
              type={chartType}
            />
          </div>

          {/* Right Sidebar */}
          <div className="space-y-6">
            {/* Study Streak Card */}
            <StudyStreakCard
              currentStreak={stats?.study_streak || 0}
              longestStreak={stats?.study_streak || 0} // In a real app, you'd track this separately
              totalStudyDays={Math.min(stats?.total_reviews || 0, 100)} // Simplified calculation
              weeklyGoal={7}
              weeklyProgress={Math.min(stats?.study_streak || 0, 7)}
              nextReviewDate={stats?.next_review_date}
            />

            {/* Recent Lessons */}
            <RecentLessonsSection
              lessons={recentLessons}
              isLoading={false}
              onStartStudy={handleStartStudySession}
            />

            {/* Quick Actions */}
            <Card variant="accent" padding="lg">
              <h3 className="heading-4 mb-4">⚡ Quick Actions</h3>
              <div className="space-y-3">
                <Button
                  variant="ghost"
                  size="sm"
                  className="w-full justify-start border-focus-300 text-focus-700 hover:bg-focus-50"
                  onClick={() => router.push('/progress')}
                >
                  📊 View Detailed Progress
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  className="w-full justify-start border-focus-300 text-focus-700 hover:bg-focus-50"
                  onClick={() => router.push('/lessons')}
                >
                  📚 Browse All Lessons
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  className="w-full justify-start border-focus-300 text-focus-700 hover:bg-focus-50"
                  onClick={() => router.push('/settings')}
                >
                  ⚙️ Settings
                </Button>
              </div>
            </Card>
          </div>
        </div>

        {/* Study Tips */}
        <div className="mt-8">
          <Card variant="default" padding="lg">
            <div className="flex items-start space-x-4">
              <div className="bg-achievement-100 text-achievement-600 p-3 text-2xl">
                💡
              </div>
              <div>
                <h3 className="heading-4 mb-2">Study Tip of the Day</h3>
                <p className="text-neutral-gray">
                  {getRandomStudyTip()}
                </p>
              </div>
            </div>
          </Card>
        </div>
      </div>
    </div>
  )
}

// Helper function for random study tips
function getRandomStudyTip(): string {
  const tips = [
    "Spaced repetition works best when you study consistently. Even 10-15 minutes daily is more effective than cramming for hours once a week.",
    "When you struggle with a card, try to understand the underlying concept rather than just memorizing the answer.",
    "Take breaks between study sessions. Your brain consolidates information better when you give it time to rest.",
    "Review cards in different contexts and environments to strengthen your memory connections.",
    "Don't worry about getting cards wrong initially - making mistakes is a crucial part of the learning process.",
    "Focus on understanding rather than speed. Quality of learning is more important than quantity.",
    "Use the full rating scale (0-5) honestly. Accurate self-assessment leads to better spaced repetition scheduling."
  ]
  
  return tips[Math.floor(Math.random() * tips.length)]
}