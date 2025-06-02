'use client'

import React, { useState } from 'react'
import { ContentAnalysis, ContentAnalysisProps, Lesson } from '@/types'
import Card from '@/components/ui/Card'
import Button from '@/components/ui/Button'
import { 
  Brain, 
  Target, 
  BookOpen, 
  TrendingUp, 
  Tag, 
  ChevronDown, 
  ChevronRight,
  Download,
  Eye,
  Lightbulb,
  AlertCircle,
  CheckCircle2
} from 'lucide-react'

export function ContentAnalysisDisplay({ 
  analysis, 
  lesson, 
  onExport, 
  showInsights = true 
}: ContentAnalysisProps) {
  const [expandedSections, setExpandedSections] = useState<string[]>(['key_concepts'])
  const [selectedAnalysis, setSelectedAnalysis] = useState<string>('all')

  const toggleSection = (sectionId: string) => {
    setExpandedSections(prev => 
      prev.includes(sectionId)
        ? prev.filter(id => id !== sectionId)
        : [...prev, sectionId]
    )
  }

  const filteredAnalysis = selectedAnalysis === 'all' 
    ? analysis 
    : analysis.filter(item => item.analysis_type === selectedAnalysis)

  const getAnalysisIcon = (type: string) => {
    const icons = {
      key_concepts: Brain,
      learning_objectives: Target,
      prerequisites: BookOpen,
      difficulty_assessment: TrendingUp,
      topic_extraction: Tag
    }
    const Icon = icons[type as keyof typeof icons] || Brain
    return <Icon className="w-5 h-5" />
  }

  const getAnalysisTitle = (type: string) => {
    const titles = {
      key_concepts: 'Key Concepts',
      learning_objectives: 'Learning Objectives',
      prerequisites: 'Prerequisites',
      difficulty_assessment: 'Difficulty Assessment',
      topic_extraction: 'Topic Extraction'
    }
    return titles[type as keyof typeof titles] || type
  }

  const getConfidenceColor = (score?: number) => {
    if (!score) return 'text-gray-500 bg-gray-100'
    if (score >= 0.8) return 'text-green-600 bg-green-100'
    if (score >= 0.6) return 'text-yellow-600 bg-yellow-100'
    return 'text-red-600 bg-red-100'
  }

  const renderKeyConceptsAnalysis = (data: any) => (
    <div className="space-y-4">
      {data.key_concepts?.map((concept: any, index: number) => (
        <div key={index} className="border border-gray-200 rounded-lg p-4">
          <div className="flex items-start justify-between mb-2">
            <h4 className="font-semibold text-gray-900">{concept.name || concept}</h4>
            {concept.importance_level && (
              <div className="flex items-center space-x-1">
                {[...Array(5)].map((_, i) => (
                  <div 
                    key={i}
                    className={`w-2 h-2 rounded-full ${
                      i < concept.importance_level ? 'bg-blue-500' : 'bg-gray-200'
                    }`}
                  />
                ))}
              </div>
            )}
          </div>
          {concept.description && (
            <p className="text-gray-600 text-sm">{concept.description}</p>
          )}
        </div>
      ))}
    </div>
  )

  const renderLearningObjectivesAnalysis = (data: any) => (
    <div className="space-y-4">
      {data.learning_objectives?.map((objective: any, index: number) => (
        <div key={index} className="border border-gray-200 rounded-lg p-4">
          <div className="flex items-start justify-between mb-2">
            <p className="font-medium text-gray-900">{objective.objective || objective}</p>
            {objective.cognitive_level && (
              <span className="px-2 py-1 bg-purple-100 text-purple-800 rounded text-xs font-medium">
                {objective.cognitive_level}
              </span>
            )}
          </div>
          {objective.measurability_score && (
            <div className="flex items-center space-x-2 mt-2">
              <span className="text-sm text-gray-600">Measurability:</span>
              <div className="flex-1 bg-gray-200 rounded-full h-2">
                <div 
                  className="bg-green-500 h-2 rounded-full"
                  style={{ width: `${objective.measurability_score * 100}%` }}
                />
              </div>
              <span className="text-sm text-gray-600">
                {(objective.measurability_score * 100).toFixed(0)}%
              </span>
            </div>
          )}
        </div>
      ))}
    </div>
  )

  const renderPrerequisitesAnalysis = (data: any) => (
    <div className="space-y-4">
      {data.prerequisites?.map((prereq: any, index: number) => (
        <div key={index} className="border border-gray-200 rounded-lg p-4">
          <div className="flex items-start justify-between mb-2">
            <h4 className="font-semibold text-gray-900">{prereq.topic || prereq}</h4>
            {prereq.importance_level && (
              <span className={`px-2 py-1 rounded text-xs font-medium ${
                prereq.importance_level === 'high' ? 'bg-red-100 text-red-800' :
                prereq.importance_level === 'medium' ? 'bg-yellow-100 text-yellow-800' :
                'bg-green-100 text-green-800'
              }`}>
                {prereq.importance_level} importance
              </span>
            )}
          </div>
          {prereq.justification && (
            <p className="text-gray-600 text-sm">{prereq.justification}</p>
          )}
        </div>
      ))}
    </div>
  )

  const renderDifficultyAnalysis = (data: any) => (
    <div className="space-y-4">
      {data.overall_difficulty && (
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <div className="flex items-center justify-between mb-2">
            <h4 className="font-semibold text-blue-900">Overall Difficulty</h4>
            <span className="text-2xl font-bold text-blue-600">
              {data.overall_difficulty}/10
            </span>
          </div>
          <div className="w-full bg-blue-200 rounded-full h-3">
            <div 
              className="bg-blue-600 h-3 rounded-full"
              style={{ width: `${data.overall_difficulty * 10}%` }}
            />
          </div>
        </div>
      )}

      {data.difficulty_factors && (
        <div>
          <h4 className="font-semibold text-gray-900 mb-3">Difficulty Factors</h4>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {data.difficulty_factors.map((factor: string, index: number) => (
              <div key={index} className="flex items-center space-x-2">
                <AlertCircle className="w-4 h-4 text-orange-500" />
                <span className="text-gray-700 text-sm">{factor}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {data.recommendations && (
        <div>
          <h4 className="font-semibold text-gray-900 mb-3">Recommendations</h4>
          <div className="space-y-2">
            {Object.entries(data.recommendations).map(([level, recs]: [string, any], index) => (
              <div key={index} className="border border-gray-200 rounded-lg p-3">
                <h5 className="font-medium text-gray-800 capitalize mb-2">{level} Learners</h5>
                <ul className="list-disc list-inside space-y-1">
                  {Array.isArray(recs) ? recs.map((rec: string, i: number) => (
                    <li key={i} className="text-gray-600 text-sm">{rec}</li>
                  )) : (
                    <li className="text-gray-600 text-sm">{recs}</li>
                  )}
                </ul>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )

  const renderTopicExtraction = (data: any) => (
    <div className="space-y-4">
      {data.topics?.map((topic: any, index: number) => (
        <div key={index} className="border border-gray-200 rounded-lg p-4">
          <div className="flex items-start justify-between mb-2">
            <div>
              <h4 className="font-semibold text-gray-900">{topic.name || topic}</h4>
              {topic.category && (
                <span className="text-sm text-gray-600">{topic.category}</span>
              )}
            </div>
            {topic.relevance_score && (
              <div className="text-right">
                <div className="text-sm text-gray-600">Relevance</div>
                <div className="font-medium text-blue-600">
                  {(topic.relevance_score * 100).toFixed(0)}%
                </div>
              </div>
            )}
          </div>
          {topic.subtopics && (
            <div className="mt-3">
              <div className="flex flex-wrap gap-2">
                {topic.subtopics.map((subtopic: string, i: number) => (
                  <span 
                    key={i}
                    className="px-2 py-1 bg-gray-100 text-gray-700 rounded text-xs"
                  >
                    {subtopic}
                  </span>
                ))}
              </div>
            </div>
          )}
        </div>
      ))}
    </div>
  )

  const renderAnalysisData = (analysisItem: ContentAnalysis) => {
    const { analysis_type, analysis_data } = analysisItem

    switch (analysis_type) {
      case 'key_concepts':
        return renderKeyConceptsAnalysis(analysis_data)
      case 'learning_objectives':
        return renderLearningObjectivesAnalysis(analysis_data)
      case 'prerequisites':
        return renderPrerequisitesAnalysis(analysis_data)
      case 'difficulty_assessment':
        return renderDifficultyAnalysis(analysis_data)
      case 'topic_extraction':
        return renderTopicExtraction(analysis_data)
      default:
        return (
          <pre className="text-sm text-gray-600 bg-gray-100 p-3 rounded overflow-auto">
            {JSON.stringify(analysis_data, null, 2)}
          </pre>
        )
    }
  }

  if (analysis.length === 0) {
    return (
      <Card className="p-8 text-center">
        <div className="text-gray-500">
          <Brain className="w-12 h-12 mx-auto mb-4 opacity-50" />
          <h3 className="text-lg font-medium mb-2">No Analysis Available</h3>
          <p>Content analysis has not been performed for this lesson yet.</p>
        </div>
      </Card>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Content Analysis</h2>
          <p className="text-gray-600">
            AI-powered analysis for "{lesson.name}"
          </p>
        </div>

        <div className="flex items-center space-x-3">
          <select
            value={selectedAnalysis}
            onChange={(e) => setSelectedAnalysis(e.target.value)}
            className="border border-gray-300 rounded-md px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          >
            <option value="all">All Analysis Types</option>
            <option value="key_concepts">Key Concepts</option>
            <option value="learning_objectives">Learning Objectives</option>
            <option value="prerequisites">Prerequisites</option>
            <option value="difficulty_assessment">Difficulty Assessment</option>
            <option value="topic_extraction">Topic Extraction</option>
          </select>

          {onExport && (
            <Button
              variant="secondary"
              size="sm"
              onClick={onExport}
            >
              <Download className="w-4 h-4 mr-1" />
              Export
            </Button>
          )}
        </div>
      </div>

      {/* Analysis Sections */}
      <div className="space-y-4">
        {filteredAnalysis.map((analysisItem, index) => {
          const isExpanded = expandedSections.includes(analysisItem.analysis_type)
          
          return (
            <Card key={index} className="overflow-hidden">
              <div 
                className="flex items-center justify-between p-4 cursor-pointer hover:bg-gray-50"
                onClick={() => toggleSection(analysisItem.analysis_type)}
              >
                <div className="flex items-center space-x-3">
                  {getAnalysisIcon(analysisItem.analysis_type)}
                  <div>
                    <h3 className="font-semibold text-gray-900">
                      {getAnalysisTitle(analysisItem.analysis_type)}
                    </h3>
                    <p className="text-sm text-gray-600">
                      Analyzed on {new Date(analysisItem.created_at).toLocaleDateString()}
                    </p>
                  </div>
                </div>
                
                <div className="flex items-center space-x-3">
                  {analysisItem.confidence_score && (
                    <span className={`px-2 py-1 rounded text-xs font-medium ${getConfidenceColor(analysisItem.confidence_score)}`}>
                      {(analysisItem.confidence_score * 100).toFixed(0)}% confidence
                    </span>
                  )}
                  {isExpanded ? (
                    <ChevronDown className="w-5 h-5 text-gray-400" />
                  ) : (
                    <ChevronRight className="w-5 h-5 text-gray-400" />
                  )}
                </div>
              </div>

              {isExpanded && (
                <div className="border-t border-gray-200 p-4">
                  {renderAnalysisData(analysisItem)}
                </div>
              )}
            </Card>
          )
        })}
      </div>

      {/* Insights Section */}
      {showInsights && (
        <Card className="p-6 bg-blue-50 border-blue-200">
          <div className="flex items-start space-x-3">
            <Lightbulb className="w-6 h-6 text-blue-600 mt-1" />
            <div>
              <h3 className="font-semibold text-blue-900 mb-2">AI Insights</h3>
              <div className="space-y-2 text-blue-800">
                <p>• This content covers {analysis.length} different analytical dimensions</p>
                <p>• Average confidence score: {
                  (analysis.reduce((sum, item) => sum + (item.confidence_score || 0), 0) / analysis.length * 100).toFixed(0)
                }%</p>
                <p>• Content analysis completed on {new Date(analysis[0]?.created_at).toLocaleDateString()}</p>
              </div>
            </div>
          </div>
        </Card>
      )}
    </div>
  )
}