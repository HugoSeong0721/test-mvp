#!/usr/bin/env python3
"""Check which line-art sources answer from the GitHub runner (timing + first bytes)."""
import time, urllib.request
URLS = [
    "https://openclipart.org/",
    "https://openclipart.org/tag/coloring%20book",
    "https://openclipart.org/detail/259789/open-book-outline-coloring",
    "https://huggingface.co/api/datasets/nyuuzyou/openclipart",
    "https://huggingface.co/api/datasets/nyuuzyou/openclipart/tree/main",
    "https://commons.wikimedia.org/w/api.php?action=query&list=categorymembers&cmtitle=Category:Coloring_pages&cmtype=file&cmlimit=5&format=json",
]
for u in URLS:
    t = time.time()
    try:
        with urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "soulfulfill-coloring-probe/1.0 (github.com/soulfulfillable/test-mvp)"}), timeout=60) as r:
            body = r.read(1500)
            print(f"OK {r.status} {time.time()-t:.1f}s {u}\n   {body[:600]!r}", flush=True)
    except Exception as e:
        print(f"FAIL {time.time()-t:.1f}s {u}: {e}", flush=True)
