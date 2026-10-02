#!/usr/bin/env python3
"""NOAA CO-OPS probe + data snapshot for the tides app.

The dev sandbox cannot reach api.tidesandcurrents.noaa.gov, so this runs in
GitHub Actions (.github/workflows/fetch-noaa.yml) and commits its output to the
`tides-noaa-data` branch:

  tools/tides/out/report.md            response times, headers (CORS), field names
  tools/tides/out/stations_raw.json    mdapi tide-prediction station list (raw)
  tools/tides/out/station_details/*.json  a few stations with details/offsets
  tools/tides/out/fixtures/*.json      real predictions used by tests (hilo, 6-min)

Standard library only.
"""
import datetime as dt
import json
import os
import time
import urllib.error
import urllib.request

OUT = os.path.join(os.path.dirname(__file__), "out")
API = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"
MD = "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi"
APP = "soulfulfill_tides"

report = []


def log(line=""):
    print(line, flush=True)
    report.append(line)


def get(url, label):
    req = urllib.request.Request(url, headers={
        "Origin": "https://soulfulfillable.github.io",
        "User-Agent": "soulfulfill-tides-probe/1.0",
    })
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            body = r.read()
            ms = (time.time() - t0) * 1000
            hdr = {k.lower(): v for k, v in r.headers.items()}
            log(f"- **{label}**: HTTP {r.status}, {ms:.0f} ms, {len(body):,} bytes, "
                f"ACAO=`{hdr.get('access-control-allow-origin')}`, "
                f"type=`{hdr.get('content-type')}`, cache=`{hdr.get('cache-control')}`")
            return body
    except urllib.error.HTTPError as e:
        ms = (time.time() - t0) * 1000
        body = e.read()
        log(f"- **{label}**: HTTP {e.code} after {ms:.0f} ms: `{body[:300]!r}`")
        return body
    except Exception as e:  # noqa: BLE001
        log(f"- **{label}**: FAILED {type(e).__name__}: {e}")
        return b""


def save(rel, body):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(body)


def pred_url(station, begin, end, interval, tz="gmt", units="english"):
    return (f"{API}?product=predictions&application={APP}&begin_date={begin}&end_date={end}"
            f"&datum=MLLW&station={station}&time_zone={tz}&units={units}&interval={interval}&format=json")


