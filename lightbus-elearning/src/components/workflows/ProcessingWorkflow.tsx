'use client'

import React, { useState, useEffect } from 'react'
import { ProcessingWorkflow as WorkflowType, ProcessingJob } from '@/types'
import { supabase } from '@/lib/supabase'
import Card from '@/components/ui/Card'
import Button from '@/components/ui/Button'
import { 
  Play, 
  Pause, 
  RotateCcw, 
  CheckCircle2, 
  XCircle,
  Clock,
  AlertCircle,
  ArrowRight,
  Settings,
  Eye,
  Download
} from 'lucide-react'

interface ProcessingWorkflowProps {
  lessonId: string
  workflowType?: 'full_processing' | 'transcription_only' | 'cards_only' | 'analysis_only'
  onComplete?: (results: any) => void
  onError?: (error: string) => void
}

export function ProcessingWorkflow({ 
  lessonId, 
  workflowType = 'full_processing',
  onComplete,
  onError 
}: ProcessingWorkflowProps) {
  const [workflow, setWorkflow] = useState<WorkflowType | null>(null)
  const [activeJobs, setActiveJobs] = useState<ProcessingJob[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // Define workflow steps based on type
  const workflowSteps = {
    full_processing: [
      { id: 'transcription', name: 'Audio Transcription', dependencies: [] },
      { id: 'summarization', name: 'Content Summarization', dependencies: ['transcription'] },
      { id: 'content_analysis', name: 'Content Analysis', dependencies: ['transcription'] },
      { id: 'flashcard_generation', name: 'Flashcard Generation', dependencies: ['transcription', 'content_analysis'] },
      { id: 'review', name: 'Teacher Review', dependencies: ['flashcard_generation'] },
      { id: 'deployment', name: 'Student Deployment', dependencies: ['review'] }
    ],
    transcription_only: [
      { id: 'transcription', name: 'Audio Transcription', dependencies: [] }
    ],
    cards_only: [
      { id: 'flashcard_generation', name: 'Flashcard Generation', dependencies: [] }
    ],
    analysis_only: [
      { id: 'content_analysis', name: 'Content Analysis', dependencies: [] }
    ]
  }

  const steps = workflowSteps[workflowType]

  useEffect(() => {
    // Initialize workflow state
    initializeWorkflow()
    
    // Set up real-time subscriptions for job updates
    const subscription = supabase
      .channel('processing_jobs')
      .on('postgres_changes', 
        { 
          event: '*', 
          schema: 'public', 
          table: 'processing_jobs',
          filter: `lesson_id=eq.${lessonId}`
        }, 
        handleJobUpdate
      )
      .subscribe()

    return () => {
      subscription.unsubscribe()
    }
  }, [lessonId, workflowType])

  const initializeWorkflow = () => {
    const initialWorkflow: WorkflowType = {
      id: `workflow-${lessonId}-${Date.now()}`,
      lesson_id: lessonId,
      workflow_type: workflowType,
      status: 'pending',
      steps: steps.map(step => ({
        id: step.id,
        name: step.name,
        status: 'pending',
        progress_percentage: 0,
        dependencies: step.dependencies,
        can_retry: true,
        can_skip: step.id === 'review' // Only review step can be skipped
      })),
      total_cost_cents: 0
    }
    
    setWorkflow(initialWorkflow)
  }

  const handleJobUpdate = (payload: any) => {
    const job = payload.new as ProcessingJob
    
    setActiveJobs(prev => {
      const updated = prev.filter(j => j.id !== job.id)
      return [...updated, job]
    })

    // Update workflow step status based on job status
    if (workflow) {
      const updatedWorkflow = { ...workflow }
      const stepIndex = updatedWorkflow.steps.findIndex(s => s.id === job.job_type)
      
      if (stepIndex !== -1) {
        updatedWorkflow.steps[stepIndex] = {
          ...updatedWorkflow.steps[stepIndex],
          status: job.status === 'completed' ? 'completed' : 
                 job.status === 'failed' ? 'failed' : 'processing',
          progress_percentage: job.progress_percentage
        }
        
        setWorkflow(updatedWorkflow)
      }
    }
  }

  const startWorkflow = async () => {
    if (!workflow) return

    setLoading(true)
    setError(null)

    try {
      // Start the first step(s) that have no dependencies
      const initialSteps = workflow.steps.filter(step => (step.dependencies || []).length === 0)
      
      for (const step of initialSteps) {
        await startStep(step.id)
      }

      setWorkflow(prev => prev ? { ...prev, status: 'processing', started_at: new Date().toISOString() } : null)
      
    } catch (err) {
      console.error('Failed to start workflow:', err)
      setError('Failed to start processing workflow')
      if (onError) onError('Failed to start processing workflow')
    } finally {
      setLoading(false)
    }
  }

  const startStep = async (stepId: string) => {
    const stepConfig = {
      transcription: {
        endpoint: '/api/process-lesson-audio',
        data: { lesson_id: lessonId }
      },
      summarization: {
        endpoint: '/api/generate-summary',
        data: { lesson_id: lessonId }
      },
      content_analysis: {
        endpoint: '/api/analyze-content',
        data: { lesson_id: lessonId }
      },
      flashcard_generation: {
        endpoint: '/api/generate-flashcards',
        data: { lesson_id: lessonId }
      }
    }

    const config = stepConfig[stepId as keyof typeof stepConfig]
    if (!config) return

    try {
      const response = await fetch(config.endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${(await supabase.auth.getSession()).data.session?.access_token}`
        },
        body: JSON.stringify(config.data)
      })

      if (!response.ok) {
        throw new Error(`Failed to start ${stepId}`)
      }

      const result = await response.json()
      console.log(`Started ${stepId}:`, result)
      
    } catch (error) {
      console.error(`Failed to start ${stepId}:`, error)
      throw error
    }
  }

  const retryStep = async (stepId: string) => {
    if (!workflow) return

    const step = workflow.steps.find(s => s.id === stepId)
    if (!step || !step.can_retry) return

    setLoading(true)
    try {
      await startStep(stepId)
      
      // Update step status
      setWorkflow(prev => {
        if (!prev) return null
        const updated = { ...prev }
        const stepIndex = updated.steps.findIndex(s => s.id === stepId)
        if (stepIndex !== -1) {
          updated.steps[stepIndex] = {
            ...updated.steps[stepIndex],
            status: 'processing',
            progress_percentage: 0
          }
        }
        return updated
      })
      
    } catch (error) {
      setError(`Failed to retry ${stepId}`)
    } finally {
      setLoading(false)
    }
  }

  const skipStep = async (stepId: string) => {
    if (!workflow) return

    const step = workflow.steps.find(s => s.id === stepId)
    if (!step || !step.can_skip) return

    setWorkflow(prev => {
      if (!prev) return null
      const updated = { ...prev }
      const stepIndex = updated.steps.findIndex(s => s.id === stepId)
      if (stepIndex !== -1) {
        updated.steps[stepIndex] = {
          ...updated.steps[stepIndex],
          status: 'completed', // Mark as completed to allow dependent steps
          progress_percentage: 100
        }
      }
      return updated
    })

    // Check if dependent steps can now be started
    checkAndStartDependentSteps(stepId)
  }

  const checkAndStartDependentSteps = async (completedStepId: string) => {
    if (!workflow) return

    const dependentSteps = workflow.steps.filter(step => 
      (step.dependencies || []).includes(completedStepId) &&
      step.status === 'pending'
    )

    for (const step of dependentSteps) {
      // Check if all dependencies are completed
      const allDependenciesCompleted = (step.dependencies || []).every(depId => {
        const depStep = workflow.steps.find(s => s.id === depId)
        return depStep?.status === 'completed'
      })

      if (allDependenciesCompleted) {
        await startStep(step.id)
      }
    }
  }

  const getStepIcon = (status: string) => {
    switch (status) {
      case 'completed':
        return <CheckCircle2 className="w-5 h-5 text-green-500" />
      case 'failed':
        return <XCircle className="w-5 h-5 text-red-500" />
      case 'processing':
        return <div className="w-5 h-5 border-2 border-blue-500 border-t-transparent rounded-full animate-spin" />
      case 'skipped':
        return <ArrowRight className="w-5 h-5 text-yellow-500" />
      default:
        return <Clock className="w-5 h-5 text-gray-400" />
    }
  }

  const getStepColor = (status: string) => {
    switch (status) {
      case 'completed':
        return 'border-green-200 bg-green-50'
      case 'failed':
        return 'border-red-200 bg-red-50'
      case 'processing':
        return 'border-blue-200 bg-blue-50'
      case 'skipped':
        return 'border-yellow-200 bg-yellow-50'
      default:
        return 'border-gray-200 bg-gray-50'
    }
  }

  const canStartWorkflow = workflow?.status === 'pending'
  const isWorkflowActive = workflow?.status === 'processing'
  const isWorkflowCompleted = workflow?.status === 'completed'

  if (!workflow) {
    return (
      <Card className="p-6">
        <div className="text-center">
          <Settings className="w-12 h-12 mx-auto mb-4 text-gray-400" />
          <p className="text-gray-600">Initializing workflow...</p>
        </div>
      </Card>
    )
  }

  return (
    <div className="space-y-6">
      {/* Workflow Header */}
      <Card className="p-6">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-xl font-semibold text-gray-900">
              Processing Workflow
            </h3>
            <p className="text-gray-600">
              {workflowType.replace('_', ' ').charAt(0).toUpperCase() + workflowType.replace('_', ' ').slice(1)}
            </p>
          </div>
          
          <div className="flex items-center space-x-3">
            {canStartWorkflow && (
              <Button
                variant="primary"
                onClick={startWorkflow}
                disabled={loading}
              >
                <Play className="w-4 h-4 mr-1" />
                Start Processing
              </Button>
            )}
            
            {error && (
              <div className="flex items-center space-x-2 text-red-600">
                <AlertCircle className="w-4 h-4" />
                <span className="text-sm">{error}</span>
              </div>
            )}
          </div>
        </div>
      </Card>

      {/* Workflow Steps */}
      <div className="space-y-4">
        {workflow.steps.map((step, index) => (
          <Card key={step.id} className={`p-4 border-l-4 ${getStepColor(step.status)}`}>
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-4">
                {getStepIcon(step.status)}
                <div>
                  <h4 className="font-medium text-gray-900">{step.name}</h4>
                  <div className="flex items-center space-x-4 mt-1">
                    <span className="text-sm text-gray-600 capitalize">
                      {step.status}
                    </span>
                    {step.status === 'processing' && (
                      <div className="flex items-center space-x-2">
                        <div className="w-24 bg-gray-200 rounded-full h-2">
                          <div 
                            className="bg-blue-500 h-2 rounded-full transition-all duration-300"
                            style={{ width: `${step.progress_percentage}%` }}
                          />
                        </div>
                        <span className="text-sm text-gray-600">
                          {step.progress_percentage}%
                        </span>
                      </div>
                    )}
                  </div>
                </div>
              </div>

              <div className="flex items-center space-x-2">
                {step.status === 'failed' && step.can_retry && (
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => retryStep(step.id)}
                    disabled={loading}
                  >
                    <RotateCcw className="w-4 h-4 mr-1" />
                    Retry
                  </Button>
                )}
                
                {step.status === 'pending' && step.can_skip && (
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => skipStep(step.id)}
                  >
                    Skip
                  </Button>
                )}

                {step.status === 'completed' && (
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => console.log('View results for', step.id)}
                  >
                    <Eye className="w-4 h-4" />
                  </Button>
                )}
              </div>
            </div>

            {/* Dependencies */}
            {(step.dependencies || []).length > 0 && (
              <div className="mt-3 pl-9">
                <div className="text-xs text-gray-500">
                  Depends on: {(step.dependencies || []).join(', ')}
                </div>
              </div>
            )}
          </Card>
        ))}
      </div>

      {/* Workflow Summary */}
      <Card className="p-6">
        <div className="grid grid-cols-1 sm:grid-cols-4 gap-4">
          <div className="text-center">
            <div className="text-2xl font-bold text-blue-600">
              {workflow.steps.filter(s => s.status === 'completed').length}
            </div>
            <div className="text-sm text-gray-600">Completed</div>
          </div>
          
          <div className="text-center">
            <div className="text-2xl font-bold text-orange-600">
              {workflow.steps.filter(s => s.status === 'processing').length}
            </div>
            <div className="text-sm text-gray-600">Processing</div>
          </div>
          
          <div className="text-center">
            <div className="text-2xl font-bold text-red-600">
              {workflow.steps.filter(s => s.status === 'failed').length}
            </div>
            <div className="text-sm text-gray-600">Failed</div>
          </div>
          
          <div className="text-center">
            <div className="text-2xl font-bold text-green-600">
              ${(workflow.total_cost_cents / 100).toFixed(3)}
            </div>
            <div className="text-sm text-gray-600">Total Cost</div>
          </div>
        </div>
      </Card>
    </div>
  )
}