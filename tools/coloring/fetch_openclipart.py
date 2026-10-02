#!/usr/bin/env python3
"""Download CC0 line-art candidates from Openclipart for the coloring app.

Runs in GitHub Actions (the dev sandbox cannot reach openclipart.org).
For every item it keeps the SVG plus a provenance record (detail page URL,
title, artist, license text seen on the page, retrieval date, sha256) so each
picture can be traced back to its CC0 source later.

Output: coloring_app/line_art/openclipart/<id>.svg, <id>.json, index.json
"""
import hashlib, html, json, os, re, sys, time, urllib.parse, urllib.request
from datetime import datetime, timezone

BASE = "https://openclipart.org"
OUT = "coloring_app/line_art/openclipart"
TAGS = [t.strip() for t in os.environ.get("TAGS", "coloring book,coloring page,colouring,line art").split(",") if t.strip()]
MAX_ITEMS = int(os.environ.get("MAX_ITEMS", "400"))
MAX_PAGES = int(os.environ.get("MAX_PAGES", "15"))
UA = {"User-Agent": "soulfulfill-coloring-fetcher/1.0 (+https://github.com/soulfulfillable/test-mvp)"}


DEADLINE = time.time() + int(os.environ.get("TIME_BUDGET", "600"))


def get(url, binary=False):
    if time.time() > DEADLINE:
        print(f"  ! time budget used up, skipping {url}", flush=True)
        return None
    for attempt in range(2):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=15) as r:
                print(f"  {r.status} {url}", flush=True)
                data = r.read()
                return data if binary else data.decode("utf-8", "replace")
        except Exception as e:  # noqa: BLE001
            print(f"  ! {url}: {e}", flush=True)
            time.sleep(2)
    return None


def text_of(s):
    return html.unescape(re.sub(r"<[^>]+>", " ", s or "")).strip()


def main():
    os.makedirs(OUT, exist_ok=True)
    debug = os.path.join(OUT, "_debug")
    os.makedirs(debug, exist_ok=True)

    found = {}  # id -> (slug, tag)
    for tag in TAGS:
        for page in range(1, MAX_PAGES + 1):
            url = f"{BASE}/tag/{urllib.parse.quote(tag)}" + (f"?p={page}" if page > 1 else "")
            body = get(url)
            if body is None:
                break
            if page == 1:
                open(os.path.join(debug, f"tag-{tag.replace(' ', '_')}.html"), "w").write(body)
            ids = re.findall(r'/detail/(\d+)/([\w\-]+)', body)
            new = [(i, s) for i, s in ids if i not in found]
            print(f"tag={tag!r} page={page}: {len(ids)} links, {len(new)} new")
            for i, s in new:
                found[i] = (s, tag)
            if not new or len(found) >= MAX_ITEMS:
                break
            time.sleep(0.5)
        if len(found) >= MAX_ITEMS:
            break

    index = []
    for n, (cid, (slug, tag)) in enumerate(list(found.items())[:MAX_ITEMS]):
        jpath = os.path.join(OUT, f"{cid}.json")
        if os.path.exists(jpath):
            index.append(json.load(open(jpath)))
            continue
        detail_url = f"{BASE}/detail/{cid}/{slug}"
        page = get(detail_url)
        if page is None:
            continue
        if n == 0:
            open(os.path.join(debug, "detail-sample.html"), "w").write(page)
        m = re.search(r'href="((?:https://openclipart\.org)?/download/\d+/[^"]+?\.svg)"', page)
        dl = (BASE + m.group(1) if m and m.group(1).startswith("/") else m.group(1)) if m else f"{BASE}/download/{cid}/{slug}.svg"
        svg = get(dl, binary=True)
        if not svg or b"<svg" not in svg[:4000]:
            print(f"  - {cid}: no svg ({dl})")
            continue
        title = text_of((re.search(r"<title>(.*?)</title>", page, re.S) or [None, ""])[1])
        artist = (re.search(r'/artist/([\w\-\.]+)', page) or [None, None])[1]
        lic = "CC0" if re.search(r"CC0|creativecommons\.org/publicdomain/zero", page, re.I) else (
            "public domain (text)" if re.search(r"public domain", page, re.I) else "UNKNOWN")
        tags = sorted(set(text_of(t) for t in re.findall(r'/tag/[^"]+"[^>]*>(.*?)</a>', page)))[:40]
        flags = [t for t in tags if t.lower() in ("pd_issue", "ai", "ai generated", "aigenerated", "logo", "trademark")]
        open(os.path.join(OUT, f"{cid}.svg"), "wb").write(svg)
        rec = {
            "id": f"openclipart-{cid}", "source_name": "Openclipart", "source_item_url": detail_url,
            "source_download_url": dl, "title": title, "artist": artist, "license_seen_on_page": lic,
            "license_id": "CC0-1.0" if lic == "CC0" else None, "found_via_tag": tag, "tags": tags,
            "risk_flags": flags, "retrieved_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "original_file_sha256": hashlib.sha256(svg).hexdigest(), "original_format": "svg",
            "bytes": len(svg),
        }
        json.dump(rec, open(jpath, "w"), indent=1, ensure_ascii=False)
        index.append(rec)
        print(f"  + {cid} {title[:50]!r} by {artist} [{lic}] {len(svg)//1024}KB")
        time.sleep(0.4)

    json.dump(index, open(os.path.join(OUT, "index.json"), "w"), indent=1, ensure_ascii=False)
    print(f"done: {len(index)} items")


if __name__ == "__main__":
    main()
