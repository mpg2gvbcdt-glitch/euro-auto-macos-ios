# Vehicle catalog attribution

`vehicle-catalog.json` is a compact, filtered adaptation of the vehicle-makes-models database:

- Project: [gor3a/vehicle-makes-models](https://github.com/gor3a/vehicle-makes-models)
- Upstream source credited by that project: [autoevolution.com](https://www.autoevolution.com/)
- Data license: [Open Database License 1.0 (ODbL)](https://opendatacommons.org/licenses/odbl/1-0/)
- Changes: only makes already present in this application are retained; raw specifications are reduced to model, generation, engine, powertrain, and body measurements used by the form.

The upstream data is compiled from public sources and may omit or vary by market, body style, equipment, and homologation. Treat returned values as reference data and confirm them against the vehicle documents. The catalog data remains under ODbL; application code is governed separately by the repository's existing license.

To rebuild the compact file from the upstream `data/json/all.json` snapshot, run:

```sh
python3 scripts/prepare-vehicle-catalog.py /path/to/all.json data/vehicle-catalog.json
```
