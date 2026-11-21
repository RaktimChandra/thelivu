#!/usr/bin/env python3
"""Set SVG import scale so every vector asset rasterises at ~320 px (sharp on
high-DPI phones), and enable mipmaps for smooth down-scaling. Run after adding SVGs:
    python3 tools/svg_import_scale.py && godot --headless --path . --import
"""
import re, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[1]
TARGET = 320.0
for imp in ROOT.rglob("*.svg.import"):
    if ".godot" in imp.parts:
        continue
    svg = imp.with_suffix("")
    head = svg.read_text(encoding="utf-8", errors="ignore")[:600]
    m = re.search(r'viewBox="[\d.\-]+ [\d.\-]+ ([\d.]+) ([\d.]+)"', head)
    w = re.search(r'\bwidth="([\d.]+)', head)
    base = float(w.group(1)) if w else (max(float(m.group(1)), float(m.group(2))) if m else 100.0)
    scale = round(max(1.0, TARGET / base), 2)
    t = imp.read_text(encoding="utf-8")
    t = re.sub(r"svg/scale=[\d.]+", f"svg/scale={scale}", t)
    t = t.replace("mipmaps/generate=false", "mipmaps/generate=true")
    imp.write_text(t, encoding="utf-8")
    print(f"{svg.relative_to(ROOT)}: scale {scale}")
