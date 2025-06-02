'use client'

import React, { useState } from 'react'
import { ProcessingStatus } from '@/components/ai/ProcessingStatus'
import { AICardReview } from '@/components/ai/AICardReview'
import { ContentAnalysisDisplay } from '@/components/ai/ContentAnalysis'
import { TranscriptViewer } from '@/components/lessons/TranscriptViewer'
import { LearningInsights } from '@/components/analytics/LearningInsights'
import Card from '@/components/ui/Card'
import Button from '@/components/ui/Button'
import { 
  Brain, 
  FileAudio, 
  MessageSquare, 
  BarChart3,
  Sparkles,
  Play,
  ChevronRight,
  CheckCircle2
} from 'lucide-react'

// Mock data for demonstration
const mockProcessingJob = {
  id: 'demo-job-1',
  lesson_id: 'demo-lesson-1',
  job_type: 'transcription' as const,
  status: 'completed' as const,
  progress_percentage: 100,
  output_data: {
    transcript_id: 'demo-transcript-1',
    word_count: 1250,
    processing_time_ms: 45000
  },
  ai_service_provider: 'openai' as const,
  created_by: 'demo-user',
  created_at: new Date().toISOString(),
  updated_at: new Date().toISOString(),
  cost_cents: 250
}

const mockLesson = {
  id: 'demo-lesson-1',
  teacher_id: 'demo-teacher',
  name: 'Introduction to Machine Learning',
  description: 'Fundamental concepts of machine learning and neural networks',
  scheduled_at: new Date().toISOString(),
  has_audio: true,
  created_at: new Date().toISOString(),
  updated_at: new Date().toISOString()
}

const mockTranscript = {
  id: 'demo-transcript-1',
  lesson_id: 'demo-lesson-1',
  content: `Welcome to our introduction to machine learning. Today we'll explore the fundamental concepts that drive artificial intelligence and how neural networks learn from data.

Machine learning is a subset of artificial intelligence that enables computers to learn and improve from experience without being explicitly programmed. The key insight is that instead of writing specific instructions for every possible scenario, we can train algorithms to recognize patterns in data.

There are three main types of machine learning: supervised learning, unsupervised learning, and reinforcement learning. Supervised learning uses labeled data to train models, while unsupervised learning finds patterns in unlabeled data. Reinforcement learning learns through trial and error with a reward system.

Neural networks are inspired by the human brain and consist of interconnected nodes called neurons. Each connection has a weight that determines the strength of the signal. During training, these weights are adjusted to minimize prediction errors.

The process of training involves feeding data through the network, comparing outputs to expected results, and using backpropagation to update weights. This iterative process gradually improves the model's accuracy.`,
  transcript_type: 'auto' as const,
  confidence_score: 0.92,
  created_at: new Date().toISOString(),
  updated_at: new Date().toISOString()
}

const mockGeneratedCards = [
  {
    id: 'card-1',
    lesson_id: 'demo-lesson-1',
    front_content: 'What are the three main types of machine learning?',
    back_content: 'The three main types are: 1) Supervised learning (uses labeled data), 2) Unsupervised learning (finds patterns in unlabeled data), and 3) Reinforcement learning (learns through trial and error with rewards).',
    card_type: 'basic' as const,
    difficulty_level: 2,
    confidence_score: 0.89,
    quality_score: 0.85,
    review_status: 'pending' as const,
    tags: ['machine learning', 'types', 'supervised', 'unsupervised', 'reinforcement'],
    auto_approved: false,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  },
  {
    id: 'card-2',
    lesson_id: 'demo-lesson-1',
    front_content: 'Neural networks are inspired by the {...} and consist of interconnected nodes called {...}.',
    back_content: 'Neural networks are inspired by the human brain and consist of interconnected nodes called neurons.',
    card_type: 'cloze' as const,
    difficulty_level: 3,
    confidence_score: 0.92,
    quality_score: 0.91,
    review_status: 'approved' as const,
    tags: ['neural networks', 'brain', 'neurons'],
    auto_approved: true,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  },
  {
    id: 'card-3',
    lesson_id: 'demo-lesson-1',
    front_content: 'What is the purpose of backpropagation in neural network training?',
    back_content: 'Backpropagation is used to update the weights in a neural network by calculating gradients and propagating errors backward through the network to minimize prediction errors.',
    card_type: 'basic' as const,
    difficulty_level: 4,
    confidence_score: 0.87,
    quality_score: 0.88,
    review_status: 'pending' as const,
    tags: ['backpropagation', 'training', 'weights', 'gradients'],
    auto_approved: false,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  }
]

