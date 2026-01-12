# 6-Digit Email Verification Code Flow

This document describes the implementation of a 6-digit code email verification system for user signup, using Supabase. This replaces magic links with a user-friendly code entry experience.

## Overview

**Flow Summary:**
1. User enters email and password on signup page
2. Supabase creates auth user, trigger generates 6-digit code
3. Supabase sends email with the code (via email template)
4. User enters code on verification screen
5. RPC function validates code and confirms email
6. App signs user in with email/password
7. User proceeds to onboarding

**Why This Pattern?**
- Better UX: Users don't leave the app to click magic links
- Mobile-friendly: No context switching between email app and your app
- Familiar: Users expect 6-digit codes (like 2FA)
- Reliable: No expiring magic links that break

---

## Lessons Learned / Critical Insights

### 1. Supabase Doesn't Give Session Until Email Confirmed

**The Problem:**
After implementing the 6-digit code flow, users were stuck on "Setting up your account..." spinner after verification.

**Root Cause:**
When Supabase's "Confirm email" setting is enabled, `signUp()` does NOT return a session. The user exists in `auth.users`, but there's no session until email is confirmed.

Our custom RPC function (`verify_code_and_confirm_email`) correctly set `email_confirmed_at` in the database, but there was still no session to refresh.

**The Fix:**
After code verification, **sign the user in** with email/password instead of trying to refresh a non-existent session.

```typescript
// After code verification succeeds:
const { error: signInError } = await supabase.auth.signInWithPassword({
  email: userEmail,
  password: userPassword,
});
```

**This requires passing the password from signup to verify-email:**
```typescript
// In signup.tsx
router.push({
  pathname: '/(auth)/verify-email',
  params: {
    email: email.trim().toLowerCase(),
    pwd: password, // Needed to sign in after verification
  },
});
```

### 2. User Profile Creation Race Condition

**The Problem:**
Even after fixing the session issue, some users got stuck because the `users` table profile didn't exist.

**Root Cause:**
Database triggers that should create user profiles sometimes fail silently. If the profile doesn't exist, the app waits forever.

**The Fix:**
Make `fetchUserProfile` in AuthContext create the profile if it doesn't exist:

```typescript
const fetchUserProfile = async (userId: string, email?: string) => {
  const { data, error } = await supabase
    .from('users')
    .select('*')
    .eq('id', userId)
    .single();

  if (data) return data;

  // If no rows found (PGRST116), create the profile
  if (error?.code === 'PGRST116') {
    const { data: newUser } = await supabase
      .from('users')
      .insert({
        id: userId,
        email: email || '',
        // ... other default fields
      })
      .select()
      .single();
    return newUser;
  }

  return null;
};
```

### 3. Email Template Configuration

**The Problem:**
The 6-digit code needs to appear in the verification email, but Supabase's default email template doesn't include it.

**The Solution:**
The trigger stores the code in `raw_user_meta_data`. In Supabase email templates, use:
```
Your verification code is: {{ .Data.verification_code }}
```

**Important:** Use `.Data` not `.UserMetaData` in Supabase email templates.

### 4. Debugging Strategy That Works

When the flow doesn't work:
1. **Add console logs at each step** - session before, RPC result, session after
2. **Check the console output** - the logs will tell you exactly where it fails
3. **Don't guess** - the issue is always in the data, not where you think

---

## Database Schema

### Email Verification Codes Table

```sql
CREATE TABLE IF NOT EXISTS public.email_verification_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  code TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  verified BOOLEAN DEFAULT FALSE,
  verified_at TIMESTAMPTZ,
  attempts INTEGER DEFAULT 0,
  email_sent BOOLEAN DEFAULT FALSE,
  email_sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_verification_email_code ON public.email_verification_codes(email, code) WHERE verified = FALSE;
CREATE INDEX idx_verification_expires ON public.email_verification_codes(expires_at) WHERE verified = FALSE;
CREATE INDEX idx_verification_user_id ON public.email_verification_codes(user_id);
```

### Users Table (Your App's Profile Table)

```sql
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  -- Add your app-specific fields here
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## Database Functions (RPC)

### 1. Trigger: Generate Code on Signup

```sql
CREATE OR REPLACE FUNCTION public.handle_new_user_verification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_code TEXT;
  v_expires_at TIMESTAMPTZ;
