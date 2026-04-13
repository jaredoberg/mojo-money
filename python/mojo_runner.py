#!/usr/bin/env python3
"""
MOJO Money — main subprocess entry point.

Usage:
    python3 mojo_runner.py --module <module> --action <action> --payload <path_to_json>

Always outputs a JSON object to stdout:
    { "success": true/false, "action": "<action>", "data": {...}, "error": null }
"""

import argparse
import json
import sys
import traceback
from pathlib import Path

# Ensure python/ directory is on path
sys.path.insert(0, str(Path(__file__).parent))


def ok(action: str, data: dict) -> None:
    print(json.dumps({"success": True, "action": action, "data": data, "error": None}))


def err(action: str, message: str) -> None:
    print(json.dumps({"success": False, "action": action, "data": None, "error": message}))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--module",  required=True, help="Module name (e.g. hd_sync, shared)")
    parser.add_argument("--action",  required=True, help="Action name (e.g. parse_csv, authenticate)")
    parser.add_argument("--payload", required=True, help="Path to JSON payload file")
    args = parser.parse_args()

    # Load payload
    try:
        with open(args.payload, "r") as f:
            payload = json.load(f)
    except Exception as e:
        err(args.action, f"Failed to read payload: {e}")
        sys.exit(1)

    # Route to module handler
    try:
        if args.module == "shared":
            from shared.monarch_client import handle_action
            result = handle_action(args.action, payload)
        elif args.module == "hd_sync":
            from modules.hd_sync.sync_runner import handle_action
            result = handle_action(args.action, payload)
        else:
            err(args.action, f"Unknown module: {args.module}")
            sys.exit(1)

        ok(args.action, result)

    except Exception as e:
        err(args.action, f"{type(e).__name__}: {e}\n{traceback.format_exc()}")
        sys.exit(1)


if __name__ == "__main__":
    main()
