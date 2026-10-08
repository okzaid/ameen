# Ameen multi-currency plan

Status: approved. Order: 1 → 3 → 4 → 2 → 5 → 6 (Option B). Option A optional.

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

## Phase 1: Base Currency setting (foundation) — done

- New **Settings → Base Currency** (e.g. AED), independent of the primary
  account. The primary account stays "default account for new transactions".
- Hooks: Cashew's single conversion function (`amountRatioToPrimaryCurrency`)
  and default display currency (`getCurrencyString`/`convertToMoney` default)
  read `baseCurrency()` instead of the primary account's currency. ~3 lines.
- Migration: existing installs start with base = current primary account's
  currency, so nothing changes until the user picks another.
- Risk: low. Test: every converted total switches when base changes; picking
  a new primary account no longer changes totals.

## Phase 2: Currency view ("lens") — done

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

Spike result (68 transaction queries in tables.dart): 15 total loops over
the account list, 14 use the shared filter, and the upcoming/overdue and
loan lists use the shared search helper. With the lens in the account list
and in both shared helpers, every report is covered (budgets' category
limits, goals and loans through the list). The rest are lookups by id,
sync, deletes and notification scheduling, which must not follow the view.
Built as:
- Home header chip "All ▾" / "₹ INR ▾" (only with 2+ currencies) opens
  Currency View: All (converted into base) or one currency with account counts.
- Switching remounts the app (`RestartApp`), so every page queries again.
- Home account cards, currency breakdown and group cards follow the view;
  the Accounts and Groups management pages keep showing every account.
- New transactions default to an account of the viewed currency.
- The view is remembered; a currency without accounts falls back to All.

## Phase 3: Foreign spend on an account — done

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

## Phase 4: Real-rate transfers between currencies — done

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

## Phase 6: Locked rates in Ameen's views (Option B, toggle)

- Setting: **Convert at the transaction's date rate** (off = today's rate everywhere).
- Every new transaction stores its rate to base at save time (from Phase 3):
  `⁣≈AED@3.672500`. Older transactions are backfilled once from the rate
  service's dated endpoints (one cached request per distinct day).
- Used by Ameen's own totals: net worth (per currency and ≈ base), group
  totals, Accounts total, currency view "All ≈" totals, per-currency budgets.
- Cashew's older charts (spending graph, pie chart, budget history) keep
  today's rate and show "≈ today's rate" while the toggle is on.
- If the base currency changes, locked values are converted once more at
  today's cross rate.
- No new upstream hooks.

### Option A (optional, later): locked rates in every Cashew total

- Per-row rate expression read from the note tag inside the ~22 total
  queries in tables.dart, same toggle. Exact everywhere, but 2–5 small
  conflicts per Cashew release that touches totals. Revisit after observing
  a couple of upstream releases.

## Order, effort, risk

| Phase | Value | Effort | Upstream hooks | Merge risk |
|---|---|---|---|---|
| 1 Base Currency | foundation | S | ~3 | low |
| 2 Currency view | very high | M | ~3 (spike first) | medium |
| 3 Foreign spend | high | M | ~4 | low |
| 4 Real-rate transfers | medium | S–M | ~2 | low |
| 5 Budgets per currency | high | M–L | ~12 | medium |
| 6 Locked rates (Option B, toggle) | high | M | 0 | very low |
| Option A (later) | medium | L | ~22 | medium–high |

Each phase ships separately with tests, a web check and an APK.
