#!/usr/bin/env python3
"""Offline place list for the solunar app: US (states, DC, PR) and Canadian towns
with 1,000+ people, each with its IANA time zone.

Source: GeoNames cities1000 (CC BY 4.0, https://www.geonames.org), as shipped in
the `geonamescache` PyPI package (download.geonames.org is blocked in the dev sandbox).

    pip download geonamescache --no-deps -d /tmp/gnc && unzip -o /tmp/gnc/*.whl -d /tmp/gnc
    python3 tools/solunar/make_places.py /tmp/gnc/geonamescache/data/cities1000.json

Output: solunar_app/flutter/assets/places.tsv
    line 1: time zone names separated by '|'
    then:   name <TAB> region <TAB> lat <TAB> lng <TAB> tz index <TAB> population
"""
import json
import os
import sys

CANADA = {
    "01": "AB", "02": "BC", "03": "MB", "04": "NB", "05": "NL", "07": "NS", "08": "ON",
    "09": "PE", "10": "QC", "11": "SK", "12": "YT", "13": "NT", "14": "NU",
}
US_REGIONS = {
    "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL", "GA", "HI", "ID", "IL", "IN", "IA", "KS",
    "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC",
    "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY",
}

OUT = os.path.join(os.path.dirname(__file__), "../../solunar_app/flutter/assets/places.tsv")


def main(src):
    cities = json.load(open(src)).values()
    best = {}
    for c in cities:
        cc = c["countrycode"]
        if cc == "US":
            region = c["admin1code"]
            if region not in US_REGIONS:
                continue
        elif cc == "PR":
            region = "PR"
        elif cc == "CA":
            region = CANADA.get(c["admin1code"])
            if region is None:
                continue
        else:
            continue
        name = c["name"].replace("\t", " ").strip()
        key = (name.lower(), region)
        # Same name twice in one state: keep the bigger town.
        if key not in best or c["population"] > best[key]["population"]:
            best[key] = dict(c, region=region, name=name)

    rows = sorted(best.values(), key=lambda c: -c["population"])
    zones = sorted({c["timezone"] for c in rows})
    zi = {z: i for i, z in enumerate(zones)}
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        f.write("|".join(zones) + "\n")
        for c in rows:
            f.write(f"{c['name']}\t{c['region']}\t{c['latitude']:.3f}\t{c['longitude']:.3f}\t{zi[c['timezone']]}\t{c['population']}\n")
    print(f"{len(rows)} places, {len(zones)} time zones → {OUT} ({os.path.getsize(OUT) // 1024} KB)")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/gnc/geonamescache/data/cities1000.json")
