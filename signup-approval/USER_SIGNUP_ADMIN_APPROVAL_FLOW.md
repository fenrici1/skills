# User Signup with Admin Approval Flow

This document describes the implementation of a user registration system where users can sign up, but require administrator approval before accessing the application.

## Overview

**Flow Summary:**
1. User visits signup page and creates account
2. Account is created with `status: 'pending'`
3. User is shown a "Pending Approval" page
4. Admin sees pending users in dashboard and can Approve or Reject
5. On approval, user receives email notification and can log in
6. On rejection, user is deleted from the system

**Why This Pattern?**
- Better than invite-only: No email delivery issues with magic links expiring
- Security: Only approved users access the system
- Flexibility: Anyone can request access, admins control who gets in

---

## Lessons Learned / Detours Avoided

This section documents the debugging journey and key insights. Read this first to avoid repeating the same mistakes.

### 1. The 404 Mystery: RLS is the Silent Killer

**What Happened:**
- Admin endpoints returned 404 "User not found" even though users existed in the database
- Added debug logs confirming the route WAS being reached
- The route file existed, Next.js was routing correctly

**Root Cause:**
Supabase Row Level Security (RLS) was silently blocking queries. When RLS blocks a query, it returns an empty result - not an error. So `SELECT * FROM profiles WHERE id = 'xxx'` returns nothing, and the code interprets this as "user not found."

**The Fix:**
Use admin client (service role key) for ALL profile operations in admin endpoints:
```typescript
// This bypasses RLS completely
const adminClient = createClient(url, SERVICE_ROLE_KEY);
const { data } = await adminClient.from('profiles').select('*').eq('id', id);
```

**Key Insight:**
When debugging Supabase issues, always ask: "Could RLS be blocking this?" Empty results with no errors = RLS is probably the culprit.

### 2. Inconsistent Admin Client Usage = Subtle Bugs

**What Happened:**
- PATCH endpoint worked sometimes, failed other times
- DELETE endpoint had same 404 issue
- Code review revealed inconsistent patterns

**Root Cause:**
Some parts of the code used the regular Supabase client, others used admin client. The regular client is subject to RLS, so:
- Checking if current user is admin: Blocked by RLS → "Admin access required"
- Looking up target user: Blocked by RLS → "User not found"

**The Fix:**
Establish a consistent pattern - in admin endpoints, create admin client ONCE at the top and use it for ALL profile operations:
```typescript
// Create admin client early
const adminClient = createAdminClient(url, serviceRoleKey, options);

// Use it for ALL profile queries
const { data: currentProfile } = await adminClient.from('profiles')...
const { data: targetUser } = await adminClient.from('profiles')...
const { error } = await adminClient.from('profiles').update(...)...
```

### 3. Client-Side Profile Creation Fails Silently

**What Happened:**
- User signed up successfully (auth user created)
- User didn't appear in admin list
- No errors shown to user

**Root Cause:**
The signup page tried to create a profile using the client-side Supabase client. RLS blocked the insert because:
- User just signed up, barely authenticated
- RLS policies didn't allow users to insert their own profiles
- The insert failed silently

**The Fix:**
Move profile creation to a server-side API endpoint:
```typescript
// /api/auth/signup-profile/route.ts
const adminClient = createClient(url, SERVICE_ROLE_KEY);
await adminClient.from('profiles').insert({...});
```

**Key Insight:**
Any operation that creates data for a user who just authenticated should probably be server-side with admin privileges.

### 4. Don't Forget Secondary Auth Flows

**What Happened:**
- Main login flow correctly checked profile status
- OAuth callback flow had a "code exchange" fallback path
- This fallback path didn't check profile status
- Potential security gap: users could bypass pending status via OAuth

**The Fix:**
Audit ALL authentication paths and ensure status checks are consistent:
- Direct login: Check status ✓
- OAuth callback (session exists): Check status ✓
- OAuth callback (hash tokens): Check status ✓
- OAuth callback (code exchange): Check status ← Was missing!

### 5. "Check Again" Button That Doesn't Check

