# iOS App Store Submission — Reusable Skill

**Trigger:** `/app-store-submit`
**Purpose:** Walk through the complete iOS App Store submission process for any project, from screenshots to submission.

## Overview

**What This Skill Does:**
1. Analyzes the current project's codebase (tech stack, auth, data collection, subscriptions)
2. Generates project-specific App Store metadata recommendations
3. Walks through App Store Connect configuration step-by-step
4. Creates review notes tailored to the app's features
5. Produces a pre-submission checklist

**Built From:** Real submission experiences across Sanctuary (approved Dec 2025), RecoverEdge, and LilSense v2 (2026).

---

## How To Use This Skill

When invoked with `/app-store-submit`, Claude should:

1. **Read the project's CLAUDE.md** to understand tech stack
2. **Scan the codebase** for:
   - Auth system (Supabase, Firebase, etc.) → determines privacy labels
   - Data models → determines what data types to declare
   - Subscription/payment code (RevenueCat, StoreKit) → determines IAP setup
   - Permissions in Info.plist or app.json → determines what needs explanation in review notes
   - AI/ML usage → determines if 5.1.2 consent is needed
   - Child/health-related content → determines COPPA/Kids category concerns
3. **Present a tailored plan** with all sections below
4. **Walk through each section** interactively as the user configures App Store Connect

---

## Lessons Learned / Detours Avoided

### 1. Baby/Child/Health Apps Get Extra Scrutiny
**What Happened (LilSense):** Baby tracking apps can get flagged for Kids category review even though they're for parents.
**Fix:** Proactively add "INTENDED AUDIENCE" section to review notes explaining the app is for adults, not children. Address COPPA, Guideline 1.3, and clarify no child-facing interface exists.
**Key Insight:** Any app that involves children, even tangentially (parenting, education, health tracking for minors), should preemptively address this.

### 2. Statistical Analysis ≠ AI — But Apple Might Think It Does
**What Happened (LilSense):** App uses exponential smoothing and WHO/CDC data for predictions. Not AI, but "Smart Predictions" sounds like it could be.
**Fix:** Explicitly state in review notes: "No neural networks, no LLMs, no AI/ML of any kind — this is statistical pattern analysis." Cite the specific methods used.
**Key Insight:** If your app has anything that sounds intelligent (predictions, recommendations, analysis), clarify the technology in review notes.

### 3. AI Apps MUST Have Dedicated Consent (Guideline 5.1.2)
**What Happened (Sanctuary):** Apple requires explicit, dedicated AI consent separate from Privacy Policy/Terms acceptance. Cannot bundle together. Cannot skip.
**Fix:** Added a 4th onboarding step with dedicated "Support Powered by AI" consent screen. Recorded consent with timestamp in database.
**Key Insight:** If your app uses ANY AI (OpenAI, Claude, local ML models), you need a dedicated consent screen. Plan for this in onboarding flow.

### 4. Account Deletion Is Required (Guideline 5.1.1(v))
**What Happened (Sanctuary):** App was rejected because it had account creation but no self-service deletion.
**Fix:** Added 3-step deletion flow: Warning → Type "DELETE" → Password verification → Delete via Supabase Edge Function.
**Key Insight:** If users can create accounts, they must be able to delete them in-app. "Email us to delete" is NOT sufficient.

### 5. Subscription Setup: Don't Use In-App Purchases
**What Happened (LilSense):** User initially went to "In-App Purchases" (Consumable/Non-Consumable) instead of "Subscriptions."
**Fix:** Auto-Renewable Subscriptions are in a SEPARATE section of App Store Connect, not under In-App Purchases.
**Key Insight:** Subscriptions ≠ In-App Purchases in Apple's taxonomy. They're configured in different places.

### 6. Subscription Level Order Matters
**What Happened (LilSense):** Monthly was set as Level 1 (should be Annual).
**Fix:** Level 1 = highest value plan (annual). Apple uses level order for upgrade/downgrade logic.

### 7. App Download Price vs Subscription Price
**What Happened (LilSense):** User set app download price to $4.99 instead of $0.00.
**Fix:** App download price (Pricing and Availability) must be $0.00 for freemium apps. Subscription prices are configured separately.

