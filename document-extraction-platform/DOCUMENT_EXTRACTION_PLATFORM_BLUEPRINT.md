# Document Extraction Platform — Reusable Blueprint

**Version:** 1.0
**Last Updated:** February 25, 2026
**Reference Implementation:** Aqualis SecondaryAI (`/Users/mxz-ai-2025/Projects/aqualis-secondary-ai`)
**Proven Result:** 4,180 lines, 7 pages, 25 files, demo-ready in one session + one refinement pass

> This blueprint captures the complete architecture, patterns, and lessons from the Aqualis SecondaryAI build — the "gold standard" project in the AI Factory methodology. Use it to replicate similar "documents in → structured data → professional output" solutions for any domain.

---

## Table of Contents

1. [When to Use This Blueprint](#1-when-to-use-this-blueprint)
2. [The Journey: How Aqualis Was Built](#2-the-journey-how-aqualis-was-built)
3. [Architecture Overview](#3-architecture-overview)
4. [File Structure Template](#4-file-structure-template)
5. [The Three-Context Pattern](#5-the-three-context-pattern)
6. [Mock Data Design](#6-mock-data-design)
7. [The Extraction Animation Pattern](#7-the-extraction-animation-pattern)
8. [Calculation Library Pattern](#8-calculation-library-pattern)
9. [Excel Export Pattern](#9-excel-export-pattern)
10. [Page-by-Page Architecture](#10-page-by-page-architecture)
11. [Design System Template](#11-design-system-template)
12. [Dependency Stack](#12-dependency-stack)
13. [Demo Flow Choreography](#13-demo-flow-choreography)
14. [How to Replicate for a New Domain](#14-how-to-replicate-for-a-new-domain)
15. [Gotchas & Lessons Learned](#15-gotchas--lessons-learned)
16. [AI Factory Template Gap Analysis](#16-ai-factory-template-gap-analysis)

---

## 1. When to Use This Blueprint

This blueprint applies when the client's workflow follows this pattern:

```
Receives documents (PDFs, Excel, etc.)
        ↓
Manually extracts data points
        ↓
Populates spreadsheets/models
        ↓
Analyzes data (comparisons, sensitivity, scenarios)
        ↓
Produces output (Excel reports, one-pagers, memos)
```

**Industry examples:**
| Industry | Documents In | Data Extracted | Output |
|----------|-------------|----------------|--------|
| **PE Secondaries** | PPMs, capital accounts, quarterly reports | Fund NAV, TVPI, IRR, company metrics | Fund models, sensitivity matrices |
| **Insurance** | Applications, medical records, loss runs | Risk factors, coverage needs, claims history | Underwriting scorecards |
| **M&A Advisory** | CIMs, financial statements, data rooms | Revenue, EBITDA, multiples, synergies | Comparable analysis, valuation models |
| **Commercial Lending** | Tax returns, financials, rent rolls | Income, expenses, DSCR, LTV | Credit memos, loan sizing |
| **Compliance/Audit** | Policy docs, transaction records, filings | Violations, gaps, risk areas | Audit reports, remediation plans |
| **Commercial Printing** | Quote PDFs, job tickets, shipping docs | Line items, pricing, quantities | Invoices, billing summaries |

**The key signal:** If someone says "my team spends [hours/days] manually going through [documents] to fill out [spreadsheets]" — this blueprint applies.

---

## 2. The Journey: How Aqualis Was Built

### Timeline

| Date | Commit | Hours | What Happened |
|------|--------|-------|---------------|
| Feb 16, 11:59am | `77a2be5` | 0 | `create-next-app` — blank scaffold |
| Feb 16, 3:37pm | `96d2d83` | ~3.5 | **Full demo app**: 7 pages, 26 files, 6,502 lines added. Extraction animation, all data pages, Excel export, mock data. |
| Feb 21, 1:04pm | `142e642` | ~3 | **Post-client refinements**: 5 features added after Gil (client) demo. 536 lines changed across 8 files. |

**Total: ~6.5 hours of build time across 2 sessions.**

### What Made It Fast

1. **Complete CLAUDE.md before any code** — domain context, design system, anti-patterns, data model
2. **Mock data designed first** — 7 real fund names, 26 real company names, realistic metrics
3. **Extraction is simulated** — no real AI pipeline needed for demo; choreographed animation
4. **Calculation library isolated** — all math in one file, imported everywhere
5. **Three contexts provide all state** — no complex state management needed

### Post-Demo Changes (What the Client Asked For)

The client (Gil) saw the demo and requested 5 specific refinements:

1. **% of NAV Represented** — replaced GP Commitment column in fund table (client cared about portfolio concentration)
2. **Company-level debt & entry value** — added `debt` and `entryValue` fields to all 26 companies (client does this analysis manually)
3. **Exit modeling** — ownership-adjusted exit proceeds calculations (the core of their analysis)
4. **Close Deal workflow** — ability to archive deals, muted styling, excluded from totals
5. **Excel restructure** — Summary sheet + 7 per-fund sheets (matching their actual Excel workflow)

**Lesson:** Build the demo fast, get client feedback, then refine. The refinements took ~3 hours — less time than trying to guess all requirements upfront.

---

## 3. Architecture Overview

```
┌─ Layout (layout.tsx) ────────────────────────────────────────┐
│  DealProvider → InsightsProvider → ExtractionProvider         │
│  ┌─ Header ──────────────────────────────────────────────┐   │
│  │  Logo | Search | Notifications | Active Deal | User   │   │
│  └───────────────────────────────────────────────────────┘   │
│  ┌─ Sidebar ─┐  ┌─ Main Content ─────────────────────────┐  │
│  │ Navigation│  │  PageTransition wrapper                 │  │
│  │ • Pipeline│  │  ┌─────────────────────────────────┐   │  │
│  │ • DataRoom│  │  │  Page Header + Stats             │   │  │
│  │ • Model   │  │  ├─────────────────────────────────┤   │  │
│  │ • Company │  │  │  Data Tables / Cards / Charts    │   │  │
│  │ • Sensitiv│  │  ├─────────────────────────────────┤   │  │
│  │ • Insights│  │  │  Export / Actions                │   │  │
│  │───────────│  │  └─────────────────────────────────┘   │  │
│  │ Deal List │  │                                         │  │
│  │ • Alpine  │  │                                         │  │
│  │ • Beacon  │  │                                         │  │
│  │ • Cascade │  │                                         │  │
│  │───────────│  │                                         │  │
│  │ Run CTA   │  │                                         │  │
│  │ Branding  │  │                                         │  │
│  └───────────┘  └─────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### Data Flow

```
Mock Data (funds.ts)
    ↓
Calculation Library (exit-model.ts) ← Pure functions, no side effects
    ↓
┌───────────────────┐
│ UI Components     │ → Display formatted data
│ Excel Exporter    │ → Generate .xlsx workbook
│ API Route         │ → Serve Excel download
└───────────────────┘
    ↑
Context Providers gate which pages show data:
  - DealContext: which deal is selected
  - ExtractionContext: has extraction run? (boolean)
  - InsightsContext: AI insights with dismiss state
```

---

## 4. File Structure Template

```
src/
├── app/
│   ├── layout.tsx                    # Root layout with providers + Header + Sidebar
│   ├── globals.css                   # Tailwind v4 imports + custom fonts + print styles
│   ├── page.tsx                      # Page 1: Dashboard/Pipeline
│   ├── data-room/page.tsx            # Page 2: Upload + Extraction animation
│   ├── [primary-model]/page.tsx      # Page 3: Main data table (expandable rows)
│   ├── [detail-view]/page.tsx        # Page 4: Entity cards with filters/sort
│   ├── sensitivity/page.tsx          # Page 5: Scenario analysis matrix
│   ├── insights/page.tsx             # Page 6: AI-detected patterns
│   └── api/
│       └── export/route.ts           # Excel generation endpoint
├── components/
│   ├── layout/
│   │   ├── Header.tsx                # Top bar: branding, search, user
│   │   └── Sidebar.tsx               # Nav + entity list + deadline badges + CTA
│   └── ui/
│       ├── EmptyDealState.tsx         # "No data yet" placeholder
│       ├── PendingExtractionState.tsx # "Run extraction first" gate
│       ├── PageTransition.tsx         # Framer Motion fade-in
│       └── Toast.tsx                  # Success notification
├── context/
│   ├── [Entity]Context.tsx           # Entity selection + list management
│   ├── ExtractionContext.tsx          # Boolean gate: has processing run?
│   └── InsightsContext.tsx            # AI insights + dismiss tracking
└── lib/
    ├── calculations/
    │   └── [domain]-model.ts         # ALL deterministic math lives here
    ├── excel/
    │   └── exporter.ts               # ExcelJS workbook builder
    ├── mock-data/
    │   └── [entities].ts             # Realistic demo data + derived totals
    ├── supabase/
    │   ├── client.ts                 # Browser client
    │   └── server.ts                 # Server + service role clients
    └── types/
        └── index.ts                  # Full type system
```

**File count:** ~25 source files
**Line count:** ~4,000-5,000 lines
**Time to build:** 3-6 hours (with complete blueprint)

---

## 5. The Three-Context Pattern

This is the core state management architecture. Every page reads from these three contexts.

### Context 1: Entity Context (DealContext in Aqualis)

**Purpose:** Manages the list of top-level entities and which one is active.

```typescript
// Pattern:
interface EntityContextValue {
  entities: EntitySummary[];        // List of all entities
  activeEntityId: string;           // Currently selected
  setActiveEntityId: (id: string) => void;
  activeEntity: EntitySummary;      // Derived from above
  archiveEntity: (id: string) => void; // Status management
}

// Initial data: 3 entities (1 active, 2 pipeline)
// This gives the app a "populated" feel while focusing on one entity's data
```

**Aqualis implementation:** 3 deals (Alpine=active, Beacon=pipeline, Cascade=pipeline). Only Alpine has data — other deals show empty states.

### Context 2: Extraction Context

**Purpose:** Boolean gate that controls whether data pages show content or "awaiting extraction" state.

```typescript
interface ExtractionContextValue {
  hasExtracted: boolean;            // Has the extraction animation completed?
  markExtracted: () => void;        // Called when extraction finishes
  resetExtraction: () => void;      // Called when data room is reset
}
```

**Critical pattern:** Every data page checks `hasExtracted` before rendering content:
```tsx
if (!hasExtracted) return <PendingExtractionState />;
// Only render data content below this line
```

### Context 3: Insights Context

**Purpose:** Mock AI-generated insights with severity levels and dismiss tracking.

```typescript
interface InsightsContextValue {
  insights: Insight[];              // Array of AI-detected patterns
  dismissed: Set<string>;           // IDs of dismissed insights
  dismiss: (id: string) => void;    // Mark insight as dismissed
  activeCount: number;              // Derived: undismissed count (shown as badge)
}
```

**Insight structure:**
```typescript
interface Insight {
  id: string;
  severity: "critical" | "warning" | "info";
  fund: string;                     // Which entity this relates to
  title: string;                    // One-line summary
  description: string;              // 2-3 sentence detail
}
```

**Aqualis has 6 insights:** 1 critical (missing quarterlies), 2 warnings (concentration risk, low TVPI), 3 info (near exit, strong performer, recent fundraise).

### Nesting Order (in layout.tsx)

```tsx
<EntityProvider>
  <InsightsProvider>
    <ExtractionProvider>
      <Header />
      <Sidebar />
      <main>{children}</main>
    </ExtractionProvider>
  </InsightsProvider>
</EntityProvider>
```

---

## 6. Mock Data Design

Mock data is **strategic, not filler.** It must look real enough that clients say "this looks like our data."

### Design Principles

1. **Use real entity names** — Plaid, Marqeta, Lenskart, not "Company A"
2. **Use realistic metrics** — TVPI of 1.38x with IRR of 15.6%, not round numbers
3. **Include edge cases** — negative EBITDA, sub-1.0x MOIC, null fields
4. **Compute derived values** — `entryValue = nav / moic`, not hardcoded
5. **Match client vocabulary** — "vintage" not "inception year", "NAV" not "value"

### Data Shape (Aqualis Pattern)

```typescript
// Level 1: Top entity (fund, deal, client, etc.)
interface ParentEntity {
  id: string;
  name: string;
  // Category fields (vintage, strategy, geography)
  // Metric fields (nav, tvpi, irr)
  // Detail fields (gpCommitment, accumulatedCarry, calledPct)
  // Timeline fields (estExitWindow)
  children: ChildEntity[];          // Nested detail items
}

// Level 2: Child entity (company, line item, claim, etc.)
interface ChildEntity {
  name: string;
  category: string;                 // Sector, type, class
  primaryMetric: number;            // NAV, amount, value
  ownershipOrWeight: number;        // Percentage of parent
  performanceMetric: number;        // MOIC, return, score
  // Financial details
  revenueLtm: number | null;
  ebitdaLtm: number | null;
  debt: number | null;
  entryValue: number | null;
  holdingPeriod: number;            // Years or months
}
```

### Volume (Aqualis Standard)

| Entity | Count | Why |
|--------|-------|-----|
| Parent entities (funds) | 7 | Enough to fill a table, demonstrate variety |
| Child entities (companies) | 26 | 3-5 per parent, enough for cards/filtering |
| Deals/projects | 3 | 1 active with data, 2 pipeline as placeholders |
| Insights | 6 | 1 critical, 2 warning, 3 info — demonstrates severity levels |
| Upload files | 8 | Enough to show extraction animation variety |

### Derived Totals (computed, not hardcoded)

```typescript
export const PORTFOLIO_SUMMARY = {
  totalNav: ENTITIES.reduce((s, e) => s + e.nav, 0),
  totalChildren: ENTITIES.reduce((s, e) => s + e.children.length, 0),
  weightedAvgMetric: (() => {
    const total = ENTITIES.reduce((s, e) => s + e.nav, 0);
    return ENTITIES.reduce((s, e) => s + e.metric * (e.nav / total), 0);
  })(),
};
```

---

## 7. The Extraction Animation Pattern

The "AI Extraction" is a **choreographed client-side animation** — no actual API calls needed for the demo. This is the core "magic trick" that makes the demo impressive.

### Components

```typescript
// 1. Classification lookup — maps known filenames to results
const CLASSIFICATIONS: Record<string, {
  docType: string;
  entity: string;
  status: "extracted" | "skipped";
}> = {
  "Process_Letter.pdf": { docType: "Process Letter", entity: "All", status: "extracted" },
  "NDA.pdf": { docType: "NDA", entity: "All", status: "skipped" },
  // ... one entry per demo file
};

// 2. Step reveals — which files get processed at each step
const STEP_REVEALS: Record<number, string[]> = {
  1: ["Process_Letter.pdf", "NDA.pdf", "Summary.xlsx"],
  2: ["Fund_A_Capital_Account.pdf", "Fund_B_Capital_Account.pdf"],
  3: ["Fund_A_Financials.pdf"],
  4: ["Fund_A_Quarterly_Report.pdf"],
  6: ["Bank_Memo.pdf"],
};

// 3. Step labels — human-readable extraction progress
const EXTRACTION_STEPS = [
  "Scanning data room structure...",
  "Identifying document types...",
  "Extracting fund-level data...",
  "Parsing quarterly financials...",
  "Extracting portfolio company details...",
  "Cross-referencing ownership data...",
  "Populating fund models...",
  "Generating company one-pagers...",
  "Extraction complete",
];
```

### Animation Mechanics

```typescript
// setInterval at 1400ms per step
// Each tick:
//   1. Classify files from PREVIOUS step (Extracting → Extracted)
//   2. Mark files for CURRENT step as "Extracting"
//   3. Update progress bar
//   4. On final step: classify all remaining, mark complete

// After completion:
//   1. Set ExtractionContext.hasExtracted = true
//   2. Show success Toast
//   3. Auto-redirect to main data page after 1.5s
```

### File Status Progression

```
Pending → Extracting → Extracted (or Skipped)
  gray      blue+spin    green check    gray dash
```

### Demo File Requirements

Create 6-8 realistic placeholder files in a folder on the Desktop:
- Name them to match `CLASSIFICATIONS` keys exactly
- Mix of PDFs and Excel files
- Override display sizes with `SIZE_OVERRIDES` for realism
- Files don't need real content — only filenames matter

---

## 8. Calculation Library Pattern

**Rule:** ALL math in one file. Pure functions. No LLM. Imported by both UI and Excel exporter.

### Structure

```typescript
// /lib/calculations/[domain]-model.ts

// 1. Constants (used in sensitivity matrices)
export const DISCOUNTS = [-0.15, -0.10, -0.05, 0, 0.05] as const;
export const MULTIPLIERS = [0.8, 0.9, 1.0, 1.1, 1.2] as const;

// 2. Entity-level functions
export function entityMetric(input1: number, input2: number): number {
  return input1 * input2;
}

// 3. Child-level functions
export function childMetric(nav: number, multiplier: number, weight: number): number {
  return nav * multiplier * (weight / 100);
}

// 4. Aggregation functions
export function portfolioMetric(entities: Entity[], multiplier: number): number {
  return entities.reduce((sum, e) => sum + entityMetric(e, multiplier), 0);
}

// 5. Sensitivity functions
export function sensitivityValue(
  children: Child[],
  discount: number,
  multiplier: number
): number {
  return children.reduce((sum, c) => {
    const adjusted = c.nav * (1 + discount);
    return sum + adjusted * multiplier * (c.weight / 100);
  }, 0);
}

// 6. Display helpers
export function impliedReturn(discount: number, multiplier: number): number {
  return (1 + discount) * multiplier - 1;
}
```

### Why This Matters

- UI components call these functions → display to user
- Excel exporter calls the SAME functions → write to spreadsheet
- **Numbers always match** — single source of truth
- Pure functions are testable, predictable, composable

---

## 9. Excel Export Pattern

### Architecture

```
/api/export/route.ts          → API endpoint (GET with ?type= param)
/lib/excel/exporter.ts        → Workbook builder (ExcelJS)
/lib/calculations/model.ts    → Shared math (imported by exporter)
/lib/mock-data/entities.ts    → Shared data (imported by exporter)
```

### Sheet Structure (Aqualis Pattern)

```
Sheet 1: Summary
  - All parent entities in one table
  - 14 columns with number formatting
  - Totals/weighted average row at bottom
  - Auto-filter, frozen first row

Sheets 2-N: One per parent entity
  - Section 1: Entity header (name, key metrics)
  - Section 2: Child entity table (12-16 columns)
  - Section 3: Sensitivity matrix (5x5 discount × multiplier grid)
```

### Style Constants (reusable)

```typescript
const NAVY: ExcelJS.Fill = {
  type: "pattern", pattern: "solid",
  fgColor: { argb: "FF1A1A2E" },
};
const HEADER_FONT: Partial<ExcelJS.Font> = {
  bold: true, color: { argb: "FFFFFFFF" }, size: 10, name: "Calibri",
};
const BODY_FONT: Partial<ExcelJS.Font> = { size: 10, name: "Calibri" };
const BORDER_THIN: Partial<ExcelJS.Borders> = {
  top: { style: "thin", color: { argb: "FFE2E8F0" } },
  bottom: { style: "thin", color: { argb: "FFE2E8F0" } },
  left: { style: "thin", color: { argb: "FFE2E8F0" } },
  right: { style: "thin", color: { argb: "FFE2E8F0" } },
};

// Conditional formatting fills
const GREEN_FILL = { type: "pattern", pattern: "solid", fgColor: { argb: "FFF0FDF4" } };
const YELLOW_FILL = { type: "pattern", pattern: "solid", fgColor: { argb: "FFFFFBEB" } };
const RED_FILL = { type: "pattern", pattern: "solid", fgColor: { argb: "FFFEF2F2" } };
```

### Number Format Reference

```typescript
// Currency:    '$#,##0'
// Percentage:  '0.0%'
// Multiple:    '0.00"x"'
// Decimal:     '0.0'
// Integer:     '0'
```

### API Route Pattern

```typescript
// CRITICAL: Use new Uint8Array(buffer) for NextResponse
export async function GET(request: NextRequest) {
  const buffer = await exportFunction();
  return new NextResponse(new Uint8Array(buffer), {
    status: 200,
    headers: {
      "Content-Type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "Content-Disposition": `attachment; filename="${filename}"`,
    },
  });
}
```

### Client-Side Download Trigger

```typescript
const handleExport = useCallback(async () => {
  setExporting(true);
  try {
    const res = await fetch("/api/export?type=full");
    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "Filename.xlsx";
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  } finally {
    setExporting(false);
  }
}, []);
```

---

## 10. Page-by-Page Architecture

### Page 1: Dashboard / Pipeline (`/`)

**Purpose:** Overview of all entities with summary stats and quick insights.

**Key elements:**
- 4 stat cards (Active count, Pipeline count, Total value, Next deadline)
- 3 most recent insights (from InsightsContext) with severity indicators
- Entity cards with: name, source, status badge, 3 metric cells, deadline badge
- Active entity gets highlighted (dark background, white text)
- "Close/Archive" button on active entities

**State dependencies:** DealContext (entity list), InsightsContext (recent insights)

### Page 2: Data Room (`/data-room`)

**Purpose:** Upload documents and run the extraction animation.

**Key elements:**
- Drag-and-drop zone (react-dropzone, hidden during extraction)
- Document table: filename, doc type badge, entity assignment, size, status
- Extraction progress panel: progress bar, 9-step checklist (3 columns), percentage
- "Run AI Extraction" button (visible when files uploaded, extraction idle)
- "Reset" button (visible when files exist or extraction complete)

**State dependencies:** ExtractionContext (markExtracted, resetExtraction), DealContext (active entity)
**Special behavior:** Auto-redirect to main data page 1.5s after extraction completes

### Page 3: Main Data Table (`/fund-model`)

**Purpose:** Primary data table with expandable rows showing child entities.

**Key elements:**
- 5 stat cards (total value, total secondary metric, weighted averages, entity count)
- Expandable table: click row → shows child entity sub-table (12 columns)
- Detail cards below sub-table (4 secondary metrics per entity)
- Totals/weighted average footer row
- "Export to Excel" button

**State dependencies:** ExtractionContext (gate), DealContext (active entity)
**Pattern:** Each row is a `<FundTableGroup>` component with toggle state via `Set<string>`

### Page 4: Detail Cards (`/companies`)

**Purpose:** Card-based view of all child entities with filtering and sorting.

**Key elements:**
- Filter bar: sort dropdown, entity filter, category filter
- Count display: "Showing X of Y"
- 2-column card grid, each card has:
  - Row 1: Name, parent entity, performance badge (large)
  - Row 2: 4 data cells (primary metric, weight, entry date, holding period)
  - Row 3: 4 data cells (revenue, EBITDA, debt, margin)
  - Row 4: 4 data cells (entry value, exit value, exit proceeds, timeline)
- "Export" button

**State dependencies:** ExtractionContext (gate), DealContext (active entity)

### Page 5: Sensitivity Analysis (`/sensitivity`)

**Purpose:** Scenario analysis with discount × multiplier matrix.

**Key elements:**
- Entity selector tabs (button group at top)
- Context line (entity name, key metrics)
- 5×5 sensitivity matrix table:
  - Rows = discount rates, Columns = exit multipliers
  - Cells = calculated values with conditional coloring
  - Center cell (par) highlighted in navy
  - Green (>20% return), Yellow (0-20%), Red (negative)
- Portfolio-level summary cards (3 scenarios)
- Quick comparisons bar chart (NAV by entity, colored by performance)

**State dependencies:** ExtractionContext (gate), DealContext (active entity)

### Page 6: Insights (`/insights`)

**Purpose:** AI-detected patterns organized by severity.

**Key elements:**
- Header with insight count badge
- Summary bar: severity counts (critical badge, warning badge, info badge)
- Insight cards with:
  - Left border colored by severity
  - Severity icon + label badge + entity pill
  - Title + description
  - Dismiss (X) button
- Dismissed count note at bottom

**State dependencies:** ExtractionContext (gate), InsightsContext (insights + dismiss)

### Empty States (2 reusable components)

```
EmptyDealState:     "Data Room Not Yet Processed" + CTA to Data Room
PendingExtraction:  "Awaiting AI Extraction" + CTA to Data Room
```

Every data page (3, 4, 5, 6) uses this gate:
```tsx
if (activeEntity.id !== primaryEntityId) return <EmptyDealState />;
if (!hasExtracted) return <PendingExtractionState />;
return <ActualContent />;
```

---

## 11. Design System Template

### Fonts
```css
/* Google Fonts link in <head> */
/* Heading: Newsreader (serif) — authoritative, institutional */
/* Body: DM Sans (sans-serif) — clean, modern, readable at small sizes */

@theme inline {
  --font-sans: "DM Sans", ui-sans-serif, system-ui, sans-serif;
  --font-heading: "Newsreader", ui-serif, Georgia, serif;
}
```

### Colors
```
Primary:     #1a1a2e (dark navy — headers, selected states, primary buttons)
Accent:      #2d5a7b (muted blue — icons, links, secondary emphasis)
Gradient:    #2d5a7b → #4a9ead (logo, accent elements)
Background:  #f8f9fb (light gray — page background)
Card:        white with border-slate-200
```

### Component Patterns
```
Stat Card:       bg-white rounded-lg border border-slate-200 px-4 py-3.5
Table Header:    bg-[#1a1a2e] text-white text-[10px] font-semibold uppercase tracking-wider
Table Cell:      text-[13px] tabular-nums, right-aligned for numbers
Badge:           text-[11px] font-medium px-2 py-0.5 rounded-full bg-[color]-50 text-[color]-700
Page Title:      text-xl font-semibold font-heading text-[#1a1a2e]
Subtitle:        text-[13px] text-slate-400
Section Label:   text-[10px] font-semibold uppercase tracking-wider text-slate-400
```

### Conditional Coloring
```
Positive (>1.3x, >20%):  text-emerald-700, bg-emerald-50
Neutral (1.0-1.3x):      text-[#1a1a2e]
Negative (<1.0x, <0%):   text-red-600, bg-red-50
Warning:                  text-amber-700, bg-amber-50
```

### Tailwind v4 Setup
```css
/* globals.css — NO tailwind.config.js needed */
@import "tailwindcss";

:root {
  --background: #f8f9fb;
  --foreground: #1a1a2e;
}

@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --font-sans: "DM Sans", ui-sans-serif, system-ui, sans-serif;
  --font-heading: "Newsreader", ui-serif, Georgia, serif;
}
```

---

## 12. Dependency Stack

| Package | Version | Purpose | Essential? |
|---------|---------|---------|------------|
| `next` | 16.x | Framework (App Router) | Yes |
| `react` | 19.x | UI | Yes |
| `typescript` | 5.x | Type safety | Yes |
| `tailwindcss` | 4.x | Styling | Yes |
| `exceljs` | 4.4.x | Excel generation (server-side) | Yes |
| `react-dropzone` | 15.x | File upload UX | Yes |
| `lucide-react` | 0.5xx | Icons | Yes |
| `framer-motion` | 12.x | Page transitions | Nice-to-have |
| `@supabase/ssr` | 0.8.x | Database client | Scaffolded |
| `@supabase/supabase-js` | 2.9x | Database client | Scaffolded |
| `@anthropic-ai/sdk` | 0.7x | AI (for future real extraction) | Scaffolded |
| `@radix-ui/*` | Various | Dialog, dropdown, progress | As needed |

**Note:** Supabase and Anthropic SDK are scaffolded but not actively used in the demo. The demo runs entirely on mock data and client-side animation.

---

## 13. Demo Flow Choreography

This is the exact sequence to show a client:

### Setup
- Prepare a folder on Desktop with 6-8 files matching `CLASSIFICATIONS` keys
- Unzip if necessary (dropzone doesn't accept ZIP)
- Start dev server: `npm run dev`

### The Demo (5 minutes)

1. **Deal Pipeline** (30s) — "Here's your deal pipeline. Three active deals, bid deadlines counting down, AI-generated insights summarized at the top."

2. **Navigate to Data Room** (10s) — "Let's process Project Alpine. Click into the Data Room."

3. **Drag files** (15s) — Drag all 8 files from Desktop folder. Files appear as "Pending" in the table.

4. **Click "Run AI Extraction"** (60s) — Watch the 9-step progress animation. Files flip from Pending → Extracting → Extracted. NDA gets "Skipped." Progress bar fills. Steps check off.

5. **Auto-redirect to Fund Model** (immediate) — "Extraction complete. Here's your fund model, fully populated."

6. **Expand a fund row** (15s) — Click QED Growth III. Shows 12-column company sub-table.

7. **Navigate to Companies** (30s) — "26 company one-pagers, sortable and filterable. Each card shows entry value, exit value, exit proceeds."

8. **Navigate to Sensitivity** (30s) — "5×5 sensitivity matrix. Green cells are upside scenarios, red are downside. All ownership-adjusted."

9. **Navigate to Insights** (15s) — "6 AI-detected insights. Missing quarterlies flagged as critical, concentration risk as warning."

10. **Export to Excel** (10s) — Click "Export to Excel" on Fund Model. Downloads 8-sheet workbook.

11. **Reset and repeat** (optional) — Click Reset on Data Room. Everything clears. Ready for another demo.

---

## 14. How to Replicate for a New Domain

### Step 1: Swap the Data Model (~30 min)
- Replace `FundDetail` / `PortfolioCompany` with domain-specific types
- Keep the parent→children nesting pattern
- Keep derived totals computation
- Design 7 parent entities, 25-30 children with realistic names and metrics

### Step 2: Swap the Calculations (~30 min)
- Replace `exit-model.ts` with domain-specific pure functions
- Keep the structure: constants → entity functions → aggregation → sensitivity
- Ensure both UI and Excel exporter import from this file

### Step 3: Swap the Extraction Animation (~20 min)
- Update `CLASSIFICATIONS` with domain-appropriate doc types
- Update `EXTRACTION_STEPS` with domain-appropriate step labels
- Create demo files with matching filenames

### Step 4: Swap the Insights (~15 min)
- Write 6 domain-appropriate insights (1 critical, 2 warning, 3 info)
- Reference specific entities by name

### Step 5: Update the Design System (~15 min)
- Change hex colors if needed (or keep navy — it works for most professional tools)
- Change fonts if needed (Newsreader + DM Sans works universally for finance/professional)
- Update "Powered by [brand]" in Sidebar

### Step 6: Update the Excel Export (~45 min)
- Adjust column headers and widths
- Adjust number formats
- Adjust sensitivity matrix parameters
- Test the download

### Step 7: Update Page Titles and Copy (~15 min)
- Page headers, subtitles, stat card labels
- Sidebar navigation labels
- Empty state text

**Total estimated time: 3-4 hours for a new domain, assuming the blueprint is complete.**

---

## 15. Gotchas & Lessons Learned

### Tailwind v4
- **No `tailwind.config.js`** — uses `@import "tailwindcss"` and `@theme inline` in CSS
- If you see Tailwind classes not applying, check that `globals.css` starts with `@import "tailwindcss"`
- Custom fonts go in `@theme inline`, not a config file

### Excel Export
- **`new Uint8Array(buffer)`** is required when creating NextResponse from ExcelJS buffer
- Sheet names max 31 chars — always use `sanitizeSheetName()`
- Number formats use Excel syntax, not JavaScript (`'$#,##0'` not `Intl.NumberFormat`)
- ExcelJS `addRow()` with objects requires `ws.columns` to be set first

### React/Next.js
- All page components are `"use client"` since they use context hooks
- `layout.tsx` is the only server component (wraps providers)
- `useCallback` for export handlers prevents re-renders
- `Set<string>` for tracking expanded/dismissed items — immutable updates via new Set()

### File Upload
- react-dropzone won't accept ZIP files — demo files must be pre-unzipped
- Override display sizes with `SIZE_OVERRIDES` for realistic file sizes in the demo
- Accept MIME types must be explicitly listed in `accept` config

### Demo Reliability
- `setInterval` at 1400ms gives enough time for visual processing
- Auto-redirect uses `setTimeout` of 1500ms after completion
- Reset function must clear: documents array, extraction state, current step, toast, and ExtractionContext
- Always have the demo folder ready before starting

---

## 16. AI Factory Template Gap Analysis

### What the AI Factory Template Has

The `templates` table stores a generic PE Due Diligence template with:
- Basic CLAUDE.md structure (What This Is, Tech Stack, Design System, Do NOT, Schema, Pages)
- Parameterized with `[Client]` placeholders
- Different design decisions from what was built (dark theme vs. light, Inter vs. Newsreader)
- 5 generic pages vs. 7 specific pages actually built

### What This Blueprint Adds

| Gap | AI Factory Template | This Blueprint |
|-----|-------------------|----------------|
| Architecture | Not specified | Three-context pattern, extraction gate, layout shell |
| Data model | Basic schema | Full TypeScript types with relationships, derived values |
| Mock data design | Not specified | 7 entities, 26 children, computed totals, edge cases |
| Extraction mechanics | "Upload → Extract" | Step-by-step animation with CLASSIFICATIONS, STEP_REVEALS |
| Calculation library | "Deterministic math" mentioned | 12 pure functions with constants, composability |
| Excel export | "Export to Excel" mentioned | 8-sheet workbook, style constants, number formats, sensitivity matrices |
| Demo choreography | Not specified | 11-step demo script with timing |
| Replication guide | Not specified | 7-step domain swap guide with time estimates |
| Gotchas | Not specified | 12 specific code-level gotchas |
| Git journey | Not tracked | 3 commits, timeline, post-demo changes |

### Recommendation

Update the AI Factory `templates` table `blueprint_template` field for `pe_due_diligence` to reference this document. The stored template should be the *CLAUDE.md for the build*, while this document should be the *architectural blueprint for replication*.

Two-level system:
1. **CLAUDE.md** (stored in templates table) — tells Claude what to build
2. **This Blueprint** (stored in Skills/) — tells a human or Claude how to replicate the pattern

---

*This blueprint is updated after each engagement that uses the document extraction pattern. Reference implementation is always Aqualis SecondaryAI.*
