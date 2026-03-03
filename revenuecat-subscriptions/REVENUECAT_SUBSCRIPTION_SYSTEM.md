# RevenueCat Subscription System — Reusable Skill

**Trigger:** `/revenuecat-setup`
**Purpose:** Add subscription monetization to any React Native (Expo) iOS app using RevenueCat. Includes paywall, feature gating, trial triggers, and sandbox testing.
**Built From:** LilSense v2 (live on App Store, subscriptions active and verified).

---

## Overview

**What This Skill Does:**
1. Creates subscription products in App Store Connect
2. Configures RevenueCat project with offerings
3. Implements SubscriptionContext (React Context pattern)
4. Builds a PaywallModal component
5. Adds feature gating hooks (useFeatureGate, useTrialTrigger)
6. Sets up sandbox testing
7. Verifies the complete purchase flow

**Time Savings:** ~3-5 days of integration work reduced to ~4 hours.

---

## How To Use This Skill

When invoked with `/revenuecat-setup`, Claude should:

1. **Read the project's package.json and app.json** to confirm React Native/Expo
2. **Ask for pricing decisions:**
   - Monthly price (e.g., $4.99)
   - Annual price (e.g., $29.99 or $34.99)
   - Free trial length (7 days recommended)
   - Paywall trigger (e.g., after 10 actions or 3 days)
   - What features are premium vs free
3. **Implement in order:** App Store Connect → RevenueCat dashboard → Code integration → Testing

---

## Step-by-Step Implementation

### Step 1: App Store Connect — Create Subscriptions

**CRITICAL DETOUR AVOIDED:** Subscriptions are NOT under "In-App Purchases." They are in a SEPARATE section.

1. App Store Connect → Your App → **Distribution** tab
2. Left sidebar → **Subscriptions** (under Monetization)
3. Create a **Subscription Group** (e.g., `[appname]_premium`)
4. Add subscription products inside the group:

| Product | Reference Name | Product ID | Duration | Price |
|---------|---------------|------------|----------|-------|
| Monthly | [App] Premium Monthly | `[appname]_premium_monthly` | 1 Month | $4.99 |
| Annual | [App] Premium Annual | `[appname]_premium_annual` | 1 Year | $29.99 |

**CRITICAL:** Set subscription levels correctly:
- **Level 1 = Annual** (highest value) — Apple uses levels for upgrade/downgrade logic
- **Level 2 = Monthly**
- Getting this wrong causes confusing upgrade prompts

**For each product, configure:**
- Subscription Duration
- Subscription Price (base country → Apple auto-generates others)
- Free trial: Introductory Offer → Free → 7 days (or your chosen length)
- App Store Localization: Display name + description shown on purchase sheet

### Step 2: RevenueCat Dashboard Configuration