### 8. Unused Permissions Need Explanation
**What Happened (LilSense):** Microphone permission declared for future voice feature but not active.
**Fix:** Explain in review notes why the permission exists and that it's not currently accessed.
**Key Insight:** If your Info.plist declares a permission your app doesn't actively use, Apple may ask about it. Preempt with review notes.

### 9. Screenshots: One Device Covers All Sizes
**What Happened:** Multiple simulator runs for different device sizes.
**Fix:** Capture on iPhone 17 Pro Max (iOS 26.1) for 6.9" — App Store Connect auto-scales for 6.7", 6.5", 5.5". iPad Pro 13" (M5) covers all iPad sizes.
**Key Insight:** You only need two simulators for all screenshot sizes.

### 10. Prebuild Resets Build Numbers (Expo/React Native)
**What Happened (LilSense):** `npx expo prebuild` resets CURRENT_PROJECT_VERSION to 1 in Xcode project.
**Fix:** Always run sed fix after prebuild:
```bash
sed -i '' 's/CURRENT_PROJECT_VERSION = 1;/CURRENT_PROJECT_VERSION = [NUMBER];/g' ios/AppName.xcodeproj/project.pbxproj
```

---

## Section 1: Screenshots

### Device Matrix
| Platform | Simulator | Resolution | Covers |
|----------|-----------|-----------|--------|
| **iPhone** | iPhone 17 Pro Max (iOS 26.1) | 1320 x 2868 (6.9") | 6.7", 6.5", 5.5" auto-scaled |
| **iPad** | iPad Pro 13-inch M5 (iOS 26.1) | 2064 x 2752 (13") | 12.9" auto-scaled |

### Clean Status Bar
```bash
# Find booted device
xcrun simctl list devices booted

# Set clean status bar
xcrun simctl status_bar "<UDID>" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4

# Take screenshot
# Option A: ⌘S in Simulator (saves to Desktop)
# Option B: Terminal
xcrun simctl io booted screenshot ~/Desktop/screenshot.png

# Reset status bar when done
xcrun simctl status_bar "<UDID>" clear
```

### Simulator Troubleshooting
| Issue | Fix |
|-------|-----|
| Keyboard not working | Simulator → I/O → Keyboard → Connect Hardware Keyboard (`⌘⇧K`) |
| App won't connect to dev server | Start `npx expo start`, then deep link: `xcrun simctl openurl "<UDID>" "<scheme>://expo-development-client/?url=http%3A%2F%2Flocalhost%3A8081"` |
| Simulator frozen | Device menu → Restart |

### Screenshot Best Practices
- Show app fully populated with realistic data — never empty states
- Minimum 3, recommended 5–10 per device size
- Consider text overlays for App Store marketing (Figma, Rotato, AppMockUp)
- Use the app's primary theme (dark mode if that's the default)

---

## Section 2: App Privacy (Nutrition Labels)

### Step 1: "Do you collect data?" → YES
Answer Yes if your app has ANY of: authentication, user-generated content, health data, analytics, subscriptions.

### Step 2: Data Type Selection

**Analyze the project's codebase for these signals:**

| Signal in Code | Data Type to Check |
|---------------|-------------------|
| Auth system (Supabase Auth, Firebase Auth) | Email Address, User ID |
| User profiles with names | Name |
| Health/medical/fitness data | Health |
| User-generated content (notes, entries, logs) | Other User Content |
| RevenueCat / StoreKit / subscription code | Purchases |
| Analytics SDK (PostHog, Mixpanel, Amplitude) | Product Interaction |
| Crash reporting (Sentry, Crashlytics) | Crash Data |
| Location services | Precise/Coarse Location |
| Photo/camera access (actively used) | Photos or Videos |
| Audio recording (actively used) | Audio Data |

**Common "Skip" items for privacy-first apps:**
Phone Number, Physical Address, Financial Info (Apple handles payments), Advertising Data, Device ID, Browsing History, Search History, Sensitive Info.

### Step 3: Follow-Up Questions (for each data type)

For typical indie/privacy-first apps, the answer pattern is the same for every data type:

| Question | Answer |
|----------|--------|
| Purpose | **App Functionality** only (skip Advertising, Marketing, Analytics unless applicable) |
| Linked to Identity? | **Yes** (if data is tied to user account) |
| Used to Track? | **No** (unless you share with ad networks) |

**Exception:** If you have analytics (PostHog, etc.), check "Analytics" as purpose for Product Interaction data, and set Linked to Identity = No.

---

## Section 3: Subscriptions (Auto-Renewable)

### Where to Configure
**Subscriptions** section in left sidebar — NOT "In-App Purchases" (that's for one-time purchases).

### Setup Steps
1. Create **Subscription Group** (e.g., "AppName Premium")
2. Add subscriptions within the group
3. Set **Level Order**: Level 1 = highest value (annual), Level 2 = monthly
4. For each subscription, configure:
   - Reference Name (internal)
   - Product ID (must match RevenueCat exactly)
   - Duration (1 month / 1 year)
   - Price (from Apple's price tier list)
   - Localization: Display Name + Description

### Common Pricing
| Plan | Price | Notes |
|------|-------|-------|
| Monthly | $4.99 | Standard for utility apps |
| Annual | $34.99–$49.99 | 30–42% savings vs monthly |

### Product ID Convention
```
appname_premium_monthly
appname_premium_annual
```
If IDs already taken (from previous builds), append `_v2`.

### After Creating
1. Go to version page (e.g., "1.0 Prepare for Submission")
2. Scroll to "In-App Purchases and Subscriptions"
3. Select subscriptions to include with submission

### App Download Price
- Go to **Pricing and Availability** (left sidebar)
- Set to **$0.00 (Free)** for freemium apps
- This is separate from subscription prices

### RevenueCat Integration
After App Store Connect setup:
1. Add product IDs to RevenueCat dashboard → Products
2. Attach products to entitlement (e.g., `premium`)
3. Verify entitlement name matches code: `customerInfo.entitlements.active['premium']`

### Optional: Billing Grace Period
Enable under Subscriptions → Billing Grace Period. Gives users a few days to fix payment issues. Good for retention.

---

## Section 4: Review Notes Template

Generate review notes tailored to the app. Include ALL applicable sections:

```
TEST ACCOUNT:
Email: [test account email]
Password: [test account password]

[If app requires data to demo features:]
The test account has been pre-populated with [X days] of sample data
to demonstrate all features including [feature that needs data].

ABOUT THE APP:
[1-2 sentence description of what the app does and who it's for]

[IF APP INVOLVES CHILDREN/BABIES/MINORS — INCLUDE THIS:]
INTENDED AUDIENCE — PARENTS/CAREGIVERS (NOT CHILDREN):
[App name] is designed for and used exclusively by adult [parents/
caregivers/teachers/etc.]. [Children/minors] do not interact with
this app in any way. The app is not directed at children, does not
fall under the Kids category (Guideline 1.3), and is not subject to
COPPA as a child-directed service. [Describe how data is managed by
adults, not children.]

[IF APP HAS PREDICTIONS/ANALYSIS THAT IS NOT AI:]
PREDICTION/ANALYSIS FEATURES:
This app includes [feature name]. These [predictions/analyses] do NOT
use artificial intelligence or machine learning. The system uses:
1. [Specific method] — [brief description]
2. [Data sources] — [brief description]
No neural networks, no large language models, no AI/ML of any kind.
No AI consent screen is required because no AI technology is used.

[IF APP USES AI — Guideline 5.1.2:]
AI FEATURES AND CONSENT:
This app includes AI-powered features using [provider]. Per Apple's
guidelines (Section 5.1.2), we have implemented explicit AI consent
during onboarding:
- Users see a dedicated consent screen before accessing AI features
- Consent is required to proceed
- Consent includes explanations of: data privacy, user control, limitations
- AI consent is timestamped and stored

[IF APP HAS SUBSCRIPTIONS:]
SUBSCRIPTION INFO:
- Free tier: [what's included]
- Premium: [what's included]
- Monthly: $[price]
- Annual: $[price]

[IF APP DECLARES UNUSED PERMISSIONS:]
[PERMISSION NAME] PERMISSION:
The [permission] is declared in Info.plist for [reason]. This feature
is not active in the current version — the [hardware] is never accessed.

DATA PRIVACY:
- [List key privacy points]
- Full account deletion available in [location]

CONTACT:
[support email]
```

---

## Section 5: Export Compliance

Standard for most apps (HTTPS only):

| Question | Answer |
|----------|--------|
| Uses encryption? | Yes |
| Qualifies for exemption? | Yes |
| Which exemption? | Standard HTTPS/TLS for secure data transmission |

---

## Section 6: Age Rating

### For Apps NOT in Kids Category
Answer "None" to all content descriptors unless the app specifically contains that content.

**Common ratings:**
- **4+** — No objectionable content (utility apps, trackers, tools)
- **12+** — Mature themes (mental health, grief, faith/spiritual content)
- **17+** — Frequent/intense mature themes, unrestricted web access

---

## Section 7: Pre-Submission Checklist

### App Store Connect
- [ ] App name, subtitle, keywords
- [ ] Description (first 170 chars visible before "more")
- [ ] Promotional text (can update without new build)
- [ ] Screenshots uploaded (iPhone + iPad if universal)
- [ ] App icon (1024x1024 PNG, no transparency, no rounded corners)
- [ ] Categories (Primary + Secondary)
- [ ] Privacy Policy URL (publicly accessible)
- [ ] Support URL (publicly accessible)
- [ ] Terms of Service URL
- [ ] Age Rating questionnaire
- [ ] App Privacy nutrition labels completed + published
- [ ] Subscriptions/IAP created and attached to version
- [ ] App download price ($0.00 for freemium)
- [ ] Export compliance
- [ ] Review notes with test account
- [ ] Build uploaded and selected
- [ ] What's New text (for updates)

### Code (Before Final Build)
- [ ] Payment bypass / debug flags set to `false`
- [ ] All debug logging removed or gated
- [ ] Version and build numbers correct
- [ ] All changes committed and pushed to git
- [ ] Prebuild + build number fix (Expo apps)

### RevenueCat (If Applicable)
- [ ] Product IDs match App Store Connect exactly
- [ ] Products attached to correct entitlement
- [ ] Entitlement name matches code
- [ ] Sandbox testing verified on device

### URLs (Verify All Work)
- [ ] Privacy Policy URL loads
- [ ] Terms of Service URL loads
- [ ] Support URL loads
- [ ] Marketing URL loads (if provided)

---

## Section 8: Post-Submission

### Review Timeline
- Typical: 24–48 hours
- First submission may take longer
- Check status in App Store Connect

### If Rejected
1. Read rejection reason carefully — Apple cites specific guidelines
2. Address the specific issue (don't over-fix)
3. Reply in Resolution Center if clarification needed
4. Common fixes: add account deletion, add AI consent, fix broken URLs, add test account
5. Resubmit

### After Approval
- [ ] Release (manual or automatic)
- [ ] Monitor crash reports in Xcode Organizer
- [ ] Respond to user reviews within 24–48 hours
- [ ] Plan first update based on feedback

---

## Appendix: Tech Stack Detection Guide

When scanning a project, look for these signals to determine what sections apply:

| File/Pattern | Indicates | Sections Affected |
|-------------|-----------|-------------------|
| `supabase` in code | Auth + database | Privacy labels, review notes |
| `RevenueCat` or `Purchases` import | Subscriptions | Subscription setup, privacy labels |
| `openai`, `anthropic`, `@google/generative-ai` | AI features | 5.1.2 consent, review notes |
| `expo-speech-recognition`, microphone permission | Voice/audio | Permission explanation in review notes |
| `expo-location`, location permission | Location services | Privacy labels |
| `sentry`, `crashlytics` | Crash reporting | Privacy labels (Diagnostics) |
| `posthog`, `mixpanel`, `amplitude` | Analytics | Privacy labels (Usage Data) |
| `baby`, `child`, `kid`, `infant`, `minor` in content | Child-adjacent | COPPA/Kids clarification in review notes |
| `health`, `medical`, `symptom`, `temperature` | Health data | Privacy labels (Health) |
| `camera`, `photo` in active use | Photo/video capture | Privacy labels |

---

*Last updated: March 1, 2026*
*Source apps: Sanctuary (approved Dec 2025), RecoverEdge v2, LilSense v2*
