#!/usr/bin/env python3
"""Build docs/coloring-preview.html: playable quality check of converted pictures.

usage: build_preview.py out.html id1 id2 ...   (reads work/<id>.svg|.json|.meta.json)
"""
import json, os, re, sys

WORK = os.environ.get("WORK", "work")
out, ids = sys.argv[1], sys.argv[2:]
pics = []
for i in ids:
    svg = open(f"{WORK}/{i}.svg", encoding="utf-8", errors="replace").read()
    svg = re.sub(r"<\?xml.*?\?>|<!DOCTYPE.*?>", "", svg, flags=re.S)
    data = json.load(open(f"{WORK}/{i}.json"))
    meta = json.load(open(f"{WORK}/{i}.meta.json"))
    pics.append({"id": i, "svg": svg, "data": data, "meta": meta})

html = open(os.path.join(os.path.dirname(__file__), "preview_template.html"), encoding="utf-8").read()
html = html.replace("/*PICS*/[]", json.dumps(pics, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/"))
open(out, "w", encoding="utf-8").write(html)
print(out, os.path.getsize(out) // 1024, "KB")
