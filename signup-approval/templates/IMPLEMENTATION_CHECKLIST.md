# Signup with Admin Approval - Implementation Checklist

Use this checklist when implementing the signup + admin approval flow in a new app.

## Pre-requisites

- [ ] Supabase project set up
- [ ] Next.js App Router project
- [ ] Supabase client configured (`/lib/supabase/client.ts` and `/lib/supabase/server.ts`)
- [ ] Environment variables ready

## Environment Variables

```env
# Required
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...  # CRITICAL - needed for admin operations

# Optional but recommended
RESEND_API_KEY=re_xxx              # For approval notification emails
NEXT_PUBLIC_APP_URL=https://...    # For email links (defaults to localhost:3000)
```

## Database Setup

- [ ] **Profiles table** with status and role columns:
```sql
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('admin', 'user', 'readonly')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('active', 'pending', 'suspended')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

- [ ] **RLS policies** (remember: these will block admin operations from client-side)
- [ ] **First admin user** created manually with `status: 'active'`, `role: 'admin'`

## File Implementation

### Phase 1: Signup Flow

- [ ] **`/app/(auth)/signup/page.tsx`**
  - Registration form with email, password, name
  - Password strength indicator
  - Calls signup-profile API after auth signup
  - Shows success message directing to pending approval

- [ ] **`/app/api/auth/signup-profile/route.ts`**
  - Uses admin client (service role key) to bypass RLS
  - Creates profile with `status: 'pending'`
  - Validates input with Zod

### Phase 2: Pending State Handling

- [ ] **`/app/(auth)/pending-approval/page.tsx`**
  - Shows waiting message
  - "Check Again" button that ACTUALLY queries database
  - Auto-redirects if status becomes 'active'
  - Sign out option

- [ ] **`/app/(auth)/login/page.tsx`** - Add status check:
  - After successful auth, check profile status
  - `pending` → redirect to `/pending-approval`
  - `suspended` → sign out, show error
  - `active` → proceed to dashboard

- [ ] **`/app/auth/callback/page.tsx`** (if using OAuth) - Add status check:
  - Check ALL auth paths (session exists, hash tokens, code exchange)
  - Same redirects as login page

### Phase 3: Admin Management

- [ ] **`/app/api/admin/users/route.ts`**
  - GET endpoint to list all users
  - Uses admin client for profile queries
  - Verifies requester is admin

- [ ] **`/app/api/admin/users/[id]/route.ts`**
  - PATCH endpoint for status/role updates
  - DELETE endpoint for user removal
  - Uses admin client for ALL profile operations
  - Prevents self-modification
  - Sends approval email on pending → active

- [ ] **Admin UI page** (e.g., `/app/(dashboard)/dashboard/admin/users/page.tsx`)
  - Lists users with status badges
  - Quick Approve/Reject buttons for pending users
  - Role and status editing for all users

### Phase 4: Notifications (Optional but Recommended)

- [ ] **`/lib/email/user-notification-email.ts`**
  - Approval email template (HTML + text)
  - Uses Resend (or your email service)
  - Graceful fallback if not configured

## Common Gotchas Checklist

- [ ] **Admin client usage**: ALL profile queries in admin endpoints use service role key
- [ ] **Self-modification prevention**: Admin cannot modify their own account
- [ ] **Status check in all auth flows**: Login, OAuth callback (all paths), auth callback
- [ ] **"Check Again" actually checks**: Don't just use router.refresh()
- [ ] **Profile creation server-side**: Client-side insert will fail due to RLS

## Testing Checklist

- [ ] New user can sign up
- [ ] New user sees pending approval page
- [ ] Pending user cannot access dashboard (redirected)
- [ ] Pending user's "Check Again" works
- [ ] Admin sees pending users in admin dashboard
- [ ] Admin can approve user
- [ ] Approved user receives email (if configured)
- [ ] Approved user can log in
- [ ] Admin can reject (delete) user
- [ ] Rejected user is completely removed
- [ ] Admin cannot modify their own account
- [ ] Suspended user is signed out and blocked

## Quick Reference: When to Use Admin Client

| Operation | Client to Use |
|-----------|--------------|
| User reading own profile | Regular client (if RLS allows) |
| Admin reading any profile | Admin client |
| Admin updating any profile | Admin client |
| Creating profile for new user | Admin client |
| Checking if current user is admin | Admin client |

## Template Files Reference

All templates are in `/docs/templates/signup-approval/`:

- `signup-page.tsx.template` - User registration
- `signup-profile-api.ts.template` - Server-side profile creation
- `pending-approval-page.tsx.template` - Waiting room
- `admin-users-api.ts.template` - List users endpoint
- `admin-users-id-api.ts.template` - Update/delete user endpoints
- `approval-email.ts.template` - Notification email

## Full Documentation

See `USER_SIGNUP_ADMIN_APPROVAL_FLOW.md` for:
- Detailed explanations
- Code examples
- Lessons learned / debugging insights
- Security considerations
