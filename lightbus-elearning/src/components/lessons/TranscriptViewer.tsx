'use client'

import React, { useState, useRef, useEffect } from 'react'
import { Transcript, TranscriptViewerProps, Lesson } from '@/types'
import Card from '@/components/ui/Card'
import Button from '@/components/ui/Button'
import Input from '@/components/ui/Input'
import { 
  Search, 
  Download, 
  FileText, 
  Plus, 
  Clock, 
  Eye, 
  EyeOff,
  Volume2,
  VolumeX,
  Copy,
  CheckCircle2,
  Filter,
  Highlighter
} from 'lucide-react'

interface TimestampSegment {
  text: string
  start: number
  end: number
  confidence?: number
  speaker?: string
}

export function TranscriptViewer({ 
  transcript, 
  lesson, 
  onCreateCard, 
  onExport, 
  searchable = true 
}: TranscriptViewerProps) {
  const [searchQuery, setSearchQuery] = useState('')
  const [highlightedText, setHighlightedText] = useState('')
  const [selectedText, setSelectedText] = useState<{text: string, start?: number, end?: number} | null>(null)
  const [showTimestamps, setShowTimestamps] = useState(true)
  const [showConfidence, setShowConfidence] = useState(false)
  const [speakerFilter, setSpeakerFilter] = useState<string>('all')
  const [currentPlayTime, setCurrentPlayTime] = useState<number>(0)
  const [copied, setCopied] = useState(false)
  const transcriptRef = useRef<HTMLDivElement>(null)

  // Parse transcript content into segments (if it's structured)
  const segments: TimestampSegment[] = React.useMemo(() => {
    try {
      // Try to parse as structured JSON first
      const parsed = JSON.parse(transcript.content)
      if (Array.isArray(parsed)) {
        return parsed
      }
    } catch {
      // If not JSON, treat as plain text and create simple segments
      const sentences = transcript.content.split(/[.!?]+/).filter(s => s.trim())
      return sentences.map((sentence, index) => ({
        text: sentence.trim(),
        start: index * 5, // Estimate 5 seconds per sentence
        end: (index + 1) * 5,
        confidence: transcript.confidence_score
      }))
    }
    return []
  }, [transcript.content, transcript.confidence_score])

  // Get unique speakers for filter
  const speakers = React.useMemo(() => {
    const speakerSet = new Set(segments.map(s => s.speaker).filter(Boolean))
    return Array.from(speakerSet) as string[]
  }, [segments])

  // Filter segments based on search and speaker
  const filteredSegments = React.useMemo(() => {
    let filtered = segments

    if (speakerFilter !== 'all') {
      filtered = filtered.filter(segment => segment.speaker === speakerFilter)
    }

    if (searchQuery.trim()) {
      const query = searchQuery.toLowerCase()
      filtered = filtered.filter(segment => 
        segment.text.toLowerCase().includes(query)
      )
    }

    return filtered
  }, [segments, searchQuery, speakerFilter])

  const handleTextSelection = () => {
    const selection = window.getSelection()
    if (selection && selection.toString().trim()) {
      const selectedContent = selection.toString().trim()
      setSelectedText({ text: selectedContent })
      setHighlightedText(selectedContent)
    }
  }

  const handleCreateCard = () => {
    if (selectedText && onCreateCard) {
      onCreateCard(selectedText)
      setSelectedText(null)
      setHighlightedText('')
      window.getSelection()?.removeAllRanges()
    }
  }

  const handleCopyTranscript = async () => {
    try {
      const textToCopy = filteredSegments.map(segment => 
        showTimestamps 
          ? `[${formatTime(segment.start)}] ${segment.text}`
          : segment.text
      ).join('\n')
      
      await navigator.clipboard.writeText(textToCopy)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch (error) {
      console.error('Failed to copy transcript:', error)
    }
  }

  const handleExport = (format: 'pdf' | 'txt') => {
    if (onExport) {
      onExport(format)
    } else {
      // Default export behavior
      const content = filteredSegments.map(segment => 
        showTimestamps 
          ? `[${formatTime(segment.start)}] ${segment.text}`
          : segment.text
      ).join('\n')
      
      const blob = new Blob([content], { type: 'text/plain' })
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `${lesson.name}_transcript.${format}`
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
      URL.revokeObjectURL(url)
    }
  }

  const formatTime = (seconds: number): string => {
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
  }

  const highlightSearchQuery = (text: string): string => {
    if (!searchQuery.trim()) return text
    
    const regex = new RegExp(`(${searchQuery})`, 'gi')
    return text.replace(regex, '<mark class="bg-yellow-200 px-1 rounded">$1</mark>')
  }

  const getConfidenceColor = (confidence?: number): string => {
    if (!confidence) return ''
    if (confidence >= 0.8) return 'border-l-green-500'
    if (confidence >= 0.6) return 'border-l-yellow-500'
    return 'border-l-red-500'
  }

  const getSpeakerColor = (speaker?: string): string => {
    if (!speaker) return 'text-gray-700'
    
    const colors = [
      'text-blue-700',
      'text-green-700', 
      'text-purple-700',
      'text-orange-700',
      'text-pink-700'
    ]
    
    const index = speakers.indexOf(speaker) % colors.length
    return colors[index]
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Lesson Transcript</h2>
          <p className="text-gray-600">
            {lesson.name} • {transcript.transcript_type} transcript
            {transcript.confidence_score && (
              <span className="ml-2 text-sm">
                ({(transcript.confidence_score * 100).toFixed(0)}% confidence)
              </span>
            )}
          </p>
        </div>

        <div className="flex items-center space-x-2">
          <Button
            variant="ghost"
            size="sm"
            onClick={handleCopyTranscript}
          >
            {copied ? (
              <CheckCircle2 className="w-4 h-4 mr-1 text-green-500" />
            ) : (
              <Copy className="w-4 h-4 mr-1" />
            )}
            {copied ? 'Copied!' : 'Copy'}
          </Button>
          
          <Button
            variant="secondary"
            size="sm"
            onClick={() => handleExport('txt')}
          >
            <Download className="w-4 h-4 mr-1" />
            Export TXT
          </Button>
          
          <Button
            variant="secondary"
            size="sm"
            onClick={() => handleExport('pdf')}
          >
            <FileText className="w-4 h-4 mr-1" />
            Export PDF
          </Button>
        </div>
      </div>

      {/* Controls */}
      <Card className="p-4">
        <div className="flex flex-col sm:flex-row gap-4">
          {/* Search */}
          {searchable && (
            <div className="flex-1">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                <Input
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder="Search transcript..."
                  className="pl-10"
                />
              </div>
            </div>
          )}

          {/* Filters */}
          <div className="flex items-center space-x-3">
            {speakers.length > 0 && (
              <select
                value={speakerFilter}
                onChange={(e) => setSpeakerFilter(e.target.value)}
                className="border border-gray-300 rounded-md px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <option value="all">All Speakers</option>
                {speakers.map(speaker => (
                  <option key={speaker} value={speaker}>{speaker}</option>
                ))}
              </select>
            )}

            {/* View Options */}
            <div className="flex items-center space-x-2">
              <Button
                variant={showTimestamps ? "primary" : "ghost"}
                size="sm"
                onClick={() => setShowTimestamps(!showTimestamps)}
              >
                <Clock className="w-4 h-4 mr-1" />
                Times
              </Button>
              
              <Button
                variant={showConfidence ? "primary" : "ghost"}
                size="sm"
                onClick={() => setShowConfidence(!showConfidence)}
              >
                <Filter className="w-4 h-4 mr-1" />
                Confidence
              </Button>
            </div>
          </div>
        </div>
      </Card>

      {/* Selection Actions */}
      {selectedText && (
        <Card className="p-4 bg-blue-50 border-blue-200">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="font-medium text-blue-900">Text Selected</h3>
              <p className="text-blue-700 text-sm mt-1">
                "{selectedText.text.substring(0, 100)}..."
              </p>
            </div>
            {onCreateCard && (
              <Button
                variant="primary"
                size="sm"
                onClick={handleCreateCard}
              >
                <Plus className="w-4 h-4 mr-1" />
                Create Flashcard
              </Button>
            )}
          </div>
        </Card>
      )}

      {/* Transcript Content */}
      <Card className="p-6">
        <div 
          ref={transcriptRef}
          className="space-y-4 max-h-96 overflow-y-auto"
          onMouseUp={handleTextSelection}
        >
          {filteredSegments.length === 0 ? (
            <div className="text-center py-8 text-gray-500">
              <Search className="w-12 h-12 mx-auto mb-4 opacity-50" />
              <p>No transcript segments found matching your criteria.</p>
            </div>
          ) : (
            filteredSegments.map((segment, index) => (
              <div 
                key={index}
                className={`border-l-4 pl-4 py-2 ${getConfidenceColor(segment.confidence)} hover:bg-gray-50 transition-colors`}
              >
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    {/* Timestamp and Speaker */}
                    <div className="flex items-center space-x-3 mb-2">
                      {showTimestamps && (
                        <span className="text-sm font-mono text-gray-500 bg-gray-100 px-2 py-1 rounded">
                          {formatTime(segment.start)}
                        </span>
                      )}
                      {segment.speaker && (
                        <span className={`text-sm font-medium ${getSpeakerColor(segment.speaker)}`}>
                          {segment.speaker}
                        </span>
                      )}
                      {showConfidence && segment.confidence && (
                        <span className="text-xs text-gray-500">
                          {(segment.confidence * 100).toFixed(0)}%
                        </span>
                      )}
                    </div>

                    {/* Text Content */}
                    <div 
                      className="text-gray-900 leading-relaxed select-text"
                      dangerouslySetInnerHTML={{ 
                        __html: highlightSearchQuery(segment.text) 
                      }}
                    />
                  </div>

                  {/* Actions */}
                  <div className="ml-4 opacity-0 group-hover:opacity-100 transition-opacity">
                    {onCreateCard && (
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => setSelectedText({ 
                          text: segment.text, 
                          start: segment.start, 
                          end: segment.end 
                        })}
                      >
                        <Plus className="w-4 h-4" />
                      </Button>
                    )}
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      </Card>

      {/* Summary Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-4 gap-4">
        <Card className="p-4 text-center">
          <div className="text-2xl font-bold text-blue-600">{segments.length}</div>
          <div className="text-sm text-gray-600">Total Segments</div>
        </Card>
        
        <Card className="p-4 text-center">
          <div className="text-2xl font-bold text-green-600">{speakers.length || 1}</div>
          <div className="text-sm text-gray-600">Speakers</div>
        </Card>
        
        <Card className="p-4 text-center">
          <div className="text-2xl font-bold text-purple-600">
            {Math.ceil(transcript.content.split(' ').length / 150)}
          </div>
          <div className="text-sm text-gray-600">Est. Minutes</div>
        </Card>
        
        <Card className="p-4 text-center">
          <div className="text-2xl font-bold text-orange-600">
            {transcript.content.split(' ').length}
          </div>
          <div className="text-sm text-gray-600">Words</div>
        </Card>
      </div>
    </div>
  )
}