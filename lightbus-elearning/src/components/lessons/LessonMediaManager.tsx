'use client'

import React, { useState, useRef, useEffect } from 'react'
import { supabase } from '@/lib/supabase'
import Button from '@/components/ui/Button'
import Card from '@/components/ui/Card'
import ConfirmationModal from '@/components/ui/ConfirmationModal'

interface LessonMediaManagerProps {
  lessonId: string
  onMediaChange?: () => void
  className?: string
  showTitle?: boolean
}

interface LessonMediaFile {
  media_id: string
  file_path: string
  file_name: string
  file_size: number
  mime_type: string
  upload_order: number
  processing_status: 'pending' | 'processing' | 'completed' | 'failed'
  created_at: string
}

interface UploadProgress {
  fileName: string
  progress: number
  status: 'uploading' | 'completed' | 'error'
  error?: string
  filePath?: string
}

interface SystemSettings {
  max_audio_files_per_lesson: number
  max_audio_file_size_mb: number
  supported_audio_formats: string[]
}

const DEFAULT_SETTINGS: SystemSettings = {
  max_audio_files_per_lesson: 5,
  max_audio_file_size_mb: 100,
  supported_audio_formats: [
    'audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/wave', 'audio/x-wav',
    'audio/m4a', 'audio/mp4', 'audio/aac', 'audio/ogg', 'audio/vorbis'
  ]
}

