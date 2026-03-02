---
title: Complete Authentication System Skill
version: 1.0
source_project: recovery-edge-app
created: 2026-01-23
---

# Complete Authentication System Skill

A comprehensive, production-ready authentication system built with React + Supabase, featuring multi-step signup, extended sessions, password reset, account claiming, IP tracking, and robust session management.

## Overview

This skill provides a complete authentication solution that can be adapted for any React + Supabase application. It includes:

- **Login** with remembered email, extended sessions (30-day "keep me signed in")
- **Signup** with multi-step flow, email validation, team selection, terms acceptance
- **Password Reset** via email link
- **Account Claiming** for pre-created roster/team member accounts
- **Session Management** with auto-refresh, tab focus validation, proactive validation
- **IP & Device Tracking** for security and login history
- **Legal Modals** for Privacy Policy and Terms of Service
- **Auth Resolver** for handling different ID relationships (direct auth users vs. roster athletes)

---

## Architecture Overview

```
src/
├── components/
│   └── auth/
│       ├── AuthContainer.js      # Toggle between Login/SignUp
│       ├── Login.js              # Login form with all features
│       ├── SignUpImproved.js     # Multi-step signup
│       ├── ResetPassword.js      # Password reset page
│       └── ClaimAccount.js       # Roster athlete account claiming
│   └── legal/
│       ├── PrivacyPolicy.js      # Privacy policy modal
│       └── TermsOfService.js     # Terms of service modal
├── utils/
│   ├── sessionManager.js         # Extended session & auto-refresh
│   ├── authResolver.js           # ID mapping for roster athletes
│   ├── ipAddress.js              # IP & device info capture
│   └── sentryLogger.js           # Security event logging
└── lib/
    └── supabase.js               # Supabase client initialization
```

---

## Component Details

### 1. AuthContainer.js

**Purpose:** Simple wrapper that toggles between Login and SignUp modes.

**Key Features:**
- State management for `isLogin` toggle
- Passes `onSwitch` callback to child components
- Passes `onSuccess` callback for post-auth actions

**Usage:**
```jsx
<AuthContainer onSuccess={() => handleAuthSuccess()} />
```

---

### 2. Login.js

**Purpose:** Full-featured login form with enterprise-grade features.

**Key Features:**

| Feature | Description |
|---------|-------------|
| Remembered Email | Stores last successful login email in localStorage |
| Extended Sessions | 30-day "Keep me signed in" option |
| Forgot Password | Inline mode switch to reset flow |
| Password Visibility Toggle | Eye icon to show/hide password |
| IP & Device Tracking | Captures location and browser info |
| Login History Logging | Records all login attempts (success/failure) via RPC |
| Sentry Integration | Security logging for failed attempts |

**State Variables:**
- `email`, `password` - Form inputs
- `loading`, `error` - UI states
- `showPassword` - Password visibility toggle
- `forgotPasswordMode`, `resetEmailSent` - Password reset flow
- `rememberMe` - Extended session checkbox
- `rememberedEmail` - Stored email from previous login

**LocalStorage Keys:**
- `recoveryedge_remembered_email` - Last login email
- `recoveryedge_extended_session` - Boolean for extended session
- `recoveryedge_session_expiry` - ISO date of session expiry

**Flow:**
1. Load remembered email on mount
2. User enters credentials
3. Get IP address and device info (async)
4. Attempt sign in via `supabase.auth.signInWithPassword()`
5. Log attempt to database via RPC `log_login_attempt`
6. Log to Sentry for security tracking
7. Save email to localStorage (always)
8. If "Remember Me" checked, set extended session flags
9. Fetch user profile and set Sentry user context
10. Call `onSuccess()` callback

---

### 3. SignUpImproved.js

**Purpose:** Multi-step registration with validation and team selection.

**Key Features:**

| Feature | Description |
|---------|-------------|
| 2-Step Flow | Step 1: Email/Password, Step 2: Profile/Team |
| Real-time Email Check | Debounced check for existing email via RPC |
| Password Validation | Minimum 8 characters, confirmation match |
| Team Selection | Dynamic loading from `team_configurations` table |
| Team Branding | Button colors match selected team |
| Terms & Privacy | Modal links with checkbox acceptance |
| Success State | Shows confirmation message with email instructions |

