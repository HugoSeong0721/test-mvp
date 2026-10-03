#!/usr/bin/env python3
"""Reference values for the solunar engine tests, computed with PyEphem.

    pip install ephem
    python3 tools/solunar/make_reference.py   # → solunar_app/flutter/test/fixtures/ephem_reference.json

Definitions (match the app):
- Moonrise/moonset: USNO — upper limb on the horizon, 34' refraction, topocentric
  (pressure=0, horizon=-0:34, upper limb).
- Moon overhead / underfoot: upper / lower meridian transit.
- Sunrise/sunset: NOAA — sun centre at -0:50 (use_center=True, pressure=0).
- Days are local calendar days in the place's IANA time zone.
"""
import datetime as dt
import json
import math
import os
import random
from zoneinfo import ZoneInfo

import ephem

PLACES = [
    ("Austin, TX", 30.2672, -97.7431, "America/Chicago"),
    ("Minneapolis, MN", 44.9778, -93.2650, "America/Chicago"),
    ("Seattle, WA", 47.6062, -122.3321, "America/Los_Angeles"),
    ("Miami, FL", 25.7617, -80.1918, "America/New_York"),
    ("Bangor, ME", 44.8012, -68.7778, "America/New_York"),
    ("Denver, CO", 39.7392, -104.9903, "America/Denver"),
    ("Phoenix, AZ", 33.4484, -112.0740, "America/Phoenix"),
    ("Anchorage, AK", 61.2181, -149.9003, "America/Anchorage"),
    ("Fairbanks, AK", 64.8378, -147.7164, "America/Anchorage"),
    ("Utqiagvik, AK", 71.2906, -156.7886, "America/Anchorage"),
    ("Honolulu, HI", 21.3069, -157.8583, "Pacific/Honolulu"),
    ("Toronto, ON", 43.6532, -79.3832, "America/Toronto"),
    ("Sydney, AU", -33.8688, 151.2093, "Australia/Sydney"),
]

OUT = os.path.join(os.path.dirname(__file__), "../../solunar_app/flutter/test/fixtures/ephem_reference.json")


def iso(d):
    return d.datetime().replace(tzinfo=dt.timezone.utc).isoformat().replace("+00:00", "Z")


def to_ephem(t):
    return ephem.Date(t.astimezone(dt.timezone.utc).replace(tzinfo=None))


def observer(lat, lng):
    o = ephem.Observer()
    o.lat, o.lon = str(lat), str(lng)
    o.elevation = 0
    o.pressure = 0
    return o


def events_between(lat, lng, start, end):
    """All moon events with start <= t < end (UTC datetimes)."""
    out = []
    e_end = to_ephem(end)
    for kind, fn in (("rise", "next_rising"), ("set", "next_setting"),
                     ("overhead", "next_transit"), ("underfoot", "next_antitransit")):
        o = observer(lat, lng)
        o.horizon = "-0:34"
        o.date = to_ephem(start)
        while True:
            try:
                t = getattr(o, fn)(ephem.Moon())
            except (ephem.AlwaysUpError, ephem.NeverUpError):
                break
            if t >= e_end:
                break
            out.append((kind, iso(t)))
            o.date = t + ephem.minute
    out.sort(key=lambda x: x[1])
    return [{"kind": k, "time": t} for k, t in out]


def sun(lat, lng, local_noon):
    o = observer(lat, lng)
    o.horizon = "-0:50"
    o.date = to_ephem(local_noon)
    s = ephem.Sun()
    try:
        rise = iso(o.previous_rising(s, use_center=True))
        sset = iso(o.next_setting(s, use_center=True))
    except (ephem.AlwaysUpError, ephem.NeverUpError):
        return None
    return {"sunrise": rise, "sunset": sset}


def day_entry(place, day):
    name, lat, lng, tzname = place
    tz = ZoneInfo(tzname)
    start = dt.datetime(day.year, day.month, day.day, tzinfo=tz)
    nxt = day + dt.timedelta(days=1)
    end = dt.datetime(nxt.year, nxt.month, nxt.day, tzinfo=tz)
    noon = dt.datetime(day.year, day.month, day.day, 12, tzinfo=tz)
    m = ephem.Moon(to_ephem(noon))
    return {
        "date": day.isoformat(),
        "start": start.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z"),
        "end": end.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z"),
        "moon": events_between(lat, lng, start, end),
        "sun": sun(lat, lng, noon),
        "illumination": round(m.moon_phase, 5),
        "distanceKm": round(m.earth_distance * ephem.meters_per_au / 1000, 1),
    }


def main():
    rnd = random.Random(7)
    places = []
    for place in PLACES:
        days = [dt.date(2026, 10, 1) + dt.timedelta(days=i) for i in range(20)]
        if place[0] == "Austin, TX":  # two months straight, across the DST change
            days = [dt.date(2026, 10, 1) + dt.timedelta(days=i) for i in range(61)]
        days += [dt.date(2026, 1, 1) + dt.timedelta(days=rnd.randrange(365 * 5)) for _ in range(15)]
        places.append({
            "name": place[0], "lat": place[1], "lng": place[2], "tz": place[3],
            "days": [day_entry(place, d) for d in sorted(set(days))],
        })

    positions = []
    for _ in range(60):
        t = dt.datetime(2026, 1, 1, tzinfo=dt.timezone.utc) + dt.timedelta(seconds=rnd.randrange(5 * 365 * 86400))
        m = ephem.Moon(to_ephem(t))
        positions.append({
            "time": t.isoformat().replace("+00:00", "Z"),
            "ra": round(math.degrees(m.g_ra), 5),
            "dec": round(math.degrees(m.g_dec), 5),
            "distanceKm": round(m.earth_distance * ephem.meters_per_au / 1000, 1),
        })

    phases = []
    d = ephem.Date("2026/1/1")
    while d < ephem.Date("2031/1/1"):
        for kind, fn in (("new", ephem.next_new_moon), ("first", ephem.next_first_quarter_moon),
                         ("full", ephem.next_full_moon), ("last", ephem.next_last_quarter_moon)):
            phases.append({"kind": kind, "time": iso(fn(d))})
        d = ephem.Date(d + 29.53)
    phases = sorted({(p["kind"], p["time"]) for p in phases}, key=lambda x: x[1])

    data = {
        "generator": f"PyEphem {ephem.__version__}",
        "places": places,
        "positions": positions,
        "phases": [{"kind": k, "time": t} for k, t in phases],
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        json.dump(data, f, indent=0, separators=(",", ":"))
    n = sum(len(day["moon"]) for p in places for day in p["days"])
    print(f"{len(places)} places, {n} moon events, {len(positions)} positions, {len(phases)} phases → {OUT}")


if __name__ == "__main__":
    main()
