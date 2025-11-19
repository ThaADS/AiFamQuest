import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { GoogleGenerativeAI } from 'npm:@google/generative-ai@0.1.3'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface StudyPlanRequest {
  userId: string
  subject: string
  topic: string
  examDate: string
  difficulty: 'easy' | 'medium' | 'hard'
  availableTime: number
}

interface StudySession {
  date: string
  duration: number
  focus: string
  tasks: string[]
  difficulty: string
}

interface QuizQuestion {
  q: string
  a?: string
  type: 'text' | 'multiple_choice'
  options?: string[]
  answer?: string
}

interface StudyPlan {
  plan: StudySession[]
  milestones: Array<{ date: string; checkpoint: string }>
  quizzes: Array<{ sessionIndex: number; questions: QuizQuestion[] }>
  totalEstimatedHours: number
  confidenceScore: number
}

function calculateSessionDates(examDate: Date, numSessions: number): Date[] {
  const dates: Date[] = []
  const intervals = [1, 3, 7, 14, 21] // Spaced repetition intervals in days

  let currentDate = new Date(examDate)
  currentDate.setDate(currentDate.getDate() - 1) // Day before exam

  for (let i = numSessions - 1; i >= 0; i--) {
    dates.unshift(new Date(currentDate))
    const interval = intervals[Math.min(i, intervals.length - 1)]
    currentDate.setDate(currentDate.getDate() - interval)
  }

  return dates
}

function buildPrompt(params: {
  user: { name: string; age: number }
  subject: string
  topic: string
  examDate: string
  difficulty: string
  availableTime: number
  daysUntilExam: number
}): string {
  const { user, subject, topic, examDate, difficulty, availableTime, daysUntilExam } = params

  return `You are an expert study coach for students aged 10-17.

Student Profile:
- Name: ${user.name}
- Age: ${user.age}

Study Item:
- Subject: ${subject} (e.g., Biology, Math, History)
- Topic: ${topic}
- Exam Date: ${examDate}
- Difficulty: ${difficulty} (easy/medium/hard)
- Available Time: ${availableTime} minutes per session
- Days Until Exam: ${daysUntilExam}

Create a backward study plan using spaced repetition:
1. Break topic into subtopics (5-10 items)
2. Schedule study sessions working backwards from exam
3. Apply spaced repetition intervals: 1 day → 3 days → 7 days → 14 days
4. Number of sessions based on difficulty:
   - Easy: 3 sessions (1 week before)
   - Medium: 5 sessions (2 weeks before)
   - Hard: 7+ sessions (3-4 weeks before)
5. Generate 2-3 practice questions per session (mix text and multiple choice)
6. Include checkpoints every 3 sessions

Return ONLY valid JSON (no markdown):
{
  "plan": [
    {
      "date": "YYYY-MM-DD",
      "duration": ${availableTime},
      "focus": "Short subtopic name",
      "tasks": ["Specific task 1", "Specific task 2", "5-min quiz"],
      "difficulty": "easy|medium|hard"
    }
  ],
  "milestones": [
    {"date": "YYYY-MM-DD", "checkpoint": "Quiz: topics covered"}
  ],
  "quizzes": [
    {
      "sessionIndex": 0,
      "questions": [
        {"q": "Question text?", "a": "Answer", "type": "text"},
        {"q": "Multiple choice question?", "options": ["A", "B", "C"], "answer": "B", "type": "multiple_choice"}
      ]
    }
  ],
  "totalEstimatedHours": 5.5,
  "confidenceScore": 0.85
}

IMPORTANT: Return only the JSON object, no additional text or formatting.`
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { userId, subject, topic, examDate, difficulty, availableTime } = await req.json() as StudyPlanRequest

    // Validate input
    if (!userId || !subject || !topic || !examDate || !difficulty || !availableTime) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Initialize Supabase client
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Fetch user data
    const { data: user, error: userError } = await supabaseAdmin
      .from('users')
      .select('name, age')
      .eq('id', userId)
      .single()

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'User not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Calculate days until exam
    const examDateObj = new Date(examDate)
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const daysUntilExam = Math.floor((examDateObj.getTime() - today.getTime()) / (1000 * 60 * 60 * 24))

    if (daysUntilExam < 1) {
      return new Response(
        JSON.stringify({ error: 'Exam date must be in the future' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Initialize Gemini
    const genAI = new GoogleGenerativeAI(Deno.env.get('GEMINI_API_KEY') ?? '')
    const model = genAI.getGenerativeModel({ model: 'gemini-2.0-flash-exp' })

    // Build prompt
    const prompt = buildPrompt({
      user,
      subject,
      topic,
      examDate,
      difficulty,
      availableTime,
      daysUntilExam
    })

    console.log('Calling Gemini with prompt...')

    // Call Gemini
    const result = await model.generateContent(prompt)
    const responseText = result.response.text()

    console.log('Gemini response:', responseText)

    // Parse JSON response
    let plan: StudyPlan
    try {
      // Remove markdown code blocks if present
      const cleanedText = responseText
        .replace(/```json\n/g, '')
        .replace(/```\n/g, '')
        .replace(/```/g, '')
        .trim()

      plan = JSON.parse(cleanedText)
    } catch (parseError) {
      console.error('Failed to parse Gemini response:', parseError)
      return new Response(
        JSON.stringify({ error: 'Invalid AI response format', details: responseText }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Save study item to database
    const { data: studyItem, error: insertError } = await supabaseAdmin
      .from('study_items')
      .insert({
        user_id: userId,
        subject,
        topic,
        test_date: examDate,
        study_plan: plan,
        status: 'active',
        difficulty
      })
      .select()
      .single()

    if (insertError) {
      console.error('Failed to insert study item:', insertError)
      return new Response(
        JSON.stringify({ error: 'Failed to save study plan' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create study sessions
    const sessionsToInsert = plan.plan.map(session => ({
      study_item_id: studyItem.id,
      scheduled_at: new Date(session.date).toISOString(),
      duration: session.duration,
      focus: session.focus,
      tasks: session.tasks,
      completed: false
    }))

    const { error: sessionsError } = await supabaseAdmin
      .from('study_sessions')
      .insert(sessionsToInsert)

    if (sessionsError) {
      console.error('Failed to insert study sessions:', sessionsError)
      // Don't fail the request, study item is already created
    }

    return new Response(
      JSON.stringify({
        success: true,
        studyItem,
        plan
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('Error in ai-homework-coach function:', error)
    return new Response(
      JSON.stringify({
        error: 'Internal server error',
        details: error instanceof Error ? error.message : 'Unknown error'
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