const mockContentAnalysis = [
  {
    id: 'analysis-1',
    lesson_id: 'demo-lesson-1',
    analysis_type: 'key_concepts' as const,
    analysis_data: {
      key_concepts: [
        {
          name: 'Machine Learning',
          description: 'A subset of AI that enables computers to learn from data without explicit programming',
          importance_level: 5
        },
        {
          name: 'Neural Networks',
          description: 'Brain-inspired computing systems with interconnected neurons',
          importance_level: 4
        },
        {
          name: 'Supervised Learning',
          description: 'Learning approach using labeled training data',
          importance_level: 4
        },
        {
          name: 'Backpropagation',
          description: 'Algorithm for training neural networks by adjusting weights',
          importance_level: 3
        }
      ]
    },
    confidence_score: 0.91,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  },
  {
    id: 'analysis-2',
    lesson_id: 'demo-lesson-1',
    analysis_type: 'difficulty_assessment' as const,
    analysis_data: {
      overall_difficulty: 6,
      difficulty_factors: [
        'Abstract mathematical concepts',
        'Technical terminology',
        'Interconnected concepts requiring synthesis'
      ],
      recommendations: {
        beginner: [
          'Start with visual analogies and examples',
          'Focus on conceptual understanding before technical details',
          'Use interactive demonstrations'
        ],
        intermediate: [
          'Practice with real datasets',
          'Implement basic algorithms',
          'Study mathematical foundations'
        ],
        advanced: [
          'Explore advanced architectures',
          'Optimize hyperparameters',
          'Research latest techniques'
        ]
      }
    },
    confidence_score: 0.85,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  }
]

const mockStudent = {
  id: 'demo-student',
  email: 'student@demo.com',
  name: 'Alex Thompson',
  role: 'student' as const,
  created_at: new Date().toISOString(),
  updated_at: new Date().toISOString()
}

const mockInsights = [
  {
    id: 'insight-1',
    student_id: 'demo-student',
    lesson_id: 'demo-lesson-1',
    insight_type: 'weakness_identification' as const,
    insight_data: {
      weak_areas: ['Neural Network Architecture', 'Backpropagation Algorithm'],
      performance_trend: 'Declining in advanced topics',
      summary: 'Student struggling with technical implementation details'
    },
    priority_level: 4,
    confidence_score: 0.87,
    is_active: true,
    acted_upon: false,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  },
  {
    id: 'insight-2',
    student_id: 'demo-student',
    lesson_id: 'demo-lesson-1',
    insight_type: 'study_recommendation' as const,
    insight_data: {
      recommended_topics: ['Linear Algebra Basics', 'Gradient Descent', 'Loss Functions'],
      study_duration: 45,
      difficulty_adjustment: 'Increase foundation review time',
      summary: 'Focus on mathematical foundations before advanced concepts'
    },
    priority_level: 3,
    confidence_score: 0.92,
    is_active: true,
    acted_upon: false,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  }
]

