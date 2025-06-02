import { serve } from "https://deno.land/std@0.208.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ProcessAudioRequest {
  lesson_id: string
  audio_url: string
  service_provider?: 'openai' | 'assemblyai'
  options?: {
    language?: string
    speaker_labels?: boolean
    auto_highlights?: boolean
    sentiment_analysis?: boolean
    entity_detection?: boolean
  }
}

interface ProcessingJobUpdate {
  job_id: string
  status: 'pending' | 'processing' | 'completed' | 'failed'
  progress_percentage?: number
  error_message?: string
  output_data?: any
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get the authorization header
    const authHeader = req.headers.get('Authorization')!
    const token = authHeader.replace('Bearer ', '')

    // Verify the user
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser(token)
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { lesson_id, audio_url, service_provider = 'openai', options = {} }: ProcessAudioRequest = await req.json()

    // Validate lesson access
    const { data: lesson, error: lessonError } = await supabaseClient
      .from('lessons')
      .select('id, teacher_id, name')
      .eq('id', lesson_id)
      .single()

    if (lessonError || !lesson) {
      return new Response(
        JSON.stringify({ error: 'Lesson not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check if user is the teacher of this lesson
    if (lesson.teacher_id !== user.id) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized to process this lesson' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create processing job
    const { data: processingJob, error: jobError } = await supabaseClient
      .from('processing_jobs')
      .insert({
        lesson_id,
        job_type: 'transcription',
        status: 'pending',
        input_data: { audio_url, options },
        ai_service_provider: service_provider,
        created_by: user.id
      })
      .select()
      .single()

    if (jobError) {
      console.error('Failed to create processing job:', jobError)
      return new Response(
        JSON.stringify({ error: 'Failed to create processing job' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Update job status to processing
    await updateJobStatus(supabaseClient, processingJob.id, {
      job_id: processingJob.id,
      status: 'processing',
      progress_percentage: 5
    })

    // Process audio based on service provider
    let transcriptionResult
    try {
      if (service_provider === 'openai') {
        transcriptionResult = await processWithOpenAI(audio_url, options)
      } else if (service_provider === 'assemblyai') {
        transcriptionResult = await processWithAssemblyAI(audio_url, options)
      } else {
        throw new Error('Invalid service provider')
      }

      // Update progress
      await updateJobStatus(supabaseClient, processingJob.id, {
        job_id: processingJob.id,
        status: 'processing',
        progress_percentage: 80
      })

      // Store transcript
      const { data: transcript, error: transcriptError } = await supabaseClient
        .from('transcripts')
        .insert({
          lesson_id,
          content: transcriptionResult.text,
          transcript_type: 'auto',
          confidence_score: transcriptionResult.confidence
        })
        .select()
        .single()

      if (transcriptError) {
        throw new Error('Failed to store transcript')
      }

      // Generate summary if transcript is long enough
      let summary = null
      if (transcriptionResult.text.length > 500) {
        await updateJobStatus(supabaseClient, processingJob.id, {
          job_id: processingJob.id,
          status: 'processing',
          progress_percentage: 90
        })

        const summaryResult = await generateSummary(transcriptionResult.text)
        
        const { data: summaryData, error: summaryError } = await supabaseClient
          .from('summaries')
          .insert({
            lesson_id,
            content: summaryResult.summary,
            summary_type: 'auto'
          })
          .select()
          .single()

        if (!summaryError) {
          summary = summaryData
        }
      }

      // Store content analysis
      const analysisResult = await analyzeContent(transcriptionResult.text)
      
      const { data: contentAnalysis } = await supabaseClient
        .from('content_analysis')
        .insert({
          lesson_id,
          processing_job_id: processingJob.id,
          analysis_type: 'key_concepts',
          analysis_data: analysisResult,
          confidence_score: analysisResult.confidence
        })
        .select()
        .single()

      // Complete the job
      await updateJobStatus(supabaseClient, processingJob.id, {
        job_id: processingJob.id,
        status: 'completed',
        progress_percentage: 100,
        output_data: {
          transcript_id: transcript.id,
          summary_id: summary?.id,
          analysis_id: contentAnalysis?.id,
          processing_time_ms: transcriptionResult.processing_time_ms,
          word_count: transcriptionResult.text.split(' ').length
        }
      })

      return new Response(
        JSON.stringify({
          success: true,
          job_id: processingJob.id,
          transcript_id: transcript.id,
          summary_id: summary?.id,
          analysis_id: contentAnalysis?.id,
          message: 'Audio processing completed successfully'
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )

    } catch (error) {
      console.error('Audio processing failed:', error)
      
      // Update job status to failed
      await updateJobStatus(supabaseClient, processingJob.id, {
        job_id: processingJob.id,
        status: 'failed',
        error_message: error.message
      })

      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'Audio processing failed',
          job_id: processingJob.id,
          details: error.message 
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

  } catch (error) {
    console.error('Request processing failed:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

async function updateJobStatus(supabaseClient: any, jobId: string, update: ProcessingJobUpdate) {
  try {
    await supabaseClient
      .from('processing_jobs')
      .update({
        status: update.status,
        progress_percentage: update.progress_percentage,
        error_message: update.error_message,
        output_data: update.output_data,
        processing_started_at: update.status === 'processing' ? new Date().toISOString() : undefined,
        processing_completed_at: ['completed', 'failed'].includes(update.status) ? new Date().toISOString() : undefined,
        updated_at: new Date().toISOString()
      })
      .eq('id', jobId)
  } catch (error) {
    console.error('Failed to update job status:', error)
  }
}

async function processWithOpenAI(audioUrl: string, options: any) {
  const openaiApiKey = Deno.env.get('OPENAI_API_KEY')
  if (!openaiApiKey) {
    throw new Error('OpenAI API key not configured')
  }

  const startTime = Date.now()

  // Download audio file
  const audioResponse = await fetch(audioUrl)
  if (!audioResponse.ok) {
    throw new Error('Failed to download audio file')
  }

  const audioBlob = await audioResponse.blob()
  
  // Prepare form data for OpenAI Whisper API
  const formData = new FormData()
  formData.append('file', audioBlob, 'audio.mp3')
  formData.append('model', 'whisper-1')
  formData.append('response_format', 'verbose_json')
  
  if (options.language) {
    formData.append('language', options.language)
  }

  // Call OpenAI Whisper API
  const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${openaiApiKey}`,
    },
    body: formData,
  })

  if (!response.ok) {
    const errorData = await response.json()
    throw new Error(`OpenAI API error: ${errorData.error?.message || 'Unknown error'}`)
  }

  const result = await response.json()
  
  return {
    text: result.text,
    confidence: 0.85, // OpenAI doesn't provide confidence scores, use default
    segments: result.segments || [],
    processing_time_ms: Date.now() - startTime
  }
}

async function processWithAssemblyAI(audioUrl: string, options: any) {
  const assemblyaiApiKey = Deno.env.get('ASSEMBLYAI_API_KEY')
  if (!assemblyaiApiKey) {
    throw new Error('AssemblyAI API key not configured')
  }

  const startTime = Date.now()

  // Submit transcription job to AssemblyAI
  const transcriptResponse = await fetch('https://api.assemblyai.com/v2/transcript', {
    method: 'POST',
    headers: {
      'Authorization': assemblyaiApiKey,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      audio_url: audioUrl,
      speaker_labels: options.speaker_labels || false,
      auto_highlights: options.auto_highlights || false,
      sentiment_analysis: options.sentiment_analysis || false,
      entity_detection: options.entity_detection || false,
      language_code: options.language || 'en_us'
    }),
  })

  if (!transcriptResponse.ok) {
    throw new Error('Failed to submit transcription job to AssemblyAI')
  }

  const transcript = await transcriptResponse.json()
  const transcriptId = transcript.id

  // Poll for completion
  let transcriptionResult
  let attempts = 0
  const maxAttempts = 60 // 5 minutes timeout

  while (attempts < maxAttempts) {
    await new Promise(resolve => setTimeout(resolve, 5000)) // Wait 5 seconds

    const statusResponse = await fetch(`https://api.assemblyai.com/v2/transcript/${transcriptId}`, {
      headers: {
        'Authorization': assemblyaiApiKey,
      },
    })

    if (!statusResponse.ok) {
      throw new Error('Failed to check transcription status')
    }

    transcriptionResult = await statusResponse.json()

    if (transcriptionResult.status === 'completed') {
      break
    } else if (transcriptionResult.status === 'error') {
      throw new Error(`AssemblyAI transcription failed: ${transcriptionResult.error}`)
    }

    attempts++
  }

  if (attempts >= maxAttempts) {
    throw new Error('Transcription timed out')
  }

  return {
    text: transcriptionResult.text,
    confidence: transcriptionResult.confidence,
    segments: transcriptionResult.words || [],
    processing_time_ms: Date.now() - startTime
  }
}

async function generateSummary(text: string) {
  const openaiApiKey = Deno.env.get('OPENAI_API_KEY')
  if (!openaiApiKey) {
    throw new Error('OpenAI API key not configured for summary generation')
  }

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${openaiApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-3.5-turbo',
      messages: [
        {
          role: 'system',
          content: 'You are an educational content summarizer. Create a concise, well-structured summary of the lesson content that highlights key concepts, main points, and learning objectives. Use bullet points and clear headings.'
        },
        {
          role: 'user',
          content: `Please summarize this lesson transcript:\n\n${text}`
        }
      ],
      max_tokens: 500,
      temperature: 0.3,
    }),
  })

  if (!response.ok) {
    throw new Error('Failed to generate summary')
  }

  const result = await response.json()
  return {
    summary: result.choices[0].message.content
  }
}

async function analyzeContent(text: string) {
  const openaiApiKey = Deno.env.get('OPENAI_API_KEY')
  if (!openaiApiKey) {
    return { key_concepts: [], confidence: 0 }
  }

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${openaiApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-3.5-turbo',
      messages: [
        {
          role: 'system',
          content: 'You are an educational content analyzer. Extract key concepts, learning objectives, and important topics from the lesson content. Return your analysis as a JSON object with arrays for key_concepts, learning_objectives, and topics.'
        },
        {
          role: 'user',
          content: `Analyze this lesson content and extract key educational elements:\n\n${text}`
        }
      ],
      max_tokens: 300,
      temperature: 0.2,
    }),
  })

  if (!response.ok) {
    return { key_concepts: [], confidence: 0 }
  }

  try {
    const result = await response.json()
    const content = result.choices[0].message.content
    const analysis = JSON.parse(content)
    
    return {
      ...analysis,
      confidence: 0.8
    }
  } catch (error) {
    console.error('Failed to parse content analysis:', error)
    return { key_concepts: [], confidence: 0 }
  }
}