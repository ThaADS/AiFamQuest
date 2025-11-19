import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')!
const GEMINI_BASE_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent'

interface FamilyMember {
  id: string
  name: string
  age: number
  role: 'parent' | 'teen' | 'child' | 'helper'
}

interface Task {
  id: string
  title: string
  category: string
  frequency: string
  estimated_duration: number
}

interface CalendarEvent {
  user_id: string
  date: string
  title: string
  start_time: string
  end_time: string
}

interface Constraints {
  maxTasksPerDay: number
  respectBusyHours: boolean
  rotationStrategy: 'fairness' | 'random' | 'fixed'
}

interface TaskAssignment {
  taskId: string
  title: string
  assignee: string
  suggestedTime: string
  reason: string
}

interface DayPlan {
  date: string
  tasks: TaskAssignment[]
}

interface WeekPlan {
  weekPlan: DayPlan[]
  fairness: {
    distribution: Record<string, number>
    notes: string
  }
}

serve(async (req) => {
  try {
    // Parse request
    const { familyId, weekStart, constraints = {} } = await req.json()

    if (!familyId || !weekStart) {
      return new Response(
        JSON.stringify({ error: 'familyId and weekStart are required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Fetch family members with ages and roles
    const { data: members, error: membersError } = await supabase
      .from('users')
      .select('id, display_name, age, role')
      .eq('family_id', familyId)

    if (membersError || !members || members.length === 0) {
      return new Response(
        JSON.stringify({ error: 'Failed to fetch family members', details: membersError }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Fetch recurring tasks
    const { data: tasks, error: tasksError } = await supabase
      .from('tasks')
      .select('id, title, category, frequency, estimated_duration')
      .eq('family_id', familyId)
      .not('frequency', 'is', null)
      .eq('status', 'active')

    if (tasksError) {
      return new Response(
        JSON.stringify({ error: 'Failed to fetch tasks', details: tasksError }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Calculate week end date (7 days from start)
    const weekStartDate = new Date(weekStart)
    const weekEndDate = new Date(weekStartDate)
    weekEndDate.setDate(weekEndDate.getDate() + 7)

    // Fetch calendar events for the week
    const { data: events, error: eventsError } = await supabase
      .from('events')
      .select('user_id, title, start_time, end_time')
      .eq('family_id', familyId)
      .gte('start_time', weekStartDate.toISOString())
      .lt('start_time', weekEndDate.toISOString())

    if (eventsError) {
      return new Response(
        JSON.stringify({ error: 'Failed to fetch events', details: eventsError }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Calculate workload capacity per member based on age/role
    const membersWithCapacity = members.map((m: any) => {
      let capacity = 0.10 // default for young kids

      if (m.role === 'parent') {
        capacity = 0.40
      } else if (m.role === 'teen' || (m.age && m.age >= 13 && m.age <= 17)) {
        capacity = 0.30
      } else if (m.role === 'child' || (m.age && m.age >= 6 && m.age <= 12)) {
        capacity = 0.20
      } else if (m.age && m.age < 6) {
        capacity = 0.10
      }

      return {
        id: m.id,
        name: m.display_name,
        age: m.age,
        role: m.role,
        workload: capacity
      }
    })

    // Format events for prompt
    const formattedEvents = (events || []).map((e: any) => ({
      userId: e.user_id,
      title: e.title,
      startTime: e.start_time,
      endTime: e.end_time
    }))

    // Build Gemini prompt
    const prompt = buildGeminiPrompt(
      membersWithCapacity,
      tasks || [],
      formattedEvents,
      {
        maxTasksPerDay: constraints.maxTasksPerDay || 3,
        respectBusyHours: constraints.respectBusyHours !== false,
        rotationStrategy: constraints.rotationStrategy || 'fairness'
      },
      weekStart
    )

    // Call Gemini API
    const geminiResponse = await fetch(
      `${GEMINI_BASE_URL}?key=${GEMINI_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{
            parts: [{ text: prompt }]
          }],
          generationConfig: {
            temperature: 0.7,
            topK: 40,
            topP: 0.95,
            maxOutputTokens: 2048,
          }
        })
      }
    )

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text()
      return new Response(
        JSON.stringify({ error: 'Gemini API request failed', details: errorText }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    const geminiData = await geminiResponse.json()

    // Extract text from Gemini response
    const responseText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text

    if (!responseText) {
      return new Response(
        JSON.stringify({ error: 'Invalid Gemini response format', details: geminiData }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Parse JSON from response (strip markdown code blocks if present)
    let cleanedText = responseText.trim()
    if (cleanedText.startsWith('```json')) {
      cleanedText = cleanedText.replace(/```json\n?/g, '').replace(/```\n?$/g, '')
    } else if (cleanedText.startsWith('```')) {
      cleanedText = cleanedText.replace(/```\n?/g, '').replace(/```\n?$/g, '')
    }

    const weekPlan: WeekPlan = JSON.parse(cleanedText)

    return new Response(
      JSON.stringify(weekPlan),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('AI Task Planner error:', error)
    return new Response(
      JSON.stringify({
        error: 'Internal server error',
        details: error instanceof Error ? error.message : String(error)
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})

function buildGeminiPrompt(
  members: Array<{ id: string; name: string; age: number; role: string; workload: number }>,
  tasks: any[],
  events: any[],
  constraints: Constraints,
  weekStart: string
): string {
  const weekStartDate = new Date(weekStart)
  const dates = Array.from({ length: 7 }, (_, i) => {
    const date = new Date(weekStartDate)
    date.setDate(date.getDate() + i)
    return date.toISOString().split('T')[0]
  })

  return `You are a fair task scheduler for families. Generate a weekly task distribution that balances workload fairly across family members.

**Family Members:**
${members.map(m => `- ${m.name} (ID: ${m.id}, age ${m.age}, role: ${m.role}, capacity: ${m.workload * 100}%)`).join('\n')}

**Recurring Tasks (this week):**
${tasks.map(t => `- ${t.title} (ID: ${t.id}, ${t.frequency}, ~${t.estimated_duration || 15}min, category: ${t.category})`).join('\n')}

**Calendar Events (busy times):**
${events.length > 0 ? events.map(e => `- ${e.title} (${e.userId}) at ${e.startTime}`).join('\n') : '(No events scheduled)'}

**Week Dates:** ${dates.join(', ')}

**Constraints:**
- Maximum ${constraints.maxTasksPerDay} tasks per person per day
- ${constraints.respectBusyHours ? 'Avoid scheduling during calendar events' : 'Ignore calendar events'}
- Fair distribution: parents 40%, teens 30%, children 20%, young kids 10%
- Rotate tasks: don't assign the same person repeatedly to the same task
- Suggest specific times (e.g., 17:00 before dinner, 08:00 before school)
- Consider task duration and member availability

**Important Rules:**
1. Each recurring task (daily/weekly) must appear in the schedule
2. Daily tasks should rotate among eligible members throughout the week
3. Weekly tasks should be assigned once to appropriate members
4. Parents should handle complex/dangerous tasks
5. Children should get age-appropriate tasks
6. Distribute workload to match capacity percentages
7. Provide clear reasoning for each assignment

Generate a weekly task schedule in this EXACT JSON format (no markdown, no explanations outside JSON):

{
  "weekPlan": [
    {
      "date": "2025-11-17",
      "tasks": [
        {
          "taskId": "task-uuid-here",
          "title": "Task name",
          "assignee": "user-uuid-here",
          "suggestedTime": "2025-11-17T17:00:00Z",
          "reason": "Why this person at this time (consider age, events, workload)"
        }
      ]
    }
  ],
  "fairness": {
    "distribution": {
      "user-uuid-1": 0.28,
      "user-uuid-2": 0.24
    },
    "notes": "Explanation of how workload was balanced"
  }
}

Respond with ONLY the JSON object, no additional text.`
}
