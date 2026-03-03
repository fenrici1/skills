# Supabase Edge Functions for AI Apps — Reusable Skill

**Trigger:** `/supabase-ai-edge`
**Purpose:** Add AI-powered edge functions to any Supabase project. Handles the pattern of receiving data from the app, calling an AI API (OpenAI, Claude), and returning structured results.
**Built From:** LilSense v2 (8 edge functions in production), Command Center (chat-portfolio edge function with OpenAI).

---

## Overview

**What This Skill Does:**
1. Creates Supabase Edge Functions that call AI APIs (OpenAI GPT-4o Mini, Claude, etc.)
2. Handles authentication, rate limiting, and error handling
3. Returns structured JSON that the app can consume
4. Keeps AI API keys server-side (never in the app bundle)
5. Provides cost monitoring patterns

**Why Edge Functions for AI:**
- API keys stay on the server (not shipped in the app binary)
- Can add rate limiting, caching, and cost controls
- Can switch AI providers without app updates
- Can batch/queue requests for efficiency
- OTA-updatable logic (no App Store review for AI changes)

---

## How To Use This Skill

When invoked with `/supabase-ai-edge`, Claude should:

1. **Ask what AI task is needed:**
   - Text summarization
   - Structured data extraction (from OCR text, voice transcripts, etc.)
   - Classification/tagging
   - Conversational Q&A
   - Image analysis (via multimodal API)
2. **Determine the AI provider and model** (GPT-4o Mini recommended for cost)
3. **Create the edge function** following the patterns below
4. **Add environment variables** for API keys
5. **Test with curl** before app integration

---

## Edge Function Template: AI Processing

### Basic Structure

```typescript
// supabase/functions/[function-name]/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Authenticate the request
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    );
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 2. Parse the request body
    const { inputText, context } = await req.json();
    if (!inputText) {
      return new Response(JSON.stringify({ error: 'inputText is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 3. Call AI API
    const aiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('OPENAI_API_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: `You are a helpful assistant. Return JSON only.`
          },
          {
            role: 'user',
            content: inputText
          }
        ],
        response_format: { type: 'json_object' },
        temperature: 0.3,
        max_tokens: 500,
      }),
    });

    const aiData = await aiResponse.json();
    const result = JSON.parse(aiData.choices[0].message.content);

    // 4. Optionally store result in database
    // await supabase.from('results').insert({ user_id: user.id, result });

    // 5. Return structured response
    return new Response(JSON.stringify({ success: true, data: result }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    console.error('Edge function error:', error);
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
```

---

## Specific Templates

### Template A: Voice Transcript Summarizer

```typescript
// supabase/functions/summarize-transcript/index.ts
// Input: raw transcript text
// Output: { summary, actionItems[], tags[], keyPoints[] }

const systemPrompt = `You are a note-taking assistant. Given a voice transcript, extract:
1. "summary": A 2-3 sentence summary of the main content
2. "actionItems": Array of action items mentioned (empty array if none)
3. "tags": Array of 1-3 topic tags
4. "keyPoints": Array of key points (max 5)

Return valid JSON only. Be concise.`;
```

### Template B: Document Data Extractor

```typescript
// supabase/functions/extract-document/index.ts
// Input: OCR text from scanned document + document type hint
// Output: structured data based on document type

const systemPrompts = {
  receipt: `Extract from this receipt: { merchant, date, items: [{name, price}], subtotal, tax, total, paymentMethod }`,
  business_card: `Extract: { name, title, company, email, phone, address, website }`,
  form: `Extract all labeled fields as key-value pairs: { fields: [{label, value}] }`,
  note: `Convert to structured text: { title, body, lists: [{items}] }`,
};
```

### Template C: Plant Identifier & Advisor

```typescript
// supabase/functions/identify-plant/index.ts
// Input: base64 image OR description of plant/symptoms
// Output: { species, commonName, careInstructions, diagnosis?, recommendations[] }

// Note: For image input, use GPT-4o (not mini) with vision capability
// Cost: ~$0.003 per image analysis
```

