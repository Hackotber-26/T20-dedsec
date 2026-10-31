from __future__ import annotations

import asyncio
import ipaddress
import re
import socket
import time
from datetime import datetime, timezone
from typing import Any
from urllib.parse import urlsplit

import httpx
import tldextract
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

router = APIRouter()
_EXTRACT = tldextract.TLDExtract(suffix_list_urls=())  # bundled PSL snapshot; no startup download
_CACHE: dict[str, tuple[float, dict[str, Any]]] = {}
_CACHE_TTL_SECONDS = 6 * 60 * 60
_DOMAIN_RE = re.compile(r"^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$", re.I)


class ReputationRequest(BaseModel):
    url: str = Field(min_length=4, max_length=4096)


def _get_host(value: str) -> str:
    candidate = value.strip()
    if not candidate:
        raise ValueError("URL is empty")
    parsed = urlsplit(candidate if "://" in candidate else f"https://{candidate}")
    if parsed.scheme.lower() not in {"http", "https"} or not parsed.hostname:
        raise ValueError("Only HTTP and HTTPS URLs are supported")
    if parsed.username or parsed.password:
        # The local detector separately flags this; reject ambiguous input here.
        raise ValueError("URLs containing embedded credentials are not supported for reputation lookup")
    host = parsed.hostname.rstrip(".").encode("idna").decode("ascii").lower()
    try:
        ipaddress.ip_address(host.strip("[]"))
        raise ValueError("IP-address URLs do not have domain registration reputation")
    except ValueError as exc:
        if str(exc).startswith("IP-address"):
            raise
    if not _DOMAIN_RE.fullmatch(host):
        raise ValueError("Invalid or unsupported hostname")
    if host in {"localhost"} or host.endswith((".localhost", ".local", ".internal", ".test", ".invalid")):
        raise ValueError("Local or reserved hostnames are not supported")
    return host


def _registrable_domain(host: str) -> str:
    result = _EXTRACT(host)
    if not result.domain or not result.suffix:
        raise ValueError("Could not determine the registrable domain")
    return f"{result.domain}.{result.suffix}".lower()


def _registration_date(payload: dict[str, Any]) -> datetime | None:
    for event in payload.get("events", []):
        if str(event.get("eventAction", "")).lower() in {"registration", "registered"}:
            raw = event.get("eventDate")
            if isinstance(raw, str):
                try:
                    parsed = datetime.fromisoformat(raw.replace("Z", "+00:00"))
                    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
                except ValueError:
                    pass
    return None


async def _dns_check(domain: str) -> tuple[bool, bool]:
    """Return (resolved, resolved_to_non_public_address)."""
    try:
        records = await asyncio.wait_for(
            asyncio.to_thread(socket.getaddrinfo, domain, None, 0, socket.SOCK_STREAM),
            timeout=3.0,
        )
        addresses = {item[4][0] for item in records}
        if not addresses:
            return False, False
        non_public = any(
            not ipaddress.ip_address(address).is_global for address in addresses
        )
        return True, non_public
    except (OSError, asyncio.TimeoutError, ValueError):
        return False, False


async def _lookup(domain: str) -> dict[str, Any]:
    now = time.time()
    cached = _CACHE.get(domain)
    if cached and cached[0] > now:
        return {**cached[1], "cached": True}

    dns_resolved, non_public_dns = await _dns_check(domain)
    created_at = None
    registrar = None
    rdap_status = "unavailable"

    try:
        timeout = httpx.Timeout(6.0, connect=3.0)
        async with httpx.AsyncClient(timeout=timeout, follow_redirects=True,
                                     headers={"User-Agent": "Pehchaan-URL-Reputation/1.0"}) as client:
            response = await client.get(f"https://rdap.org/domain/{domain}")
            if response.status_code == 200:
                data = response.json()
                if isinstance(data, dict):
                    created_at = _registration_date(data)
                    entities = data.get("entities", [])
                    for entity in entities if isinstance(entities, list) else []:
                        roles = entity.get("roles", [])
                        if "registrar" in roles:
                            vcard = entity.get("vcardArray", [])
                            if len(vcard) > 1 and isinstance(vcard[1], list):
                                for item in vcard[1]:
                                    if len(item) >= 4 and item[0] == "fn":
                                        registrar = item[3]
                                        break
                            if registrar:
                                break
                    rdap_status = "available"
            elif response.status_code == 404:
                rdap_status = "not_found"
    except (httpx.HTTPError, ValueError, TypeError):
        rdap_status = "unavailable"

    age_days = None
    reputation_score = 0
    signals: list[dict[str, Any]] = []
    if created_at is not None:
        age_days = max(0, (datetime.now(timezone.utc) - created_at.astimezone(timezone.utc)).days)
        if age_days < 7:
            reputation_score += 25
            signals.append({"type": "new_domain_under_7_days", "risk": 25,
                            "detail": "Domain registration is less than 7 days old."})
        elif age_days < 30:
            reputation_score += 20
            signals.append({"type": "new_domain_under_30_days", "risk": 20,
                            "detail": "Domain registration is less than 30 days old."})
        elif age_days < 90:
            reputation_score += 10
            signals.append({"type": "young_domain_under_90_days", "risk": 10,
                            "detail": "Domain registration is less than 90 days old."})
        elif age_days < 180:
            reputation_score += 5
            signals.append({"type": "domain_under_180_days", "risk": 5,
                            "detail": "Domain registration is less than 180 days old."})

    if non_public_dns:
        reputation_score += 15
        signals.append({"type": "non_public_dns_address", "risk": 15,
                        "detail": "The hostname resolved to a non-public IP address."})
    elif not dns_resolved:
        signals.append({"type": "dns_unresolved", "risk": 0,
                        "detail": "DNS did not resolve during this check; this is inconclusive."})

    result = {
        "domain": domain,
        "domainAgeDays": age_days,
        "registrar": registrar,
        "rdapStatus": rdap_status,
        "dnsResolved": dns_resolved,
        "nonPublicDns": non_public_dns,
        "reputationScore": min(40, reputation_score),
        "signals": signals,
        "checkedAt": datetime.now(timezone.utc).isoformat(),
        "cacheTtlSeconds": _CACHE_TTL_SECONDS,
        "cached": False,
        "limitations": [
            "Registration age is a weak signal, not proof of fraud.",
            "No website content, redirect chain, TLS certificate or threat-feed verdict was fetched.",
            "Missing RDAP data is unknown, not evidence that the domain is safe."
        ],
    }
    _CACHE[domain] = (now + _CACHE_TTL_SECONDS, result)
    return result


@router.post("/v1/url/reputation")
async def url_reputation(request: ReputationRequest) -> dict[str, Any]:
    try:
        host = _get_host(request.url)
        domain = _registrable_domain(host)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    try:
        return await _lookup(domain)
    except Exception as exc:  # keep this endpoint from taking down analysis
        raise HTTPException(status_code=503, detail="URL reputation lookup is temporarily unavailable") from exc
