# IAS Tax Return Playbook

**Entity:** Innovative Apparel System, Inc. (S-Corp)
**Purpose:** Complete guide for annual Form 1120 preparation
**Created:** 2026-02-01 (from 2024 tax year audit)
**Estimated Time Savings:** 2-3x faster with this playbook

---

## TABLE OF CONTENTS

1. [Pre-Audit Setup](#1-pre-audit-setup)
2. [Source File Collection](#2-source-file-collection)
3. [Database Import Process](#3-database-import-process)
4. [Sign Convention Rules](#4-sign-convention-rules)
5. [Category Mapping](#5-category-mapping)
6. [Form 1120 Line Assignments](#6-form-1120-line-assignments)
7. [Entity Allocation](#7-entity-allocation)
8. [1099-K Reconciliation](#8-1099-k-reconciliation)
9. [Balance Transfer Handling](#9-balance-transfer-handling)
10. [Audit Workflow](#10-audit-workflow)
11. [Common Pitfalls & Fixes](#11-common-pitfalls--fixes)
12. [Final Verification Queries](#12-final-verification-queries)
13. [Lessons Learned](#13-lessons-learned)

---

## 1. PRE-AUDIT SETUP

### Folder Structure
```
/Desktop/[YEAR] IAS Tax/
├── Amazon+Shopify/           # 1099-K forms
│   ├── 2024-1099K.pdf        # Amazon US
│   ├── 2024-1099K (1).pdf    # Amazon Canada
│   └── Shopify-1099K-2024.pdf
├── Amex-[YEAR]/              # 7 Amex cards
├── CapitalOne-[YEAR]/        # 3 Capital One cards
├── Chase-[YEAR]/             # Chase cards
├── Bank of America-[YEAR]/   # BofA cards
├── Barclay-[YEAR]/           # Barclays cards
├── US Bank-[YEAR]/           # US Bank cards
├── Citi-[YEAR]/              # Citi cards
├── WF-[YEAR]/                # Wells Fargo checking + LOC
├── Fidelity [YEAR]/          # Brokerage (if applicable)
├── sql/                      # Audit SQL queries
└── [Audit documentation .md files]
```

### Database Schema Requirements
```sql
-- transactions table minimum fields
CREATE TABLE transactions (
    id SERIAL PRIMARY KEY,
    date DATE NOT NULL,
    card_number VARCHAR(20),      -- Last 4 digits or account ID
    amount DECIMAL(12,2),         -- NEGATIVE = expense, POSITIVE = credit
    vendor VARCHAR(255),
    description TEXT,
    category VARCHAR(50),
    entity VARCHAR(20),           -- 'IAS', 'WiscAI', 'PERSONAL'
    form_1120_line VARCHAR(5),    -- '12', '13', '16', '18', '22', '23', '26', '1a', '2'
    deductible BOOLEAN DEFAULT true
);
```

### Master Account List (IAS)

| # | Account | Type | Card Numbers |
|---|---------|------|--------------|
| 1 | WF-1064 | IAS Checking | - |
| 2 | WF-1309 | WF BusinessLine LOC | - |
| 3 | Amex Platinum | Credit Card | 21005 |
| 4 | Amex Gold | Credit Card | 12007 |
| 5 | Amex Blue Cash | Credit Card | 71003 |
| 6 | Amex BlueBuzPlus | Credit Card | 91006 |
| 7 | Amex SimplyCash | Credit Card | 51009 |
| 8 | Amex Bonvoy | Credit Card | 42004 |
| 9 | Amex BlueBizCash | Credit Card | 61008 |
| 10 | Capital One Blue | Credit Card | 7311 |
| 11 | Capital One Green | Credit Card | 8655 |
| 12 | Capital One Green | Credit Card | 7210 |
| 13 | Chase Business | Credit Card | 9959 |
| 14 | Chase Prime | Credit Card | 9665 |
| 15 | Chase | Credit Card | 4723 |
| 16 | Barclays | Credit Card | 1287 |
| 17 | BofA | Credit Card | 1487 |
| 18 | BofA | Credit Card | 2780 |
| 19 | BofA | Credit Card | 9153 |
| 20 | US Bank | Credit Card | 5430 |
| 21 | Citi | Credit Card | 2930 |

---

## 2. SOURCE FILE COLLECTION

### Required Documents Checklist

**1099-K Forms (CRITICAL - collect by Feb 15)**
- [ ] Amazon US 1099-K
- [ ] Amazon Canada 1099-K (if applicable)
- [ ] Shopify 1099-K
- [ ] PayPal 1099-K (if applicable)
- [ ] Any other marketplace 1099-Ks

**Bank Statements**
- [ ] Wells Fargo IAS Checking - 12 monthly statements OR CSV export
- [ ] Wells Fargo LOC statements (if applicable)

**Credit Card Statements**
- [ ] All Amex cards - CSV or XLSX export preferred
- [ ] All Capital One cards - CSV export
- [ ] All Chase cards - CSV or XLSX export
- [ ] All BofA cards - CSV or XLSX export
- [ ] Barclays - CSV export
- [ ] US Bank - PDF statements
- [ ] Citi - PDF statements

**Payroll**
- [ ] Gusto annual summary
- [ ] W-2s issued
- [ ] 1099s issued to contractors

**Other**
- [ ] SBA loan statements (for interest calculation)
- [ ] Insurance premium records
- [ ] Inventory count (beginning and ending)

### File Format Preferences (in order)
1. **CSV** - Best for import, clean data
2. **XLSX** - Good, may need column mapping
3. **PDF** - Last resort, requires manual extraction

---

## 3. DATABASE IMPORT PROCESS

### Step 1: Import Credit Card Transactions

```sql
-- Example import from CSV (adjust columns per source)
COPY transactions_staging (date, description, amount, category_raw)
FROM '/path/to/file.csv'
WITH (FORMAT csv, HEADER true);

-- Transform and insert
INSERT INTO transactions (date, card_number, amount, vendor, description, entity)
SELECT
    date,
    '[CARD_NUMBER]',
    amount,  -- Check sign convention!
    description,
    description,
    'IAS'
FROM transactions_staging;
```

### Step 2: Verify Import Counts

```sql
-- After each import, verify count matches source
SELECT card_number, COUNT(*) as txn_count,
       SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as debits,
       SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as credits
FROM transactions
WHERE card_number = '[CARD]'
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
GROUP BY card_number;
```

---

## 4. SIGN CONVENTION RULES

### ⚠️ CRITICAL - Most Common Error Source

**Standard Convention (MUST verify for each card):**
- **Expenses (debits):** NEGATIVE amounts
- **Credits/Payments:** POSITIVE amounts

### Sign Convention by Issuer

| Issuer | Raw Export | Needs Flip? |
|--------|-----------|-------------|
| Amex (21005, 12007, 71003, 42004, 51009) | Expenses positive | **YES** |
| Amex (91006, 61008) | Expenses negative | No |
| Capital One | Expenses negative | No |
| Chase | Expenses negative | No |
| BofA | Expenses negative | No |
| Barclays | Expenses negative | No |
| US Bank | Expenses negative | No |
| Wells Fargo Checking | Withdrawals negative | No |

### Verification Query

```sql
-- Run BEFORE any fixes to detect inverted signs
SELECT
    card_number,
    COUNT(CASE WHEN amount > 0 THEN 1 END) as positive_count,
    COUNT(CASE WHEN amount < 0 THEN 1 END) as negative_count,
    SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as positive_sum,
    SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as negative_sum
FROM transactions
WHERE date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
GROUP BY card_number
ORDER BY card_number;
```

**Red Flag:** If positive_count >> negative_count for a credit card, signs are likely inverted.

### Fix Query (when needed)

```sql
-- Flip signs for affected cards
UPDATE transactions
SET amount = -amount
WHERE card_number IN ('[CARD1]', '[CARD2]')
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31';
```

---

## 5. CATEGORY MAPPING

### Standard Categories (Consolidated)

| Category | Description | Form 1120 Line |
|----------|-------------|----------------|
| REVENUE-AMAZON | Amazon US deposits | 1a |
| REVENUE-AMAZON-INTL | Amazon Canada/UK deposits | 1a |
| REVENUE-SHOPIFY | Shopify deposits | 1a |
| REVENUE-PAYPAL | PayPal deposits | 1a |
| REVENUE-PAYONEER | Payoneer deposits | 1a |
| REVENUE-OTHER | Other revenue | 1a |
| COGS | Inventory purchases | 2 |
| OFFICER-COMP | Officer wages (Gusto Net + Tax) | 12 |
| WAGES | Employee wages (non-officer) | 13 |
| RENT | Rent/lease payments | 16 |
| TAXES | Business taxes/licenses | 17 |
| INTEREST | Loan/credit card interest | 18 |
| ADV | Advertising (Amazon PPC, etc.) | 22 |
| ADV-AMZN | Amazon advertising specifically | 22 |
| PENSION | 401k/retirement contributions | 23 |
| SHIPPING | Outbound shipping | 26 |
| TRAVEL | Business travel | 26 |
| SOFTWARE | Software subscriptions | 26 |
| PAYROLL | Contractors (Gusto Cnd + fees) | 26 |
| OFFICE | Office supplies, telecom, dues | 26 |
| INSURANCE | Business insurance | 26 |
| MEALS | Business meals (50% deductible) | 26 |
| LEGAL | Legal/professional services | 26 |
| FEE | Bank fees, processing fees | 26 |

### Non-Deductible Categories (NULL form_1120_line)

| Category | Description |
|----------|-------------|
| TRANSFER-LOC | Line of credit draws/payments |
| TRANSFER-OWNER | Owner loan activity |
| TRANSFER-OUT | Internal transfers |
| CC-PAYMENT-* | Credit card payments |
| LOAN-PAYMENT-SBA | SBA loan principal |
| CREDIT-REWARD | Reward credits (income) |

### Auto-Categorization Rules

```sql
-- Example: Auto-categorize by vendor pattern
UPDATE transactions SET category = 'ADV-AMZN'
WHERE vendor ILIKE '%amazon%advertising%' AND category IS NULL;

UPDATE transactions SET category = 'SOFTWARE'
WHERE vendor ILIKE '%shopify%' AND category IS NULL;

UPDATE transactions SET category = 'SHIPPING'
WHERE vendor IN ('GENEVA SUPPLY', 'ZIPSCALE', 'UPS', 'FEDEX', 'USPS');

UPDATE transactions SET category = 'STORAGE'
WHERE vendor ILIKE '%storage%' OR vendor ILIKE '%northern living%';
```

---

## 6. FORM 1120 LINE ASSIGNMENTS

### Line Assignment Query

```sql
-- Bulk assign form_1120_line based on category
UPDATE transactions SET form_1120_line = '1a' WHERE category LIKE 'REVENUE%';
UPDATE transactions SET form_1120_line = '2' WHERE category = 'COGS';
UPDATE transactions SET form_1120_line = '12' WHERE category = 'OFFICER-COMP';
UPDATE transactions SET form_1120_line = '13' WHERE category = 'WAGES';
UPDATE transactions SET form_1120_line = '16' WHERE category = 'RENT';
UPDATE transactions SET form_1120_line = '17' WHERE category = 'TAXES';
UPDATE transactions SET form_1120_line = '18' WHERE category = 'INTEREST';
UPDATE transactions SET form_1120_line = '22' WHERE category LIKE 'ADV%';
UPDATE transactions SET form_1120_line = '23' WHERE category = 'PENSION';
UPDATE transactions SET form_1120_line = '26' WHERE category IN (
    'SHIPPING', 'TRAVEL', 'SOFTWARE', 'PAYROLL', 'OFFICE',
    'INSURANCE', 'MEALS', 'LEGAL', 'FEE', 'STORAGE', 'SERVICES'
);
```

### Line-by-Line Verification

```sql
-- Get totals by Form 1120 line
SELECT
    form_1120_line,
    COUNT(*) as txn_count,
    SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END)::numeric(12,2) as debits,
    SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END)::numeric(12,2) as credits
FROM transactions
WHERE entity = 'IAS'
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
  AND form_1120_line IS NOT NULL
GROUP BY form_1120_line
ORDER BY form_1120_line;
```

---

## 7. ENTITY ALLOCATION

### Multi-Entity Cards

Some cards have mixed usage (IAS, WiscAI, Personal). These MUST be reviewed transaction-by-transaction.

| Card | Entities | Allocation Method |
|------|----------|-------------------|
| 21005 (Amex Platinum) | IAS, WiscAI, Personal | Manual review |
| 12007 (Amex Gold) | IAS, Personal | Manual review |
| 71003 (Amex Blue Cash) | IAS, WiscAI, Personal | Manual review |
| 7311 (Capital One Blue) | IAS, WiscAI, Personal | Manual review |

### Entity Assignment Query

```sql
-- Check entity allocation
SELECT entity, COUNT(*) as cnt, SUM(ABS(amount))::numeric(12,2) as total
FROM transactions
WHERE card_number = '[CARD]'
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
  AND amount < 0
GROUP BY entity ORDER BY total DESC;
```

### WiscAI Exclusion

WiscAI expenses are NOT IAS deductions. Always filter by entity = 'IAS' for Form 1120.

```sql
-- IAS only totals
SELECT SUM(ABS(amount)) as ias_total
FROM transactions
WHERE entity = 'IAS'
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
  AND amount < 0;
```

---

## 8. 1099-K RECONCILIATION

### ⚠️ CRITICAL - IRS Matching

The IRS receives 1099-K forms showing GROSS sales. Your Form 1120 Line 1a must reconcile.

### Gross vs Net Method

| Method | Line 1a | COGS Treatment | IRS Match |
|--------|---------|----------------|-----------|
| **Gross (Recommended)** | 1099-K total | Include platform fees | ✅ Yes |
| Net | Deposits only | Fees already deducted | ❌ Needs attachment |

### 1099-K Collection

| Source | Expected By | Where to Find |
|--------|-------------|---------------|
| Amazon US | Feb 15 | Seller Central → Tax Documents |
| Amazon Canada | Feb 15 | Seller Central → Tax Documents |
| Shopify | Jan 31 | Settings → Taxes → 1099-K |
| PayPal | Jan 31 | PayPal Business → Tax Documents |

### Reconciliation Calculation

```
1099-K Gross Sales:
  Amazon US:        $XXX,XXX.XX
  Amazon Canada:    $X,XXX.XX
  Shopify:          $X,XXX.XX
  ─────────────────────────────
  TOTAL 1099-K:     $XXX,XXX.XX

Net Deposits (from DB):
  Amazon:           $XXX,XXX.XX
  Shopify:          $X,XXX.XX
  Other:            $XX,XXX.XX
  ─────────────────────────────
  TOTAL DEPOSITS:   $XXX,XXX.XX

Platform Fees (COGS):
  1099-K - Deposits = $XXX,XXX.XX
```

### Schedule A (COGS) for Gross Method

```
Line 1: Beginning inventory           $______
Line 2: Purchases (wire transfers)    $______
Line 3: Cost of labor                 $0
Line 4: Additional 263A costs         $0
Line 5: Other costs (PLATFORM FEES)   $______  ← 1099-K minus deposits
Line 6: Total                         $______
Line 7: Ending inventory              $______
Line 8: COGS (Line 6 - Line 7)        $______
```

---

## 9. BALANCE TRANSFER HANDLING

### ⚠️ CRITICAL - Not New Deductions

Cards with prior year 0% promotional balance transfers show large payments but minimal new expenses.

### How to Identify Balance Transfer Cards

1. **Large payments from checking** (>$5K) to a card
2. **Low transaction count** on the card itself
3. **Interest charges appearing** after promotional period ends

### Treatment

| Item | Deductible? | Where |
|------|-------------|-------|
| Prior year balance payoff | **NO** | Balance sheet only |
| 2024 purchases on card | **YES** | By category |
| 2024 interest charged | **YES** | Line 18 |
| 2024 fees charged | **YES** | Line 26 |

### Documentation Query

```sql
-- Find balance transfer card activity
SELECT
    card_number,
    COUNT(*) as txn_count,
    SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as debits,
    SUM(CASE WHEN category = 'INTEREST' THEN ABS(amount) ELSE 0 END) as interest,
    SUM(CASE WHEN category = 'FEE' THEN ABS(amount) ELSE 0 END) as fees
FROM transactions
WHERE card_number IN ('1287', '1487', '2780', '5430', '9153')
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
GROUP BY card_number;
```

---

## 10. AUDIT WORKFLOW

### Phase 1: Data Collection (Day 1)

- [ ] Create year folder structure
- [ ] Download all 1099-K forms
- [ ] Download all bank/card statements (CSV preferred)
- [ ] Request Gusto payroll summary

### Phase 2: Database Import (Day 1-2)

- [ ] Import checking account transactions
- [ ] Import each credit card (verify count after each)
- [ ] Run sign convention check
- [ ] Fix any inverted signs

### Phase 3: Categorization (Day 2-3)

- [ ] Run auto-categorization queries
- [ ] Review uncategorized transactions
- [ ] Assign form_1120_line values
- [ ] Review entity allocations on mixed cards

### Phase 4: Card-by-Card Audit (Day 3-4)

For each card:
```sql
-- Source vs DB comparison
SELECT
    COUNT(*) as db_count,
    SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as db_debits
FROM transactions
WHERE card_number = '[CARD]'
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31';
```

- [ ] Amex cards (7) - verify against source CSVs
- [ ] Capital One cards (3) - verify against source
- [ ] Chase cards - verify against source
- [ ] Other cards - verify against source

### Phase 5: 1099-K Reconciliation (Day 4)

- [ ] Sum all 1099-K gross amounts
- [ ] Sum all deposit revenues from DB
- [ ] Calculate platform fees (gross - net)
- [ ] Decide gross vs net method
- [ ] Prepare Schedule A if gross method

### Phase 6: Form 1120 Line Verification (Day 5)

- [ ] Run line totals query
- [ ] Compare to prior year (reasonableness check)
- [ ] Verify officer compensation (Line 12)
- [ ] Verify wages (Line 13)
- [ ] Build Line 26 attachment

### Phase 7: Final Review (Day 5)

- [ ] Check for NULL form_1120_line (should be non-deductible only)
- [ ] Verify entity = 'IAS' filter applied
- [ ] Cross-check checking payments vs card expenses
- [ ] Document any open items for accountant

---

## 11. COMMON PITFALLS & FIXES

### Pitfall 1: Sign Convention Inverted
**Symptom:** Totals way off, positive amounts for expenses
**Fix:** Flip signs with UPDATE SET amount = -amount

### Pitfall 2: 1099-K Mismatch
**Symptom:** IRS inquiry letter
**Fix:** Use gross method, match 1099-K on Line 1a

### Pitfall 3: Balance Transfers Counted as Expenses
**Symptom:** Expenses inflated by $60K+
**Fix:** Only count 2024 activity (purchases, interest, fees)

### Pitfall 4: Mixed Entity Cards
**Symptom:** WiscAI or Personal expenses in IAS totals
**Fix:** Review and tag entity on each transaction

### Pitfall 5: Officer Wages on Wrong Line
**Symptom:** Line 12 empty, Line 13 too high
**Fix:** Separate Gusto Net/Tax (officer) from contractors

### Pitfall 6: Credits Stored as Negative
**Symptom:** Net amounts incorrect
**Fix:** Credits should be POSITIVE, expenses NEGATIVE

### Pitfall 7: Missing Interest Deductions
**Symptom:** Line 18 too low
**Fix:** Check all cards for INTEREST category, assign Line 18

### Pitfall 8: Duplicate Transactions
**Symptom:** Totals higher than source
**Check:**
```sql
SELECT date, amount, vendor, COUNT(*)
FROM transactions
WHERE card_number = '[CARD]'
GROUP BY date, amount, vendor
HAVING COUNT(*) > 1;
```

---

## 12. FINAL VERIFICATION QUERIES

### Master Verification Query

```sql
-- Complete Form 1120 line summary
SELECT
    form_1120_line,
    COUNT(*) as txn_count,
    SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END)::numeric(12,2) as credits,
    SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END)::numeric(12,2) as debits,
    (SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) -
     SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END))::numeric(12,2) as net
FROM transactions
WHERE entity = 'IAS'
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
  AND form_1120_line IS NOT NULL
GROUP BY form_1120_line
ORDER BY form_1120_line;
```

### Uncategorized Check

```sql
-- Should return minimal results
SELECT category, COUNT(*), SUM(ABS(amount))
FROM transactions
WHERE entity = 'IAS'
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
  AND amount < 0
  AND (form_1120_line IS NULL OR category IS NULL)
  AND category NOT LIKE 'TRANSFER%'
  AND category NOT LIKE 'CC-PAYMENT%'
GROUP BY category ORDER BY SUM(ABS(amount)) DESC;
```

### Line 26 Breakdown

```sql
-- For Form 1120 attachment
SELECT category, COUNT(*) as cnt, SUM(ABS(amount))::numeric(12,2) as total
FROM transactions
WHERE entity = 'IAS'
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
  AND form_1120_line = '26'
  AND amount < 0
GROUP BY category ORDER BY total DESC;
```

### Revenue by Source

```sql
-- Verify against 1099-Ks
SELECT
    category,
    COUNT(*) as txn_count,
    SUM(amount)::numeric(12,2) as total
FROM transactions
WHERE entity = 'IAS'
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
  AND category LIKE 'REVENUE%'
GROUP BY category ORDER BY total DESC;
```

---

## 13. LESSONS LEARNED

### From 2024 Audit

1. **Check sign conventions FIRST** - Before any analysis, verify each card has correct signs. Amex cards especially need checking.

2. **1099-K gross method prevents IRS letters** - Match Line 1a to 1099-K totals, put platform fees in COGS.

3. **Balance transfers are NOT expenses** - Large checking payments to cards may be paying off prior year debt, not new expenses.

4. **Gusto requires splitting:**
   - Gusto Net + Tax → Line 12 (Officer)
   - Gusto Cnd + Fee → Line 26 (Contractors)

5. **Credits reduce net, not add to expenses** - Track credits separately and subtract from gross to get net deduction.

6. **Entity allocation is critical** - WiscAI and Personal expenses must be excluded from IAS Form 1120.

7. **Document everything** - Create audit MD files for each card group. Future you will thank present you.

8. **Source file naming matters** - Keep consistent naming: `[Issuer]-[Last4]-[Year].csv`

9. **Run verification queries after EVERY fix** - Don't assume the UPDATE worked.

10. **Platform fees are huge (~$326K on $618K gross)** - Amazon/Shopify take ~50%+ in fees before deposit.

### Time Savers for Next Year

1. **Use this playbook** - Don't reinvent the wheel
2. **Auto-categorize early** - Set up vendor patterns before manual review
3. **Verify signs immediately** - Fix before any other work
4. **Collect 1099-Ks first** - They drive the reconciliation
5. **Keep running totals** - Update as you go, don't recalculate

---

## APPENDIX A: SQL FILE TEMPLATE

Save as `/[YEAR] IAS Tax/sql/01-verify-imports.sql`:

```sql
-- 01: Verify all imports
-- Run after importing all sources

-- Card-by-card totals
SELECT
    card_number,
    COUNT(*) as txn_count,
    SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END)::numeric(12,2) as debits,
    SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END)::numeric(12,2) as credits
FROM transactions
WHERE date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
GROUP BY card_number
ORDER BY debits DESC;
```

---

## APPENDIX B: CHECKLIST TEMPLATE

```markdown
# IAS [YEAR] Tax Audit Checklist

## Data Collection
- [ ] 1099-K: Amazon US
- [ ] 1099-K: Amazon Canada
- [ ] 1099-K: Shopify
- [ ] Bank: WF Checking (12 months)
- [ ] Card: Amex (7 cards)
- [ ] Card: Capital One (3 cards)
- [ ] Card: Chase
- [ ] Card: BofA
- [ ] Card: Others
- [ ] Payroll: Gusto summary

## Import Verification
- [ ] Sign conventions verified
- [ ] Transaction counts match source
- [ ] Totals match source

## Categorization
- [ ] Auto-categorization run
- [ ] Manual review complete
- [ ] Form 1120 lines assigned
- [ ] Entity allocation reviewed

## Reconciliation
- [ ] 1099-K totals calculated
- [ ] Deposit totals calculated
- [ ] Platform fees calculated
- [ ] COGS method decided

## Final Verification
- [ ] All lines verified
- [ ] Line 26 breakdown created
- [ ] Audit documentation complete
- [ ] Ready for accountant
```

---

## APPENDIX C: FORM 1120 TEMPLATE

```
FORM 1120 - IAS [YEAR]

INCOME
Line 1a: Gross receipts (1099-K)     $___________
Line 1c: Balance                      $___________
Line 2:  COGS                         $___________
Line 3:  Gross profit                 $___________
Line 11: Total income                 $___________

DEDUCTIONS
Line 12: Officer compensation         $___________
Line 13: Salaries and wages           $___________
Line 16: Rents                        $___________
Line 17: Taxes and licenses           $___________
Line 18: Interest                     $___________
Line 22: Advertising                  $___________
Line 23: Pension                      $___________
Line 26: Other deductions             $___________
Line 27: Total deductions             $___________

Line 30: Taxable income               $___________
```

---

**End of Playbook**

*Last Updated: 2026-02-01*
*Based on: IAS 2024 Tax Year Audit*
