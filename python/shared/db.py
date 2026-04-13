"""
SQLite history logger — thin Python wrapper for sync run persistence.
The Swift DatabaseService handles most DB work; this is available for
Python-side logging if needed.
"""

import sqlite3
from pathlib import Path
from datetime import datetime


def _db_path() -> Path:
    support = Path.home() / "Library" / "Application Support" / "MojoMoney"
    support.mkdir(parents=True, exist_ok=True)
    return support / "mojo.sqlite"


def get_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(str(_db_path()))
    conn.row_factory = sqlite3.Row
    return conn


def log_sync_run(module: str, orders_processed: int, matched: int,
                 applied: int, status: str) -> int:
    with get_connection() as conn:
        cur = conn.execute(
            "INSERT INTO sync_runs (module, orders_processed, matched, applied, status) "
            "VALUES (?, ?, ?, ?, ?)",
            (module, orders_processed, matched, applied, status)
        )
        return cur.lastrowid


def log_sync_result(run_id: int, hd_order_number: str | None,
                    hd_invoice_number: str | None, hd_amount: float,
                    hd_date: str, monarch_transaction_id: str | None,
                    monarch_amount: float | None, status: str,
                    notes_written: str | None, tags_applied: str | None,
                    error: str | None) -> None:
    with get_connection() as conn:
        conn.execute(
            """INSERT INTO sync_results
               (run_id, hd_order_number, hd_invoice_number, hd_amount, hd_date,
                monarch_transaction_id, monarch_amount, status,
                notes_written, tags_applied, error)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (run_id, hd_order_number, hd_invoice_number, hd_amount, hd_date,
             monarch_transaction_id, monarch_amount, status,
             notes_written, tags_applied, error)
        )


def is_already_applied(hd_order_number: str | None, monarch_transaction_id: str) -> bool:
    with get_connection() as conn:
        row = conn.execute(
            "SELECT COUNT(*) FROM sync_results "
            "WHERE hd_order_number = ? AND monarch_transaction_id = ? AND status = 'applied'",
            (hd_order_number, monarch_transaction_id)
        ).fetchone()
        return row[0] > 0
