-- =============================================================================
-- IAS TAX RETURN SQL TEMPLATES
-- =============================================================================
-- Instructions: Replace [YEAR] with current tax year (e.g., 2025)
-- Run queries in order during audit process
-- =============================================================================

-- =============================================================================
-- PHASE 1: SIGN CONVENTION VERIFICATION (RUN FIRST!)
-- =============================================================================

-- 01: Check sign distribution per card (CRITICAL)
-- Red flag: If positive_count >> negative_count for credit cards
SELECT
    card_number,
    COUNT(CASE WHEN amount > 0 THEN 1 END) as positive_count,
    COUNT(CASE WHEN amount < 0 THEN 1 END) as negative_count,
    SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END)::numeric(12,2) as positive_sum,
    SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END)::numeric(12,2) as negative_sum
FROM transactions
WHERE date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
GROUP BY card_number
ORDER BY card_number;

-- 02: FIX - Flip signs for inverted cards (UPDATE CARD LIST AS NEEDED)
-- Common offenders: Amex 21005, 12007, 71003, 42004, 51009
/*
UPDATE transactions
SET amount = -amount
WHERE card_number IN ('21005', '12007', '71003', '42004', '51009')
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31';
*/

-- =============================================================================
-- PHASE 2: IMPORT VERIFICATION
-- =============================================================================

-- 03: Card-by-card totals (compare to source files)
SELECT
    card_number,
    COUNT(*) as txn_count,
    SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END)::numeric(12,2) as debits,
    SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END)::numeric(12,2) as credits,
    SUM(amount)::numeric(12,2) as net
FROM transactions
WHERE date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
GROUP BY card_number
ORDER BY debits DESC;

-- 04: Check for duplicates
SELECT date, amount, vendor, card_number, COUNT(*)
FROM transactions
WHERE date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
GROUP BY date, amount, vendor, card_number
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;

-- =============================================================================
-- PHASE 3: CATEGORIZATION
-- =============================================================================

-- 05: Uncategorized transactions (largest first)
SELECT id, date, card_number, amount, vendor, category
FROM transactions
WHERE date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
  AND (category IS NULL OR category = '')
  AND amount < 0
ORDER BY ABS(amount) DESC
LIMIT 50;

-- 06: Category breakdown (all cards)
SELECT category, COUNT(*) as cnt, SUM(ABS(amount))::numeric(12,2) as total
FROM transactions
WHERE entity = 'IAS'
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
  AND amount < 0
GROUP BY category
ORDER BY total DESC;

-- 07: AUTO-CATEGORIZE by vendor patterns (customize as needed)
/*
UPDATE transactions SET category = 'ADV-AMZN'
WHERE vendor ILIKE '%amazon%advertising%' AND category IS NULL;

UPDATE transactions SET category = 'SOFTWARE'
WHERE vendor ILIKE '%shopify%' AND category IS NULL;

UPDATE transactions SET category = 'SHIPPING'
WHERE vendor IN ('GENEVA SUPPLY', 'ZIPSCALE', 'UPS', 'FEDEX', 'USPS')
  AND category IS NULL;
*/

-- =============================================================================
-- PHASE 4: FORM 1120 LINE ASSIGNMENTS
-- =============================================================================

-- 08: Assign form_1120_line based on category
/*
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
*/

-- 09: Verify Form 1120 line totals
SELECT
    form_1120_line,
    COUNT(*) as txn_count,
    SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END)::numeric(12,2) as debits,
    SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END)::numeric(12,2) as credits,
    (SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) -
     SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END))::numeric(12,2) as net
FROM transactions
WHERE entity = 'IAS'
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
  AND form_1120_line IS NOT NULL
GROUP BY form_1120_line
ORDER BY form_1120_line;

-- =============================================================================
-- PHASE 5: ENTITY VERIFICATION
-- =============================================================================

-- 10: Entity breakdown for multi-entity cards
SELECT card_number, entity, COUNT(*) as cnt, SUM(ABS(amount))::numeric(12,2) as total
FROM transactions
WHERE card_number IN ('21005', '12007', '71003', '7311')
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
  AND amount < 0
GROUP BY card_number, entity
ORDER BY card_number, total DESC;

-- =============================================================================
-- PHASE 6: REVENUE & 1099-K RECONCILIATION
-- =============================================================================

