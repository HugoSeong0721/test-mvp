#!/usr/bin/env python3
"""Line art (PNG raster of an SVG) -> paint-by-number regions.

Steps (see docs/coloring-plan.html section 5):
 1 binarize   2 close small gaps (only for region finding)   3 label regions
 4 drop regions too small for a finger (they become part of the line)
 5 assign colors (temporary automatic palette)   6 label point = pole of
 inaccessibility (distance-transform max)   7 vectorize to SVG paths
 8 QA numbers

Usage: convert.py in.png out.json [--size 1024]
"""
import json, sys
import cv2
import numpy as np
from skimage.segmentation import expand_labels

S = 1024                      # working grid (picture fits a 1024x1024 box)
# A region must hold a circle of radius R_MIN grid px. Canvas ~390pt wide on
# iPhone, so 1024px ~ 390pt; with zoom <=3x the 44pt tap target needs an
# inscribed radius of 22/3 pt ~ 19px. We use 18.
R_MIN = 18
# Curated soft palette (temporary until per-picture art direction).
PALETTE = ["#F4A6A0", "#F7C873", "#A8D5A2", "#8EC5E8", "#C3A6E0", "#F2E3B3",
           "#E88B6B", "#6FB7A8", "#5B8DCB", "#D98FB5", "#B7D27A", "#E8B88A"]


def load(path):
    img = cv2.imread(path, cv2.IMREAD_UNCHANGED)
    if img.ndim == 3 and img.shape[2] == 4:          # transparent background -> white
        a = img[:, :, 3:4].astype(np.float32) / 255
        img = (img[:, :, :3] * a + 255 * (1 - a)).astype(np.uint8)
    g = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY) if img.ndim == 3 else img
    h, w = g.shape
    k = S / max(h, w)
    g = cv2.resize(g, (round(w * k), round(h * k)), interpolation=cv2.INTER_AREA)
    pad = np.full((S, S), 255, np.uint8)
    y0, x0 = (S - g.shape[0]) // 2, (S - g.shape[1]) // 2
    pad[y0:y0 + g.shape[0], x0:x0 + g.shape[1]] = g
    return pad


def convert(path):
    g = load(path)
    line = (g < 160).astype(np.uint8)                       # 1 = ink
    closed = cv2.morphologyEx(line, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)))
    closed = cv2.dilate(closed, np.ones((2, 2), np.uint8))
    free = (1 - closed).astype(np.uint8)
    n, lab = cv2.connectedComponents(free, connectivity=4)

    # background = every component touching the border
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    regions = []
    keep = np.zeros_like(lab)
    dropped = 0
    for i in range(1, n):
        if i in border:
            continue
        m = (lab == i).astype(np.uint8)
        dt = cv2.distanceTransform(m, cv2.DIST_L2, 5)
        r = float(dt.max())
        if r < R_MIN:
            dropped += 1
            continue
        yx = np.unravel_index(dt.argmax(), dt.shape)
        regions.append({"id": len(regions), "lab": i, "x": int(yx[1]), "y": int(yx[0]), "r": round(r, 1),
                        "area": int(m.sum())})
        keep[lab == i] = len(regions)
    # grow kept regions slightly under the line so fills meet the ink (no white halos)
    grown = expand_labels(keep, distance=3)

    # adjacency for coloring
    adj = {i: set() for i in range(1, len(regions) + 1)}
    for a, b in ((grown[:, :-1], grown[:, 1:]), (grown[:-1, :], grown[1:, :])):
        pass
    big = expand_labels(keep, distance=8)
    for a, b in ((big[:, :-1], big[:, 1:]), (big[:-1, :], big[1:, :])):
        mask = (a != b) & (a > 0) & (b > 0)
        for p, q in set(zip(a[mask].tolist(), b[mask].tolist())):
            adj[p].add(q); adj[q].add(p)

    # greedy coloring, biggest first, cycling palette so colors are used evenly
    usage = [0] * len(PALETTE)
    color = {}
    for reg in sorted(regions, key=lambda r: -r["area"]):
        k = reg["id"] + 1
        banned = {color[j] for j in adj[k] if j in color}
        options = [c for c in range(len(PALETTE)) if c not in banned] or list(range(len(PALETTE)))
        c = min(options, key=lambda c: (usage[c], c))
        color[k] = c; usage[c] += 1
    used = sorted({c for c in color.values()})
    remap = {c: i for i, c in enumerate(used)}

    out = []
    for reg in regions:
        k = reg["id"] + 1
        m = (grown == k).astype(np.uint8)
        cs, hier = cv2.findContours(m, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_SIMPLE)
        d = []
        for c in cs:
            c = cv2.approxPolyDP(c, 0.8, True)
            if len(c) < 3:
                continue
            pts = c.reshape(-1, 2)
            d.append("M" + "L".join(f"{x},{y}" for x, y in pts) + "Z")
        out.append({"c": remap[color[k]] + 1, "x": reg["x"], "y": reg["y"], "r": reg["r"], "d": "".join(d)})

    rs = [r["r"] for r in regions]
    return {
        "size": S,
        "palette": [PALETTE[c] for c in used],
        "regions": out,
        "qa": {"regions": len(out), "colors": len(used), "dropped_small": dropped,
               "min_r": min(rs) if rs else 0, "est_minutes": round((len(out) * 1.3 * 1.5 + len(used) * 4) / 60, 1)},
    }


if __name__ == "__main__":
    res = convert(sys.argv[1])
    json.dump(res, open(sys.argv[2], "w"), separators=(",", ":"))
    print(json.dumps(res["qa"]))
