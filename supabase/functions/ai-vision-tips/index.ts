/**
 * AI Vision Cleaning Tips - Supabase Edge Function
 *
 * Analyzes photos of stains/messes using Gemini Vision API
 * and provides step-by-step cleaning guidance
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')
const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-latest:generateContent'

interface VisionContext {
  room?: string
  surface?: string
  userInput?: string
}

interface VisionRequest {
  image_url: string
  context: VisionContext
}

interface DetectionResult {
  surface: string
  stain: string
  confidence: number
}

interface ProductRecommendations {
  recommended: string[]
  avoid: string[]
}

interface VisionResponse {
  detected: DetectionResult
  steps: string[]
  products: ProductRecommendations
  warnings: string[]
  estimatedMinutes: number
  difficulty: number
}

async function downloadImage(url: string): Promise<string> {
  const response = await fetch(url)
  if (!response.ok) {
    throw new Error(`Failed to download image: ${response.statusText}`)
  }

  const arrayBuffer = await response.arrayBuffer()
  const base64 = btoa(
    new Uint8Array(arrayBuffer).reduce((data, byte) => data + String.fromCharCode(byte), '')
  )

  return base64
}

function buildPrompt(context: VisionContext): string {
  return `Analyze this photo and provide detailed cleaning advice.

Context:
- Room: ${context.room || 'unknown'}
- Surface type (if known): ${context.surface || 'unknown'}
- User notes: ${context.userInput || 'none'}

Analyze the image carefully and provide:
1. Detected surface type (marble, wood, fabric, tile, glass, plastic, metal, etc.)
2. Stain/mess identification (wine, grease, ink, food, dirt, mold, etc.)
3. Confidence level (0.0 to 1.0)
4. Step-by-step cleaning instructions (5-10 clear, actionable steps)
5. Recommended products (prefer common household items)
6. Products to AVOID (can damage this surface)
7. Safety warnings if applicable
8. Estimated time in minutes
9. Difficulty rating (1=easy, 2=medium, 3=hard, 4=very hard, 5=professional needed)

IMPORTANT: Return ONLY valid JSON in this exact format:
{
  "detected": {
    "surface": "marble",
    "stain": "red_wine",
    "confidence": 0.87
  },
  "steps": [
    "Step 1: Blot immediately with paper towel (don't rub)",
    "Step 2: Mix baking soda with water to create a paste",
    "Step 3: Apply paste to stain and let sit for 10 minutes",
    "Step 4: Wipe with damp microfiber cloth",
    "Step 5: Dry thoroughly with clean towel"
  ],
  "products": {
    "recommended": ["Baking soda", "White vinegar (diluted)", "Microfiber cloth"],
    "avoid": ["Bleach", "Acidic cleaners (lemon juice)", "Abrasive scrubbers"]
  },
  "warnings": [
    "Marble is porous - act quickly to prevent staining",
    "Test any cleaner on hidden area first",
    "Never use acidic products on marble"
  ],
  "estimatedMinutes": 15,
  "difficulty": 2
}

Do not include any text before or after the JSON. Return only the JSON object.`
}

async function analyzeWithGemini(imageBase64: string, context: VisionContext): Promise<VisionResponse> {
  const prompt = buildPrompt(context)

  const requestBody = {
    contents: [
      {
        parts: [
          { text: prompt },
          {
            inline_data: {
              mime_type: 'image/jpeg',
              data: imageBase64
            }
          }
        ]
      }
    ],
    generationConfig: {
      temperature: 0.4,
      topK: 32,
      topP: 1,
      maxOutputTokens: 2048,
    },
    safetySettings: [
      {
        category: "HARM_CATEGORY_HARASSMENT",
        threshold: "BLOCK_MEDIUM_AND_ABOVE"
      },
      {
        category: "HARM_CATEGORY_HATE_SPEECH",
        threshold: "BLOCK_MEDIUM_AND_ABOVE"
      },
      {
        category: "HARM_CATEGORY_SEXUALLY_EXPLICIT",
        threshold: "BLOCK_MEDIUM_AND_ABOVE"
      },
      {
        category: "HARM_CATEGORY_DANGEROUS_CONTENT",
        threshold: "BLOCK_MEDIUM_AND_ABOVE"
      }
    ]
  }

  const response = await fetch(`${GEMINI_API_URL}?key=${GEMINI_API_KEY}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(requestBody)
  })

  if (!response.ok) {
    const errorText = await response.text()
    throw new Error(`Gemini API error: ${response.status} ${errorText}`)
  }

  const data = await response.json()

  if (!data.candidates || data.candidates.length === 0) {
    throw new Error('No response from Gemini API')
  }

  const textResponse = data.candidates[0].content.parts[0].text

  // Extract JSON from response (handle potential markdown code blocks)
  let jsonText = textResponse.trim()
  if (jsonText.startsWith('```json')) {
    jsonText = jsonText.replace(/```json\n?/g, '').replace(/```\n?$/g, '')
  } else if (jsonText.startsWith('```')) {
    jsonText = jsonText.replace(/```\n?/g, '').replace(/```\n?$/g, '')
  }

  try {
    const parsedResponse: VisionResponse = JSON.parse(jsonText)

    // Validate response structure
    if (!parsedResponse.detected || !parsedResponse.steps || !parsedResponse.products) {
      throw new Error('Invalid response structure from Gemini')
    }

    return parsedResponse
  } catch (parseError) {
    console.error('Failed to parse Gemini response:', textResponse)
    throw new Error(`Failed to parse JSON response: ${parseError.message}`)
  }
}

serve(async (req: Request) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  try {
    // Verify Gemini API key is configured
    if (!GEMINI_API_KEY) {
      throw new Error('GEMINI_API_KEY environment variable is not set')
    }

    // Parse request body
    const requestData: VisionRequest = await req.json()

    if (!requestData.image_url) {
      return new Response(
        JSON.stringify({ error: 'image_url is required' }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }

    // Download and convert image to base64
    console.log('Downloading image from:', requestData.image_url)
    const imageBase64 = await downloadImage(requestData.image_url)

    // Analyze with Gemini Vision
    console.log('Analyzing with Gemini Vision...')
    const analysis = await analyzeWithGemini(imageBase64, requestData.context || {})

    // Return successful response
    return new Response(
      JSON.stringify({
        success: true,
        analysis,
        metadata: {
          model: 'gemini-2.5-flash-latest',
          timestamp: new Date().toISOString(),
          context: requestData.context
        }
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )

  } catch (error) {
    console.error('Error in ai-vision-tips function:', error)

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Internal server error',
        timestamp: new Date().toISOString()
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  }
})
