# IAS Tax Return Cheatsheet (1-Page Quick Reference)

## SIGN CONVENTIONS - CHECK FIRST!
```
✓ Expenses = NEGATIVE    ✓ Credits = POSITIVE
```
**Cards needing sign flip:** Amex 21005, 12007, 71003, 42004, 51009

---

## FORM 1120 LINE MAPPING

| Line | Category | What Goes Here |
|------|----------|----------------|
| **1a** | REVENUE-* | Gross sales (match 1099-K!) |
| **2** | COGS | Inventory + Platform fees |
| **12** | OFFICER-COMP | Gusto Net + Gusto Tax |
| **13** | WAGES | Non-officer wages only |
| **16** | RENT | Rent payments |
| **17** | TAXES | Business taxes/licenses |
| **18** | INTEREST | All interest expense |
| **22** | ADV* | Advertising (Amazon PPC, etc.) |
| **23** | PENSION | 401k contributions |
| **26** | Other | Shipping, Travel, Software, Office, Insurance, Meals, Legal, Fees, Contractors |

---

## 1099-K RECONCILIATION (Gross Method)

```
Line 1a = 1099-K Total (Amazon US + Canada + Shopify)
COGS    = (1099-K Total) - (Bank Deposits) + Inventory Formula
```

**Platform Fees (~50% of gross):** Amazon referral, FBA, shipping, returns

---

## ENTITY FILTER - ALWAYS USE!
```sql
WHERE entity = 'IAS'  -- Excludes WiscAI and PERSONAL
```

---

## BALANCE TRANSFER CARDS (NOT Expenses!)

**Cards:** 1287, 1487, 2780, 5430, 9153

Only deductible: 2024 purchases, interest, fees (NOT prior year payoff)

---

## LINE 26 CATEGORIES

| Category | DB Name |
|----------|---------|
| Shipping | SHIPPING |
| Travel | TRAVEL |
| Software | SOFTWARE |
| Contractors | PAYROLL |
| Office | OFFICE |
| Insurance | INSURANCE |
| Meals (50%) | MEALS |
| Legal | LEGAL |
| Bank Fees | FEE |

---

## QUICK VERIFICATION QUERY

```sql
SELECT form_1120_line,
       SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END)::numeric(12,2) as debits
FROM transactions
WHERE entity = 'IAS' AND date >= '[YEAR]-01-01' AND date <= '[YEAR]-12-31'
  AND form_1120_line IS NOT NULL
GROUP BY form_1120_line ORDER BY form_1120_line;
```

---

## RED FLAGS

⚠️ Expenses showing as positive → **Sign flip needed**
⚠️ Line 1a doesn't match 1099-K → **IRS will send letter**
⚠️ Line 12 is $0 → **Officer wages missing**
⚠️ Balance transfer card has $60K+ → **Probably prior year payoff**

---

## AUDIT FILE NAMING

```
[ISSUER]-CARDS-AUDIT-[YEAR].md
FORM-1120-FINAL-[YEAR].md
IAS-[YEAR]-AUDIT-COMPLETE.md
BALANCE-TRANSFER-ANALYSIS-[YEAR].md
```
