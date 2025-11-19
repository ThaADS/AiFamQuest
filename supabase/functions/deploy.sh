#!/bin/bash

# FamQuest Supabase Edge Functions Deployment Script
# Usage: ./deploy.sh [function-name]

set -e

echo "🚀 FamQuest Edge Functions Deployment"
echo "======================================"

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Install with: npm install -g supabase"
    exit 1
fi

# Check if logged in
if ! supabase projects list &> /dev/null; then
    echo "🔐 Please login to Supabase first:"
    supabase login
fi

# Link to project if not already linked
if [ ! -f "../../.supabase/config.toml" ]; then
    echo "🔗 Linking to Supabase project..."
    supabase link --project-ref vtjtmaajygckpguzceuc
fi

# Deploy function
if [ -z "$1" ]; then
    # Deploy all functions
    echo "📦 Deploying all functions..."
    supabase functions deploy ai-task-planner
else
    # Deploy specific function
    echo "📦 Deploying $1..."
    supabase functions deploy "$1"
fi

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Next steps:"
echo "1. Set secrets: supabase secrets set GEMINI_API_KEY=YOUR_KEY"
echo "2. Test function: curl -X POST https://vtjtmaajygckpguzceuc.supabase.co/functions/v1/ai-task-planner ..."
echo "3. Monitor logs: supabase functions logs ai-task-planner --follow"
