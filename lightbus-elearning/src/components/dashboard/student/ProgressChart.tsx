'use client'

import React from 'react'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, AreaChart, Area, ComposedChart, Bar } from 'recharts'
import { 
  mapReviewDataToChart, 
  getUserTimezone, 
  isToday,
  formatDisplayDate
} from '@/utils/dateHelpers'

interface ProgressChartProps {
  weeklyData: number[]
  monthlyData: number[]
  type?: 'weekly' | 'monthly'
  analyticsData?: {
    lessons_participated: number
    cards_added: number
    cards_studied: number
    current_month_name: string
    weekly_study_data?: any[]
    monthly_study_data?: any[]
  }
}

const ProgressChart: React.FC<ProgressChartProps> = ({ 
  weeklyData, 
  monthlyData, 
  type = 'weekly',
  analyticsData 
}) => {
  const userTimezone = getUserTimezone()
  
  const chartData = type === 'weekly' 
    ? mapReviewDataToChart(weeklyData, 'weekly', userTimezone)
    : mapReviewDataToChart(monthlyData, 'monthly', userTimezone)

  // Calculate meaningful statistics
  const totalReviews = chartData.reduce((sum, day) => sum + day.reviews, 0)
  const nonZeroDays = chartData.filter(d => d.reviews > 0).length
  const avgReviews = nonZeroDays > 0 ? totalReviews / nonZeroDays : 0
  const maxReviews = Math.max(...chartData.map(d => d.reviews))
  const currentStreak = calculateStreak(chartData)

  const CustomTooltip = ({ active, payload, label }: any) => {
    if (active && payload && payload.length) {
      const data = payload[0].payload
      
      return (
        <div className="bg-white p-4 border border-gray-300 shadow-lg rounded-lg">
          <p className="font-semibold text-gray-800 mb-2">
            {type === 'weekly' ? data.day : `${data.month} ${data.day}`}
            {data.isToday && <span className="ml-2 text-xs bg-blue-100 text-blue-800 px-2 py-1 rounded">Today</span>}
          </p>
          <div className="space-y-1 text-sm">
            <p className="text-orange-600">
              <span className="font-medium">{data.reviews}</span> cards studied
            </p>
            {data.reviews === 0 && (
              <p className="text-gray-500 text-xs">No study activity</p>
            )}
          </div>
        </div>
      )
    }
    return null
  }

  return (
    <div className="h-full">
      <div className="mb-6">
        {/* Enhanced Statistics Row - Key Learning Metrics */}
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
            <div className="text-xs text-neutral-gray">Cards Available</div>
          </div>
          <div className="text-center p-4 bg-purple-50 rounded-lg border border-purple-200">
            <div className="text-xl font-bold text-purple-600">
              {analyticsData?.cards_studied || 0}
            </div>
            <div className="text-xs text-neutral-gray">Cards Studied</div>
          </div>
        </div>
      </div>

      {/* Chart */}
      <div className="h-80 bg-white rounded-lg border border-gray-200 p-4">
        <div className="flex items-center justify-between mb-4">
          <h4 className="font-semibold text-gray-800">
            {type === 'weekly' ? 'Last 7 Days' : analyticsData?.current_month_name || 'This Month'}
          </h4>
          <div className="text-sm text-gray-500">
            Learning activity overview
          </div>
        </div>
        
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={chartData} margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
            <XAxis
              dataKey="day"
              axisLine={false}
              tickLine={false}
              tick={(props) => {
                const { x, y, payload } = props
                const data = chartData[payload.index]
                const isToday = data?.isToday
                return (
                  <g transform={`translate(${x},${y})`}>
                    <text
                      x={0}
                      y={0}
                      dy={16}
                      textAnchor="middle"
                      fill={isToday ? '#3B82F6' : '#6B7280'}
                      fontSize={12}
                      fontWeight={isToday ? 'bold' : 'normal'}
                    >
                      {payload.value}
                    </text>
                    {isToday && (
                      <circle
                        cx={0}
                        cy={-8}
                        r={3}
                        fill="#3B82F6"
                      />
                    )}
                  </g>
                )
              }}
            />
            <YAxis
              axisLine={false}
              tickLine={false}
              tick={{ fontSize: 12, fill: '#6B7280' }}
              label={{ value: 'Cards Studied', angle: -90, position: 'insideLeft' }}
            />
            <Tooltip content={<CustomTooltip />} />
            
            {/* Daily Reviews - Primary focus with dots and lines */}
            <Line
              type="monotone"
              dataKey="reviews"
              stroke="#FF6B35"
              strokeWidth={3}
              dot={(props) => {
                const { cx, cy, payload } = props
                const isToday = payload.isToday
                return (
                  <circle
                    cx={cx}
                    cy={cy}
                    r={isToday ? 6 : 4}
                    fill={isToday ? '#3B82F6' : '#FF6B35'}
                    stroke="#fff"
                    strokeWidth={2}
                  />
                )
              }}
              activeDot={{
                r: 6,
                fill: '#FF6B35',
                stroke: '#fff',
                strokeWidth: 2
              }}
              connectNulls={false}
              name="Daily Reviews"
            />
          </LineChart>
        </ResponsiveContainer>
      </div>

      {/* Legend */}
      <div className="mt-4 flex flex-wrap gap-4 text-sm">
        <div className="flex items-center gap-2">
          <div className="w-3 h-3 bg-orange-500 rounded-full"></div>
          <span>Daily Study Activity</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-3 h-3 bg-blue-500 rounded-full"></div>
          <span>Current Day</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-4 h-0.5 bg-orange-500"></div>
          <span>Activity Trend</span>
        </div>
      </div>

      {/* Achievement Indicators - Only show meaningful data */}
      {(maxReviews > 0 || currentStreak > 0) && (
        <div className="mt-4 pt-4 border-t border-neutral-gray border-opacity-20">
          <div className="flex items-center justify-between text-sm">
            {maxReviews > 0 && (
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 bg-orange-500 rounded-full"></div>
                <span className="text-neutral-gray">Best Day: {maxReviews} cards</span>
              </div>
            )}
            {currentStreak >= 2 && (
              <div className="flex items-center gap-1 text-orange-600">
                <span>🔥</span>
                <span className="font-semibold">{currentStreak} day streak!</span>
              </div>
            )}
            {avgReviews > 0 && (
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 bg-indigo-500 rounded-full"></div>
                <span className="text-neutral-gray">Average: {avgReviews.toFixed(1)} cards/study day</span>
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
              {totalReviews > 0 && (
                <p>
                  📈 Study Activity: <span className="font-semibold text-indigo-600">{totalReviews}</span> total reviews in {type === 'weekly' ? 'last 7 days' : 'this month'}
                </p>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Empty State */}
      {totalReviews === 0 && (analyticsData?.cards_added || 0) === 0 && (
        <div className="mt-4 pt-4 border-t border-neutral-gray border-opacity-20">
          <div className="text-center py-8">
            <div className="text-4xl mb-2">📚</div>
            <h3 className="text-lg font-semibold text-gray-800 mb-2">Ready to start learning?</h3>
            <p className="text-gray-600 text-sm">
              Join some lessons and start studying cards to see your progress here!
            </p>
          </div>
        </div>
      )}
    </div>
  )
}

// Helper function to calculate current study streak with timezone awareness
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