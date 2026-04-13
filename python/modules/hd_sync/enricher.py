"""
Build the enriched notes and tags for a matched HD transaction.

Notes format:
    ⚡ Home Depot | Riverhouse | WH27744341
    📦 13 items · $1,430.43 · Crystal River #6332

    ELECTRICAL
      · QO 200A Indoor Load Center (LP620-BPD) ×1 — $388.50
      ...
      + 9 more items

    🔗 WH27744341 · Inv: 5956995 · Card: X-0305

Tags:
    - "Home Depot Receipt"
    - "HD-[JobName]"      (normalised)
    - "[PrimaryDepartment]"  (dept with highest spend)
"""

from collections import defaultdict


MAX_NOTES_CHARS    = 900
MAX_ITEMS_SHOWN    = 8


def _fmt_amount(amount: float) -> str:
    return f"${abs(amount):,.2f}"


def build_notes(hd_transaction: dict) -> str:
    """Construct the structured note string (<= MAX_NOTES_CHARS chars)."""
    order_number   = hd_transaction.get("order_number") or ""
    invoice_number = hd_transaction.get("invoice_number") or ""
    job_name       = hd_transaction.get("job_name") or ""
    order_origin   = hd_transaction.get("order_origin") or ""
    card_alias     = hd_transaction.get("card_alias") or ""
    total_amount   = hd_transaction.get("total_amount", 0)
    line_items     = hd_transaction.get("line_items", [])

    display_id  = order_number or invoice_number or "In-Store"
    origin_disp = "Online" if order_origin.lower() == "online" else order_origin

    # Header line
    parts = ["⚡ Home Depot"]
    if job_name:
        parts.append(job_name)
    if order_number:
        parts.append(order_number)
    header = " | ".join(parts)

    # Summary line
    summary = f"📦 {len(line_items)} items · {_fmt_amount(total_amount)} · {origin_disp}"

    # Group line items by department, sorted by extended_retail desc
    by_dept: dict[str, list[dict]] = defaultdict(list)
    for item in line_items:
        dept = (item.get("department_name") or "OTHER").upper()
        by_dept[dept].append(item)

    dept_totals: dict[str, float] = {}
    for dept, items in by_dept.items():
        dept_totals[dept] = sum(i.get("extended_retail", 0) for i in items)

    # Sort departments by total spend desc
    sorted_depts = sorted(dept_totals, key=lambda d: dept_totals[d], reverse=True)

    dept_lines: list[str] = []
    total_shown = 0
    total_items = len(line_items)

    for dept in sorted_depts:
        items_sorted = sorted(by_dept[dept], key=lambda i: i.get("extended_retail", 0), reverse=True)

        remaining = MAX_ITEMS_SHOWN - total_shown
        if remaining <= 0:
            break

        dept_lines.append(f"\n{dept}")
        shown_in_dept = 0
        for item in items_sorted:
            if total_shown >= MAX_ITEMS_SHOWN:
                break
            desc = item.get("sku_description", "?")
            qty  = int(item.get("quantity", 1))
            amt  = _fmt_amount(item.get("extended_retail", 0))
            dept_lines.append(f"  · {desc} ×{qty} — {amt}")
            total_shown += 1
            shown_in_dept += 1

    leftover = total_items - total_shown
    if leftover > 0:
        dept_lines.append(f"  + {leftover} more items")

    # Footer
    footer_parts = []
    if order_number:
        footer_parts.append(order_number)
    if invoice_number:
        footer_parts.append(f"Inv: {invoice_number}")
    if card_alias:
        footer_parts.append(f"Card: {card_alias}")
    footer = "🔗 " + " · ".join(footer_parts) if footer_parts else ""

    note = header + "\n" + summary
    if dept_lines:
        note += "\n" + "\n".join(dept_lines)
    if footer:
        note += "\n\n" + footer

    # Truncate gracefully
    if len(note) > MAX_NOTES_CHARS:
        note = note[:MAX_NOTES_CHARS - 3] + "..."

    return note


def build_tags(hd_transaction: dict) -> list[str]:
    """Return the list of tag names to apply."""
    tags = ["Home Depot Receipt"]

    job_name = hd_transaction.get("job_name") or ""
    if job_name:
        # Normalise: strip spaces, title-case
        tag_job = "HD-" + job_name.strip().title().replace(" ", "")
        tags.append(tag_job)

    # Primary department = highest spend
    line_items = hd_transaction.get("line_items", [])
    dept_totals: dict[str, float] = defaultdict(float)
    for item in line_items:
        dept = (item.get("department_name") or "").strip()
        if dept:
            dept_totals[dept] += item.get("extended_retail", 0)

    if dept_totals:
        primary_dept = max(dept_totals, key=lambda d: dept_totals[d])
        tags.append(primary_dept.title())

    return tags


def build_enrichment(hd_transaction: dict) -> dict:
    """Return notes + tags for a transaction."""
    return {
        "notes": build_notes(hd_transaction),
        "tags":  build_tags(hd_transaction),
    }
