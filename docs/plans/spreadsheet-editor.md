# Ameen: recent places + Daftar (spreadsheet editor)

Status: 1 done; 2 proposed (2026-10-10). Order: 1 Recent places → 2 Daftar
(built and tested on Cashew's Preview Demo data) → .mmbak import later.

## 1. Recent places (small) — done

- "Type a place" and "Rename place" show recent places as chips under the
  input; typing filters them (contains, case-insensitive); tap to fill.
- Source: a "recent places" list (max 20, newest first) in settings, updated
  when a transaction with a place is saved; seeded once from places already
  stored on transactions. Synced between devices, merged per name (like
  title → account links).
- Cost: ~1 hook line; the rest in `lib/ameen/locationTagging.dart`.

## 2. Daftar (spreadsheet editor)

Name: **Daftar** (the merchant's ledger book in Arabic, Urdu and Persian).
Link: **https://app.ameen.zaidshaikh.com/daftar**. It must live on the web
app's own address: the browser keeps the app's data per address, so another
address (e.g. a subdomain) would start empty.

A page inside the Ameen app (web at app.ameen.zaidshaikh.com; any wide
screen). Edits the same database as everything else, so links to budgets,
goals, transfers and objectives stay intact and changes reach the phone
through Google Drive sync. General-purpose: for ongoing editing of all
entries, not only import cleanup; must stay fast at any size.

### Entry points
- Link: /daftar is handled where the web app already reads link paths at
  start (Cashew's app links, e.g. /addTransaction); before onboarding the
  welcome screen shows first.
- "Daftar" in the More page and the wide-screen sidebar, shown when the
  window is ≥ 900 px wide (a phone gets a short "open on a wider screen" note).
- Optional "Open Daftar" link on ameen.zaidshaikh.com next to "Open app".

### Grid
- One row per transaction. Columns: Date & time · Title · Category ›
  Subcategory · Amount (account currency) · Account · Type (expense, income,
  transfer, upcoming, subscription, repeating, credit/debt) · Paid · Note ·
  Place · Paid-in amount/currency · Budget · Goal · Created/modified.
- Columns can be shown/hidden, reordered and resized; layout remembered.
- Virtualised rows and columns: only what's on screen is drawn, so size
  doesn't matter. Rows are loaded in pages from the database as you scroll.
- Category, account and type cells show their colour/icon like the app.
- Hidden note tags (place, paid-in, rates) are never shown raw: Note shows
  only what you wrote; Place and Paid-in have their own columns.

### Editing
- Double-click (or Enter) edits a cell: text for title/note/place, number for
  amount, pickers for category/subcategory/account/type/budget/goal, date
  picker for date.
- Edits are staged, not saved at once: changed cells are highlighted, a bar
  shows "37 changes · Save · Discard". Save writes them in one batch.
- Keyboard: arrows, Enter, Tab, Esc, Ctrl+Z/Ctrl+Y, Ctrl+A (all filtered),
  Delete (clear cell where allowed).
- Copy/paste a cell value down a selection (like Excel fill).

### Filter, search, sort
- Filter bar per column: text contains/equals/starts with/is empty; number
  range; date range; pick lists for category, account, type, paid; "has
  place", "has note", "has paid-in".
- Global search across title, note and place.
- Sort by any column; Shift-click adds a second/third sort.
- Saved views (filters + sort + columns), e.g. "Uncategorised", "Big
  expenses", "This month".
- Footer: row count, selected count, totals of the selection per currency.

### Bulk edits (on selected rows)
- Set category / subcategory / account / type / paid / budget / goal.
- Find & replace in titles, notes or places (plain or whole-word; preview).
- Set or clear the place; rename a place everywhere.
- Shift dates (± days/hours); set a date.
- Amounts: flip expense ↔ income; multiply/set (with preview).
- Delete (with confirmation).
- Every bulk edit shows a preview ("142 transactions will change", sample
  before → after) and can be undone (last 20 bulk edits while the page is
  open).

### Cleanup helpers
- Duplicates: groups of same date, amount and account with similar titles;
  keep one, delete the others, per group or all.
- Similar titles: groups like "CARREFOUR 1234", "CARREFOUR 5678" → one name;
  optional "also remember for new transactions" (title → category/account).
- Uncategorised: suggest the category most used with the same title.
- Merge categories: uses Cashew's existing merge.

### Rules that keep data safe
- Transfers: editing one side's amount/account offers to update its paired
  transaction; deleting asks about the pair (uses Cashew's pairing).
- Account change on a foreign-currency row re-converts the paid-in original
  (same logic as Add Transaction).
- Balance corrections and loan/goal links are shown but edited only through
  their own fields.
- Each saved change bumps the transaction's modified time, so Drive sync
  carries it; avoid editing the same rows on the phone at the same time
  ("latest change wins" per transaction).

### Build phases (each one shippable, demo data first)
1. Read-only grid: columns, virtual scrolling, sort, filters, search, saved
   views, selection totals. — done (editors open as dialogs on desktop)
2. Editing: cell edits, staged save/discard, keyboard, fill-down, undo.
3. Bulk edits with preview + undo; transfer/foreign-currency rules.
4. Cleanup helpers: duplicates, similar titles, uncategorised suggestions.
Later: .mmbak (Money Manager by Realbyte) importer, then clean up with this.

### Upstream / merge cost
- New code in `lib/ameen/daftar/`; one data file (`daftarData.dart`) is the
  only part that talks to Cashew's database. Hooks: the More page entry, the
  wide-screen sidebar entry and the /daftar link (~3–4 lines).
- Grid built from Flutter's own two-dimensional scrolling (no new package) to
  keep `pubspec.yaml` identical to upstream, unless performance testing shows
  a package is needed (would add one line).
- No database schema change.

### Testing
- Unit tests for filters, sort, bulk-edit planning, find & replace,
  duplicate grouping, undo.
- Browser checks on Preview Demo data (thousands of generated rows) for
  speed, editing and keyboard use; sync check on the phone after a bulk edit.
