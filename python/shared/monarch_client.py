"""
Thin async wrapper around the monarchmoney library.
All public functions return plain dicts suitable for JSON serialisation.
"""

import asyncio
from typing import Any

try:
    from monarchmoney import MonarchMoney
    from monarchmoney.monarchmoney import RequireMFAException
    MONARCH_AVAILABLE = True
except ImportError:
    MONARCH_AVAILABLE = False
    RequireMFAException = Exception  # placeholder so references compile


def _require_monarch() -> "MonarchMoney":
    if not MONARCH_AVAILABLE:
        raise ImportError("monarchmoney not installed. Run: pip install monarchmoney")
    return MonarchMoney()


# ---------------------------------------------------------------------------
# Authentication
# ---------------------------------------------------------------------------

def authenticate(email: str, password: str, mfa_token: str | None = None) -> dict:
    """Authenticate and return a session token."""
    mm = _require_monarch()
    asyncio.run(_login(mm, email, password, mfa_token))
    return {"session_token": mm.token, "user_email": email}


async def _login(mm: "MonarchMoney", email: str, password: str, mfa_token: str | None):
    # use_saved_session=False so we always do a fresh login; save_session=False to
    # avoid writing the pickle file (we manage the token ourselves via Keychain)
    token = mfa_token.strip() if mfa_token else None

    # A short all-digit string is a one-time passcode from an authenticator app.
    # The library's mfa_secret_key parameter expects the raw TOTP base32 seed
    # instead — so we use the two-step flow (login → RequireMFAException →
    # multi_factor_authenticate) when the user supplies a numeric OTP.
    is_otp_code = token is not None and token.isdigit() and len(token) in (6, 7, 8)

    if is_otp_code:
        try:
            await mm.login(
                email=email, password=password,
                use_saved_session=False, save_session=False,
            )
        except RequireMFAException:
            await mm.multi_factor_authenticate(email, password, token)
    else:
        # token is either None or a TOTP base32 secret key
        await mm.login(
            email=email, password=password,
            use_saved_session=False, save_session=False,
            mfa_secret_key=token,
        )


# ---------------------------------------------------------------------------
# Transactions
# ---------------------------------------------------------------------------

def get_transactions(session_token: str, date_from: str, date_to: str,
                     search: str = "Home Depot") -> list[dict]:
    """Fetch Monarch transactions filtered to the given date range and merchant search."""
    mm = _require_monarch()
    mm.set_token(session_token)
    results = asyncio.run(_fetch_transactions(mm, date_from, date_to, search))
    return results


async def _fetch_transactions(mm: "MonarchMoney", date_from: str, date_to: str,
                               search: str) -> list[dict]:
    resp = await mm.get_transactions(
        start_date=date_from,
        end_date=date_to,
        search=search,
        limit=1000
    )
    txns = []
    for t in resp.get("allTransactions", {}).get("results", []):
        txns.append({
            "id":       t.get("id", ""),
            "date":     t.get("date", ""),
            "amount":   float(t.get("amount", 0)),
            "merchant": t.get("merchant", {}).get("name", t.get("originalName", "")),
            "category": (t.get("category") or {}).get("name"),
            "notes":    t.get("notes"),
        })
    return txns


# ---------------------------------------------------------------------------
# Enrichment
# ---------------------------------------------------------------------------

def update_transaction(session_token: str, transaction_id: str,
                       notes: str | None = None, category_id: str | None = None) -> bool:
    mm = _require_monarch()
    mm.set_token(session_token)
    return asyncio.run(_update_tx(mm, transaction_id, notes, category_id))


async def _update_tx(mm, tx_id: str, notes: str | None, category_id: str | None) -> bool:
    kwargs: dict[str, Any] = {}
    if notes is not None:
        kwargs["notes"] = notes
    if category_id is not None:
        kwargs["category_id"] = category_id
    await mm.update_transaction(tx_id, **kwargs)
    return True


def get_or_create_tag(session_token: str, name: str) -> str | None:
    mm = _require_monarch()
    mm.set_token(session_token)
    return asyncio.run(_get_or_create_tag(mm, name))


async def _get_or_create_tag(mm, name: str) -> str | None:
    tags = await mm.get_transaction_tags()
    existing = {t["name"].lower(): t["id"] for t in tags.get("householdTransactionTags", [])}
    if name.lower() in existing:
        return existing[name.lower()]
    result = await mm.create_transaction_tag(name, color="#00C6AE")
    # Response is {"createTransactionTag": {"tag": {"id": ..., ...}}}
    tag = (result.get("createTransactionTag") or {}).get("tag") or result
    return tag.get("id")


def set_tags(session_token: str, transaction_id: str, tag_ids: list[str]) -> bool:
    mm = _require_monarch()
    mm.set_token(session_token)
    return asyncio.run(_set_tags(mm, transaction_id, tag_ids))


async def _set_tags(mm, tx_id: str, tag_ids: list[str]) -> bool:
    await mm.set_transaction_tags(tx_id, tag_ids)
    return True


# ---------------------------------------------------------------------------
# Action dispatcher
# ---------------------------------------------------------------------------

def handle_action(action: str, payload: dict) -> dict:
    if action == "authenticate":
        result = authenticate(
            email=payload["email"],
            password=payload["password"],
            mfa_token=payload.get("mfa_token")
        )
        return result

    elif action == "get_transactions":
        txns = get_transactions(
            session_token=payload["session_token"],
            date_from=payload["date_from"],
            date_to=payload["date_to"]
        )
        return {"transactions": txns}

    elif action == "update_transaction":
        ok = update_transaction(
            session_token=payload["session_token"],
            transaction_id=payload["transaction_id"],
            notes=payload.get("notes"),
            category_id=payload.get("category_id")
        )
        return {"updated": ok}

    else:
        raise ValueError(f"Unknown shared action: {action}")
