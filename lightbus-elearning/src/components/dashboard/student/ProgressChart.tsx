'use client'

import React from 'react'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, AreaChart, Area } from 'recharts'

interface ProgressChartProps {
  weeklyData: number[]
  monthlyData: number[]
  type?: 'weekly' | 'monthly'
  analyticsData?: {
    lessons_participated: number
    cards_added: number
    cards_studied: number
    current_month_name: string
  }
}

const ProgressChart: React.FC<ProgressChartProps> = ({ 
  weeklyData, 
  monthlyData, 
  type = 'weekly',
  analyticsData 
}) => {
  // Prepare weekly data
  const weeklyChartData = weeklyData.map((value, index) => {
    const date = new Date()
    date.setDate(date.getDate() - (6 - index))
    return {
      day: date.toLocaleDateString('en-US', { weekday: 'short' }),
      reviews: value,
      date: date.toISOString().split('T')[0]
    }
  })

  // Prepare monthly data (current month from day 1 to last day)
  const monthlyChartData = monthlyData.map((value, index) => {
    const startOfMonth = new Date()
    startOfMonth.setDate(1)
    const date = new Date(startOfMonth)
    date.setDate(index + 1)
    
    return {
      day: `${date.getDate()}`,
      reviews: value,
      date: date.toISOString().split('T')[0],
      month: date.toLocaleDateString('en-US', { month: 'short' })
    }
  })

  const chartData = type === 'weekly' ? weeklyChartData : monthlyChartData

  // Calculate statistics
  const totalReviews = chartData.reduce((sum, day) => sum + day.reviews, 0)
  const avgReviews = totalReviews / chartData.length
  const maxReviews = Math.max(...chartData.map(d => d.reviews))
  const currentStreak = calculateStreak(chartData)

  const CustomTooltip = ({ active, payload, label }: any) => {
    if (active && payload && payload.length) {
      const data = payload[0].payload
      return (
        <div className="bg-white p-3 border border-neutral-charcoal shadow-lg rounded-lg">
          <p className="font-semibold text-neutral-charcoal">
            {type === 'weekly' ? data.day : `${data.month} ${data.day}`}
          </p>
          <p className="text-learning-600">
            <span className="font-medium">{payload[0].value}</span> cards studied
          </p>
        </div>
      )
    }
    return null
  }

  return (
    <div className="h-full">
      <div className="mb-6">
        {/* Enhanced Statistics Row */}
        <div className="grid grid-cols-3 gap-4 mb-6">
          <div className="text-center p-4 bg-blue-50 rounded-lg border border-blue-200">
            <div className="text-xl font-bold text-blue-600">
              {analyticsData?.lessons_participated || 0}
            </div>
            <div className="text-xs text-neutral-gray">Lessons Joined</div>
          </div>
          <div className="text-center p-4 bg-green-50 rounded-lg border border-green-200">
            <div className="text-xl font-bold text-green-600">
              {analyticsData?.cards_added || 0}
            </div>
            <div className="text-xs text-neutral-gray">Cards Added</div>
          </div>
          <div className="text-center p-4 bg-purple-50 rounded-lg border border-purple-200">
            <div className="text-xl font-bold text-purple-600">
              {analyticsData?.cards_studied || 0}
            </div>
            <div className="text-xs text-neutral-gray">Cards Studied</div>
          </div>
        </div>

        {/* Period Statistics */}
        <div className="grid grid-cols-3 gap-4 mb-6">
          <div className="text-center p-4 bg-orange-50 rounded-lg border border-orange-200">
            <div className="text-xl font-bold text-orange-600">{totalReviews}</div>
            <div className="text-xs text-neutral-gray">
              {type === 'weekly' ? 'Week' : analyticsData?.current_month_name || 'Month'} Total
            </div>
          </div>
          <div className="text-center p-4 bg-teal-50 rounded-lg border border-teal-200">
            <div className="text-xl font-bold text-teal-600">{avgReviews.toFixed(1)}</div>
            <div className="text-xs text-neutral-gray">Daily Average</div>
          </div>
          <div className="text-center p-4 bg-pink-50 rounded-lg border border-pink-200">
            <div className="text-xl font-bold text-pink-600">{currentStreak}</div>
            <div className="text-xs text-neutral-gray">Current Streak</div>
          </div>
        </div>
      </div>

      {/* Chart */}
      <div className="h-64 bg-white rounded-lg border border-gray-200 p-4">
        <div className="flex items-center justify-between mb-4">
          <h4 className="font-semibold text-gray-800">
            {type === 'weekly' ? 'Last 7 Days' : analyticsData?.current_month_name || 'This Month'}
          </h4>
          <div className="text-sm text-gray-500">
            Cards studied per day
          </div>
        </div>
        
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={chartData} margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
            <defs>
              <linearGradient id="energeticGradient" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#FF6B35" stopOpacity={0.8}/>
                <stop offset="95%" stopColor="#FF6B35" stopOpacity={0.1}/>
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
            <XAxis 
              dataKey="day" 
              axisLine={false}
              tickLine={false}
              tick={{ fontSize: 12, fill: '#6B7280' }}
            />
            <YAxis 
              axisLine={false}
              tickLine={false}
              tick={{ fontSize: 12, fill: '#6B7280' }}
            />
            <Tooltip content={<CustomTooltip />} />
            <Area
              type="monotone"
              dataKey="reviews"
              stroke="#FF6B35"
              strokeWidth={3}
              fill="url(#energeticGradient)"
              activeDot={{ 
                r: 6, 
                fill: '#FF6B35',
                stroke: '#fff',
                strokeWidth: 2
              }}
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>

      {/* Achievement Indicators */}
      {maxReviews > 0 && (
        <div className="mt-4 pt-4 border-t border-neutral-gray border-opacity-20">
          <div className="flex items-center justify-between text-sm">
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 bg-learning-500 rounded-full"></div>
              <span className="text-neutral-gray">Best Day: {maxReviews} cards</span>
            </div>
            {currentStreak >= 3 && (
              <div className="flex items-center gap-1 text-achievement-600">
                <span>🔥</span>
                <span className="font-semibold">{currentStreak} day streak!</span>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Learning Progress Summary */}
      {analyticsData && (
        <div className="mt-4 pt-4 border-t border-neutral-gray border-opacity-20">
          <div className="bg-gray-50 p-4 rounded-lg">
            <h5 className="font-semibold text-gray-800 mb-2">Learning Summary</h5>
            <div className="text-sm text-gray-600 space-y-1">
              <p>
                📚 Participating in <span className="font-semibold text-blue-600">{analyticsData.lessons_participated}</span> lessons
              </p>
              <p>
                🎯 <span className="font-semibold text-green-600">{analyticsData.cards_added}</span> cards available for study
              </p>
              <p>
                ✅ Studied <span className="font-semibold text-purple-600">{analyticsData.cards_studied}</span> different cards
              </p>
              {analyticsData.cards_added > 0 && (
                <p>
                  📊 Progress: <span className="font-semibold text-orange-600">
                    {Math.round((analyticsData.cards_studied / analyticsData.cards_added) * 100)}%
                  </span> cards explored
                </p>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

// Helper function to calculate current study streak
function calculateStreak(chartData: any[]): number {
  let streak = 0
  for (let i = chartData.length - 1; i >= 0; i--) {
    if (chartData[i].reviews > 0) {
      streak++
    } else {
      break
    }
  }
  return streak
}

export default ProgressChart