-- 11: Revenue by source (compare to 1099-K)
SELECT
    category,
    COUNT(*) as txn_count,
    SUM(amount)::numeric(12,2) as total
FROM transactions
WHERE entity = 'IAS'
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
  AND category LIKE 'REVENUE%'
GROUP BY category
ORDER BY total DESC;

-- 12: Revenue by month (for 1099-K matching)
SELECT
    EXTRACT(MONTH FROM date) as month,
    SUM(amount)::numeric(12,2) as revenue
FROM transactions
WHERE entity = 'IAS'
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
  AND category LIKE 'REVENUE-AMAZON%'
GROUP BY EXTRACT(MONTH FROM date)
ORDER BY month;

-- =============================================================================
-- PHASE 7: LINE 26 OTHER DEDUCTIONS
-- =============================================================================

-- 13: Line 26 breakdown (for Form 1120 attachment)
SELECT category, COUNT(*) as cnt, SUM(ABS(amount))::numeric(12,2) as total
FROM transactions
WHERE entity = 'IAS'
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
  AND form_1120_line = '26'
  AND amount < 0
GROUP BY category
ORDER BY total DESC;

-- =============================================================================
-- PHASE 8: BALANCE TRANSFER CARDS
-- =============================================================================

-- 14: Balance transfer card activity
SELECT
    card_number,
    COUNT(*) as txn_count,
    SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END)::numeric(12,2) as debits,
    SUM(CASE WHEN category = 'INTEREST' THEN ABS(amount) ELSE 0 END)::numeric(12,2) as interest,
    SUM(CASE WHEN category = 'FEE' THEN ABS(amount) ELSE 0 END)::numeric(12,2) as fees
FROM transactions
WHERE card_number IN ('1287', '1487', '2780', '5430', '9153')
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
GROUP BY card_number;

-- =============================================================================
-- PHASE 9: PAYROLL VERIFICATION
-- =============================================================================

-- 15: Payroll breakdown (Gusto)
SELECT vendor, category, COUNT(*) as cnt, SUM(ABS(amount))::numeric(12,2) as total
FROM transactions
WHERE entity = 'IAS'
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
  AND (vendor ILIKE '%gusto%' OR category LIKE '%PAYROLL%')
GROUP BY vendor, category
ORDER BY total DESC;

-- 16: FIX - Move officer wages to Line 12
/*
UPDATE transactions
SET form_1120_line = '12'
WHERE entity = 'IAS'
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
  AND category = 'EXPENSE-PAYROLL'
  AND vendor IN ('Gusto Net', 'Gusto Tax');
*/

-- 17: FIX - Move contractors to Line 26
/*
UPDATE transactions
SET form_1120_line = '26'
WHERE entity = 'IAS'
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
  AND category = 'EXPENSE-PAYROLL'
  AND vendor IN ('Gusto Cnd', 'Gusto Fee');
*/

-- =============================================================================
-- PHASE 10: FINAL VERIFICATION
-- =============================================================================

-- 18: Check for transactions without form_1120_line (should be non-deductible only)
SELECT category, COUNT(*) as cnt, SUM(ABS(amount))::numeric(12,2) as total
FROM transactions
WHERE entity = 'IAS'
  AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
  AND amount < 0
  AND form_1120_line IS NULL
  AND category NOT LIKE 'TRANSFER%'
  AND category NOT LIKE 'CC-PAYMENT%'
  AND category NOT LIKE 'LOAN-PAYMENT%'
  AND category NOT LIKE 'CREDIT%'
GROUP BY category
ORDER BY total DESC;

-- 19: Final P&L summary
SELECT
    'REVENUE' as type,
    SUM(CASE WHEN amount > 0 AND form_1120_line = '1a' THEN amount ELSE 0 END)::numeric(12,2) as amount
FROM transactions
WHERE entity = 'IAS' AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
UNION ALL
SELECT
    'EXPENSES' as type,
    SUM(CASE WHEN amount < 0 AND form_1120_line IS NOT NULL AND form_1120_line != '1a'
        THEN ABS(amount) ELSE 0 END)::numeric(12,2)
FROM transactions
WHERE entity = 'IAS' AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31';

-- =============================================================================
-- END OF TEMPLATES
-- =============================================================================
