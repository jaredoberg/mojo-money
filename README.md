# MOJO Money

> Monarch, on autopilot.

Native macOS and iOS app that extends Monarch Money with powerful automation
modules. Built for people who want their financial data to work as hard as they do.

---

## Modules

| Module | Status | Description |
|--------|--------|-------------|
| ⚡ HD Sync | ✅ Available | Enrich Monarch transactions with Home Depot Pro purchase details |
| 🏗 Lowes Sync | 🚧 Coming Soon | Same for Lowe's Pro |
| 📧 Email Sync | 🚧 Coming Soon | Auto-match email receipts to transactions |
| 📊 Project Tracker | 🚧 Coming Soon | Job costing across merchants |
| 📄 Report Builder | 🚧 Coming Soon | Custom PDF financial reports |

---

## Requirements

- macOS 14 (Sonoma) or iOS 17+
- Xcode 15+
- Python 3.11+
- Monarch Money account (**password auth required** — not Google SSO)

---

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/jaredoberg/mojo-money.git
cd mojo-money
```

### 2. Install Python dependencies

```bash
./scripts/setup.sh
```

Or manually:
```bash
pip install -r python/requirements.txt
```

### 3. Generate the Xcode project

```bash
xcodegen generate
```

### 4. Open in Xcode

```bash
open MojoMoney.xcodeproj
```

Build and run on macOS or iOS Simulator.

### 5. Connect Monarch Money

On first launch, the onboarding flow will prompt for your Monarch credentials.
These are stored securely in your system Keychain and never leave your device.

> **Note:** Monarch requires password-based login. If your account uses Google SSO,
> go to **Monarch Settings → Security** and set a password first.

---

## How to Export from Home Depot Pro

1. Log in to [homedepot.com/pro](https://www.homedepot.com/pro)
2. Navigate to **Purchase Tracking**
3. Set your desired date range
4. Export two files:
   - **Summary CSV** — order totals, dates, job names, card info
   - **Details CSV** — line items, SKUs, departments
5. In MOJO Money, go to **HD Sync → Import CSVs** and select both files

---

## Architecture

```
mojo-money/
├── MojoMoney/           # SwiftUI app (macOS + iOS)
│   ├── App/             # Entry point, AppState
│   ├── Core/            # MOJOModule protocol, services
│   ├── Shared/          # Reusable views and components
│   └── Modules/
│       ├── HDSync/      # Module 1 — fully implemented
│       ├── LowesSync/   # Stub
│       ├── EmailSync/   # Stub
│       ├── ProjectTracker/ # Stub
│       └── ReportBuilder/  # Stub
└── python/              # Python backend (subprocess bridge)
    ├── mojo_runner.py   # Main entry point / dispatcher
    ├── shared/          # Monarch API wrapper, DB logger
    └── modules/
        └── hd_sync/     # CSV parser, matcher, enricher
```

**Python bridge:** The Swift app calls Python via subprocess, passing JSON payloads
and receiving JSON responses. Python handles all Monarch API calls and CSV parsing.
No PythonKit. No embedded interpreter.

---

## Privacy

- All data stays on your device
- Credentials are stored in your system Keychain
- No telemetry, no analytics, no cloud sync
- Open source — inspect every line

---

## Development

### Adding a new module

1. Create `MojoMoney/Modules/YourModule/YourModule.swift` conforming to `MOJOModule`
2. Add it to `ModuleRegistry.swift`
3. Create `python/modules/your_module/` with `__init__.py` and handlers
4. Register the action in `mojo_runner.py`

---

## License

MIT — see [LICENSE](LICENSE)
