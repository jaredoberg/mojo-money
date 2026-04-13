"""
Parse Home Depot Pro Purchase Tracking CSV exports.

Both CSVs have a 6-line metadata header before the column headers — use skiprows=6.
"""

import re
from datetime import datetime
from pathlib import Path

import pandas as pd


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_DOLLAR_RE = re.compile(r"[\$,\s]")


def _parse_amount(val) -> float | None:
    if pd.isna(val) or str(val).strip() == "":
        return None
    s = _DOLLAR_RE.sub("", str(val)).strip()
    # Handle negatives like -$345.72 → already stripped to -345.72
    # or ($345.72) accounting format
    s = s.replace("(", "-").replace(")", "")
    try:
        return float(s)
    except ValueError:
        return None


def _parse_date(val) -> str | None:
    if pd.isna(val) or str(val).strip() == "":
        return None
    s = str(val).strip()
    for fmt in ("%Y-%m-%d", "%m/%d/%Y", "%m/%d/%y", "%Y/%m/%d"):
        try:
            return datetime.strptime(s, fmt).strftime("%Y-%m-%d")
        except ValueError:
            continue
    return s  # return raw if unparseable


def _clean_str(val, default: str = "") -> str:
    if pd.isna(val):
        return default
    return str(val).strip()


# ---------------------------------------------------------------------------
# Summary CSV
# ---------------------------------------------------------------------------

SUMMARY_COLS = {
    "Date":                   "date",
    "Transaction ID":         "transaction_id",
    "Order Number":           "order_number",
    "Invoice Number":         "invoice_number",
    "Total Amount Paid":      "total_amount_str",
    "Job Name":               "job_name",
    "Order Origin":           "order_origin",
    "Payment":                "card_alias",
    "Purchaser/Buyer Name-ID":"purchaser",
}


def parse_summary(filepath: str) -> list[dict]:
    """Parse the Summary CSV.  Returns a list of order dicts."""
    df = pd.read_csv(filepath, skiprows=6, dtype=str, keep_default_na=False)
    df.columns = df.columns.str.strip()

    rows = []
    for _, row in df.iterrows():
        amount = _parse_amount(row.get("Total Amount Paid", ""))
        if amount is None:
            continue

        date = _parse_date(row.get("Date", ""))
        if date is None:
            continue

        is_return = amount < 0
        order_number  = _clean_str(row.get("Order Number", "")) or None
        invoice_number = _clean_str(row.get("Invoice Number", "")) or None

        rows.append({
            "date":           date,
            "transaction_id": _clean_str(row.get("Transaction ID", "")),
            "order_number":   order_number,
            "invoice_number": invoice_number,
            "total_amount":   amount,
            "is_return":      is_return,
            "job_name":       _clean_str(row.get("Job Name", "")) or None,
            "order_origin":   _clean_str(row.get("Order Origin", "")),
            "card_alias":     _clean_str(row.get("Payment", "")) or None,
            "purchaser":      _clean_str(row.get("Purchaser/Buyer Name-ID", "")) or None,
        })
    return rows


# ---------------------------------------------------------------------------
# Details CSV
# ---------------------------------------------------------------------------

def parse_details(filepath: str) -> list[dict]:
    """Parse the Details CSV.  Returns a list of line-item dicts."""
    df = pd.read_csv(filepath, skiprows=6, dtype=str, keep_default_na=False)
    df.columns = df.columns.str.strip()

    rows = []
    for _, row in df.iterrows():
        qty = _parse_amount(row.get("Quantity", "0")) or 0
        if qty == 0:
            continue  # skip wish-list / $0.00 rows

        date = _parse_date(row.get("Date", ""))
        if date is None:
            continue

        rows.append({
            "date":            date,
            "order_number":    _clean_str(row.get("Order Number", "")) or None,
            "invoice_number":  _clean_str(row.get("Invoice Number", "")) or None,
            "sku_number":      _clean_str(row.get("SKU Number", "")) or None,
            "sku_description": _clean_str(row.get("SKU Description", "")),
            "quantity":        qty,
            "unit_price":      _parse_amount(row.get("Unit price", "")) or 0.0,
            "net_unit_price":  _parse_amount(row.get("Net Unit Price", "")) or 0.0,
            "extended_retail": _parse_amount(row.get("Extended Retail (before discount)", "")) or 0.0,
            "department_name": _clean_str(row.get("Department Name", "")).upper(),
            "class_name":      _clean_str(row.get("Class Name", "")) or None,
            "subclass_name":   _clean_str(row.get("Subclass Name", "")) or None,
            "job_name":        _clean_str(row.get("Job Name", "")) or None,
            "purchaser":       _clean_str(row.get("Purchaser", "")) or None,
        })
    return rows


# ---------------------------------------------------------------------------
# Join
# ---------------------------------------------------------------------------

def join(summary: list[dict], details: list[dict]) -> list[dict]:
    """
    Attach line items to each summary order.
    - Online orders: match by order_number
    - In-store orders (no order_number): match by date + invoice_number
    """
    # Index details by order_number
    by_order: dict[str, list[dict]] = {}
    by_invoice: dict[tuple, list[dict]] = {}

    for item in details:
        on = item.get("order_number")
        inv = item.get("invoice_number")
        date = item.get("date", "")
        if on:
            by_order.setdefault(on, []).append(item)
        elif inv:
            by_invoice.setdefault((date, inv), []).append(item)

    result = []
    for order in summary:
        on  = order.get("order_number")
        inv = order.get("invoice_number")
        date = order.get("date", "")

        if on and on in by_order:
            items = by_order[on]
        elif inv and (date, inv) in by_invoice:
            items = by_invoice[(date, inv)]
        else:
            items = []

        result.append({**order, "line_items": items})

    return result
