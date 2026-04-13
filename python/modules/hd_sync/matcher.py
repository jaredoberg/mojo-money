"""
Match HD Summary transactions to Monarch Money transactions.

Matching rules:
- Amount match:  abs(hd_total - monarch_amount) <= $0.02
- Date window:   abs((hd_date - monarch_date).days) <= 3
- Merchant pre-filter: merchant contains "Home Depot", "HOMEDEPOT", "HD ", "THE HOME DEPOT"

Result statuses:
- matched   — exactly one Monarch candidate
- ambiguous — multiple candidates
- unmatched — no candidate found
"""

from datetime import datetime, timedelta
from typing import Any


HD_MERCHANT_KEYWORDS = ["home depot", "homedepot", "hd ", "the home depot"]
AMOUNT_TOLERANCE   = 0.02
DEFAULT_DATE_WINDOW = 3  # days


def _parse_date(date_str: str) -> datetime | None:
    for fmt in ("%Y-%m-%d", "%m/%d/%Y", "%m/%d/%y"):
        try:
            return datetime.strptime(date_str, fmt)
        except ValueError:
            continue
    return None


def _is_hd_merchant(merchant: str) -> bool:
    m = merchant.lower()
    return any(kw in m for kw in HD_MERCHANT_KEYWORDS)


def match_transactions(hd_transactions: list[dict],
                       monarch_transactions: list[dict],
                       date_window_days: int = DEFAULT_DATE_WINDOW,
                       amount_tolerance: float = AMOUNT_TOLERANCE) -> list[dict]:
    """
    Returns a list of MatchResult dicts.
    """
    # Pre-filter Monarch to Home Depot merchants
    hd_monarch = [t for t in monarch_transactions if _is_hd_merchant(t.get("merchant", ""))]

    results = []
    for hd in hd_transactions:
        hd_amount = hd.get("total_amount", 0)
        hd_date   = _parse_date(hd.get("date", ""))

        candidates = []
        for mt in hd_monarch:
            monarch_amount = float(mt.get("amount", 0))
            monarch_date   = _parse_date(mt.get("date", ""))

            if hd_date is None or monarch_date is None:
                continue

            amount_ok = abs(abs(hd_amount) - abs(monarch_amount)) <= amount_tolerance
            date_ok   = abs((hd_date - monarch_date).days) <= date_window_days

            if amount_ok and date_ok:
                candidates.append(mt)

        if len(candidates) == 1:
            status     = "matched"
            monarch_tx = candidates[0]
            confidence = 1.0
        elif len(candidates) > 1:
            status     = "ambiguous"
            monarch_tx = None
            confidence = 0.5
        else:
            status     = "unmatched"
            monarch_tx = None
            confidence = 0.0

        results.append({
            "hd_order":       hd,
            "monarch_tx":     monarch_tx,
            "status":         status,
            "confidence":     confidence,
            "candidates":     candidates,
            "is_user_override": False,
            "proposed_notes": None,
            "proposed_tags":  [],
        })

    return results
