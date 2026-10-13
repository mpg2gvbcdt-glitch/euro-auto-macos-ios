#!/usr/bin/env python3
import base64
import json
import sys
import zlib
from pathlib import Path


path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("EuroAuto/Resources/vehicle-catalog.json")
envelope = json.loads(path.read_text(encoding="utf-8"))
if envelope.get("encoding") != "deflate-base64":
    raise SystemExit(f"Unexpected catalog encoding in {path}")

compressed = base64.b64decode(envelope["data"], validate=True)
try:
    catalog_bytes = zlib.decompress(compressed, wbits=-15)
except zlib.error:
    catalog_bytes = zlib.decompress(compressed)
if len(catalog_bytes) != envelope.get("uncompressedBytes"):
    raise SystemExit("Catalog length does not match its header")
catalog = json.loads(catalog_bytes)
makes = len(catalog)
models = sum(len(make["models"]) for make in catalog)
generations = sum(len(model["generations"]) for make in catalog for model in make["models"])
engines = sum(len(generation["engines"]) for make in catalog for model in make["models"] for generation in model["generations"])
engine_records = [engine for make in catalog for model in make["models"] for generation in model["generations"] for engine in generation["engines"]]

if (makes, models, generations, engines) != (32, 1389, 3841, 23432):
    raise SystemExit(f"Catalog count mismatch: {makes} makes, {models} models, {generations} generations, {engines} engines")

bmw = next(make for make in catalog if make["make"] == "BMW")
series_3 = next(model for model in bmw["models"] if model["n"] == "3 Series")
labels = {generation["n"] for generation in series_3["generations"]}
if "3 Series Touring · G21 (2019–2026)" not in labels or "3 Series Touring · F31 (2012–2019)" not in labels:
    raise SystemExit("BMW 3 Series Touring chassis codes or consolidated year ranges are missing")
if any("yf" not in engine or "yt" not in engine for engine in engine_records):
    raise SystemExit("Engine availability years are missing")
if any(engine["yf"] and engine["yt"] and engine["yf"] > engine["yt"] for engine in engine_records):
    raise SystemExit("An engine has an invalid availability year range")

print(f"Catalog OK: {makes} makes, {models} models, {generations} chassis/generation groups, {engines} distinct engines; BMW Touring ranges verified")