export default function AIFeaturesDemo() {
  const [activeDemo, setActiveDemo] = useState<string>('overview')
  const [processingStep, setProcessingStep] = useState(0)

  const demoSections = [
    {
      id: 'overview',
      title: 'AI Features Overview',
      icon: Sparkles,
      description: 'Comprehensive AI-powered learning platform capabilities'
    },
    {
      id: 'processing',
      title: 'Audio Processing',
      icon: FileAudio,
      description: 'Real-time audio transcription and summarization'
    },
    {
      id: 'cards',
      title: 'Flashcard Generation',
      icon: MessageSquare,
      description: 'AI-generated flashcards with quality review'
    },
    {
      id: 'analysis',
      title: 'Content Analysis',
      icon: Brain,
      description: 'Deep content analysis and insights'
    },
    {
      id: 'insights',
      title: 'Learning Analytics',
      icon: BarChart3,
      description: 'Personalized learning insights and recommendations'
    }
  ]

  const processingWorkflow = [
    { step: 'Upload', description: 'Teacher uploads lesson audio', completed: true },
    { step: 'Transcribe', description: 'AI converts speech to text', completed: true },
    { step: 'Analyze', description: 'Extract key concepts and structure', completed: true },
    { step: 'Generate', description: 'Create flashcards automatically', completed: processingStep >= 3 },
    { step: 'Review', description: 'Teacher reviews and approves', completed: processingStep >= 4 },
    { step: 'Deploy', description: 'Cards available to students', completed: processingStep >= 5 }
  ]

  const handleCardApprove = async (cardIds: string[]) => {
    console.log('Approving cards:', cardIds)
    // Simulate API call
    await new Promise(resolve => setTimeout(resolve, 1000))
  }

  const handleCardReject = async (cardIds: string[]) => {
    console.log('Rejecting cards:', cardIds)
    // Simulate API call
    await new Promise(resolve => setTimeout(resolve, 1000))
  }

  const handleCardEdit = async (cardId: string, updates: any) => {
    console.log('Editing card:', cardId, updates)
    // Simulate API call
    await new Promise(resolve => setTimeout(resolve, 1000))
  }

  const handleInsightAction = async (insightId: string) => {
    console.log('Acting on insight:', insightId)
    // Simulate API call
    await new Promise(resolve => setTimeout(resolve, 1000))
  }

  const renderOverview = () => (
    <div className="space-y-8">
      <div className="text-center">
        <h1 className="text-4xl font-bold text-gray-900 mb-4">
          AI-Powered Learning Platform
        </h1>
        <p className="text-xl text-gray-600 max-w-3xl mx-auto">
          Experience the future of education with our comprehensive AI features that transform 
          audio lessons into interactive learning experiences with automated transcription, 
          intelligent flashcard generation, and personalized analytics.
        </p>
      </div>

      {/* Feature Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {demoSections.slice(1).map(section => {
          const Icon = section.icon
          return (
            <Card 
              key={section.id} 
              className="p-6 hover:shadow-lg transition-shadow cursor-pointer"
              onClick={() => setActiveDemo(section.id)}
            >
              <div className="text-center">
                <div className="bg-blue-100 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4">
                  <Icon className="w-8 h-8 text-blue-600" />
                </div>
                <h3 className="font-semibold text-gray-900 mb-2">{section.title}</h3>
                <p className="text-gray-600 text-sm">{section.description}</p>
              </div>
            </Card>
          )
        })}
      </div>

      {/* Processing Workflow */}
      <Card className="p-8">
        <h2 className="text-2xl font-bold text-gray-900 mb-6 text-center">
          End-to-End AI Processing Workflow
        </h2>
        
        <div className="flex items-center justify-between mb-6">
          {processingWorkflow.map((item, index) => (
            <div key={index} className="flex flex-col items-center">
              <div className={`w-12 h-12 rounded-full flex items-center justify-center mb-2 ${
                item.completed ? 'bg-green-500 text-white' : 'bg-gray-300 text-gray-600'
              }`}>
                {item.completed ? (
                  <CheckCircle2 className="w-6 h-6" />
                ) : (
                  <span className="font-semibold">{index + 1}</span>
                )}
              </div>
              <div className="text-center">
                <div className="font-medium text-gray-900">{item.step}</div>
                <div className="text-xs text-gray-600 max-w-20">{item.description}</div>
              </div>
              {index < processingWorkflow.length - 1 && (
                <ChevronRight className="w-6 h-6 text-gray-400 absolute translate-x-16" />
              )}
            </div>
          ))}
        </div>

        <div className="text-center">
          <Button
            variant="primary"
            onClick={() => {
              setProcessingStep(prev => (prev + 1) % 6)
            }}
          >
            <Play className="w-4 h-4 mr-2" />
            Simulate Processing Step
          </Button>
        </div>
      </Card>
    </div>
  )

  const renderContent = () => {
    switch (activeDemo) {
      case 'overview':
        return renderOverview()
      
      case 'processing':
        return (
          <div className="space-y-6">
            <div className="text-center mb-8">
              <h2 className="text-3xl font-bold text-gray-900 mb-4">Audio Processing</h2>
              <p className="text-gray-600">Real-time audio transcription with AI-powered analysis</p>
            </div>
            
            <ProcessingStatus 
              jobId={mockProcessingJob.id}
              onComplete={(result) => console.log('Processing completed:', result)}
              onError={(error) => console.error('Processing error:', error)}
            />
            
            <TranscriptViewer
              transcript={mockTranscript}
              lesson={mockLesson}
              onCreateCard={(selection) => console.log('Creating card from:', selection)}
              onExport={(format) => console.log('Exporting as:', format)}
            />
          </div>
        )
      
      case 'cards':
        return (
          <div className="space-y-6">
            <div className="text-center mb-8">
              <h2 className="text-3xl font-bold text-gray-900 mb-4">AI Flashcard Generation</h2>
              <p className="text-gray-600">Automatically generated flashcards with teacher review workflow</p>
            </div>
            
            <AICardReview
              cards={mockGeneratedCards}
              onApprove={handleCardApprove}
              onReject={handleCardReject}
              onEdit={handleCardEdit}
            />
          </div>
        )
      
      case 'analysis':
        return (
          <div className="space-y-6">
            <div className="text-center mb-8">
              <h2 className="text-3xl font-bold text-gray-900 mb-4">Content Analysis</h2>
              <p className="text-gray-600">Deep AI analysis of educational content</p>
            </div>
            
            <ContentAnalysisDisplay
              analysis={mockContentAnalysis}
              lesson={mockLesson}
              onExport={() => console.log('Exporting analysis')}
            />
          </div>
        )
      
      case 'insights':
        return (
          <div className="space-y-6">
            <div className="text-center mb-8">
              <h2 className="text-3xl font-bold text-gray-900 mb-4">Learning Analytics</h2>
              <p className="text-gray-600">AI-powered insights and personalized recommendations</p>
            </div>
            
            <LearningInsights
              insights={mockInsights}
              student={mockStudent}
              onActionTaken={handleInsightAction}
            />
          </div>
        )
      
      default:
        return renderOverview()
    }
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Navigation */}
      <div className="bg-white border-b border-gray-200 sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center space-x-8">
              <h1 className="text-xl font-bold text-gray-900">AI Features Demo</h1>
              <nav className="flex space-x-4">
                {demoSections.map(section => (
                  <button
                    key={section.id}
                    onClick={() => setActiveDemo(section.id)}
                    className={`px-3 py-2 text-sm font-medium rounded-md transition-colors ${
                      activeDemo === section.id
                        ? 'bg-blue-100 text-blue-700'
                        : 'text-gray-600 hover:text-gray-900 hover:bg-gray-100'
                    }`}
                  >
                    {section.title}
                  </button>
                ))}
              </nav>
            </div>
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {renderContent()}
      </div>
    </div>
  )
}