'use client'

import React, { useState, useRef } from 'react'
import { supabase } from '@/lib/supabase'
import Button from '@/components/ui/Button'
import Card from '@/components/ui/Card'

interface MediaUploadProps {
  lessonId?: string
  onSuccess?: (filePath: string) => void
  onCancel?: () => void
  className?: string
}

interface UploadProgress {
  fileName: string
  progress: number
  status: 'uploading' | 'completed' | 'error'
  error?: string
  filePath?: string
}

const ACCEPTED_TYPES = {
  audio: [
    'audio/mpeg',      // Standard MIME type for MP3
    'audio/mp3',       // Non-standard but some systems use it
    'audio/wav',
    'audio/wave',      // Alternative MIME type for WAV
    'audio/x-wav',     // Alternative MIME type for WAV
    'audio/m4a',
    'audio/mp4',       // Some M4A files use this
    'audio/aac',
    'audio/ogg',
    'audio/vorbis'     // Alternative for OGG
  ],
  video: [
    'video/mp4',
    'video/quicktime', // Standard MIME type for MOV
    'video/mov',       // Non-standard but some systems use it
    'video/avi',
    'video/x-msvideo', // Standard MIME type for AVI
    'video/mkv',
    'video/x-matroska', // Standard MIME type for MKV
    'video/webm'
  ]
}

const MAX_FILE_SIZE = 100 * 1024 * 1024 // 100MB

