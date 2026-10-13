#!/usr/bin/env python3
"""Add curated chassis codes and consolidate split generation-year records."""
import base64
import json
import re
import sys
import zlib
from pathlib import Path


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def build_catalog(catalog, generation_index):
    index_makes = {make["make"]: make for make in generation_index}
    result = []
    for make in catalog:
        indexed_make = index_makes.get(make["make"])
        if indexed_make is None:
            raise ValueError(f"generation index is missing make {make['make']}")
        index_models = {model["name"]: model for model in indexed_make["models"]}
        models = []
        for model in make["models"]:
            indexed_model = index_models.get(model["n"])
            if indexed_model is None or len(indexed_model["generations"]) != len(model["generations"]):
                raise ValueError(f"generation index does not match {make['make']} {model['n']}")

            grouped = {}
            for position, generation in enumerate(model["generations"]):
                metadata = indexed_model["generations"][position]
                if metadata["label"] != generation["n"]:
                    raise ValueError(f"generation order mismatch for {make['make']} {model['n']}")
                code = metadata.get("bodyCode", "").strip()
                start = metadata.get("yearFrom")
                end = metadata.get("yearTo")
                if code:
                    base_name = re.sub(r"\s*\(\d{4}\)$", "", generation["n"])
                    key = ("body-code", base_name, code)
                else:
                    key = ("generation", position)

                entry = grouped.get(key)
                if entry is None:
                    entry = {
                        "n": generation["n"],
                        "from": start if start and start > 1886 else generation.get("from"),
                        "to": end if end and end > 1886 else generation.get("to"),
                        "body": code or generation.get("body"),
                        "_base_name": base_name if code else "",
                        "_body_code": code,
                        "engines": [],
                        "_engines_by_specs": {},
                    }
                    grouped[key] = entry
                else:
                    if start and start > 1886:
                        entry["from"] = min(entry["from"], start) if entry["from"] else start
                    if end and end > 1886:
                        entry["to"] = max(entry["to"], end) if entry["to"] else end
                for engine in generation["engines"]:
                    encoded = json.dumps(engine, ensure_ascii=False, sort_keys=True)
                    applicable_from = start if start and start > 1886 else None
                    applicable_to = end if end and end > 1886 else None
                    existing_engine = entry["_engines_by_specs"].get(encoded)
                    if existing_engine is None:
                        existing_engine = dict(engine, yf=applicable_from, yt=applicable_to)
                        entry["_engines_by_specs"][encoded] = existing_engine
                        entry["engines"].append(existing_engine)
                    else:
                        if applicable_from:
                            existing_engine["yf"] = min(existing_engine["yf"], applicable_from) if existing_engine["yf"] else applicable_from
                        if applicable_to:
                            existing_engine["yt"] = max(existing_engine["yt"], applicable_to) if existing_engine["yt"] else applicable_to

            generations = []
            for entry in grouped.values():
                if entry["_body_code"] and entry["from"] and entry["to"]:
                    entry["n"] = f"{entry['_base_name']} · {entry['_body_code']} ({entry['from']}–{entry['to']})"
                else:
                    label = re.sub(r"\s*\(\d{4}\)$", "", entry["n"])
                    if entry["from"] and entry["to"]:
                        entry["n"] = f"{label} ({entry['from']}–{entry['to']})"
                entry.pop("_base_name")
                entry.pop("_body_code")
                entry.pop("_engines_by_specs")
                generations.append(entry)
            generations.sort(key=lambda item: item["from"] or 0, reverse=True)
            models.append({"n": model["n"], "generations": generations})
        result.append({"make": make["make"], "models": models})
    return result


def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: build_enriched_vehicle_catalog.py <catalog.json> <generation-index.json> <output-envelope.json>")
    catalog_path, index_path, output_path = map(Path, sys.argv[1:])
    catalog = read_json(catalog_path)
    generation_index = read_json(index_path)
    enriched = build_catalog(catalog, generation_index)
    raw = json.dumps(enriched, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    compressor = zlib.compressobj(9, zlib.DEFLATED, -15)
    compressed = compressor.compress(raw) + compressor.flush()
    envelope = {
        "encoding": "deflate-base64",
        "uncompressedBytes": len(raw),
        "data": base64.b64encode(compressed).decode("ascii"),
    }
    output_path.write_text(json.dumps(envelope, separators=(",", ":")) + "\n", encoding="utf-8")
    models = sum(len(make["models"]) for make in enriched)
    generations = sum(len(model["generations"]) for make in enriched for model in make["models"])
    engines = sum(len(generation["engines"]) for make in enriched for model in make["models"] for generation in model["generations"])
    print(f"Wrote {output_path}: {len(enriched)} makes, {models} models, {generations} generations, {engines} engines")


if __name__ == "__main__":
    main()
