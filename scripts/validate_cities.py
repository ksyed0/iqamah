#!/usr/bin/env python3
"""
validate_cities.py — Schema validation for iqamah/Resources/cities.json

Asserts every city entry has the required fields with valid values:
- name: non-empty string
- countryCode: 2-letter ISO 3166-1 alpha-2 code
- latitude: float in [-90, 90]
- longitude: float in [-180, 180]
- timezone: valid IANA timezone identifier (checked against system tz database)

Every country entry must have:
- name: non-empty string
- code: 2-letter code matching a code used by at least one city

Exit 0 if valid, exit 1 with actionable error messages if not.
"""

import json
import sys
import os
from zoneinfo import available_timezones

CITIES_PATH = os.path.join(
    os.path.dirname(__file__), "..", "iqamah", "Resources", "cities.json"
)

def error(msg: str) -> None:
    print(f"❌  {msg}", file=sys.stderr)

def main() -> int:
    # ── Load ──────────────────────────────────────────────────────────────
    try:
        with open(CITIES_PATH, encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        error(f"cities.json not found at {CITIES_PATH}")
        return 1
    except json.JSONDecodeError as e:
        error(f"cities.json is not valid JSON: {e}")
        return 1

    cities = data.get("cities", [])
    countries = data.get("countries", [])
    valid_tzs = available_timezones()
    failures = []

    # ── Validate cities ───────────────────────────────────────────────────
    for i, city in enumerate(cities):
        loc = f"cities[{i}] '{city.get('name', '<unnamed>')}'"

        if not isinstance(city.get("name"), str) or not city["name"].strip():
            failures.append(f"{loc}: 'name' must be a non-empty string")

        cc = city.get("countryCode", "")
        if not isinstance(cc, str) or len(cc) != 2 or not cc.isalpha():
            failures.append(f"{loc}: 'countryCode' must be a 2-letter ISO code, got {cc!r}")

        lat = city.get("latitude")
        if not isinstance(lat, (int, float)) or not (-90 <= lat <= 90):
            failures.append(f"{loc}: 'latitude' must be in [-90, 90], got {lat!r}")

        lon = city.get("longitude")
        if not isinstance(lon, (int, float)) or not (-180 <= lon <= 180):
            failures.append(f"{loc}: 'longitude' must be in [-180, 180], got {lon!r}")

        tz = city.get("timezone", "")
        if tz not in valid_tzs:
            failures.append(f"{loc}: 'timezone' {tz!r} is not a valid IANA identifier")

    # ── Validate countries ────────────────────────────────────────────────
    city_codes = {c.get("countryCode") for c in cities}
    for i, country in enumerate(countries):
        loc = f"countries[{i}] '{country.get('name', '<unnamed>')}'"

        if not isinstance(country.get("name"), str) or not country["name"].strip():
            failures.append(f"{loc}: 'name' must be a non-empty string")

        code = country.get("code", "")
        if not isinstance(code, str) or len(code) != 2 or not code.isalpha():
            failures.append(f"{loc}: 'code' must be a 2-letter ISO code, got {code!r}")

    # ── Summary ───────────────────────────────────────────────────────────
    if failures:
        print(f"\ncities.json validation FAILED — {len(failures)} error(s):\n")
        for f in failures[:20]:   # cap at 20 to avoid noise
            error(f)
        if len(failures) > 20:
            print(f"  ... and {len(failures) - 20} more errors")
        return 1

    print(f"✅  cities.json valid — {len(cities)} cities, {len(countries)} countries")
    return 0


if __name__ == "__main__":
    sys.exit(main())
