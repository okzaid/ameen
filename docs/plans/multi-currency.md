# Ameen multi-currency plan

Status: proposed, waiting for approval. Locked historical rates are deferred
(rates are still captured on every new transaction so they can be used later).

## What Cashew already does (keep)

- Every account has a currency; every transaction is stored in its account's
  currency. Budgets, goals and category limits belong to an account
  (`walletFk`), so each already has a currency.
- Totals (budgets, charts, category totals, net worth, graphs) are computed
  per account in ~22 SQL queries and multiplied by **today's** rate into the
  primary account's currency (`amountRatioToPrimaryCurrency`).
- Daily rates come from the free fawazahmed0 currency API (cached), with
  user-defined overrides on the Exchange Rates page.

## Principles

1. **Native first.** Amounts are shown in their own currency wherever we can be
   exact. Base-currency values are secondary and labelled "≈".
2. **Account balance = what the bank charged.** Foreign spend keeps the
   original amount as information, never as the balance.
3. **No schema changes.** Extra per-transaction data goes in the hidden note
   tags we already use for location (backed up, synced, merge-safe).
4. **Few, marked hooks** into upstream; logic lives in `lib/ameen/`.

## Phase 1: Base Currency setting (foundation)

- New **Settings → Base Currency** (e.g. AED), independent of the primary
  account. The primary account stays "default account for new transactions".
- Hooks: Cashew's single conversion function (`amountRatioToPrimaryCurrency`)
  and default display currency (`getCurrencyString`/`convertToMoney` default)
  read `baseCurrency()` instead of the primary account's currency. ~3 lines.
- Migration: existing installs start with base = current primary account's
  currency, so nothing changes until the user picks another.
- Risk: low. Test: every converted total switches when base changes; picking
  a new primary account no longer changes totals.

## Phase 2: Currency view ("lens")

The key idea for "everything in each account's currency" without rewriting
Cashew's reports.

- A currency switcher on Home (chip row/app-bar menu): **All (≈ base) · AED · INR · USD**.
- Choosing **INR** makes the whole app (home widgets, budgets, pie charts,
  graphs, transaction lists, search) show only INR accounts' transactions,
  in ₹, exactly (no conversion involved).
- How (two hooks, verified by a spike before building):
  1. Most total queries loop over the app-wide account list
     (`AllWallets.list`, provided once at the app root). With a lens active,
     that list only contains accounts of the lens currency, so totals only add
     those accounts (the full index stays for lookups).
  2. Transaction lists use the shared SQL filter
     (`onlyShowIfFollowsSearchFilters`, 16 queries); it gets
     "account currency = lens".
  The display currency follows the lens (Phase 1 hook). Totals that were
  "INR → base × today's rate" become pure INR sums because the rate cancels.
- Spike first: Cashew has 77 transaction queries; the spike lists which ones
  neither loop over accounts nor use the shared filter, and decides per query.
- "All" behaves like today: everything converted to base, labelled ≈.
- Risk: medium. Needs a careful test pass of every report page with each lens.

## Phase 3: Foreign spend on an account

- Amount pad gets a **currency chip** next to the amount (default = account
  currency). Pick USD, type 20 → shows "≈ Đ73.45 at 3.6725 · tap to edit".
- Tap to correct the charged amount (from the bank statement) or the rate.
- Saved transaction: amount = charged Đ73.45 on ADCB. Hidden tag keeps the
  original: `⁣¤USD 20.00 @3.672500`.
- Display: transaction row shows "Đ73.45" with "$20.00" underneath; details
  show original, rate, and effective FX fee vs the day's rate.
- Search: "USD" finds foreign-currency spends.
- Hooks: amount pad (selectAmount), transaction row amount
  (transactionEntryAmount), save path (already hooked for location).
- Tag system generalised: one parser for all Ameen tags (location, currency,
  rate) so notes can carry several.

## Phase 4: Real-rate transfers between currencies

- Transfer popup: when the two accounts differ in currency, show **Sent**
  (Đ1,000 from ADCB) and **Received** (₹22,600 into ICICI), both editable,
  with the effective rate shown and today's rate as a hint.
- Both transactions get a tag with the counterpart amount and rate.
- Hook: Cashew's TransferBalancePopup (addWalletPage.dart), ~2 places.

## Phase 5: Budgets per currency

- A budget's currency = its account (already in Cashew). Budget editor gets a
  clear **Currency** picker (sets the budget's account to one of that
  currency) and a choice:
  - **Only ₹ transactions** (exact): budget's account filter = all INR accounts.
  - **Convert all into ₹**: every currency counts, converted at today's rate (≈).
- Budget cards, budget page and history show the budget's own currency.
- Hooks: budget amount conversion helpers (`budgetAmountToPrimaryCurrency`,
  limits, objectives) and the currency passed to their `convertToMoney`
  calls (~10–15 lines across budgetContainer/budgetPage). Highest hook count.
- Same treatment available for goals.

## Phase 6 (deferred): Locked historical rates

- Every new transaction already stores the rate to base at save time
  (`⁣≈AED@3.672500`), starting in Phase 3.
- Later, Ameen's own totals can use those rates; Cashew's SQL totals stay on
  today's rate unless we decide the merge cost is worth it.

## Order, effort, risk

| Phase | Value | Effort | Upstream hooks | Merge risk |
|---|---|---|---|---|
| 1 Base Currency | foundation | S | ~3 | low |
| 2 Currency view | very high | M | ~3 (spike first) | medium |
| 3 Foreign spend | high | M | ~4 | low |
| 4 Real-rate transfers | medium | S–M | ~2 | low |
| 5 Budgets per currency | high | M–L | ~12 | medium |
| 6 Locked rates | later | L | 0–22 | low–high |

Each phase ships separately with tests, a web check and an APK.