**State Variables:**
- `step` - Current step (1 or 2)
- `formData` - All form fields (email, password, confirmPassword, first_name, last_name, team, user_type)
- `availableTeams` - Teams loaded from database
- `loadingTeams` - Teams loading state
- `agreedToTerms` - Terms checkbox state
- `loading`, `error` - UI states
- `showPassword`, `showConfirmPassword` - Visibility toggles
- `checkingEmail`, `emailChecked` - Email validation states
- `signupSuccess` - Success state after signup

**Database Interactions:**
1. `team_configurations` - Fetch available teams
2. RPC `check_email_exists` - Real-time email validation
3. `supabase.auth.signUp()` - Create auth user
4. RPC `log_login_attempt` - Log signup attempt

**Flow:**
1. Fetch available teams on mount
2. **Step 1:** Email & Password
   - Debounced email check (500ms) via RPC
   - Show checkmark if available, error if taken
   - Validate password length (8+) and match
3. **Step 2:** Profile & Team
   - First name, last name (required)
   - Team selection from dropdown
   - Team branding preview
   - Terms & Privacy checkbox with modal links
4. Submit: Create auth user with metadata
5. Show success message with email confirmation instructions

---

### 4. ResetPassword.js

**Purpose:** Password reset page reached via email link.

**Key Features:**
- Session validation from URL token
- Password confirmation with match validation
- Minimum password length (6 characters)
- Show/hide password toggles
- Auto-redirect to login on success
- Error handling for invalid/expired links

**Flow:**
1. On mount, check for valid session from password reset URL
2. If no session, show error and redirect after 3 seconds
3. User enters new password + confirmation
4. Validate match and length
5. Call `supabase.auth.updateUser({ password })`
6. Show success message and redirect to login

---

### 5. ClaimAccount.js

**Purpose:** Account claiming for pre-created roster athletes.

**Key Features:**
- Token-based invitation system
- Displays athlete info from profile
- Expiration checking
- Already-claimed detection
- Auto-sign-in after successful claim
- Login history tracking for claims

**URL Format:** `/claim-account?token=<invitation_token>`

**Flow:**
1. Extract token from URL
2. Fetch athlete profile by `invitation_token`
3. Validate: not already claimed, not expired
4. Display athlete info (name, email, position)
5. User sets password (6+ characters) with confirmation
6. Create auth user via `supabase.auth.signUp()`
7. Link to profile via RPC `claim_account`
8. Auto sign-in via `supabase.auth.signInWithPassword()`
9. Log claim event to login history
10. Redirect to app

**Required Database Fields:**
- `profiles.invitation_token` - Unique invite token
- `profiles.invitation_status` - pending/claimed/active
- `profiles.invitation_expires_at` - Token expiry date

---

### 6. SessionManager (sessionManager.js)

**Purpose:** Singleton class for managing extended sessions with auto-refresh.

**Key Features:**

| Feature | Description |
|---------|-------------|
| 30-Day Extended Sessions | Persisted via localStorage flags |
| Auto Token Refresh | Every 50 minutes (Supabase tokens expire at 1 hour) |
| Tab Focus Validation | Checks session when tab becomes visible |
| Proactive Validation | `ensureValidSession()` before navigation |
| Concurrent Validation Prevention | Prevents duplicate validations |
| Session Activity Tracking | Logs refreshes/restorations to login history |
| Graceful Error Recovery | Signs out on refresh failure |

**Methods:**

```javascript
// Initialize on app start
sessionManager.initialize()

// Validate before navigation
const isValid = await sessionManager.ensureValidSession()

// Manual refresh
const { success, session } = await sessionManager.refreshSession()

// Get debug info
const info = sessionManager.getSessionInfo()

// Clear on logout
sessionManager.clearSession()
await sessionManager.logout()

// Cleanup
sessionManager.destroy()
```

**LocalStorage Keys:**
- `recoveryedge_extended_session` - 'true' if extended
- `recoveryedge_session_expiry` - ISO expiry date
- `recoveryedge_last_refresh` - Timestamp of last refresh
- `recoveryedge_last_validation` - Timestamp of last validation

---

### 7. AuthResolver (authResolver.js)

**Purpose:** Resolves ID mismatch between auth users and roster athlete profiles.

**Problem Solved:**
- Regular users: `session.user.id === profiles.id`
- Roster athletes: `session.user.id !== profiles.id` (linked via `auth_user_id`)

**Key Functions:**