**What Happened:**
- Pending approval page had a "Check Again" button
- Button just called `router.refresh()` - only reloads React components
- Didn't actually re-query the profile status

**The Fix:**
Make the button actually query the database:
```typescript
const checkStatus = async () => {
  const { data: profile } = await supabase
    .from('profiles')
    .select('status')
    .eq('id', user.id)
    .single();

  if (profile?.status === 'active') {
    router.push('/dashboard');
  }
};
```

### 6. Invite-Only Flow Problems (Why We Switched)

**Original Approach:** Admin sends invite email → User clicks link → Sets password

**Problems Encountered:**
- Magic links expired quickly (Supabase default is short)
- Email delivery inconsistent
- Users would try link hours later → expired
- Re-sending invites was cumbersome

**Better Approach:** Self-signup with admin approval
- No expiring links
- User creates account immediately
- Admin approves when ready
- More robust, fewer support issues

### Summary: The RLS Mental Model

When working with Supabase + RLS:

1. **Client-side code** = Subject to RLS policies
2. **Server-side with anon key** = Still subject to RLS
3. **Server-side with service role key** = Bypasses RLS completely

**Rule of Thumb:**
- User managing their OWN data → Client-side is fine (if RLS allows)
- Admin managing OTHER users' data → Must use service role key
- Creating data for brand new users → Must use service role key

---

## Database Schema

### Profiles Table

```sql
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT,
  role TEXT NOT NULL DEFAULT 'reviewer' CHECK (role IN ('admin', 'reviewer', 'finance', 'readonly')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('active', 'pending', 'suspended')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Status Values:**
- `pending` - Awaiting admin approval (default for new signups)
- `active` - Approved and can access the application
- `suspended` - Blocked from accessing the application

**Role Values:**
- `admin` - Full access, can manage users
- `reviewer` - Standard access (default for new signups)
- `finance` - Finance-specific access
- `readonly` - View-only access

---

## Row Level Security (RLS)

**Critical Issue:** Supabase RLS policies block profile queries from client-side code. New users can't create their own profiles because they're not authenticated yet.

**Solution:** Use server-side API routes with admin client (service role key) to bypass RLS.

```typescript
// Create admin client to bypass RLS
const { createClient: createAdminClient } = await import('@supabase/supabase-js');
const adminClient = createAdminClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
  { auth: { autoRefreshToken: false, persistSession: false } }
);

// Now queries bypass RLS
const { data } = await adminClient.from('profiles').select('*');
```

**When to Use Admin Client:**
- Creating profiles for new users (signup)
- Admin endpoints reading/updating any profile
- Any operation that needs to access profiles the current user can't see

---

## Implementation Files

### 1. Signup Page
**File:** `/app/(auth)/signup/page.tsx`

**Purpose:** User registration form that creates auth user + profile

**Key Points:**
- Uses Supabase Auth `signUp()` to create auth user
- Calls server API to create profile (bypasses RLS)
- Password validation with strength indicator
- Redirects to `/pending-approval` on success

```typescript
// Create auth user
const { data, error } = await supabase.auth.signUp({
  email,
  password,
  options: { data: { full_name: fullName } }
});

// Create profile via server API (bypasses RLS)
if (data.user) {
  await fetch('/api/auth/signup-profile', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      userId: data.user.id,
      email: email,
      fullName: fullName,
    }),
  });
}
```

### 2. Signup Profile API
**File:** `/app/api/auth/signup-profile/route.ts`

**Purpose:** Server-side profile creation that bypasses RLS

**Key Points:**
- Validates input with Zod
- Uses admin client (service role key)
- Creates profile with `status: 'pending'`, `role: 'reviewer'`

```typescript
const { error: profileError } = await adminClient
  .from('profiles')
  .insert({
    id: validated.userId,
    email: validated.email,
    full_name: validated.fullName,
    role: 'reviewer',
    status: 'pending',
  });