1. Create project at [app.revenuecat.com](https://app.revenuecat.com)
2. Add iOS app → Enter bundle ID + App Store Connect shared secret
3. **Products:** Add both product IDs from App Store Connect
4. **Entitlements:** Create `premium` entitlement → attach both products
5. **Offerings:** Create `default` offering → add both products as packages
6. **API Keys:** Copy the iOS public API key (starts with `appl_`)

**Shared Secret Location:**
App Store Connect → Your App → Distribution → App Information → App-Specific Shared Secret → Generate → Copy → Paste into RevenueCat

### Step 3: Code Integration

#### 3.1 Install Dependencies

```bash
npx expo install react-native-purchases
```

Add to `app.json` plugins (if using Expo prebuild):
```json
{
  "plugins": [
    "react-native-purchases"
  ]
}
```

#### 3.2 SubscriptionContext

```tsx
// src/context/SubscriptionContext.tsx
import React, { createContext, useContext, useEffect, useState } from 'react';
import Purchases, {
  PurchasesOfferings,
  PurchasesPackage,
  CustomerInfo,
} from 'react-native-purchases';
import { Platform } from 'react-native';

const REVENUECAT_API_KEY = 'appl_YOUR_KEY_HERE'; // from .env in production
const ENTITLEMENT_ID = 'premium';

interface SubscriptionContextType {
  isPremium: boolean;
  offerings: PurchasesOfferings | null;
  loading: boolean;
  purchasePackage: (pkg: PurchasesPackage) => Promise<boolean>;
  restorePurchases: () => Promise<boolean>;
}

const SubscriptionContext = createContext<SubscriptionContextType>({
  isPremium: false,
  offerings: null,
  loading: true,
  purchasePackage: async () => false,
  restorePurchases: async () => false,
});

export function SubscriptionProvider({ children, userId }: { children: React.ReactNode; userId?: string }) {
  const [isPremium, setIsPremium] = useState(false);
  const [offerings, setOfferings] = useState<PurchasesOfferings | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const init = async () => {
      if (Platform.OS === 'ios') {
        await Purchases.configure({ apiKey: REVENUECAT_API_KEY });
        if (userId) {
          await Purchases.logIn(userId);
        }
      }
      await checkSubscription();
      await loadOfferings();
      setLoading(false);
    };
    init();
  }, [userId]);

  const checkSubscription = async () => {
    try {
      const customerInfo = await Purchases.getCustomerInfo();
      setIsPremium(customerInfo.entitlements.active[ENTITLEMENT_ID] !== undefined);
    } catch (e) {
      console.error('Failed to check subscription:', e);
    }
  };

  const loadOfferings = async () => {
    try {
      const offs = await Purchases.getOfferings();
      setOfferings(offs);
    } catch (e) {
      console.error('Failed to load offerings:', e);
    }
  };

  const purchasePackage = async (pkg: PurchasesPackage): Promise<boolean> => {
    try {
      const { customerInfo } = await Purchases.purchasePackage(pkg);
      const premium = customerInfo.entitlements.active[ENTITLEMENT_ID] !== undefined;
      setIsPremium(premium);
      return premium;
    } catch (e: any) {
      if (!e.userCancelled) console.error('Purchase failed:', e);
      return false;
    }
  };

  const restorePurchases = async (): Promise<boolean> => {
    try {
      const customerInfo = await Purchases.restorePurchases();
      const premium = customerInfo.entitlements.active[ENTITLEMENT_ID] !== undefined;
      setIsPremium(premium);
      return premium;
    } catch (e) {
      console.error('Restore failed:', e);
      return false;
    }
  };

  return (
    <SubscriptionContext.Provider value={{ isPremium, offerings, loading, purchasePackage, restorePurchases }}>
      {children}
    </SubscriptionContext.Provider>
  );
}

export const useSubscription = () => useContext(SubscriptionContext);
```

#### 3.3 Feature Gate Hook

```tsx
// src/hooks/useFeatureGate.ts
import { useState } from 'react';
import { useSubscription } from '../context/SubscriptionContext';

export function useFeatureGate() {
  const { isPremium } = useSubscription();
  const [showPaywall, setShowPaywall] = useState(false);

  const requirePremium = (callback?: () => void): boolean => {
    if (isPremium) {
      callback?.();
      return true;
    }
    setShowPaywall(true);
    return false;
  };

  return { isPremium, requirePremium, showPaywall, setShowPaywall };
}
```

#### 3.4 Trial Trigger Hook

```tsx
// src/hooks/useTrialTrigger.ts
import { useEffect, useState } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { useSubscription } from '../context/SubscriptionContext';

const ACTIONS_KEY = 'trial_action_count';
const INSTALL_KEY = 'trial_install_date';
const TRIGGER_ACTIONS = 10;  // Adjust per app
const TRIGGER_DAYS = 3;       // Adjust per app

export function useTrialTrigger() {
  const { isPremium } = useSubscription();
  const [shouldShowPaywall, setShouldShowPaywall] = useState(false);

  const recordAction = async () => {
    if (isPremium) return;

    // Check action count
    const countStr = await AsyncStorage.getItem(ACTIONS_KEY);
    const count = (parseInt(countStr || '0') || 0) + 1;
    await AsyncStorage.setItem(ACTIONS_KEY, count.toString());

    // Check install date
    let installDate = await AsyncStorage.getItem(INSTALL_KEY);
    if (!installDate) {
      installDate = new Date().toISOString();
      await AsyncStorage.setItem(INSTALL_KEY, installDate);
    }
    const daysSinceInstall = Math.floor(
      (Date.now() - new Date(installDate).getTime()) / (1000 * 60 * 60 * 24)
    );

    if (count >= TRIGGER_ACTIONS || daysSinceInstall >= TRIGGER_DAYS) {
      setShouldShowPaywall(true);
    }
  };

  return { shouldShowPaywall, setShouldShowPaywall, recordAction };
}
```

#### 3.5 Paywall Modal

```tsx
// src/components/subscription/PaywallModal.tsx
// Key pattern: Show annual as "recommended" (anchor pricing)
// Monthly exists to make annual look like a deal
// Include: feature list, price comparison, restore button, close button
// Animated entry (slide up) for 2.9x higher conversion vs static
```

### Step 4: Testing

**Sandbox Testing Checklist:**
1. Create sandbox test account in App Store Connect → Users and Access → Sandbox Testers
2. Sign out of real App Store on test device (Settings → App Store → Sign Out)
3. In-app purchase will prompt for sandbox credentials
4. Verify in RevenueCat dashboard: Customer → check entitlements active
5. Sandbox subscriptions auto-renew on accelerated schedule (monthly = every 5 min)

**Common Testing Issues:**
| Issue | Fix |
|-------|-----|
| "Cannot connect to iTunes Store" | Use physical device, not simulator |
| Purchase succeeds but isPremium stays false | Check entitlement ID matches exactly |
| Offerings returns null | Verify products are "Ready to Submit" in App Store Connect |
| "Product not found" | Wait 15-30 min after creating products (propagation delay) |

---

## Lessons Learned / Detours Avoided

### 1. App Download Price Must Be $0.00 for Freemium
**What Happened:** Set app download price to $4.99 instead of free.
**Fix:** Pricing and Availability → Price = Free ($0.00). Subscription prices are separate.

### 2. Subscription Level Order Matters
**What Happened:** Monthly was Level 1 (should be Annual).
**Fix:** Level 1 = highest value (annual). Apple uses levels for upgrade/downgrade logic.

### 3. Hard Paywall Converts 5.5x Better Than Freemium
**Data:** RevenueCat 2025 — hard paywall converts 12.1% vs freemium 2.2%.
**Recommendation:** For utility apps with high search intent, use hard paywall with generous free trial.

### 4. Annual Pricing Retains 2.5x Better Than Monthly
**Data:** RevenueCat 2025 — annual retention 36-47% at 12 months vs monthly 17-20%.
**Recommendation:** Make annual the default/highlighted option. Monthly exists as price anchor.

### 5. Paywall at End of Onboarding Captures ~50% of Trial Starts
**Data:** Superwall research on million-dollar apps.
**Recommendation:** Show paywall after onboarding completes, before main app. User is maximally motivated.
