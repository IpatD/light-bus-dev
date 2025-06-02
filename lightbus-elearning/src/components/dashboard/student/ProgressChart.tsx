'use client'

import React from 'react'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, AreaChart, Area } from 'recharts'

interface ProgressChartProps {
  weeklyData: number[]
  monthlyData: number[]
  type?: 'weekly' | 'monthly'
}

const ProgressChart: React.FC<ProgressChartProps> = ({ 
  weeklyData, 
  monthlyData, 
  type = 'weekly' 
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

  // Prepare monthly data (show last 30 days)
  const monthlyChartData = monthlyData.map((value, index) => {
    const date = new Date()
    date.setDate(date.getDate() - (29 - index))
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
            <span className="font-medium">{payload[0].value}</span> reviews
          </p>
        </div>
      )
    }
    return null
  }

  return (
    <div className="h-full">
      <div className="mb-6">
        {/* Statistics Row */}
        <div className="grid grid-cols-3 gap-4 mb-6">
          <div className="text-center p-4 bg-learning-50 rounded-lg border border-learning-200">
            <div className="text-xl font-bold text-learning-500">{totalReviews}</div>
            <div className="text-xs text-neutral-gray">Total Reviews</div>
          </div>
          <div className="text-center p-4 bg-achievement-50 rounded-lg border border-achievement-200">
            <div className="text-xl font-bold text-achievement-500">{avgReviews.toFixed(1)}</div>
            <div className="text-xs text-neutral-gray">Daily Average</div>
          </div>
          <div className="text-center p-4 bg-focus-50 rounded-lg border border-focus-200">
            <div className="text-xl font-bold text-focus-500">{currentStreak}</div>
            <div className="text-xs text-neutral-gray">Current Streak</div>
          </div>
        </div>
      </div>

      {/* Chart */}
      <div className="h-64 bg-white rounded-lg border border-gray-200 p-4">
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
              <span className="text-neutral-gray">Best Day: {maxReviews} reviews</span>
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