BEGIN
  IF NEW.email_confirmed_at IS NULL THEN
    v_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
    v_expires_at := NOW() + INTERVAL '15 minutes';

    INSERT INTO public.email_verification_codes (
      email, code, user_id, expires_at, email_sent
    ) VALUES (
      NEW.email, v_code, NEW.id, v_expires_at, TRUE
    );

    -- Store code in user metadata for email template
    UPDATE auth.users
    SET raw_user_meta_data =
      COALESCE(raw_user_meta_data, '{}'::jsonb) ||
      jsonb_build_object(
        'verification_code', v_code,
        'verification_expires', v_expires_at
      )
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created_verification
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user_verification();
```

### 2. Verify Code and Confirm Email

```sql
CREATE OR REPLACE FUNCTION public.verify_code_and_confirm_email(
  p_email TEXT,
  p_code TEXT
)
RETURNS TABLE(success BOOLEAN, message TEXT, user_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_record RECORD;
  v_user_id UUID;
BEGIN
  -- Find valid code
  SELECT * INTO v_record
  FROM public.email_verification_codes
  WHERE email = p_email
    AND code = p_code
    AND verified = FALSE
    AND expires_at > NOW()
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_record IS NULL THEN
    -- Check for expired code
    SELECT * INTO v_record
    FROM public.email_verification_codes
    WHERE email = p_email AND code = p_code AND verified = FALSE
    ORDER BY created_at DESC LIMIT 1;

    IF v_record IS NOT NULL THEN
      UPDATE public.email_verification_codes
      SET attempts = attempts + 1 WHERE id = v_record.id;
      RETURN QUERY SELECT FALSE, 'Code has expired. Please request a new one.'::TEXT, NULL::UUID;
    ELSE
      RETURN QUERY SELECT FALSE, 'Invalid verification code.'::TEXT, NULL::UUID;
    END IF;
    RETURN;
  END IF;

  IF v_record.attempts >= 5 THEN
    RETURN QUERY SELECT FALSE, 'Too many attempts. Please request a new code.'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  -- Mark code as verified
  UPDATE public.email_verification_codes
  SET verified = TRUE, verified_at = NOW()
  WHERE id = v_record.id;

  -- Confirm email in auth.users
  IF v_record.user_id IS NOT NULL THEN
    UPDATE auth.users
    SET email_confirmed_at = NOW(),
        raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb)
          - 'verification_code' - 'verification_expires'
    WHERE id = v_record.user_id;
    v_user_id := v_record.user_id;
  END IF;

  RETURN QUERY SELECT TRUE, 'Email verified successfully!'::TEXT, v_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_code_and_confirm_email TO anon, authenticated;
```

### 3. Resend Verification Code

```sql
CREATE OR REPLACE FUNCTION public.resend_verification_code(p_email TEXT)
RETURNS TABLE(success BOOLEAN, message TEXT, code TEXT, expires_at TIMESTAMPTZ)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_code TEXT;
  v_expires_at TIMESTAMPTZ;
  v_user_id UUID;
BEGIN
  SELECT id INTO v_user_id FROM auth.users
  WHERE email = p_email AND email_confirmed_at IS NULL;

  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'User not found or already verified'::TEXT, NULL::TEXT, NULL::TIMESTAMPTZ;
    RETURN;
  END IF;

  -- Invalidate old codes
  UPDATE public.email_verification_codes
  SET verified = TRUE WHERE email = p_email AND verified = FALSE;

  -- Generate new code
  v_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
  v_expires_at := NOW() + INTERVAL '15 minutes';

  INSERT INTO public.email_verification_codes (email, code, user_id, expires_at)
  VALUES (p_email, v_code, v_user_id, v_expires_at);

  -- Update user metadata
  UPDATE auth.users
  SET raw_user_meta_data =
    COALESCE(raw_user_meta_data, '{}'::jsonb) ||
    jsonb_build_object('verification_code', v_code, 'verification_expires', v_expires_at)
  WHERE id = v_user_id;

  RETURN QUERY SELECT TRUE, 'New verification code generated'::TEXT, v_code, v_expires_at;
END;
$$;

GRANT EXECUTE ON FUNCTION public.resend_verification_code TO anon, authenticated;
```

---

## Implementation Files

### 1. Signup Page

**Key Points:**
- Standard email/password signup form
- Calls `supabase.auth.signUp()`
- Passes email AND password to verify-email page

```typescript
// app/(auth)/signup.tsx
const handleSignUp = async () => {
  const { error } = await supabase.auth.signUp({
    email: email.trim().toLowerCase(),
    password,
  });

  if (error) {
    setError(error.message);
    return;
  }

  // Pass password for post-verification sign-in
  router.push({
    pathname: '/(auth)/verify-email',
    params: {
      email: email.trim().toLowerCase(),
      pwd: password,
    },
  });
};
```

### 2. Verify Email Page

**Key Points:**
- 6 individual digit inputs with auto-focus
- Auto-submits when all 6 digits entered
- Signs user in after verification (not refresh!)
- Resend code functionality

```typescript
// app/(auth)/verify-email.tsx
const userEmail = params.email as string;
const userPassword = params.pwd as string;

