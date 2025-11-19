# Supabase Edge Functions - FamQuest

This directory contains Supabase Edge Functions for AI-powered features.

## Functions

### ai-vision-tips

**Purpose**: Analyzes photos of stains/messes using Gemini Vision API and provides cleaning guidance.

**Endpoint**: `POST /functions/v1/ai-vision-tips`

**Request Body**:
```json
{
  "image_url": "https://supabase-storage-url/photo.jpg",
  "context": {
    "room": "kitchen",
    "surface": "marble",
    "userInput": "Red wine stain"
  }
}
```

**Response**:
```json
{
  "success": true,
  "analysis": {
    "detected": {
      "surface": "marble",
      "stain": "red_wine",
      "confidence": 0.87
    },
    "steps": [
      "Blot immediately with paper towel (don't rub)",
      "Mix baking soda with water to create a paste",
      "Apply paste to stain and let sit for 10 minutes",
      "Wipe with damp microfiber cloth",
      "Dry thoroughly with clean towel"
    ],
    "products": {
      "recommended": ["Baking soda", "White vinegar (diluted)"],
      "avoid": ["Bleach", "Acidic cleaners (lemon juice)"]
    },
    "warnings": [
      "Marble is porous - act quickly",
      "Test any cleaner on hidden area first"
    ],
    "estimatedMinutes": 15,
    "difficulty": 2
  },
  "metadata": {
    "model": "gemini-2.5-flash-latest",
    "timestamp": "2025-11-13T16:30:00Z"
  }
}
```

## Deployment

### Prerequisites

1. **Supabase CLI** installed:
```bash
npm install -g supabase
```

2. **Gemini API Key** from Google AI Studio:
   - Visit https://makersuite.google.com/app/apikey
   - Create API key
   - Add to Supabase secrets

### Deploy Function

```bash
# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref your-project-ref

# Set Gemini API key as secret
supabase secrets set GEMINI_API_KEY=your-api-key-here

# Deploy the function
supabase functions deploy ai-vision-tips
```

### Local Testing

```bash
# Start local Supabase
supabase start

# Set environment variable
export GEMINI_API_KEY=your-api-key-here

# Serve function locally
supabase functions serve ai-vision-tips --env-file .env.local
```

### Test Request

```bash
curl -X POST 'http://localhost:54321/functions/v1/ai-vision-tips' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer YOUR_SUPABASE_ANON_KEY' \
  -d '{
    "image_url": "https://your-storage-url/photo.jpg",
    "context": {
      "room": "kitchen",
      "surface": "countertop",
      "userInput": "Coffee stain"
    }
  }'
```

## Environment Variables

Required secrets in Supabase dashboard:

- `GEMINI_API_KEY` - Google Gemini API key

## Cost Estimation

**Gemini 2.5 Flash Pricing**:
- Input: $0.075 per 1M tokens (~$0.0000075 per image analysis)
- Output: $0.30 per 1M tokens (~$0.0003 per response)
- **Estimated cost per request**: ~$0.003

**Expected Usage**:
- 5,000 photos/month = $15/month
- 10,000 photos/month = $30/month

**Optimization**:
- Results cached in task metadata (no repeat analysis)
- Photo compression reduces processing time
- Fast model (gemini-2.5-flash) for cost efficiency

## Security

- Image URLs must be from Supabase Storage (same project)
- Authentication required via Supabase JWT
- Rate limiting: 10 requests/minute per user (Supabase default)
- Safe content filtering enabled in Gemini API

## Monitoring

View function logs:
```bash
supabase functions logs ai-vision-tips
```

Check invocations in Supabase Dashboard:
- Project → Edge Functions → ai-vision-tips → Logs

## Troubleshooting

### Error: "GEMINI_API_KEY environment variable is not set"
**Solution**: Deploy secret using `supabase secrets set GEMINI_API_KEY=...`

### Error: "Failed to download image"
**Solution**: Ensure image URL is publicly accessible or includes signed URL from Supabase Storage

### Error: "Gemini API error: 429"
**Solution**: Rate limit exceeded. Implement client-side throttling or upgrade Gemini API quota

### Error: "Failed to parse JSON response"
**Solution**: Gemini returned non-JSON. Check prompt formatting and response handling.

## Development

### Run Tests
```bash
deno test --allow-net --allow-env
```

### Format Code
```bash
deno fmt index.ts
```

### Lint Code
```bash
deno lint index.ts
```

## References

- [Supabase Edge Functions Docs](https://supabase.com/docs/guides/functions)
- [Gemini API Docs](https://ai.google.dev/docs)
- [FamQuest PRD](../../AI_Gezinsplanner_PRD_v2.1.md)