```

### 3. Pending Approval Page
**File:** `/app/(auth)/pending-approval/page.tsx`

**Purpose:** Waiting room for unapproved users

**Key Points:**
- Shows user's email
- "Check Again" button that queries profile status
- Auto-redirects to dashboard if status becomes 'active'
- Sign Out button to allow different account login

```typescript
const checkStatus = async () => {
  setChecking(true);
  const { data: { user } } = await supabase.auth.getUser();
  if (user) {
    const { data: profile } = await supabase
      .from('profiles')
      .select('status')
      .eq('id', user.id)
      .single();

    if (profile?.status === 'active') {
      router.push('/dashboard');
      return;
    }
  }
  setChecking(false);
};
```

### 4. Login Page
**File:** `/app/(auth)/login/page.tsx`

**Purpose:** Authentication with status check

**Key Points:**
- Standard email/password login
- After auth success, checks profile status
- Redirects based on status:
  - `pending` -> `/pending-approval`
  - `active` -> `/dashboard`
  - `suspended` -> Signs out, shows error

```typescript
// Check profile status
const { data: profile } = await supabase
  .from('profiles')
  .select('status')
  .eq('id', data.user.id)
  .single();

if (profile?.status === 'pending') {
  router.push('/pending-approval');
  return;
}

if (profile?.status === 'suspended') {
  setError('Your account has been suspended. Please contact an administrator.');
  await supabase.auth.signOut();
  return;
}
```

### 5. Auth Callback Page
**File:** `/app/auth/callback/page.tsx`

**Purpose:** Handle OAuth callbacks and magic links

**Key Points:**
- Processes hash parameters from Supabase auth URLs
- Checks profile status after all auth flows
- Handles invite flow (sets status to active, redirects to password setup)
- Handles password recovery flow

### 6. Admin Users API - List
**File:** `/app/api/admin/users/route.ts`

**Purpose:** List all users for admin dashboard

**Key Points:**
- Requires authenticated admin user
- Uses admin client to read all profiles
- Returns paginated list with email, status, role

### 7. Admin Users API - Update/Delete
**File:** `/app/api/admin/users/[id]/route.ts`

**Purpose:** Approve, reject, or modify users

**PATCH Endpoint (Approve/Update):**
- Validates request with Zod
- Uses admin client for ALL profile operations
- Prevents self-modification
- Sends approval email when status changes to 'active'
- Logs to audit_log table

```typescript
// Send approval email if user was just approved (pending -> active)
if (validated.status === 'active' && targetUser.status === 'pending') {
  await sendApprovalEmail({
    to: targetUser.email,
    userName: targetUser.full_name || targetUser.email.split('@')[0],
    loginUrl: `${process.env.NEXT_PUBLIC_APP_URL}/login`,
  });
}
```

**DELETE Endpoint (Reject):**
- Completely removes user from system
- Deletes from profiles table first (FK constraint)
- Deletes from Supabase Auth
- Logs to audit_log table

```typescript
// Delete profile first (due to foreign key constraints)
await adminClient.from('profiles').delete().eq('id', id);

// Delete from Supabase Auth
await adminClient.auth.admin.deleteUser(id);
```

### 8. Admin Users Dashboard
**File:** `/app/(dashboard)/dashboard/admin/users/page.tsx`

**Purpose:** UI for managing users

**Key Points:**
- Lists all users with status badges
- Quick "Approve" button for pending users
- "Reject" button that deletes pending users
- Dropdown menu with Edit/Delete for all users
- Optimistic UI updates after actions

### 9. Email Notification
**File:** `/lib/email/user-notification-email.ts`

**Purpose:** Send approval notification emails

**Key Points:**
- Uses Resend email service
- HTML and plain text versions
- Includes login URL button
- Gracefully handles missing API key

---

## Environment Variables

```env
# Required
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...  # Critical for admin operations

# Optional
RESEND_API_KEY=re_xxx  # For approval emails
NEXT_PUBLIC_APP_URL=https://app.example.com  # For email links
```

---

## Common Issues and Solutions

### 1. "User not found" / 404 on Admin Operations

**Symptom:** PATCH or DELETE returns 404 even though user exists

**Cause:** RLS blocking profile query

**Solution:** Use admin client for profile lookup

```typescript
// Wrong - RLS blocks this
const { data: profile } = await supabase
  .from('profiles')
  .select('*')
  .eq('id', targetId)
  .single();

