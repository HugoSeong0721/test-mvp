#!/usr/bin/env python3
"""Build the compact station list bundled in the tides app.

Runs in GitHub Actions after fetch_noaa.py (the sandbox cannot reach NOAA).
The mdapi list has no DST flag, so each station's details are fetched in
parallel for `observedst` / `timezone`. Output (tools/tides/out/):

  stations_compact.json  [[id, name, state, lat, lng, isRef(1/0), refId, tzCorr, dst(1/0/-1), tzAbbr], ...]
  stations_build.md      counts and failures
"""
import concurrent.futures as cf
import json
import os
import time
import urllib.request

OUT = os.path.join(os.path.dirname(__file__), "out")
MD = "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi"


def detail(sid):
    url = f"{MD}/stations/{sid}.json?expand=details"
    for attempt in range(4):
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                st = json.loads(r.read())["stations"][0]
                return sid, st.get("observedst"), st.get("timezone")
        except Exception as e:  # noqa: BLE001
            err = e
            time.sleep(1 + attempt * 2)
    return sid, None, f"ERR {err}"


def main():
    raw = json.load(open(os.path.join(OUT, "stations_raw.json")))["stations"]
    t0 = time.time()
    with cf.ThreadPoolExecutor(max_workers=16) as ex:
        info = {sid: (dst, tz) for sid, dst, tz in ex.map(detail, [s["id"] for s in raw])}
    rows, fails = [], []
    for s in raw:
        dst, tz = info.get(s["id"], (None, None))
        if dst is None:
            fails.append((s["id"], s["name"], tz))
        rows.append([
            s["id"], s["name"].strip(), s.get("state") or "",
            round(float(s["lat"]), 5), round(float(s["lng"]), 5),
            1 if s.get("type") == "R" else 0,
            s.get("reference_id") or "",
            s.get("timezonecorr"),
            1 if dst is True else (0 if dst is False else -1),
            tz if (tz and not str(tz).startswith("ERR")) else "",
        ])
    with open(os.path.join(OUT, "stations_compact.json"), "w") as f:
        json.dump(rows, f, separators=(",", ":"), ensure_ascii=False)
    with open(os.path.join(OUT, "stations_build.md"), "w") as f:
        f.write(f"# stations_compact.json\n\n- stations: {len(rows)}\n- detail time: {time.time() - t0:.0f}s\n")
        f.write(f"- dst true: {sum(1 for r in rows if r[8] == 1)}, false: {sum(1 for r in rows if r[8] == 0)}, unknown: {len(fails)}\n")
        tzs = {}
        for r in rows:
            tzs[f"{r[9]} {r[7]} dst={r[8]}"] = tzs.get(f"{r[9]} {r[7]} dst={r[8]}", 0) + 1
        f.write("- timezone combos:\n" + "".join(f"  - {k}: {v}\n" for k, v in sorted(tzs.items())))
        f.write("- failures:\n" + "".join(f"  - {a} {b}: {c}\n" for a, b, c in fails[:200]))
    print(open(os.path.join(OUT, "stations_build.md")).read())


if __name__ == "__main__":
    main()