def main():
    os.makedirs(OUT, exist_ok=True)
    today = dt.datetime.now(dt.timezone.utc).date()
    log(f"# NOAA CO-OPS probe — {dt.datetime.now(dt.timezone.utc):%Y-%m-%d %H:%M} UTC")
    log()
    log("## Station list")
    raw = get(f"{MD}/stations.json?type=tidepredictions", "stations.json?type=tidepredictions")
    save("stations_raw.json", raw)
    stations = []
    try:
        data = json.loads(raw)
        stations = data.get("stations", [])
        log(f"- count: {len(stations)} (top-level keys: {list(data.keys())})")
        if stations:
            log(f"- fields of first station: `{sorted(stations[0].keys())}`")
            log(f"- first station: `{json.dumps(stations[0])[:600]}`")
            types = {}
            for s in stations:
                types[s.get("type")] = types.get(s.get("type"), 0) + 1
            log(f"- by type: {types}")
            tzc = {}
            for s in stations:
                tzc[str(s.get("timezonecorr"))] = tzc.get(str(s.get("timezonecorr")), 0) + 1
            log(f"- timezonecorr values: {tzc}")
            states = {}
            for s in stations:
                states[s.get("state") or "?"] = states.get(s.get("state") or "?", 0) + 1
            log(f"- states: {dict(sorted(states.items()))}")
    except Exception as e:  # noqa: BLE001
        log(f"- parse error: {e}")

    # second call for timing variance (cache?)
    get(f"{MD}/stations.json?type=tidepredictions", "stations.json again (cache?)")

    log()
    log("## Station details")
    for sid in ["9414290", "9414131", "1612340", "8518750"]:
        body = get(f"{MD}/stations/{sid}.json?expand=details,tidepredoffsets&units=english", f"station {sid} details")
        save(f"station_details/{sid}.json", body)
        try:
            st = json.loads(body)["stations"][0]
            log(f"  - keys: `{sorted(st.keys())}`")
            log(f"  - `{json.dumps({k: st.get(k) for k in ['id','name','state','type','timezone','timezonecorr','observedst','reference_id','lat','lng','tidal','greatlakes']})}`")
        except Exception as e:  # noqa: BLE001
            log(f"  - parse error: {e}")

    log()
    log("## Predictions")
    begin = (today - dt.timedelta(days=1)).strftime("%Y%m%d")
    end = (today + dt.timedelta(days=9)).strftime("%Y%m%d")
    samples = [
        ("9414290", "San Francisco (R)"),
        ("8518750", "The Battery NY (R)"),
        ("1612340", "Honolulu (R, no DST)"),
        ("9455920", "Anchorage (R)"),
        ("8723214", "Virginia Key FL (R)"),
    ]
    # pick a subordinate station from the list
    sub = next((s for s in stations if s.get("type") == "S" and s.get("state") == "CA"), None)
    if sub:
        samples.append((sub["id"], f"{sub['name']} (S)"))
    for sid, name in samples:
        body = get(pred_url(sid, begin, end, "hilo"), f"{name} hilo 11 days")
        save(f"fixtures/{sid}_hilo.json", body)
        try:
            p = json.loads(body).get("predictions", [])
            log(f"  - {len(p)} hi/lo, first `{p[:2]}`")
        except Exception as e:  # noqa: BLE001
            log(f"  - parse error: {e}")
        body = get(pred_url(sid, begin, end, "6"), f"{name} 6-min 11 days")
        save(f"fixtures/{sid}_6min.json", body)
        try:
            p = json.loads(body).get("predictions", [])
            log(f"  - {len(p)} points, first `{p[:2]}`")
        except Exception as e:  # noqa: BLE001
            log(f"  - parse error: {e}")
    # local time vs gmt, metric, hourly, and a 31-day hilo (rewarded feature size)
    body = get(pred_url("9414290", begin, begin, "hilo", tz="lst_ldt"), "SF hilo lst_ldt 1 day")
    log(f"  - `{body[:400]!r}`")
    body = get(pred_url("9414290", begin, begin, "hilo", tz="gmt"), "SF hilo gmt 1 day")
    log(f"  - `{body[:400]!r}`")
    body = get(pred_url("9414290", begin, begin, "hilo", units="metric"), "SF hilo metric 1 day")
    log(f"  - `{body[:300]!r}`")
    body = get(pred_url("9414290", begin, begin, "h"), "SF hourly 1 day")
    log(f"  - `{body[:200]!r}`")
    # 30-day table (rewarded feature): what the app requests — 1 day back to 31 days ahead
    m_begin = (today - dt.timedelta(days=1)).strftime("%Y%m%d")
    m_end = (today + dt.timedelta(days=31)).strftime("%Y%m%d")
    for sid in ["9414290", "9410068", "1612340"]:
        body = get(pred_url(sid, m_begin, m_end, "hilo"), f"{sid} hilo 33 days (30-day table)")
        save(f"fixtures/{sid}_hilo30.json", body)
    # error shapes
    body = get(pred_url("0000000", begin, begin, "hilo"), "bad station id")
    log(f"  - `{body[:300]!r}`")
    log()
    log("## Timing (5 repeated hilo 8-day calls, SF)")
    for i in range(5):
        get(pred_url("9414290", today.strftime("%Y%m%d"), (today + dt.timedelta(days=7)).strftime("%Y%m%d"), "hilo"), f"try {i+1}")

    with open(os.path.join(OUT, "report.md"), "w") as f:
        f.write("\n".join(report) + "\n")


if __name__ == "__main__":
    main()