// Correct - Admin client bypasses RLS
const { data: profile } = await adminClient
  .from('profiles')
  .select('*')
  .eq('id', targetId)
  .single();
```

### 2. "Admin access required" / 403 on Admin Operations

**Symptom:** Admin gets 403 when trying to manage users

**Cause:** Admin check query blocked by RLS

**Solution:** Use admin client to check if current user is admin

```typescript
// Check admin role using admin client
const { data: currentProfile } = await adminClient
  .from('profiles')
  .select('role')
  .eq('id', user.id)
  .single();

if (currentProfile?.role !== 'admin') {
  return NextResponse.json({ error: 'Admin access required' }, { status: 403 });
}
```

### 3. Signup Profile Not Created

**Symptom:** User signs up but doesn't appear in admin list

**Cause:** Client-side profile insert blocked by RLS

**Solution:** Create server-side API endpoint for profile creation

### 4. Approval Email Not Sending

**Symptom:** Users approved but no email received

**Check:**
1. `RESEND_API_KEY` environment variable set
2. Email domain verified in Resend dashboard
3. Check server logs for email errors

---

## Security Considerations

1. **Service Role Key:** Never expose in client-side code. Only use in API routes.

2. **Admin Check:** Always verify admin role before allowing user management operations.

3. **Self-Modification Prevention:** Admins cannot modify their own account to prevent lockouts.

4. **Audit Logging:** All user modifications are logged to `audit_log` table.

5. **Input Validation:** Use Zod schemas to validate all API inputs.

---

## Testing Checklist

- [ ] User can sign up with email/password
- [ ] New user status is 'pending'
- [ ] Pending user redirected to pending-approval page
- [ ] Pending user cannot access dashboard
- [ ] Admin can see pending users in admin dashboard
- [ ] Admin can approve pending user
- [ ] Approved user receives email notification
- [ ] Approved user can log in and access dashboard
- [ ] Admin can reject (delete) pending user
- [ ] Rejected user removed from system
- [ ] Admin cannot modify their own account
- [ ] Suspended user signed out and cannot log in

---

## Adapting for Other Apps

1. **Copy these files:**
   - `/app/(auth)/signup/page.tsx`
   - `/app/(auth)/pending-approval/page.tsx`
   - `/app/api/auth/signup-profile/route.ts`
   - `/app/api/admin/users/route.ts`
   - `/app/api/admin/users/[id]/route.ts`
   - `/lib/email/user-notification-email.ts`

2. **Database setup:**
   - Create profiles table with status field
   - Set up appropriate RLS policies

3. **Environment variables:**
   - Set `SUPABASE_SERVICE_ROLE_KEY`
   - Set `RESEND_API_KEY` for notifications
   - Set `NEXT_PUBLIC_APP_URL` for email links

4. **Customize:**
   - Update branding in email templates
   - Adjust roles to match your app's needs
   - Add/remove profile fields as needed

---

## File Structure

```
apps/web/
├── app/
│   ├── (auth)/
│   │   ├── login/page.tsx          # Login with status check
│   │   ├── signup/page.tsx         # User registration
│   │   └── pending-approval/page.tsx # Waiting room
│   ├── (dashboard)/
│   │   └── dashboard/
│   │       └── admin/
│   │           └── users/page.tsx  # Admin user management
│   ├── api/
│   │   ├── auth/
│   │   │   └── signup-profile/route.ts  # Profile creation API
│   │   └── admin/
│   │       └── users/
│   │           ├── route.ts        # List users
│   │           └── [id]/route.ts   # Update/Delete user
│   └── auth/
│       └── callback/page.tsx       # OAuth callback handler
├── lib/
│   ├── email/
│   │   └── user-notification-email.ts  # Approval emails
│   └── supabase/
│       ├── client.ts               # Browser client
│       └── server.ts               # Server client
└── docs/
    └── USER_SIGNUP_ADMIN_APPROVAL_FLOW.md  # This doc
```
