# Expo iOS App Scaffold — Reusable Skill

**Trigger:** `/expo-ios-scaffold`
**Purpose:** Spin up a production-ready iOS app from scratch using the proven LilSense v2 architecture. Auth, subscriptions, edge functions, OTA updates — all wired and ready.
**Built From:** LilSense v2 (shipped to App Store Feb 2026, 127 commits, 4-5 weeks from zero to live).

---

## Overview

**What This Skill Does:**
1. Creates a new Expo (SDK 54+) project with expo-router
2. Wires Supabase (auth, database, edge functions)
3. Integrates RevenueCat for subscriptions with paywall
4. Sets up NativeWind/Tailwind styling
5. Creates the standard screen structure (auth, onboarding, tabs, settings)
6. Configures EAS Build + EAS Update for CI/CD and OTA
7. Sets up the iOS build pipeline (prebuild → Xcode → TestFlight)

**Time Savings:** ~2 weeks of boilerplate eliminated. Start building features on day 1.

---

## How To Use This Skill

When invoked with `/expo-ios-scaffold`, Claude should:

1. **Ask for project details:**
   - App name (display name + bundle ID)
   - Primary feature description (1 sentence)
   - Supabase project (new or existing?)
   - RevenueCat pricing tiers (monthly/annual amounts)
   - Number of main tabs

2. **Generate the project scaffold** following the architecture below

3. **Walk through environment setup** (Supabase keys, RevenueCat API key, EAS project ID)

4. **Verify the build** with `npm start` → iOS simulator

---

## Architecture (Proven in Production)

```
[app-name]/
├── app/                           # expo-router (file-based routing)
│   ├── _layout.tsx               # Root layout — wraps all providers
│   ├── index.tsx                 # Entry: auth check → redirect
│   ├── (auth)/
│   │   ├── _layout.tsx
│   │   ├── login.tsx             # Email/password login
│   │   └── signup.tsx            # Signup with email verification
│   ├── (onboarding)/
│   │   ├── _layout.tsx
│   │   └── welcome.tsx           # Swipeable onboarding cards
│   ├── (tabs)/
│   │   ├── _layout.tsx           # Tab bar configuration
│   │   ├── home.tsx              # Main screen
│   │   ├── history.tsx           # Timeline/log view
│   │   ├── insights.tsx          # AI/analytics screen
│   │   └── settings.tsx          # Account, subscription, legal
│   ├── legal.tsx                 # Privacy + Terms (required)
│   └── reset-password.tsx        # Deep link handler
├── src/
│   ├── context/
│   │   ├── AuthContext.tsx        # Supabase auth state
│   │   └── SubscriptionContext.tsx # RevenueCat state + isPremium
│   ├── hooks/
│   │   ├── useFeatureGate.ts     # Premium feature gating
│   │   └── useTrialTrigger.ts    # Paywall trigger logic
│   ├── services/
│   │   └── supabase.ts           # Supabase client init
│   ├── components/
│   │   ├── auth/                 # Login/signup forms
│   │   ├── subscription/         # PaywallModal
│   │   └── ui/                   # Toast, shared components
│   ├── theme/
│   │   ├── colors.ts             # Brand colors + dark mode
│   │   └── typography.ts         # Font families + sizes
│   └── types/
│       └── index.ts              # Shared TypeScript types
├── supabase/
│   ├── functions/
│   │   ├── delete-account/       # Self-service account deletion
│   │   └── send-verification-email/ # 6-digit code verification
│   ├── migrations/               # SQL migrations
│   └── schema.sql                # Database schema
├── assets/                       # App icon, splash, images
├── app.json                      # Expo config (permissions, plugins, EAS)
├── eas.json                      # EAS Build profiles
├── tailwind.config.js            # NativeWind config
├── tsconfig.json
└── package.json
```

---

## Core Dependencies (Tested Versions)

```json
{
  "dependencies": {
    "expo": "~54.0.0",
    "expo-router": "~6.0.0",
    "react": "19.1.0",
    "react-native": "0.81.5",
    "nativewind": "^4.0.0",
    "tailwindcss": "^3.3.2",
    "@supabase/supabase-js": "^2.x",
    "react-native-purchases": "^9.7.0",
    "expo-haptics": "~14.1.0",
    "expo-linking": "~7.1.0",
    "@react-native-async-storage/async-storage": "^2.1.0",
    "expo-secure-store": "~14.1.0"
  }
}
```

---

## Key Patterns (Copy From LilSense)

### 1. Root Layout Provider Stack

```tsx
// app/_layout.tsx
export default function RootLayout() {
  return (
    <AuthProvider>
      <SubscriptionProvider>
        {/* Add app-specific providers here */}
        <Stack screenOptions={{ headerShown: false }}>
          <Stack.Screen name="index" />
          <Stack.Screen name="(auth)" />
          <Stack.Screen name="(onboarding)" />
          <Stack.Screen name="(tabs)" />
        </Stack>
        <Toast />
      </SubscriptionProvider>
    </AuthProvider>
  );
}
```

