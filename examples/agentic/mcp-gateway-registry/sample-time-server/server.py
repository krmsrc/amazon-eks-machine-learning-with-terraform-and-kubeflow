"""Minimal MCP time server for testing the MCP Gateway Registry.

Exposes a single tool, `get_current_time`, over streamable-HTTP transport
(the transport the gateway proxies at the `/mcp` path). Intentionally tiny:
no external dependencies, no API keys, no network egress.
"""

import os
from datetime import datetime, timezone
from zoneinfo import ZoneInfo, available_timezones

from mcp.server.fastmcp import FastMCP

# host=0.0.0.0 so it is reachable from other pods; the streamable-HTTP
# endpoint is served at <host>:<port>/mcp.
mcp = FastMCP(
    "sample-time",
    host="0.0.0.0",
    port=int(os.environ.get("PORT", "8000")),
)


@mcp.tool()
def get_current_time(tz: str = "UTC") -> str:
    """Return the current time in the given IANA timezone (default UTC).

    Args:
        tz: IANA timezone name, e.g. "UTC", "America/New_York", "Asia/Kolkata".
    """
    try:
        zone = ZoneInfo(tz) if tz != "UTC" else timezone.utc
    except Exception:
        return f"Unknown timezone {tz!r}. Try one of: UTC, America/New_York, Europe/London, Asia/Kolkata."
    now = datetime.now(zone)
    return now.strftime("%Y-%m-%d %H:%M:%S %Z")


@mcp.tool()
def list_timezones(prefix: str = "") -> list[str]:
    """List available IANA timezone names, optionally filtered by prefix."""
    names = sorted(available_timezones())
    if prefix:
        names = [n for n in names if n.lower().startswith(prefix.lower())]
    return names[:50]


if __name__ == "__main__":
    mcp.run(transport="streamable-http")
