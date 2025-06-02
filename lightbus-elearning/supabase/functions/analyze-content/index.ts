import { serve } from "https://deno.land/std@0.208.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface AnalyzeContentRequest {
  lesson_id: string
  content: string
  analysis_types: ('key_concepts' | 'learning_objectives' | 'prerequisites' | 'difficulty_assessment' | 'topic_extraction')[]
  options?: {
    educational_level?: string
    subject_area?: string
    language?: string
    detailed_analysis?: boolean
  }
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

    const { 
      lesson_id, 
      content, 
      analysis_types,
      options = {} 
    }: AnalyzeContentRequest = await req.json()

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
        JSON.stringify({ error: 'Unauthorized to analyze content for this lesson' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create processing job
    const { data: processingJob, error: jobError } = await supabaseClient
      .from('processing_jobs')
      .insert({
        lesson_id,
        job_type: 'content_analysis',
        status: 'pending',
        input_data: { 
          content: content.substring(0, 1000), // Store truncated version
          analysis_types,
          options 
        },
        ai_service_provider: 'openai',
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
      status: 'processing',
      progress_percentage: 10
    })

    try {
      const analysisResults = []
      const totalAnalyses = analysis_types.length

      // Perform each type of analysis
      for (let i = 0; i < analysis_types.length; i++) {
        const analysisType = analysis_types[i]
        const progress = Math.floor(((i + 1) / totalAnalyses) * 80) + 10

        await updateJobStatus(supabaseClient, processingJob.id, {
          status: 'processing',
          progress_percentage: progress
        })

        const analysisResult = await performAnalysis(content, analysisType, options)
        
        // Store analysis result
        const { data: storedAnalysis, error: analysisError } = await supabaseClient
          .from('content_analysis')
          .insert({
            lesson_id,
            processing_job_id: processingJob.id,
            analysis_type: analysisType,
            analysis_data: analysisResult.data,
            confidence_score: analysisResult.confidence_score
          })
          .select()
          .single()

        if (!analysisError && storedAnalysis) {
          analysisResults.push(storedAnalysis)
        }
      }

      // Generate learning insights based on analysis
      await updateJobStatus(supabaseClient, processingJob.id, {
        status: 'processing',
        progress_percentage: 95
      })

      const insights = await generateLearningInsights(analysisResults, content, options)
      
      // Store insights if generated
      if (insights.length > 0) {
        await supabaseClient
          .from('learning_insights')
          .insert(
            insights.map(insight => ({
              student_id: user.id, // For now, associate with teacher, later can be per student
              lesson_id,
              insight_type: insight.type,
              insight_data: insight.data,
              priority_level: insight.priority,
              confidence_score: insight.confidence,
              is_active: true
            }))
          )
      }

      // Complete the job
      await updateJobStatus(supabaseClient, processingJob.id, {
        status: 'completed',
        progress_percentage: 100,
        output_data: {
          analysis_count: analysisResults.length,
          insights_generated: insights.length,
          analysis_types_completed: analysis_types,
          content_length: content.length,
          educational_level: options.educational_level,
          subject_area: options.subject_area
        }
      })

      return new Response(
        JSON.stringify({
          success: true,
          job_id: processingJob.id,
          analysis_results: analysisResults,
          insights_generated: insights.length,
          message: 'Content analysis completed successfully'
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )

    } catch (error) {
      console.error('Content analysis failed:', error)
      
      // Update job status to failed
      await updateJobStatus(supabaseClient, processingJob.id, {
        status: 'failed',
        error_message: error instanceof Error ? error.message : 'Unknown error'
      })

      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'Content analysis failed',
          job_id: processingJob.id,
          details: error instanceof Error ? error.message : 'Unknown error'
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

async function updateJobStatus(supabaseClient: any, jobId: string, update: any) {
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

async function performAnalysis(content: string, analysisType: string, options: any) {
  const openaiApiKey = Deno.env.get('OPENAI_API_KEY')
  if (!openaiApiKey) {
    throw new Error('OpenAI API key not configured')
  }

  const prompts = {
    key_concepts: {
      system: `You are an educational content analyzer. Extract the key concepts, main ideas, and important terms from the educational content. Return a JSON object with an array of key concepts, each with a name, description, and importance level (1-5).`,
      user: `Extract key concepts from this educational content:\n\n${content}`
    },
    learning_objectives: {
      system: `You are an educational curriculum designer. Based on the content provided, identify clear, measurable learning objectives that students should achieve after studying this material. Use Bloom's taxonomy levels. Return a JSON object with learning objectives, each having an objective statement, cognitive level, and measurability score.`,
      user: `Identify learning objectives for this educational content:\n\n${content}`
    },
    prerequisites: {
      system: `You are an educational pathway advisor. Analyze the content and identify prerequisite knowledge, skills, or concepts that students should have before studying this material. Return a JSON object with prerequisites, each having a topic, importance level, and justification.`,
      user: `Identify prerequisites for understanding this educational content:\n\n${content}`
    },
    difficulty_assessment: {
      system: `You are an educational difficulty assessor. Analyze the content and assess its difficulty level considering vocabulary, concepts, cognitive load, and prerequisites. Return a JSON object with overall difficulty (1-10), difficulty factors, and recommendations for different learner levels.`,
      user: `Assess the difficulty level of this educational content:\n\n${content}`
    },
    topic_extraction: {
      system: `You are a topic modeling expert. Extract and categorize the main topics and subtopics covered in the educational content. Return a JSON object with hierarchical topics, each with a name, category, and relevance score.`,
      user: `Extract topics from this educational content:\n\n${content}`
    }
  }

  const prompt = prompts[analysisType as keyof typeof prompts]
  if (!prompt) {
    throw new Error(`Unknown analysis type: ${analysisType}`)
  }

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${openaiApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4',
      messages: [
        { role: 'system', content: prompt.system },
        { role: 'user', content: prompt.user }
      ],
      max_tokens: 1000,
      temperature: 0.3,
    }),
  })

  if (!response.ok) {
    const errorData = await response.json()
    throw new Error(`OpenAI API error: ${errorData.error?.message || 'Unknown error'}`)
  }

  const result = await response.json()
  const analysisContent = result.choices[0].message.content

  try {
    const analysisData = JSON.parse(analysisContent)
    return {
      data: analysisData,
      confidence_score: 0.85,
      processing_type: analysisType
    }
  } catch (error) {
    console.error('Failed to parse analysis result:', error)
    return {
      data: { raw_content: analysisContent },
      confidence_score: 0.5,
      processing_type: analysisType
    }
  }
}

async function generateLearningInsights(analysisResults: any[], content: string, options: any) {
  const openaiApiKey = Deno.env.get('OPENAI_API_KEY')
  if (!openaiApiKey || analysisResults.length === 0) {
    return []
  }

  const analysisData = analysisResults.reduce((acc, result) => {
    acc[result.analysis_type] = result.analysis_data
    return acc
  }, {})

  const systemPrompt = `You are an intelligent learning analytics system. Based on the content analysis results, generate actionable learning insights and recommendations. Consider the educational level, subject area, and analysis data to provide personalized recommendations.

Return a JSON array of insights, each with:
- type: One of 'weakness_identification', 'study_recommendation', 'optimal_timing', 'progress_prediction', 'intervention_needed'
- data: Object with specific insight details
- priority: Integer 1-5 (5 being highest priority)
- confidence: Float 0.0-1.0

Focus on practical, actionable recommendations that can help improve learning outcomes.`

  const userPrompt = `Generate learning insights based on this analysis:

Analysis Results: ${JSON.stringify(analysisData, null, 2)}
Educational Level: ${options.educational_level || 'Not specified'}
Subject Area: ${options.subject_area || 'Not specified'}
Content Length: ${content.length} characters`

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openaiApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-3.5-turbo',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt }
        ],
        max_tokens: 800,
        temperature: 0.4,
      }),
    })

    if (!response.ok) {
      console.error('Failed to generate learning insights')
      return []
    }

    const result = await response.json()
    const insightsContent = result.choices[0].message.content

    try {
      const insights = JSON.parse(insightsContent)
      return Array.isArray(insights) ? insights : []
    } catch (error) {
      console.error('Failed to parse learning insights:', error)
      return []
    }
  } catch (error) {
    console.error('Error generating learning insights:', error)
    return []
  }
}