### 2. Auth Context Pattern

```tsx
// src/context/AuthContext.tsx — key exports
const AuthContext = createContext<{
  user: User | null;
  loading: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signUp: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
  resetPassword: (email: string) => Promise<void>;
}>({...});

// Uses Supabase onAuthStateChange listener
// Stores session via expo-secure-store
// Redirects via expo-router on auth state change
```

### 3. Subscription Context + Feature Gating

```tsx
// src/context/SubscriptionContext.tsx
const SubscriptionContext = createContext<{
  isPremium: boolean;
  offerings: PurchasesOfferings | null;
  purchasePackage: (pkg: PurchasesPackage) => Promise<void>;
  restorePurchases: () => Promise<void>;
}>({...});

// src/hooks/useFeatureGate.ts
export function useFeatureGate(feature: string) {
  const { isPremium } = useSubscription();
  const [showPaywall, setShowPaywall] = useState(false);

  const checkAccess = () => {
    if (!isPremium) {
      setShowPaywall(true);
      return false;
    }
    return true;
  };

  return { hasAccess: isPremium, checkAccess, showPaywall, setShowPaywall };
}
```

### 4. Paywall Trigger Logic

```tsx
// src/hooks/useTrialTrigger.ts
// Trigger paywall after N actions OR N days (whichever first)
// LilSense used: 10 events OR 3 days
// Configurable per app
const TRIGGER_ACTIONS = 10;
const TRIGGER_DAYS = 3;
```

### 5. iOS Build Pipeline

```bash
# Claude's prep (automated):
# 1. Bump build number in app.json
# 2. Clear Xcode cache: rm -rf ~/Library/Developer/Xcode/DerivedData/[AppName]-*
# 3. Prebuild: npx expo prebuild --platform ios --clean
# 4. Fix build number (prebuild resets to 1):
#    sed -i '' 's/CURRENT_PROJECT_VERSION = 1;/CURRENT_PROJECT_VERSION = [N];/g' ios/[AppName].xcodeproj/project.pbxproj
# 5. Open: open ios/[appname].xcworkspace (NOT .xcodeproj)

# User's Xcode steps:
# 1. Wait for indexing
# 2. Signing: select "WiscAI, LLC" team
# 3. ⌘B to build
# 4. Product → Archive → Distribute → App Store Connect
```

---

## Lessons Learned / Detours Avoided

### 1. Use .xcworkspace, Not .xcodeproj
**What Happened:** Build failures when opening the wrong file after prebuild.
**Fix:** Always `open ios/[name].xcworkspace` — CocoaPods dependencies require the workspace.

### 2. Prebuild Resets Build Number to 1
**What Happened:** Every `expo prebuild --clean` resets CURRENT_PROJECT_VERSION to 1 in the Xcode project.
**Fix:** Run `sed` command after prebuild to restore the correct build number. Always bump in app.json FIRST.

### 3. Simple React Context > Redux/Zustand
**What Happened:** Considered Zustand for state management.
**Fix:** React Context is sufficient for apps with <10 state domains. LilSense shipped with 6 contexts, zero state management libraries, zero issues.

### 4. RevenueCat Sandbox Testing Requires Specific Setup
**What Happened:** Subscriptions not working in development.
**Fix:** Must create sandbox test accounts in App Store Connect. Must use the RevenueCat sandbox API key. Must test on a physical device (not simulator) for purchase flow.

### 5. EAS Update > Full Rebuild for Iteration
**What Happened:** Slow iteration cycle waiting for TestFlight processing.
**Fix:** Use `eas update --branch production` for JS-only changes. Updates appear in ~30 seconds. Reserve full builds for native code changes only.

### 6. Haptic Feedback Makes Apps Feel Native
**What Happened:** App felt like a web wrapper.
**Fix:** Add `expo-haptics` to every button press, toggle, and action confirmation. Small detail, massive UX improvement.

### 7. Font Loading Must Complete Before Render
**What Happened:** Text flickering/layout shift on app open.
**Fix:** Use `useFonts` hook + `SplashScreen.preventAutoHideAsync()`. Only render app after fonts are loaded.

---

## Checklist: New App from Scaffold

- [ ] Create Expo project: `npx create-expo-app@latest [name] --template tabs`
- [ ] Install all dependencies from the list above
- [ ] Set up Supabase project (or use existing)
- [ ] Create RevenueCat project + products in App Store Connect
- [ ] Copy context patterns (Auth, Subscription)
- [ ] Set up file-based routing structure
- [ ] Configure NativeWind/Tailwind
- [ ] Add account deletion edge function
- [ ] Add email verification edge function
- [ ] Configure app.json (permissions, plugins, EAS project ID)
- [ ] Configure eas.json (build profiles)
- [ ] Test auth flow on simulator
- [ ] Test subscription flow on physical device
- [ ] First TestFlight build
- [ ] OTA update test
