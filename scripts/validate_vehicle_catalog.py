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

catalog_bytes = zlib.decompress(base64.b64decode(envelope["data"], validate=True))
if len(catalog_bytes) != envelope.get("uncompressedBytes"):
    raise SystemExit("Catalog length does not match its header")
catalog = json.loads(catalog_bytes)
makes = len(catalog)
models = sum(len(make["models"]) for make in catalog)
generations = sum(len(model["generations"]) for make in catalog for model in make["models"])
engines = sum(len(generation["engines"]) for make in catalog for model in make["models"] for generation in model["generations"])

if (makes, models, generations, engines) != (32, 1389, 4791, 23572):
    raise SystemExit(f"Catalog count mismatch: {makes} makes, {models} models, {generations} generations, {engines} engines")

print(f"Catalog OK: {makes} makes, {models} models, {generations} generations, {engines} engines")
