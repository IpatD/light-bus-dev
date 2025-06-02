'use client'

import React, { useState, useEffect } from 'react'
import { ProcessingJob, ProcessingStatusProps } from '@/types'
import { supabase } from '@/lib/supabase'
import Card from '@/components/ui/Card'
import Button from '@/components/ui/Button'
import { CheckCircle2, XCircle, Clock, AlertCircle, RotateCcw, Eye, EyeOff } from 'lucide-react'

export function ProcessingStatus({ 
  jobId, 
  onComplete, 
  onError, 
  showDetails = true 
}: ProcessingStatusProps) {
  const [job, setJob] = useState<ProcessingJob | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [showDetailedView, setShowDetailedView] = useState(false)
  const [retryCount, setRetryCount] = useState(0)

  useEffect(() => {
    fetchJobStatus()
    const interval = setInterval(() => {
      if (job?.status === 'processing' || job?.status === 'pending') {
        fetchJobStatus()
      }
    }, 2000) // Poll every 2 seconds for active jobs

    return () => clearInterval(interval)
  }, [jobId, job?.status])

  const fetchJobStatus = async () => {
    try {
      const { data, error } = await supabase
        .from('processing_jobs')
        .select('*')
        .eq('id', jobId)
        .single()

      if (error) {
        throw error
      }

      setJob(data)
      setLoading(false)

      // Handle completion
      if (data.status === 'completed' && onComplete) {
        onComplete(data.output_data)
      }

      // Handle error
      if (data.status === 'failed' && onError) {
        onError(data.error_message || 'Processing failed')
      }

    } catch (err) {
      console.error('Failed to fetch job status:', err)
      setError('Failed to fetch processing status')
      setLoading(false)
    }
  }

  const handleRetry = async () => {
    if (!job || retryCount >= 3) return

    try {
      setRetryCount(prev => prev + 1)
      
      // Reset job status to pending
      const { error } = await supabase
        .from('processing_jobs')
        .update({
          status: 'pending',
          progress_percentage: 0,
          error_message: null,
          processing_started_at: null,
          processing_completed_at: null,
          updated_at: new Date().toISOString()
        })
        .eq('id', jobId)

      if (error) {
        throw error
      }

      // Trigger job reprocessing based on job type
      await triggerJobReprocessing(job)
      
      fetchJobStatus()
    } catch (err) {
      console.error('Failed to retry job:', err)
      setError('Failed to retry processing')
    }
  }

  const triggerJobReprocessing = async (job: ProcessingJob) => {
    // This would typically trigger the appropriate Edge Function
    // For now, we'll just simulate the trigger
    console.log(`Retriggering ${job.job_type} for lesson ${job.lesson_id}`)
  }

  const getStatusIcon = () => {
    if (!job) return <Clock className="w-5 h-5 text-gray-400" />

    switch (job.status) {
      case 'completed':
        return <CheckCircle2 className="w-5 h-5 text-green-500" />
      case 'failed':
        return <XCircle className="w-5 h-5 text-red-500" />
      case 'processing':
        return (
          <div className="w-5 h-5 border-2 border-blue-500 border-t-transparent rounded-full animate-spin" />
        )
      case 'cancelled':
        return <AlertCircle className="w-5 h-5 text-yellow-500" />
      default:
        return <Clock className="w-5 h-5 text-gray-400" />
    }
  }

  const getStatusColor = () => {
    if (!job) return 'bg-gray-100'

    switch (job.status) {
      case 'completed':
        return 'bg-green-100 border-green-200'
      case 'failed':
        return 'bg-red-100 border-red-200'
      case 'processing':
        return 'bg-blue-100 border-blue-200'
      case 'cancelled':
        return 'bg-yellow-100 border-yellow-200'
      default:
        return 'bg-gray-100 border-gray-200'
    }
  }

  const getJobTypeDisplayName = (jobType: string) => {
    const types = {
      transcription: 'Audio Transcription',
      summarization: 'Content Summarization',
      flashcard_generation: 'Flashcard Generation',
      content_analysis: 'Content Analysis'
    }
    return types[jobType as keyof typeof types] || jobType
  }

  const formatTimeEstimate = (startTime?: string) => {
    if (!startTime) return null
    
    const start = new Date(startTime)
    const now = new Date()
    const elapsed = Math.floor((now.getTime() - start.getTime()) / 1000)
    
    if (elapsed < 60) return `${elapsed}s elapsed`
    if (elapsed < 3600) return `${Math.floor(elapsed / 60)}m ${elapsed % 60}s elapsed`
    return `${Math.floor(elapsed / 3600)}h ${Math.floor((elapsed % 3600) / 60)}m elapsed`
  }

  if (loading) {
    return (
      <Card className="p-4">
        <div className="flex items-center space-x-3">
          <div className="w-5 h-5 border-2 border-blue-500 border-t-transparent rounded-full animate-spin" />
          <span className="text-gray-600">Loading processing status...</span>
        </div>
      </Card>
    )
  }

  if (error) {
    return (
      <Card className="p-4 bg-red-50 border-red-200">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <XCircle className="w-5 h-5 text-red-500" />
            <span className="text-red-700">{error}</span>
          </div>
          <Button 
            variant="secondary" 
            size="sm" 
            onClick={fetchJobStatus}
          >
            <RotateCcw className="w-4 h-4 mr-1" />
            Retry
          </Button>
        </div>
      </Card>
    )
  }

  if (!job) {
    return (
      <Card className="p-4 bg-gray-50">
        <span className="text-gray-600">Processing job not found</span>
      </Card>
    )
  }

  return (
    <Card className={`p-4 border-2 ${getStatusColor()}`}>
      <div className="space-y-4">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            {getStatusIcon()}
            <div>
              <h3 className="font-semibold text-gray-900">
                {getJobTypeDisplayName(job.job_type)}
              </h3>
              <p className="text-sm text-gray-600 capitalize">
                Status: {job.status}
              </p>
            </div>
          </div>
          
          {showDetails && (
            <Button 
              variant="ghost" 
              size="sm"
              onClick={() => setShowDetailedView(!showDetailedView)}
            >
              {showDetailedView ? (
                <EyeOff className="w-4 h-4" />
              ) : (
                <Eye className="w-4 h-4" />
              )}
            </Button>
          )}
        </div>

        {/* Progress Bar */}
        {job.status === 'processing' && (
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span>Progress</span>
              <span>{job.progress_percentage}%</span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div 
                className="bg-blue-500 h-2 rounded-full transition-all duration-300"
                style={{ width: `${job.progress_percentage}%` }}
              />
            </div>
          </div>
        )}

        {/* Time Information */}
        {job.processing_started_at && (
          <div className="text-sm text-gray-600">
            {formatTimeEstimate(job.processing_started_at)}
          </div>
        )}

        {/* Error Message */}
        {job.status === 'failed' && job.error_message && (
          <div className="bg-red-50 border border-red-200 rounded-md p-3">
            <p className="text-sm text-red-700">
              <strong>Error:</strong> {job.error_message}
            </p>
            {retryCount < 3 && (
              <Button 
                variant="secondary" 
                size="sm" 
                onClick={handleRetry}
                className="mt-2"
              >
                <RotateCcw className="w-4 h-4 mr-1" />
                Retry ({3 - retryCount} attempts remaining)
              </Button>
            )}
          </div>
        )}

        {/* Success Output */}
        {job.status === 'completed' && job.output_data && (
          <div className="bg-green-50 border border-green-200 rounded-md p-3">
            <p className="text-sm text-green-700">
              <strong>Completed successfully!</strong>
            </p>
            {showDetailedView && (
              <div className="mt-2 text-xs text-gray-600">
                <pre className="whitespace-pre-wrap">
                  {JSON.stringify(job.output_data, null, 2)}
                </pre>
              </div>
            )}
          </div>
        )}

        {/* Detailed View */}
        {showDetailedView && showDetails && (
          <div className="border-t pt-4 space-y-3">
            <div className="grid grid-cols-2 gap-4 text-sm">
              <div>
                <span className="font-medium text-gray-700">Job ID:</span>
                <p className="text-gray-600 font-mono text-xs">{job.id}</p>
              </div>
              <div>
                <span className="font-medium text-gray-700">Service:</span>
                <p className="text-gray-600">{job.ai_service_provider || 'N/A'}</p>
              </div>
              <div>
                <span className="font-medium text-gray-700">Created:</span>
                <p className="text-gray-600">
                  {new Date(job.created_at).toLocaleString()}
                </p>
              </div>
              <div>
                <span className="font-medium text-gray-700">Cost:</span>
                <p className="text-gray-600">
                  ${(job.cost_cents / 100).toFixed(3)}
                </p>
              </div>
            </div>

            {job.input_data && (
              <div>
                <span className="font-medium text-gray-700">Input Data:</span>
                <pre className="mt-1 text-xs text-gray-600 bg-gray-100 p-2 rounded overflow-auto max-h-32">
                  {JSON.stringify(job.input_data, null, 2)}
                </pre>
              </div>
            )}
          </div>
        )}
      </div>
    </Card>
  )
}