# Claude Code Prompt: MOJO Money App

## Project Overview

Build **MOJO Money** — a native macOS and iOS app that extends and automates Monarch Money with powerful modules that Monarch doesn't natively support. MOJO Money is designed as a modular platform; each module targets a specific automation gap.

**Module 1 (build this now):** Monarch HD Sync — enriches Monarch Money transactions with itemized line-item detail from Home Depot Pro purchase history exports.

Future modules (scaffold the architecture for these but don't build yet):
- Module 2: Monarch Lowes Sync
- Module 3: Monarch Email Receipt Sync (Gmail-based)
- Module 4: Monarch Project Cost Tracker (job costing across merchants)
- Module 5: Monarch Report Builder (custom PDF reports)

Create a GitHub repository named `mojo-money` and push the initial project to it.

---

## Brand & Design Language

**App Name:** MOJO Money  
**Tagline:** "Monarch, on autopilot."  
**Icon concept:** A stylized "M" with a lightning bolt — suggesting automation and momentum.

### Visual Design — Mirror Monarch Money's Aesthetic
Monarch Money uses a clean, modern financial UI:
- **Primary accent:** Teal/mint `#00C6AE` (match Monarch's brand color exactly)
- **Background:** Deep navy `#0F1923` (dark mode) / off-white `#F5F7FA` (light mode)
- **Card surface:** `#1C2B38` (dark) / `#FFFFFF` (light)
- **Text primary:** `#FFFFFF` (dark) / `#0F1923` (light)
- **Text secondary:** `#8A9BB0`
- **Success/positive:** `#34D399`
- **Warning:** `#FBBF24`
- **Destructive/negative:** `#F87171`
- **Typography:** SF Pro (system font) — `.largeTitle`, `.title2`, `.headline`, `.subheadline`, `.caption`
- **Cards:** RoundedRectangle cornerRadius 16, subtle shadow (opacity 0.08, radius 12)
- **Buttons:** Filled teal primary, ghost outline secondary, destructive red tertiary
- **Spacing:** 8pt grid system throughout

### App Icon & Branding
- App icon: Deep navy background, teal "M" with lightning bolt accent
- Use the name "MOJO Money" in the app header/title bar
- Subtle MOJO logo mark (just the M+bolt) in sidebar/tab bar header

---

## Tech Stack

- **UI:** SwiftUI (universal — macOS + iOS from one codebase using `#if os(macOS)` where needed)
- **Minimum targets:** macOS 14 (Sonoma), iOS 17
- **Backend/logic:** Python 3.11+ called via subprocess with JSON stdin/stdout (do NOT use PythonKit)
- **Monarch API:** `monarchmoney` Python library (`pip install monarchmoney`)
- **Local storage:** SQLite via Swift's built-in `sqlite3` + a thin Swift wrapper
- **Keychain:** Native `Security` framework for credentials
- **GitHub:** `gh repo create mojo-money --public`

---

## Architecture — Modular Platform

The app is architected so new sync modules can be added with minimal boilerplate. Each module conforms to a `MOJOModule` protocol:

```swift
protocol MOJOModule {
    var id: String { get }              // e.g. "hd-sync"
    var displayName: String { get }     // e.g. "HD Sync"
    var icon: String { get }            // SF Symbol name
    var accentColor: Color { get }
    var isEnabled: Bool { get }
    var statusSummary: String { get }   // e.g. "Last synced 2 hours ago"
    
    func makeContentView() -> AnyView
    func makeSettingsView() -> AnyView
}
```

Each module lives in its own folder under `Modules/[ModuleName]/` with its own SwiftUI views, models, and Python backend.

### Python Backend Structure
Each module has its own Python package under `python/modules/[module_name]/`. The shared bridge interface is:

```bash
python3 python/mojo_runner.py --module hd_sync --action <action> --payload payload.json
```

Response is always JSON on stdout:
```json
{
  "success": true,
  "action": "parse_csv",
  "data": { ... },
  "error": null
}
```

---

## Project File Structure

```
mojo-money/
├── README.md
├── LICENSE (MIT)
├── .gitignore
├── MojoMoney.xcodeproj/
├── MojoMoney/                          # SwiftUI App Target
│   ├── App/
│   │   ├── MojoMoneyApp.swift
│   │   └── AppState.swift              # ObservableObject, global state
│   ├── Core/
│   │   ├── MOJOModule.swift            # Protocol definition
│   │   ├── ModuleRegistry.swift        # Registers all enabled modules
│   │   ├── PythonBridge.swift          # subprocess caller + JSON encode/decode
│   │   ├── KeychainService.swift       # Credential storage
│   │   ├── DatabaseService.swift       # SQLite wrapper
│   │   └── MonarchService.swift        # Shared Monarch API Swift calls
│   ├── Shared/
│   │   ├── Views/
│   │   │   ├── ContentView.swift       # Root NavigationSplitView / TabView
│   │   │   ├── DashboardView.swift     # Module cards overview
│   │   │   ├── SettingsView.swift      # Global settings (Monarch auth)
│   │   │   └── OnboardingView.swift    # First-launch flow
│   │   └── Components/
│   │       ├── MOJOButton.swift        # Styled button variants
│   │       ├── StatCard.swift          # Dashboard stat tile
│   │       ├── TransactionRow.swift    # Monarch-style transaction row
│   │       ├── StatusBadge.swift       # ✅ ⚠️ ❌ status indicator
│   │       ├── SectionHeader.swift     # Styled section headers
│   │       └── EmptyStateView.swift    # Consistent empty states
│   └── Modules/
│       ├── HDSync/                     # Module 1 — built now
│       │   ├── HDSyncModule.swift      # MOJOModule conformance
│       │   ├── Views/
│       │   │   ├── HDSyncDashboard.swift
│       │   │   ├── HDImportView.swift
│       │   │   ├── HDMatchView.swift
│       │   │   ├── HDSyncPreviewView.swift
│       │   │   ├── HDHistoryView.swift
│       │   │   └── HDSettingsView.swift
│       │   └── Models/
│       │       ├── HDTransaction.swift
│       │       ├── HDLineItem.swift
│       │       ├── MatchResult.swift
│       │       └── SyncRun.swift
│       ├── LowesSync/                  # Module 2 — stub only
│       │   └── LowesSyncModule.swift   # "Coming Soon" placeholder
│       ├── EmailSync/                  # Module 3 — stub only
│       │   └── EmailSyncModule.swift
│       ├── ProjectTracker/             # Module 4 — stub only
│       │   └── ProjectTrackerModule.swift
│       └── ReportBuilder/             # Module 5 — stub only
│           └── ReportBuilderModule.swift
├── python/
│   ├── mojo_runner.py                  # Main entry point / dispatcher
│   ├── requirements.txt                # monarchmoney, pandas
│   ├── shared/
│   │   ├── monarch_client.py           # monarchmoney wrapper
│   │   └── db.py                       # SQLite history logger
│   └── modules/
│       ├── hd_sync/
│       │   ├── __init__.py
│       │   ├── csv_parser.py
│       │   ├── matcher.py
│       │   ├── enricher.py
│       │   └── sync_runner.py
│       ├── lowes_sync/                 # stub
│       │   └── __init__.py
│       └── email_sync/                 # stub
│           └── __init__.py
└── scripts/
    ├── setup.sh                        # pip install -r requirements.txt
    └── create_github_repo.sh           # gh repo create + git push
```

---

## App Navigation

### macOS — NavigationSplitView
```
Sidebar                    Detail
─────────────────────      ─────────────────────────────────────
MOJO Money [M⚡]           [Module content]
─────────────────────
Dashboard
─────────────────────
MODULES
  ⚡ HD Sync         ←── Module 1 (active)
  🏗 Lowes Sync      ←── Coming Soon badge
  📧 Email Sync      ←── Coming Soon badge
  📊 Project Tracker ←── Coming Soon badge
  📄 Report Builder  ←── Coming Soon badge
─────────────────────
  ⚙ Settings
```

### iOS — TabView
```
[Dashboard] [HD Sync] [···More] [Settings]
```

---

## Dashboard Screen

Shows module cards in a 2-column grid (macOS) or vertical stack (iOS):

```
┌─────────────────────────────────────────────────┐
│  MOJO Money                          ⚙          │
│  "Monarch, on autopilot."                        │
├─────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐       │
│  │ ⚡ HD Sync       │  │ 🏗 Lowes Sync   │       │
│  │                 │  │                 │       │
│  │ 47 matched      │  │   Coming Soon   │       │
│  │ Last: 2hr ago   │  │                 │       │
│  │ [Open →]        │  │ [Learn More]    │       │
│  └─────────────────┘  └─────────────────┘       │
│  ┌─────────────────┐  ┌─────────────────┐       │
│  │ 📧 Email Sync   │  │ 📊 Project Cost │       │
│  │   Coming Soon   │  │   Coming Soon   │       │
│  └─────────────────┘  └─────────────────┘       │
├─────────────────────────────────────────────────┤
│  Monarch Connection    ● Connected               │
│  Last sync: Today 5:20 AM                       │
└─────────────────────────────────────────────────┘
```

---

## Settings Screen (Global)

Monarch Money connection section:
- Email field
- Password field (SecureField, stored in Keychain under `com.mojomoney.monarch.credentials`)
- MFA token field (ephemeral, not stored)
- [Connect] / [Disconnect] button with connection status indicator
- Note displayed: "Requires Monarch password login. If you use Google SSO, set a password in Monarch Settings → Security first."

Python environment section:
- Python path (auto-detected, override field)
- [Verify Environment] button — runs `python3 -c "import monarchmoney; print('OK')"` and shows result
- [Install Dependencies] button — runs `pip install -r requirements.txt` in a sheet with live output

---

## Module 1: Monarch HD Sync — Full Implementation

### HD Sync Module Dashboard
```
┌─────────────────────────────────────────────────┐
│ ⚡ HD Sync                                       │
│ Enrich Monarch transactions with Home Depot      │
│ Pro purchase details                             │
├─────────────────────────────────────────────────┤
│  [Import CSVs]   [Match]   [Sync Preview]        │
├────────────┬────────────┬────────────┬──────────┤
│ 82         │ 311        │ 47         │ $47,820  │
│ Orders     │ Line Items │ Matched    │ Enriched │
└────────────┴────────────┴────────────┴──────────┘
```

### Data Inputs — Home Depot Pro CSV Format

The app ingests two CSV exports from the Home Depot Pro Purchase Tracking portal.

**IMPORTANT:** Both CSVs have a 6-line metadata header before the actual column headers. Use `skiprows=6` in pandas.

#### Summary CSV Headers:
```
Date, Receipt Added Date, Order Origin, Purchaser/Buyer Name-ID, Transaction ID,
Register Number, Job Name, Program Disc Amt, Other Disc, Pre-tax Amount,
Total Amount Paid, Order Number, Payment, Text2Confirm, Card/Account Nickname, Invoice Number
```

Key fields:
- `Date` — purchase date (YYYY-MM-DD)
- `Total Amount Paid` — string like `"$1,430.43"` or `"-$345.72"` (negatives = returns)
- `Order Number` — e.g. `WH27744341` (online) or blank (in-store)
- `Job Name` — project label (e.g. "Riverhouse", "OBERG") — becomes a Monarch tag
- `Order Origin` — `"online"` or store string like `"#6332, Crystal River"`
- `Payment` — card last-4 alias e.g. `X-4515`, `X-8727`, `X-0305`
- `Invoice Number` — receipt number

#### Details CSV Headers:
```
Date, Store Number, Transaction ID, Register Number, Job Name, SKU Number,
SKU Description, Quantity, Unit price, Department Name, Class Name, Subclass Name,
Program Discount Amount, Program Discount Indicator, Other Discount Amount,
Extended Retail (before discount), Net Unit Price, Internet SKU, Purchaser,
Order Number, Invoice Number
```

Key fields:
- `Order Number` — foreign key to Summary CSV
- `SKU Description` — full item description
- `Quantity` — skip rows where Quantity = 0 (wish-list items)
- `Net Unit Price` — price per unit (strip `$`, `,`, parse as float)
- `Extended Retail (before discount)` — line item subtotal
- `Department Name` — ELECTRICAL, LUMBER, PLUMBING, HARDWARE, BLDG. MATERIALS, etc.
- `Job Name` — project name

#### Parsing Rules:
- Strip `$` and `,` from all dollar strings before float conversion
- Negative amounts = returns — flag and handle separately
- Skip Details rows where Quantity == 0 (saved/wish-list items with $0.00 values)
- For in-store transactions (blank Order Number in Summary): match Details by Date + Invoice Number
- One Order Number in Summary maps to multiple Detail rows — join on `Order Number`

### Transaction Matching Logic

Match each HD Summary row to a Monarch transaction:

1. Pull Monarch transactions filtered to the CSV date range via `get_transactions`
2. Pre-filter Monarch transactions where merchant contains "Home Depot", "HOMEDEPOT", "HD ", or "THE HOME DEPOT"
3. Match on:
   - **Amount:** `abs(hd_total - monarch_amount) <= 0.02`
   - **Date window:** `abs((hd_date - monarch_date).days) <= 3`
4. Classify results:
   - ✅ **Matched** — exactly one Monarch transaction satisfies both criteria
   - ⚠️ **Ambiguous** — multiple Monarch candidates (same amount, nearby dates) — require user selection
   - ❌ **Unmatched** — no candidate found — display HD row with reason

Display in a table sorted by date descending. Allow manual override of any match.

Edge cases to handle:
- Same-day multiple transactions of similar amounts → show as ambiguous
- Returns (negative HD amounts) → match to credit/refund Monarch transactions
- In-store transactions without Order Number → match by Invoice Number + amount
- Split shipments → one HD order charged across multiple Monarch transactions on different dates — detect and flag

### Enrichment — What Gets Written to Monarch

For each confirmed match, call `update_transaction` and `set_transaction_tags`.

#### Notes Format:
```
⚡ Home Depot | Riverhouse | WH27744341
📦 13 items · $1,430.43 · Crystal River #6332

ELECTRICAL
  · QO 200A Indoor Load Center (LP620-BPD) ×1 — $388.50
  · QO 200A Outdoor Enclosure ×2 — $418.00
  · 66-Space Load Center Cover (LDC66-W) ×1 — $173.33
  · 3/4" x 100ft ENT Conduit (Blue) ×2 — $132.00
  + 9 more items

🔗 WH27744341 · Inv: 5956995 · Card: X-0305
```

Notes construction rules:
- Group line items by `Department Name`
- Within each department, sort by `Extended Retail` descending
- Show top items per department; if total items > 8, show top 8 then `+ N more items`
- Always include: Job Name, Order Number, Invoice Number, Card alias, Store/Origin
- Target under 900 characters (Monarch note limit is ~1,000); truncate gracefully
- If Monarch transaction already has notes containing "Home Depot" or "⚡" — append new content rather than overwrite, with a `\n---\n` separator

#### Tags to Apply:
- `Home Depot Receipt` — always
- `HD-[JobName]` — e.g. `HD-Riverhouse`, `HD-OBERG` (normalize: strip spaces, title case)
- `[PrimaryDepartment]` — the department with highest total spend in that transaction (e.g. `Electrical`, `Lumber`)

Before creating any tag, call `get_transaction_tags` and check for existing match (case-insensitive) to avoid duplicates.

### HD Sync Screens

#### Import Screen
```
┌─────────────────────────────────────────────────┐
│  ⚡ HD Sync — Import                             │
│                                                 │
│  ┌───────────────────┐  ┌───────────────────┐   │
│  │  Summary CSV      │  │  Details CSV      │   │
│  │                   │  │                   │   │
│  │  Drop file here   │  │  Drop file here   │   │
│  │  or [Browse]      │  │  or [Browse]      │   │
│  │                   │  │                   │   │
│  │  ✅ 82 orders     │  │  ✅ 311 items     │   │
│  │  Mar 2024–Apr 2026│  │                   │   │
│  └───────────────────┘  └───────────────────┘   │
│                                                 │
│  Parsed: 82 transactions · 311 line items        │
│  Cards: X-4515 · X-8727 · X-0305               │
│  Jobs: Riverhouse · OBERG                       │
│                                                 │
│             [Preview Transactions →]            │
└─────────────────────────────────────────────────┘
```

#### Match Screen
List of HD transactions with match status. Each row:
- Left: HD orange circle icon, Order # or "In-Store"
- Center: Date · Store/Origin · Job Name
- Right: Amount (teal = matched, gray = unmatched, amber = ambiguous)
- Tap/click to expand: shows proposed Monarch match details and line item preview

Toolbar: `[Match All]` `[Clear]` `[Filter: All ▾]`

#### Sync Preview Screen
Split view:
- Left panel (gray): Current Monarch transaction state
- Right panel (teal highlight): Proposed enriched state
- Diff highlighting for new content being added
- Summary bar: "47 transactions will be updated · 3 new tags will be created"
- `[Dry Run — Export Preview]` `[Apply All]` `[Apply Selected]`

#### History Screen
Table of all past sync runs:
- Columns: Date/Time, Orders Processed, Matched, Applied, Status
- Expandable rows showing individual transaction results
- Search by Order Number or date
- `[Re-sync Selected]` for failed items

### Sync History — SQLite Schema

```sql
CREATE TABLE sync_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    module TEXT NOT NULL,                    -- 'hd_sync'
    orders_processed INTEGER,
    matched INTEGER,
    applied INTEGER,
    status TEXT                              -- 'completed', 'partial', 'failed'
);

CREATE TABLE sync_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id INTEGER REFERENCES sync_runs(id),
    hd_order_number TEXT,
    hd_invoice_number TEXT,
    hd_amount REAL,
    hd_date TEXT,
    monarch_transaction_id TEXT,
    monarch_amount REAL,
    status TEXT,                             -- 'matched', 'ambiguous', 'unmatched', 'applied', 'skipped'
    notes_written TEXT,
    tags_applied TEXT,
    error TEXT
);

CREATE INDEX idx_hd_order ON sync_results(hd_order_number);
CREATE INDEX idx_monarch_tx ON sync_results(monarch_transaction_id);
```

Idempotency rule: Before applying enrichment, check if `(hd_order_number, monarch_transaction_id)` already exists with `status = 'applied'` in `sync_results`. If so, skip unless user explicitly forces re-sync.

---

## Python Backend — Full Spec

### `python/mojo_runner.py` — Main Dispatcher
```python
# Entry point: reads --module, --action, --payload from args
# Routes to appropriate module handler
# Always outputs JSON to stdout
# Handles exceptions and outputs error JSON
```

### `python/shared/monarch_client.py`
Thin wrapper around `monarchmoney`:
- `authenticate(email, password, mfa_token=None)` → returns session token
- `get_transactions(start_date, end_date, search="Home Depot")` → list of dicts
- `update_transaction(transaction_id, notes=None, category_id=None)` → success bool
- `get_or_create_tag(name)` → tag_id
- `set_tags(transaction_id, tag_ids)` → success bool

### `python/modules/hd_sync/csv_parser.py`
- `parse_summary(filepath)` → list of HDTransaction dicts
- `parse_details(filepath)` → list of HDLineItem dicts
- `join(summary, details)` → list of HDTransaction with embedded line items
- Handles: skiprows=6, dollar string cleaning, zero-quantity row filtering, return detection

### `python/modules/hd_sync/matcher.py`
- `match_transactions(hd_transactions, monarch_transactions)` → list of MatchResult dicts
- Each MatchResult: `{hd_order, monarch_tx, status, confidence, candidates}`

### `python/modules/hd_sync/enricher.py`
- `build_notes(hd_transaction_with_items)` → str (max 900 chars)
- `build_tags(hd_transaction_with_items)` → list of tag name strings
- Groups by department, sorts by value, truncates gracefully

### `python/modules/hd_sync/sync_runner.py`
- `run(payload)` → orchestrates parse → match → enrich → (dry run or apply)
- Returns full result JSON including preview data

---

## Python Actions Interface

### `parse_csv`
Input:
```json
{
  "summary_csv_path": "/path/to/summary.csv",
  "details_csv_path": "/path/to/details.csv"
}
```
Output:
```json
{
  "success": true,
  "data": {
    "transaction_count": 82,
    "line_item_count": 311,
    "date_range": {"from": "2024-03-13", "to": "2026-04-13"},
    "cards": ["X-4515", "X-8727", "X-0305"],
    "job_names": ["Riverhouse", "OBERG"],
    "transactions": [ ... ]
  }
}
```

### `get_monarch_transactions`
Input: `{"date_from": "...", "date_to": "...", "session_token": "..."}`
Output: `{"success": true, "data": {"transactions": [...]}}`

### `match`
Input: `{"hd_transactions": [...], "monarch_transactions": [...]}`
Output: `{"success": true, "data": {"results": [...], "matched": 47, "ambiguous": 3, "unmatched": 32}}`

### `dry_run`
Input: `{"matches": [...], "session_token": "..."}`
Output: Full preview of changes without writing anything

### `apply`
Input: `{"matches": [...], "session_token": "...", "dry_run": false}`
Output: Results of each write operation

---

## Onboarding Flow (First Launch)

Three-step sheet shown on first launch:

**Step 1 — Welcome**
- MOJO Money logo + name
- "Monarch, on autopilot."
- Brief description of what MOJO does
- [Get Started →]

**Step 2 — Connect Monarch**
- Email + Password + MFA fields
- "Your credentials are stored securely in your Mac/iPhone Keychain and never leave your device."
- [Connect] with spinner, then ✅ Connected
- Note about Google SSO requirement

**Step 3 — Choose First Module**
- Module cards (HD Sync highlighted, others grayed as Coming Soon)
- [Open HD Sync →]

---

## README Contents

The README must include:

```markdown
# MOJO Money

> Monarch, on autopilot.

Native macOS and iOS app that extends Monarch Money with powerful automation
modules. Built for people who want their financial data to work as hard as they do.

## Modules

| Module | Status | Description |
|--------|--------|-------------|
| ⚡ HD Sync | ✅ Available | Enrich Monarch transactions with Home Depot Pro purchase details |
| 🏗 Lowes Sync | 🚧 Coming Soon | Same for Lowe's Pro |
| 📧 Email Sync | 🚧 Coming Soon | Auto-match email receipts to transactions |
| 📊 Project Tracker | 🚧 Coming Soon | Job costing across merchants |
| 📄 Report Builder | 🚧 Coming Soon | Custom PDF financial reports |

## Requirements
- macOS 14 (Sonoma) or iOS 17+
- Xcode 15+
- Python 3.11+
- Monarch Money account (password auth required — not Google SSO)

## Setup
[step-by-step instructions]

## How to Export from Home Depot Pro
[Purchase Tracking export walkthrough]

## Privacy
All data stays on your device. Credentials are stored in Keychain.
No telemetry. No cloud sync. Just you and your finances.

## License
MIT
```

---

## GitHub Setup Commands

```bash
gh auth login
gh repo create mojo-money --public \
  --description "Native macOS/iOS app that extends Monarch Money with powerful automation modules" \
  --homepage ""
git init
git add .
git commit -m "feat: initial MOJO Money app with HD Sync module"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/mojo-money.git
git push -u origin main
```

---

## Success Criteria — Module 1 Complete When:

- [ ] App launches with MOJO Money branding (name, teal accent, navy background)
- [ ] Onboarding flow works on both macOS and iOS
- [ ] Dashboard shows module cards with HD Sync active and others as Coming Soon
- [ ] Both HD Pro CSVs parse correctly (82 summary rows, 311 detail rows from sample)
- [ ] Monarch authentication stores credentials in Keychain
- [ ] Matching correctly identifies Home Depot transactions within date/amount tolerances
- [ ] Ambiguous matches surface for user review
- [ ] Notes are written in the structured format with department grouping
- [ ] Tags (Home Depot Receipt, HD-Riverhouse, primary department) are applied
- [ ] Dry run preview shows accurate before/after diff
- [ ] Idempotency: re-importing the same CSV does not double-enrich
- [ ] History log records every sync run with per-transaction results
- [ ] App runs on macOS 14+ and iOS 17+ from a single SwiftUI codebase
- [ ] GitHub repo `mojo-money` is public with complete README