export default function MediaUpload({ 
  lessonId, 
  onSuccess, 
  onCancel, 
  className = '' 
}: MediaUploadProps) {
  const [uploads, setUploads] = useState<UploadProgress[]>([])
  const [isDragging, setIsDragging] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const validateFile = (file: File): string | null => {
    // Check file size
    if (file.size > MAX_FILE_SIZE) {
      return `File size must be less than ${MAX_FILE_SIZE / (1024 * 1024)}MB`
    }

    // Check file type
    const allAcceptedTypes = [...ACCEPTED_TYPES.audio, ...ACCEPTED_TYPES.video]
    if (!allAcceptedTypes.includes(file.type)) {
      return 'Please select an audio or video file'
    }

    return null
  }

  const generateStoragePath = (fileName: string, lessonId?: string): string => {
    const timestamp = Date.now()
    const sanitizedName = fileName.replace(/[^a-zA-Z0-9.-]/g, '_')
    
    if (lessonId) {
      return `lessons/${lessonId}/media/${timestamp}_${sanitizedName}`
    } else {
      return `uploads/media/${timestamp}_${sanitizedName}`
    }
  }

  const uploadFile = async (file: File): Promise<void> => {
    const validationError = validateFile(file)
    if (validationError) {
      setUploads(prev => [...prev, {
        fileName: file.name,
        progress: 0,
        status: 'error',
        error: validationError
      }])
      return
    }

    const uploadId = `${file.name}_${Date.now()}`
    const storagePath = generateStoragePath(file.name, lessonId)

    // Initialize upload progress
    setUploads(prev => [...prev, {
      fileName: file.name,
      progress: 0,
      status: 'uploading'
    }])

    try {
      // Upload to Supabase Storage
      const { data, error } = await supabase.storage
        .from('media')
        .upload(storagePath, file, {
          cacheControl: '3600',
          upsert: false
        })

      if (error) throw error

      // Update progress to completed
      setUploads(prev => prev.map(upload => 
        upload.fileName === file.name && upload.status === 'uploading'
          ? { ...upload, progress: 100, status: 'completed', filePath: data.path }
          : upload
      ))

      // Update lesson with media path if lessonId provided
      if (lessonId) {
        const { error: updateError } = await supabase.rpc('update_lesson', {
          p_lesson_id: lessonId,
          p_recording_path: data.path
        })

        if (updateError) {
          console.error('Error updating lesson:', updateError)
        } else {
          // Also update has_audio flag
          await supabase
            .from('lessons')
            .update({ has_audio: true })
            .eq('id', lessonId)
        }
      }

      if (onSuccess) {
        onSuccess(data.path)
      }
    } catch (error: any) {
      console.error('Upload error:', error)
      setUploads(prev => prev.map(upload => 
        upload.fileName === file.name && upload.status === 'uploading'
          ? { ...upload, status: 'error', error: error.message || 'Upload failed' }
          : upload
      ))
    }
  }

  const handleFileSelect = (files: FileList | null) => {
    if (!files) return

    Array.from(files).forEach(file => {
      uploadFile(file)
    })
  }

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault()
    setIsDragging(true)
  }

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault()
    setIsDragging(false)
  }

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault()
    setIsDragging(false)
    handleFileSelect(e.dataTransfer.files)
  }

  const getFileIcon = (fileName: string) => {
    const extension = fileName.split('.').pop()?.toLowerCase()
    
    if (['mp3', 'wav', 'm4a', 'aac', 'ogg'].includes(extension || '')) {
      return '🎵'
    } else if (['mp4', 'mov', 'avi', 'mkv', 'webm'].includes(extension || '')) {
      return '🎬'
    }
    return '📁'
  }

  const formatFileSize = (bytes: number): string => {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  return (
    <Card variant="default" padding="lg" className={className}>
      <div className="mb-6">
        <h2 className="heading-2 mb-2">🎧 Upload Media Content</h2>
        <p className="text-neutral-gray">
          Upload audio or video files to generate flashcards automatically.
        </p>
      </div>

      {/* Upload Area */}
      <div
        className={`
          border-2 border-dashed p-8 text-center transition-colors cursor-pointer
          ${isDragging 
            ? 'border-learning-500 bg-learning-50' 
            : 'border-neutral-gray hover:border-learning-400 hover:bg-learning-25'
          }
        `}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
        onClick={() => fileInputRef.current?.click()}
      >
        <div className="text-6xl mb-4">
          {isDragging ? '📥' : '🎧'}
        </div>
        
        <h3 className="heading-4 mb-2">
          {isDragging ? 'Drop files here' : 'Upload Media Files'}
        </h3>
        
        <p className="text-neutral-gray mb-4">
          Drag and drop your audio or video files here, or click to browse
        </p>
        
        <div className="text-sm text-neutral-gray mb-4">
          <div className="mb-2">
            <strong>Supported formats:</strong>
          </div>
          <div className="flex flex-wrap justify-center gap-2">
            <span className="px-2 py-1 bg-learning-100 text-learning-600 text-xs">MP3</span>
            <span className="px-2 py-1 bg-learning-100 text-learning-600 text-xs">WAV</span>
            <span className="px-2 py-1 bg-learning-100 text-learning-600 text-xs">M4A</span>
            <span className="px-2 py-1 bg-learning-100 text-learning-600 text-xs">MP4</span>
            <span className="px-2 py-1 bg-learning-100 text-learning-600 text-xs">MOV</span>
            <span className="px-2 py-1 bg-learning-100 text-learning-600 text-xs">AVI</span>
          </div>
          <div className="mt-2">
            Max file size: {MAX_FILE_SIZE / (1024 * 1024)}MB
          </div>
        </div>

        <Button variant="primary" type="button">
          Choose Files
        </Button>
      </div>

      <input
        ref={fileInputRef}
        type="file"
        accept={[...ACCEPTED_TYPES.audio, ...ACCEPTED_TYPES.video].join(',')}
        multiple
        onChange={(e) => handleFileSelect(e.target.files)}
        className="hidden"
      />

      {/* Upload Progress */}
      {uploads.length > 0 && (
        <div className="mt-6 space-y-3">
          <h3 className="heading-4">Upload Progress</h3>
          {uploads.map((upload, index) => (
            <div
              key={`${upload.fileName}_${index}`}
              className="p-4 border border-neutral-gray border-opacity-20"
            >
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center space-x-3">
                  <span className="text-2xl">{getFileIcon(upload.fileName)}</span>
                  <div>
                    <div className="font-medium text-sm">{upload.fileName}</div>
                    <div className="text-xs text-neutral-gray">
                      {upload.status === 'uploading' && `${upload.progress}% uploaded`}
                      {upload.status === 'completed' && 'Upload completed'}
                      {upload.status === 'error' && `Error: ${upload.error}`}
                    </div>
                  </div>
                </div>
                
                <div className="text-right">
                  {upload.status === 'uploading' && (
                    <div className="w-4 h-4 border-2 border-learning-500 border-t-transparent rounded-full animate-spin"></div>
                  )}
                  {upload.status === 'completed' && (
                    <div className="text-achievement-500 text-lg">✅</div>
                  )}
                  {upload.status === 'error' && (
                    <div className="text-red-500 text-lg">❌</div>
                  )}
                </div>
              </div>
              
              {upload.status === 'uploading' && (
                <div className="w-full bg-neutral-gray bg-opacity-20 h-2">
                  <div 
                    className="bg-learning-500 h-2 transition-all duration-300"
                    style={{ width: `${upload.progress}%` }}
                  ></div>
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Info Section */}
      <div className="mt-6 p-4 bg-learning-50 border border-learning-200">
        <h4 className="font-semibold text-learning-600 mb-2 flex items-center">
          🤖 AI Processing
        </h4>
        <div className="space-y-2 text-sm text-neutral-gray">
          <div className="flex items-start space-x-2">
            <span className="text-learning-500 mt-0.5">•</span>
            <span>Audio files will be automatically transcribed using speech-to-text</span>
          </div>
          <div className="flex items-start space-x-2">
            <span className="text-learning-500 mt-0.5">•</span>
            <span>AI will generate flashcards from the transcribed content</span>
          </div>
          <div className="flex items-start space-x-2">
            <span className="text-learning-500 mt-0.5">•</span>
            <span>You can review and edit generated cards before publishing to students</span>
          </div>
        </div>
      </div>

      {/* Actions */}
      {onCancel && (
        <div className="flex items-center justify-between pt-6">
          <Button 
            type="button" 
            variant="ghost" 
            onClick={onCancel}
          >
            Cancel
          </Button>
          
          <div className="text-sm text-neutral-gray">
            {uploads.filter(u => u.status === 'completed').length > 0 && (
              <span>✅ {uploads.filter(u => u.status === 'completed').length} file(s) uploaded successfully</span>
            )}
          </div>
        </div>
      )}
    </Card>
  )
}