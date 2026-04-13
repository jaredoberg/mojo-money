#!/bin/bash
# MOJO Money — Python environment setup
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "==> MOJO Money: Installing Python dependencies"
echo "    Project root: $PROJECT_ROOT"

# Find python3
PYTHON=$(which python3 2>/dev/null || echo "/usr/bin/python3")
echo "    Python: $PYTHON"

"$PYTHON" -m pip install -r "$PROJECT_ROOT/python/requirements.txt"

echo ""
echo "==> Verifying installation..."
"$PYTHON" -c "import monarchmoney; print('    ✅  monarchmoney installed')" 2>/dev/null \
    || echo "    ⚠️  monarchmoney not found — run: pip install monarchmoney"
"$PYTHON" -c "import pandas; print('    ✅  pandas installed')" 2>/dev/null \
    || echo "    ⚠️  pandas not found"

echo ""
echo "==> Setup complete."
