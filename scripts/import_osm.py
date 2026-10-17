#!/usr/bin/env python3
"""Import chicken restaurants of mainland France from OpenStreetMap into Supabase.

Usage:
  SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_SERVICE_KEY=... python3 scripts/import_osm.py [--refresh]
  python3 scripts/import_osm.py --self-test

Raw Overpass responses are cached in data/osm/<region>.json; --refresh downloads them again.
Data © OpenStreetMap contributors, ODbL.
"""
from __future__ import annotations

import json
import os
import random
import re
import subprocess
import sys
import tempfile
import time
import unicodedata
import urllib.parse
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "data" / "osm"
FIXTURE = Path(__file__).resolve().parent / "fixtures" / "overpass_sample.json"

# The 13 regions of mainland France (ISO 3166-2), one Overpass query each to stay under server limits.
REGIONS = ["FR-ARA", "FR-BFC", "FR-BRE", "FR-CVL", "FR-20R", "FR-GES", "FR-HDF",
           "FR-IDF", "FR-NOR", "FR-NAQ", "FR-OCC", "FR-PDL", "FR-PAC"]
ENDPOINTS = ["https://overpass-api.de/api/interpreter",
             "https://maps.mail.ru/osm/tools/overpass/api/interpreter"]

CHICKEN_CUISINES = {"chicken", "fried_chicken", "rotisserie"}
CHAIN_BRANDS = {"kfc", "popeyes", "chicken street", "hungry chicken"}
NAME_CUISINES = {"portuguese", "peruvian"}
# Matched at the start of a word, so "Apollo" is not "pollo"; churrasc covers churrasco/churrascaria.
CHICKEN_WORDS = re.compile(r"\b(poulet|chicken|frango|pollo|brasa|churrasc|rotisserie|wings|tenders)")


def normalize(text: str) -> str:
    """Lowercase without accents: "Rôtisserie" -> "rotisserie"."""
    return "".join(c for c in unicodedata.normalize("NFKD", text) if not unicodedata.combining(c)).lower()


def cuisines(tags: dict) -> set[str]:
    return {c.strip() for c in normalize(tags.get("cuisine", "")).split(";") if c.strip()}


def chicken_rule(tags: dict) -> str | None:
    """Return the spec rule that makes this place a chicken place, or None."""
    if tags.get("amenity") not in ("restaurant", "fast_food"):
        return None
    found = cuisines(tags)
    name_match = bool(CHICKEN_WORDS.search(normalize(tags.get("name", ""))))
    if found & CHICKEN_CUISINES:
        return "cuisine"
    if normalize(tags.get("brand", "")) in CHAIN_BRANDS:
        return "brand"
    if found & NAME_CUISINES and name_match:
        return "portuguese/peruvian + name"
    if name_match:
        return "name"
    return None


def to_row(element: dict) -> dict | None:
    tags = element.get("tags", {})
    if not tags.get("name") or chicken_rule(tags) is None:
        return None
    point = element.get("center") or element  # ways/relations come with "out center"
    if "lat" not in point:
        return None
    street = " ".join(filter(None, [tags.get("addr:housenumber"), tags.get("addr:street")]))
    return {
        "osm_id": f"{element['type']}/{element['id']}",
        "name": tags["name"],
        "kind": tags["amenity"],
        "address": street or None,
        "city": tags.get("addr:city"),
        "location": f"SRID=4326;POINT({point['lon']} {point['lat']})",
        "brand": tags.get("brand"),
        "cuisine": tags.get("cuisine"),
    }


def overpass_query(region: str) -> str:
    place = '["amenity"~"^(restaurant|fast_food)$"]'
    # Broad server-side prefilter; chicken_rule() decides.
    return f"""[out:json][timeout:300];
area["ISO3166-2"="{region}"]["admin_level"="4"]->.a;
(
  nwr(area.a){place}["cuisine"~"chicken|rotisserie|portuguese|peruvian",i];
  nwr(area.a){place}["brand"~"^(kfc|popeyes|chicken street|hungry chicken)$",i];
  nwr(area.a){place}["name"~"poulet|chicken|frango|pollo|brasa|churrasc|r.tisserie|wings|tenders",i];
);
out center tags;"""


