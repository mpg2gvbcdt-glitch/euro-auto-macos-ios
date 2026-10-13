# Vehicle catalog attribution

`vehicle-catalog.json` is a compact, filtered adaptation of the vehicle-makes-models database:

- Project: [gor3a/vehicle-makes-models](https://github.com/gor3a/vehicle-makes-models)
- Upstream source credited by that project: [autoevolution.com](https://www.autoevolution.com/)
- Data license: [Open Database License 1.0 (ODbL)](https://opendatacommons.org/licenses/odbl/1-0/)
- Changes: only makes already present in this application are retained; raw specifications are reduced to model, generation, engine, powertrain, and body measurements used by the form.

The bundled generation labels are enriched with curated manufacturer chassis codes and consolidated production-year ranges from the vehicle-generation index. Entries split by facelift year are combined when they share the same body style and chassis code. Engine records retain their applicable year range so the app can filter powertrains after a year is selected.

The upstream data is compiled from public sources and may omit or vary by market, body style, equipment, and homologation. Treat returned values as reference data and confirm them against the vehicle documents. The catalog data remains under ODbL; application code is governed separately by the repository's existing license.

To rebuild the compact source from the upstream `data/json/all.json` snapshot, run:

```sh
python3 scripts/prepare-vehicle-catalog.py /path/to/all.json data/vehicle-catalog.json
```

Then build the app resource using the curated generation index:

```sh
python3 scripts/build_enriched_vehicle_catalog.py ../data/vehicle-catalog.json ../data/vehicle-generation-index.json EuroAuto/Resources/vehicle-catalog.json
```