```javascript
// Get full profile regardless of ID type
const profile = await resolveUserProfile(supabase, session.user.id)

// Just get the profile ID
const profileId = await getProfileId(supabase, session.user.id)

// Check if user is a roster athlete
const isRoster = isRosterAthlete(profile)

// Get correct ID for database queries (always profile.id)
const athleteId = getAthleteId(profile)

// Debug ID relationships
debugIdRelationships(profile, session.user.id)

// Validate FK relationships
const validation = await validateForeignKeys(supabase, profile)
```

**Resolution Strategy:**
1. Try direct match: `profiles.id = session.user.id`
2. Try auth link match: `profiles.auth_user_id = session.user.id`
3. Check if valid auth user without profile (mid-signup)

---

### 8. IP Address Utilities (ipAddress.js)

**Purpose:** Capture user IP address and device information for security tracking.

**Functions:**

```javascript
// Get IP with location (uses ipapi.co)
const ip = await getUserIpAddress()
// Returns: "192.168.1.1 (Madison, United States)"

// Simple IP only (uses ipify.org)
const ip = await getUserIpAddressSimple()
// Returns: "192.168.1.1"

// Get device info
const deviceInfo = getDeviceInfo()
// Returns: { browser, os, platform, vendor, isMobile, userAgent }

// Format for display
const formatted = formatDeviceInfo(deviceInfo)
// Returns: "Chrome on macOS (Desktop)"
```

---

### 9. Legal Modals (PrivacyPolicy.js, TermsOfService.js)

**Purpose:** Full-screen modal components for legal documents.

**Features:**
- Fixed overlay with backdrop blur
- Scrollable content area
- Close button in header
- Responsive sizing (max-width: 800px, max-height: 90vh)

**Usage:**
```jsx
{showPrivacyPolicy && (
  <PrivacyPolicy onClose={() => setShowPrivacyPolicy(false)} />
)}
```

---

## Database Requirements

### Tables