const handleVerifyCode = async (codeString: string) => {
  // Call RPC to verify code
  const { data, error } = await supabase.rpc('verify_code_and_confirm_email', {
    p_email: userEmail,
    p_code: codeString,
  });

  if (error || !data?.[0]?.success) {
    setError(data?.[0]?.message || 'Invalid code');
    return;
  }

  // CRITICAL: Sign in the user (Supabase doesn't give session until confirmed)
  if (!userPassword) {
    router.replace('/(auth)/login');
    return;
  }

  const { error: signInError } = await supabase.auth.signInWithPassword({
    email: userEmail,
    password: userPassword,
  });

  if (signInError) {
    setError('Verification successful! Please sign in.');
    router.replace('/(auth)/login');
    return;
  }

  router.replace('/(onboarding)/add-baby'); // Or your post-signup destination
};
```

### 3. AuthContext

**Key Points:**
- Listens for auth state changes
- Fetches or creates user profile
- Creates profile if missing (PGRST116 error)

```typescript
// src/context/AuthContext.tsx
const fetchUserProfile = useCallback(async (userId: string, email?: string) => {
  const { data, error } = await supabase
    .from('users')
    .select('*')
    .eq('id', userId)
    .single();

  if (data) return data;

  // Create profile if not found
  if (error?.code === 'PGRST116') {
    const { data: newUser } = await supabase
      .from('users')
      .insert({ id: userId, email: email || '' })
      .select()
      .single();
    return newUser;
  }

  return null;
}, []);
```

---

## Supabase Email Template

In Supabase Dashboard → Authentication → Email Templates → Confirm signup:

```html
<h2>Confirm your email</h2>
<p>Your verification code is:</p>
<h1 style="font-size: 32px; letter-spacing: 8px;">{{ .Data.verification_code }}</h1>
<p>This code expires in 15 minutes.</p>
```

**Important:** Use `{{ .Data.verification_code }}` not `{{ .UserMetaData.verification_code }}`

---

## Common Issues and Solutions

### 1. Stuck on "Setting up account..." spinner

**Cause:** No session after verification
**Solution:** Sign in with email/password after code verification

### 2. Code verified but user can't proceed

**Cause:** User profile not created
**Solution:** AuthContext should create profile if PGRST116 error

### 3. "Invalid code" even with correct code

**Cause:** Code expired or too many attempts
**Solution:** Request new code, check database for attempt count

### 4. Email doesn't contain the code

**Cause:** Wrong template variable
**Solution:** Use `{{ .Data.verification_code }}` in email template

### 5. Resend code says "User not found"

**Cause:** User already verified, or wrong email
**Solution:** Check `email_confirmed_at` is NULL in auth.users

---

## Testing Checklist

- [ ] User can sign up with email/password
- [ ] User receives email with 6-digit code
- [ ] User can enter code (auto-advances on each digit)
- [ ] Correct code → user signed in → proceeds to next screen
- [ ] Wrong code → error message, can retry
- [ ] Expired code → error message, prompt to resend
- [ ] Resend code works and invalidates old code
- [ ] 5 failed attempts → locked out, must resend
- [ ] User profile created successfully
- [ ] Session persists after app restart

---

## File Structure

```
app/
├── (auth)/
│   ├── signup.tsx           # Signup form, passes password to verify
│   ├── verify-email.tsx     # 6-digit code entry, signs in after verify
│   └── login.tsx            # Standard login
├── (onboarding)/
│   └── ...                  # Post-signup screens
src/
├── context/
│   └── AuthContext.tsx      # Auth state, profile fetch/create
├── lib/
│   └── supabase.ts          # Supabase client config
supabase/
└── migrations/
    ├── xxx_email_verification_codes.sql
    └── xxx_supabase_native_email_verification.sql
```

---

## Adapting for Other Apps

1. **Copy migration files** - The SQL creates the table and functions

2. **Update email template** in Supabase Dashboard

3. **Update signup page** to pass password to verify-email

4. **Update verify-email page** to sign in after verification

5. **Update AuthContext** to create profile if missing

6. **Customize:**
   - Code expiry time (default 15 minutes)
   - Max attempts (default 5)
   - Post-verification destination
   - Profile fields

---

## Security Considerations

1. **Password in URL params:** Safe on native apps (not exposed in browser history). If concerned, use React Context or secure storage.

2. **Rate limiting:** The RPC functions have attempt limits (5 max)

3. **Code expiry:** 15 minutes default, adjust as needed

4. **SECURITY DEFINER:** RPC functions run with elevated privileges - they can update auth.users

5. **Clean up expired codes:** Run `cleanup_expired_verification_codes()` periodically

---

## Reference Implementation

**Source:** LilSense App (`/Users/mxz-ai-2025/Projects/lilsense-app`)

**Key commits:**
- `cdc6cbc` - Fix post-verification auth: sign in user after email code verification

**Files to reference:**
- `app/(auth)/signup.tsx`
- `app/(auth)/verify-email.tsx`
- `src/context/AuthContext.tsx`
- `supabase/migrations/012_email_verification_codes.sql`
- `supabase/migrations/013_supabase_native_email_verification.sql`
