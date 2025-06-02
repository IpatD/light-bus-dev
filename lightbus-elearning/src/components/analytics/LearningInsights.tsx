'use client'

import React, { useState, useEffect } from 'react'
import { LearningInsight, LearningInsightsProps, User } from '@/types'
import { supabase } from '@/lib/supabase'
import Card from '@/components/ui/Card'
import Button from '@/components/ui/Button'
import { 
  Brain, 
  TrendingUp, 
  Clock, 
  Target, 
  AlertTriangle,
  CheckCircle2,
  Star,
  BookOpen,
  Calendar,
  BarChart3,
  Lightbulb,
  ArrowRight,
  RefreshCw,
  Filter,
  ChevronDown,
  ChevronRight
} from 'lucide-react'

export function LearningInsights({ 
  insights, 
  student, 
  onActionTaken, 
  showRecommendations = true 
}: LearningInsightsProps) {
  const [expandedInsights, setExpandedInsights] = useState<string[]>([])
  const [filterType, setFilterType] = useState<string>('all')
  const [filterPriority, setFilterPriority] = useState<string>('all')
  const [loading, setLoading] = useState(false)

  const filteredInsights = insights.filter(insight => {
    if (!insight.is_active) return false
    if (filterType !== 'all' && insight.insight_type !== filterType) return false
    if (filterPriority !== 'all' && insight.priority_level.toString() !== filterPriority) return false
    return true
  }).sort((a, b) => b.priority_level - a.priority_level)

  const toggleInsightExpansion = (insightId: string) => {
    setExpandedInsights(prev => 
      prev.includes(insightId)
        ? prev.filter(id => id !== insightId)
        : [...prev, insightId]
    )
  }

  const handleActionTaken = async (insightId: string) => {
    if (!onActionTaken) return

    setLoading(true)
    try {
      await onActionTaken(insightId)
      
      // Mark insight as acted upon
      await supabase
        .from('learning_insights')
        .update({ 
          acted_upon: true,
          updated_at: new Date().toISOString()
        })
        .eq('id', insightId)
        
    } catch (error) {
      console.error('Failed to mark insight as acted upon:', error)
    } finally {
      setLoading(false)
    }
  }

  const getInsightIcon = (type: string) => {
    const icons = {
      weakness_identification: AlertTriangle,
      study_recommendation: BookOpen,
      optimal_timing: Clock,
      progress_prediction: TrendingUp,
      intervention_needed: Target
    }
    const Icon = icons[type as keyof typeof icons] || Lightbulb
    return <Icon className="w-5 h-5" />
  }

  const getInsightTitle = (type: string) => {
    const titles = {
      weakness_identification: 'Learning Weakness Identified',
      study_recommendation: 'Study Recommendation',
      optimal_timing: 'Optimal Study Timing',
      progress_prediction: 'Progress Prediction',
      intervention_needed: 'Intervention Needed'
    }
    return titles[type as keyof typeof titles] || 'Learning Insight'
  }

  const getPriorityColor = (priority: number) => {
    if (priority >= 4) return 'border-l-red-500 bg-red-50'
    if (priority >= 3) return 'border-l-orange-500 bg-orange-50'
    if (priority >= 2) return 'border-l-yellow-500 bg-yellow-50'
    return 'border-l-blue-500 bg-blue-50'
  }

  const getPriorityLabel = (priority: number) => {
    if (priority >= 4) return 'Critical'
    if (priority >= 3) return 'High'
    if (priority >= 2) return 'Medium'
    return 'Low'
  }

  const formatTimeAgo = (dateString: string) => {
    const date = new Date(dateString)
    const now = new Date()
    const diffInHours = Math.floor((now.getTime() - date.getTime()) / (1000 * 60 * 60))
    
    if (diffInHours < 1) return 'Just now'
    if (diffInHours < 24) return `${diffInHours}h ago`
    const diffInDays = Math.floor(diffInHours / 24)
    if (diffInDays < 7) return `${diffInDays}d ago`
    return date.toLocaleDateString()
  }

  const renderInsightContent = (insight: LearningInsight) => {
    const data = insight.insight_data

    switch (insight.insight_type) {
      case 'weakness_identification':
        return (
          <div className="space-y-3">
            {data.weak_areas && (
              <div>
                <h4 className="font-medium text-gray-900 mb-2">Areas of Concern:</h4>
                <div className="flex flex-wrap gap-2">
                  {data.weak_areas.map((area: string, index: number) => (
                    <span 
                      key={index}
                      className="px-2 py-1 bg-red-100 text-red-800 rounded-full text-sm"
                    >
                      {area}
                    </span>
                  ))}
                </div>
              </div>
            )}
            {data.performance_trend && (
              <div className="bg-gray-100 p-3 rounded">
                <span className="text-sm text-gray-700">
                  Performance trend: <strong>{data.performance_trend}</strong>
                </span>
              </div>
            )}
          </div>
        )

      case 'study_recommendation':
        return (
          <div className="space-y-3">
            {data.recommended_topics && (
              <div>
                <h4 className="font-medium text-gray-900 mb-2">Focus Topics:</h4>
                <ul className="list-disc list-inside space-y-1">
                  {data.recommended_topics.map((topic: string, index: number) => (
                    <li key={index} className="text-gray-700 text-sm">{topic}</li>
                  ))}
                </ul>
              </div>
            )}
            {data.study_duration && (
              <div className="flex items-center space-x-2">
                <Clock className="w-4 h-4 text-blue-500" />
                <span className="text-sm text-gray-700">
                  Recommended study time: <strong>{data.study_duration} minutes</strong>
                </span>
              </div>
            )}
            {data.difficulty_adjustment && (
              <div className="bg-blue-100 p-3 rounded">
                <span className="text-sm text-blue-800">
                  Difficulty adjustment: <strong>{data.difficulty_adjustment}</strong>
                </span>
              </div>
            )}
          </div>
        )

      case 'optimal_timing':
        return (
          <div className="space-y-3">
            {data.best_study_times && (
              <div>
                <h4 className="font-medium text-gray-900 mb-2">Optimal Study Times:</h4>
                <div className="grid grid-cols-2 gap-2">
                  {data.best_study_times.map((time: string, index: number) => (
                    <div key={index} className="bg-green-100 p-2 rounded text-center">
                      <span className="text-green-800 font-medium">{time}</span>
                    </div>
                  ))}
                </div>
              </div>
            )}
            {data.frequency_recommendation && (
              <div className="flex items-center space-x-2">
                <Calendar className="w-4 h-4 text-green-500" />
                <span className="text-sm text-gray-700">
                  Study frequency: <strong>{data.frequency_recommendation}</strong>
                </span>
              </div>
            )}
          </div>
        )

      case 'progress_prediction':
        return (
          <div className="space-y-3">
            {data.predicted_completion && (
              <div className="bg-purple-100 p-3 rounded">
                <div className="flex items-center space-x-2">
                  <Target className="w-4 h-4 text-purple-600" />
                  <span className="text-purple-800">
                    Predicted completion: <strong>{data.predicted_completion}</strong>
                  </span>
                </div>
              </div>
            )}
            {data.success_probability && (
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-700">Success probability:</span>
                <div className="flex items-center space-x-2">
                  <div className="w-24 bg-gray-200 rounded-full h-2">
                    <div 
                      className="bg-purple-500 h-2 rounded-full"
                      style={{ width: `${data.success_probability * 100}%` }}
                    />
                  </div>
                  <span className="text-sm font-medium">
                    {(data.success_probability * 100).toFixed(0)}%
                  </span>
                </div>
              </div>
            )}
          </div>
        )

      case 'intervention_needed':
        return (
          <div className="space-y-3">
            {data.intervention_type && (
              <div className="bg-red-100 border border-red-200 p-3 rounded">
                <div className="flex items-center space-x-2">
                  <AlertTriangle className="w-4 h-4 text-red-600" />
                  <span className="text-red-800 font-medium">
                    {data.intervention_type}
                  </span>
                </div>
              </div>
            )}
            {data.recommended_actions && (
              <div>
                <h4 className="font-medium text-gray-900 mb-2">Recommended Actions:</h4>
                <ul className="list-disc list-inside space-y-1">
                  {data.recommended_actions.map((action: string, index: number) => (
                    <li key={index} className="text-gray-700 text-sm">{action}</li>
                  ))}
                </ul>
              </div>
            )}
          </div>
        )

      default:
        return (
          <pre className="text-sm text-gray-600 bg-gray-100 p-3 rounded overflow-auto">
            {JSON.stringify(data, null, 2)}
          </pre>
        )
    }
  }

  const getInsightSummary = (insight: LearningInsight): string => {
    const data = insight.insight_data
    
    switch (insight.insight_type) {
      case 'weakness_identification':
        return data.summary || `Identified ${data.weak_areas?.length || 0} areas needing attention`
      case 'study_recommendation':
        return data.summary || `Focus on ${data.recommended_topics?.length || 0} key topics`
      case 'optimal_timing':
        return data.summary || `Best study times identified for optimal learning`
      case 'progress_prediction':
        return data.summary || `Completion predicted for ${data.predicted_completion || 'unknown date'}`
      case 'intervention_needed':
        return data.summary || `Immediate attention required: ${data.intervention_type || 'support needed'}`
      default:
        return 'AI-generated learning insight available'
    }
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Learning Insights</h2>
          <p className="text-gray-600">
            AI-powered recommendations for {student.name}
          </p>
        </div>

        {/* Filters */}
        <div className="flex items-center space-x-3">
          <select
            value={filterType}
            onChange={(e) => setFilterType(e.target.value)}
            className="border border-gray-300 rounded-md px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          >
            <option value="all">All Types</option>
            <option value="weakness_identification">Weaknesses</option>
            <option value="study_recommendation">Recommendations</option>
            <option value="optimal_timing">Timing</option>
            <option value="progress_prediction">Predictions</option>
            <option value="intervention_needed">Interventions</option>
          </select>

          <select
            value={filterPriority}
            onChange={(e) => setFilterPriority(e.target.value)}
            className="border border-gray-300 rounded-md px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          >
            <option value="all">All Priorities</option>
            <option value="5">Critical</option>
            <option value="4">High</option>
            <option value="3">Medium</option>
            <option value="2">Low</option>
          </select>
        </div>
      </div>

      {/* Insights List */}
      <div className="space-y-4">
        {filteredInsights.length === 0 ? (
          <Card className="p-8 text-center">
            <div className="text-gray-500">
              <Lightbulb className="w-12 h-12 mx-auto mb-4 opacity-50" />
              <h3 className="text-lg font-medium mb-2">No Insights Available</h3>
              <p>No learning insights match your current filter criteria.</p>
            </div>
          </Card>
        ) : (
          filteredInsights.map(insight => {
            const isExpanded = expandedInsights.includes(insight.id)
            
            return (
              <Card 
                key={insight.id} 
                className={`border-l-4 ${getPriorityColor(insight.priority_level)}`}
              >
                <div className="p-6">
                  {/* Header */}
                  <div 
                    className="flex items-center justify-between cursor-pointer"
                    onClick={() => toggleInsightExpansion(insight.id)}
                  >
                    <div className="flex items-center space-x-3">
                      {getInsightIcon(insight.insight_type)}
                      <div>
                        <h3 className="font-semibold text-gray-900">
                          {getInsightTitle(insight.insight_type)}
                        </h3>
                        <p className="text-sm text-gray-600">
                          {getInsightSummary(insight)}
                        </p>
                      </div>
                    </div>
                    
                    <div className="flex items-center space-x-3">
                      <div className="text-right">
                        <span className={`px-2 py-1 rounded text-xs font-medium ${
                          insight.priority_level >= 4 ? 'bg-red-100 text-red-800' :
                          insight.priority_level >= 3 ? 'bg-orange-100 text-orange-800' :
                          insight.priority_level >= 2 ? 'bg-yellow-100 text-yellow-800' :
                          'bg-blue-100 text-blue-800'
                        }`}>
                          {getPriorityLabel(insight.priority_level)}
                        </span>
                        <div className="text-xs text-gray-500 mt-1">
                          {formatTimeAgo(insight.created_at)}
                        </div>
                      </div>
                      
                      {isExpanded ? (
                        <ChevronDown className="w-5 h-5 text-gray-400" />
                      ) : (
                        <ChevronRight className="w-5 h-5 text-gray-400" />
                      )}
                    </div>
                  </div>

                  {/* Expanded Content */}
                  {isExpanded && (
                    <div className="mt-6 space-y-4">
                      {renderInsightContent(insight)}
                      
                      {/* Confidence Score */}
                      {insight.confidence_score && (
                        <div className="flex items-center space-x-2">
                          <Star className="w-4 h-4 text-yellow-500" />
                          <span className="text-sm text-gray-600">
                            Confidence: {(insight.confidence_score * 100).toFixed(0)}%
                          </span>
                        </div>
                      )}

                      {/* Actions */}
                      {!insight.acted_upon && (
                        <div className="flex justify-end pt-4 border-t">
                          <Button
                            variant="primary"
                            size="sm"
                            onClick={() => handleActionTaken(insight.id)}
                            disabled={loading}
                          >
                            <CheckCircle2 className="w-4 h-4 mr-1" />
                            Mark as Addressed
                          </Button>
                        </div>
                      )}

                      {insight.acted_upon && (
                        <div className="bg-green-100 border border-green-200 rounded p-3">
                          <div className="flex items-center space-x-2">
                            <CheckCircle2 className="w-4 h-4 text-green-600" />
                            <span className="text-green-800 text-sm font-medium">
                              This insight has been addressed
                            </span>
                          </div>
                        </div>
                      )}
                    </div>
                  )}
                </div>
              </Card>
            )
          })
        )}
      </div>

      {/* Summary Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-4 gap-4">
        <Card className="p-4 text-center">
          <div className="text-2xl font-bold text-red-600">
            {insights.filter(i => i.priority_level >= 4 && i.is_active).length}
          </div>
          <div className="text-sm text-gray-600">Critical Insights</div>
        </Card>
        
        <Card className="p-4 text-center">
          <div className="text-2xl font-bold text-orange-600">
            {insights.filter(i => i.priority_level === 3 && i.is_active).length}
          </div>
          <div className="text-sm text-gray-600">High Priority</div>
        </Card>
        
        <Card className="p-4 text-center">
          <div className="text-2xl font-bold text-green-600">
            {insights.filter(i => i.acted_upon).length}
          </div>
          <div className="text-sm text-gray-600">Addressed</div>
        </Card>
        
        <Card className="p-4 text-center">
          <div className="text-2xl font-bold text-blue-600">
            {(insights.reduce((sum, i) => sum + (i.confidence_score || 0), 0) / insights.length * 100).toFixed(0)}%
          </div>
          <div className="text-sm text-gray-600">Avg Confidence</div>
        </Card>
      </div>
    </div>
  )
}