**profiles:**
```sql
CREATE TABLE profiles (
  id UUID PRIMARY KEY,
  email TEXT UNIQUE,
  first_name TEXT,
  last_name TEXT,
  preferred_name TEXT,
  user_type TEXT, -- 'athlete', 'staff', 'admin', 'development'
  team TEXT,
  team_id TEXT DEFAULT 'wisconsin',
  photo_url TEXT,

  -- For roster athletes
  auth_user_id UUID REFERENCES auth.users(id),
  invitation_token TEXT UNIQUE,
  invitation_status TEXT DEFAULT 'pending', -- 'pending', 'claimed', 'active'
  invitation_expires_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**team_configurations:**
```sql
CREATE TABLE team_configurations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  team_id TEXT UNIQUE NOT NULL,
  team_name TEXT NOT NULL,
  organization_name TEXT,
  branding JSONB, -- { primary_color: '#hex', secondary_color: '#hex', ... }
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**login_history:**
```sql
CREATE TABLE login_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  email TEXT,
  success BOOLEAN DEFAULT false,
  error_message TEXT,
  error_code TEXT,
  ip_address TEXT,
  user_agent TEXT,
  device_info TEXT,
  event_type TEXT, -- 'login', 'signup', 'account_claim', 'session_refresh', 'session_restore'
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### RPC Functions

**log_login_attempt:**
```sql
CREATE OR REPLACE FUNCTION log_login_attempt(
  p_user_id UUID,
  p_email TEXT,
  p_success BOOLEAN,
  p_error_message TEXT DEFAULT NULL,
  p_error_code TEXT DEFAULT NULL,
  p_ip_address TEXT DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL,
  p_device_info TEXT DEFAULT NULL,
  p_event_type TEXT DEFAULT 'login'
)
RETURNS void AS $$
BEGIN
  INSERT INTO login_history (
    user_id, email, success, error_message, error_code,
    ip_address, user_agent, device_info, event_type
  ) VALUES (
    p_user_id, p_email, p_success, p_error_message, p_error_code,
    p_ip_address, p_user_agent, p_device_info, p_event_type
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**check_email_exists:**
```sql
CREATE OR REPLACE FUNCTION check_email_exists(email_to_check TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM auth.users WHERE email = email_to_check
  ) OR EXISTS (
    SELECT 1 FROM profiles WHERE email = email_to_check
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**claim_account:**
```sql
CREATE OR REPLACE FUNCTION claim_account(
  invite_token TEXT,
  new_auth_user_id UUID,
  new_email TEXT
)
RETURNS void AS $$
BEGIN
  UPDATE profiles
  SET
    auth_user_id = new_auth_user_id,
    email = new_email,
    invitation_status = 'claimed',
    updated_at = NOW()
  WHERE invitation_token = invite_token
    AND invitation_status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid or already claimed invitation';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## Implementation Checklist

### Phase 1: Core Setup
- [ ] Initialize Supabase client with proper config (localStorage, auto-refresh, PKCE)
- [ ] Create profiles table with all required columns
- [ ] Create login_history table
- [ ] Create RPC functions (log_login_attempt, check_email_exists)
- [ ] Set up RLS policies

### Phase 2: Basic Auth Components
- [ ] Create AuthContainer.js
- [ ] Create Login.js with basic functionality
- [ ] Create SignUpImproved.js with 2-step flow
- [ ] Create legal modal components

### Phase 3: Enhanced Features
- [ ] Add sessionManager.js for extended sessions
- [ ] Integrate IP/device tracking
- [ ] Add Sentry logging (optional)
- [ ] Add email availability checking

### Phase 4: Advanced Features
- [ ] Create ResetPassword.js
- [ ] Create ClaimAccount.js (if using roster athletes)
- [ ] Create authResolver.js (if using roster athletes)
- [ ] Add team_configurations for multi-team support

### Phase 5: Testing
- [ ] Test regular signup flow
- [ ] Test login with remembered email
- [ ] Test extended session (30-day)
- [ ] Test session auto-refresh
- [ ] Test password reset flow
- [ ] Test account claiming flow
- [ ] Test session validation on tab focus

---

## Styling Notes

The current implementation uses **inline styles** for portability. To adapt to your styling system:

**Tailwind CSS:**
Replace inline styles with Tailwind classes. Example:
```jsx
// Before
<div style={{ padding: '40px', backgroundColor: 'white', borderRadius: '12px' }}>

// After (Tailwind)
<div className="p-10 bg-white rounded-xl">
```

**CSS Modules / Styled Components:**
Extract styles to separate files and import.

**Design Tokens:**
Current color scheme:
- Background: `#f5f5f5` (light gray)
- Card: `#ffffff` (white)
- Primary: `#3b82f6` (blue-500)
- Error: `#dc2626` (red-600)
- Success: `#10b981` (emerald-500)
- Text: `#1a1a1a`, `#374151`, `#666666`
- Border: `#d1d5db` (gray-300)

---

## Lessons Learned / Critical Insights

1. **Email availability check must use RPC** - Direct queries to auth.users are blocked by RLS.

2. **Session refresh timing** - Refresh at 50 minutes (not 60) for safety buffer before Supabase's 1-hour expiry.

3. **Tab focus validation** - Essential for detecting stale sessions after device sleep/background.

4. **Concurrent validation prevention** - Without this, multiple rapid navigation events cause race conditions.

5. **IP tracking graceful degradation** - Always catch and continue if IP services fail; don't block auth flow.

6. **Roster athlete ID mapping** - Always use `profile.id` for database queries, never `auth_user_id`.

7. **Password field names** - Use `autoComplete="new-password"` for signup, `autoComplete="current-password"` for login.

8. **Extended session on refresh** - Must check both flag AND expiry date; flag alone is insufficient.

9. **Account claim auto-signin** - Must wait for auth user creation to complete before signing in.

10. **Login history logging** - Use retry logic; don't fail the auth flow if logging fails.

---

## Customization Points

| Item | Location | How to Customize |
|------|----------|------------------|
| App Name | Login.js, SignUp.js | Replace "RecoveryEdge" with your app name |
| Colors | All components | Update inline styles or Tailwind classes |
| LocalStorage Keys | sessionManager.js, Login.js | Update key prefixes (e.g., `recoveryedge_` → `myapp_`) |
| Extended Session Duration | Login.js | Change `30` in `setDate(getDate() + 30)` |
| Password Requirements | SignUp.js, ResetPassword.js | Update `minLength` validation |
| Team Selection | SignUpImproved.js | Remove if not using multi-team |
| Legal Documents | PrivacyPolicy.js, TermsOfService.js | Update content |
| IP Service | ipAddress.js | Change API endpoint if needed |
| Session Refresh Interval | sessionManager.js | Update `REFRESH_INTERVAL` constant |

---

## File Templates

Templates for all components are available in the parent project:
- `/Users/mxz-ai-2025/Projects/recovery-edge-app/src/components/auth/`
- `/Users/mxz-ai-2025/Projects/recovery-edge-app/src/utils/`

Copy and adapt as needed for your project.