def post(url: str, body: bytes, headers: dict[str, str], timeout: int = 60) -> bytes:
    """POST with macOS curl: the system Python's LibreSSL 2.8 fails the TLS handshake with Overpass."""
    with tempfile.NamedTemporaryFile("w", suffix=".txt") as header_file:  # keeps the key out of `ps`
        header_file.write("".join(f"{k}: {v}\n" for k, v in headers.items()))
        header_file.flush()
        result = subprocess.run(
            ["curl", "-sS", "--fail-with-body", "-m", str(timeout), "-H", f"@{header_file.name}",
             "--data-binary", "@-", url],
            input=body, capture_output=True)
    if result.returncode != 0:
        raise OSError(f"curl exit {result.returncode}: {(result.stderr or result.stdout)[:200]!r}")
    return result.stdout


def fetch_region(region: str, refresh: bool) -> list[dict]:
    path = CACHE / f"{region}.json"
    if path.exists() and not refresh:
        return json.loads(path.read_text())["elements"]
    data = urllib.parse.urlencode({"data": overpass_query(region)}).encode()
    for attempt in range(6):
        url = ENDPOINTS[attempt % len(ENDPOINTS)]
        try:
            body = post(url, data, {"User-Agent": "la-carto-poulet-import/1.0"}, timeout=330)
            elements = json.loads(body)["elements"]
            CACHE.mkdir(parents=True, exist_ok=True)
            path.write_bytes(body)
            return elements
        except (OSError, json.JSONDecodeError, KeyError) as error:
            wait = 30 * (attempt + 1)
            print(f"  {region}: {url} failed ({error}), retrying in {wait}s", file=sys.stderr)
            time.sleep(wait)
    raise SystemExit(f"{region}: all Overpass servers failed, re-run later (cached regions are kept)")


def upsert(rows: list[dict]) -> None:
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_KEY")
    if not url or not key:
        raise SystemExit("Set SUPABASE_URL and SUPABASE_SERVICE_KEY (never commit the key).")
    for start in range(0, len(rows), 500):
        post(f"{url}/rest/v1/restaurants?on_conflict=osm_id", json.dumps(rows[start:start + 500]).encode(),
             {"apikey": key, "Authorization": f"Bearer {key}", "Content-Type": "application/json",
              "Prefer": "resolution=merge-duplicates,return=minimal"})


def collect(elements: list[dict]) -> tuple[dict[str, dict], dict[str, str]]:
    """Rows keyed by osm_id (regions overlap at borders) and the rule that matched each one."""
    rows, rules = {}, {}
    for element in elements:
        row = to_row(element)
        if row:
            rows[row["osm_id"]] = row
            rules[row["osm_id"]] = chicken_rule(element["tags"])
    return rows, rules


def report(rows: dict[str, dict], rules: dict[str, str]) -> None:
    counts = Counter(rules.values())
    print(f"{len(rows)} restaurants")
    for rule, count in counts.most_common():
        print(f"  {rule}: {count}")
    print("20 random matches:")
    for r in random.sample(list(rows.values()), min(20, len(rows))):
        print(f"  {r['name']} ({r['kind']}, {r['city'] or '?'}) cuisine={r['cuisine']} brand={r['brand']}")


def self_test() -> None:
    elements = json.loads(FIXTURE.read_text())["elements"]
    expected = {e["id"]: e["expect"] for e in elements}
    for e in elements:
        assert chicken_rule(e.get("tags", {})) == expected[e["id"]], (e["tags"].get("name"), expected[e["id"]])
    rows, _ = collect(elements + elements)  # same data twice: no duplicates
    assert len(rows) == sum(1 for v in expected.values() if v), rows.keys()
    way = rows["way/7"]
    assert way["location"] == "SRID=4326;POINT(2.35 48.86)" and way["address"] == "12 Rue de Lappe", way
    print(f"self-test ok ({len(elements)} elements, {len(rows)} chicken places)")


def main() -> None:
    if "--self-test" in sys.argv:
        return self_test()
    refresh = "--refresh" in sys.argv
    elements = []
    for region in REGIONS:
        found = fetch_region(region, refresh)
        print(f"{region}: {len(found)} elements", file=sys.stderr)
        elements += found
    rows, rules = collect(elements)
    upsert(list(rows.values()))
    report(rows, rules)


if __name__ == "__main__":
    main()
