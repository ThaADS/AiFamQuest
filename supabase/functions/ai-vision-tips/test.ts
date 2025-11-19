/**
 * Test script for ai-vision-tips Edge Function
 *
 * Run with: deno run --allow-net --allow-env test.ts
 */

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || 'http://localhost:54321'
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') || 'test-key'

// Test images (example URLs - replace with real test images)
const TEST_IMAGES = {
  wine_stain: 'https://example.com/test-wine-stain.jpg',
  grease_stain: 'https://example.com/test-grease.jpg',
  ink_stain: 'https://example.com/test-ink.jpg',
}

interface TestCase {
  name: string
  imageUrl: string
  context: {
    room?: string
    surface?: string
    userInput?: string
  }
  expectedDetection: {
    surface?: string
    stain?: string
  }
}

const testCases: TestCase[] = [
  {
    name: 'Wine stain on marble',
    imageUrl: TEST_IMAGES.wine_stain,
    context: {
      room: 'kitchen',
      surface: 'marble',
      userInput: 'Red wine spilled on countertop',
    },
    expectedDetection: {
      surface: 'marble',
      stain: 'wine',
    },
  },
  {
    name: 'Grease on granite',
    imageUrl: TEST_IMAGES.grease_stain,
    context: {
      room: 'kitchen',
      surface: 'granite',
      userInput: 'Oil splatter near stove',
    },
    expectedDetection: {
      surface: 'granite',
      stain: 'grease',
    },
  },
  {
    name: 'Ink on fabric',
    imageUrl: TEST_IMAGES.ink_stain,
    context: {
      room: 'bedroom',
      surface: 'cotton',
      userInput: 'Pen leaked on shirt',
    },
    expectedDetection: {
      surface: 'fabric',
      stain: 'ink',
    },
  },
]

async function testFunction(testCase: TestCase): Promise<boolean> {
  console.log(`\n🧪 Testing: ${testCase.name}`)
  console.log(`   Image: ${testCase.imageUrl}`)
  console.log(`   Context: ${JSON.stringify(testCase.context)}`)

  try {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/ai-vision-tips`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
      },
      body: JSON.stringify({
        image_url: testCase.imageUrl,
        context: testCase.context,
      }),
    })

    const data = await response.json()

    if (!response.ok) {
      console.error(`   ❌ FAILED: ${data.error}`)
      return false
    }

    if (!data.success) {
      console.error(`   ❌ FAILED: Response not successful`)
      return false
    }

    const analysis = data.analysis

    // Validate structure
    if (!analysis || !analysis.detected || !analysis.steps || !analysis.products) {
      console.error(`   ❌ FAILED: Invalid response structure`)
      console.error(`   Response: ${JSON.stringify(data, null, 2)}`)
      return false
    }

    // Validate expected detection (fuzzy match)
    const detectedSurface = analysis.detected.surface.toLowerCase()
    const detectedStain = analysis.detected.stain.toLowerCase()

    let surfaceMatch = true
    let stainMatch = true

    if (testCase.expectedDetection.surface) {
      surfaceMatch = detectedSurface.includes(testCase.expectedDetection.surface.toLowerCase()) ||
        testCase.expectedDetection.surface.toLowerCase().includes(detectedSurface)
    }

    if (testCase.expectedDetection.stain) {
      stainMatch = detectedStain.includes(testCase.expectedDetection.stain.toLowerCase()) ||
        testCase.expectedDetection.stain.toLowerCase().includes(detectedStain)
    }

    console.log(`   📊 Detection:`)
    console.log(`      Surface: ${analysis.detected.surface} (confidence: ${analysis.detected.confidence})`)
    console.log(`      Stain: ${analysis.detected.stain}`)
    console.log(`   ⏱️  Time: ${analysis.estimatedMinutes} min (difficulty: ${analysis.difficulty}/5)`)
    console.log(`   📝 Steps: ${analysis.steps.length} steps`)
    console.log(`   ✅ Products: ${analysis.products.recommended.length} recommended`)
    console.log(`   ⚠️  Warnings: ${analysis.warnings.length} warnings`)

    if (!surfaceMatch || !stainMatch) {
      console.warn(`   ⚠️  WARNING: Detection mismatch`)
      if (!surfaceMatch) console.warn(`      Expected surface: ${testCase.expectedDetection.surface}`)
      if (!stainMatch) console.warn(`      Expected stain: ${testCase.expectedDetection.stain}`)
    }

    console.log(`   ✅ PASSED`)
    return true

  } catch (error) {
    console.error(`   ❌ FAILED: ${error.message}`)
    return false
  }
}

async function runTests() {
  console.log('🚀 Starting ai-vision-tips tests')
  console.log(`   Supabase URL: ${SUPABASE_URL}`)
  console.log(`   Test cases: ${testCases.length}`)

  let passed = 0
  let failed = 0

  for (const testCase of testCases) {
    const result = await testFunction(testCase)
    if (result) {
      passed++
    } else {
      failed++
    }

    // Wait between tests to avoid rate limiting
    await new Promise(resolve => setTimeout(resolve, 2000))
  }

  console.log('\n' + '='.repeat(50))
  console.log(`📊 Test Results:`)
  console.log(`   Total: ${testCases.length}`)
  console.log(`   ✅ Passed: ${passed}`)
  console.log(`   ❌ Failed: ${failed}`)
  console.log('='.repeat(50))

  if (failed > 0) {
    Deno.exit(1)
  }
}

// Run tests
if (import.meta.main) {
  runTests()
}
