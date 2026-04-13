"""
HD Sync orchestrator — handles all actions dispatched by mojo_runner.py.

Actions:
- parse_csv
- get_monarch_transactions
- match
- dry_run
- apply
"""

import sys
from pathlib import Path

from .csv_parser import parse_summary, parse_details, join as join_csv
from .matcher    import match_transactions
from .enricher   import build_enrichment


def handle_action(action: str, payload: dict) -> dict:
    if action == "parse_csv":
        return _parse_csv(payload)
    elif action == "get_monarch_transactions":
        return _get_monarch_transactions(payload)
    elif action == "match":
        return _match(payload)
    elif action == "dry_run":
        return _apply(payload, dry_run=True)
    elif action == "apply":
        return _apply(payload, dry_run=payload.get("dry_run", False))
    else:
        raise ValueError(f"Unknown hd_sync action: {action}")


# ---------------------------------------------------------------------------
# parse_csv
# ---------------------------------------------------------------------------

def _parse_csv(payload: dict) -> dict:
    summary_path = payload["summary_csv_path"]
    details_path = payload["details_csv_path"]

    summary = parse_summary(summary_path)
    details = parse_details(details_path)
    joined  = join_csv(summary, details)

    # Collect metadata
    all_dates = [t["date"] for t in joined if t.get("date")]
    date_range = None
    if all_dates:
        date_range = {"from": min(all_dates), "to": max(all_dates)}

    cards = sorted({t["card_alias"] for t in joined if t.get("card_alias")})
    jobs  = sorted({t["job_name"]   for t in joined if t.get("job_name")})

    line_item_count = sum(len(t.get("line_items", [])) for t in joined)

    # Pre-generate proposed notes/tags
    for t in joined:
        enrichment = build_enrichment(t)
        t["proposed_notes"] = enrichment["notes"]
        t["proposed_tags"]  = enrichment["tags"]

    return {
        "transaction_count": len(joined),
        "line_item_count":   line_item_count,
        "date_range":        date_range,
        "cards":             cards,
        "job_names":         jobs,
        "transactions":      joined,
    }


# ---------------------------------------------------------------------------
# get_monarch_transactions
# ---------------------------------------------------------------------------

def _get_monarch_transactions(payload: dict) -> dict:
    sys.path.insert(0, str(Path(__file__).parent.parent.parent))
    from shared.monarch_client import get_transactions
    txns = get_transactions(
        session_token=payload["session_token"],
        date_from=payload["date_from"],
        date_to=payload["date_to"]
    )
    return {"transactions": txns}


# ---------------------------------------------------------------------------
# match
# ---------------------------------------------------------------------------

def _match(payload: dict) -> dict:
    hd_txns       = payload["hd_transactions"]
    monarch_txns  = payload["monarch_transactions"]
    date_window   = payload.get("date_window_days", 3)
    amt_tolerance = payload.get("amount_tolerance", 0.02)

    results = match_transactions(hd_txns, monarch_txns, date_window, amt_tolerance)

    matched   = sum(1 for r in results if r["status"] == "matched")
    ambiguous = sum(1 for r in results if r["status"] == "ambiguous")
    unmatched = sum(1 for r in results if r["status"] == "unmatched")

    return {
        "results":   results,
        "matched":   matched,
        "ambiguous": ambiguous,
        "unmatched": unmatched,
    }


# ---------------------------------------------------------------------------
# apply / dry_run
# ---------------------------------------------------------------------------

def _apply(payload: dict, dry_run: bool) -> dict:
    matches       = payload.get("matches", [])
    session_token = payload.get("session_token", "")

    if not dry_run:
        sys.path.insert(0, str(Path(__file__).parent.parent.parent))
        from shared.monarch_client import update_transaction, get_or_create_tag, set_tags
        from shared.db import is_already_applied, log_sync_result

    applied = 0
    errors: list[str] = []

    for match in matches:
        hd = match.get("hd_order", {})
        mt = match.get("monarch_tx")
        if not mt:
            continue

        order_number  = hd.get("order_number")
        invoice_number = hd.get("invoice_number")
        monarch_tx_id = mt.get("id", "")

        # Idempotency check
        if not dry_run and is_already_applied(order_number, monarch_tx_id):
            continue

        enrichment = build_enrichment(hd)
        notes = enrichment["notes"]
        tag_names = enrichment["tags"]

        # Check if existing notes need append
        existing_notes = mt.get("notes") or ""
        if existing_notes and ("Home Depot" in existing_notes or "⚡" in existing_notes):
            notes = existing_notes + "\n---\n" + notes

        if dry_run:
            applied += 1
            continue

        try:
            # Update notes
            update_transaction(session_token, monarch_tx_id, notes=notes)

            # Resolve/create tags and apply
            tag_ids = [get_or_create_tag(session_token, name) for name in tag_names]
            tag_ids = [t for t in tag_ids if t]
            if tag_ids:
                set_tags(session_token, monarch_tx_id, tag_ids)

            log_sync_result(
                run_id=0,  # Will be set by Swift after the run is recorded
                hd_order_number=order_number,
                hd_invoice_number=invoice_number,
                hd_amount=hd.get("total_amount", 0),
                hd_date=hd.get("date", ""),
                monarch_transaction_id=monarch_tx_id,
                monarch_amount=mt.get("amount"),
                status="applied",
                notes_written=notes,
                tags_applied=",".join(tag_names),
                error=None
            )
            applied += 1

        except Exception as e:
            err_msg = f"{order_number or invoice_number}: {e}"
            errors.append(err_msg)
            if not dry_run:
                log_sync_result(
                    run_id=0,
                    hd_order_number=order_number,
                    hd_invoice_number=invoice_number,
                    hd_amount=hd.get("total_amount", 0),
                    hd_date=hd.get("date", ""),
                    monarch_transaction_id=monarch_tx_id,
                    monarch_amount=mt.get("amount"),
                    status="failed",
                    notes_written=None,
                    tags_applied=None,
                    error=str(e)
                )

    status = "completed" if not errors else ("partial" if applied > 0 else "failed")
    return {"applied": applied, "status": status, "errors": errors}
