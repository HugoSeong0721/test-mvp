#!/usr/bin/env python3
"""Make tides_app/flutter/assets/stations.json from the NOAA snapshot.

Input: tools/tides/out/stations_raw.json from the `tides-noaa-data` branch
(fetched by .github/workflows/fetch-noaa.yml — the sandbox cannot reach NOAA):

  git show origin/tides-noaa-data:tools/tides/out/stations_raw.json > /tmp/stations_raw.json
  python3 tools/tides/make_asset.py /tmp/stations_raw.json

NOAA's per-station `observedst` is missing for ~1,250 stations and wrong for
some (Hawaii marked DST), so daylight saving is decided here by region.
Row format: [id, name, state, lat, lng, isReference(1/0), stdOffsetHours, dst(1/0)]
"""
import json
import os
import re
import sys

NO_DST_STATES = {"HI", "PR", "VI", "GU", "AS", "MP", "FM", "MH", "PW", "UM"}


def observes_dst(s):
    st, tz, lat, lng = s.get("state") or "", s["timezonecorr"], float(s["lat"]), float(s["lng"])
    if st:
        return st not in NO_DST_STATES
    if tz is None or tz >= 0 or tz in (-10, -11):
        return False  # Pacific islands, Asia, Indian Ocean
    if tz == -4:
        bermuda = 32 <= lat <= 33 and -65.5 <= lng <= -64
        cuba = 19.5 <= lat <= 23.5 and -85 <= lng <= -74
        return bermuda or cuba
    # -5..-9: US / Canada observe DST; Mexico (except Baja California and the
    # Matamoros border strip) dropped it in 2022.
    pacific_mexico = lat < 32.5 and lng < -104
    gulf_mexico = lat < 25.85 and -98 < lng < -86.5
    if pacific_mexico:
        return tz == -8 and lat >= 28  # Baja California keeps US DST
    if gulf_mexico:
        return False
    return True


# All-caps words NOAA uses for reference-station cities ("SAN DIEGO (Broadway)")
# are title-cased; real acronyms stay.
KEEP_CAPS = {"ICWW", "USCG", "MARAD", "LAWMA", "NERR", "NOAA", "ANVSA", "GNSS", "USS", "NAS",
             "AFB", "MSF", "PGA", "ICW", "NAB", "GPS", "RR"}


def tidy(name):
    name = re.sub(r"\s+", " ", name.strip())
    return re.sub(r"\b[A-Z]{3,}\b",
                  lambda m: m.group(0) if m.group(0) in KEEP_CAPS else m.group(0).capitalize(), name)


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "out", "stations_raw.json")
    raw = json.load(open(src))["stations"]
    rows = []
    for s in raw:
        rows.append([
            s["id"], tidy(s["name"]), s.get("state") or "",
            round(float(s["lat"]), 4), round(float(s["lng"]), 4),
            1 if s.get("type") == "R" else 0,
            int(s["timezonecorr"]), 1 if observes_dst(s) else 0,
        ])
    rows.sort(key=lambda r: r[0])
    dst = os.path.join(os.path.dirname(__file__), "..", "..", "tides_app", "flutter", "assets", "stations.json")
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst, "w") as f:
        json.dump(rows, f, separators=(",", ":"), ensure_ascii=False)
    print(f"{len(rows)} stations -> {os.path.normpath(dst)} ({os.path.getsize(dst):,} bytes); "
          f"dst={sum(r[7] for r in rows)} no-dst={sum(1 - r[7] for r in rows)}")


if __name__ == "__main__":
    main()