export default function LessonMediaManager({ 
  lessonId, 
  onMediaChange, 
  className = '',
  showTitle = true
}: LessonMediaManagerProps) {
  const [mediaFiles, setMediaFiles] = useState<LessonMediaFile[]>([])
  const [uploads, setUploads] = useState<UploadProgress[]>([])
  const [isDragging, setIsDragging] = useState(false)
  const [isLoading, setIsLoading] = useState(true)
  const [settings, setSettings] = useState<SystemSettings>(DEFAULT_SETTINGS)
  const [deleteModal, setDeleteModal] = useState<{ isOpen: boolean; mediaId?: string; fileName?: string }>({ isOpen: false })
  const fileInputRef = useRef<HTMLInputElement>(null)

  // Load system settings and existing media files
  useEffect(() => {
    loadSystemSettings()
    loadMediaFiles()
  }, [lessonId])

  const loadSystemSettings = async () => {
    try {
      const { data, error } = await supabase
        .from('system_settings')
        .select('setting_key, setting_value, setting_type')
        .in('setting_key', ['max_audio_files_per_lesson', 'max_audio_file_size_mb', 'supported_audio_formats'])

      if (error) {
        console.error('Error loading system settings:', error)
        return
      }

      const newSettings = { ...DEFAULT_SETTINGS }
      data?.forEach(setting => {
        if (setting.setting_key === 'max_audio_files_per_lesson') {
          newSettings.max_audio_files_per_lesson = parseInt(setting.setting_value)
        } else if (setting.setting_key === 'max_audio_file_size_mb') {
          newSettings.max_audio_file_size_mb = parseInt(setting.setting_value)
        } else if (setting.setting_key === 'supported_audio_formats') {
          newSettings.supported_audio_formats = JSON.parse(setting.setting_value)
        }
      })
      setSettings(newSettings)
    } catch (error) {
      console.error('Error parsing system settings:', error)
    }
  }

  const loadMediaFiles = async () => {
    setIsLoading(true)
    try {
      const { data, error } = await supabase.rpc('get_lesson_audio_files', {
        p_lesson_id: lessonId
      })

      if (error) {
        console.error('Error loading media files:', error)
        return
      }

      setMediaFiles(data || [])
    } catch (error) {
      console.error('Error loading media files:', error)
    } finally {
      setIsLoading(false)
    }
  }

  const validateFile = (file: File): string | null => {
    // Check file size
    const maxSizeBytes = settings.max_audio_file_size_mb * 1024 * 1024
    if (file.size > maxSizeBytes) {
      return `File size must be less than ${settings.max_audio_file_size_mb}MB`
    }

    // Check file type
    if (!settings.supported_audio_formats.includes(file.type)) {
      return 'Please select a supported audio file format'
    }

    // Check if we can add more files
    if (mediaFiles.length >= settings.max_audio_files_per_lesson) {
      return `Maximum ${settings.max_audio_files_per_lesson} audio files allowed per lesson`
    }

    return null
  }

  const generateStoragePath = (fileName: string): string => {
    const timestamp = Date.now()
    const sanitizedName = fileName.replace(/[^a-zA-Z0-9.-]/g, '_')
    return `lessons/${lessonId}/media/${timestamp}_${sanitizedName}`
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

    const storagePath = generateStoragePath(file.name)

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

      // Add to lesson media using the new function
      const { data: mediaResult, error: mediaError } = await supabase.rpc('add_lesson_audio', {
        p_lesson_id: lessonId,
        p_file_path: data.path,
        p_file_name: file.name,
        p_file_size: file.size,
        p_mime_type: file.type
      })

      if (mediaError) {
        throw new Error(mediaError.message)
      }

      // Reload media files to show the new upload
      await loadMediaFiles()
      
      if (onMediaChange) {
        onMediaChange()
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

  const handleDeleteFile = async (mediaId: string) => {
    try {
      const { data, error } = await supabase.rpc('remove_lesson_audio', {
        p_media_id: mediaId
      })

      if (error) {
        throw new Error(error.message)
      }

      // Reload media files
      await loadMediaFiles()
      
      if (onMediaChange) {
        onMediaChange()
      }

      setDeleteModal({ isOpen: false })
    } catch (error: any) {
      console.error('Delete error:', error)
      alert('Failed to delete audio file: ' + error.message)
    }
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

  const getProcessingStatusDisplay = (status: string) => {
    switch (status) {
      case 'pending': return { text: 'Pending', icon: '⏳', color: 'text-yellow-600' }
      case 'processing': return { text: 'Processing', icon: '⚙️', color: 'text-blue-600' }
      case 'completed': return { text: 'Completed', icon: '✅', color: 'text-green-600' }
      case 'failed': return { text: 'Failed', icon: '❌', color: 'text-red-600' }
      default: return { text: status, icon: '❓', color: 'text-gray-600' }
    }
  }

  const canAddMoreFiles = mediaFiles.length < settings.max_audio_files_per_lesson

  if (isLoading) {
    return (
      <Card variant="default" padding="lg" className={className}>
        <div className="flex items-center justify-center p-8">
          <div className="text-lg">Loading media files...</div>
        </div>
      </Card>
    )
  }

  return (
    <>
      <Card variant="default" padding="lg" className={className}>
        {showTitle && (
          <div className="mb-6">
            <h2 className="heading-2 mb-2">🎧 Lesson Audio Files</h2>
            <p className="text-neutral-gray">
              Manage audio files for this lesson. Audio will be automatically processed to generate flashcards.
            </p>
          </div>
        )}

        {/* Existing Media Files */}
        {mediaFiles.length > 0 && (
          <div className="mb-6">
            <h3 className="heading-4 mb-3">Current Audio Files ({mediaFiles.length}/{settings.max_audio_files_per_lesson})</h3>
            <div className="space-y-3">
              {mediaFiles.map((media) => {
                const statusDisplay = getProcessingStatusDisplay(media.processing_status)
                return (
                  <div
                    key={media.media_id}
                    className="p-4 border border-neutral-gray border-opacity-20 rounded-lg"
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center space-x-3">
                        <span className="text-2xl">{getFileIcon(media.file_name)}</span>
                        <div>
                          <div className="font-medium text-sm">{media.file_name}</div>
                          <div className="text-xs text-neutral-gray">
                            {formatFileSize(media.file_size)} • Uploaded {new Date(media.created_at).toLocaleDateString()}
                          </div>
                          <div className={`text-xs ${statusDisplay.color} flex items-center gap-1`}>
                            <span>{statusDisplay.icon}</span>
                            <span>{statusDisplay.text}</span>
                          </div>
                        </div>
                      </div>
                      
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => setDeleteModal({ 
                          isOpen: true, 
                          mediaId: media.media_id, 
                          fileName: media.file_name 
                        })}
                        className="text-red-600 hover:text-red-800"
                      >
                        🗑️ Delete
                      </Button>
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        )}

        {/* Upload Area */}
        {canAddMoreFiles && (
          <div>
            <h3 className="heading-4 mb-3">Add New Audio File</h3>
            <div
              className={`
                border-2 border-dashed p-8 text-center transition-colors cursor-pointer rounded-lg
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
              
              <h4 className="heading-4 mb-2">
                {isDragging ? 'Drop audio file here' : 'Upload Audio File'}
              </h4>
              
              <p className="text-neutral-gray mb-4">
                Drag and drop an audio file here, or click to browse
              </p>
              
              <div className="text-sm text-neutral-gray mb-4">
                <div className="mb-2">
                  <strong>Supported formats:</strong>
                </div>
                <div className="flex flex-wrap justify-center gap-2">
                  <span className="px-2 py-1 bg-learning-100 text-learning-600 text-xs">MP3</span>
                  <span className="px-2 py-1 bg-learning-100 text-learning-600 text-xs">WAV</span>
                  <span className="px-2 py-1 bg-learning-100 text-learning-600 text-xs">M4A</span>
                  <span className="px-2 py-1 bg-learning-100 text-learning-600 text-xs">AAC</span>
                  <span className="px-2 py-1 bg-learning-100 text-learning-600 text-xs">OGG</span>
                </div>
                <div className="mt-2">
                  Max file size: {settings.max_audio_file_size_mb}MB • 
                  {settings.max_audio_files_per_lesson - mediaFiles.length} files remaining
                </div>
              </div>

              <Button variant="primary" type="button">
                Choose Audio File
              </Button>
            </div>

            <input
              ref={fileInputRef}
              type="file"
              accept={settings.supported_audio_formats.join(',')}
              onChange={(e) => handleFileSelect(e.target.files)}
              className="hidden"
            />
          </div>
        )}

        {!canAddMoreFiles && (
          <div className="text-center p-6 bg-yellow-50 border border-yellow-200 rounded-lg">
            <div className="text-yellow-800">
              Maximum number of audio files ({settings.max_audio_files_per_lesson}) reached for this lesson.
              Delete an existing file to add a new one.
            </div>
          </div>
        )}

        {/* Upload Progress */}
        {uploads.length > 0 && (
          <div className="mt-6 space-y-3">
            <h3 className="heading-4">Upload Progress</h3>
            {uploads.map((upload, index) => (
              <div
                key={`${upload.fileName}_${index}`}
                className="p-4 border border-neutral-gray border-opacity-20 rounded-lg"
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
                  <div className="w-full bg-neutral-gray bg-opacity-20 h-2 rounded">
                    <div 
                      className="bg-learning-500 h-2 transition-all duration-300 rounded"
                      style={{ width: `${upload.progress}%` }}
                    ></div>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}

        {/* Info Section */}
        <div className="mt-6 p-4 bg-learning-50 border border-learning-200 rounded-lg">
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
      </Card>

      {/* Delete Confirmation Modal */}
      <ConfirmationModal
        isOpen={deleteModal.isOpen}
        onClose={() => setDeleteModal({ isOpen: false })}
        onConfirm={() => deleteModal.mediaId && handleDeleteFile(deleteModal.mediaId)}
        title="Delete Audio File"
        message={`Are you sure you want to delete "${deleteModal.fileName}"? This action cannot be undone and will also remove any generated content from this audio file.`}
        confirmText="Delete"
        variant="danger"
      />
    </>
  )
}