---

## Deployment & Environment

### Setting Secrets

```bash
# Set API keys (one-time per project)
supabase secrets set OPENAI_API_KEY=sk-...

# For Claude API instead:
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
```

### Deploying

```bash
# Deploy a specific function
supabase functions deploy [function-name]

# Deploy with no JWT verification (for public endpoints)
supabase functions deploy [function-name] --no-verify-jwt

# Deploy all functions
supabase functions deploy
```

### Testing with curl

```bash
curl -X POST 'https://[project-ref].supabase.co/functions/v1/[function-name]' \
  -H 'Authorization: Bearer [user-jwt-token]' \
  -H 'Content-Type: application/json' \
  -d '{"inputText": "Test input"}'
```

---

## Calling from React Native

```typescript
// src/services/ai.ts
import { supabase } from './supabase';

export async function summarizeTranscript(transcript: string) {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) throw new Error('Not authenticated');

  const response = await fetch(
    `${SUPABASE_URL}/functions/v1/summarize-transcript`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${session.access_token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ inputText: transcript }),
    }
  );

  if (!response.ok) throw new Error('Summarization failed');
  return response.json();
}
```

---

## Cost Control Patterns

### Rate Limiting (per user)

```typescript
// Check user's usage before calling AI
const { count } = await supabase
  .from('ai_usage')
  .select('*', { count: 'exact' })
  .eq('user_id', user.id)
  .gte('created_at', new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString());

const DAILY_LIMIT_FREE = 5;
const DAILY_LIMIT_PREMIUM = 100;

if (count >= (isPremium ? DAILY_LIMIT_PREMIUM : DAILY_LIMIT_FREE)) {
  return new Response(JSON.stringify({ error: 'Daily limit reached' }), { status: 429 });
}
```

### Token Usage Logging

```typescript
// After AI call, log usage for cost monitoring
const usage = aiData.usage;
await supabase.from('ai_usage').insert({
  user_id: user.id,
  function_name: 'summarize-transcript',
  input_tokens: usage.prompt_tokens,
  output_tokens: usage.completion_tokens,
  model: 'gpt-4o-mini',
  // Estimated cost
  cost_usd: (usage.prompt_tokens * 0.00000015) + (usage.completion_tokens * 0.0000006),
});
```

---

## Lessons Learned / Detours Avoided

### 1. Always Use --no-verify-jwt for Functions Called by Authenticated Users
**What Happened:** Edge function returned 401 even with valid session token.
**Fix:** The Supabase client already sends the JWT. The function validates it internally via `supabase.auth.getUser()`. Using `--no-verify-jwt` on deploy avoids the double-check at the gateway level. Validate auth inside the function instead.

### 2. CORS Headers Are Required on Every Response Path
**What Happened:** Function worked in curl but failed from the app with CORS error.
**Fix:** Include `corsHeaders` on success, error, AND the OPTIONS preflight response. Every single return path.

### 3. response_format: { type: 'json_object' } Prevents Parsing Errors
**What Happened:** GPT sometimes returned markdown-wrapped JSON or explanatory text around the JSON.
**Fix:** Use OpenAI's `response_format` parameter. Guarantees valid JSON output. Only available on GPT-4o and GPT-4o Mini.

### 4. Temperature 0.3 for Extraction, 0.7 for Creative
**What Happened:** Inconsistent extraction results at default temperature (1.0).
**Fix:** Use low temperature (0.1-0.3) for data extraction, summarization, and classification. Higher (0.7-0.9) only for creative/conversational tasks.

### 5. max_tokens Prevents Runaway Costs
**What Happened:** One edge case input produced a 4000-token response.
**Fix:** Always set `max_tokens` appropriate to your expected output size. Summarization rarely needs >500 tokens.
