import { serve } from "https://deno.land/std@0.208.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface GenerateFlashcardsRequest {
  lesson_id: string
  source_content?: string
  transcript_id?: string
  options?: {
    card_count?: number
    difficulty_level?: number
    card_types?: ('basic' | 'cloze' | 'multiple_choice' | 'true_false')[]
    focus_topics?: string[]
    min_quality_score?: number
    auto_approve_threshold?: number
  }
}

interface GeneratedCard {
  front_content: string
  back_content: string
  card_type: string
  difficulty_level: number
  confidence_score: number
  source_text?: string
  source_timestamp_start?: number
  source_timestamp_end?: number
  tags: string[]
  quality_score: number
  explanation?: string
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
      source_content, 
      transcript_id, 
      options = {} 
    }: GenerateFlashcardsRequest = await req.json()

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
        JSON.stringify({ error: 'Unauthorized to generate flashcards for this lesson' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get source content
    let contentToProcess = source_content
    if (!contentToProcess && transcript_id) {
      const { data: transcript, error: transcriptError } = await supabaseClient
        .from('transcripts')
        .select('content')
        .eq('id', transcript_id)
        .single()

      if (transcript && !transcriptError) {
        contentToProcess = transcript.content
      }
    }

    if (!contentToProcess) {
      return new Response(
        JSON.stringify({ error: 'No source content provided' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create processing job
    const { data: processingJob, error: jobError } = await supabaseClient
      .from('processing_jobs')
      .insert({
        lesson_id,
        job_type: 'flashcard_generation',
        status: 'pending',
        input_data: { 
          source_content: contentToProcess.substring(0, 1000), // Store truncated version
          transcript_id,
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
      // Generate flashcards using OpenAI
      await updateJobStatus(supabaseClient, processingJob.id, {
        status: 'processing',
        progress_percentage: 30
      })

      const generatedCards = await generateFlashcardsWithAI(contentToProcess, options)

      await updateJobStatus(supabaseClient, processingJob.id, {
        status: 'processing',
        progress_percentage: 70
      })

      // Store generated cards
      const cardsToStore = generatedCards.map(card => ({
        lesson_id,
        processing_job_id: processingJob.id,
        front_content: card.front_content,
        back_content: card.back_content,
        card_type: card.card_type,
        difficulty_level: card.difficulty_level,
        confidence_score: card.confidence_score,
        source_text: card.source_text,
        source_timestamp_start: card.source_timestamp_start,
        source_timestamp_end: card.source_timestamp_end,
        tags: card.tags,
        quality_score: card.quality_score,
        review_status: card.quality_score >= (options.auto_approve_threshold || 0.8) ? 'approved' : 'pending',
        auto_approved: card.quality_score >= (options.auto_approve_threshold || 0.8)
      }))

      const { data: storedCards, error: storeError } = await supabaseClient
        .from('auto_generated_cards')
        .insert(cardsToStore)
        .select()

      if (storeError) {
        throw new Error('Failed to store generated cards')
      }

      await updateJobStatus(supabaseClient, processingJob.id, {
        status: 'processing',
        progress_percentage: 90
      })

      // Auto-approve high-quality cards by creating SR cards
      const autoApprovedCards = storedCards.filter(card => card.auto_approved)
      let createdSRCards = []

      if (autoApprovedCards.length > 0) {
        const srCardsToCreate = autoApprovedCards.map(card => ({
          lesson_id,
          created_by: user.id,
          front_content: card.front_content,
          back_content: card.back_content,
          card_type: card.card_type,
          difficulty_level: card.difficulty_level,
          tags: card.tags,
          status: 'approved',
          approved_by: user.id,
          approved_at: new Date().toISOString()
        }))

        const { data: srCards, error: srError } = await supabaseClient
          .from('sr_cards')
          .insert(srCardsToCreate)
          .select()

        if (!srError) {
          createdSRCards = srCards

          // Update auto_generated_cards with sr_card_id references
          for (let i = 0; i < autoApprovedCards.length; i++) {
            await supabaseClient
              .from('auto_generated_cards')
              .update({ sr_card_id: srCards[i].id })
              .eq('id', autoApprovedCards[i].id)
          }
        }
      }

      // Complete the job
      await updateJobStatus(supabaseClient, processingJob.id, {
        status: 'completed',
        progress_percentage: 100,
        output_data: {
          cards_generated: storedCards.length,
          cards_auto_approved: autoApprovedCards.length,
          cards_pending_review: storedCards.length - autoApprovedCards.length,
          sr_cards_created: createdSRCards.length,
          average_quality_score: storedCards.reduce((sum, card) => sum + card.quality_score, 0) / storedCards.length
        }
      })

      return new Response(
        JSON.stringify({
          success: true,
          job_id: processingJob.id,
          cards_generated: storedCards.length,
          cards_auto_approved: autoApprovedCards.length,
          cards_pending_review: storedCards.length - autoApprovedCards.length,
          generated_cards: storedCards,
          message: 'Flashcards generated successfully'
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )

    } catch (error) {
      console.error('Flashcard generation failed:', error)
      
      // Update job status to failed
      await updateJobStatus(supabaseClient, processingJob.id, {
        status: 'failed',
        error_message: error instanceof Error ? error.message : 'Unknown error'
      })

      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'Flashcard generation failed',
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

async function generateFlashcardsWithAI(content: string, options: any): Promise<GeneratedCard[]> {
  const openaiApiKey = Deno.env.get('OPENAI_API_KEY')
  if (!openaiApiKey) {
    throw new Error('OpenAI API key not configured')
  }

  const cardCount = options.card_count || 10
  const difficultyLevel = options.difficulty_level || 2
  const cardTypes = options.card_types || ['basic', 'cloze']
  const focusTopics = options.focus_topics || []
  const minQualityScore = options.min_quality_score || 0.6

  const systemPrompt = `You are an expert educational content creator specializing in creating high-quality flashcards for spaced repetition learning. 

Your task is to analyze the provided content and create ${cardCount} flashcards with the following specifications:
- Difficulty level: ${difficultyLevel}/5
- Card types to include: ${cardTypes.join(', ')}
- Minimum quality score: ${minQualityScore}
${focusTopics.length > 0 ? `- Focus on these topics: ${focusTopics.join(', ')}` : ''}

For each flashcard, provide:
1. front_content: The question or prompt (clear and concise)
2. back_content: The answer or explanation (comprehensive but not too lengthy)
3. card_type: One of ${cardTypes.join(', ')}
4. difficulty_level: 1-5 scale
5. confidence_score: 0.0-1.0 (how confident you are in the quality)
6. tags: Array of relevant keywords/topics
7. quality_score: 0.0-1.0 (overall quality assessment)
8. explanation: Brief explanation of why this is important to learn

Guidelines:
- Make questions specific and testable
- Ensure answers are accurate and complete
- Use clear, educational language
- Avoid overly complex or ambiguous questions
- For cloze cards, use {...} to indicate the deletion
- For multiple choice, include options in the back_content

Return ONLY a valid JSON array of flashcard objects.`

  const userPrompt = `Create flashcards from this educational content:\n\n${content}`

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${openaiApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt }
      ],
      max_tokens: 2000,
      temperature: 0.3,
    }),
  })

  if (!response.ok) {
    const errorData = await response.json()
    throw new Error(`OpenAI API error: ${errorData.error?.message || 'Unknown error'}`)
  }

  const result = await response.json()
  const content_response = result.choices[0].message.content

  try {
    const generatedCards = JSON.parse(content_response)
    
    // Validate and enhance generated cards
    return generatedCards
      .filter((card: any) => card.quality_score >= minQualityScore)
      .map((card: any, index: number) => ({
        front_content: card.front_content || '',
        back_content: card.back_content || '',
        card_type: cardTypes.includes(card.card_type) ? card.card_type : 'basic',
        difficulty_level: Math.min(5, Math.max(1, card.difficulty_level || difficultyLevel)),
        confidence_score: Math.min(1.0, Math.max(0.0, card.confidence_score || 0.7)),
        source_text: extractSourceText(content, card.front_content, index),
        tags: Array.isArray(card.tags) ? card.tags : [],
        quality_score: Math.min(1.0, Math.max(0.0, card.quality_score || 0.7)),
        explanation: card.explanation || ''
      }))
      .slice(0, cardCount) // Ensure we don't exceed requested count

  } catch (error) {
    console.error('Failed to parse generated flashcards:', error)
    throw new Error('Failed to parse AI-generated flashcards')
  }
}

function extractSourceText(content: string, frontContent: string, index: number): string {
  // Try to find relevant source text by looking for keywords from the question
  const keywords = frontContent.toLowerCase().split(' ').filter(word => word.length > 3)
  const sentences = content.split(/[.!?]+/)
  
  for (const sentence of sentences) {
    const sentenceLower = sentence.toLowerCase()
    const matchCount = keywords.filter(keyword => sentenceLower.includes(keyword)).length
    
    if (matchCount >= Math.max(1, keywords.length * 0.3)) {
      return sentence.trim()
    }
  }
  
  // Fallback: return a portion of content around the estimated position
  const estimatedPosition = Math.floor((index / 10) * content.length)
  const start = Math.max(0, estimatedPosition - 100)
  const end = Math.min(content.length, estimatedPosition + 100)
  
  return content.substring(start, end).trim()
}